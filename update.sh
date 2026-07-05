#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Updating notlight..."
cd "$REPO_DIR"

if ! git pull 2>/dev/null; then
  echo "ERROR: git pull failed. Is this a git clone?"
  exit 1
fi

echo "==> Rebuilding..."
bash install.sh
