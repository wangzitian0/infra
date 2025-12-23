# E2E 测试框架 - 设置指南

## 📋 项目概览

这是一个为 **codex_infra** 设计的端到端自动化测试框架，用于自动化部署完成后的验证。

**关键特点**：
- ✅ **42 个测试用例**，覆盖 Portal、Platform、API、数据库
- ⚡ **烟雾测试** 1-2 分钟快速验证
- 🎭 **Playwright + Python**，支持浏览器自动化 + API 测试
- 📦 **uv 管理依赖**，确保可重现性
- 🔄 **CI/CD 就绪**，GitHub Actions 工作流配置示例已包含

---

## 🚀 快速开始（5 分钟）

### 1️⃣ 安装依赖

```bash
cd e2e_regressions

# 使用 uv 安装（自动生成 uv.lock）
uv sync

# 安装浏览器驱动
uv run playwright install chromium
```

### 2️⃣ 配置环境

```bash
# 复制模板
cp .env.example .env

# 编辑 .env，至少填入这些：
# PORTAL_URL=https://home.zitian.party
# SSO_URL=https://sso.zitian.party
# VAULT_URL=https://secrets.zitian.party
# DASHBOARD_URL=https://kdashboard.zitian.party
```

### 3️⃣ 运行测试

```bash
# 烟雾测试（推荐先跑）
make test-smoke

# 或使用脚本
./run_tests.sh smoke
```

---

## 📁 项目结构

```
e2e_regressions/
│
├── 📄 核心配置
│   ├── pyproject.toml          # uv 项目配置
│   ├── pytest.ini              # pytest 配置
│   ├── conftest.py             # 全局 fixtures
│   ├── .env.example            # 环境变量模板
│   └── .gitignore              # Git 忽略规则
│
├── 📚 文档
│   ├── README.md               # 完整文档（必读）
│   ├── QUICK_START.md          # 快速入门（5 分钟）
│   ├── ARCHITECTURE.md         # 架构设计
│   ├── TESTING_STRATEGY.md     # 测试策略
│   └── SETUP_GUIDE.md          # 本文件
│
├── 🛠️ 工具
│   ├── Makefile                # 常用命令
│   ├── run_tests.sh            # 测试运行脚本
│   └── .github-workflow-example.yml  # CI/CD 模板
│
└── 🧪 测试文件
    └── tests/
        ├── test_portal_sso.py       # SSO/Portal 测试（7 个）
        ├── test_platform.py         # Platform 服务（7 个）
        ├── test_api_health.py       # API 健康检查（10 个）
        ├── test_databases.py        # 数据库连接（9 个）
        └── test_e2e_smoke.py        # E2E 烟雾测试（9 个）

共 42 个测试用例
```

---

## 🎯 使用方式

### 方式 1: 使用 Makefile（推荐）

```bash
make help                # 查看所有命令

make install            # 安装依赖
make test-smoke         # 快速烟雾测试（1-2 分钟）
make test-sso           # SSO/Portal 测试（3-5 分钟）
make test-platform      # Platform 服务测试（2-3 分钟）
make test-api           # API 健康测试（2-3 分钟）
make test-database      # 数据库测试（3-5 分钟）
make test               # 全部测试（15-25 分钟）

make test-headed        # 可见浏览器运行
make test-debug         # 调试模式
make report             # 生成 HTML 报告
make clean              # 清理临时文件
```

### 方式 2: 使用脚本

```bash
./run_tests.sh smoke                # 烟雾测试
./run_tests.sh sso --headed         # SSO 测试 + 可见浏览器
./run_tests.sh all --report         # 全部测试 + 报告
./run_tests.sh install              # 安装依赖
```

### 方式 3: 直接用 pytest

```bash
uv run pytest                       # 全部测试
uv run pytest -m smoke              # 按标签运行
uv run pytest tests/test_portal_sso.py  # 特定文件
uv run pytest -k test_portal_accessible # 特定函数
```

---

## 🔧 配置详解

### 环境变量（.env）

**必配项**（至少这些）：
```bash
PORTAL_URL=https://home.zitian.party
SSO_URL=https://sso.zitian.party
VAULT_URL=https://secrets.zitian.party
DASHBOARD_URL=https://kdashboard.zitian.party
```

**可选项**（用于 SSO 和数据库测试）：
```bash
TEST_USERNAME=your_username
TEST_PASSWORD=your_password

DB_HOST=postgresql.data-prod.svc.cluster.local
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password

REDIS_HOST=redis.data-prod.svc.cluster.local
REDIS_PORT=6379

CLICKHOUSE_HOST=clickhouse.data-prod.svc.cluster.local
CLICKHOUSE_PORT=8123
```

**高级配置**：
```bash
HEADLESS=true           # false 显示浏览器
TIMEOUT_MS=30000        # 超时时间（毫秒）
SLOW_MO=0               # 操作延迟（毫秒）
```

---

## 📊 测试分类

