# PostgreSQL Tests

验证业务 PostgreSQL 数据库的连接和基本操作。

## 测试覆盖

- 数据库连接可达性
- 基本 CRUD 操作
- 连接池配置
- 事务处理
- 数据持久化

## 运行测试

```bash
uv run pytest tests/data/postgresql/ -v
```

## 环境配置

需要配置以下环境变量：
- `DB_HOST` - 数据库主机
- `DB_PORT` - 端口号（默认 5432）
- `DB_USER` - 用户名
- `DB_PASSWORD` - 密码

## SSOT 参考

配置详见：
- [db.business_pg.md](file:///Users/SP14016/zitian/cc_infra/docs/ssot/db.business_pg.md) - 业务数据库配置
- [db.overview.md](file:///Users/SP14016/zitian/cc_infra/docs/ssot/db.overview.md) - 数据库架构概览
