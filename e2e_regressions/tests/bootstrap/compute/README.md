# Bootstrap 计算层测试

验证 K3s 集群、Atlantis CI 和 Traefik Ingress 的健康状态。

## SSOT 参考

- [bootstrap.compute.md](../../../../docs/ssot/bootstrap.compute.md)

## 测试矩阵

| 组件 | 测试 | 标记 | 验证内容 |
|------|------|------|----------|
| **K3s** | `test_k3s_api_accessible` | smoke | API 可达性 |
| **K3s** | `test_k3s_namespaces_exist` | - | Namespace 结构 |
| **K3s** | `test_k3s_core_services_running` | - | 核心服务运行 |
| **Atlantis** | `test_atlantis_config_exists` | smoke | 配置文件存在 |
| **Atlantis** | `test_atlantis_config_valid` | - | 配置内容有效 |
| **Atlantis** | `test_atlantis_projects_defined` | - | 项目定义完整 |
| **Atlantis** | `test_atlantis_endpoint_accessible` | - | Webhook 端点可达 |
| **Traefik** | `test_traefik_routes_traffic` | smoke | 路由功能 |
| **Traefik** | `test_traefik_https_redirect` | - | HTTPS 重定向 |
| **Traefik** | `test_traefik_preserves_headers` | - | Header 保留 |
| **Traefik** | `test_traefik_handles_invalid_routes` | - | 无效路由处理 |

## 运行测试

```bash
# 所有计算层测试
uv run pytest tests/bootstrap/compute/ -v

# Smoke 测试
uv run pytest tests/bootstrap/compute/ -m smoke -v
```

## 环境变量

| 变量 | 必需 | 说明 |
|------|------|------|
| `DASHBOARD_URL` | ✅ | K8s Dashboard URL |
| `PORTAL_URL` | ✅ | Portal URL |
| `VAULT_URL` | ✅ | Vault URL |
| `ATLANTIS_URL` | ❌ | Atlantis URL (可选) |
