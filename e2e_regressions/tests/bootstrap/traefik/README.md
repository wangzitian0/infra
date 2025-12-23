# Traefik Ingress Tests

## 测试范围

- Traefik 流量路由
- HTTP 到 HTTPS 重定向
- 无效路由处理
- Header 保留

## SSOT Reference

Traefik 配置详见根目录 `1.bootstrap/4.traefik_config.tf`。

## 运行测试

```bash
uv run pytest tests/bootstrap/traefik/ -v
```
