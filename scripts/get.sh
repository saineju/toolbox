#!/bin/bash

ORIG_ARCH=$(uname -m)
case ${ORIG_ARCH} in
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
        ver=$(curl -s https://api.github.com/repos/helm/helm/releases/latest |jq -r .tag_name|tr -d "v")
    fi
    echo "Attempting to install helm version ${ver}"
    DOWNLOAD_URL="https://get.helm.sh"
    FILE="helm-v${ver}-linux-${ARCH}.tar.gz"
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
    mv /tmp/linux-${ARCH}/helm /usr/local/sbin/
    rm -rf /tmp/linux-${ARCH}
    rm -f /tmp/${FILE}
    rm -f /tmp/${SHASUMS}
}

function install_hcloud() {
    ver=$1
    if [[ "${ver}" == "" || "${ver}" == "latest" ]]; then
        ver=$(curl -s https://api.github.com/repos/hetznercloud/cli/releases/latest|jq -r .tag_name|tr -d "v")
    fi
    echo "Attempting to install Hetzner cloud cli version ${ver}"
    DOWNLOAD_URL="https://github.com/hetznercloud/cli/releases/download/v${ver}"
    FILE="hcloud-linux-${ARCH}.tar.gz"
    SHASUMS="hetzner_checksums.txt"
    wget -qO /tmp/${FILE} ${DOWNLOAD_URL}/${FILE}
    wget -qO /tmp/${SHASUMS} $DOWNLOAD_URL/checksums.txt
    cd /tmp
    grep -Eo "^.* ${FILE}" ${SHASUMS}|sha256sum -c
    if [ $? != 0 ]; then
        echo "Checksums did not match, downloaded file is corrupted, exiting"
        exit 1
    fi
    mkdir hcloud
    cd hcloud
    tar -xzvf /tmp/${FILE}
    chmod +x hcloud
    mv /tmp/hcloud/hcloud /usr/local/sbin/
    rm -rf /tmp/hcloud
    rm -f /tmp/${FILE}
    rm -f /tmp/${SHASUMS}
}

function install_bitwarden() {
    if [ "${ARCH}" == 'arm64' ]; then
        echo "Unfortunately bitwarden does not have precompiled binary for arm64, and currently this task does not support building it."
        exit 0
    fi
    ver=$1
    if [[ "${ver}" == "" || "${ver}" == "latest" ]]; then
        ver=$(curl -s https://api.github.com/repos/bitwarden/cli/releases/latest|jq -r .tag_name|tr -d "v")
    fi
    echo "Attempting to install Bitwarden cli version ${ver}"
    DOWNLOAD_URL="https://github.com/bitwarden/cli/releases/download/v${ver}"
    FILE="bw-linux-${ver}.zip"
    SHASUMS="bw-linux-sha256-${ver}.txt"
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

function install_awscliv2() {
    cd /tmp
    gpg --import awscli.pgp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${ORIG_ARCH}.zip" -o "awscliv2.zip"
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${ORIG_ARCH}.zip.sig" -o "awscliv2.sig"
    gpg --verify awscliv2.sig awscliv2.zip
    if [ $? != 0 ]; then
        echo "Signature does not match, download corrupted, exiting"
        exit 1
    fi
    unzip awscliv2.zip
    ./aws/install
    rm -rf /tmp/aws
    rm -f /tmp/awscliv2.zip
    rm -f /tmp/awscliv2.sig
}

function install_uv() {
    ver=$1
    if [[ "${ver}" == "" || "${ver}" == "latest" ]]; then
        ver=$(curl -s https://api.github.com/repos/astral-sh/uv/releases/latest|jq -r .tag_name|tr -d "v")
    fi
    filename="uv-${ORIG_ARCH}-unknown-linux-gnu.tar.gz"
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${ver}/${filename}" -o /tmp/${filename}
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${ver}/${filename}.sha256" -o /tmp/${filename}.sha256
    cd /tmp
    sha256sum -c ${filename}.sha256
    if [ $? != 0 ]; then
	echo "Signature does not match, download corrupted, exiting"
	exit 1
    fi
    tar -xzf /tmp/${filename} -C /usr/local/sbin --strip-components=1 uv-${ORIG_ARCH}-unknown-linux-gnu/uv
    rm -f /tmp/${filename}
    rm -f /tmp/${filename}.sha256
}

function install_starship() {
    ver=$1
    filename=starship-${ORIG_ARCH}-unknown-linux-musl.tar.gz
    if [[ "${ver}" == "" || "${ver}" == "latest" ]]; then
        ver=$(curl -s https://api.github.com/repos/starship/starship/releases/latest|jq -r .tag_name|tr -d "v")
    fi
    curl -fsSL "https://github.com/starship/starship/releases/download/v${ver}/${filename}" -o /tmp/${filename}
    curl -fsSL "https://github.com/starship/starship/releases/download/v${ver}/${filename}.sha256" -o /tmp/${filename}.sha256
    echo "$(cat /tmp/${filename}.sha256) /tmp/${filename}" | sha256sum -c -
    if [ $? != 0 ]; then
	echo "Signature does not match, download corrupted, exiting"
	exit 1
    fi
    tar -xzf /tmp/${filename} -C /usr/local/sbin starship
    rm /tmp/${filename} /tmp/${filename}.sha256
}

function install_mfahelper() {
    wget -qO /usr/local/sbin/mfa_credentials.py https://raw.githubusercontent.com/saineju/awscli_mfa/master/mfa_credentials.py
}

function install_vault() {
    ver=$1
    if [[ "${ver}" == "" ||  "${ver}" == "latest" ]]; then
        ver=$(curl -s https://releases.hashicorp.com/vault/|grep -Eo "\/[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\/"|head -1|tr -d '/')
    fi
    echo "Attempting to install vault version ${ver}"
    DOWNLOAD_URL="https://releases.hashicorp.com/vault/${ver}"
    FILE="vault_${ver}_linux_${ARCH}.zip"
    SHASUMS="vault_${ver}_SHA256SUMS"
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

function install_kubectl() {
    ver=$1
    if [[ "${ver}" == "" || "${ver}" == "latest" ]]; then
	ver=$(curl -s https://dl.k8s.io/release/stable.txt | tr -d 'v')
    fi
    echo "Attempting to install kubectl version ${ver}"
    DOWNLOAD_URL=https://dl.k8s.io/v${ver}/bin/linux/${ARCH}
    FILE=kubectl
    SHASUMS=${FILE}.sha256
    wget -qO /tmp/${FILE} ${DOWNLOAD_URL}/${FILE}
    wget -qO /tmp/${SHASUMS} ${DOWNLOAD_URL}/${SHASUMS}
    echo "$(cat /tmp/${SHASUMS}) /tmp/${FILE}" | sha256sum -c
    if [ $? != 0 ]; then
	echo "Checksums did not match, downloaded file is corrupted, exiting"
	exit 1
    fi
    mv /tmp/kubectl /usr/local/sbin/
    rm -f /tmp/${FILE}
    rm -f /tmp/${SHASUMS}
}

function repo_gcloud() {
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor | tee /etc/apt/keyrings/google-cloud.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/google-cloud.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
	    > /etc/apt/sources.list.d/google-cloud-sdk.list
}

function repo_azure() {
    curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null
    chmod go+r /etc/apt/keyrings/microsoft.gpg
    echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: $(lsb_release -cs)
Components: main
Architectures: ${ARCH}
Signed-by: /etc/apt/keyrings/microsoft.gpg" | tee /etc/apt/sources.list.d/azure-cli.sources
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main"
}

function install_ssm() {
    cd /tmp
    local arch=${ARCH}
    if [[ "${arch}" == "amd64" ]]; then
	arch=64bit
    fi
    gpg --import aws_ssm.pgp
    DOWNLOAD_URL=https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_${arch}
    FILE=session-manager-plugin.deb
    SIG=${FILE}.sig
    wget -qO /tmp/${FILE} ${DOWNLOAD_URL}/${FILE}
    wget -qO /tmp/${SIG} ${DOWNLOAD_URL}/${SIG}
    gpg --verify ${SIG} ${FILE}
    if [ $? != 0 ]; then
        echo "Signature does not match, download corrupted, exiting"
        exit 1
    fi
    dpkg -i /tmp/${FILE}
    rm -f /tmp/${FILE}
    rm -f /tmp/${SIG}
    rm -f /tmp/aws_ssm.pgp
}

function repo_heroku() {
    curl -fsSL https://cli-assets.heroku.com/apt/release.key | gpg --dearmor | tee /etc/apt/keyrings/heroku.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/heroku.gpg] https://cli-assets.heroku.com/apt ./" > /etc/apt/sources.list.d/heroku.list
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
        key_vault)
            install_key_vault
            shift
            ;;
        awscliv2)
            install_awscliv2
            shift
            ;;
	uv)
	    shift
	    install_uv $1
	    shift
	    ;;
	starship)
	    shift
	    install_starship $1
	    shift
	    ;;
	mfahelper)
	    install_mfahelper
	    shift
	    ;;
	kubectl)
	    shift
	    install_kubectl $1
	    shift
	    ;;
	vault)
	    shift
	    install_vault $1
	    shift
	    ;;
	gcloud)
	    repo_gcloud
	    shift
	    ;;
	azure)
	    repo_azure
	    shift
	    ;;
	ssm)
	    install_ssm
	    shift
	    ;;
	heroku)
	    repo_heroku
	    shift
	    ;;
        *)
            echo "get $1 not implemented, sorry"
            exit 1
            ;;
    esac
done
