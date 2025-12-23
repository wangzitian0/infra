# DNS & Certificate Tests

验证 DNS 解析和 SSL/TLS 证书配置。

## 测试覆盖

### DNS
- 域名解析验证
- 通配符 DNS 配置
- 所有服务域名可达性
- DNS 缓存和 TTL

### Certificates
- HTTPS 启用验证
- 证书有效性（含自签名）
- 证书过期检查
- Cert-Manager 状态
- 证书自动续期

## 运行测试

```bash
# DNS 测试
uv run pytest tests/bootstrap/dns_cert/test_dns.py -v

# 证书测试
uv run pytest tests/bootstrap/dns_cert/test_certificates.py -v

# Smoke 测试
uv run pytest tests/bootstrap/dns_cert/ -m smoke -v
```

## SSOT 参考

配置详见：
- Terraform: `1.bootstrap/3.dns_and_cert.tf`
- [core.env.md](file:///Users/SP14016/zitian/cc_infra/docs/ssot/core.env.md) - 环境变量
