#!/bin/bash

TYPE=$1

if [ -z "${VPN_USER}" ]; then
    read -p "Enter username for vpn: " VPN_USER
fi
read -sp "Enter password for vpn: " password
echo

_monitor_openconnect() {
    local vpn_server_ip="$1"
    local oc_pid="$2"
    local prev_state="down"

    while kill -0 "${oc_pid}" 2>/dev/null; do
        local iface
        iface=$(ip -o link show | awk -F': ' '/^[0-9]+: (tap|tun)/{print $2; exit}')
        if [ -n "${iface}" ] && [ "${prev_state}" = "down" ]; then
            #/scripts/firewall.sh strict "${vpn_server_ip}" "${iface}"
            prev_state="up"
        elif [ -z "${iface}" ] && [ "${prev_state}" = "up" ]; then
            /scripts/firewall.sh relaxed
            prev_state="down"
        fi
        sleep 2
    done
    /scripts/firewall.sh relaxed
}

openconnect() {
    if [ -z "${OPENCONNECT_URL}" ]; then
        read -p "Enter openconnect url: " OPENCONNECT_URL
    fi

    local oc_host
    oc_host=$(echo "${OPENCONNECT_URL}" | sed -E 's|^https?://||; s|/.*||; s|:.*||')
    local vpn_server_ip
    vpn_server_ip=$(getent ahostsv4 "${oc_host}" 2>/dev/null | awk 'NR==1{print $1}')
    if [ -z "${vpn_server_ip}" ]; then
        vpn_server_ip=$(getent hosts "${oc_host}" | awk 'NR==1{print $1}')
    fi

    echo "${password}" | /usr/sbin/openconnect "${OPENCONNECT_URL}" -u "${VPN_USER}" \
        --non-inter --passwd-on-stdin ${OPENCONNECT_PARAMS} &
    local oc_pid=$!

    _monitor_openconnect "${vpn_server_ip}" "${oc_pid}" &
    wait "${oc_pid}"
}

openvpn() {
    if [ ! -f /dev/net/tun ]; then
        /scripts/create_device.sh
    fi
    if [ ! -z "${ASK_OTP}" ]; then
        read -sp "Enter OTP Code: " OTP_CODE
    fi

    if [ ! -z "${OTP_CODE}" ]; then
        password=${password}${OTP_CODE}
    fi

    /usr/sbin/openvpn \
        --config "${OPENVPN_CONFIG_PATH:-/openvpn/ovpn.conf}" \
        --auth-user-pass <(printf '%s\n%s\n' "$VPN_USER" "$password") \
        --script-security 2 \
        --up /scripts/vpn_up.sh \
        --down /scripts/vpn_down.sh
}

case ${TYPE} in
  openvpn)
    openvpn
  ;;
  openconnect)
    openconnect
  ;;
esac

