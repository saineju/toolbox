#!/bin/bash

mkdir -p /dev/net
mknod /dev/net/tun c 10 200
ip tuntap add mode tap tap
