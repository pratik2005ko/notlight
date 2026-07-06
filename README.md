# notlight

A slick launcher for Hyprland that does way more than just launch apps. Built with [Quickshell](https://github.com/Quickshell/Quickshell).

I use this thing all day — it replaces app launchers, file search, web search, terminal command runner, and even answers questions with AI. All from one little panel.

## What it can do

Hit your keybind (Alt+Space by default) and start typing:

- **App search** — just start typing an app name. Filters by name, comment, even categories. Works instantly.
- **File search** — `/f something` — searches your home directory with `fd`, sorted by type (video, audio, image, doc, etc.)
- **AI answer** — `/s ask me anything` — sends your question to Groq AI, gets back an answer with code blocks you can copy with one click
- **Google search** — `/g query` — opens a browser tab with your search. Press Enter to send.
- **YouTube** — `/yt search terms` — shows video results inline with duration, press Enter on one to watch
- **Web bookmarks** — `/w code` — opens a saved URL by a short name you gave it
- **Capture URLs** — `/cap https://example.com mycode` — saves a URL with a short name for later
- **Shell commands** — `/sh query` — fuzzy search through your saved terminal commands, Enter to launch in kitty
- **Capture commands** — `/sc mycode ls -la` — saves a terminal command with a short name
- **Aliases** — right-click any app result to give it a nickname (it'll jump to the top when you type that)

## One-command install

```bash
git clone https://github.com/pratik2005ko/notlight.git
cd notlight
chmod +x install.sh && ./install.sh
```

That's it. The script checks dependencies, compiles the YouTube search binary, symlinks the config, and sets up the systemd service.

## Doing it manually

### What you need

- **Quickshell** — the framework this runs on
- **fd** — powers the file search
- **kitty** — my terminal of choice (for apps that need a terminal and the file browser)
- **mpv** — plays videos and audio from file search results
- **yazi** — the directory browser that opens when you hit a folder
- **wl-copy** — for the "copy to clipboard" button on code blocks in AI answers
- **libcurl + nlohmann-json** — for building the YouTube search binary

### Steps

```bash
git clone https://github.com/pratik2005ko/notlight.git
cd notlight
g++ -std=c++17 -O2 -s yt-search.cpp -o yt-search -lcurl
ln -sf "$PWD" ~/.config/quickshell/spotlight
```

### Setting it up as a service (auto-start)

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

### Add a keybinding

Pop this in your Hyprland config:

```conf
bind = Alt, Space, exec, ~/.config/quickshell/spotlight/toggle-spotlight
```

## Getting the AI answer mode to work

You'll need a Groq API key. When you use `/s` for the first time without one, the panel shows a text field where you can paste it in. Or you can create the file yourself:

```json
# ~/.config/quickshell/spotlight-data/secrets.json
{"groq_key": "gsk_your_key_here"}
```

## How to use it

| Prefix | Mode | What happens |
|--------|------|-------------|
| *(none)* | App | Just type and pick an app |
| `/f` | Files | Searches files with `fd` |
| `/s` | AI Ask | Sends to Groq AI (press Enter) |
| `/g` | Google | Opens Google in your browser |
| `/yt` | YouTube | Shows inline results, Enter to open |
| `/w` | Web | Opens a URL you saved earlier |
| `/cap` | Capture | Save a URL with a short code |
| `/sh` | Shell | Finds and launches a saved command |
| `/sc` | Shell capture | Save a command with a short code |

Both `/` and `\` work as prefix (handy if your keyboard layout makes `/` awkward). Your stuff is stored in `~/.config/quickshell/spotlight-data/` — separate from the repo, so updates don't wipe anything.

When AI mode shows you code, each block has a little **copy** button that uses `wl-copy` under the hood.

## Updating

```bash
cd ~/.config/quickshell/spotlight
git pull
./install.sh
```

Or just run the update script:

```bash
~/.config/quickshell/spotlight/update.sh
```

It pulls the latest code and rebuilds the YouTube binary if needed. Your data files are safe — they live outside the repo.

## Uninstalling

```bash
systemctl --user stop notlight.service
systemctl --user disable notlight.service
rm -f ~/.config/systemd/user/notlight.service
systemctl --user daemon-reload

rm -rf ~/.config/quickshell/spotlight-data
rm -f ~/.config/quickshell/spotlight

# Delete the repo folder if you cloned it
# rm -rf /path/to/notlight
```

## Where your data lives

Everything is in `~/.config/quickshell/spotlight-data/`:

| File | What's in it |
|------|-------------|
| `secrets.json` | Your Groq API key |
| `captures.json` | URLs you saved with `/cap` |
| `commands.json` | Shell commands you saved with `/sc` |
| `aliases.json` | App nicknames set via right-click |

These get created automatically the first time you use a feature — no manual setup needed.

## Changing the keybinding

Edit your Hyprland config (`~/.config/hypr/hyprland.conf`):

```conf
bind = Alt, Space, exec, ~/.config/quickshell/spotlight/toggle-spotlight
```

Then reload with `hyprctl reload`.

## How it works under the hood

It runs as a systemd user service so it's always ready. The toggle script just sends an IPC signal to show or hide the panel — no restart, no delay. systemd fires it up when you log in, and it sits there using basically no resources until you need it.

## Themes

Two built-in themes you can switch between:

- **macOS** — the original frosted glass look with rounded corners, smooth animations
- **Windows 95** — chonky gray bevels, square corners, classic title bar

Switch with `/theme macos` or `/theme win95` in the search bar, or from the terminal: `qs ipc call spotlight themeWin95`. Your choice sticks — it's saved to `theme.json`.

## License

MIT
