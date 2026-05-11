#!/bin/bash

SUPPORTED="openvpn openconnect"

sudo /scripts/firewall.sh relaxed
sudo /scripts/nft_logger.sh &
while cat /var/log/squid/access.log; do :; done &
while cat /var/log/squid/cache.log; do :; done >&2 &
sudo squid -N &
/usr/bin/microsocks ${MICROSOCKS_PARAMS} &

if [[ -n "${TYPE}" ]]; then
    sudo /scripts/start_vpn.sh ${TYPE}
else
    echo "Proxies ready. Connect with: docker exec -it <name> sudo /scripts/start_vpn.sh <type>"
    echo "Supported types: ${SUPPORTED}"
    sleep infinity
fi
