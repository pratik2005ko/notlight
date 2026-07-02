# spotlight

A multi-mode launcher for Hyprland built with [Quickshell](https://github.com/Quickshell/Quickshell).

## Features

- **App search** (default mode) — instant filtering of installed applications by name, comment, or categories
- **File search** (`/f query`) — fast file search via `fd`, categorized by extension (video, audio, image, doc, directory, etc.)
- **AI answer** (`/s query`) — ask Groq AI for natural-language answers (Enter to trigger)
- **Google search** (`/g query`) — open search query in browser (Enter to trigger)
- **YouTube inline search** (`/yt query`) — search videos inline, preview results with duration, launch in browser on Enter
- **Alias system** — right-click an app result to set/remove a custom alias (boosts to top of search results)
- **macOS-style spring animation** — centered panel with scale bounce on open/close

## Dependencies

- [Quickshell](https://github.com/Quickshell/Quickshell)
- `fd` — file search (`/f`)
- `kitty` — terminal for terminal apps and directory browser (yazi)
- `mpv` — video/audio playback
- `yazi` — directory file browser
- `libcurl` + `nlohmann-json` — YouTube search (compiled binary)

## Installation

```bash
git clone https://github.com/pratik2005ko/spotlight.git
cd spotlight
# Compile YouTube search binary
g++ -std=c++17 yt-search.cpp -o yt-search -lcurl
```

Link to Quickshell config:
```bash
ln -sf "$PWD" ~/.config/quickshell/spotlight
```

## Configuration

### API Key (required for AI answer mode)

On first use in `/s` mode, the UI will prompt you to enter your Groq API key. You can also create the file manually:

```json
# ~/.config/quickshell/spotlight/secrets.json
{"groq_key": "gsk_your_key_here"}
```

### Keybinding

Add to your Hyprland config:

```conf
bind = Alt, Space, exec, ~/.config/quickshell/spotlight/toggle-spotlight
```

## Usage

| Prefix | Mode | Action |
|--------|------|--------|
| *(none)* | App search | Filter installed apps by name/comment/categories |
| `/f` | File search | Search files by name via `fd` |
| `/s` | AI answer | Ask Groq AI (Enter to send) |
| `/g` | Google search | Open Google search in browser (Enter to send) |
| `/yt` | YouTube | Search videos inline (Enter to send, Enter on result to open) |

Both `/` and `\` work as prefix characters (`\f`, `\s`, etc.).

## License

MIT
