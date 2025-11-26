# 环境配置目录

这个目录用于管理机器特定的环境变量和配置。

## 文件说明

- **`.env.example`** - 配置模板（进 Git，作为参考）
- **`.env.local`** - 机器特定配置（不进 Git，实际使用）⚠️
- **`.env`** - 备用配置文件（不进 Git）

## 使用方法

### 1. 创建机器特定配置

首次安装时，Ansible 会自动从 `.env.example` 复制创建 `.env.local`：

```bash
cp .env.example .env.local
```

### 2. 编辑配置

填入你的实际 tokens 和机器特定变量：

```bash
vim .env.local
```

示例：
```bash
export OPEN_ROUTER_TOKEN="sk-or-v1-xxxxx"
export FINNHUB_TOKEN="xxxxx"
export TWELVE_DATA_API_KEY="xxxxx"
```

### 3. 配置生效

`.env.local` 会在 `.zshrc` 中自动加载：

```bash
[ -f ~/dev_env/env/.env.local ] && source ~/dev_env/env/.env.local
```

重启终端或运行：
```bash
source ~/.zshrc
```

## 安全提醒

⚠️ **重要**: `.env.local` 和 `.env` 已在 `.gitignore` 中，不会被 Git 追踪。

- ✅ 可以安全地存储 API tokens 和密钥
- ✅ 每台机器独立配置
- ✅ 不会意外提交到 Git

## 多机器管理

不同机器可以有不同的 `.env.local` 配置：

- **开发机器**: 使用测试环境的 tokens
- **生产机器**: 使用生产环境的 tokens
- **个人电脑**: 使用个人账号的 tokens