| 类别 | 耗时 | 何时运行 | 命令 |
|------|------|--------|------|
| **Smoke** | 1-2 min | 部署直后 | `make test-smoke` |
| **SSO** | 3-5 min | 验证 Portal 登录 | `make test-sso` |
| **Platform** | 2-3 min | 验证 Platform 服务 | `make test-platform` |
| **API** | 2-3 min | 验证 API 端点 | `make test-api` |
| **Database** | 3-5 min | 验证数据库连接 | `make test-database` |
| **E2E** | 5-10 min | 完整验证 | `make test-e2e` |
| **All** | 15-25 min | 最终验证 | `make test` |

---

## 🔍 常见场景

### 场景 1: 部署刚完成，快速检查

```bash
make test-smoke
# 预期: 全部通过 ✓
```

### 场景 2: 想看浏览器操作过程

```bash
make test-headed
# 会在浏览器中看到实时操作
```

### 场景 3: 调试登录流程

```bash
HEADLESS=false uv run pytest tests/test_portal_sso.py::test_portal_password_login -s
# 可见浏览器 + 显示 print 输出
```

### 场景 4: 数据库连接失败

```bash
uv run pytest tests/test_databases.py -vv
# 详细输出，查看具体错误
```

### 场景 5: 生成测试报告

```bash
make report
# 生成 report.html，在浏览器打开
```

---

## 🐛 故障排除

### ❌ 浏览器启动失败

```bash
# 重新安装浏览器
uv run playwright install chromium --with-deps
```

### ❌ 超时错误

```bash
# 增加超时时间
TIMEOUT_MS=60000 make test-smoke
```

### ❌ SSL 证书错误

```bash
# 已自动配置忽略自签名证书
# 如果仍有问题，检查 conftest.py 中的 ignore_https_errors=True
```

### ❌ 数据库连接失败

```bash
# 检查 .env 中的连接信息
echo $DB_HOST $DB_PORT $DB_USER

# 在 Pod 中测试连接
kubectl run -it --rm debug --image=postgres:latest -- \
  psql -h $DB_HOST -U $DB_USER -c "SELECT 1"
```

### ❌ 找不到 uv 命令

```bash
# 安装 uv（如果还没有）
curl -LsSf https://astral.sh/uv/install.sh | sh

# 或用 pip（如果有 Python）
pip install uv
```

---

## 🚀 CI/CD 集成

### GitHub Actions 设置

1. **复制工作流文件**：
   ```bash
   cp .github-workflow-example.yml ../.github/workflows/e2e-tests.yml
   ```

2. **在 GitHub 仓库中添加 Secrets**：
   - `PORTAL_URL`
   - `SSO_URL`
   - `VAULT_URL`
   - `DASHBOARD_URL`
   - `TEST_USERNAME`
   - `TEST_PASSWORD`
   - 数据库相关（可选）

3. **工作流会自动触发**：
   - 推送到 main 分支
   - 创建 PR
   - 每 6 小时自动运行一次

### 本地 CI 模拟

```bash
# 在本地运行 CI 工作流
act -j smoke-tests
```

---

## 📖 文档导航

| 文档 | 适合人群 | 内容 |
|------|---------|------|
| **README.md** | 所有人 | 完整文档和 API 参考 |
| **QUICK_START.md** | 快速开始 | 5 分钟上手指南 |
| **SETUP_GUIDE.md** | 本文件 | 详细设置和场景 |
| **ARCHITECTURE.md** | 开发者 | 项目架构和 fixtures |
| **TESTING_STRATEGY.md** | 维护者 | 测试策略和故障排查 |

---

## ✅ 设置检查清单

使用本清单验证设置是否正确：

- [ ] `uv sync` 完成，依赖已安装
- [ ] Playwright 浏览器已安装
- [ ] `.env` 文件已创建且配置正确
- [ ] `make test-smoke` 能运行并全部通过
- [ ] 能看到 HTML 报告（`make report`）
- [ ] （可选）CI/CD 工作流已配置

---

## 🎓 下一步

1. **快速验证**：`make test-smoke`
2. **浏览文档**：阅读 [README.md](README.md)
3. **理解架构**：阅读 [ARCHITECTURE.md](ARCHITECTURE.md)
4. **配置 CI/CD**：复制 `.github-workflow-example.yml`
5. **添加自定义测试**：在 `tests/` 目录中新建文件

---

## 💡 提示

- 🔄 **Makefile 最友好**：`make help` 查看所有命令
- 🚀 **烟雾测试最快**：1-2 分钟看到关键问题
- 📊 **报告最直观**：`make report` 生成 HTML 报告
- 🔧 **Headless 调试**：`make test-headed` 看浏览器操作
- 🐍 **pytest 最灵活**：直接用 pytest 运行特定测试

---

## 📞 支持

遇到问题？

1. 查看 [README.md](README.md) 的常见问题部分
2. 查看 [TESTING_STRATEGY.md](TESTING_STRATEGY.md) 的故障诊断
3. 检查 `.env.example` 确保环境变量正确
4. 运行 `make clean` 清理临时文件再重试

---

**准备好了吗？现在就运行**：

```bash
make test-smoke
```

祝你测试顺利！🎉
