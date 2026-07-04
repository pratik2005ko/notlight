# notlight

A multi-mode launcher for Hyprland built with [Quickshell](https://github.com/Quickshell/Quickshell).

## Features

- **App search** (default mode) — instant filtering of installed applications by name, comment, or categories
- **File search** (`/f query`) — fast file search via `fd`, categorized by extension (video, audio, image, doc, directory, etc.)
- **AI answer** (`/s query`) — ask Groq AI for natural-language answers with syntax-highlighted code blocks and per-block copy buttons
- **Google search** (`/g query`) — open search query in browser (Enter to trigger)
- **YouTube inline search** (`/yt query`) — search videos inline, preview results with duration, launch in browser on Enter
- **Web mode** (`/w code`) — open a saved URL by its short name
- **Capture mode** (`/cap url code`) — save a URL with a short name for quick access
- **Shell mode** (`/sh query`) — fuzzy search and launch predefined terminal commands
- **Shell capture** (`/sc code command`) — save a terminal command with a short code name
- **Alias system** — right-click an app result to set/remove a custom alias (boosts to top of search results)
- **macOS-style spring animation** — centered panel with scale bounce on open/close

## Quick Install

```bash
git clone https://github.com/pratik2005ko/notlight.git
cd notlight
chmod +x install.sh && ./install.sh
```

## Manual Install

### Dependencies

- [Quickshell](https://github.com/Quickshell/Quickshell)
- `fd` — file search (`/f`)
- `kitty` — terminal for terminal apps and directory browser (yazi)
- `mpv` — video/audio playback
- `yazi` — directory file browser
- `wl-copy` — clipboard copy for code blocks
- `libcurl` + `nlohmann-json` — YouTube search (compiled binary)

### Steps

```bash
git clone https://github.com/pratik2005ko/notlight.git
cd notlight
g++ -std=c++17 yt-search.cpp -o yt-search -lcurl
ln -sf "$PWD" ~/.config/quickshell/spotlight
```

### Systemd Service (auto-start)

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/notlight.service << 'EOF'
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
EOF

systemctl --user daemon-reload
systemctl --user enable --now notlight.service
```

### Keybinding

Add to your Hyprland config:

```conf
bind = Alt, Space, exec, ~/.config/quickshell/spotlight/toggle-spotlight
```

## Configuration

### API Key (required for AI answer mode)

On first use in `/s` mode, the UI will prompt you to enter your Groq API key. You can also create the file manually:

```json
# ~/.config/quickshell/spotlight-data/secrets.json
{"groq_key": "gsk_your_key_here"}
```

## Usage

| Prefix | Mode | Action |
|--------|------|--------|
| *(none)* | App search | Filter installed apps by name/comment/categories |
| `/f` | File search | Search files by name via `fd` |
| `/s` | AI answer | Ask Groq AI (Enter to send) |
| `/g` | Google search | Open Google search in browser (Enter to send) |
| `/yt` | YouTube | Search videos inline (Enter to send, Enter on result to open) |
| `/w` | Web | Open a saved URL by short name (Enter to open) |
| `/cap` | Capture | Save a URL with a short code name (Enter to save) |
| `/sh` | Shell | Fuzzy search predefined terminal commands (Enter to launch in kitty) |
| `/sc` | Shell capture | Save a terminal command with a short code name (Enter to save) |

Both `/` and `\` work as prefix characters (`\f`, `\s`, etc.). All data is stored in `~/.config/quickshell/spotlight-data/` (separate from the repo).

In AI answer mode, code blocks in responses have individual **copy** buttons — click to copy that block to clipboard via `wl-copy`.

## Uninstall

```bash
# Stop and disable service
systemctl --user stop notlight.service
systemctl --user disable notlight.service
rm -f ~/.config/systemd/user/notlight.service
systemctl --user daemon-reload

# Remove data (captures, commands, aliases, API key)
rm -rf ~/.config/quickshell/spotlight-data
rm -f ~/.config/quickshell/spotlight

# Remove repo (if installed via git clone)
# rm -rf /path/to/notlight
```

## Configuration Files

All data is stored in `~/.config/quickshell/spotlight-data/` (outside the repo):

| File | Purpose |
|------|---------|
| `secrets.json` | Groq API key (`{"groq_key": "gsk_..."}`) |
| `captures.json` | Saved URLs from `/cap` mode |
| `commands.json` | Saved shell commands from `/sc` mode |
| `aliases.json` | App aliases set via right-click |

These files are auto-created on first use — no manual setup required.

## Changing the Toggle Keybinding

Edit your Hyprland config (`~/.config/hypr/hyprland.conf`) and change the bind:

```conf
# Default: Alt+Space
bind = Alt, Space, exec, ~/.config/quickshell/spotlight/toggle-spotlight

# Example: Super+Space instead
# bind = SUPER, Space, exec, ~/.config/quickshell/spotlight/toggle-spotlight
```

Then reload: `hyprctl reload`

## Modes at a Glance

Type these prefixes in the search bar to switch modes:

| Prefix | Mode | What it does |
|--------|------|-------------|
| *(none)* | App | Launch installed apps |
| `/f` | File | Search files via `fd` |
| `/s` | AI | Ask Groq AI anything |
| `/g` | Google | Search in browser |
| `/yt` | YouTube | Search videos inline |
| `/w` | Web | Open a saved URL |
| `/cap` | Capture | Save a URL with a short name |
| `/sh` | Shell | Launch a saved command |
| `/sc` | Shell capture | Save a terminal command |

Type `\f`, `\s`, etc. if `/` conflicts with your keyboard layout.

## Architecture

notlight runs as a **systemd user service** (daemonized). The toggle script uses `qs ipc` to show/hide the panel without restarting the process, keeping startup instant. On first launch after boot, systemd starts the service automatically.

## License

MIT
