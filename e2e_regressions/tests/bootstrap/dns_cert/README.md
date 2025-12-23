# DNS & Certificate Tests

## 测试范围

### DNS Tests
- 域名解析验证
- 通配符 DNS 配置
- 所有服务域名可达性

### Certificate Tests
- HTTPS 启用验证
- 证书有效性（包括自签名）
- 证书过期检查
- Cert-Manager 运行状态

## SSOT Reference

DNS 和证书配置详见根目录 `1.bootstrap/3.dns_and_cert.tf`。

## 运行测试

```bash
# 运行 DNS 测试
uv run pytest tests/bootstrap/dns_cert/test_dns.py -v

# 运行证书测试
uv run pytest tests/bootstrap/dns_cert/test_certificates.py -v
```
