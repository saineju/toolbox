#!/bin/bash
set -euo pipefail
# Called by OpenVPN as root when the tunnel goes down.
/scripts/firewall.sh relaxed
