# E2E Regression Tests Architecture

## 项目结构

```
e2e_regressions/
├── pyproject.toml                 # uv 项目配置 + 依赖定义
├── pytest.ini                     # pytest 配置
├── uv.lock                        # 锁定的依赖版本（自动生成）
├── .env.example                   # 环境变量模板
├── .gitignore                     # Git 忽略规则
│
├── README.md                      # 完整文档（维护者必读）
├── QUICK_START.md                 # 快速开始指南
├── ARCHITECTURE.md                # 本文件
│
├── Makefile                       # 常用命令快捷方式
├── run_tests.sh                   # 测试运行脚本
├── .github-workflow-example.yml   # GitHub Actions 工作流模板
│
├── conftest.py                    # pytest 全局配置和 fixtures
│
└── tests/
    ├── __init__.py
    ├── test_portal_sso.py         # SSO/Portal 测试（7 个测试）
    ├── test_platform.py           # Platform 服务测试（7 个测试）
    ├── test_api_health.py         # API 健康检查（10 个测试）
    ├── test_databases.py          # 数据库连接测试（9 个测试）
    └── test_e2e_smoke.py          # E2E 烟雾测试（9 个测试）

Total: 42 test cases
```

## 依赖关系

```
pyproject.toml (uv 定义)
    ├── pytest 7.4.3          # 测试框架
    ├── pytest-asyncio 0.21   # 异步支持
    ├── playwright 1.40       # 浏览器自动化
    ├── pydantic 2.5          # 数据验证
    ├── httpx 0.25            # HTTP 客户端
    ├── psycopg2-binary       # PostgreSQL 驱动
    ├── redis 5.0             # Redis 客户端
    └── python-dotenv         # 环境变量加载

↓ uv sync 生成

uv.lock (锁定版本，确保可重现性)

↓ CI/GitHub Actions 自动管理
```

## 测试分类和执行流程

### 按运行耗时分类

```
快速层 (< 5 min)
├── 烟雾测试 (1-2 min)
│   └── 关键服务可访问性检查
│
标准层 (3-10 min)
├── SSO 测试 (3-5 min)
│   └── Portal 登录流程
├── Platform 测试 (2-3 min)
│   └── Vault/Dashboard/Casdoor API
├── API 测试 (2-3 min)
│   └── 端点响应、重定向、头部
└── 数据库测试 (3-5 min)
    └── PG/Redis/ClickHouse 连接

完整层 (5-10 min)
└── E2E 测试
    └── 跨层验证、性能基线、恢复测试
```

### 执行决策树

```
用户运行测试
├── make help
│   └── 显示所有命令
├── make test-smoke
│   ├── 检查所有关键服务可访问
│   └── 5 个并发 HTTP 请求
├── make test-sso
│   ├── Portal 页面加载
│   ├── OIDC 发现端点
│   ├── SSO 登录表单
│   └── 响应式设计验证
├── make test-platform
│   ├── Vault API (/v1/sys/health)
│   ├── Dashboard 访问
│   ├── Casdoor API (/api/get-orgs)
│   └── 浏览器 UI 加载测试
├── make test-api
│   ├── HTTP 连接性
│   ├── 响应时间测试
│   ├── SSL 证书验证
│   ├── 错误页面处理
│   └── CORS 头部验证
├── make test-database
│   ├── PostgreSQL 连接
│   ├── PostgreSQL 查询性能
│   ├── Redis SET/GET
│   ├── ClickHouse HTTP 查询
│   └── 数据库写权限检查
└── make test (or make test-e2e)
    └── 运行全部 42 个测试
```

## 配置管理

### 环境变量链

```
.env.example (Git 跟踪)
    │
    ├─→ 用户复制和修改
    │
    └─→ .env (Git 忽略)
            │
            ├─→ conftest.py 加载
            │
            └─→ 注入到 pytest fixtures
                    ├─→ config fixture
                    ├─→ page fixture (Playwright)
                    ├─→ browser fixture
                    └─→ db_connection_string
```

### 环境优先级

```
1. .env 文件（本地开发）
2. GitHub Secrets（CI/CD）
3. pyproject.toml 中的默认值（后备）
```

## Fixtures 架构

```
conftest.py
├── TestConfig
│   ├── 读取所有环境变量
│   └── 提供默认值
│
├── @fixture config
│   └── 全局配置对象
│
├── @fixture browser
│   ├── 启动 Chromium
│   ├── 配置：headless, slowMo, timeout
│   └── 关闭清理
│
├── @fixture context
│   ├── 创建 BrowserContext
│   ├── 配置：viewpoint, 忽略 HTTPS 错误
│   └── 关闭清理
│
├── @fixture page
│   ├── 创建 Page 对象
│   ├── 设置默认超时
│   └── 关闭清理
│
├── @fixture db_connection_string
│   └── 返回 PostgreSQL 连接字符串
│
└── @fixture redis_connection_string
    └── 返回 Redis 连接字符串
```

## 测试标记 (Markers)

