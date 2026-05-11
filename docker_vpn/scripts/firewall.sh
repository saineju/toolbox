#!/bin/bash
set -euo pipefail

nft delete table inet vpn_fw 2>/dev/null || true

nft -f - <<'EOF'
table inet vpn_fw {
    chain input {
        type filter hook input priority filter; policy drop;
        iif lo accept
        ct state established,related accept
        ct state invalid drop
        tcp dport { 1080, 3128 } accept
        log prefix "nft_drop: " group 1 counter drop
    }
    chain output {
        type filter hook output priority filter; policy drop;
        oif lo accept
        #oifname "tap*" accept
        #oifname "tun*" accept
        ct state established,related accept
        ct state invalid drop
        meta l4proto { tcp, udp } th dport 53 accept
        meta skuid 13 tcp dport { 80, 443 } accept
        udp dport 1194 accept
        tcp dport 1194 accept
        tcp dport 22 log prefix "ssh_allow:" group 1 accept
        log prefix "nft_drop: " group 1 counter drop
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
    }
}
EOF
echo "Firewall: active"
