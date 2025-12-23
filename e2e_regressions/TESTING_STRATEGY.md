# E2E 测试策略

## 分层测试策略

本项目遵循测试金字塔原则，按部署阶段分层测试：

```
        ┌─────────────────┐
        │  E2E 完整场景    │  (5-10 min)
        │  • 跨层验证      │
        │  • 性能基线      │
        └────────┬────────┘
        ┌─────────────────┐
        │  单层服务测试    │  (10-15 min)
        │  • SSO/Portal   │
        │  • Platform Srv │
        │  • API/Database │
        └────────┬────────┘
        ┌─────────────────┐
        │  快速烟雾测试    │  (1-2 min) ← 重点
        │  • 可访问性      │
        │  • HTTP 健康检查 │
        └─────────────────┘
```

## 部署验证流程

### 阶段 1: L1 Bootstrap 完成 ✓

```bash
# 验证 Kubernetes 集群
kubectl get nodes
kubectl get pods -n kube-system

# E2E 测试还不适用，因为没有应用层
```

### 阶段 2: L2 Platform 完成 ✓

```bash
# 运行烟雾测试
make test-smoke

# 应该全部通过：
# ✓ Vault 可访问
# ✓ Casdoor 可访问
# ✓ Dashboard 可访问
# ✓ Portal 可访问
```

### 阶段 3: L3 Data 完成 ✓

```bash
# 运行数据库测试
make test-database

# 应该通过：
# ✓ PostgreSQL 连接
# ✓ Redis 连接
# ✓ ClickHouse 连接
```

### 阶段 4: L4 Apps 完成 ✓

```bash
# 运行完整测试
make test

# 所有 42 个测试应该通过
```

## 测试覆盖范围

### SSO/Portal 层

| 测试项 | 目的 | 失败原因 |
|--------|------|---------|
| Portal 可访问 | 验证入口 | Ingress 未配置 |
| SSO 登录页面加载 | 验证 Casdoor | Casdoor 服务未启动 |
| 密码登录流程 | 验证认证 | 用户/密码错误或 OAuth 配置错误 |
| 服务链接显示 | 验证 Portal 内容 | Homer 配置错误 |
| 会话持久性 | 验证 Cookie | Ingress 未配置 sticky sessions |
| 响应式设计 | 验证 UI | CSS/JS 加载错误 |

### Platform 服务层

| 服务 | 测试项 | 失败原因 |
|------|--------|---------|
| **Vault** | HTTP 健康检查 | Vault Pod 未启动 |
| | API 可访问 | ServiceAccount 权限缺失 |
| | 配置端点 | Vault 初始化失败 |
| **Casdoor** | API 可访问 | Casdoor Pod 未启动 |
| | 组织端点 | 初始化数据缺失 |
| **Dashboard** | UI 加载 | Dashboard Pod 未启动 |
| | 可访问性 | RBAC 配置错误 |

### API 健康层

| 测试项 | 目的 | 失败原因 |
|--------|------|---------|
| HTTP 连通性 | 基础网络 | Ingress/网络策略问题 |
| 响应时间 | 性能基线 | 资源不足、高负载 |
| SSL 证书 | 传输安全 | cert-manager 未配置 |
| 错误处理 | 优雅降级 | 应用错误处理缺陷 |
| 重定向链 | 路由正确 | Ingress 规则错误 |

### 数据库层

| 测试项 | 目的 | 失败原因 |
|--------|------|---------|
| PostgreSQL 连接 | 基础连通 | 服务未启动或防火墙 |
| 查询性能 | 性能基线 | 数据库负载/配置 |
| Redis 连接 | 缓存可用 | 服务未启动或内存不足 |
| SET/GET 操作 | 基础功能 | Redis 权限或键值冲突 |
| ClickHouse 连接 | 时序数据库 | 服务未启动或配置 |

## 故障诊断指南

### 场景 1: 烟雾测试全部失败

```
症状: 所有服务都无法访问
└─ DNS 问题？
   └─ 检查: nslookup home.zitian.party
└─ Network Policy？
   └─ 检查: kubectl get networkpolicy -A
└─ Ingress 未配置？
   └─ 检查: kubectl get ingress -A
```

### 场景 2: Portal 可访问但 SSO 登录失败

