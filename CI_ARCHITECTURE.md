# CI 6-Actions Architecture

本 PR 实现了正确的 CI 架构：**6 个逻辑 Action，基于 10 个原子操作**。

## 🎯 6 个逻辑 Action (CI Checks)

| # | Action | 包含原子操作 | PR Auto | Post-merge Auto | Manual |
|---|--------|------------|---------|----------------|--------|
| 1 | **check** | TF fmt + TF validate + Digger fmt + Digger validate | ✅ | ✅ | `/check` |
| 2 | **bootstrap-plan** | Bootstrap plan | ✅ | ✅ | `/bootstrap-plan` |
| 3 | **plan** | TF plan + Digger plan | ✅ | ✅ | `/plan` |
| 4 | **bootstrap-apply** | Bootstrap apply | ❌ | ✅ | `/bootstrap-apply` |
| 5 | **apply** | TF apply + Digger apply | ❌ | ✅ | `/apply` |
| 6 | **e2e** | E2E tests | ❌ | ✅ | `/e2e` |

## 📊 Workflow 流程

### PR Push (自动触发 3 个)
```
check → bootstrap-plan → plan
```

### Post-merge (自动顺序触发 6 个)
```
check →
  ├→ bootstrap-plan →
  └→ plan → 
      ├→ bootstrap-apply →
      └→ apply →
          └→ e2e
```

### Manual (任意时刻手动触发)
```
/check
/bootstrap-plan
/plan
/bootstrap-apply
/apply
/e2e
```

## ✅ 测试清单

### 自动测试
- [ ] PR创建触发 check
- [ ] PR创建触发 bootstrap-plan
- [ ] PR创建触发 plan
- [ ] Merge触发所有6个（顺序）

### 手动测试
- [ ] `/check` 命令
- [ ] `/bootstrap-plan` 命令
- [ ] `/plan` 命令
- [ ] `/bootstrap-apply` 命令
- [ ] `/apply` 命令
- [ ] `/e2e` 命令
- [ ] `/help` 命令

---

**架构原则**：
- 原子操作清晰 (fmt/validate/plan/apply/e2e)
- 逻辑分组合理 (6个独立actions)
- 触发机制统一 (auto + manual)
- 依赖关系明确 (needs)
