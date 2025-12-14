# L2 Platform Variables (Vault)
# Populated via TF_VAR_* from 1.bootstrap/2.atlantis.tf

variable "kubeconfig_path" {
  description = "Path to kubeconfig file (set via TF_VAR_kubeconfig_path in Atlantis)"
  type        = string
  default     = ""
}

variable "env_prefix" {
  description = "Environment prefix for domain names (e.g., 'staging', 'x-staging', or empty for prod)"
  type        = string
  default     = ""
}

variable "base_domain" {
  description = "Base domain for business/production services"
  type        = string
  default     = "truealpha.club"
}

variable "internal_domain" {
  description = "Internal/infra domain for platform services (dashboard, vault, kubero, auth)"
  type        = string
  default     = "zitian.party"
}

variable "vault_chart_version" {
  description = "Vault Helm chart version"
  type        = string
  default     = "0.31.0"
}

variable "vault_image_tag" {
  description = "Vault image tag"
  type        = string
  default     = "1.20.4"
}

variable "vault_postgres_password" {
  description = "PostgreSQL password for Vault storage backend (from GitHub Secret via L1)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.vault_postgres_password) >= 16
    error_message = "vault_postgres_password must be at least 16 characters."
  }
}

variable "kubero_ui_image_tag" {
  description = "Kubero UI image tag. Pin this to a fixed version for reproducible deploys (avoid 'latest')."
  type        = string
  default     = "latest"
}

variable "kubero_ui_image_pull_policy" {
  description = "Kubero UI image pull policy. Use IfNotPresent for stability; avoid Always unless debugging."
  type        = string
  default     = "IfNotPresent"
}


variable "namespaces" {
  description = "Map of namespace names"
  type        = map(string)
  default = {
    nodep         = "nodep"
    security      = "security"
    apps          = "apps"
    data          = "data"
    ingestion     = "ingestion"
    kubero        = "kubero"
    observability = "observability"
    platform      = "platform"
  }
}

variable "vps_host" {
  description = "VPS host IP for DNS records (set via TF_VAR_vps_host in Atlantis)"
  type        = string
  default     = ""
}

# ============================================================
# OAuth2-Proxy (GitHub OAuth)
# ============================================================

variable "github_oauth_client_id" {
  description = "GitHub OAuth App Client ID (set via TF_VAR_github_oauth_client_id)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth App Client Secret (set via TF_VAR_github_oauth_client_secret)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_oauth_org" {
  description = "GitHub organization to restrict access (leave empty for any GitHub user)"
  type        = string
  default     = ""
}

# ============================================================
# Cloudflare (for Casdoor DNS)
# ============================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API Token for DNS record management (set via TF_VAR_cloudflare_api_token)"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================
# Casdoor SSO
# ============================================================

variable "casdoor_admin_password" {
  description = "Casdoor admin password (from 1Password via GitHub Secret CASDOOR_ADMIN_PASSWORD)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.casdoor_admin_password == "" || length(var.casdoor_admin_password) >= 12
    error_message = "casdoor_admin_password must be at least 12 characters (or empty to disable Casdoor)."
  }
}

variable "enable_portal_sso_gate" {
  description = "Enable Casdoor-based SSO gate for platform portals (Vault/Dashboard/Kubero) via OAuth2-Proxy; keep false until Casdoor + client credentials are ready to avoid lockout."
  type        = bool
  default     = false
}

variable "casdoor_portal_client_id" {
  description = "Casdoor application Client ID used by the portal SSO gate (OAuth2-Proxy)."
  type        = string
  default     = "portal-gate"
}

variable "casdoor_portal_client_secret" {
  description = "Casdoor application Client Secret used by the portal SSO gate (OAuth2-Proxy). Leave blank to auto-generate."
  type        = string
  sensitive   = true
  default     = ""
}

variable "casdoor_vault_oidc_client_secret" {
  description = "Vault OIDC Client Secret in Casdoor. Leave blank to auto-generate. Store in 1Password for disaster recovery."
  type        = string
  sensitive   = true
  default     = ""
}

variable "casdoor_dashboard_oidc_client_secret" {
  description = "Dashboard OIDC Client Secret in Casdoor. Leave blank to auto-generate. Store in 1Password for disaster recovery."
  type        = string
  sensitive   = true
  default     = ""
}

variable "casdoor_kubero_oidc_client_secret" {
  description = "Kubero OIDC Client Secret in Casdoor. Leave blank to auto-generate. Store in 1Password for disaster recovery."
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================
# Vault Configuration
# ============================================================

variable "vault_root_token" {
  description = "Vault root token for database secrets engine config (from 1Password via GitHub Secret VAULT_ROOT_TOKEN)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.vault_root_token == "" || length(var.vault_root_token) > 20
    error_message = "vault_root_token must be a valid Vault token (or empty to skip Vault config)."
  }
}

variable "vault_address" {
  description = "Vault server address. Default is internal K8s DNS for Atlantis. Set to http://localhost:8200 for GitHub Actions with port-forward."
  type        = string
  default     = "http://vault.platform.svc.cluster.local:8200"
}

# ============================================================
# One-Auth (SSO Gate Switch)
# ============================================================

variable "enable_one_auth" {
  description = "Enable SSO gate (Traefik middleware) for L2 ingresses; turn on only after verifying base L2 endpoints are reachable."
  type        = bool
  default     = false
  # NOTE: Cross-variable validation (OAuth2-Proxy prerequisites) is in 99.one-auth.tf precondition
}

# ============================================================
# Vault Database Backend (L3 PostgreSQL)
# ============================================================

variable "enable_postgres_backend" {
  description = "Enable Vault database backend for L3 PostgreSQL. Set to true ONLY after L3 PostgreSQL is deployed and running."
  type        = bool
  default     = false
  # Two-phase deploy:
  # 1. Apply L2 with enable_postgres_backend=false (creates vault_mount, stores password)
  # 2. Apply L3 (PostgreSQL deployed)
  # 3. Apply L2 with enable_postgres_backend=true (creates database connection)
}
