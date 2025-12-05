# 3.computing (Runtime & PaaS / Layer 3)

**Scope**:
- **Workload Management**: Kubero (PaaS Controller).
- **UI**: Kubernetes Dashboard, Kubero UI.
- **Namespace**: `kubero` (for PaaS), `kubernetes-dashboard`.

## Components (Phase 1.x)

### 1. Kubernetes Dashboard
Official Web UI for cluster management.
- **Access**: NodePort 30443 (staging).
- **Auth**: Token-based (ServiceAccount).

**Quick Start**:
1. Deploy: `terraform apply -target="module.computing"`
2. Get Token:
   ```bash
   kubectl -n kubernetes-dashboard create token dashboard-admin
   ```
3. Access: `https://<VPS_IP>:30443`

### 2. Kubero (PaaS)
*Status: Planned*
- Provides Heroku-like GitOps experience.
- Controller manages App/Pipeline/Service.

## Dependencies
- Requires `1.nodep` (Cluster).
- Requires `2.env_and_networking` (Secrets/Ingress).
