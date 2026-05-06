FROM ubuntu:24.04 AS builder

ARG TERRAFORM=true
ARG TERRAFORMVERSION=latest
ARG HELM=true
ARG HELMVERSION=latest
ARG KUBECTL=true
ARG KUBECTLVERSION=latest
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
ARG VAULTVERSION=latest
ARG AZURE_CLI=true
ARG STARSHIP=true
ARG STARSHIPVERSION=latest
ARG UV=true
ARG UVVERSION=latest
ARG MFAHELPER=true

COPY scripts/ /usr/local/sbin/
COPY aws_pgp_keys/awscli.pgp /tmp/awscli.pgp
COPY requirements.txt /tmp/requirements.txt

SHELL ["/bin/bash","-c"]

RUN apt-get update && apt-get install -y wget curl gnupg unzip jq git dos2unix

## Install helm
RUN [[ "${HELM}" == "true" || "${HELM}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh helm ${HELMVERSION} \
 || true

## Install terraform
RUN [[ "${TERRAFORM}" == "true" || "${TERRAFORM}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh terraform ${TERRAFORMVERSION} \
 || true

## Install hetzner cloud
RUN [[ "${HCLOUD}" == "true" || "${HCLOUD}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh hcloud ${HCLOUDVERSION} \
 || true

## Install bitwarden
RUN [[ "${BITWARDEN}" == "true" || "${BITWARDEN}" == "yes" ]] \
  && bash /usr/local/sbin/get.sh bitwarden ${BITWARDENVERSION} \
  || true

## Install keyvault
RUN [[ "${KEYVAULT}" == "true" || "${KEYVAULT}" == "yes" ]] \
  && bash /usr/local/sbin/get.sh key_vault \
  || true

## Install Starship
RUN [[ "${STARSHIP}" == "true" || "${STARSHIP}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh starship ${STARSHIPVERSION} \
 || true

# Get aws cli mfa helper script
RUN [[ "${MFAHELPER}" == "true" || "${MFAHELPER}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh mfahelper \
 || true

## Install uv
RUN [[ "${UV}" == "true" || "${UV}" == "yes" ]] \
  && bash /usr/local/sbin/get.sh uv ${UVVERSION} \
  || true

## Install AWSCLI v2
RUN [[ "${AWSCLI}" == "true" || "${AWSCLI}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh awscliv2 \
 || true

## Install hashicorp vault
RUN [[ "${VAULT}" == "true" || "${VAULT}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh vault ${VAULTVERSION} \
 || true

## Install kubectl
RUN [[ "${KUBECTL}" == "true" || "${KUBECTL}" == "yes" ]] \
 && bash /usr/local/sbin/get.sh kubectl ${KUBECTLVERSION} \
 || true

FROM ubuntu:24.04

ARG GCLOUD=true
ARG AZURE_CLI=true
ARG AWS_SSM=true
ARG HEROKU=true
ARG UNAME=toolbox
ARG UID=1000
ARG GID=1000
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash","-c"]

## Copy binaries from builder
COPY --from=builder /usr/local/sbin /usr/local/sbin
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy requirements, scripts & configs
COPY requirements.txt /tmp/requirements.txt

## Add any additional CA's as trusted
COPY ./ca_certs/* /usr/local/share/ca-certificates/

## Add signature for 
COPY aws_pgp_keys/aws_ssm.pgp /tmp/aws_ssm.pgp

## Setup base
RUN ln -fs /usr/share/zoneinfo/Europe/Helsinki /etc/localtime \
  && userdel ubuntu \
  && groupadd -g $GID -o $UNAME \
  && useradd -m -u $UID -g $GID -o -s /bin/zsh $UNAME \
  && mkdir -p /home/$UNAME/{.config,.ssh} \
  && chown -R $UNAME:$UNAME /home/$UNAME \
  && chmod og-rwx /home/$UNAME/.ssh \
  && chmod +x /usr/local/sbin/*

## Enable repos, Install updates & required packages
RUN arch=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') \
 && apt-get update \
 && apt-get install -y curl wget gnupg lsb-release apt-transport-https ca-certificates \
 && packages="gnupg-agent python3-minimal python3-pip python3-venv ssh bat fzf eza ripgrep" \
 && packages="$packages zsh git vim nano language-pack-en software-properties-common lsof unzip jq dos2unix" \
 && packages="$packages dnsutils sshpass ncat rsync tzdata jo iputils-ping jc neovim python3-neovim" \
 && packages="$packages krb5-user proxychains-ng bsdmainutils libcap2" \
 && if [[ "${GCLOUD}" == "true" || "${GCLOUD}" == "yes" ]]; then \
   bash /usr/local/sbin/get.sh gcloud; \
   packages="$packages google-cloud-sdk";\
   fi \
 && if [[ "${AZURE_CLI}" == "true" || "${AZURE_CLI}" == "yes" ]]; then \
   bash /usr/local/sbin/get.sh azure; \
   packages="$packages azure-cli"; \
   fi \
 && if [[ "$AWS_SSM" == "true" || "$AWS_SSM" == "yes" ]]; then \
   bash /usr/local/sbin/get.sh ssm; \
   fi \
 && if [[ "$HEROKU" == "true" || "$HEROKU" == "yes" ]]; then \
   bash /usr/local/sbin/get.sh heroku; \
   packages="$packages heroku"; \
   fi \
 && apt-get update \
 && apt-get -y upgrade \
 && apt-get install -y --no-install-recommends $packages \
 && uv venv /opt/toolbox \
 && uv pip install --python /opt/toolbox/bin/python -r /tmp/requirements.txt \
 && update-ca-certificates \
 && if [ -f /usr/local/sbin/vault ]; then \
   setcap cap_ipc_lock= /usr/local/sbin/vault; \
   fi \
 && rm -f /tmp/requirements.txt \
 && dpkg-reconfigure --frontend noninteractive tzdata \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

## Make home dir persistent
VOLUME /home/$UNAME

## Switch user & workdir
USER $UNAME
WORKDIR /home/$UNAME

ENTRYPOINT ["/bin/zsh"]
