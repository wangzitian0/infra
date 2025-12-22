# L2 Platform Layer Configuration

# Include root configuration
include "root" {
  path = find_in_parent_folders()
}

# Layer-specific configuration
# Phase 1: Backend migration only
# Phase 2: Will add dependency blocks for L1 outputs

# Note: State key override is automatic via parent config
# Key will be: k3s/platform.tfstate
