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
// alone.
Item {
  id: root

  readonly property string modulePath: decodeURIComponent(
    Qt.resolvedUrl("passthrough.lua").toString().replace(/^file:\/\//, "")
  )

  readonly property string loadCode:
    "if not hypr_passthrough then dofile(" + luaString(modulePath) + ").setup().loaded_by = 'omarchy-plugin' end"

  readonly property string unloadCode:
    "if hypr_passthrough and hypr_passthrough.loaded_by == 'omarchy-plugin' then hypr_passthrough.teardown() end"

  property bool loadPending: false

  function luaString(value) {
    return "\"" + value.replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
  }

  function load() {
    if (loader.running) {
      loadPending = true
      return
    }

    loader.running = true
  }

  Process {
    id: loader
    command: ["hyprctl", "eval", root.loadCode]

    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "ok") console.warn("hypr-passthrough: " + text.trim())
      }
    }

    onRunningChanged: {
      if (!running && root.loadPending) {
        root.loadPending = false
        running = true
      }
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event && event.name === "configreloaded") root.load()
    }
  }

  Component.onCompleted: load()
  Component.onDestruction: Quickshell.execDetached(["hyprctl", "eval", root.unloadCode])
}
