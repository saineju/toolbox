# docker_vpn

This is an experimental setup to use dockers for VPN connections. 
Initially only openvpn is supported, but within time there migth be other VPN clients as well

The original idea is to use the container to connect to VPN and open a socks proxy through which
the resources behind the VPN can be accessed. Currently the container uses microsocks as the socks
proxy server, but it could just as easily include openssh server and that could be used to create
socks proxy instead.

This is still very much work in progress and requires further testing.

### Usage

First build the container

```
docker build -t openvpntest .
``` 

Currently the docker aims to connect to VPN directly and it expects to find openvpn related configurations
and other related files from /openvpn -directory and it currently expects that the vpn configuration file is
named ovpn.conf.

Start the container (firewall and proxies only, no VPN yet):

```
docker run --name vpn --cap-add NET_ADMIN -v /path/to/openvpn:/openvpn -p 127.0.0.1:1080:1080 -it openvpntest
```

Connect the VPN when you need it:

```
docker exec -it vpn sudo /scripts/start_vpn.sh openvpn
```

Disconnect:

```
docker exec vpn sudo /scripts/stop_vpn.sh
```

To connect VPN automatically at container start, pass `-e TYPE=openvpn` (or `TYPE=openconnect`) to `docker run`.

After the proxies are up you should be able to configure your browser to use port 1080 as socks5 proxy and be able to
connect pages over VPN through that proxy. For convenience I prefer to use Firefox with multi account containers
plugin https://addons.mozilla.org/en-US/firefox/addon/multi-account-containers/, as you can configure a proxy
per container.

For SSH connection ssh ProxyCommand can be used

```
host testhost
  hostname <enter real hostname>
  ProxyCommand bash -c 'nc --proxy-type=socks5 --proxy localhost:1080 %h %p'
```

### Routing other containers through the VPN

Any container can have all its traffic automatically routed through the VPN by sharing the VPN
container's network namespace — no proxy configuration needed inside the joined container:

```
docker run --network container:vpn some-other-image
```

The joined container sees the same network interfaces (including the VPN tunnel) and routing
table as the VPN container, so the kill-switch firewall applies to it automatically.

Note: the VPN container must be started before any container that joins its network, and without
`--rm` so it can be restarted with `docker start vpn` without recreating it.

### Firewall

The container runs an nftables firewall (`inet vpn_fw`) from startup:

- **Relaxed** (VPN down): allows DNS, HTTP/HTTPS, and common VPN ports; blocks everything else
- **Strict** (VPN up): allows traffic only through the VPN tunnel and to the VPN server IP
  (so the client can reconnect if the tunnel drops); blocks everything else

For OpenVPN the transition is driven by `--up`/`--down` hooks. For OpenConnect a background
monitor polls for the tunnel interface.

View per-rule packet/byte counters:

```
docker exec vpn nft list ruleset
```

Dropped packets are logged to the host kernel log with prefix `nft_drop:`:

```
dmesg | grep "nft_drop"
```

Note: `ip daddr` in strict mode matches IPv4 only. IPv6 VPN servers are not whitelisted for
reconnection; all their traffic would be blocked while in strict mode.

If your `.ovpn` config contains `up` or `down` directives they will run alongside the firewall
hooks. If that causes conflicts, remove those directives from the config file.

### ToDo

* Make things configurable (vpn config file, microsocks etc)
* Test user/password setups for VPN