```
症状: 能访问 Portal，但登录时失败
└─ Casdoor 未启动？
   └─ 检查: kubectl get pod -n platform -l app=casdoor
└─ OIDC 配置错误？
   └─ 检查: curl https://sso.zitian.party/.well-known/openid-configuration
└─ OAuth2-Proxy 配置错误？
   └─ 检查: kubectl logs -n platform -l app=oauth2-proxy
```

### 场景 3: Platform 服务可访问但 API 错误

```
症状: Vault/Dashboard/Casdoor 返回 500
└─ 数据库连接问题？
   └─ 检查: kubectl logs <pod> -n platform
└─ 初始化失败？
   └─ 检查: terraform apply -target module.vault
└─ 权限问题？
   └─ 检查: kubectl describe pod <pod>
```

### 场景 4: 数据库连接失败

```
症状: test_database 失败
└─ 服务未启动？
   └─ 检查: kubectl get pod -n data-prod -l app=postgres
└─ 连接字符串错误？
   └─ 检查: echo $DB_HOST, $DB_PORT, $DB_USER
└─ 权限/密码错误？
   └─ 检查: kubectl exec -it <pod> -- psql -U postgres
└─ 网络不通？
   └─ 检查: kubectl run -it --rm debug --image=postgres:latest -- psql -h postgresql.data-prod
```

## 测试驱动修复流程

### Step 1: 识别失败

```bash
make test-smoke 2>&1 | grep "FAILED"
# Output: FAILED test_platform.py::test_vault_is_accessible
```

### Step 2: 查看详细错误

```bash
uv run pytest tests/test_platform.py::test_vault_is_accessible -vv
# Output: ConnectionError: Failed to connect to https://secrets.zitian.party
```

### Step 3: 收集诊断信息

```bash
# 检查 Kubernetes 资源
kubectl describe pod -n platform $(kubectl get pod -n platform -l app=vault -o name | head -1)

# 检查日志
kubectl logs -n platform -l app=vault --tail=50

# 检查网络
kubectl get svc -n platform vault
```

### Step 4: 应用修复

```bash
# 例如: Vault Pod 未启动
terraform apply -target kubernetes_pod.vault

# 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app=vault -n platform --timeout=300s
```

### Step 5: 重新运行测试

```bash
# 清除缓存（可选）
make clean

# 重新运行失败的测试
make test-smoke -k test_vault_is_accessible
```

## 性能基线建立

### 首次建立基线

```bash
# 在新环境中运行一次
make test-e2e --report

# 记录输出（report.html 中的耗时）
# Portal 首页加载: ~1.2s
# Vault API: ~0.8s
# Casdoor API: ~0.9s
```

### 监控性能变化

```bash
# 定期运行 (cron job 或手动)
make test-e2e

# 对比输出，识别异常
# 如果响应时间 > 基线 2x，触发告警
```

## CI/CD 集成检查清单

- [ ] Secrets 已配置 (PORTAL_URL, VAULT_URL 等)
- [ ] 烟雾测试设置为 required status check
- [ ] 测试报告已配置为 artifact
- [ ] 定时运行已启用（6 小时）
- [ ] 失败告警已配置（可选）
- [ ] 性能基线已建立

## 本地开发指南

### 快速反馈循环

```bash
# 开发环境中运行特定测试
HEADLESS=false make test-sso

# 附加 debugging
make test-debug -k test_portal_password_login
```

### 调试技巧

```bash
# 添加断点
import pdb; pdb.set_trace()

# 显示 print 输出
uv run pytest -s tests/test_portal_sso.py

# 保存浏览器视频
RECORD_VIDEO=true make test-sso

# 保存截图
# 手动在测试中添加: await page.screenshot(path="debug.png")
```

## 维护建议

### 周期性检查

- **每周**: 查看 CI 日志，确保烟雾测试通过
- **每月**: 更新依赖版本，检查安全补丁
- **每季度**: 审查测试覆盖范围，补充缺失测试
- **每半年**: 重新建立性能基线，更新超时时间

### 警告信号

- 烟雾测试频繁超时 (> 3 分钟)
- API 响应时间 > 基线 2 倍
- 测试间歇性失败（flaky）
- 新增的环境变量未同步到 CI
