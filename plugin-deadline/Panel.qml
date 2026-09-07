import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Deadline bar widget: countdown to the next deadline + upcoming list popup.
//
// Deadlines are entered by hand through `pomo deadline add` — no feed to import
// from, by design. This widget only reads and removes.
//
// Left click toggles the list, right click removes nothing (deliberately: the
// bar is a glance surface, destructive actions live in the popup behind `x`).
Panel {
  id: root
  moduleName: "student.deadline"
  ipcTarget: "student.deadline"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Match the pomodoro widget: underline the painted label, not the slot.
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // A popup that grows without bound stops being glanceable and starts
  // clipping against the panel's height cap. Show the front of the queue and
  // count the rest.
  readonly property int maxRows: 6
  readonly property var shown: svc.items.slice(0, maxRows)
  readonly property int hiddenCount: Math.max(0, svc.items.length - maxRows)

  // Single-column keyboard cursor over the visible rows. Mouse hover drives
  // the same state so exactly one row is highlighted at a time.
  property bool cursorActive: false
  property int cursorRow: 0

  function clampCursor() {
    root.cursorRow = Math.max(0, Math.min(root.shown.length - 1, root.cursorRow))
  }

  function moveCursor(dx, dy) {
    if (!root.cursorActive) {
      root.cursorActive = true
      root.clampCursor()
      return
    }
    if (dy !== 0) root.cursorRow += dy
    root.clampCursor()
  }

  function hoverCursor(row) {
    root.cursorActive = true
    root.cursorRow = row
  }

  function removeSelected() {
    if (!root.cursorActive) return
    var item = root.shown[root.cursorRow]
    if (item) svc.remove(item.id)
  }

  function rowColor(due) {
    return svc.isUrgent(due) ? root.urgent : svc.isNear(due) ? root.foreground : root.dim
  }

  onOpenedChanged: {
    if (opened) {
      root.cursorActive = false
      root.cursorRow = 0
    }
  }

  Connections {
    target: svc
    function onItemsChanged() { root.clampCursor() }
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
    // The bar label is the whole point of the widget, so it earns the theme's
    // urgent color once the next deadline is inside a day.
    foreground: svc.nextItem && svc.isUrgent(svc.nextItem.due)
      ? (bar ? bar.urgent : Color.urgent)
      : (bar ? bar.barForeground : Color.foreground)
    tooltipText: svc.tooltipText
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(400))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function (dx, dy) { root.moveCursor(dx, dy) }
      onDeleteRequested: root.removeSelected()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(8)

        PanelSectionHeader {
          text: "DEADLINES"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Text {
          visible: svc.items.length === 0
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "Nothing due. Add one from a terminal:\npomo deadline add \"Essay draft\" next friday 17:00"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Repeater {
          model: root.shown

          CursorSurface {
            id: row
            required property var modelData
            required property int index

            width: column.width
            implicitHeight: rowContent.implicitHeight + Style.space(10)
            hasCursor: root.cursorActive && root.cursorRow === index
            foreground: root.foreground

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onContainsMouseChanged: if (containsMouse) root.hoverCursor(row.index)
            }

            ColumnLayout {
              id: rowContent
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(8)

                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  text: row.modelData.title
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                Text {
                  textFormat: Text.PlainText
                  text: svc.fmtRel(row.modelData.due)
                  color: root.rowColor(row.modelData.due)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
              }

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: svc.fmtWhen(row.modelData.due)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        Text {
          visible: root.hiddenCount > 0
          width: parent.width
          textFormat: Text.PlainText
          text: "+" + root.hiddenCount + " more · pomo deadline list"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          visible: svc.items.length > 0
          width: parent.width
          textFormat: Text.PlainText
          text: "x removes the selected deadline"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
