import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: root

  readonly property color accent: "#0a84ff"
  readonly property color bgPanel: "#f00d0d0d"
  readonly property color bgRow: "#141414"
  readonly property color bgRowHover: "#1c1c1c"
  readonly property color textPrimary: "#e5e5e5"
  readonly property color textSecondary: "#666666"
  readonly property color textAccent: "#ffffff"
  readonly property color borderColor: "#20ffffff"
  readonly property color dividerColor: "#15ffffff"
  readonly property int radius: 14
  readonly property int radiusInner: 8

  property bool open: false
  property string mode: "app"
  property string searchQuery: ""
  property var results: []
  property int selectedIndex: 0
  property bool searching: false


  property string answerTitle: ""
  property string answerText: ""
  property string answerUrl: ""
  property string answerSource: ""
  property string groqKey: ""
  property bool hasGroqKey: false
  property string secretsPath: home + "/.config/quickshell/spotlight/secrets.json"
  property bool secretsLoaded: false
  property string groqKeyInput: ""

  property var apps: []
  property var appAliases: ({})
  property string aliasesPath: home + "/.config/quickshell/spotlight/aliases.json"
  property bool appsLoaded: false
  property string aliasInputDesktopId: ""
  property string aliasInputText: ""
  property bool aliasSavedFeedback: false
  property bool captureSavedFeedback: false
  property string captureFeedbackText: ""
  property var captures: ({})
  property string capturesPath: home + "/.config/quickshell/spotlight/captures.json"

  readonly property string home: Quickshell.env("HOME") || ""

  readonly property var categoryInfo: ({
    video:  { label: "VIDEO",  color: "#60a5fa" },
    audio:  { label: "AUDIO",  color: "#a78bfa" },
    image:  { label: "IMAGE",  color: "#fb923c" },
    doc:    { label: "DOC",    color: "#4ade80" },
    dir:    { label: "DIR",    color: "#94a3b8" },
    other:  { label: "FILE",   color: "#64748b" },
    app:    { label: "APP",    color: "#f472b6" },
    youtube: { label: "YT",    color: "#ff0000" },
  })

  IpcHandler {
    target: "spotlight"
    function toggle() { root.open = !root.open }
    function show() { root.open = true }
    function hide() { root.open = false }
  }

  onOpenChanged: {
    if (open) {
      root.searchQuery = ""
      root.results = []
      root.selectedIndex = 0
      root.mode = "app"
      root.answerTitle = ""
      root.answerText = ""
      root.answerUrl = ""
      root.answerSource = ""
      root.aliasInputDesktopId = ""
      searchInput.text = ""
      searchInput.forceActiveFocus()
      if (!root.appsLoaded)
        root.loadApps()
      root.loadAliases()
      root.loadCaptures()
      root.loadSecrets()
    }
  }

  function processInput(raw) {
    root.selectedIndex = 0

    if (raw.length > 0 && raw[0] === '\\')
      raw = '/' + raw.slice(1)

    if (raw.length < 1) {
      root.mode = "app"
      root.searchQuery = ""
      root.results = []
      root.searching = false
      root.answerTitle = ""
      root.answerText = ""
      root.answerUrl = ""
      root.answerSource = ""
      searchTimer.stop()
      return
    }

    var newMode = ""
    var stripped = raw
    if (raw.length >= 3 && raw.slice(0, 3) === "/f ") { newMode = "file"; stripped = raw.slice(3) }
    else if (raw.length >= 3 && raw.slice(0, 3) === "/s ") { newMode = "answer"; stripped = raw.slice(3) }
    else if (raw.length >= 3 && raw.slice(0, 3) === "/g ") { newMode = "google"; stripped = raw.slice(3) }
    else if (raw.length >= 4 && raw.slice(0, 4) === "/yt ") { newMode = "youtube"; stripped = raw.slice(4) }
    else if (raw.length >= 3 && raw.slice(0, 3) === "/w ") { newMode = "web"; stripped = raw.slice(3) }
    else if (raw.length >= 5 && raw.slice(0, 5) === "/cap ") { newMode = "capture"; stripped = raw.slice(5) }

    if (newMode !== "") {
      if (root.mode !== newMode) {
        root.results = []
        root.answerTitle = ""
        root.answerText = ""
        root.answerUrl = ""
        root.answerSource = ""
      }
      root.mode = newMode
      root.searchQuery = stripped

      if (newMode === "file") {
        if (stripped.length > 0)
          searchTimer.restart()
        else
          searchTimer.stop()
      } else if (newMode === "youtube") {
        if (stripped.length > 0)
          searchTimer.restart()
        else
          searchTimer.stop()
      } else if (newMode === "answer") {
        searchTimer.stop()
      } else {
        searchTimer.stop()
      }
      return
    }

    // No prefix detected
    if (root.mode === "file") {
      root.searchQuery = raw
      if (raw.length > 0)
        searchTimer.restart()
      else
        searchTimer.stop()
      return
    }
    if (root.mode === "youtube") {
      root.searchQuery = raw
      if (raw.length > 0)
        searchTimer.restart()
      else
        searchTimer.stop()
      return
    }
    if (root.mode === "answer" || root.mode === "google" || root.mode === "web" || root.mode === "capture") {
      root.searchQuery = raw
      return
    }

    // Default: app mode
    root.mode = "app"
    root.searchQuery = raw
    root.answerTitle = ""
    root.answerText = ""
    root.results = root.filterApps(raw)
    searchTimer.stop()
  }

  onSearchQueryChanged: {
    if (root.mode === "app" && root.searchQuery.length > 0) {
      root.results = root.filterApps(root.searchQuery)
    }
  }

  Timer {
    id: searchTimer
    interval: 120
    onTriggered: {
      if (root.mode === "file")
        root.runSearch()
      else if (root.mode === "youtube")
        root.runYoutubeSearch()
    }
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.searching = false
        var lines = text.split("\n")
        var arr = []
        var q = root.searchQuery.toLowerCase()

        for (var i = 0; i < lines.length; i++) {
          var line = lines[i]
          if (!line) continue
          var tab = line.indexOf("\t")
          if (tab < 0) continue
          var cat = line.slice(0, tab)
          var path = line.slice(tab + 1)
          var slash = path.lastIndexOf("/")
          var name = slash >= 0 ? path.slice(slash + 1) : path
          var dir = slash >= 0 ? path.slice(0, slash) : ""
          var ext = name.lastIndexOf(".")
          var displayName = ext > 0 ? name.slice(0, ext) : name

          arr.push({
            type: "file",
            category: cat,
            path: path,
            name: displayName,
            ext: ext > 0 ? name.slice(ext).toLowerCase() : "",
            dir: root.home && dir.indexOf(root.home) === 0 ? "~" + dir.slice(root.home.length) : dir,
            info: root.categoryInfo[cat] || root.categoryInfo["other"],
          })
        }

        if (q.length > 0) {
          arr.sort(function(a, b) {
            var aPre = a.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
            var bPre = b.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
            if (aPre !== bPre) return aPre - bPre
            return a.name.length - b.name.length
          })
        }

        root.results = arr.slice(0, 30)
      }
    }
    stderr: StdioCollector {}
  }

  Process {
    id: secretLoadProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.groq_key) {
            root.groqKey = data.groq_key
            root.hasGroqKey = true
          }
        } catch (e) {}
        root.secretsLoaded = true
      }
    }
    stderr: StdioCollector {}
  }

  Process {
    id: secretSaveProc
    stderr: StdioCollector {}
  }

  Process {
    id: ytSearchProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.searching = false
        try {
          var data = JSON.parse(text)
          var arr = []
          for (var i = 0; i < data.length; i++) {
            var d = data[i]
            arr.push({
              type: "youtube",
              category: "youtube",
              videoId: d.id,
              name: d.title,
              author: d.author || "",
              duration: d.duration || "",
              info: root.categoryInfo["youtube"],
            })
          }
          root.results = arr
        } catch (e) {
          root.results = []
        }
      }
    }
    stderr: StdioCollector {}
  }

  Process {
    id: appScanProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.apps = JSON.parse(text)
          root.appsLoaded = true
        } catch (e) {}
      }
    }
    stderr: StdioCollector {}
  }

  Process {
    id: aliasLoadProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.appAliases = data || ({})
        } catch (e) {
          root.appAliases = ({})
        }
      }
    }
    stderr: StdioCollector {}
  }

  Process {
    id: aliasSaveProc
    stderr: StdioCollector {}
  }

  Process {
    id: captureLoadProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.captures = data || ({})
        } catch (e) {
          root.captures = ({})
        }
      }
    }
    stderr: StdioCollector {}
  }

  Process {
    id: captureSaveProc
    stderr: StdioCollector {}
  }

  function loadApps() {
    appScanProc.running = false
    appScanProc.command = ["python3", "-c",
      "import os, json\n" +
      "dirs = [os.path.expanduser('~/.local/share/applications'),\n" +
      "  '/usr/share/applications', '/usr/local/share/applications',\n" +
      "  '/var/lib/flatpak/exports/share/applications',\n" +
      "  os.path.expanduser('~/.local/share/flatpak/exports/share/applications')]\n" +
      "icon_dirs = [os.path.expanduser('~/.local/share/icons/hicolor/48x48/apps'),\n" +
      "  os.path.expanduser('~/.local/share/icons/hicolor/64x64/apps'),\n" +
      "  os.path.expanduser('~/.local/share/icons/hicolor/scalable/apps'),\n" +
      "  '/usr/share/icons/hicolor/48x48/apps', '/usr/share/icons/hicolor/64x64/apps',\n" +
      "  '/usr/share/icons/hicolor/scalable/apps', '/usr/share/icons/hicolor/32x32/apps',\n" +
      "  '/usr/share/icons/Adwaita/48x48/apps', '/usr/share/icons/Adwaita/scalable/apps',\n" +
      "  '/usr/share/pixmaps']\n" +
      "exts = ['.png','.svg','.xpm']\n" +
      "def resolve_icon(name):\n" +
      "  if not name: return ''\n" +
      "  if name.startswith('/'): return name if os.path.isfile(name) else ''\n" +
      "  for d in icon_dirs:\n" +
      "    if not os.path.isdir(d): continue\n" +
      "    for e in exts:\n" +
      "      p = os.path.join(d, name + e)\n" +
      "      if os.path.isfile(p): return p\n" +
      "    p = os.path.join(d, name)\n" +
      "    if os.path.isfile(p): return p\n" +
      "  return ''\n" +
      "seen = set()\n" +
      "result = []\n" +
      "for d in dirs:\n" +
      "  if not os.path.isdir(d): continue\n" +
      "  for f in os.listdir(d):\n" +
      "    if not f.endswith('.desktop'): continue\n" +
      "    if f in seen: continue\n" +
      "    seen.add(f)\n" +
      "    fp = os.path.join(d, f)\n" +
      "    try:\n" +
      "      entry = {'desktopId': f, 'name': '', 'exec': '', 'icon': '', 'iconPath': '', 'comment': '', 'categories': '', 'terminal': False}\n" +
      "      inDesktop = False\n" +
      "      skip = False\n" +
      "      for line in open(fp, 'r', errors='ignore'):\n" +
      "        line = line.strip()\n" +
      "        if line.startswith('['):\n" +
      "          inDesktop = line == '[Desktop Entry]'\n" +
      "          continue\n" +
      "        if not inDesktop or not line or line.startswith('#'): continue\n" +
      "        if '=' not in line: continue\n" +
      "        k, v = line.split('=', 1)\n" +
      "        k, v = k.strip(), v.strip()\n" +
      "        if k == 'Type' and v != 'Application': skip = True; break\n" +
      "        if k == 'NoDisplay' and v == 'true': skip = True; break\n" +
      "        if k == 'Name' and not entry['name']: entry['name'] = v\n" +
      "        elif k == 'Exec': entry['exec'] = v\n" +
      "        elif k == 'Icon': entry['icon'] = v\n" +
      "        elif k == 'Comment': entry['comment'] = v\n" +
      "        elif k == 'Categories': entry['categories'] = v\n" +
      "        elif k == 'Terminal': entry['terminal'] = v == 'true'\n" +
      "      if skip or not entry['name'] or not entry['exec']: continue\n" +
      "      entry['exec'] = __import__('re').sub(r'%[fFuUdDnNickvm]', '', entry['exec'].replace('%%', '\\x00')).replace('\\x00', '%').strip()\n" +
      "      entry['iconPath'] = resolve_icon(entry['icon'])\n" +
      "      result.append(entry)\n" +
      "    except: pass\n" +
      "print(json.dumps(result))"]
    appScanProc.running = true
  }

  function loadAliases() {
    aliasLoadProc.running = false
    aliasLoadProc.command = ["sh", "-c", "cat \"" + root.aliasesPath + "\" 2>/dev/null || echo '{}'"]
    aliasLoadProc.running = true
  }

  function loadCaptures() {
    captureLoadProc.running = false
    captureLoadProc.command = ["sh", "-c", "cat \"" + root.capturesPath + "\" 2>/dev/null || echo '{}'"]
    captureLoadProc.running = true
  }

  function saveAlias(alias, desktopId) {
    var al = alias.trim().toLowerCase()
    if (al.length < 1) return
    root.appAliases[al] = desktopId
    root.aliasSavedFeedback = true
    feedbackTimer.restart()
    writeAliases()
  }

  function removeAlias(alias) {
    var al = alias.trim().toLowerCase()
    if (root.appAliases[al]) {
      delete root.appAliases[al]
      writeAliases()
    }
  }

  function writeAliases() {
    aliasSaveProc.running = false
    var json = JSON.stringify(root.appAliases)
    aliasSaveProc.command = ["sh", "-c",
      "mkdir -p \"$(dirname \"" + root.aliasesPath + "\")\" && " +
      "echo '" + json + "' > \"" + root.aliasesPath + "\""]
    aliasSaveProc.running = true
  }

  function saveCapture(code, url) {
    var c = code.trim().toLowerCase()
    if (c.length < 1 || !url || url.trim().length < 1) return
    root.captures[c] = url.trim()
    root.captureFeedbackText = "Saved! :" + c + " \u2192 " + url.trim()
    root.captureSavedFeedback = true
    captureFeedbackTimer.restart()
    writeCaptures()
  }

  function removeCapture(code) {
    var c = code.trim().toLowerCase()
    if (root.captures[c]) {
      delete root.captures[c]
      writeCaptures()
    }
  }

  function writeCaptures() {
    captureSaveProc.running = false
    var json = JSON.stringify(root.captures)
    captureSaveProc.command = ["sh", "-c",
      "mkdir -p \"$(dirname \"" + root.capturesPath + "\")\" && " +
      "echo '" + json + "' > \"" + root.capturesPath + "\""]
    captureSaveProc.running = true
  }

  function resolveCapture(code) {
    return root.captures[code.trim().toLowerCase()] || ""
  }

  function resolveAlias(alias) {
    return root.appAliases[alias.trim().toLowerCase()] || ""
  }

  function aliasForDesktopId(desktopId) {
    for (var key in root.appAliases) {
      if (root.appAliases[key] === desktopId) return key
    }
    return ""
  }

  function filterApps(q) {
    if (!root.apps || root.apps.length === 0 || q.length < 1) return []
    var matched = []
    var aliasDesktopId = root.resolveAlias(q)

    for (var i = 0; i < root.apps.length; i++) {
      var app = root.apps[i]
      var alias = root.aliasForDesktopId(app.desktopId)
      if (app.name.toLowerCase().indexOf(q) >= 0 ||
          (app.comment && app.comment.toLowerCase().indexOf(q) >= 0) ||
          (app.categories && app.categories.toLowerCase().indexOf(q) >= 0) ||
          (alias && alias.indexOf(q) >= 0)) {
        matched.push({
          type: "app",
          category: "app",
          desktopId: app.desktopId,
          name: app.name,
          exec: app.exec,
          icon: app.icon,
          iconPath: app.iconPath,
          comment: app.comment,
          categories: app.categories,
          alias: alias,
          terminal: app.terminal,
          info: root.categoryInfo["app"],
        })
      }
    }

    if (aliasDesktopId) {
      for (var i = 0; i < matched.length; i++) {
        if (matched[i].desktopId === aliasDesktopId) {
          var item = matched.splice(i, 1)[0]
          matched.unshift(item)
          break
        }
      }
    }

    return matched.slice(0, 8)
  }

  function runSearch() {
    var q = root.searchQuery.trim()
    if (q.length < 1) { results = []; return }
    root.searching = true
    searchProc.running = false
    searchProc.command = ["sh", "-c", root.searchScript, "sh", q]
    searchProc.running = true
  }

  function loadSecrets() {
    if (root.secretsLoaded) return
    secretLoadProc.running = false
    secretLoadProc.command = ["sh", "-c", "cat \"" + root.secretsPath + "\" 2>/dev/null || echo '{}'"]
    secretLoadProc.running = true
  }

  function saveGroqKey(key) {
    root.groqKey = key
    root.hasGroqKey = true
    root.groqKeyInput = ""
    var json = JSON.stringify({"groq_key": key})
    secretSaveProc.running = false
    secretSaveProc.command = ["sh", "-c",
      "mkdir -p \"$(dirname \"" + root.secretsPath + "\")\" && " +
      "echo '" + json + "' > \"" + root.secretsPath + "\""]
    secretSaveProc.running = true
  }

  function runWebSearch() {
    var q = root.searchQuery.trim()
    if (q.length < 1 || !root.hasGroqKey) { return }
    root.searching = true

    var xhr = new XMLHttpRequest()
    xhr.open("POST", "https://api.groq.com/openai/v1/chat/completions")
    xhr.setRequestHeader("Authorization", "Bearer " + root.groqKey)
    xhr.setRequestHeader("Content-Type", "application/json")
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        root.searching = false
        try {
          var data = JSON.parse(xhr.responseText)
          if (data.choices && data.choices.length > 0) {
            root.answerText = data.choices[0].message.content || ""
            root.answerTitle = ""
            root.answerUrl = ""
            root.answerSource = "Groq AI"
          } else {
            root.answerText = data.error?.message || "No answer found"
            root.answerTitle = ""
            root.answerUrl = ""
            root.answerSource = ""
          }
        } catch (e) {
          root.answerTitle = ""
          root.answerText = "Error: " + e.message
          root.answerUrl = ""
          root.answerSource = ""
        }
      }
    }
    xhr.send(JSON.stringify({
      model: "llama-3.3-70b-versatile",
      messages: [
        {role: "system", content: "Answer concisely in 1-2 sentences. No markdown, no formatting, just plain text."},
        {role: "user", content: q}
      ],
      temperature: 0.3,
      max_tokens: 200
    }))
  }

  readonly property string searchScript:
    'q=$1; fd --hidden --no-ignore --type f --type d -a ' +
    '-E .cache -E .git -E .cargo -E .rustup -E .npm -E .gradle -E .mozilla -E .var -E node_modules ' +
    '-c never -- "$q" "$HOME" 2>/dev/null | ' +
    'head -50 | while IFS= read -r p; do ' +
    '  if [ -d "$p" ]; then printf "dir\t%s\\n" "$p"; ' +
    '  else ' +
    '    ext=$(echo "${p##*.}" | tr "A-Z" "a-z"); ' +
    '    case "$ext" in ' +
    '      mp4|avi|mkv|mov|wmv|flv|webm|m4v|mpg|mpeg|3gp) printf "video\t%s\\n" "$p" ;; ' +
    '      mp3|wav|flac|aac|ogg|wma|m4a|opus|aiff|alac) printf "audio\t%s\\n" "$p" ;; ' +
    '      jpg|jpeg|png|gif|bmp|svg|webp|ico|tiff|tif|heic|heif|raw) printf "image\t%s\\n" "$p" ;; ' +
    '      pdf|txt|md|json|xml|html|css|js|ts|py|c|cpp|h|hpp|java|rb|go|rs|lua|sh|yaml|yml|toml|ini|cfg|conf|log|doc|docx|xls|xlsx|ppt|pptx|csv) printf "doc\t%s\\n" "$p" ;; ' +
    '      *) printf "other\t%s\\n" "$p" ;; ' +
    '    esac; ' +
    '  fi; ' +
    'done'

  function runYoutubeSearch() {
    var q = root.searchQuery.trim()
    if (q.length < 1) { root.results = []; return }
    root.searching = true
    root.results = []
    var binPath = root.home + "/active projects c/spotlight/yt-search"
    ytSearchProc.running = false
    ytSearchProc.command = [binPath, q]
    ytSearchProc.running = true
  }

  function launch(item) {
    if (!item) return
    root.open = false
    if (item.type === "app") {
      if (item.terminal)
        Quickshell.execDetached(["kitty", "-e", "/bin/sh", "-c", item.exec])
      else
        Quickshell.execDetached(["/bin/sh", "-c", item.exec + " &"])
      return
    }
    if (item.type === "youtube") {
      Qt.openUrlExternally("https://www.youtube.com/watch?v=" + item.videoId)
      return
    }
    switch (item.category) {
      case "video":
      case "audio":
        Quickshell.execDetached(["mpv", item.path])
        break
      case "dir":
        Quickshell.execDetached(["kitty", "-e", "yazi", item.path])
        break
      default:
        Quickshell.execDetached(["xdg-open", item.path])
        break
    }
  }

  function openGoogle(query) {
    Qt.openUrlExternally("https://www.google.com/search?q=" + encodeURIComponent(query))
    root.open = false
  }

  function openYoutube(query) {
    Qt.openUrlExternally("https://www.youtube.com/results?search_query=" + encodeURIComponent(query))
    root.open = false
  }

  Timer {
    id: feedbackTimer
    interval: 1200
    onTriggered: root.aliasSavedFeedback = false
  }

  Timer {
    id: captureFeedbackTimer
    interval: 2000
    onTriggered: {
      root.captureSavedFeedback = false
      root.captureFeedbackText = ""
    }
  }

  readonly property string modePillText: {
    if (root.mode === "answer") return "ASK"
    if (root.mode === "file") return "FILE"
    if (root.mode === "google") return "GOOGLE"
    if (root.mode === "youtube") return "YOUTUBE"
    if (root.mode === "web") return "WEB"
    if (root.mode === "capture") return "CAP"
    return "APP"
  }

  readonly property string placeholderText: {
    if (root.mode === "answer") return "Ask anything..."
    if (root.mode === "file") return "Search files..."
    if (root.mode === "google") return "Search Google..."
    if (root.mode === "youtube") return "Search YouTube..."
    if (root.mode === "web") return "Type code to open..."
    if (root.mode === "capture") return "<url> <code>..."
    return "Search apps..."
  }

  PanelWindow {
    id: win
    color: "transparent"
    visible: root.open
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:spotlight"
    anchors { top: true; bottom: true; left: true; right: true }

    onVisibleChanged: if (visible) searchInput.forceActiveFocus()

    MouseArea {
      anchors.fill: parent
      onClicked: root.open = false
    }

    Item {
      id: panel
      width: 640
      height: root.mode === "answer" ? Math.min(panelContent.implicitHeight, 800) : Math.min(panelContent.implicitHeight, 660)
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round((parent.height - searchBarItem.height) / 2)

      opacity: root.open ? 1 : 0
      scale: root.open ? 1 : 0.85
      Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
      Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

      Rectangle {
        id: panelBg
        anchors.fill: parent
        radius: root.radius
        color: root.bgPanel
        border.color: root.borderColor
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent }

        Column {
          id: panelContent
          width: parent.width
          spacing: 0
          padding: 0

          Rectangle {
            width: parent.width
            height: 1
            color: root.dividerColor
            y: 60
            visible: root.results.length > 0 || (root.mode === "answer" && (root.answerText.length > 0 || !root.hasGroqKey))
          }

          Item {
            id: searchBarItem
            width: parent.width
            height: 60

            Canvas {
              x: 20
              anchors.verticalCenter: parent.verticalCenter
              width: 22
              height: 22
              antialiasing: true

              onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = root.textSecondary
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.arc(10, 10, 7, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(15.5, 15.5)
                ctx.lineTo(21, 21)
                ctx.stroke()
              }
            }

            TextInput {
              id: searchInput
              x: 54
              width: parent.width - 72
              anchors.verticalCenter: parent.verticalCenter
              color: root.textPrimary
              font.pixelSize: 22
              font.weight: Font.Normal
              selectionColor: root.accent
              selectByMouse: true
              clip: true

              onTextChanged: root.processInput(text)

              Text {
                text: root.placeholderText
                color: root.textSecondary
                font: searchInput.font
                visible: searchInput.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.7
              }

              Keys.onPressed: function(ev) {
                if (ev.key === Qt.Key_Escape) {
                  root.open = false
                  ev.accepted = true
                } else if (ev.key === Qt.Key_Down) {
                  root.selectedIndex = Math.min(root.selectedIndex + 1, root.results.length - 1)
                  ev.accepted = true
                } else if (ev.key === Qt.Key_Up) {
                  root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                  ev.accepted = true
                  } else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                    if (root.mode === "google") {
                      root.openGoogle(root.searchQuery)
                    } else if (root.mode === "youtube") {
                      if (root.results.length > 0 && root.results[root.selectedIndex]) {
                        root.launch(root.results[root.selectedIndex])
                      } else if (!root.searching) {
                        root.runYoutubeSearch()
                      }
                    } else if (root.mode === "answer") {
                      if (!root.searching)
                        root.runWebSearch()
                    } else if (root.mode === "web") {
                      var code = root.searchQuery.trim().toLowerCase()
                      var url = root.captures[code]
                      if (url) {
                        Qt.openUrlExternally(url)
                        root.open = false
                      }
                    } else if (root.mode === "capture") {
                      var text = root.searchQuery.trim()
                      var lastSpace = text.lastIndexOf(" ")
                      if (lastSpace > 0) {
                        var capUrl = text.slice(0, lastSpace).trim()
                        var capCode = text.slice(lastSpace + 1).trim()
                        if (capUrl.length > 0 && capCode.length > 0)
                          root.saveCapture(capCode, capUrl)
                      }
                    } else {
                      root.launch(root.results[root.selectedIndex])
                    }
                  ev.accepted = true
                } else if (ev.key === Qt.Key_Backspace && searchInput.text.length === 0) {
                  root.open = false
                  ev.accepted = true
                }
              }
            }

            BusyIndicator {
              anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
              width: 16; height: 16
              running: root.searching
              visible: root.searching
            }

            Rectangle {
              anchors { right: parent.right; rightMargin: 40; verticalCenter: parent.verticalCenter }
              width: modeLabel.width + 14
              height: 20
              radius: 4
              color: Qt.rgba(0.65,0.42,1,0.12)
              border.width: 1
              border.color: Qt.rgba(0.65,0.42,1,0.35)

              Text {
                id: modeLabel
                anchors.centerIn: parent
                text: root.modePillText
                color: "#a78bfa"
                font.pixelSize: 9
                font.letterSpacing: 1.2
                font.weight: Font.Medium
              }
            }
          }

          Item {
            width: parent.width
            height: root.mode === "answer" && root.answerText.length > 0 ? answerLayout.height + 16 : 0
            visible: root.mode === "answer" && root.answerText.length > 0

            Column {
              id: answerLayout
              x: 14
              y: 8
              width: parent.width - 28
              spacing: 4

              Text {
                text: root.answerTitle
                color: root.accent
                font.pixelSize: 15
                font.weight: Font.Bold
                wrapMode: Text.Wrap
                width: parent.width
                visible: root.answerTitle.length > 0
              }

              Text {
                text: root.answerText
                color: root.textPrimary
                font.pixelSize: 13
                wrapMode: Text.Wrap
                width: parent.width
                lineHeight: 1.4
              }

              Text {
                text: root.answerSource.length > 0 ? "Source: " + root.answerSource : ""
                color: root.textSecondary
                font.pixelSize: 11
                width: parent.width
                visible: root.answerSource.length > 0
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.open = false
            }
          }

          Item {
            width: parent.width
            height: root.mode === "answer" && !root.hasGroqKey && root.answerText.length === 0 ? setupLayout.height + 16 : 0
            visible: root.mode === "answer" && !root.hasGroqKey && root.answerText.length === 0

            onVisibleChanged: if (visible) groqSetupInput.forceActiveFocus()

            Column {
              id: setupLayout
              x: 14
              y: 8
              width: parent.width - 28
              spacing: 8

              Text {
                text: "Groq API key required"
                color: root.accent
                font.pixelSize: 15
                font.weight: Font.Bold
              }

              Text {
                text: "Enter your Groq API key to use the ASK (/s) mode. Get one for free at console.groq.com"
                color: root.textSecondary
                font.pixelSize: 11
                wrapMode: Text.Wrap
                width: parent.width
              }

              Rectangle {
                width: parent.width
                height: 32
                radius: 6
                color: "#1c1c1c"
                border.color: root.dividerColor

                TextInput {
                  id: groqSetupInput
                  anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                  color: root.textPrimary
                  font.pixelSize: 12
                  clip: true
                  echoMode: TextInput.Password
                  onTextChanged: root.groqKeyInput = text
                  Keys.onReturnPressed: {
                    if (text.trim().length > 0)
                      root.saveGroqKey(text.trim())
                  }
                  Keys.onEscapePressed: root.open = false
                }
              }

              Rectangle {
                width: 60
                height: 26
                radius: 4
                color: root.accent

                Text {
                  anchors.centerIn: parent
                  text: "Save"
                  color: "#ffffff"
                  font.pixelSize: 11
                  font.weight: Font.Medium
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    if (groqSetupInput.text.trim().length > 0)
                      root.saveGroqKey(groqSetupInput.text.trim())
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.open = false
            }
          }

          ListView {
            id: resultList
            width: parent.width
            height: Math.min(root.results.length, 8) * 56
            clip: true
            model: root.results
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            interactive: true
            visible: root.mode === "app" || root.mode === "file" || root.mode === "youtube"

            delegate: Item {
              id: row
              width: resultList.width
              height: 56
              required property var modelData
              required property int index
              readonly property bool isSelected: index === root.selectedIndex
              readonly property bool isApp: row.modelData.type === "app"
              readonly property bool isYt: row.modelData.type === "youtube"

              Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                radius: root.radiusInner
                color: row.isSelected ? bgRowHover : "transparent"
              }

              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                width: 3
                radius: 2
                color: root.accent
                visible: row.isSelected
                opacity: 0.8
              }

              // App icon
              Item {
                x: 16
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                visible: isApp

                Image {
                  id: appIcon
                  anchors.fill: parent
                  source: isApp && row.modelData.iconPath ? "file://" + row.modelData.iconPath : ""
                  sourceSize { width: 32; height: 32 }
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  visible: status === Image.Ready
                }

                Rectangle {
                  anchors.fill: parent
                  radius: width / 2
                  color: Qt.rgba(0.96,0.45,0.71,0.2)
                  visible: !isApp || !row.modelData.iconPath || appIcon.status !== Image.Ready

                  Text {
                    anchors.centerIn: parent
                    text: isApp ? row.modelData.name.charAt(0).toUpperCase() : ""
                    color: root.textSecondary
                    font.pixelSize: 14
                    font.weight: Font.Bold
                  }
                }
              }

              // YouTube thumbnail area
              Item {
                x: 16
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                visible: isYt

                Rectangle {
                  anchors.fill: parent
                  radius: 6
                  color: Qt.rgba(1,0,0,0.15)

                  Text {
                    anchors.centerIn: parent
                    text: "\u25B6"
                    color: "#ff0000"
                    font.pixelSize: 14
                  }
                }
              }

              Column {
                x: isApp ? 54 : (isYt ? 54 : 22)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                  text: row.modelData.name
                  color: row.isSelected ? root.textPrimary : root.textPrimary
                  font.pixelSize: 14
                  font.weight: Font.Normal
                  elide: Text.ElideRight
                  width: isApp ? 340 : (isYt ? 380 : 420)
                  opacity: row.isSelected ? 1.0 : 0.85
                }

                Text {
                  text: isApp
                    ? (row.modelData.comment || row.modelData.categories || "")
                    : isYt
                      ? (row.modelData.author + "  \u00B7  " + row.modelData.duration)
                      : row.modelData.dir + (row.modelData.ext ? "  \u00B7  " + row.modelData.ext : "")
                  color: isApp ? root.textSecondary : (isYt ? "#ff4444" : "#eaff00")
                  font.pixelSize: 11
                  elide: Text.ElideRight
                  width: isApp ? 340 : (isYt ? 380 : 420)
                  opacity: 0.7
                }
              }

              // Alias badge
              Text {
                anchors { left: parent.left; leftMargin: isApp ? 54 : 22; bottom: parent.bottom; bottomMargin: 8 }
                text: isApp && row.modelData.alias ? ":" + row.modelData.alias : ""
                color: "#f472b6"
                font.pixelSize: 9
                font.letterSpacing: 1.2
                font.weight: Font.Medium
                visible: text.length > 0
                opacity: 0.8
              }

              // Type pill
              Rectangle {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                width: catLabel.width + 14
                height: 20
                radius: 4
                color: Qt.rgba(1,1,1,0.06)

                Rectangle {
                  anchors.fill: parent
                  radius: 4
                  color: row.modelData.info.color
                  opacity: 0.2
                }

                Text {
                  id: catLabel
                  anchors.centerIn: parent
                  text: row.modelData.info.label
                  color: row.modelData.info.color
                  font.pixelSize: 9
                  font.letterSpacing: 1.2
                  font.weight: Font.Medium
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPositionChanged: root.selectedIndex = row.index
                onClicked: function(mouse) {
                  if (mouse.button === Qt.RightButton) {
                    if (isApp) {
                      root.aliasInputDesktopId = row.modelData.desktopId
                      root.aliasInputText = row.modelData.alias || ""
                      aliasInput.forceActiveFocus()
                      aliasInput.selectAll()
                    }
                    return
                  }
                  root.launch(row.modelData)
                }
              }
            }
          }

          // Alias input overlay
          Item {
            width: parent.width
            height: root.aliasInputDesktopId.length > 0 ? 50 : 0
            visible: height > 0
            clip: true

            Behavior on height {
              NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Rectangle {
              anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; topMargin: 4 }
              height: 40
              radius: root.radiusInner
              color: "#1c1c1c"
              border.width: 1
              border.color: root.dividerColor

              Text {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: root.aliasSavedFeedback ? "Alias saved!" : "Alias:"
                color: root.aliasSavedFeedback ? "#4ade80" : root.textSecondary
                font.pixelSize: 11
              }

              TextInput {
                id: aliasInput
                anchors { left: parent.left; leftMargin: 52; right: saveBtn.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                height: 26
                color: root.textPrimary
                font.pixelSize: 12
                clip: true
                text: root.aliasInputText
                selectByMouse: true
                maximumLength: 20

                onTextChanged: root.aliasInputText = text

                Keys.onEscapePressed: {
                  root.aliasInputDesktopId = ""
                  searchInput.forceActiveFocus()
                }
                Keys.onReturnPressed: {
                  if (root.aliasInputText.trim().length > 0) {
                    root.saveAlias(root.aliasInputText, root.aliasInputDesktopId)
                  } else {
                    var existing = root.aliasForDesktopId(root.aliasInputDesktopId)
                    if (existing)
                      root.removeAlias(existing)
                  }
                  root.aliasInputDesktopId = ""
                  searchInput.forceActiveFocus()
                }
              }

              Item {
                id: saveBtn
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: 28
                height: 26

                Rectangle {
                  anchors.fill: parent
                  radius: 4
                  color: saveArea.containsMouse ? "#2a2a2a" : "transparent"
                }

                Text {
                  anchors.centerIn: parent
                  text: "\u2713"
                  color: root.textSecondary
                  font.pixelSize: 12
                }

                MouseArea {
                  id: saveArea
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: {
                    if (root.aliasInputText.trim().length > 0) {
                      root.saveAlias(root.aliasInputText, root.aliasInputDesktopId)
                    } else {
                      var existing = root.aliasForDesktopId(root.aliasInputDesktopId)
                      if (existing)
                        root.removeAlias(existing)
                    }
                    root.aliasInputDesktopId = ""
                    searchInput.forceActiveFocus()
                  }
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: root.captureSavedFeedback ? 36 : 0
            visible: height > 0
            color: "transparent"
            clip: true

            Behavior on height {
              NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Text {
              anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
              text: root.captureFeedbackText
              color: "#4ade80"
              font.pixelSize: 12
            }
          }

          Item {
            width: parent.width
            height: root.results.length > 8 ? 6 : 0
          }
        }
      }
    }
  }
}
