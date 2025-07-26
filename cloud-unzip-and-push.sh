#!/bin/bash
set -euo pipefail

# === Configuration ===
REPO_URL="https://github.com/Shauny123/byword-infrastructure.git"
ZIP_URL="https://YOUR_PUBLIC_ZIP_LINK_HERE"  # Use local path if already in cloud
TEMP_DIR="temp-infra"
ZIP_NAME="byword-infrastructure.zip"
REPO_NAME="byword-infrastructure"

echo "🔁 Cloning repository..."
git clone "$REPO_URL" "$TEMP_DIR"
cd "$TEMP_DIR"

echo "📦 Downloading and extracting infrastructure package..."
curl -L -o "$ZIP_NAME" "$ZIP_URL"
unzip -o "$ZIP_NAME"

echo "🧹 Cleaning up any .DS_Store or temp files..."
find . -name ".DS_Store" -delete

echo "🧪 Optionally formatting Terraform files..."
find . -name "*.tf" -exec terraform fmt {} \;

echo "📤 Committing and pushing back to GitHub..."
git add .
git commit -m "Automated unzip + repo sync"
git push origin main

echo "✅ Done. Repo updated with contents from ZIP."
