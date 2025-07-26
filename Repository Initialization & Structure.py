#!/bin/bash
set -euo pipefail

# Initialize project structure
mkdir -p byword-infrastructure/{terraform,kubernetes/{base,environments/{development,staging,production},apps/{external-dns,cert-manager,ingress-nginx,monitoring,byword-intake-api}},helm-releases,flux-system,scripts}
cd byword-infrastructure

# Initialize git repository
git init
git checkout -b main

# Create .gitignore
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars

# Kubernetes secrets
*.key
*.crt
*.pem
secrets/

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF
