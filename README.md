# dev_env

一键安装跨系统的开发生产环境，支持多机器管理。

## 特性

✅ **完全自动化** - SSH 密钥生成、工具安装、仓库克隆、软链接配置  
✅ **多机器支持** - 机器特定配置独立管理，不进 Git  
✅ **跨平台** - 支持 macOS 和 Linux  
✅ **模块化配置** - 环境配置分离，灵活切换

## 前置准备：GitHub Token（可选）

如果你的仓库是私有的，或者想通过 HTTPS 克隆，需要先生成 GitHub Personal Access Token。

### 生成 GitHub Token

1. 访问 GitHub Settings: https://github.com/settings/tokens
2. 点击 **"Generate new token"** → **"Generate new token (classic)"**
3. 设置：
   - **Note**: 填写描述，如 "dev_env_install"
   - **Expiration**: 选择过期时间（建议 90 days 或 No expiration）
   - **Scopes**: 勾选 `repo` (完整仓库访问权限)
4. 点击 **"Generate token"**
5. **立即复制 token**（只显示一次！）

### 使用 Token 克隆仓库

使用 token 替代密码进行 HTTPS 克隆：

```bash
# 格式：https://<TOKEN>@github.com/<username>/<repo>.git
git clone https://ghp_xxxxxxxxxxxx@github.com/wangzitian0/dev_env.git ~/zitian/dev_env
```

或者在克隆时输入：
- Username: 你的 GitHub 用户名
- Password: 粘贴你的 token（不是 GitHub 密码）

> [!TIP]
> 推荐使用 SSH 密钥而不是 token，更安全且无需管理过期时间。
> 本安装脚本会自动生成 SSH 密钥。

---

## 快速开始

在新机器上运行以下命令即可完成所有配置：

```bash
curl -fsSL https://raw.githubusercontent.com/wangzitian0/dev_env/main/init.sh | bash
```

这将自动完成：
- 📦 安装 Git 和 Ansible
- 📥 克隆 dev_env 仓库到 `~/zitian/dev_env`
- 🔑 生成 SSH 密钥并提示添加到 GitHub
- 🛠️ 安装 oh-my-zsh 及常用插件
- 📁 创建工作目录和软链接
- ⚙️ 初始化配置文件

> [!IMPORTANT]
> 安装过程中会暂停，提示你将 SSH 公钥添加到 GitHub。添加完成后按 Enter 继续。

### 安装完成后

```bash
# 1. 切换到 SSH URL（推荐）
cd ~/zitian/dev_env
git remote set-url origin git@github.com:wangzitian0/dev_env.git

# 2. 配置机器特定变量（可选）
vim ~/zitian/dev_env/env/.env.local

# 3. 重启终端
exec zsh
```

---

## 目录结构

```
~/zitian/dev_env/              # 本仓库（进 Git）
├── .ssh/config                # SSH 配置
├── .zshrc                     # zsh 配置
├── env.shopee.zsh             # Shopee 环境配置
├── env.personal.zsh           # 个人环境配置
├── env/
│   ├── .env.local             # 机器特定配置（不进 Git）⚠️
│   └── .env.example           # 配置模板
├── scripts/
│   └── generate_ssh_key.sh    # SSH 密钥生成脚本
└── ansible/
    ├── setup.yml              # 主安装脚本
    └── vars/repos.yml         # 仓库配置

~/workspace/                   # Shopee 工作项目
~/zitian/                      # 个人项目
```

## 环境配置说明

### 模块化环境配置

在 `.zshrc` 中，环境配置已模块化：

```bash
# Shopee Golang 技术栈
source ~/dev_env/env.shopee.zsh

# 个人 Python 开发环境
source ~/dev_env/env.personal.zsh

# 机器特定配置（不进 Git）
[ -f ~/dev_env/env/.env.local ] && source ~/dev_env/env/.env.local
```

### 在不同环境中切换

只需注释/取消注释对应的 `source` 行即可：

```bash
# 只需要 Shopee 环境
source ~/dev_env/env.shopee.zsh
# source ~/dev_env/env.personal.zsh
```

## 多机器管理

每台机器的特定配置（tokens、路径等）存储在 `env/.env.local`，该文件：
- ✅ 不会被 Git 追踪（已在 `.gitignore` 中）
- ✅ 每台机器独立配置
- ✅ 使用 `.env.example` 作为模板参考

## 已安装组件

运行 `ansible-playbook ansible/setup.yml` 后会自动配置：
- ✅ oh-my-zsh 及常用插件（zsh-autosuggestions, zsh-syntax-highlighting）
- ✅ 开发工具（tree 等）
- ✅ zsh 配置文件软链接
- ✅ SSH 配置软链接
- ✅ 工作目录结构

## IDE 安装

通过 JetBrains Toolbox 安装 Goland / PyCharm：
https://www.jetbrains.com/toolbox-app/

## 故障排除

### SSH 密钥问题

如果 SSH 密钥生成失败，可以手动运行：
```bash
~/zitian/dev_env/scripts/generate_ssh_key.sh
```

### 软链接冲突

如果已有 `~/.zshrc` 或 `~/.ssh`，Ansible 会自动备份为 `.backup.YYYYMMDD_HHMMSS`

### 仓库克隆失败

确保：
1. SSH 密钥已添加到 GitHub/GitLab
2. `ansible/vars/repos.yml` 中的 URL 正确
3. 有相应仓库的访问权限

## License

MIT
