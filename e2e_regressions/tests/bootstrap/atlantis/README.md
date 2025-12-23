# Atlantis CI/CD Tests

## 测试范围

- Atlantis Webhook 可访问性
- Atlantis UI（如果暴露）
- GitHub Webhook 配置验证

## SSOT Reference

Atlantis 配置详见根目录 `1.bootstrap/2.atlantis.tf`。

## 运行测试

```bash
uv run pytest tests/bootstrap/atlantis/ -v
```

## 注意事项

部分测试需要配置 `ATLANTIS_URL` 环境变量才能运行。
