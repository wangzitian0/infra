# Quick Start Guide

## 一分钟快速开始

### 1. 初始化项目

```bash
cd e2e_regressions

# 安装依赖（生成 uv.lock）
uv sync

# 安装浏览器驱动
uv run playwright install chromium
```

### 2. 配置环境

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env，填入你的实际地址和凭证
# 关键配置：
# - PORTAL_URL=https://home.zitian.party
# - TEST_USERNAME=your_user
# - TEST_PASSWORD=your_password
```

### 3. 运行测试

```bash
# 快速烟雾测试（推荐先跑这个）
uv run pytest -m smoke -v

# 或使用 Makefile
make test-smoke
```

## 使用 Makefile（推荐）

```bash
# 查看所有可用命令
make help

# 安装依赖
make install

# 运行各类测试
make test-smoke        # 烟雾测试（快速）
make test-sso          # SSO/Portal 测试
make test-platform     # Platform 服务测试
make test-database     # 数据库测试
make test              # 全部测试

# 调试模式（显示浏览器、更详细的输出）
make test-headed       # 可见浏览器运行
make test-debug        # 详细模式 + 慢速执行

# 生成报告
make report
```

## 直接使用 pytest

```bash
# 所有测试
uv run pytest

# 按标签运行
uv run pytest -m smoke       # 烟雾测试
uv run pytest -m sso         # SSO 测试
uv run pytest -m platform    # 平台服务
uv run pytest -m api         # API 测试
uv run pytest -m database    # 数据库测试

# 详细输出 + 显示浏览器
uv run pytest -vv --headed

# 仅运行某个测试文件
uv run pytest tests/test_portal_sso.py -v

# 仅运行某个测试函数
uv run pytest tests/test_portal_sso.py::test_portal_accessible -v

# 显示 print 输出
uv run pytest -s

# 失败时停止
uv run pytest -x

# 生成 HTML 报告
uv run pytest --html=report.html --self-contained-html
```

## 常见场景

### 场景 1：部署完成后验证

```bash
# 快速检查所有关键服务是否可访问（~1-2 分钟）
make test-smoke

# 如果烟雾测试通过，尝试全量测试
make test
```

### 场景 2：调试单个测试

```bash
# 用可见浏览器运行，查看实际操作
HEADLESS=false uv run pytest tests/test_portal_sso.py::test_portal_accessible -s

# 或通过 Makefile
make test-headed
```

### 场景 3：检查 SSO 登录流程

```bash
# 确保 TEST_USERNAME 和 TEST_PASSWORD 在 .env 中配置
make test-sso
```

### 场景 4：检查数据库连接

```bash
# 确保数据库凭证在 .env 中配置
make test-database
```

## 环境变量配置

最小配置（只需这些）：

```bash
PORTAL_URL=https://home.zitian.party
SSO_URL=https://sso.zitian.party
VAULT_URL=https://secrets.zitian.party
DASHBOARD_URL=https://kdashboard.zitian.party
```

可选配置（用于 SSO 和数据库测试）：

```bash
TEST_USERNAME=your_username
TEST_PASSWORD=your_password
DB_HOST=postgresql.data-prod.svc.cluster.local
DB_PASSWORD=your_db_password
REDIS_HOST=redis.data-prod.svc.cluster.local
CLICKHOUSE_HOST=clickhouse.data-prod.svc.cluster.local
```

## 故障排除

### 问题：浏览器启动失败
```bash
# 重新安装浏览器驱动
uv run playwright install chromium --with-deps
```

### 问题：超时（服务响应慢）
```bash
# 增加超时时间
TIMEOUT_MS=60000 uv run pytest -m smoke
```

### 问题：SSL/TLS 证书错误
```bash
# 我们已经配置忽略自签名证书，通常不需要处理
# 如果仍有问题，检查 conftest.py 中的 ignore_https_errors=True
```

### 问题：数据库连接失败
```bash
# 检查连接字符串
# PostgreSQL 应该可访问：postgresql://user:pass@host:port/db
# Redis 应该可访问：redis://host:port
# 在 CI 中可能需要使用 port-forward
```

## CI/CD 集成

### GitHub Actions

1. 复制工作流文件：
```bash
cp .github-workflow-example.yml ../.github/workflows/e2e-tests.yml
```

2. 在 GitHub 仓库中添加以下 Secrets：
```
PORTAL_URL
SSO_URL
VAULT_URL
DASHBOARD_URL
TEST_USERNAME
TEST_PASSWORD
DB_HOST
DB_PASSWORD
REDIS_HOST
CLICKHOUSE_HOST
```

3. 工作流会在以下情况触发：
- 推送到 main 分支
- 创建 PR
- 每 6 小时自动运行一次（烟雾测试）

## 测试覆盖范围

| 类别 | 耗时 | 测试项目 |
|------|------|---------|
| **烟雾** | 1-2 分钟 | 所有服务可访问 |
| **SSO** | 3-5 分钟 | Portal 登录、Casdoor OIDC |
| **Platform** | 2-3 分钟 | Vault、Dashboard、Casdoor API |
| **API** | 2-3 分钟 | 端点响应、头部、重定向 |
| **数据库** | 3-5 分钟 | PostgreSQL、Redis、ClickHouse 连接 |
| **E2E** | 5-10 分钟 | 完整流程验证 |

## 下一步

- 查看 [README.md](README.md) 了解完整文档
- 查看测试文件了解具体测试逻辑
- 在项目中 pin 特定 pytest 版本或 Playwright 版本：编辑 `pyproject.toml`
- 添加自定义测试：在 `tests/` 目录中创建新文件
