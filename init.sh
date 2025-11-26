#!/bin/bash
# dev_env 初始化和安装脚本
# 
# 使用方法 1: 一键安装（在新机器上）
#   curl -fsSL https://raw.githubusercontent.com/wangzitian0/dev_env/main/init.sh | bash
#
# 使用方法 2: 手动安装（已克隆仓库）
#   ./init.sh

set -e

REPO_URL="https://github.com/wangzitian0/dev_env.git"
INSTALL_DIR="$HOME/zitian/dev_env"

# 检测是否通过 curl 执行（没有 git 仓库）
if [ ! -d ".git" ]; then
  echo "=========================================="
  echo "dev_env 一键安装"
  echo "=========================================="
  echo ""
  
  # 检查并安装 Git
  echo ">>> 检查 Git..."
  if ! command -v git &> /dev/null; then
    echo "Git 未安装，正在安装..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      xcode-select --install
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
      sudo apt-get update
      sudo apt-get install -y git
    else
      echo "❌ 不支持的操作系统，请手动安装 Git"
      exit 1
    fi
    echo "✓ Git 安装完成"
  else
    echo "✓ Git 已安装"
  fi
  
  echo ""
  
  # 克隆仓库
  echo ">>> 克隆 dev_env 仓库到 $INSTALL_DIR..."
  if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  目录已存在: $INSTALL_DIR"
    read -p "是否删除并重新克隆？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$INSTALL_DIR"
    else
      echo "安装已取消"
      exit 0
    fi
  fi
  
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO_URL" "$INSTALL_DIR"
  echo "✓ 仓库克隆完成"
  
  echo ""
  
  # 切换到仓库目录并继续安装
  cd "$INSTALL_DIR"
fi

# 以下是原有的 Ansible 安装逻辑
echo "=========================================="
echo "安装 Ansible"
echo "=========================================="
echo ""

# Detect the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: check if Homebrew is installed, then use it to install Ansible
  if ! command -v brew &>/dev/null; then
    echo "Homebrew not found, installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  echo "Installing Ansible via Homebrew..."
  brew install ansible
elif [ -f /etc/lsb-release ]; then
  # Ubuntu: update apt repository and install Ansible
  echo "Updating apt repository..."
  sudo apt-get update
  echo "Installing Ansible via apt-get..."
  sudo apt-get install -y ansible
else
  echo "Unsupported OS"
  exit 1
fi

echo ""
echo "✓ Ansible 安装完成"
echo ""

# 如果是一键安装模式，继续运行 ansible-playbook
if [ ! -d ".git" ] || [ "$1" == "--auto" ]; then
  echo "=========================================="
  echo "运行自动化配置"
  echo "=========================================="
  echo ""
  echo "注意："
  echo "1. 安装过程中会生成 SSH 密钥"
  echo "2. 你需要将公钥添加到 GitHub"
  echo "3. 添加完成后按 Enter 继续"
  echo ""
  read -p "按 Enter 开始..." 
  
  ansible-playbook ansible/setup.yml
  
  echo ""
  echo "=========================================="
  echo "✓ 安装完成！"
  echo "=========================================="
  echo ""
  echo "下一步："
  echo "1. 切换到 SSH URL（推荐）："
  echo "   cd $INSTALL_DIR"
  echo "   git remote set-url origin git@github.com:wangzitian0/dev_env.git"
  echo ""
  echo "2. 配置机器特定变量："
  echo "   vim $INSTALL_DIR/env/.env.local"
  echo ""
  echo "3. 重启终端："
  echo "   exec zsh"
  echo ""
fi
