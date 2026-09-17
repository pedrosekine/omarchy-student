import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The quick-add gesture for the mouse: a glyph that opens today's note. It
// takes the accent colour when a reply is waiting that the student has not
// looked at yet — the same signal as the mark in the page header.
BarWidget {
  id: root
  moduleName: "student.page"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service { id: svc }
  AgentState { id: agent; config: svc.config }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰏫"
    foreground: agent.unread > 0
      ? (bar ? bar.urgent : Color.urgent)
      : (bar ? bar.barForeground : Color.foreground)
    tooltipText: agent.unread > 0
      ? "Today's note · " + agent.unread + (agent.unread === 1 ? " reply" : " replies") + " waiting"
      : "Today's note"
    onPressed: {
      if (root.bar) root.bar.run("omarchy-shell shell toggle student.page '{}'")
      else Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "student.page", "{}"])
    }
  }
}
