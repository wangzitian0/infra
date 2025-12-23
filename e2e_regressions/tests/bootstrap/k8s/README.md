# K8s Cluster Tests

验证 Kubernetes 集群的健康状态和核心功能。

## 测试覆盖

- K8s API Server 可达性
- 节点健康检查
- 核心组件状态（kube-system）
- Namespace 结构验证
- Pod 调度和运行能力

## 运行测试

```bash
# 所有 K8s 测试
uv run pytest tests/bootstrap/k8s/ -v

# Smoke 测试
uv run pytest tests/bootstrap/k8s/ -m smoke -v
```

## SSOT 参考

配置和架构详见：
- [core.dir.md](file:///Users/SP14016/zitian/cc_infra/docs/ssot/core.dir.md) - 目录结构
- Terraform: `1.bootstrap/1.k3s.tf`
