#!/bin/bash
# SSH 密钥生成和配置脚本

set -e

HOSTNAME=$(hostname -s)
KEY_NAME="${HOSTNAME}_github"
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/$KEY_NAME"

echo "==================================="
echo "SSH 密钥生成脚本"
echo "==================================="
echo "主机名: $HOSTNAME"
echo "密钥名: $KEY_NAME"
echo ""

# 检查密钥是否已存在
if [ -f "$KEY_PATH" ]; then
    echo "✓ SSH 密钥已存在: $KEY_PATH"
    echo ""
else
    echo "生成新的 SSH 密钥..."
    ssh-keygen -t ed25519 -C "${HOSTNAME}@$(whoami)" -f "$KEY_PATH" -N ""
    echo "✓ SSH 密钥已生成: $KEY_PATH"
    echo ""
fi

# 显示公钥
echo "==================================="
echo "请将以下公钥添加到 GitHub:"
echo "https://github.com/settings/keys"
echo "==================================="
echo ""
cat "${KEY_PATH}.pub"
echo ""
echo "==================================="

# 添加到 ssh-agent
if [ "$(uname)" = "Darwin" ]; then
    eval "$(ssh-agent -s)"
    ssh-add --apple-use-keychain "$KEY_PATH" 2>/dev/null || ssh-add "$KEY_PATH"
    echo "✓ 密钥已添加到 ssh-agent (macOS)"
else
    eval "$(ssh-agent -s)"
    ssh-add "$KEY_PATH"
    echo "✓ 密钥已添加到 ssh-agent"
fi

echo ""
echo "按 Enter 继续（请先添加公钥到 GitHub）..."
# 在非交互环境下直接跳过
if [ -t 0 ]; then
    read -r
else
    echo "[非交互模式] 自动跳过等待"
fi
