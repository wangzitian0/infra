# 开发者接入指南

## 快速开始

### 前置要求

- Docker Desktop >= 24.0
- Docker Compose >= 2.20
- Git
- (可选) Infisical CLI - `brew install infisical/tap/infisical`

### 本地开发环境搭建

1. **Clone 仓库**

```bash
git clone <repo-url>
cd infra
```

2. **配置环境变量**

```bash
# 方式 1: 从 Infisical 导出（推荐）
infisical login
./scripts/deploy/export-secrets.sh dev

# 方式 2: 手动配置
cp secrets/.env.example .env.dev
# 编辑 .env.dev 填入实际值
```

3. **启动服务**

```bash
docker compose \
  -f compose/base.yml \
  -f compose/dev.yml \
  --env-file .env.dev \
  -p truealpha-dev \
  up -d
```

4. **验证服务**

```bash
# 查看状态
docker compose -p truealpha-dev ps

# 访问服务
# GraphQL API: http://localhost:8000/graphql
# Neo4j Browser: http://localhost:7474
# PostgreSQL: localhost:5432
# Flower: http://localhost:5555
```

## 新服务接入

### 添加新的应用服务

1. **在 `compose/base.yml` 中定义服务**

```yaml
services:
  new-service:
    image: ${REGISTRY}/new-service:${VERSION}
    container_name: ${PROJECT_NAME}-new-service-${PEG_ENV}
    restart: unless-stopped
    environment:
      - PEG_ENV=${PEG_ENV}
      - SERVICE_CONFIG=${SERVICE_CONFIG}
    networks:
      - app_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.new-service-${PEG_ENV}.rule=Host(`service.${DOMAIN}`)"
    depends_on:
      - postgres
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

2. **在环境覆盖文件中添加端口映射（dev）**

```yaml
# compose/dev.yml
services:
  new-service:
    ports:
      - "3000:3000"
    volumes:
      - ../../apps/new-service:/app:delegated
```

3. **添加环境变量到 Infisical**

```bash
infisical secrets set SERVICE_CONFIG "value" --env=dev
```

4. **测试新服务**

```bash
docker compose -p truealpha-dev up -d new-service
docker compose -p truealpha-dev logs -f new-service
```

### OpenTelemetry 集成

在你的应用中集成 OTel SDK:

#### Python (FastAPI)

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# 配置 Tracer
provider = TracerProvider()
otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
    insecure=True
)
provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(provider)

# Instrument FastAPI
app = FastAPI()
FastAPIInstrumentor.instrument_app(app)
```

#### Node.js (Express)

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
  serviceName: process.env.OTEL_SERVICE_NAME,
});

sdk.start();
```

### PostHog 事件追踪

#### Frontend

```javascript
import posthog from 'posthog-js';

posthog.init(process.env.POSTHOG_API_KEY, {
  api_host: process.env.POSTHOG_HOST,
});

// 追踪事件
posthog.capture('button_clicked', {
  button_name: 'signup',
});
```

#### Backend

```python
from posthog import Posthog

posthog = Posthog(
    api_key=os.getenv('POSTHOG_API_KEY'),
    host=os.getenv('POSTHOG_HOST')
)

# 追踪事件
posthog.capture(
    distinct_id='user_123',
    event='api_called',
    properties={'endpoint': '/graphql'}
)
```

## 环境变量管理

### 环境变量命名规范

- 使用大写字母和下划线
- 前缀标识用途: `DB_*`, `REDIS_*`, `OTEL_*`
- 敏感信息必须通过 Infisical 管理

### 添加新的环境变量

1. 在 Infisical 中添加

```bash
infisical secrets set NEW_CONFIG "value" --env=dev
infisical secrets set NEW_CONFIG "value" --env=staging
infisical secrets set NEW_CONFIG "value" --env=prod
```

2. 更新 `.env.example`

```bash
# 添加注释说明
NEW_CONFIG=default_value
```

3. 在代码中使用

```python
import os
config = os.getenv('NEW_CONFIG')
```

## 测试

### 本地运行测试

```bash
# 启动测试数据库
docker compose -f compose/base.yml -f compose/ci.yml up -d

