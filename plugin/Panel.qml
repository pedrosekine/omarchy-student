import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Pomodoro bar widget: countdown label + progress popup (clock-style).
//
// Left click toggles the progress popup, right click toggles pause/resume,
// middle click skips to the next phase.
Panel {
  id: root
  moduleName: "student.pomo"
  ipcTarget: "student.pomo"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Counter scope toggle: 0 = day, 1 = week, 2 = month.
  property int scopeIndex: 0

  // Microwave-style duration entry (idle only): digits shift in from the
  // right, e.g. 2 -> --:-2, 25 -> --:25, 2500 -> 25:00, 25000 -> 250:00.
  property string entryDigits: ""

  function entryText() {
    var d = entryDigits
    while (d.length < 4) d = "-" + d
    if (d.length > 4) return d.substring(0, d.length - 2) + ":" + d.substring(d.length - 2)
    return d.substring(0, 2) + ":" + d.substring(2, 4)
  }

  function entrySeconds() {
    var d = entryDigits
    while (d.length < 4) d = "0" + d
    var ss = parseInt(d.substring(d.length - 2), 10)
    var mm = parseInt(d.substring(0, d.length - 2), 10)
    return mm * 60 + ss
  }

  function startFromEntry() {
    var s = entrySeconds()
    if (s <= 0) return
    svc.startFocus(Math.max(1, Math.round(s / 60)))
    root.entryDigits = ""
  }

  onOpenedChanged: {
    if (opened && svc.phase === "idle") idleTimer.focus = true
    else if (!opened) root.entryDigits = ""
  }

  function scopeCount() {
    return scopeIndex === 0 ? svc.dayCount : scopeIndex === 1 ? svc.weekCount : svc.monthCount
  }

  function scopeText() {
    var n = scopeCount()
    var sessions = n === 1 ? "1 session" : n + " sessions"
    return sessions + (scopeIndex === 0 ? " today" : scopeIndex === 1 ? " this week" : " this month")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service {
    id: svc
    settings: root.settings
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: svc.labelText
    tooltipText: "Pomodoro — left: progress, right: pause/resume, middle: skip"
    onPressed: function (b) {
      if (b === Qt.RightButton) svc.toggle()
      else if (b === Qt.MiddleButton) svc.skip()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(400))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) {
        root.switchPanel(direction)
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        RowLayout {
          width: parent.width
          spacing: Style.space(12)

          Text {
            id: idleTimer
            visible: svc.phase === "idle"
            Layout.preferredWidth: Style.space(110)
            Layout.alignment: Qt.AlignVCenter
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignLeft
            text: root.entryText()
            color: root.entryDigits === "" ? root.dim : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: idleTimer.focus = true
            }

            Keys.onPressed: function (event) {
              if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                if (root.entryDigits.length < 5) root.entryDigits += (event.key - Qt.Key_0)
                event.accepted = true
              } else if (event.key === Qt.Key_Backspace) {
                root.entryDigits = root.entryDigits.slice(0, -1)
                event.accepted = true
              }
            }
            Keys.onReturnPressed: root.startFromEntry()
            Keys.onEnterPressed: root.startFromEntry()
            Keys.onEscapePressed: idleTimer.focus = false
          }

          Text {
            visible: svc.phase !== "idle"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignLeft
            text: svc.fmt(svc.remaining)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: svc.toggle()
            }
          }

          PanelActionButton {
            Layout.alignment: Qt.AlignVCenter
            foreground: root.foreground
            iconText: svc.runStatus === "running" && !svc.expired ? "\uf04c" : "\uf04b"
            tooltipText: svc.runStatus === "running" && !svc.expired ? "Pause" : "Resume"
            onClicked: svc.toggle()
          }

          PanelActionButton {
            Layout.alignment: Qt.AlignVCenter
            foreground: root.foreground
            iconText: "\uf051"
            tooltipText: "Skip to next phase"
            onClicked: svc.skip()
          }

          PanelActionButton {
            Layout.alignment: Qt.AlignVCenter
            foreground: root.foreground
            iconText: "\uf021"
            tooltipText: "Reset to idle"
            onClicked: svc.reset()
          }
        }

        RowLayout {
          visible: svc.phase === "idle"
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: [15, 25, 45, 60]

            Rectangle {
              required property int modelData

              Layout.fillWidth: true
              implicitHeight: pickLabel.implicitHeight + Style.space(12)
              radius: Style.space(4)
              color: "transparent"
              border.color: root.dim
              border.width: 1

              Text {
                id: pickLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: parent.modelData + " min"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: svc.startFocus(parent.modelData)
              }
            }
          }
        }

        Rectangle {
          id: track
          width: parent.width
          implicitHeight: Style.space(6)
          radius: height / 2
          color: Qt.darker(root.foreground, 3.2)

          Rectangle {
            width: track.width * svc.progress
            height: parent.height
            radius: parent.radius
            color: root.foreground
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: svc.effTotal > 0
          width: parent.width
          horizontalAlignment: Text.AlignLeft
          text: svc.fmt(svc.effTotal - svc.remaining) + " elapsed · " + svc.fmt(svc.remaining) + " left"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignLeft
          text: root.scopeText()
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        RowLayout {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: ["Day", "Week", "Month"]

            Rectangle {
              required property string modelData
              required property int index

              readonly property bool selected: root.scopeIndex === index

              Layout.fillWidth: true
              implicitHeight: segLabel.implicitHeight + Style.space(12)
              radius: Style.space(4)
              color: selected ? root.dim : "transparent"
              border.color: root.dim
              border.width: 1

              Text {
                id: segLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: parent.modelData
                color: selected ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.scopeIndex = parent.index
              }
            }
          }
        }

        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
            text: "Auto-start breaks & focus"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          ToggleSwitch {
            Layout.alignment: Qt.AlignVCenter
            checked: svc.autoStart
            foreground: root.foreground
            onToggled: svc.autostartToggle()
          }
        }
      }
    }
  }
}
