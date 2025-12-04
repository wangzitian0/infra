# Kubernetes Dashboard 部署指南

## 概述

Kubernetes Dashboard 是官方的 Web UI 管理工具，提供：
- 查看所有 Kubernetes 资源（Pods、Services、Deployments 等）
- 实时监控资源状态和日志
- 编辑和删除资源
- 部署新应用
- 故障排查

## 部署步骤

### 1. 部署 Dashboard

```bash
cd terraform
terraform apply -target="helm_release.kubernetes_dashboard" -var-file="staging.tfvars"
```

部署内容：
- Kubernetes Dashboard v7.10.0（最新稳定版）
- 通过 NodePort 暴露在端口 30443
- 创建 admin ServiceAccount 用于完整集群访问
- 配置资源限制以节省资源

### 2. 获取访问 Token

部署完成后，获取管理员 Token：

```bash
# 方法 1: 直接从 Secret 获取
kubectl -n kubernetes-dashboard get secret dashboard-admin-token -o jsonpath='{.data.token}' | base64 -d

# 方法 2: 使用 kubectl 创建临时 token（Kubernetes 1.24+）
kubectl -n kubernetes-dashboard create token dashboard-admin
```

将输出的 Token 复制保存，稍后登录时需要使用。

### 3. 访问 Dashboard

#### 方式 A: 通过 NodePort 访问（推荐用于远程访问）

1. 获取 VPS 的公网 IP 地址
2. 在浏览器中访问：`https://<VPS_IP>:30443`
3. 选择 "Token" 认证方式
4. 粘贴步骤 2 获取的 Token
5. 点击 "Sign in"

**注意**：由于使用自签名证书，浏览器会显示安全警告。点击 "高级" → "继续访问" 即可。

#### 方式 B: 通过 Port Forward 访问（推荐用于本地访问）

```bash
# 在本地机器上运行
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```

然后访问：`https://localhost:8443`

### 4. 验证部署

检查 Dashboard 是否正常运行：

```bash
# 查看 Dashboard 相关的 Pods
kubectl -n kubernetes-dashboard get pods

# 查看 Dashboard Service
kubectl -n kubernetes-dashboard get svc

# 查看 Dashboard 日志（如遇问题）
kubectl -n kubernetes-dashboard logs -l app.kubernetes.io/name=kubernetes-dashboard
```

预期输出：
- 所有 Pods 状态为 `Running`
- Service `kubernetes-dashboard-kong-proxy` 类型为 `NodePort`，端口 30443

## 常见使用场景

### 查看集群资源
1. 左侧菜单选择 "Workloads" → "Pods"
2. 可以看到所有 namespace 下的 Pods
3. 点击 Pod 名称查看详细信息、日志、事件

### 查看服务状态
1. 左侧菜单选择 "Service" → "Services"
2. 查看所有 Service 的 ClusterIP、端口等信息

### 查看存储卷
1. 左侧菜单选择 "Config and Storage" → "Persistent Volume Claims"
2. 查看 PostgreSQL、MongoDB、Redis 等的持久化存储使用情况

### 查看日志
1. 找到目标 Pod
2. 点击右侧的三个点按钮 → "Logs"
3. 实时查看应用日志

### 执行命令（类似 kubectl exec）
1. 找到目标 Pod
2. 点击右侧的三个点按钮 → "Exec"
3. 在 Shell 中执行命令

## 安全建议

1. **Token 安全**：
   - 不要将 Token 提交到代码仓库
   - 定期轮换 Token
   - 仅在受信任的网络环境下使用

2. **访问控制**：
   - 当前配置使用 `cluster-admin` 角色（完整权限）
   - 生产环境建议创建受限的 ServiceAccount

3. **HTTPS**：
   - 始终通过 HTTPS 访问
   - 考虑配置有效的 TLS 证书（如使用 cert-manager）

## 故障排查

### Dashboard Pod 无法启动

```bash
# 查看 Pod 状态
kubectl -n kubernetes-dashboard get pods

# 查看详细事件
kubectl -n kubernetes-dashboard describe pod <pod-name>

# 查看日志
kubectl -n kubernetes-dashboard logs <pod-name>
```

### 无法访问 30443 端口

1. 检查防火墙规则：
```bash
# 在 VPS 上检查
sudo ufw status
sudo ufw allow 30443/tcp
```

2. 检查 Service：
```bash
kubectl -n kubernetes-dashboard get svc kubernetes-dashboard-kong-proxy
```

### Token 认证失败

1. 确认 Token 是否正确复制（无多余空格）
2. 重新生成 Token：
```bash
kubectl -n kubernetes-dashboard create token dashboard-admin
```

3. 检查 ServiceAccount 和 RBAC：
```bash
kubectl -n kubernetes-dashboard get sa dashboard-admin
kubectl get clusterrolebinding dashboard-admin
```

## 资源占用

Dashboard 配置的资源限制：
- API Server: 100m CPU, 128Mi 内存（请求）/ 250m CPU, 256Mi 内存（限制）
- Web Server: 50m CPU, 64Mi 内存（请求）/ 150m CPU, 128Mi 内存（限制）
- Kong Proxy: 默认配置

总计约 150m CPU 和 192Mi 内存的请求资源。

## 卸载

如需移除 Dashboard：

```bash
cd terraform
terraform destroy -target="helm_release.kubernetes_dashboard" -var-file="staging.tfvars"
terraform destroy -target="kubernetes_cluster_role_binding.dashboard_admin" -var-file="staging.tfvars"
terraform destroy -target="kubernetes_service_account.dashboard_admin" -var-file="staging.tfvars"
terraform destroy -target="kubernetes_manifest.dashboard_namespace" -var-file="staging.tfvars"
```

## 参考资料

- [Kubernetes Dashboard 官方文档](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [Dashboard GitHub](https://github.com/kubernetes/dashboard)
- [Helm Chart](https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard)
