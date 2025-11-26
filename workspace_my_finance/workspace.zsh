# workspace_my_finance specific aliases/env

# 个人环境（示例：原 env.personal.zsh）
source ~/dev_env/env.personal.zsh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
export PATH="/Users/SP14016/.pixi/bin:$PATH"

if [[ "$(uname -m)" == "arm64" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

alias ibrew='arch -x86_64 /usr/local/bin/brew'

# P3 Command Completion (Unified)
source /Users/SP14016/zitian/my_finance/infra/scripts/p3/p3-completion.zsh
export PATH="/Users/SP14016/zitian/my_finance:$PATH"

export PATH="$PATH:/Users/SP14016/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
export NODE_OPTIONS="--max-old-space-size=8192"

# Secrets/keys 请放在 workspace_my_finance/.env.local（不提交）
# export OPEN_ROUTER_TOKEN="..."
# export FINNHUB_TOKEN="..."
# export TWELVE_DATA_API_KEY="..."

export PATH="/opt/homebrew/bin:$PATH"
# export PATH="$HOME/.local/bin:$PATH" # Duplicate

# Added by Antigravity
export PATH="/Users/SP14016/.antigravity/antigravity/bin:$PATH"