# 运行测试
docker compose exec backend pytest

# 清理
docker compose -f compose/base.yml -f compose/ci.yml down
```

### CI 环境测试

所有 PR 会自动运行测试。查看 `.github/workflows/` 中的配置。

## 部署流程

### 部署到 Test (PR 预览)

1. 创建 PR
2. 自动部署预览环境
3. 在 PR 评论中获取预览 URL
4. 合并 PR 后自动清理

### 部署到 Staging

```bash
# 方式 1: 通过 GitHub Actions
# 在 GitHub UI 中手动触发 deploy workflow

# 方式 2: 手动部署
./scripts/deploy/deploy.sh staging
```

### 部署到 Production

1. 确保 staging 环境验证通过
2. 创建 PR 到 main 分支
3. 通过 code review
4. 合并后自动触发生产部署

或手动触发:

```bash
./scripts/deploy/deploy.sh prod v1.2.3
```

## Terraform 变更流程

### 修改基础设施

1. 修改 `terraform/` 下的文件
2. 创建 PR
3. Atlantis 自动运行 `terraform plan`
4. 审查 plan 输出
5. 评论 `atlantis apply` 应用变更

### 添加新环境

1. 复制环境模板

```bash
cp -r terraform/envs/dev terraform/envs/new-env
```

2. 修改 `terraform.tfvars`
3. 在 `atlantis.yaml` 中添加项目配置
4. 通过 PR 应用变更

## 故障排查

### 服务启动失败

```bash
# 检查日志
docker compose -p truealpha-dev logs backend

# 验证配置
docker compose -f compose/base.yml -f compose/dev.yml config

# 检查环境变量
docker compose -p truealpha-dev exec backend env
```

### 数据库连接问题

```bash
# 测试 Neo4j 连接
docker compose -p truealpha-dev exec neo4j \
  cypher-shell -u neo4j -p password "RETURN 1"

# 测试 PostgreSQL 连接
docker compose -p truealpha-dev exec postgres \
  psql -U truealpha -d truealpha -c "SELECT 1"
```

### 网络问题

```bash
# 检查网络
docker network ls | grep truealpha

# 检查服务间连接
docker compose -p truealpha-dev exec backend ping neo4j
```

## 最佳实践

### 1. 环境隔离

- 始终使用正确的环境前缀 (`DB_TABLE_PREFIX`)
- 不要混用不同环境的数据库
- 使用独立的 Docker 网络

### 2. 密钥安全

- 绝不提交 `.env` 文件到 Git
- 使用 Infisical 管理所有敏感配置
- 定期轮换密钥

### 3. 日志与监控

- 在关键路径添加 trace 标记
- 使用结构化日志
- 监控关键指标 (错误率、延迟)

### 4. 资源管理

- 定期清理未使用的 Docker 资源
- 使用资源限制防止单个服务占用过多资源
- 监控磁盘使用

## 常见问题

**Q: 如何重置本地数据库?**

```bash
docker compose -p truealpha-dev down -v
docker compose -p truealpha-dev up -d
```

**Q: 如何更新 Docker 镜像?**

```bash
docker compose -p truealpha-dev pull
docker compose -p truealpha-dev up -d
```

**Q: 如何查看正在运行的服务?**

```bash
docker compose -p truealpha-dev ps
```

**Q: 如何进入容器调试?**

```bash
docker compose -p truealpha-dev exec backend bash
```

## 参考资料

- [架构文档](../architecture.md)
- [运维手册](../runbooks/operations.md)
- [BRN-004 设计文档](../../PEG-scaner/docs/origin/BRN-004.dev_test_prod_design.md)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [Terraform 文档](https://www.terraform.io/docs)
