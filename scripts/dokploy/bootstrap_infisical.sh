#!/usr/bin/env bash
set -euo pipefail

# Bootstrap self-hosted Infisical on Dokploy via API (idempotent-ish).
# Requires: curl, jq

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_COMPOSE_FILE="${REPO_ROOT}/compose/platform/infisical.yml"

log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
}

fatal() {
  echo "Error: $*" >&2
  exit 1
}

need_bin() {
  command -v "$1" >/dev/null 2>&1 || fatal "Missing dependency: $1"
}

need_bin curl
need_bin jq

# Defaults
DOKPLOY_API_URL="${DOKPLOY_API_URL:-https://cloud.truealpha.club/api}"
DOKPLOY_PROJECT_NAME="${DOKPLOY_PROJECT_NAME:-truealpha}"
DOKPLOY_ENVIRONMENT_NAME="${DOKPLOY_ENVIRONMENT_NAME:-platform}"
DOKPLOY_COMPOSE_NAME="${DOKPLOY_COMPOSE_NAME:-infisical}"
DOKPLOY_COMPOSE_APP_NAME="${DOKPLOY_COMPOSE_APP_NAME:-${DOKPLOY_COMPOSE_NAME}-${DOKPLOY_ENVIRONMENT_NAME}}"
DOKPLOY_COMPOSE_FILE="${DOKPLOY_COMPOSE_FILE:-$DEFAULT_COMPOSE_FILE}"
DOKPLOY_SSH_KEY_NAME="${DOKPLOY_SSH_KEY_NAME:-infra-ssh}"
DOKPLOY_SERVER_NAME="${DOKPLOY_SERVER_NAME:-truealpha-platform}"
DOKPLOY_SERVER_PORT="${DOKPLOY_SERVER_PORT:-22}"
DOKPLOY_SERVER_TYPE="${DOKPLOY_SERVER_TYPE:-deploy}"
DOKPLOY_FORCE_DEPLOY="${DOKPLOY_FORCE_DEPLOY:-0}"

INFISICAL_HOST="${INFISICAL_HOST:-secrets.truealpha.club}"
INFISICAL_REDIS_PASSWORD="${INFISICAL_REDIS_PASSWORD:-infisical}"
INFISICAL_TRAEFIK_NETWORK="${INFISICAL_TRAEFIK_NETWORK:-traefik}"
INFISICAL_AUTH_SECRET="${INFISICAL_AUTH_SECRET:-$INFISICAL_ENCRYPTION_KEY}"
INFISICAL_TELEMETRY_DISABLED="${INFISICAL_TELEMETRY_DISABLED:-true}"
INFISICAL_LICENSE_KEY="${INFISICAL_LICENSE_KEY:-}"
export INFISICAL_HOST INFISICAL_REDIS_PASSWORD INFISICAL_TRAEFIK_NETWORK INFISICAL_AUTH_SECRET INFISICAL_TELEMETRY_DISABLED INFISICAL_LICENSE_KEY

# Required inputs
REQUIRED_VARS=(
  DOKPLOY_API_KEY
  DOKPLOY_SERVER_IP
  DOKPLOY_SERVER_USERNAME
  DOKPLOY_SSH_PRIVATE_KEY
  DOKPLOY_SSH_PUBLIC_KEY
  INFISICAL_ENCRYPTION_KEY
  INFISICAL_ADMIN_EMAIL
  INFISICAL_ADMIN_PASSWORD
  INFISICAL_POSTGRES_USER
  INFISICAL_POSTGRES_PASSWORD
  INFISICAL_POSTGRES_DB
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    fatal "Missing required environment variable: $var"
  fi
done

[ -f "$DOKPLOY_COMPOSE_FILE" ] || fatal "Compose file not found: $DOKPLOY_COMPOSE_FILE"

api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local headers=(-H "x-api-key: ${DOKPLOY_API_KEY}")
  if [ -n "$body" ]; then
    headers+=(-H "content-type: application/json")
    curl -sS -X "$method" "${DOKPLOY_API_URL}${path}" "${headers[@]}" -d "$body"
  else
    curl -sS -X "$method" "${DOKPLOY_API_URL}${path}" "${headers[@]}"
  fi
}

