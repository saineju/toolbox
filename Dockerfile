FROM ubuntu:24.04

ARG UNAME=toolbox
ARG UID=1000
ARG GID=1000
ARG TERRAFORM=true
ARG TERRAFORMVERSION=latest
ARG HELM=true
ARG HELMVERSION=latest
ARG KUBECTL=true
ARG KUBECTLVERSION=kubectl
ARG HEROKU=true
ARG GCLOUD=true
ARG AWSCLI=true
ARG AWS_SSM=true
ARG HCLOUD=true
ARG HCLOUDVERSION=latest
ARG BITWARDEN=true
ARG BITWARDENVERSION=latest
ARG KEYVAULT=true
ARG VAULT=true
ARG VAULTVERSION=vault
ARG AZURE_CLI=true
ARG KUBECTLREPOVERSION=v1.32
# Check https://github.com/starship/starship/releases for the latest version
ARG STARSHIP_VERSION=1.25.1
ARG UV_VERSION=0.11.8

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash","-c"]

## Setup timezone
RUN ln -fs /usr/share/zoneinfo/Europe/Helsinki /etc/localtime

## Install updates & required packages
RUN apt-get update \
 && apt-get -y upgrade \
 && apt-get install -y curl gnupg-agent ca-certificates apt-transport-https python3-minimal python3-pip python3-venv \
    zsh git vim nano language-pack-en software-properties-common lsof unzip wget jq dos2unix dnsutils sshpass \
    ncat rsync tzdata jo iputils-ping jc neovim python3-neovim \
    krb5-user proxychains-ng bsdmainutils \
 && dpkg-reconfigure --frontend noninteractive tzdata \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

## Set up user
RUN userdel ubuntu \
 && groupadd -g $GID -o $UNAME \
 && useradd -m -u $UID -g $GID -o -s /bin/zsh $UNAME \
 && apt-get clean \
 && mkdir -p /home/$UNAME/.config \
 && chown -R $UNAME:$UNAME /home/$UNAME

## Install Starship
RUN arch=$(uname -m) \
 && filename=starship-${arch}-unknown-linux-musl.tar.gz \
 && curl -fL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/${filename}" \
    -o /tmp/${filename} \
 && curl -fL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/${filename}.sha256" \
    -o /tmp/${filename}.sha256 \
 && echo "$(cat /tmp/${filename}.sha256) /tmp/${filename}" | sha256sum -c - \
 && tar -xzf /tmp/${filename} -C /usr/local/bin starship \
 && rm /tmp/${filename} /tmp/${filename}.sha256

# Copy requirements, scripts & configs
COPY requirements.txt /tmp/requirements.txt
COPY scripts/ /usr/local/sbin/
COPY awscli.pgp /tmp/awscli.pgp

# Get aws cli mfa helper script
RUN wget -qO /usr/local/sbin/mfa_credentials.py https://raw.githubusercontent.com/saineju/awscli_mfa/master/mfa_credentials.py

RUN arch=$(uname -m) \
  && filename="uv-${arch}-unknown-linux-gnu.tar.gz" \
  && curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${filename}" \
    -o /tmp/${filename} \
 && curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${filename}.sha256" \
    -o /tmp/${filename}.sha256 \
 && cd /tmp \
 && sha256sum -c ${filename}.sha256 \
 && tar -xzf /tmp/${filename} -C /usr/local/bin --strip-components=1 uv-${arch}-unknown-linux-gnu/uv \
 && rm /tmp/${filename} /tmp/${filename}.sha256
                                               

## Install Hashicorp Vault
RUN [[ "${VAULT}" == "true" || "${VAULT}" == "yes" ]] \
 && arch=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') \
 && curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor | tee /etc/apt/keyrings/hashicorp.gpg > /dev/null \
 && echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list \
 && apt-get update \
 && apt-get install -y ${VAULTVERSION} libcap2 \
 && setcap cap_ipc_lock= /usr/bin/vault \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 || true

