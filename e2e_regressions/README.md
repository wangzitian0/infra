# E2E 回归测试 (E2E Regression Testing)

> **定位**：部署后的自动化验证系统
> **存储**：`e2e_regressions/` (项目根目录)
> **触发**：Atlantis apply 成功后

## 架构

```
部署流程:
├── Atlantis plan ✓
├── Atlantis apply ✓
└── E2E 回归测试 ← 仅当 apply 成功时运行
    ├── 烟雾测试 (1-2 min)
    ├── 功能测试 (10-20 min)
    └── E2E 测试 (5-10 min)
```

## 快速使用

```bash
# 安装
cd e2e_regressions
uv sync
uv run playwright install chromium

# 配置
cp .env.example .env
# 编辑 .env 填入部署的 URL

# 运行烟雾测试（部署直后推荐）
make test-smoke

# 其他
make test          # 全部 42 个测试
make test-headed   # 可见浏览器调试
make report        # HTML 报告
```

## 测试覆盖范围

### 按层级

| 层级 | 测试项 | 耗时 | 文件 |
|------|--------|------|------|
| **L2 Platform** | Vault, Dashboard, Casdoor 可访问 | 2-3 min | `test_platform.py` |
| **L3 Data** | PostgreSQL, Redis, ClickHouse 连接 | 3-5 min | `test_databases.py` |
| **L4 Portal** | Homer SSO 登录、服务链接 | 3-5 min | `test_portal_sso.py` |
| **API** | HTTP 端点、响应时间、SSL 证书 | 2-3 min | `test_api_health.py` |
| **E2E** | 跨层验证、性能基线、故障恢复 | 5-10 min | `test_e2e_smoke.py` |

### 按标记（42 个测试）

```bash
make test-smoke      # 烟雾：6 个测试 (1-2 min)
make test-sso        # SSO：7 个测试
make test-platform   # Platform：7 个测试
make test-api        # API：10 个测试
make test-database   # 数据库：9 个测试
make test-e2e        # E2E：9 个测试
```

## 故障诊断

### 所有服务不可访问
```
症状: test_http_connectivity 失败
→ 检查 DNS/Ingress
  kubectl get ingress -A
  nslookup home.zitian.party
→ 检查网络策略
  kubectl get networkpolicy -A
```

### Portal 可访问但 SSO 失败
```
症状: test_portal_password_login 失败
→ Casdoor 是否启动
  kubectl get pod -n platform -l app=casdoor
→ OIDC 配置是否正确
  curl https://sso.zitian.party/.well-known/openid-configuration
```

### 数据库连接失败
```
症状: test_postgresql_connection 失败
→ 检查 Pod 启动
  kubectl get pod -n data-prod -l app=postgres
→ 测试连接（需要 port-forward）
  kubectl run -it --rm debug --image=postgres:latest -- \
    psql -h postgresql.data-prod.svc.cluster.local -U postgres
```

## CI/CD 集成

### GitHub Actions

已集成到 `.github/workflows/e2e-tests.yml`：

**触发方式**:
1. **Post-merge**: 推送到 `main` 分支时自动运行
2. **手动触发**: GitHub Actions UI → `workflow_dispatch`
3. **PR 评论**: 在 PR 中输入 `infra e2e`

**工作流功能**:
```yaml
# e2e-tests.yml
on:
  push:
    branches: [main]           # 合并后自动运行
  workflow_dispatch:           # 手动触发
    inputs:
      test_scope: smoke|all    # 选择测试范围
  workflow_call:               # 供其他 workflow 调用
```

**测试范围选项**:
- `smoke`: 快速烟雾测试 (默认, ~2min)
- `platform`: Platform 服务测试
- `sso`: SSO/Portal 测试
- `api`: API 健康测试
- `all`: 全部测试

## 维护

| 任务 | 频率 | 命令 |
|------|------|------|
| 更新依赖 | 月 | `uv sync && uv lock` |
| 运行全量测试 | 周 | `make test` |
| 生成报告 | 按需 | `make report` |
| 扩展测试 | 按需 | 在 `tests/` 新建 `test_*.py` |

## 状态

- ✅ **框架搭建**: 完成
- ✅ **测试用例**: 39 个测试 (37 passed, 1 failed, 1 skipped)
- ✅ **CI 集成**: 已完成 (`e2e-tests.yml`)
- ⏳ **数据库测试**: 待补充 (`test_databases.py`)

---

## 架构问题讨论（#S-CI-ARCH）

### 问题：当前 CI 和命令体系脱节

**现状**：
- Atlantis apply 成功 ≠ 部署成功
- E2E 测试依赖手动触发或定时任务
- 没有 feedback 机制告诉用户"部署实际成功了吗"

**建议方案**：

#### 1. 定义"部署完全成功"的条件

```
Atlantis apply ✓ (基础设施同步)
    ↓
等待资源就绪 (Kubernetes 健康检查)
    ↓
运行 E2E 烟雾测试 (功能验证)
    ↓
CI 状态 = success/failure ← 这是最终答案
```

#### 2. 三层 CI 状态模型

```
❌ FAILED (apply 失败 或 资源就绪失败)
  → 在 PR 评论中显示：❌ Deployment failed: [error]

⚠️ PENDING (apply 成功，等待资源就绪)
  → 在 PR 评论中显示：🟡 Running E2E tests...

✅ SUCCESS (所有检查通过)
  → 在 PR 评论中显示：✅ Deployment successful
    - Vault: ready
    - Dashboard: ready
    - Portal: ready
    - Databases: ready
```

#### 3. 建议的 GitHub Actions 流程

```yaml
post-apply-validation:
  needs: atlantis-apply
  if: needs.atlantis-apply.result == 'success'  # ← 关键：仅 apply 成功时运行

  steps:
    - name: 1️⃣ Wait for resources ready
      run: |
        kubectl wait --for=condition=ready pod \
          -l app=vault -n platform --timeout=5m
        # ... 其他资源 ...

    - name: 2️⃣ Run E2E smoke tests
      run: make test-smoke

    - name: 3️⃣ Report results
      if: always()
      uses: actions/github-script@v6
      with:
        script: |
          const status = ${{ job.status }} === 'success' ? '✅' : '❌'
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            body: `${status} **Deployment Status**: ...`
          })
```

#### 4. 优势

✅ **clear**: 用户清楚知道部署是否真正完成
✅ **fail-fast**: apply 失败立即停止，不浪费时间等待 E2E
✅ **actionable**: 错误明确，容易定位问题
✅ **measurable**: 有明确的 success/failure 指标

---

## 参考

- 详细文档：`e2e_regressions/README.md`
- 快速开始：`e2e_regressions/QUICK_START.md`
- 架构深度：`e2e_regressions/ARCHITECTURE.md`
- 测试策略：`e2e_regressions/TESTING_STRATEGY.md`
