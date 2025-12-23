# Platform Auth Tests

验证 SSO、OAuth2、Casdoor 认证流程。

## 测试覆盖

- Casdoor 登录流程
- OAuth2 token 验证
- 权限和角色检查
- Session 管理
- 登出流程

## 运行测试

```bash
uv run pytest tests/platform/auth/ -v
```

## 环境配置

需要配置：
- `SSO_URL` - Casdoor SSO URL
- `TEST_USERNAME` - 测试用户
- `TEST_PASSWORD` - 测试密码

## SSOT 参考

配置详见：
- [platform.auth.md](file:///Users/SP14016/zitian/cc_infra/docs/ssot/platform.auth.md) - 认证架构
