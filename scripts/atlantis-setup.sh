#!/bin/bash
set -euo pipefail

# This script prepares the Atlantis environment by:
# 1. Generating backend.tfvars from templates (injecting R2_BUCKET)
# 2. Fetching kubeconfig from VPS (for kubectl/helm providers)

# --- 1. Generate Backend Config ---
# Determines which template to use based on WORKSPACE or specific file existence
TEMPLATE_FILE=""

# Check if we are in a known workflow context or infer from file
if [ -n "${1:-}" ]; then
    TEMPLATE_FILE="$1"
elif [ -f "envs/${WORKSPACE}.backend.tfvars.template" ]; then
    TEMPLATE_FILE="envs/${WORKSPACE}.backend.tfvars.template"
elif [ -f "envs/infra.backend.tfvars.template" ] && [ "${WORKFLOW:-infra}" == "infra" ]; then
    # Default fallback for infra workflow if not matched by workspace name (e.g. default)
    TEMPLATE_FILE="envs/infra.backend.tfvars.template"
fi

if [ -n "${TEMPLATE_FILE}" ]; then
    echo "Generating backend.tfvars from ${TEMPLATE_FILE}..."
    sed -e "s|{{ENV}}|${WORKSPACE}|g" \
        -e "s|PLACEHOLDER_BUCKET|${R2_BUCKET}|g" \
        -e "s|PLACEHOLDER_ACCOUNT_ID|${R2_ACCOUNT_ID}|g" \
        "${TEMPLATE_FILE}" > backend.tfvars
else
    echo "No backend template found. Initializing without backend.tfvars (assuming default or pre-configured)."
fi

# --- 2. Fetch Kubeconfig ---
# Only if SSH key and Host are available
if [ -n "${TF_VAR_ssh_private_key:-}" ] && [ -n "${TF_VAR_vps_host:-}" ]; then
    echo "Fetching kubeconfig from ${TF_VAR_vps_host}..."
    mkdir -p output
    
    SSH_KEY_FILE="/tmp/atlantis_id_rsa"
    echo "${TF_VAR_ssh_private_key}" > "${SSH_KEY_FILE}"
    chmod 600 "${SSH_KEY_FILE}"
    
    SSH_PORT="${TF_VAR_ssh_port:-22}"
    SSH_USER="${TF_VAR_vps_user:-root}"
    
    # Fetch kubeconfig
    if ssh -i "${SSH_KEY_FILE}" -o StrictHostKeyChecking=no -p "${SSH_PORT}" "${SSH_USER}@${TF_VAR_vps_host}" "cat /etc/rancher/k3s/k3s.yaml" > output/truealpha-k3s-kubeconfig.yaml; then
        echo "Kubeconfig fetched."
        # Replace localhost with public IP
        sed -i "s/127.0.0.1/${TF_VAR_vps_host}/g" output/truealpha-k3s-kubeconfig.yaml
        chmod 600 output/truealpha-k3s-kubeconfig.yaml
    else
        echo "WARNING: Failed to fetch kubeconfig. Providers dependent on it may fail."
    fi
    
    rm -f "${SSH_KEY_FILE}"
else
    echo "Skipping kubeconfig fetch (SSH key or Host variable missing)."
fi
