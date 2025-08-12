#!/bin/bash
set -e

REPO_URL="https://raw.githubusercontent.com/mobilecause/imagemagick/main"

echo "Installing ImageMagick repository..."

# Download repo config with priority=9
curl -fsSL "$REPO_URL/imagemagick-repo/client-setup/imagemagick-build.repo" \\
    -o "/etc/yum.repos.d/imagemagick-build.repo"

# Refresh cache
dnf clean all
dnf makecache

echo "✅ ImageMagick repository installed with priority 9!"
echo "📦 Install ImageMagick: dnf install ImageMagick ImageMagick-devel"
echo "🔍 Verify source: dnf info ImageMagick"