extract_first_id() {
  jq -r 'first(.organizationId // .id // .projectId // .environmentId // .composeId // .serverId // .sshKeyId // .applicationId // .postgresId // .redisId // .mongoId // .mysqlId // .mariadbId)'
}

# 1) Organization
ORG_ID="${DOKPLOY_ORGANIZATION_ID:-}"
if [ -z "$ORG_ID" ]; then
  log "Fetching organizations"
  ORG_ID=$(api GET "/organization.all" | jq -r '.[0].organizationId // .[0].id // empty')
fi
[ -n "$ORG_ID" ] || fatal "Unable to resolve organization id"
log "Using organization: $ORG_ID"

# 2) SSH Key
log "Ensuring SSH key: $DOKPLOY_SSH_KEY_NAME"
SSH_KEY_ID=$(api GET "/sshKey.all" | jq -r --arg name "$DOKPLOY_SSH_KEY_NAME" '.[] | select(.name==$name) | (.sshKeyId // .id)' | head -n1)
if [ -z "$SSH_KEY_ID" ]; then
  body=$(jq -n \
    --arg name "$DOKPLOY_SSH_KEY_NAME" \
    --arg priv "$DOKPLOY_SSH_PRIVATE_KEY" \
    --arg pub "$DOKPLOY_SSH_PUBLIC_KEY" \
    --arg org "$ORG_ID" \
    '{name:$name, description:"Provisioned by automation", privateKey:$priv, publicKey:$pub, organizationId:$org}')
  SSH_KEY_ID=$(api POST "/sshKey.create" "$body" | extract_first_id)
  [ -n "$SSH_KEY_ID" ] || fatal "Failed to create SSH key"
  log "Created SSH key id: $SSH_KEY_ID"
else
  log "Reusing SSH key id: $SSH_KEY_ID"
fi

# 3) Server
log "Ensuring server: $DOKPLOY_SERVER_NAME"
SERVER_ID=$(api GET "/server.all" | jq -r --arg name "$DOKPLOY_SERVER_NAME" '.[] | select(.name==$name) | (.serverId // .id)' | head -n1)
if [ -z "$SERVER_ID" ]; then
  body=$(jq -n \
    --arg name "$DOKPLOY_SERVER_NAME" \
    --arg ip "$DOKPLOY_SERVER_IP" \
    --argjson port "$DOKPLOY_SERVER_PORT" \
    --arg user "$DOKPLOY_SERVER_USERNAME" \
    --arg key "$SSH_KEY_ID" \
    --arg type "$DOKPLOY_SERVER_TYPE" \
    '{name:$name, ipAddress:$ip, port:$port, username:$user, sshKeyId:$key, serverType:$type, description:"Provisioned by automation"}')
  SERVER_ID=$(api POST "/server.create" "$body" | extract_first_id)
  [ -n "$SERVER_ID" ] || fatal "Failed to create server"
  log "Created server id: $SERVER_ID"
else
  log "Reusing server id: $SERVER_ID"
fi

# 4) Project + Environment
log "Ensuring project: $DOKPLOY_PROJECT_NAME"
PROJECTS=$(api GET "/project.all")
PROJECT_ID=$(echo "$PROJECTS" | jq -r --arg name "$DOKPLOY_PROJECT_NAME" '.[] | select(.name==$name) | (.projectId // .id)' | head -n1)
if [ -z "$PROJECT_ID" ]; then
  body=$(jq -n --arg name "$DOKPLOY_PROJECT_NAME" '{name:$name, description:"truealpha infra platform"}')
  PROJECT_ID=$(api POST "/project.create" "$body" | extract_first_id)
  [ -n "$PROJECT_ID" ] || fatal "Failed to create project"
  log "Created project id: $PROJECT_ID"
  PROJECTS=$(api GET "/project.all")
fi

