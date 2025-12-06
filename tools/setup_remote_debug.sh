#!/bin/bash
set -e

# Usage: ./tools/setup_remote_debug.sh <VPS_HOST> [VPS_USER]
# Example: ./tools/setup_remote_debug.sh 1.2.3.4 root

VPS_HOST="${1:-$VPS_HOST}"
VPS_USER="${2:-root}"

if [ -z "$VPS_HOST" ]; then
    echo "Error: VPS_HOST is required."
    echo "Usage: $0 <VPS_HOST> [VPS_USER]"
    exit 1
fi

echo "🚀 Setting up remote debugging on $VPS_USER@$VPS_HOST..."

# 1. Install dependencies on Remote
echo "📦 Installing Terraform & Tools on Main VPS..."
ssh "$VPS_USER@$VPS_HOST" "bash -s" << 'EOF'
    set -e
    
    # 1. Create tf_tester user
    if ! id -u tf_tester >/dev/null 2>&1; then
        useradd -m -s /bin/bash tf_tester
        echo "✅ User tf_tester created."
        # Add to sudoers (passwordless) for debugging convenience
        echo "tf_tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tf_tester
        chmod 0440 /etc/sudoers.d/tf_tester
    fi

    # 2. Install Terraform (if missing)
    if ! command -v terraform >/dev/null; then
        echo "⬇️ Installing Terraform..."
        apt-get update && apt-get install -y gnupg software-properties-common curl
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
        apt-get update && apt-get install -y terraform
    fi
    
    # 3. Install Git & rsync
    apt-get install -y git rsync
    
    # 4. Create directory
    mkdir -p /home/tf_tester/infra
    chown -R tf_tester:tf_tester /home/tf_tester
EOF

# 2. Sync Code (rsync)
echo "🔄 Syncing local code to /home/tf_tester/infra..."
rsync -avz --exclude '.git' --exclude '.terraform' --exclude 'output' \
    ./ "$VPS_USER@$VPS_HOST:/home/tf_tester/infra/"

# 3. Fix Permissions
echo "🔧 Fixing permissions..."
ssh "$VPS_USER@$VPS_HOST" "chown -R tf_tester:tf_tester /home/tf_tester/infra"

echo "✅ Done! You can now log in and run terraform locally on the VPS:"
echo "   ssh $VPS_USER@$VPS_HOST"
echo "   su - tf_tester"
echo "   cd infra/terraform"
echo "   export AWS_ACCESS_KEY_ID=..."
echo "   terraform init && terraform plan"
