import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Blocks.js" as Blocks

// The page: today's note as a blank sheet in the shell.
//
// No file tree, no chrome. A themed sheet, the date, the text. Every keystroke
// is saved (coalesced over a few hundred milliseconds, flushed on Enter and
// on close) so the file on disk is always what you see. Escape closes.
//
// Editing niceties that make markdown capture cheap: Enter continues a list
// item (checkboxes reset to unticked), Enter on an empty item leaves the
// list, Tab indents. Ctrl+Up/Down jump between blocks — the same block
// splitting the agent will use, so the navigation unit and the reply unit
// are one thing from day one.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property color dim: Util.alpha(foreground, 0.45)
  readonly property color faint: Util.alpha(foreground, 0.22)
  readonly property color urgent: Color.urgent
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  readonly property string fontFamily: Style.font.family
  readonly property int textSize: Style.font.heading
  readonly property real lineHeight: 1.45

  readonly property int sheetWidth: Math.min(Style.space(760), panel.width - Style.space(48))
  readonly property int sheetMargin: Style.space(28)
  readonly property int sheetPadding: Style.space(44)

  property string dateLabel: ""
  property bool applying: false

  readonly property string problem: svc.configError || svc.error

  function open(payloadJson) {
    root.opened = true
    root.dateLabel = Qt.formatDate(new Date(), "dddd d MMMM")
    svc.openToday()
    Qt.callLater(function () { editor.forceActiveFocus() })
  }

  function close() {
    root.flush()
    root.opened = false
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "student.page")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // Disk → editor. Guarded so the resulting textChanged does not look like
  // typing and schedule a write of what was just read.
  function applyText(t) {
    root.applying = true
    editor.text = t
    root.applying = false
    editor.cursorPosition = editor.length
  }

  function flush() {
    saveTimer.stop()
    if (svc.ready) svc.save(editor.text)
  }

  function lineBounds(pos) {
    var t = editor.text
    var start = t.lastIndexOf("\n", pos - 1) + 1
    var end = t.indexOf("\n", pos)
    if (end < 0) end = t.length
    return { start: start, end: end, text: t.substring(start, end) }
  }

  // Enter inside a list item carries the marker to the next line; Enter on
  // an item with nothing after the marker removes the marker instead.
  function handleReturn() {
    var pos = editor.cursorPosition
    var line = root.lineBounds(pos)
    var m = line.text.match(/^(\s*)([-*+]\s(\[[ xX]\]\s)?|(\d+)([.)])\s)(.*)$/)
    if (!m) {
      editor.insert(pos, "\n")
      return
    }
    var content = m[6]
    if (content === "" && pos >= line.end) {
      editor.remove(line.start, line.end)
      return
    }
    var marker = m[2]
    if (m[3]) marker = m[2].replace(/\[[xX]\]/, "[ ]")
    else if (m[4]) marker = (parseInt(m[4], 10) + 1) + m[5] + " "
    editor.insert(pos, "\n" + m[1] + marker)
  }

  function lineIndexAt(pos) {
    var n = 0
    var t = editor.text
    for (var i = 0; i < pos && i < t.length; i++) if (t.charCodeAt(i) === 10) n++
    return n
  }

  function positionOfLine(lineIndex) {
    var t = editor.text
    var pos = 0
    for (var k = 0; k < lineIndex; k++) {
      var nl = t.indexOf("\n", pos)
      if (nl < 0) return t.length
      pos = nl + 1
    }
    return pos
  }

  // Ctrl+Up / Ctrl+Down: previous / next block start.
  function jumpBlock(direction) {
    var blocks = Blocks.split(editor.text)
    if (blocks.length === 0) return
    var line = root.lineIndexAt(editor.cursorPosition)
    var target = -1
    if (direction < 0) {
      for (var i = blocks.length - 1; i >= 0; i--) if (blocks[i].start < line) { target = i; break }
    } else {
      for (var j = 0; j < blocks.length; j++) if (blocks[j].start > line) { target = j; break }
    }
    if (target < 0) return
    editor.cursorPosition = root.positionOfLine(blocks[target].start)
  }

  Service {
    id: svc
    onLoaded: root.applyText(svc.body)
    onExternalChange: root.applyText(svc.body)
  }

  Timer {
    id: saveTimer
    interval: 300
    onTriggered: root.flush()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "student-page"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: sheet
      width: root.sheetWidth
      height: panel.height - root.sheetMargin * 2
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: root.sheetPadding

      MouseArea {
        anchors.fill: parent
        onClicked: editor.forceActiveFocus()
      }

      Item {
        anchors.fill: parent
        anchors.topMargin: sheet.contentTopInset
        anchors.rightMargin: sheet.contentRightInset
        anchors.bottomMargin: sheet.contentBottomInset
        anchors.leftMargin: sheet.contentLeftInset

        Item {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: dateText.implicitHeight

          Text {
            id: dateText
            anchors.left: parent.left
            textFormat: Text.PlainText
            text: root.dateLabel
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          // Right side: the agent mark and the save dot. The mark stands in
          // for the template's link line, which the service keeps out of the
          // editor; it will carry the reply-waiting state once there is one.
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Text {
              visible: svc.header !== ""
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "agent"
              color: root.faint
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            // Saved / unsaved, as quietly as possible: a dot that brightens
            // while a write is pending and settles once it landed.
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(6)
              height: width
              radius: width / 2
              color: root.problem !== "" ? root.urgent : (svc.pending || svc.saving ? root.foreground : root.faint)
              Behavior on color { ColorAnimation { duration: 180 } }
            }
          }
        }

        Text {
          visible: root.problem !== ""
          anchors.top: header.bottom
          anchors.topMargin: Style.space(24)
          anchors.left: parent.left
          anchors.right: parent.right
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: root.problem
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        Flickable {
          id: flick
          visible: root.problem === ""
          anchors.top: header.bottom
          anchors.topMargin: Style.space(24)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          clip: true
          contentWidth: width
          contentHeight: editor.contentHeight + height * 0.4
          boundsBehavior: Flickable.StopAtBounds

          function ensureVisible(r) {
            if (contentY >= r.y) contentY = r.y
            else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
          }

          TextEdit {
            id: editor
            width: flick.width
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            selectByKeyboard: true
            persistentSelection: false
            color: root.foreground
            selectionColor: Style.selectionFill
            selectedTextColor: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.textSize
            // TextEdit has no line-height property; a slightly larger font
            // box does the job of breathing room between lines.
            cursorVisible: activeFocus
            enabled: svc.ready
            tabStopDistance: 4 * Style.space(8)

            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            onTextChanged: {
              if (root.applying) return
              svc.markPending(text)
              saveTimer.restart()
            }

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function (event) {
              if (event.key === Qt.Key_Escape) {
                root.dismiss()
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier)) return
                root.handleReturn()
                Qt.callLater(root.flush)
                event.accepted = true
              } else if (event.key === Qt.Key_Tab) {
                editor.insert(editor.cursorPosition, "\t")
                event.accepted = true
              } else if (event.key === Qt.Key_Up && (event.modifiers & Qt.ControlModifier)) {
                root.jumpBlock(-1)
                event.accepted = true
              } else if (event.key === Qt.Key_Down && (event.modifiers & Qt.ControlModifier)) {
                root.jumpBlock(1)
                event.accepted = true
              }
            }
          }
        }
      }
    }
  }
}
