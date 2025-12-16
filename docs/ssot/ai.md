# AI 接入（OpenRouter）SSOT

> **核心问题**：应用如何统一接入 LLM？变量/密钥在哪里定义与注入？

## 选型

| 项目 | 选择 | 理由 |
|------|------|------|
| **LLM Gateway** | OpenRouter | 单一 API 入口、可切换模型/供应商、计费聚合 |

## 变量与密钥

### 运行时环境变量（L4 Apps）

| Env | 必填 | 默认值 | 说明 |
|-----|------|--------|------|
| `OPENROUTER_BASE_URL` | ❌ | `https://openrouter.ai/api/v1` | API Host |
| `OPENROUTER_DEFAULT_MODEL` | ❌ | (按应用设置) | 默认模型名 |

### 运行时密钥（Vault SSOT）

| Secret | 必填 | 用途 | 存储位置 |
|--------|------|------|----------|
| `OPENROUTER_API_KEY` | ✅ | 调用 OpenRouter | Vault（KV） |

> 密钥分层策略见 `docs/ssot/secrets.md` 与 DD-001。

## 注入方式

```
Vault（KV SSOT）
   ↓ Vault Agent Injector
App Pod（/vault/secrets/*）
```

## 使用规范

- 不在 Terraform / GitHub Secrets 里长期保存 OpenRouter Key（除 CI 临时用）。
- 模型选择由应用层决定；infra 只提供接入通道。

## 实施状态

| 项目 | 状态 |
|------|------|
| OpenRouter Key 管理 | ⏳ 未配置 |
| 应用侧 SDK 接入 | ⏳ 未落地 |

---

## Used by（反向链接）

- [docs/ssot/README.md](./README.md)
- [docs/ssot/secrets.md](./secrets.md)
