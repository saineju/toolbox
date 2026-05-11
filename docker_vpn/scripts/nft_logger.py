#!/usr/bin/env python3
"""Read nftables NFLOG group and print dropped packet info to stdout."""
import os, socket, struct, sys

NETLINK_NETFILTER    = 12
NFNL_SUBSYS_ULOG     = 4
NFULNL_MSG_PACKET    = 0
NFULNL_MSG_CONFIG    = 1
NFULA_CFG_CMD        = 1
NFULA_CFG_MODE       = 2
NFULA_IFINDEX_INDEV  = 4
NFULA_IFINDEX_OUTDEV = 5
NFULA_PAYLOAD        = 9
NFULA_PREFIX         = 10
NFULNL_CFG_CMD_BIND  = 1
NFULNL_COPY_PACKET   = 2
NLM_F_REQUEST        = 1
NLM_F_ACK            = 4

PROTOS = {1: 'ICMP', 6: 'TCP', 17: 'UDP', 58: 'ICMPv6'}

def nla(nla_type, data):
    n = 4 + len(data)
    return struct.pack('HH', n, nla_type) + data + b'\x00' * ((-n) & 3)

def nl_send(sock, msg_type, flags, payload):
    length = 16 + len(payload)
    sock.sendall(struct.pack('IHHII', length, msg_type, flags, 0, os.getpid()) + payload)

def nfg(family, group):
    return struct.pack('BBH', family, 0, socket.htons(group))

def configure_group(sock, family, group):
    msg_type = (NFNL_SUBSYS_ULOG << 8) | NFULNL_MSG_CONFIG
    nl_send(sock, msg_type, NLM_F_REQUEST | NLM_F_ACK,
            nfg(family, group) + nla(NFULA_CFG_CMD, struct.pack('B', NFULNL_CFG_CMD_BIND)))
    sock.recv(65536)
    # Request full packet payload — without this the kernel sends only the prefix
    nl_send(sock, msg_type, NLM_F_REQUEST | NLM_F_ACK,
            nfg(family, group) + nla(NFULA_CFG_MODE, struct.pack('!IBx', 65535, NFULNL_COPY_PACKET)))
    sock.recv(65536)

def parse_ip(data):
    if not data:
        return {}
    try:
        ver = data[0] >> 4
        if ver == 4 and len(data) >= 20:
            ihl = (data[0] & 0xF) * 4
            proto = data[9]
            r = {'src': socket.inet_ntop(socket.AF_INET,  data[12:16]),
                 'dst': socket.inet_ntop(socket.AF_INET,  data[16:20]),
                 'proto': PROTOS.get(proto, proto)}
            if proto in (6, 17) and len(data) >= ihl + 4:
                r['sport'], r['dport'] = struct.unpack_from('!HH', data, ihl)
            return r
        if ver == 6 and len(data) >= 40:
            proto = data[6]
            r = {'src': socket.inet_ntop(socket.AF_INET6, data[8:24]),
                 'dst': socket.inet_ntop(socket.AF_INET6, data[24:40]),
                 'proto': PROTOS.get(proto, proto)}
            if proto in (6, 17) and len(data) >= 44:
                r['sport'], r['dport'] = struct.unpack_from('!HH', data, 40)
            return r
    except Exception:
        pass
    return {}

group = int(sys.argv[1]) if len(sys.argv) > 1 else 1
sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, NETLINK_NETFILTER)
sock.bind((os.getpid(), 0))
configure_group(sock, socket.AF_INET,  group)
configure_group(sock, socket.AF_INET6, group)

while True:
    data = sock.recv(65536)
    if len(data) < 20:
        continue
    nl_len, nl_type = struct.unpack_from('IH', data, 0)
    if (nl_type >> 8) != NFNL_SUBSYS_ULOG or (nl_type & 0xFF) != NFULNL_MSG_PACKET:
        continue

    prefix = ''
    raw_pkt = b''
    in_idx = out_idx = 0

    off = 20  # skip 16-byte nl header + 4-byte nfgenmsg header
    while off + 4 <= min(nl_len, len(data)):
        nla_len, nla_type = struct.unpack_from('HH', data, off)
        if nla_len < 4:
            break
        val = data[off+4:off+nla_len]
        match nla_type:
            case 10:  # NFULA_PREFIX
                prefix = val.rstrip(b'\x00').decode('utf-8', errors='replace')
            case 9:   # NFULA_PAYLOAD
                raw_pkt = val
            case 4:   # NFULA_IFINDEX_INDEV
                in_idx  = struct.unpack('!I', val)[0] if len(val) >= 4 else 0
            case 5:   # NFULA_IFINDEX_OUTDEV
                out_idx = struct.unpack('!I', val)[0] if len(val) >= 4 else 0
        off += (nla_len + 3) & ~3

    p = parse_ip(raw_pkt)
    parts = [prefix.rstrip() or 'nft_drop:']
    if in_idx:
        try:    parts.append(f'IN={socket.if_indextoname(in_idx)}')
        except OSError: pass
    if out_idx:
        try:    parts.append(f'OUT={socket.if_indextoname(out_idx)}')
        except OSError: pass
    if p.get('src'):    parts.append(f'SRC={p["src"]}')
    if p.get('dst'):    parts.append(f'DST={p["dst"]}')
    if p.get('proto'):  parts.append(f'PROTO={p["proto"]}')
    if p.get('sport'):  parts.append(f'SPT={p["sport"]} DPT={p["dport"]}')

    print(' '.join(parts), flush=True)
