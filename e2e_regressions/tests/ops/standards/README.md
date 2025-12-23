# Engineering Standards (运维标准规范)

> **SSOT 状态**：本文件定义了组件接入集群的“准入标准”。

---

## 1. 健康检查分层规范

所有部署在集群内的 L2-L4 组件必须满足以下覆盖度要求：

| 检查类型 | 适用场景 | 强制 | 说明 |
|----------|----------|------|------|
| **initContainer** | 有外部依赖 (DB/Vault) | ✅ 必须 | 建议 120s 超时，使用 `nc` 或专用 check 脚本 |
| **Probes** | 长期运行的 Pod | ✅ 必须 | 必须包含 Readiness 和 Liveness |
| **validation** | TF 敏感变量 | ✅ 必须 | 在 `variables.tf` 中定义正则表达式校验 |
| **precondition** | 强依赖资源 | ✅ 必须 | 在 `resource` 或 `data` 中定义生命周期前置检查 |
| **Helm timeout** | Helm Release | ✅ 必须 | 默认 300s，防止 Apply 过程中出现死锁 |

---

## 2. 覆盖度矩阵 (L1-L4)

| 层级 | 组件 | initContainer | Probes | validation | precondition | timeout |
|------|------|---------------|--------|------------|--------------|---------|
| **L1** | Atlantis | N/A | ✅ R+L | ✅ | ✅ | 300s |
| **L1** | DNS/Cert | N/A | N/A | ✅ | N/A | 300s |
| **L2** | Vault | ✅ 120s | ✅ R+L | ✅ | ✅ | 300s |
| **L2** | Casdoor | ✅ 120s | ✅ S+R+L | ✅ | ✅ | 300s |
| **L3** | Databases | ✅ 120s | ✅ Helm | ✅ | ✅ | 300s |
| **L4** | Kubero | N/A | ✅ R+L | N/A | N/A | 300s |

---

## 3. 防御性配置要求 (Defensive Rules)

- **Propagation Delay**: 所有的 Ingress/DNS 变更必须伴随 `time_sleep` 资源（参考 `AGENTS.md` SOP Rule 5）。
- **Identity Consistency**: 所有的自动评论必须由 `infra-flash` 身份发出。
- **No Shadowing**: 严禁在 Composite Action 中混用 GitHub Env 和 Shell Vars。
