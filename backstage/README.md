# Backstage Developer Portal

## 📍 你在这里

这个目录将包含 Backstage 开发者门户配置。

## 🎯 核心目标

**通过 Backstage 监测：环境 × 基建 = 是否真的好了？**

## 🏗️ 架构设计

### 健康监测仪表盘

```
┌─────────────────────────────────────────────┐
│  TrueAlpha Platform Health Dashboard       │
├─────────────────────────────────────────────┤
│                                             │
│  📊 Environment Status                      │
│  ┌──────┬──────────┬──────────┬─────────┐  │
│  │ Env  │ Infra    │ Services │ Overall │  │
│  ├──────┼──────────┼──────────┼─────────┤  │
│  │ dev  │ ✅ (3/3) │ ✅ (7/7) │ 🟢      │  │
│  │ test │ ✅ (2/2) │ ⚠️ (5/7) │ 🟡      │  │
│  │ stag │ ✅ (3/3) │ ✅ (7/7) │ 🟢      │  │
│  │ prod │ ✅ (3/3) │ ✅ (7/7) │ 🟢      │  │
│  └──────┴──────────┴──────────┴─────────┘  │
│                                             │
│  🏗️ Infrastructure Components              │
│  • Cloudflare DNS    ✅                     │
│  • VPS Reachable     ✅                     │
│  • Docker Running    ✅                     │
│                                             │
│  🚀 Application Services                    │
│  • Backend API       ✅  (200ms p95)        │
│  • Neo4j            ✅  (50ms avg)         │
│  • PostgreSQL       ✅  (30ms avg)         │
│  • Redis            ✅  (5ms avg)          │
│  • Celery Workers   ✅  (3/3 active)       │
│  • Flower           ✅                      │
│  • Traefik          ✅                      │
│                                             │
└─────────────────────────────────────────────┘
```

### 监测维度

#### 1. 基础设施层 (Infrastructure)
- **Cloudflare DNS**: 通过 API 检查 DNS 记录
- **VPS 可达性**: Ping/SSH 连接测试
- **Docker 运行**: Docker daemon 状态

#### 2. 服务层 (Services)  
- **Backend**: Health endpoint 检查
- **Neo4j**: Cypher 查询测试
- **PostgreSQL**: 连接池状态
- **Redis**: Ping 命令
- **Celery**: Worker 数量和任务队列
- **Flower**: UI 可访问性
- **Traefik**: 路由规则生效

#### 3. 应用层 (Application)
- **API 响应时间**: p50/p95/p99
- **错误率**: 5xx errors
- **QPS**: 每秒请求数

## 📦 实施计划

### Phase 1: Catalog 定义 (当前可做)

创建 `catalog-info.yaml`:

```yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: truealpha
  title: TrueAlpha Platform
  description: 环境即服务基础设施
spec:
  owner: platform-team

---
# Dev 环境
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: env-dev
  title: Development Environment
  annotations:
    github.com/repo: wangzitian0/infra
    backstage.io/health-check: "https://dev.truealpha.club/health"
    cloudflare.io/zone-id: "${ZONE_ID}"
  tags:
    - environment
    - dev
spec:
  type: environment
  owner: platform-team
  system: truealpha
  lifecycle: development
  dependsOn:
    - resource:infra-cloudflare-dns
    - resource:infra-vps-hosthatch

---
# Cloudflare Infrastructure
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: infra-cloudflare-dns
  title: Cloudflare DNS/CDN/WAF
  annotations:
    cloudflare.io/zone-id: "${ZONE_ID}"
spec:
  type: infrastructure
  owner: platform-team
  system: truealpha
```

### Phase 2: 健康检查插件

开发自定义插件 `@truealpha/plugin-health-monitor`:

```typescript
// 健康检查接口
interface HealthCheck {
  environment: string;
  infrastructure: {
    cloudflare_dns: HealthStatus;
    vps_reachable: HealthStatus;
    docker_running: HealthStatus;
  };
  services: {
    backend: HealthStatus;
    neo4j: HealthStatus;
    postgres: HealthStatus;
    redis: HealthStatus;
  };
  overall: 'healthy' | 'warning' | 'critical';
}
```

### Phase 3: 自动化操作

通过 Scaffolder 模板实现：
- 创建新环境
- 触发部署
- 执行回滚

## 🚀 快速开始

### 1. 初始化 Backstage

```bash
cd backstage
npx @backstage/create-app@latest
```

### 2. 配置 Catalog

将 `catalog-info.yaml` 放在仓库根目录

### 3. 开发健康检查插件

```bash
cd backstage/app
yarn create-plugin --id health-monitor
```

### 4. 集成数据源

- Cloudflare API
- Docker API  
- Health endpoints

## 📊 数据流

```
Backstage UI
    ↓
Health Check Plugin
    ↓ 并发请求
    ├─→ Cloudflare API (DNS 状态)
    ├─→ VPS SSH (Docker 状态)  
    ├─→ Health Endpoints (服务状态)
    └─→ SigNoz API (性能指标)
    ↓
汇总展示
```

## 📚 相关资源

- [Backstage 官方文档](https://backstage.io/docs)
- [Catalog 数据模型](https://backstage.io/docs/features/software-catalog/descriptor-format)
- [插件开发指南](https://backstage.io/docs/plugins/)
- [架构设计](../docs/architecture.md)

## ⚠️ 注意事项

- Backstage 是预留组件，优先级相对较低
- 建议先完成 Terraform + Docker Compose 部署
- 健康检查功能可以先通过脚本实现，再集成到 Backstage
