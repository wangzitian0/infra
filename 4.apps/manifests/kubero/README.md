# Kubero Manifests

Official Kubero Operator manifests from [kubero-dev/kubero-operator](https://github.com/kubero-dev/kubero-operator).

## Files

| File | Description |
|------|-------------|
| `operator.yaml` | CRDs + Operator Deployment (~50 resources) |
| `kubero-ui-sample.yaml` | Sample Kubero CR for reference |

## Update Process

To update the operator manifest:

```bash
curl -sL "https://raw.githubusercontent.com/kubero-dev/kubero-operator/main/deploy/operator.yaml" \
  -o 4.apps/manifests/kubero/operator.yaml
```

## Source

- Repository: https://github.com/kubero-dev/kubero-operator
- Deploy path: `deploy/operator.yaml`

---
*Last updated: 2025-12-08*
