# E2E Regression Tests

自动化测试部署完成后的各种情况，使用 Python + Playwright + pytest。

## Quick Start

### 安装依赖

```bash
cd e2e_regressions
uv sync
```

### 运行测试

```bash
# 所有测试
uv run pytest

# 仅运行 smoke 测试（快速）
uv run pytest -m smoke

# 运行特定分类
uv run pytest -m sso      # SSO/Portal 测试
uv run pytest -m platform # Platform 服务测试
uv run pytest -m api      # API 测试
uv run pytest -m database # 数据库测试

# 带详细输出和浏览器可见
uv run pytest -vv --headed

# 生成 HTML 报告
uv run pytest --html=report.html --self-contained-html
```

## 项目结构

```
e2e_regressions/
├── pyproject.toml           # uv 项目配置
├── README.md                # 本文件
├── conftest.py              # pytest fixtures & 全局配置
├── .env.example             # 环境变量模板
└── tests/
    ├── __init__.py
    ├── test_portal_sso.py    # Portal SSO 登录流程
    ├── test_platform.py      # Vault, Dashboard, Casdoor 可用性
    ├── test_api_health.py    # API 端点健康检查
    ├── test_databases.py     # 数据库连接验证
    └── test_e2e_smoke.py     # 整体烟雾测试
```

## 环境配置

复制并填充环境变量：

```bash
cp .env.example .env
```

配置项：

| 变量 | 说明 | 示例 |
|------|------|------|
| `PORTAL_URL` | Portal 主页 URL | `https://home.zitian.party` |
| `SSO_URL` | Casdoor SSO URL | `https://sso.zitian.party` |
| `VAULT_URL` | Vault URL | `https://secrets.zitian.party` |
| `DASHBOARD_URL` | K8s Dashboard URL | `https://kdashboard.zitian.party` |
| `TEST_USERNAME` | 登录用户名 | `test_user` |
| `TEST_PASSWORD` | 登录密码 | `***` |
| `TEST_GITHUB_TOKEN` | GitHub OAuth token | `ghp_***` |
| `VAULT_ADDR` | Vault HTTP API | `https://secrets.zitian.party` |
| `DB_HOST` | PostgreSQL 主机 | `postgresql.data-prod.svc.cluster.local` |
| `DB_PORT` | PostgreSQL 端口 | `5432` |
| `DB_USER` | 数据库用户 | `postgres` |
| `DB_PASSWORD` | 数据库密码 | `***` |
| `REDIS_HOST` | Redis 主机 | `redis.data-prod.svc.cluster.local` |
| `REDIS_PORT` | Redis 端口 | `6379` |
| `CLICKHOUSE_HOST` | ClickHouse 主机 | `clickhouse.data-prod.svc.cluster.local` |
| `CLICKHOUSE_PORT` | ClickHouse 端口 | `8123` |

## 测试分类

### Smoke Tests (快速验证)
- Portal 可访问
- 服务端点响应 200
- 基础连接检查

### SSO Tests
- Portal GitHub OAuth 流程
- 登录后 Session 管理
- 权限检查

### Platform Tests
- Vault 健康检查
- Dashboard 可用性
- Casdoor OIDC 配置验证

### API Tests
- 业务 API 端点
- 认证/授权
- 错误处理

### Database Tests
- PostgreSQL 连接和查询
- Redis 连接和键操作
- ClickHouse 连接和查询

## CI/CD 集成

在 GitHub Actions 中运行（示例）：

```yaml
- name: Run E2E Tests
  run: |
    cd e2e_regressions
    uv sync
    uv run pytest -m smoke --html=report.html
```

## 常见问题

### 浏览器安装
首次运行会自动下载浏览器，或手动安装：
```bash
uv run playwright install chromium
```

### 超时问题
调整 `conftest.py` 中的超时时间：
```python
TIMEOUT = 30000  # ms
```

### 跳过某个测试
```bash
uv run pytest -k "not test_portal_sso"
```

### 生成调试视频
在 conftest.py 中启用：
```python
browser_context_args = {
    "record_video_dir": "test-videos",
}
```

## 维护指南

1. **新增服务**：在对应测试文件中添加健康检查
2. **更新 URL**：修改 `.env` 和相关测试
3. **变更认证方式**：更新 `test_portal_sso.py` 中的登录逻辑
4. **数据库迁移**：更新 `test_databases.py` 中的连接字符串

## 参考

- [Playwright Python 文档](https://playwright.dev/python/)
- [pytest 文档](https://docs.pytest.org/)
- [项目架构](../docs/ssot/core.dir.md)
