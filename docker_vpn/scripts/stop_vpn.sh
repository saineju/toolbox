#!/bin/bash
set -euo pipefail
pkill -x openvpn 2>/dev/null && echo "Stopped openvpn" || true
pkill -x openconnect 2>/dev/null && echo "Stopped openconnect" || true
