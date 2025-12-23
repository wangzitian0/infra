# K8s Cluster Tests

## 测试范围

- K8s API Server 可访问性
- 节点健康状态
- 核心组件运行状态
- Namespace 结构验证

## SSOT Reference

K8s 集群配置详见根目录 `1.bootstrap/1.k3s.tf`。

## 运行测试

```bash
# 运行所有 K8s 测试
uv run pytest tests/bootstrap/k8s/ -v

# 运行特定测试
uv run pytest tests/bootstrap/k8s/test_cluster.py::test_k8s_api_accessible -v
```
