# terraform/envs

Environment-specific tfvars templates. Copy an example (e.g., `staging.tfvars.example`) to `*.tfvars`, fill in host/SSH/secret values locally, and keep real tfvars out of git.

Key variables: `env_prefix` (e.g., `x-staging`), `base_domain`, Cloudflare secrets.
