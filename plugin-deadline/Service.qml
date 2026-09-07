import QtQuick
import Quickshell
import Quickshell.Io

// Live deadline list. Watches the CLI's deadlines.tsv (one "id<TAB>epoch<TAB>title"
// per line) and recomputes countdowns locally every second — same no-polling
// shape as the pomodoro Service.
Item {
  id: root

  property var settings: ({})

  // Parsed file contents, sorted by due date (soonest first).
  property var items: []
  property int nowSec: Math.floor(Date.now() / 1000)

  readonly property string filePath: (Quickshell.env("XDG_STATE_HOME")
    || Quickshell.env("HOME") + "/.local/state") + "/omarchy-student-pomodoro/deadlines.tsv"

  // What the bar shows: the soonest deadline still ahead, or — when everything
  // has already passed — the least-late one. Mirrors `pomo deadline next`.
  readonly property var nextItem: pickNext()

  function pickNext() {
    var last = null
    for (var i = 0; i < items.length; i++) {
      if (items[i].due >= nowSec) return items[i]
      last = items[i]
    }
    return last
  }

  // Urgency bands, shared by the bar label and the popup rows.
  readonly property int soonSecs: 24 * 3600
  readonly property int nearSecs: 3 * 24 * 3600

  function isLate(due) {
    return due < nowSec
  }

  function isUrgent(due) {
    return due - nowSec < soonSecs
  }

  function isNear(due) {
    return due - nowSec < nearSecs
  }

  function unit(secs) { // largest whole unit: 4d / 3h / 25m
    var a = Math.abs(secs)
    if (a >= 86400) return Math.floor(a / 86400) + "d"
    if (a >= 3600) return Math.floor(a / 3600) + "h"
    return Math.floor(a / 60) + "m"
  }

  function fmtRel(due) { // "in 4d" / "2h late"
    var d = due - nowSec
    return d < 0 ? unit(d) + " late" : "in " + unit(d)
  }

  function fmtWhen(due) { // "Fri 11 Sep 17:00"
    return Qt.formatDateTime(new Date(due * 1000), "ddd d MMM HH:mm")
  }

  // Bar label: bare countdown, no "in" — the calendar glyph already says what
  // it is, and bar space is the scarcest thing on screen.
  readonly property string labelText: nextItem
    ? " " + (isLate(nextItem.due) ? "late" : unit(nextItem.due - nowSec))
    : " --"

  readonly property string tooltipText: nextItem
    ? nextItem.title + " — " + fmtWhen(nextItem.due) + " (" + fmtRel(nextItem.due) + ")"
    : "No deadlines — pomo deadline add \"Essay draft\" friday"

  function tick() {
    nowSec = Math.floor(Date.now() / 1000)
  }

  function applyText(raw) {
    var out = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].split("\t")
      if (f.length < 3) continue
      var id = parseInt(f[0], 10)
      var due = parseInt(f[1], 10)
      if (!isFinite(id) || !isFinite(due)) continue
      // Titles can't contain tabs (the CLI strips them), so anything past the
      // third field is a stray tab in a hand-edited file — rejoin it.
      out.push({ id: id, due: due, title: f.slice(2).join(" ") })
    }
    out.sort(function (a, b) { return a.due - b.due })
    items = out
  }

  function fileGone() {
    items = []
  }

  // Fire-and-forget CLI action; the FileView picks up the result.
  function remove(id) {
    if (actionProc.running) return
    actionProc.command = ["pomo", "deadline", "rm", String(id)]
    actionProc.running = true
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.tick()
  }

  FileView {
    path: root.filePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyText(text())
    onLoadFailed: root.fileGone()
  }

  Process {
    id: actionProc
    running: false
  }
}