ENVIRONMENT_ID=$(echo "$PROJECTS" | jq -r --arg pid "$PROJECT_ID" --arg env "$DOKPLOY_ENVIRONMENT_NAME" '
  .[] | select((.projectId // .id)==$pid) | .environments[]? | select(.name==$env) | (.environmentId // .id)
') | head -n1

if [ -z "$ENVIRONMENT_ID" ]; then
  body=$(jq -n --arg name "$DOKPLOY_ENVIRONMENT_NAME" --arg pid "$PROJECT_ID" '{name:$name, projectId:$pid, description:"platform baseline"}')
  ENVIRONMENT_ID=$(api POST "/environment.create" "$body" | extract_first_id)
  [ -n "$ENVIRONMENT_ID" ] || fatal "Failed to create environment"
  log "Created environment id: $ENVIRONMENT_ID"
  PROJECTS=$(api GET "/project.all")
fi
log "Using environment id: $ENVIRONMENT_ID"

# 5) Render compose (envsubst on ${VAR})
TMP_COMPOSE="$(mktemp)"
if command -v envsubst >/dev/null 2>&1; then
  envsubst <"$DOKPLOY_COMPOSE_FILE" >"$TMP_COMPOSE"
else
  # Minimal fallback: replace ${VAR} manually for required ones
  python - <<'PY' "$DOKPLOY_COMPOSE_FILE" "$TMP_COMPOSE" || exit 1
import os, sys
src, dst = sys.argv[1], sys.argv[2]
data = open(src, "r", encoding="utf-8").read()
for key, val in os.environ.items():
    data = data.replace(f"${{{key}}}", val)
open(dst, "w", encoding="utf-8").write(data)
PY
fi
COMPOSE_CONTENT="$(cat "$TMP_COMPOSE")"
rm -f "$TMP_COMPOSE"

# 6) Compose create/update
PROJECTS=${PROJECTS:-$(api GET "/project.all")}
COMPOSE_ID=$(echo "$PROJECTS" | jq -r --arg pid "$PROJECT_ID" --arg env "$ENVIRONMENT_ID" --arg name "$DOKPLOY_COMPOSE_NAME" '
  .[] | select((.projectId // .id)==$pid)
    | .environments[]? | select((.environmentId // .id)==$env)
    | .compose[]? | select(.name==$name) | (.composeId // .id)
') | head -n1

if [ -n "$COMPOSE_ID" ]; then
  log "Updating compose: $DOKPLOY_COMPOSE_NAME ($COMPOSE_ID)"
  body=$(jq -n \
    --arg id "$COMPOSE_ID" \
    --arg cf "$COMPOSE_CONTENT" \
    '{composeId:$id, composeFile:$cf, name:null, description:null}')
  api POST "/compose.update" "$body" >/dev/null
else
  log "Creating compose: $DOKPLOY_COMPOSE_NAME"
  body=$(jq -n \
    --arg name "$DOKPLOY_COMPOSE_NAME" \
    --arg env "$ENVIRONMENT_ID" \
    --arg server "$SERVER_ID" \
    --arg app "$DOKPLOY_COMPOSE_APP_NAME" \
    --arg cf "$COMPOSE_CONTENT" \
    '{name:$name, environmentId:$env, serverId:$server, appName:$app, composeType:"docker-compose", composeFile:$cf, description:"Infisical self-hosted"}')
  COMPOSE_ID=$(api POST "/compose.create" "$body" | extract_first_id)
  [ -n "$COMPOSE_ID" ] || fatal "Failed to create compose"
  log "Created compose id: $COMPOSE_ID"
fi

# 7) Deploy compose
if [ "$DOKPLOY_FORCE_DEPLOY" != "0" ] || [ -n "$COMPOSE_ID" ]; then
  log "Triggering deploy for compose $COMPOSE_ID"
  body=$(jq -n --arg id "$COMPOSE_ID" '{composeId:$id, title:"deploy via automation", description:"Infisical bootstrap"}')
  api POST "/compose.deploy" "$body" >/dev/null
  log "Deploy request sent"
fi

log "Done. Compose ID: $COMPOSE_ID; Environment ID: $ENVIRONMENT_ID; Server ID: $SERVER_ID"
