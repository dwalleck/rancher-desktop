#!/bin/bash
# Rancher Desktop K3s Cache Setup (WSL Version)
# Run this from within WSL/Ubuntu

set -e

VERSION="${1:-v1.33.3+k3s1}"
BASE_URL="https://github.com/k3s-io/k3s/releases/download/$VERSION"

# Determine cache directory (WSL path to Windows LOCALAPPDATA)
USER_PROFILE=$(wslpath "$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')")
CACHE_DIR="$USER_PROFILE/AppData/Local/rancher-desktop/cache/k3s/$VERSION"

echo "========================================"
echo "Rancher Desktop K3s Cache Setup (WSL)"
echo "========================================"
echo ""
echo "Version: $VERSION"
echo "Cache Directory: $CACHE_DIR"
echo ""

# Create cache directory
echo "[1/3] Creating cache directory..."
mkdir -p "$CACHE_DIR"
echo "  ✓ Directory created"

# Download files
echo "[2/3] Downloading k3s files..."
cd "$CACHE_DIR"

FILES=("k3s" "k3s-airgap-images-amd64.tar.zst" "sha256sum-amd64.txt")

for file in "${FILES[@]}"; do
    echo "  Downloading: $file"
    if curl -k -L -f -o "$file" "$BASE_URL/$file"; then
        size=$(du -h "$file" | cut -f1)
        echo "    ✓ Downloaded successfully ($size)"
    else
        echo "    ✗ Failed to download $file"
        exit 1
    fi
done

# Verify files
echo "[3/3] Verifying cached files..."
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        echo "  ✓ $file ($size)"
    else
        echo "  ✗ $file (missing)"
        exit 1
    fi
done

echo ""
echo "========================================"
echo "SUCCESS! K3s files cached successfully."
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Close Rancher Desktop if it's running"
echo "  2. Start Rancher Desktop"
echo "  3. It should now start without downloading k3s"
echo ""
echo "Cache location: $CACHE_DIR"
