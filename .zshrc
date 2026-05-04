## Environment
export LANG=en_US.UTF-8
export TERM="xterm-256color"
export EDITOR='nano'

## History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

## Completion
autoload -Uz compinit && compinit
autoload -Uz bashcompinit && bashcompinit
zstyle ':completion:*' menu select

## Python venv (activate before tool completions that may need it)
export PATH=/opt/toolbox/bin:$PATH

## Tool completions
command -v kubectl        &>/dev/null && source <(kubectl completion zsh)
command -v helm           &>/dev/null && source <(helm completion zsh)
command -v hcloud         &>/dev/null && source <(hcloud completion zsh)
command -v vault          &>/dev/null && complete -o nospace -C vault vault
command -v terraform      &>/dev/null && complete -o nospace -C terraform terraform
command -v aws_completer  &>/dev/null && complete -C aws_completer aws
command -v heroku         &>/dev/null && source <(heroku autocomplete --shell zsh 2>/dev/null)
command -v ansible        &>/dev/null && eval "$(register-python-argcomplete ansible)"
command -v ansible-playbook &>/dev/null && eval "$(register-python-argcomplete ansible-playbook)"

## Gcloud
[[ -f /usr/share/google-cloud-sdk/completion.zsh.inc ]] \
  && source /usr/share/google-cloud-sdk/completion.zsh.inc

## SSH agent
[[ -f $HOME/.ssh/ssh-agent ]] || ssh-agent > $HOME/.ssh/ssh-agent
source $HOME/.ssh/ssh-agent

## Aliases
alias describe-instances="describe.py instances"
alias describe-services="describe.py services"
alias describe-account="describe.py account"
alias start-session="aws ssm start-session"

## Starship prompt
eval "$(starship init zsh)"
