# Project Implementation Status

**SSOT Type**: Implementation Progress & Status
**Scope**: Concrete implementation steps, checklists, and status tracking for specific BRNs.

## Active Projects

- [BRN-004: Staging Deployment](./BRN-004.md) - **Active**
  - **Goal**: Deploy k3s + Vault + Core Platform on Staging VPS.
  - **Status**: Phase 0.x (Bootstrap) Complete. Cloudflare integration in progress (PR #56).

- [BRN-008: CI/CD Architecture - Deploy Verification](./BRN-008-CI-CD-Architecture.md) - **Active (NEW)**
  - **Goal**: 解决 CI/CD 脱节问题 - Atlantis apply 后自动验证部署是否真的成功
  - **Problem**: apply ✓ ≠ deployment success; E2E 测试手动触发，无法反馈到 PR
  - **Solution**: 三层验证模型 (apply → readiness → e2e tests) + PR 评论反馈
  - **Status**: Phase 1 完成 ✅ 框架已交付；Phase 2 待实施 (GitHub Actions 改造)
  - **Deliverables**:
    - E2E 自动化测试框架 (42 个测试)
    - SSOT 文档 (docs/ssot/ops.e2e-regressions.md)
    - 架构设计方案 (BRN-008-CI-CD-Architecture.md)

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