## Install heroku cli
RUN [[ "${HEROKU}" == "true" || "${HEROKU}" == "yes" ]] \
 && curl -fsSL https://cli-assets.heroku.com/apt/release.key \
    | gpg --dearmor | tee /etc/apt/keyrings/heroku.gpg > /dev/null \
 && echo "deb [signed-by=/etc/apt/keyrings/heroku.gpg] https://cli-assets.heroku.com/apt ./" \
    > /etc/apt/sources.list.d/heroku.list \
 && apt-get update \
 && apt-get install -y heroku \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 || true

## Install kubectl
RUN [[ "${KUBECTL}" == "true" || "${KUBECTL}" == "yes" ]] \
  && curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBECTLREPOVERSION}/deb/Release.key \                                                                                      
     | gpg --dearmor | tee /etc/apt/keyrings/kubernetes.gpg > /dev/null \                                                                                    
  && echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/${KUBECTLREPOVERSION}/deb/ /" \                                                  
     > /etc/apt/sources.list.d/kubernetes.list \
 && apt-get update \
 && apt-get install -y ${KUBECTLVERSION} \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 || true

## Install google cloud sdk
RUN [[ "${GCLOUD}" == "true" || "${GCLOUD}" == "yes" ]] \
 && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor | tee /etc/apt/keyrings/google-cloud.gpg > /dev/null \
 && echo "deb [signed-by=/etc/apt/keyrings/google-cloud.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list \
 && apt-get update \
 && apt-get install -y google-cloud-sdk \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 || true

## Install AWSCLI v2
RUN [[ "${AWSCLI}" == "true" || "${AWSCLI}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh awscliv2 \
 || true

## Install AWS Session manager
RUN [[ "${AWS_SSM}" == "true" || "${AWS_SSM}" == "yes" ]] \
 && arch=$(uname -m | sed -e 's/x86_64/64bit/' -e 's/aarch64/arm64/') \
 && curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_${arch}/session-manager-plugin.deb" \
    -o "/tmp/session-manager-plugin.deb" \
 && dpkg -i /tmp/session-manager-plugin.deb \
 && rm -f /tmp/session-manager-plugin.deb \
 || true

## Install helm
RUN [[ "${HELM}" == "true" || "${HELM}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh helm ${HELMVERSION} \
 || true

## Install terraform
RUN [[ "${TERRAFORM}" == "true" || "${TERRAFORM}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh terraform ${TERRAFORMVERSION} 
# || true

## Install hetzner cloud
RUN [[ "${HCLOUD}" == "true" || "${HCLOUD}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh hcloud ${HCLOUDVERSION} \
 || true

## Install bitwarden
RUN [[ "${BITWARDEN}" == "true" || "${BITWARDEN}" == "yes" ]] \
  && bash /usr/local/sbin/get.sh bitwarden ${BITWARDENVERSION} \
  || true

## Install keyvault
RUN [[ "${KEYVAULT}" == "true" ]] \
  && bash /usr/local/sbin/get.sh key_vault \
  || true

## Install Azure CLI
RUN [[ "${AZURE_CLI}" == "true" || "${AZURE_CLI}" == "yes" ]] \
  && mkdir -p /etc/apt/keyrings \
  && curl -sLS https://packages.microsoft.com/keys/microsoft.asc \
     | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null \
  && chmod go+r /etc/apt/keyrings/microsoft.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
     | tee /etc/apt/sources.list.d/azure-cli.list \
  && apt-get update \
  && apt-get install -y azure-cli \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  || true

## Add any additional CA's as trusted
COPY ./ca_certs/* /usr/local/share/ca-certificates/
RUN update-ca-certificates

## Make sure all scripts are executable
RUN chmod +x /usr/local/sbin/*

## Make home dir persistent
VOLUME /home/$UNAME

## Install python modules
RUN uv venv /opt/toolbox \
 && uv pip install --python /opt/toolbox/bin/python -r /tmp/requirements.txt \
 && rm -f /tmp/requirements.txt

## Switch user & workdir
USER $UNAME
WORKDIR /home/$UNAME

ENTRYPOINT ["/bin/zsh"]
