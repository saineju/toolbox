FROM ubuntu:22.04

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
ARG AWS_ECSCLI=true
ARG HCLOUD=true
ARG HCLOUDVERSION=latest
ARG BITWARDEN=true
ARG BITWARDENVERSION=latest
ARG LASTPASS=true
ARG KEYVAULT=true
ARG VAULT=true
ARG VAULTVERSION=vault
ARG AZURE_CLI=true

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash","-c"]

## Setup timezone
RUN ln -fs /usr/share/zoneinfo/Europe/Helsinki /etc/localtime

## Install updates & required packages
RUN apt-get update \ 
 && apt-get -y upgrade \
 && apt-get install -y curl gnupg-agent ca-certificates apt-transport-https python3-minimal python3-pip python3-venv zsh git powerline fonts-powerline \
    vim nano language-pack-en software-properties-common lsof unzip wget jq dos2unix dnsutils sshpass ncat rsync tzdata yq jo iputils-ping \
 && dpkg-reconfigure --frontend noninteractive tzdata

## Set up user and zsh
RUN groupadd -g $GID -o $UNAME \
 && useradd -m -u $UID -g $GID -o -s /bin/zsh $UNAME \
 && apt-get clean \
 && su $UNAME -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" \
 && su $UNAME -c "git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k"

# Copy requirements & scripts
COPY requirements.txt /tmp/requirements.txt
COPY scripts/ /usr/local/sbin/

# Get aws cli mfa helper script
RUN wget -qO /usr/local/sbin/mfa_credentials.py https://raw.githubusercontent.com/saineju/awscli_mfa/master/mfa_credentials.py

## Copy zsh & .ssh configs
COPY --chown=$UNAME .zshrc /home/$UNAME/.zshrc
COPY --chown=$UNAME .ssh /home/$UNAME/.ssh

## Install python modules
RUN pip3 install -r /tmp/requirements.txt && rm -f /tmp/requirements.txt

## Install Hashicorp Vault
RUN [[ "${VAULT}" == "true" || "${VAULT}" == "yes" ]] \
 && arch=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') \
 && curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - \
 && apt-add-repository "deb [arch=${arch}] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
 && apt-get install -y ${VAULTVERSION} libcap2 \
 && setcap cap_ipc_lock= /usr/bin/vault \
 && sed -i 's/^plugins=(\(.*\))/plugins=(\1 vault)/' /home/$UNAME/.zshrc \
 || true

## Install heroku cli
RUN [[ "${HEROKU}" == "true" || "${HEROKU}" == "yes" ]] \
 && echo "deb https://cli-assets.heroku.com/apt ./" > /etc/apt/sources.list.d/heroku.list \
 && curl https://cli-assets.heroku.com/apt/release.key | apt-key add - \ 
 && apt-get update \
 && apt-get install -y heroku \
 && sed -i 's/^plugins=(\(.*\))/plugins=(\1 heroku)/' /home/$UNAME/.zshrc \
 || true

## Install kubectl
RUN [[ "${KUBECTL}" == "true" || "${KUBECTL}" == "yes" ]] \
 && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list \
 && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
 && apt-get update \
 && apt-get install -y ${KUBECTLVERSION} \
 && sed -i 's/^plugins=(\(.*\))/plugins=(\1 kubectl)/' /home/$UNAME/.zshrc \
 || true

## Install google cloud sdk
RUN [[ "${GCLOUD}" == "true" || "${GCLOUD}" == "yes" ]] \
 && echo "deb http://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
 && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
 && apt-get update \
 && apt-get install -y google-cloud-sdk \
 && echo -e '## Gcloud autocomplete\nsource /usr/share/google-cloud-sdk/completion.zsh.inc' >> /home/${UNAME}/.zshrc \
 || true

## Install AWSCLI v2
RUN [[ "${AWSCLI}" == "true" || "${AWSLCI}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh awscliv2 \
 || true

## Install AWS Session manager
RUN [[ "${AWS_SSM}" == "true" || "${AWS_SSM}" == "yes" ]] \
 && arch=$(uname -m | sed -e 's/x86_64/64bit/' -e 's/aarch64/arm64/') \
 && curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_${arch}/session-manager-plugin.deb" -o "/tmp/session-manager-plugin.deb" \
 && dpkg -i /tmp/session-manager-plugin.deb && rm -f /tmp/session-manager-plugin.deb \
 || true

## Install AWS ECS CLI
RUN [[ "${AWS_ECSCLI}" == "true" || "${AWS_ECSCLI}" == "yes" ]] \
 && arch=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') \
 && curl -o /usr/local/sbin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-${arch}-latest \
 || true

## Install helm & tiller
RUN [[ "${HELM}" == "true" || "${HELM}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh helm ${HELMVERSION} \
 && sed -i 's/^plugins=(\(.*\))/plugins=(\1 helm)/' /home/$UNAME/.zshrc \
 || true

## Install terraform
RUN [[ "${TERRAFORM}" == "true" || "${TERRAFORM}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh terraform ${TERRAFORMVERSION} \
 && sed -i 's/^plugins=(\(.*\))/plugins=(\1 terraform)/' /home/$UNAME/.zshrc \
 || true

## Install hetzner cloud
RUN [[ "${HCLOUD}" == "true" || "${HCLOUD}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh hcloud ${HCLOUDVERSION} \
 && echo -e '## Hcloud autocomplete\nsource <(hcloud completion zsh)' >> /home/${UNAME}/.zshrc \
 || true

## Install bitwarden
RUN [[ "${BITWARDEN}" == "true" || "${BITWARDEN}" == "yes" ]] \
  && bash /usr/local/sbin/get.sh bitwarden ${BITWARDENVERSION} \
  || true
  
## Install lastpass cli
RUN [[ "${LASTPASS}" == "true" || "${LASTPASS}" == "yes" ]] \
  && bash /usr/local/sbin/get.sh lastpass \
  || true

## Install keyvault 
RUN [[ "${KEYVAULT}" == "true" ]] \
  && bash /usr/local/sbin/get.sh key_vault \
  || true

## Install Azure CLI
RUN [[ "${AZURE_CLI}" == "true" || "${AZURE_CLI}" == "yes" ]] \
  && mkdir -p /etc/apt/keyrings \
  && curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null \
  && chmod go+r /etc/apt/keyrings/microsoft.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list \
  && apt-get update \
  && apt-get install azure-cli \
  || true
  
  
## Add any additional CA's as trusted
COPY ./ca_certs/* /usr/local/share/ca-certificates/
RUN update-ca-certificates

## Make sure all scripts & such are executable
RUN chmod +x /usr/local/sbin/*

## Make home dir persistent
VOLUME /home/$UNAME

## Switch user & workdir
USER $UNAME
WORKDIR /home/$UNAME



entrypoint ["/bin/zsh"]

