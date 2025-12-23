# Vault Secrets Engines Configuration
#
# Purpose: Configure Vault secrets engines (KV + database)
# 
# Architecture (after refactor):
# - Platform: Only creates Vault mounts (this file)
# - Data: Generates passwords, stores in Vault KV, configures Database Engine
# - Applications: Uses dynamic credentials from Vault
#
# Note: Password generation and Database Engine config moved to Data (Issue #336)

# =============================================================================
# Vault Secrets Engines (IaC - replaces manual vault secrets enable)
# =============================================================================

# Import existing Vault mounts if they exist (Handle drift from state rm)
import {
  to = vault_mount.kv
  id = "secret"
}

import {
  to = vault_mount.database
  id = "database"
}

# KV v2 secrets engine for static secrets
resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv-v2"
  description = "KV v2 secrets engine for database credentials"

  lifecycle {
    precondition {
      condition     = var.vault_root_token != ""
      error_message = "vault_root_token is required for Vault secrets engine configuration."
    }

    postcondition {
      condition     = self.accessor != ""
      error_message = "Vault KV mount failed - accessor is empty. Check Vault connectivity and permissions."
    }
  }
}

# Database secrets engine for dynamic credentials
resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "Database secrets engine for dynamic credentials (configured by Data layer)"
}

# =============================================================================
# Outputs (for Data layer to consume via terraform_remote_state)
# =============================================================================

output "vault_kv_mount" {
  description = "Vault KV mount path"
  value       = vault_mount.kv.path
}

output "vault_database_mount" {
  description = "Vault database secrets engine mount path"
  value       = vault_mount.database.path
}

# SSOT for secret names (Data layer uses these to know where to store credentials)
output "vault_db_secrets" {
  description = "Map of database names to their Vault KV secret names"
  value       = local.vault_db_secrets
}

output "vault_secret_paths" {
  description = "Map of database names to their full Vault KV paths"
  value       = local.vault_secret_paths
}
