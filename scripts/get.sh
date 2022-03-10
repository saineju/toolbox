#!/bin/bash

case $(uname -m) in
  aarch64)
    ARCH='arm64'
  ;;
  x86_64)
    ARCH='amd64'
  ;;
  *)
    echo "Unsupported arch"
    exit 1
  ;;
esac

install_terraform() {
    ver=$1
    if [[ "${ver}" == "" ||  "${ver}" == "latest" ]]; then
        ver=$(curl -s https://releases.hashicorp.com/terraform/|grep -Eo "\/[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\/"|head -1|tr -d '/')
    fi
    echo "Attempting to install terraform version ${ver}"
    DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${ver}"
    FILE="terraform_${ver}_linux_${ARCH}.zip"
    SHASUMS="terraform_${ver}_SHA256SUMS"
    wget -qO /tmp/${FILE} ${DOWNLOAD_URL}/${FILE}
    wget -qO /tmp/${SHASUMS} ${DOWNLOAD_URL}/${SHASUMS}
    cd /tmp
    grep -Eo "^.* ${FILE}" ${SHASUMS}|sha256sum -c
    if [ $? != 0 ]; then
        echo "Checksums did not match, downloaded file is corrupted, exiting"
        exit 1
    fi
    unzip /tmp/${FILE} -d /usr/local/sbin
    rm -f /tmp/${FILE}
    rm -f /tmp/${SHASUMS}
}

function install_helm() {
    ver=$1
    if [[ "${ver}" == "" || "${ver}" == "latest" ]]; then
        ver=$(curl -s https://api.github.com/repos/helm/helm/releases/latest |jq -r .tag_name)
    fi
    echo "Attempting to install helm version ${ver}"
    DOWNLOAD_URL="https://get.helm.sh"
    FILE="helm-${ver}-linux-${ARCH}.tar.gz"
    SHASUMS="${FILE}.sha256"
    wget -qO /tmp/${FILE} ${DOWNLOAD_URL}/${FILE}
    wget -qO /tmp/${SHASUMS} ${DOWNLOAD_URL}/${SHASUMS}
    cd /tmp
    echo "$(cat ${SHASUMS}) ${FILE}"|sha256sum -c
    if [ $? != 0 ]; then
        echo "Checksums did not match, downloaded file is corrupted, exiting"
        exit 1
    fi
    tar -xzvf ${FILE}
    #mv /tmp/linux-amd64/tiller /usr/local/sbin/
    mv /tmp/linux-amd64/helm /usr/local/sbin/
    rm -rf /tmp/linux-amd64
    rm -f /tmp/${FILE}
    rm -f /tmp/${SHASUMS}
}

function install_hcloud() {
    ver=$1
    if [[ "${ver}" == "" || "${ver}" == "latest" ]]; then
        ver=$(curl -s https://api.github.com/repos/hetznercloud/cli/releases/latest|jq -r .tag_name)
    fi
    echo "Attempting to install Hetzner cloud cli version ${ver}"
    DOWNLOAD_URL="https://github.com/hetznercloud/cli/releases/download/${ver}"
    FILE="hcloud-linux-${ARCH}.tar.gz"
    wget -qO /tmp/${FILE} ${DOWNLOAD_URL}/${FILE}
    cd /tmp
    mkdir hcloud
    cd hcloud
    tar -xzvf /tmp/${FILE}
    chmod +x hcloud
    mv /tmp/hcloud/hcloud /usr/local/sbin/
    rm -rf /tmp/hcloud
    rm -f /tmp/${FILE}
}

function install_bitwarden() {
    if [ "${ARCH}" == 'arm64' ]; then
        echo "Unfortunately bitwarden does not have precompiled binary for arm64, and currently this task does not support building it."
        exit 0
    fi
    ver=$1
    if [[ "${ver}" == "" || "${ver}" == "latest" ]]; then
        ver=$(curl -s https://api.github.com/repos/bitwarden/cli/releases/latest|jq -r .tag_name)
    fi
    echo "Attempting to install Bitwarden cli version ${ver}"
    DOWNLOAD_URL="https://github.com/bitwarden/cli/releases/download/${ver}"
    FILE="bw-linux-${ver:1}.zip"
    SHASUMS="bw-linux-sha256-${ver:1}.txt"
    wget -qO /tmp/${FILE} ${DOWNLOAD_URL}/${FILE}
    wget -qO /tmp/${SHASUMS} ${DOWNLOAD_URL}/${SHASUMS}
    cd /tmp
    dos2unix ${SHASUMS}
    echo "$(cat ${SHASUMS}) ${FILE}"|sha256sum -c
    if [ $? != 0 ]; then
        echo "Checksums did not match, downloaded file is corrupted, exiting"
        exit 1
    fi
    unzip /tmp/${FILE} -d /usr/local/sbin
    rm -f /tmp/${FILE}
    rm -f /tmp/${SHASUMS}
}

function install_lastpass() {
    apt-get --no-install-recommends -y install \
    bash-completion \
    build-essential \
    cmake \
    libcurl4  \
    libcurl4-openssl-dev  \
    libssl-dev  \
    libxml2 \
    libxml2-dev  \
    libssl1.1 \
    pkg-config \
    ca-certificates \
    xclip
    cd /tmp
    git clone --single-branch https://github.com/lastpass/lastpass-cli.git
    cd lastpass-cli
    make
    make install
    cd /tmp
    rm -rf lastpass-cli
}

function install_key_vault() {
    cd /tmp
    git clone --single-branch --branch support_aws_and_password https://github.com/saineju/modular_key_vault.git
    cd modular_key_vault
    cp -R backends /usr/local/sbin/
    cp -R support_scripts /usr/local/sbin/
    cp key_vault.sh /usr/local/sbin/
    cp vssh /usr/local/sbin
    cd /tmp
    rm -rf modular_key_vault
}

while [ "$1" != "" ]; do
    case $1 in
        terraform)
            shift
            install_terraform $1
            shift
            ;;
        helm)
            shift
            install_helm $1
            shift
            ;;
        hcloud)
            shift
            install_hcloud $1
            shift
            ;;
        bitwarden)
            shift
            install_bitwarden $1
            shift
            ;;
        lastpass)
            install_lastpass
            shift
            ;;
        key_vault)
            install_key_vault
            shift
            ;;
        *)
            echo "get $1 not implemented, sorry"
            exit 1
            ;;
    esac
done
