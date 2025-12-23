# Traefik Ingress Tests

验证 Traefik Ingress Controller 的路由和配置。

## 测试覆盖

- HTTP/HTTPS 流量路由
- 重定向规则（HTTP → HTTPS）
- 路由匹配和优先级
- Header 转发和修改
- 错误页面处理
- 健康检查端点

## 运行测试

```bash
# 所有 Traefik 测试
uv run pytest tests/bootstrap/traefik/ -v

# Smoke 测试
uv run pytest tests/bootstrap/traefik/ -m smoke -v
```

## SSOT 参考

配置详见：
- Terraform: `1.bootstrap/4.traefik_config.tf`
- [platform.network.md](file:///Users/SP14016/zitian/cc_infra/docs/ssot/platform.network.md) - 网络架构
