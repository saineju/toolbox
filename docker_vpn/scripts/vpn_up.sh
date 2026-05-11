#!/bin/bash
set -euo pipefail
# Called by OpenVPN as root when the tunnel comes up.
# $trusted_ip (VPN server IP) and $dev (tunnel interface) are set by OpenVPN.
#/scripts/firewall.sh strict "${trusted_ip}" "${dev}"

