# workspace_shopee specific aliases/env

# Shopee 工作目录别名
alias hehe="cd /Users/SP14016/workspace/heheda-main"
alias work="cd /Users/SP14016/workspace"
alias sr="spkit run "

# Shopee Golang 技术栈（如需额外配置可在此继续）
source ~/dev_env/env.shopee.zsh

# Golang 环境配置
export PATH="/usr/local/opt/go@1.19/bin:$PATH"
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Shopee 私有仓库配置
export GOPRIVATE='git.garena.com'
export ENV='test'
