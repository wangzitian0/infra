#!/bin/bash
#!/bin/bash
# infra tool_dev 初始化脚本：只做两件事
# 1) 安装 Ansible（若未安装）
# 2) 运行 tool_dev/ansible/setup.yml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ensure_ansible() {
  if command -v ansible >/dev/null 2>&1; then
    return
  fi
  echo "Installing Ansible..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install ansible
  elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
    sudo apt-get update && sudo apt-get install -y ansible
  else
    echo "Unsupported OS, please install Ansible manually."
    exit 1
  fi
}

main() {
  ensure_ansible
  ansible-playbook "$REPO_ROOT/tool_dev/ansible/setup.yml" --ask-become-pass
}

main "$@"
