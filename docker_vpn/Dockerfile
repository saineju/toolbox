FROM ubuntu:24.04

COPY scripts /scripts
RUN chmod +x /scripts/* && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y openvpn openconnect microsocks net-tools squid sudo nftables python3-minimal iproute2 && \
    useradd -m default && \
    echo 'Defaults:default !requiretty' > /etc/sudoers.d/default && \
    echo 'Defaults    env_keep += OPENVPN_CONFIG_PATH' >> /etc/sudoers.d/default && \
    echo 'Defaults    env_keep += OPENCONNECT_URL' >> /etc/sudoers.d/default && \
    echo 'Defaults    env_keep += OPENCONNECT_PARAMS' >> /etc/sudoers.d/default && \
    echo 'Defaults    env_keep += VPN_USER' >> /etc/sudoers.d/default && \
    echo 'Defaults    env_keep += OTP_CODE' >> /etc/sudoers.d/default && \
    echo 'Defaults    env_keep += ASK_OTP' >> /etc/sudoers.d/default && \
    echo 'default ALL=NOPASSWD:/scripts/start_vpn.sh' >> /etc/sudoers.d/default && \
    echo 'default ALL=NOPASSWD:/scripts/firewall.sh' >> /etc/sudoers.d/default && \
    echo 'default ALL=NOPASSWD:/scripts/stop_vpn.sh' >> /etc/sudoers.d/default && \
    echo 'default ALL=NOPASSWD:/usr/sbin/squid' >> /etc/sudoers.d/default && \
    echo 'default ALL=NOPASSWD:/scripts/nft_logger.sh' >> /etc/sudoers.d/default && \
    visudo -c -f /etc/sudoers.d/default && \
    rm -f /var/log/squid/access.log /var/log/squid/cache.log && \
    mkfifo -m 0666 /var/log/squid/access.log /var/log/squid/cache.log

USER default
WORKDIR /openvpn

ENTRYPOINT ["/scripts/entrypoint.sh"]
