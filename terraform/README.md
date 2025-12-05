# Infrastructure as Code (Terraform)

**SSOT Type**: Infrastructure State
**Scope**: The single source of truth for all deployed resources (VPS, K8s, Helm Releases).

## Core Files
- `main.tf`: Entry point and Phase orchestration.
- `k3s.tf`: Bootstrapping logic.
- `phases/`: Module definitions for each deployment phase.

## Usage
Refer to [BRN-004 Implementation](../project/BRN-004.md) for deployment instructions.
