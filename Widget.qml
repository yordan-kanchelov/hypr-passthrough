import QtQuick
import qs.Commons
import qs.Ui

// Bar widget for hypr-passthrough: shows whether shortcuts are being passed
// through, lists the apps it applies to, and adds the focused window's app.
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
      : "Shortcut passthrough")
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
        text: "Shortcut passthrough"
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
        text: "Focused window"
      }

      Item {
        width: parent.width
        implicitHeight: addButton.implicitHeight

        Text {
          anchors.left: parent.left
          anchors.right: addButton.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: root.targetClass || "No focused window"
          color: root.targetClass ? root.textColor : root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Button {
          id: addButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          readonly property bool listed: root.service ? root.service.isListed(root.targetClass) : false
          visible: root.targetClass !== ""
          enabled: !listed
          text: listed ? "Listed" : "Add"
          iconText: listed ? "" : String.fromCodePoint(0xF0415)
          fontSize: Style.font.bodySmall
          fontFamily: root.fontFamily
          foreground: root.textColor
          opacity: enabled ? 1 : 0.5
          bordered: true
          onClicked: if (root.service) root.service.addApp(root.targetClass)
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
        text: "None yet. Focus an app, open this menu and click Add."
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
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: root.appPatterns.length > 0
          ? root.appPatterns.map(root.patternLabel).join(", ")
          : "Loading..."
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
