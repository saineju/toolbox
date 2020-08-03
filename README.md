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
I prefer to use Iterm2 with Solarized Dark -theme and as the container uses Oh-My-Zsh and Powerlevel10, I find it necessary to install Meslo fonts -> https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k

## Building the docker

```
docker build . -t toolbox
``` 

## Usage

#### Linux & MacOS
The dockerfile creates VOLUME for `/home/toolbox`, to ensure that the volume stays persistent between container boots, it's best to create a named volume for the container and use that always

```
docker volume create toolbox
```

And start the box with

```
docker run -v toolbox:/home/toolbox --rm -it toolbox
```

I personally like to share some volumes from my base system, such as git, so to do that, just specify the required mounts during startup:

```
docker run -v toolbox:/home/toolbox -v ${HOME}/git:/home/toolbox/git -v ${HOME}/toolbox:/home/toolbox/shared --rm -it toolbox
```

#### Windows

TBD

## Features

Official cli's, tools an customizations. Most of these should support also tabulator autocomplete
* ZSH shell with oh my zsh & powerlevel9k theme installed by default
* aws cli
* ssm session-manager support for AWS (https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html)
* heroku cli
* gcloud cli
* kubectl
* helm & tiller
* terraform
* ansible
* aws ecs cli
* bitwarden cli
* lastpass cli

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
* Helm & tiller (HELM)
* AWS SSM (AWS_SSM)
* Terraform (TERRAFORM
* AWS ECS cli (AWS_ECSCLI)

To exclude tool, you need to add build-arg to the build command, argument names are mentioned in brackets above, for example

`docker build --build-arg HEROKU=false`

## Installing specific version of a tool

By default latest versions of the tools above are installed, but following tools support installing specific versions

* kubectl (KUBECTLVERSION)
* Terraform (TERRAFORMVERSION)
* Helm (HELMVERSION)

To install specific version of the tools, you need to add build-arg to the build command, argument manes are mentioned in brackets above, for example

`docker build --build-arg TERRAFORM=0.12.11`

* Kubectl is installed with apt, so you may check different versions available with command `apt-cache madison kubectl`
  - Expected format for KUBECTLVERSION is `kubectl=1.6.7-00`
* Terraform is downloaded from Hashicorp, so you may check different versions from https://releases.hashicorp.com/terraform/
  - Expected version format for Terraform is `0.12.12` 
* Helm is installed by downloading release from github, so you may check different versions from https://github.com/helm/helm/releases
  - Expected version format for Helm is `v2.15.2`

## Remote management over SSM

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
