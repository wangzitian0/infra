# Project Implementation Status

**SSOT Type**: Implementation Progress & Status
**Scope**: Concrete implementation steps, checklists, and status tracking for specific BRNs.

## Active Projects

- [BRN-004: Staging Deployment](./BRN-004.md) - **Active**
  - **Goal**: Deploy k3s + Vault + Core Platform on Staging VPS.
  - **Status**: Phase 0.x (Bootstrap) Complete. Cloudflare integration in progress (PR #56).

- [BRN-008: Infrastructure SSOT Refactor](./BRN-008.md) - **Active**
  - **Goal**: Consolidate topic-based SSOT docs under `docs/ssot/` and migrate Casdoor admin password to 1Password SSOT (via GitHub Secrets → TF_VAR).
  - **Status**: In progress (see `0.check_now.md` and `docs/change_log/2025-12-12.brn_008_infrastructure_ssot.md`).

## Active Issues

- [ISSUE-2025-12-20: Kubero SSO rollout + emergency access](./ISSUE-2025-12-20.kubero-sso.md) - **Open**

- [PR-336: OpenPanel Analytics L2/L3 Infrastructure](https://github.com/wangzitian0/infra/pull/336) - **In Progress**
  - **Goal**: Deploy OpenPanel analytics platform following L2 (permissions) + L3 (data) + L4 (apps) architecture pattern
  - **Status**: L2 refactor complete (moved password generation to L3), L3 data-staging in progress
  - **Blockers**: Database password synchronization between Terraform and K8s Secrets
  - **Plan**: See [openpanel-deployment-plan.md](./openpanel-deployment-plan.md)

## Archived Projects

(None)

## Related

- [apps/docs/index.md](../../apps/docs/index.md) - Apps documentation index (submodule)

---
*Last updated: 2025-12-22*
