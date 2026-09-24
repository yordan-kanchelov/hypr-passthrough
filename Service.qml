import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Omarchy shell service for hypr-passthrough.
//
// Hyprland only reads passthrough.lua when a config requires it, so this service
// loads it with `hyprctl eval` when the plugin is enabled, and again after every
// config reload (a reload rebuilds Hyprland's Lua state). Disabling the plugin
// unloads it. A copy required from hyprland.lua takes precedence and is left
// alone, apart from the extra apps added from the bar widget, which apply to
// whichever copy is loaded.
Item {
  id: root

  readonly property string modulePath: decodeURIComponent(
    Qt.resolvedUrl("passthrough.lua").toString().replace(/^file:\/\//, "")
  )

  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string appsDir: configHome + "/hypr-passthrough"
  readonly property string appsPath: appsDir + "/apps.json"

  // Window classes added from the bar widget, saved in apps.json.
  property var extraApps: []
  // Built-in app patterns switched off from the bar widget, saved in apps.json.
  property var disabledApps: []
  // Lua patterns configured in the module (the built-in list unless
  // hyprland.lua passes its own `apps`).
  property var appPatterns: []
  property string submapName: "passthrough"
  // True while Hyprland is in the passthrough submap.
  property bool active: false
  // Class of the focused window, "" when none.
  property string activeClass: ""

  property bool syncPending: false

  function luaString(value) {
    return "\"" + String(value).replace(/[\x00-\x1f]/g, "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
  }

  readonly property string applyCode:
    "if hypr_passthrough and hypr_passthrough.set_extra_apps then hypr_passthrough.set_extra_apps({"
    + extraApps.map(luaString).join(", ") + "}) end "
    + "if hypr_passthrough and hypr_passthrough.set_disabled_apps then hypr_passthrough.set_disabled_apps({"
    + disabledApps.map(luaString).join(", ") + "}) end"

  // Tags the copy this service instance loads. A shell restart starts the new
  // instance before the old one's detached unload runs, so each instance only
  // unloads its own copy, and replaces a copy left by an older instance (which
  // also picks up an updated passthrough.lua). A copy required from
  // hyprland.lua has no tag and is never replaced or unloaded.
  readonly property string owner: "omarchy-plugin:" + Date.now() + ":" + Math.floor(Math.random() * 1e9)

  readonly property string loadCode:
    "local p = hypr_passthrough "
    + "if p and type(p.loaded_by) == 'string' and p.loaded_by ~= " + luaString(owner)
    + " and p.loaded_by:find('^omarchy%-plugin') then p.teardown() end "
    + "if not hypr_passthrough then dofile(" + luaString(modulePath) + ").setup().loaded_by = " + luaString(owner) + " end "
    + applyCode

  readonly property string unloadCode:
    "if hypr_passthrough and hypr_passthrough.loaded_by == " + luaString(owner) + " then hypr_passthrough.teardown() end"

  // Starts with a marker line: hyprctl prints "unknown request" for an empty result.
  readonly property string statusCode:
    "if not (hypr_passthrough and hypr_passthrough.app_patterns) then return '#' end "
    + "return '#' .. hypr_passthrough.submap_name() .. '\\n' .. hypr_passthrough.app_patterns()"

  // Load the module if needed, apply the extra apps, then refresh the status.
  function sync() {
    if (loader.running) {
      syncPending = true
      return
    }

    loader.command = ["hyprctl", "eval", root.loadCode]
    loader.running = true
  }

  function isListed(windowClass) {
    var cls = String(windowClass || "").toLowerCase()
    if (!cls) return false
    if (isAdded(cls)) return true

    for (var i = 0; i < appPatterns.length; i++) {
      if (isBuiltInEnabled(appPatterns[i]) && patternMatches(appPatterns[i], cls)) return true
    }

    return false
  }

  // Match a lowercased name against one of the module's Lua patterns. The
  // built-in patterns only use ^, $ and %-escapes, which map directly.
  function patternMatches(pattern, name) {
    try {
      return new RegExp(String(pattern).replace(/%(.)/g, "\\$1")).test(String(name || "").toLowerCase())
    } catch (e) {
      return false
    }
  }

  function isAdded(windowClass) {
    var cls = String(windowClass || "").toLowerCase()
    return extraApps.some(function(app) { return app.toLowerCase() === cls })
  }

  function isBuiltInEnabled(pattern) {
    return disabledApps.indexOf(pattern) === -1
  }

  function setBuiltInEnabled(pattern, enabled) {
    var others = disabledApps.filter(function(p) { return p !== pattern })
    disabledApps = enabled ? others : others.concat([pattern])
    save()
  }

  function addApp(windowClass) {
    var cls = String(windowClass || "").trim()
    if (!cls || isAdded(cls)) return
    extraApps = extraApps.concat([cls])
    save()
  }

  function removeApp(windowClass) {
    var cls = String(windowClass || "").toLowerCase()
    extraApps = extraApps.filter(function(app) { return app.toLowerCase() !== cls })
    save()
  }

  function save() {
    sync()
    mkdir.running = true
  }

  function stringList(value) {
    return Array.isArray(value)
      ? value.filter(function(item) { return typeof item === "string" && item.trim() !== "" })
      : []
  }

  // apps.json: { "apps": [window classes to add], "disabled": [built-in patterns to skip] }
  function loadApps(text) {
    var data = {}
    try {
      data = JSON.parse(text) || {}
    } catch (e) {
      console.warn("hypr-passthrough: ignoring unreadable " + root.appsPath)
    }
    root.extraApps = stringList(Array.isArray(data) ? data : data.apps)
    root.disabledApps = stringList(data.disabled)
  }

  FileView {
    id: appsFile
    path: root.appsPath
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      root.loadApps(text())
      root.sync()
    }
    // Create the file, so it is watched and hand edits apply straight away.
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound) root.save()
    }
  }

  Process {
    id: mkdir
    command: ["mkdir", "-p", root.appsDir]
    onExited: appsFile.setText(JSON.stringify({ apps: root.extraApps, disabled: root.disabledApps }, null, 2) + "\n")
  }

  Process {
    id: loader

    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "ok") console.warn("hypr-passthrough: " + text.trim())
      }
    }

    onExited: {
      if (root.syncPending) {
        root.syncPending = false
        root.sync()
      } else {
        status.running = true
      }
    }
  }

  Process {
    id: status
    command: ["hyprctl", "repl", root.statusCode]

    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        if (lines.length === 0 || lines[0].charAt(0) !== "#") return
        var name = lines[0].substring(1).trim()
        if (name) root.submapName = name
        root.appPatterns = lines.slice(1).map(function(line) { return line.trim() }).filter(function(line) { return line !== "" })
      }
    }
  }

  Process {
    id: initialState
    command: ["sh", "-c", "hyprctl submap; hyprctl activewindow -j"]

    stdout: StdioCollector {
      onStreamFinished: {
        var newline = text.indexOf("\n")
        root.active = text.substring(0, newline).trim() === root.submapName
        try {
          root.activeClass = String(JSON.parse(text.substring(newline + 1)).class || "")
        } catch (e) {
          root.activeClass = ""
        }
      }
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (!event) return

      if (event.name === "configreloaded") {
        root.sync()
      } else if (event.name === "submap") {
        root.active = String(event.data || "") === root.submapName
      } else if (event.name === "activewindow") {
        var data = String(event.data || "")
        var comma = data.indexOf(",")
        root.activeClass = comma === -1 ? data : data.substring(0, comma)
      }
    }
  }

  Component.onCompleted: {
    sync()
    initialState.running = true
  }

  Component.onDestruction: Quickshell.execDetached(["hyprctl", "eval", root.unloadCode])
}
