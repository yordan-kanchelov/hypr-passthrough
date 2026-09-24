import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Bar widget for hypr-passthrough: shows whether shortcuts are being passed
// through, lists the apps it applies to, and adds any open app.
BarWidget {
  id: root
  moduleName: "yordan-kanchelov.passthrough"

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(moduleName) : null

  readonly property bool active: service ? service.active : false
  readonly property var extraApps: service ? service.extraApps : []
  readonly property var appPatterns: service ? service.appPatterns : []

  // The window focused when the popup opened; the popup itself takes focus.
  property string targetClass: ""

  // Every open app, once per window class, focused app first: [{ appClass, count }]
  readonly property var openApps: {
    var toplevels = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []
    var byClass = {}
    var apps = []
    for (var i = 0; i < toplevels.length; i++) {
      var appClass = String(toplevels[i].appId || "")
      if (!appClass) continue
      var key = appClass.toLowerCase()
      if (byClass[key]) {
        byClass[key].count++
      } else {
        byClass[key] = { appClass: appClass, count: 1 }
        apps.push(byClass[key])
      }
    }
    var focused = targetClass.toLowerCase()
    return apps.sort(function(a, b) {
      var af = a.appClass.toLowerCase() === focused, bf = b.appClass.toLowerCase() === focused
      if (af !== bf) return af ? -1 : 1
      return a.appClass.toLowerCase() < b.appClass.toLowerCase() ? -1 : 1
    })
  }
  property bool opened: false

  readonly property color textColor: Color.popups.text
  readonly property color mutedColor: Qt.darker(Color.popups.text, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    targetClass = service ? service.activeClass : ""
    opened = true
  }

  function close() {
    opened = false
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  // "^remote%-viewer$" -> "remote-viewer"
  function patternLabel(pattern) {
    return String(pattern).replace(/^\^/, "").replace(/\$$/, "").replace(/%(.)/g, "$1")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.active ? String.fromCodePoint(0xF08B9) : String.fromCodePoint(0xF030C)
    active: root.active
    tooltipText: root.opened ? "" : (root.active
      ? "Shortcuts go to " + (root.service ? root.service.activeClass : "the app")
      : "hypr-passthrough")
    onPressed: function(b) { root.toggle() }
  }

  PopupCard {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(520))

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        text: "hypr-passthrough"
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.active
          ? "On: shortcuts go to " + (root.service ? root.service.activeClass : "the app") + ". Super + Shift + Esc pauses."
          : "Turns on when a listed app is fullscreen and focused."
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        visible: !root.service
        width: parent.width
        wrapMode: Text.WordWrap
        text: "The passthrough service isn't running. Re-enable the plugin."
        color: Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      PanelSectionHeader {
        width: parent.width
        foreground: root.textColor
        fontFamily: root.fontFamily
        text: "Open apps"
      }

      Text {
        visible: root.openApps.length === 0
        text: "No open windows."
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.italic: true
      }

      ListView {
        id: openAppsList
        width: parent.width
        height: Math.min(contentHeight, Style.space(220))
        visible: root.openApps.length > 0
        clip: true
        interactive: contentHeight > height
        spacing: Style.space(4)
        model: root.openApps

        delegate: Item {
          id: appRow
          required property var modelData
          readonly property bool listed: root.service ? root.service.isListed(modelData.appClass) : false
          readonly property bool focused: modelData.appClass.toLowerCase() === root.targetClass.toLowerCase()
          width: openAppsList.width
          implicitHeight: addButton.implicitHeight
          height: implicitHeight

          Text {
            anchors.left: parent.left
            anchors.right: addButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: appRow.modelData.appClass
              + (appRow.modelData.count > 1 ? "  \u00d7" + appRow.modelData.count : "")
              + (appRow.focused ? "  (focused)" : "")
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: appRow.focused
          }

          Button {
            id: addButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            enabled: !appRow.listed
            text: appRow.listed ? "Listed" : "Add"
            iconText: appRow.listed ? "" : String.fromCodePoint(0xF0415)
            fontSize: Style.font.bodySmall
            fontFamily: root.fontFamily
            foreground: root.textColor
            opacity: enabled ? 1 : 0.5
            bordered: true
            onClicked: if (root.service) root.service.addApp(appRow.modelData.appClass)
          }
        }
      }

      PanelSectionHeader {
        width: parent.width
        foreground: root.textColor
        fontFamily: root.fontFamily
        text: "Your apps"
      }

      Text {
        visible: root.extraApps.length === 0
        text: "None yet. Click Add next to an open app."
        width: parent.width
        wrapMode: Text.WordWrap
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.italic: true
      }

      Repeater {
        model: root.extraApps

        delegate: Item {
          required property var modelData
          width: column.width
          implicitHeight: removeButton.implicitHeight

          Text {
            anchors.left: parent.left
            anchors.right: removeButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: modelData
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Button {
            id: removeButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: String.fromCodePoint(0xF0156)
            tooltipText: "Remove " + modelData
            fontSize: Style.font.bodySmall
            fontFamily: root.fontFamily
            foreground: root.textColor
            onClicked: if (root.service) root.service.removeApp(modelData)
          }
        }
      }

      PanelSectionHeader {
        width: parent.width
        foreground: root.textColor
        fontFamily: root.fontFamily
        text: "Built in"
      }

      Text {
        visible: root.appPatterns.length === 0
        text: "Loading..."
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Repeater {
        model: root.appPatterns

        delegate: Item {
          id: builtInRow
          required property var modelData
          readonly property bool enabledApp: root.service ? root.service.isBuiltInEnabled(modelData) : true
          width: column.width
          implicitHeight: builtInSwitch.implicitHeight

          Text {
            anchors.left: parent.left
            anchors.right: builtInSwitch.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: root.patternLabel(builtInRow.modelData)
            color: builtInRow.enabledApp ? root.textColor : root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          ToggleSwitch {
            id: builtInSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: builtInRow.enabledApp
            foreground: root.textColor
            onToggled: if (root.service) root.service.setBuiltInEnabled(builtInRow.modelData, !builtInRow.enabledApp)
          }
        }
      }
    }
  }
}
