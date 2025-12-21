# =============================================================================
# ClickHouse User & Database Management for SigNoz
# Purpose: Create dedicated user and databases for SigNoz observability stack
# Architecture:
# - Generate random password in L3
# - Store in Vault at secret/data/signoz
# - Create user in ClickHouse via HTTP API (curl)
# 
# Note: Using null_resource + curl because clickhousedbops provider requires
# WriteOnly attributes (TF 1.11+) which is incompatible with Atlantis TF 1.6.6
# =============================================================================

# 1. Generate Password
resource "random_password" "signoz_clickhouse" {
  length  = 24
  special = false
}

# 2. Store in Vault (L3 writes to L2's Vault KV mount)
resource "vault_kv_secret_v2" "signoz_clickhouse" {
  mount               = data.terraform_remote_state.l2_platform.outputs.vault_kv_mount
  name                = "signoz"
  delete_all_versions = true

  data_json = jsonencode({
    username = "signoz"
    password = random_password.signoz_clickhouse.result
    host     = "clickhouse.${local.namespace_name}.svc.cluster.local"
    port     = "9000"
    database = "signoz_traces"
  })
}

# 3. Create SigNoz User and Databases via ClickHouse HTTP API
# Uses curl to execute SQL statements directly
resource "null_resource" "signoz_clickhouse_setup" {
  triggers = {
    # Re-run if password changes
    password_hash = sha256(random_password.signoz_clickhouse.result)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    
    # Environment variables to avoid exposing secrets in command line
    environment = {
      CH_HOST     = "clickhouse.${local.namespace_name}.svc.cluster.local"
      CH_PORT     = "8123"
      CH_USER     = "default"
      CH_PASSWORD = data.vault_kv_secret_v2.clickhouse.data["password"]
      SIGNOZ_USER = "signoz"
      SIGNOZ_PASS = random_password.signoz_clickhouse.result
    }

    command = <<-EOT
      set -e
      
      # Helper function to execute ClickHouse query
      ch_query() {
        curl -sS --fail -X POST \
          "http://$CH_HOST:$CH_PORT/?user=$CH_USER&password=$CH_PASSWORD" \
          -d "$1"
      }
      
      echo "Creating SigNoz user..."
      ch_query "CREATE USER IF NOT EXISTS $SIGNOZ_USER IDENTIFIED BY '$SIGNOZ_PASS';"
      
      echo "Creating SigNoz databases..."
      ch_query "CREATE DATABASE IF NOT EXISTS signoz_traces;"
      ch_query "CREATE DATABASE IF NOT EXISTS signoz_metrics;"
      ch_query "CREATE DATABASE IF NOT EXISTS signoz_logs;"
      
      echo "Granting privileges..."
      ch_query "GRANT ALL ON signoz_traces.* TO $SIGNOZ_USER;"
      ch_query "GRANT ALL ON signoz_metrics.* TO $SIGNOZ_USER;"
      ch_query "GRANT ALL ON signoz_logs.* TO $SIGNOZ_USER;"
      
      echo "SigNoz ClickHouse setup complete!"
    EOT
  }

  depends_on = [
    random_password.signoz_clickhouse,
    vault_kv_secret_v2.signoz_clickhouse
  ]
}
