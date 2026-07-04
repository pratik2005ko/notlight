#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/quickshell/spotlight"
SYSTEMD_DIR="$HOME/.config/systemd/user"

echo "==> notlight installer"

# 1. Dependencies check
echo "==> Checking dependencies..."

MISSING=""
for cmd in fd g++ wl-copy; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING="$MISSING $cmd"
  fi
done

if ! command -v qs &>/dev/null; then
  echo "ERROR: Quickshell not found. Install it first: https://github.com/Quickshell/Quickshell"
  exit 1
fi

if [ -n "$MISSING" ]; then
  echo "WARNING: Missing commands:$MISSING"
  echo "  Install them with your package manager before using corresponding features."
fi

# 2. Compile YouTube search binary
if [ -f "$REPO_DIR/yt-search.cpp" ]; then
  echo "==> Compiling yt-search..."
  g++ -std=c++17 "$REPO_DIR/yt-search.cpp" -o "$REPO_DIR/yt-search" -lcurl
fi

# 3. Link config
echo "==> Linking config to $CONFIG_DIR"
mkdir -p "$(dirname "$CONFIG_DIR")"
ln -sf "$REPO_DIR" "$CONFIG_DIR"

# 4. Setup systemd service
echo "==> Setting up systemd user service"
mkdir -p "$SYSTEMD_DIR"
cat > "$SYSTEMD_DIR/notlight.service" << 'SERVICE'
[Unit]
Description=notlight — Multi-mode launcher
After=graphical-session.target

[Service]
Type=simple
ExecStart=qs -c spotlight
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
SERVICE

systemctl --user daemon-reload
systemctl --user enable notlight.service
systemctl --user start notlight.service

# 5. Suggest Hyprland keybinding
echo ""
echo "==> All done!"
echo ""
echo "Add this to your Hyprland config to toggle:"
echo '  bind = Alt, Space, exec, ~/.config/quickshell/spotlight/toggle-spotlight'
echo ""
echo "Then reload Hyprland: hyprctl reload"
