#!/bin/bash
# 用于私有仓库的最简安装步骤脚本：
# 1) 生成 SSH key（如果需要）并提示添加到 GitHub
# 2) 克隆仓库到 ~/zitian/infra
# 3) 运行 tool_dev/init.sh

set -e

REPO_SSH="git@github.com:wangzitian0/infra.git"
INSTALL_DIR="$HOME/zitian/infra"
KEY_NAME="${KEY_NAME_OVERRIDE:-infra_github}"
KEY_PATH="$HOME/.ssh/$KEY_NAME"

ensure_key() {
  mkdir -p "$HOME/.ssh"
  if [ ! -f "$KEY_PATH" ]; then
    echo "生成 SSH 密钥: $KEY_PATH"
    ssh-keygen -t ed25519 -C "$(hostname -s)_github" -f "$KEY_PATH" -N ""
  else
    echo "复用已有密钥: $KEY_PATH"
  fi
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add "$KEY_PATH"
  echo "请将以下公钥添加到 GitHub (https://github.com/settings/keys)："
  cat "${KEY_PATH}.pub"
  echo ""
  read -p "添加完成后按 Enter 继续克隆..."
}

clone_repo() {
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "仓库已存在：$INSTALL_DIR"
    return
  fi
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO_SSH" "$INSTALL_DIR"
}

run_ansible() {
  cd "$INSTALL_DIR"
  ./tool_dev/init.sh
}

main() {
  ensure_key
  clone_repo
  run_ansible
}

main "$@"