```
@pytest.mark.smoke
└── 快速可访问性检查，通常 < 5 min

@pytest.mark.sso
└── Portal 登录流程和 OIDC 测试

@pytest.mark.platform
└── Vault、Dashboard、Casdoor 服务测试

@pytest.mark.api
└── HTTP API 端点和头部测试

@pytest.mark.database
└── 数据库连接和查询测试

@pytest.mark.e2e
└── 完整端到端场景测试
```

## 测试模式

### 1. 断言驱动 (Assertion-Driven)

```python
# test_api_health.py
async def test_vault_is_accessible(config: TestConfig):
    response = await client.get(f"{config.VAULT_URL}/v1/sys/health")
    assert response.status_code in [200, 429, 473, 501]
```

### 2. 页面交互 (UI-Driven)

```python
# test_portal_sso.py
async def test_portal_password_login(page: Page, config: TestConfig):
    await page.goto(config.PORTAL_URL)
    await page.fill("input[type='password']", config.TEST_PASSWORD)
    await page.click("button[type='submit']")
```

### 3. 数据库连接 (Connection-Based)

```python
# test_databases.py
conn = psycopg2.connect(
    host=config.DB_HOST,
    port=config.DB_PORT,
    # ...
)
cursor.execute("SELECT version()")
```

## CI/CD 集成

### GitHub Actions 工作流

```yaml
.github/workflows/e2e-tests.yml
├── 触发条件
│   ├── 推送到 main
│   ├── 创建 PR
│   └── 每 6 小时自动运行（烟雾测试）
│
├── smoke-tests 任务 (必需)
│   ├── 运行: make test-smoke
│   └── 超时: 10 分钟
│
├── platform-tests 任务 (可选)
│   ├── 运行: make test-platform
│   └── 跳过: 定时运行时
│
├── sso-tests 任务 (可选)
│   ├── 运行: make test-sso
│   └── 跳过: 定时运行时
│
├── database-tests 任务 (可选)
│   ├── 运行: make test-database
│   └── 需要 DB_* secrets
│
└── test-report 任务
    ├── 生成 HTML 报告
    └── 上传为工件 (30 天保留)
```

## 错误处理策略

### 浏览器超时

```
┌─ TIMEOUT_MS (conftest.py) ──────────────────────┐
│ 默认: 30000ms (30秒)                              │
│ 可配置: TIMEOUT_MS=60000 make test-smoke         │
│ 影响: page.goto(), click(), fill() 等操作        │
└──────────────────────────────────────────────────┘
```

### HTTP 超时

```
┌─ httpx timeout ──────────────────────────────────┐
│ 默认: 10秒 (简单检查)                             │
│ 长: 30秒 (复杂查询、性能基线)                     │
│ 调整: 修改 test_*.py 中的 timeout 参数           │
└──────────────────────────────────────────────────┘
```

### SSL 证书验证

```python
# 配置: conftest.py
async with httpx.AsyncClient(verify=False):  # 接受自签名证书
    pass

# 浏览器配置: conftest.py
context = await browser.new_context(
    ignore_https_errors=True  # 忽略 HTTPS 错误
)
```

## 性能考虑

### 并发度

- Playwright: 单线程（async 版本）
- HTTP 请求: 可并发（使用 httpx AsyncClient）
- 数据库: 单连接（可扩展为连接池）

### 资源使用

```
内存:
├── Playwright 浏览器实例: ~200-300 MB
├── 单个 Page 对象: ~50-100 MB
└── Python 进程: ~100-150 MB
   总计: ~350-550 MB

磁盘:
├── Playwright 浏览器下载: ~200 MB (一次性)
└── 测试输出 (videos, screenshots): 按需生成

执行时间:
├── 烟雾测试: 1-2 分钟
├── 全量测试: 15-25 分钟
└── CI/CD: 实际耗时 + 2-3 分钟 (setup overhead)
```

## 扩展和定制

### 添加新测试

1. 在 `tests/` 中创建文件 `test_<feature>.py`
2. 导入 fixtures: `from conftest import TestConfig`
3. 添加标记: `@pytest.mark.<category>`
4. 编写测试函数

```python
@pytest.mark.platform
async def test_new_service(page: Page, config: TestConfig):
    await page.goto(f"{config.SERVICE_URL}")
    # ...
```

### 自定义 fixtures

在 `conftest.py` 中添加：

```python
@pytest.fixture
async def my_fixture():
    # Setup
    yield value
    # Teardown
```

### 集成其他工具

- Allure 报告: `pip install allure-pytest`
- 性能监测: `pip install pytest-benchmark`
- 截图: `page.screenshot(path="screenshot.png")`
- 视频: `browser_context_args = {"record_video_dir": "test-videos"}`

## 维护清单

- [ ] 定期更新 `pyproject.toml` 中的依赖版本
- [ ] 监控 uv.lock 中的安全补丁
- [ ] 定期审查 .env.example，同步新增的环境变量
- [ ] 检查 CI/CD 工作流是否有失败
- [ ] 维护 GitHub Actions Secrets（凭证轮换）
- [ ] 定期运行测试，监控性能基线变化
