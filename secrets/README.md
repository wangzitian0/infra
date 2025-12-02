# Secrets Management

This directory contains environment variable templates for all environments.

## Files

- `.env.example` - Template file with all required environment variables
- `.env.{environment}` - Actual configuration files (not committed to Git)

## Usage

### Option 1: Using Infisical (Recommended)

```bash
# Login to Infisical
infisical login

# Export secrets for an environment
../scripts/deploy/export-secrets.sh dev
```

### Option 2: Manual Configuration

```bash
# Copy template
cp .env.example .env.dev

# Edit and fill in values
vim .env.dev
```

## Security

⚠️ **NEVER** commit actual `.env` files to Git!

Only `.env.example` should be in version control.

## Environment Variables Guide

See `.env.example` for a complete list of required variables and their descriptions.

### Critical Variables

- `PEG_ENV` - Environment identifier (dev/test/staging/prod)
- `DB_TABLE_PREFIX` - Database isolation prefix
- `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD` - Neo4j connection
- `POSTGRES_*` - PostgreSQL configuration
- `CLOUDFLARE_API_TOKEN` - For Terraform DNS management

### Best Practices

1. Use strong, unique passwords for each environment
2. Rotate credentials regularly (especially for production)
3. Never share production credentials via insecure channels
4. Use Infisical for team collaboration on secrets
