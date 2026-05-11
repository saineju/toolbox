# Toolbox

A docker containing a bunch of custom made / official cli's and tools. The intention is to remove the need to install a bunch of python tools etc to your local machine and at the same time offer similar set of tools to all users regardless of their chosen OS.

## Prerequisites
NOTE: I use mainly MacOS, so other OS' are somewhat untested

You need to have docker installed. It is recommendable to prefer official docker images:

* Ubuntu: https://docs.docker.com/install/linux/docker-ce/ubuntu/
* MacOS: https://docs.docker.com/docker-for-mac/install/
* Windows: https://docs.docker.com/docker-for-windows/install/

For more information: https://docs.docker.com/docker-for-windows/install/

### MacOS specific
I prefer to use Solarized Dark -theme and as the container uses starship, I find it necessary to install nerd fonts -> https://www.nerdfonts.com/font-downloads (I prefer MesloLG)

## Usage
Copy the docker-compose.example.yml to docker-compose.yml and modify to your likings, you may for example want to pin tool version numbers or disable some tools you don't need.
Optionally build before starting the container

```
docker compose build
``` 

After building just start the toolbox to background

```
docker compose up -d
```

Enter the toolbox with toolbox -script or by executing

```
docker compose exec toolbox zsh
```

By default the docker compose creates persistent home directory and mounts .zshrc and starship configuration toml from the local directory
There are three default starship themes exported to starship directory, gruvbox-rainbow being the default, but you can change it as you please

## Firewalled version
Optionally you may want to limit / observe your traffic to prevent unexpected traffic, for this you may use the docker-compose-with-firewall.yml.example 
instead of the normal docker-compose.yml.example. Both work similarly, but the firewalled version contains nft tables and squid to limit outbound
access from the containers. The firewall also contains openvpn and openconnec vpn's for VPN needs.

By default the firewall / squid will allow outbound access to ports 22, 80 and 443. The firewall container also exposes socks proxy in port 1080 and
squid port to localhost, that can be used with for example firefox multi account containers.

VPN Connectivity can be utilized with using `docker compose exec firewall_vpn sudo /scripts/start_vpn.sh [openvpn|openconnect]`. 
Openvpn expects to find /openvpn/ovpn.ovpn config and asks for password and username, Openconnect will ask for connection url as well. 
The container also supports environment variables for the configuration settings

* VPN_USER - User for vpn connection
* OPENCONNECT_URL - Url for open connect
* ASK_OTP - Ask for OTP code if such is needed
* OPENVPN_CONFIG_PATH - Alternate path for ovpn.conf

## Features

Official cli's, tools an customizations. Most of these should support also tabulator autocomplete
* ZSH shell with starship prompt installed by default
* ansible

Optionally, can be switched with environment arguments in the compose file. By default all are enabled.

* aws cli
* ssm session-manager support for AWS (https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html)
* heroku cli
* gcloud cli
* kubectl
* helm
* terraform
* bitwarden cli (only amd64)
* azure cli
* hetzner cloud cli

My personal scripts to make my life a bit easier:
* helper script for parsing AWS cli (parse_aws_creds.py)
* helper script for AWS cli MFA (https://github.com/saineju/awscli_mfa)
* key_vault.sh for storing and retrieving keys from supported password vaults (https://github.com/saineju/modular_key_vault)
* ssh config configured to enable SSH over SSM for all hosts managed hosts (use ssh <machine-id>)
* Handy aliases
  - describe-instances
  - describe-services
  - describe-account
  - start-session (requires --target <machine-id> as well as --region and --profile)

## Excluding official cli's during build

By default all cli's mentioned above are installed during build, but if you wish, you may exclude following

* heroku cli (HEROKU)
* gcloud cli (GCLOUD)
* kubectl (KUBECTL)
* Helm (HELM)
* AWS SSM (AWS_SSM)
* Terraform (TERRAFORM
* Azure cli (AZURE_CLI)
* Hetzner cloud cli (HCLOUD)
* Terraform (TERRAFORM)
* Starship (STARSHIP)
* Uv (UV)

You can also exlude my tools

* Modular Key vault (KEYVAULT)
* MFA helper (MFAHELPER)

To exclude tool, you need to change the variable to 'false' in the compose file

## Installing specific version of a tool

By default latest versions of the tools above are installed, but following tools support installing specific versions

* kubectl (KUBECTLVERSION)
* Terraform (TERRAFORMVERSION)
* Helm (HELMVERSION)
* Vault (VAULTVERSION)
* Terraform (TERRAFORMVERSION)
* Kubectl (KUBECTLVERSION)
* Hetzner cloud (HCLOUDVERSION)
* Bitwarden (BITWARDENVERSION)
* Starship (STARSHIPVERSION)
* Uv (UVVERSION)

To install specific version of the tools, you need to change the variable to specific version in the compose file, for example

`TERRAFORMVERSION=0.12.11`

The expected version format is always without 'v' in front to unify the approach. The downloader script adds it if needed.

SSM can be used to start interactice shell sessions to any hosts that have SSM enabled. You can see SSM status on machines with `describe-instances` -command.

The main advantages of SSM instead of SSH are that the connections are logged fully to cloudwatch, so auditing what has been done to a specific host and by whom becomes
really easy compared to SSH, even if there is one account that everyone shares. Also the access is granted on AWS account basis, so creating individual users to hosts
is not necessary. Also you can start session from either AWS console (Systems Manager -> Managed instances -> start session), or you can use aws cli with SSM module (already
installed in this toolbox) with command `start-session --target <machine id> --profile <your profile> --region <correct region>`. The `start-session` -command is just an alias for
`aws ssm start-session`.

Limitations for SSM are that you are not able to transfer files over it directly and you can not do full port forwarding over it, while forwarding port to the specific
machine itself works, it does not allow forwarding port to another host in the network and that is where the SSH over SSM comes handy.

### SSH connections over SSM

SSH connections over SSM work in similar matter as regular SSH connections, but they just use SSM as their connection medium.

So what does this mean in practice?

* First and foremost you need to have permission in AWS environment to use SSM
* You need to have an account with your SSH key on the server as you would on other SSH hosts (you don't necessarily need to have personal account, as long as your key is there)

Documentation for the process can be found from [here](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html)

The toolbox has already a built in support for the SSH, so you should be able to just start ssh connection as you would, just using the machine id as your SSH target:

`ssh <machine id> -i <path to your ssh-key> -l <your username>`

This will ask for aws account profile name and region, unless you have already set environment variables `AWS_PROFILE` and `AWS_DEFAULT_REGION`

## toolbox script
Toolbox script is intended for an easy wrapper to either start a new container or connect to an existing container running on the machine
