import QtQuick
import Quickshell
import Quickshell.Io

// Live Pomodoro state. Watches the CLI's state.json (no polling processes)
// and recomputes the countdown locally every second.
Item {
  id: root

  property var settings: ({})

  // Must mirror cli/pomo FOCUS_LEN / BREAK_LEN.
  readonly property int focusLen: 1500
  readonly property int breakLen: 300

  // Raw state from the file.
  property string phase: "idle" // idle | focus | break
  property string runStatus: "idle" // idle | running | paused | done
  property int endsAt: 0
  property int storedRemaining: 0
  property bool autoStart: false

  // Live values.
  property int nowSec: Math.floor(Date.now() / 1000)
  property int remaining: 0
  property int total: 0 // this session's length (stored by cli/pomo)

  // Fallback for sessions started before total was stored.
  readonly property int effTotal: total > 0 ? total : phase === "focus" ? focusLen : phase === "break" ? breakLen : 0

  readonly property bool expired: (runStatus === "done") || (runStatus === "running" && phase !== "idle" && endsAt > 0 && nowSec >= endsAt)
  readonly property bool live: runStatus === "running" && !expired
  readonly property real progress: effTotal > 0 ? Math.max(0, Math.min(1, 1 - remaining / effTotal)) : 0

  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
    || Quickshell.env("HOME") + "/.local/state") + "/omarchy-student-pomodoro/state.json"

  function fmt(s) {
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" + r : r)
  }

  readonly property string labelText: phase === "idle" ? "○ --:--"
    : (runStatus === "paused" ? "○ " : "● ") + fmt(remaining)

  readonly property string phaseTitle: expired ? "Done" : phase === "focus" ? "Focus"
    : phase === "break" ? "Break" : "Pomodoro"

  // Expiry edge detection: ring once when a running phase hits zero.
  // The CLI persists a "done" status on completion, so re-ticks (or a
  // pause/resume cycle on the finished timer) can't re-fire and double-count.
  // firstTick avoids a spurious bell when the shell (re)starts mid-expiry.
  property bool prevExpired: false
  property bool firstTick: true

  function tick() {
    nowSec = Math.floor(Date.now() / 1000)
    remaining = runStatus === "running" ? Math.max(0, endsAt - nowSec) : storedRemaining
    var e = runStatus === "running" && phase !== "idle" && endsAt > 0 && nowSec >= endsAt
    if (e && !prevExpired && !firstTick && !expiredProc.running) {
      expiredProc.command = ["pomo", "expired"]
      expiredProc.running = true
    }
    prevExpired = e
    firstTick = false
  }

  // Session counters from the CLI log (same scopes as `pomo stats`).
  property int dayCount: 0
  property int weekCount: 0
  property int monthCount: 0

  readonly property string logPath: (Quickshell.env("XDG_STATE_HOME")
    || Quickshell.env("HOME") + "/.local/state") + "/omarchy-student-pomodoro/pomo.log"

  function pad(n) {
    return (n < 10 ? "0" : "") + n
  }

  function isoDay(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
  }

  function recount(raw) {
    var now = new Date()
    var day = isoDay(now)
    var monday = new Date(now)
    monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7))
    var mon = isoDay(monday)
    var m1 = now.getFullYear() + "-" + pad(now.getMonth() + 1) + "-01"
    var dc = 0, wc = 0, mc = 0
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].indexOf("focus completed") < 0) continue
      var dt = lines[i].substring(0, 10)
      if (dt >= day) dc++
      if (dt >= mon) wc++
      if (dt >= m1) mc++
    }
    dayCount = dc
    weekCount = wc
    monthCount = mc
  }

  function zeroCounts() {
    dayCount = 0
    weekCount = 0
    monthCount = 0
  }

  function applyText(raw) {
    var d = null
    try {
      d = JSON.parse(raw)
    } catch (e) {
      return
    }
    phase = d.phase || "idle"
    runStatus = d.status || "idle"
    endsAt = d.ends_at || 0
    storedRemaining = d.remaining || 0
    total = d.total || 0
    autoStart = d.auto === true
    tick()
  }

  function stateGone() {
    phase = "idle"
    runStatus = "idle"
    endsAt = 0
    storedRemaining = 0
    total = 0
    autoStart = false
    tick()
  }

  // Fire-and-forget CLI actions; the FileView picks up the result.
  function run() {
    if (actionProc.running) return
    var cmd = ["pomo"]
    for (var i = 0; i < arguments.length; i++) cmd.push(arguments[i])
    actionProc.command = cmd
    actionProc.running = true
  }

  function toggle() {
    run("toggle")
  }

  function skip() {
    run("skip")
  }

  function reset() {
    run("reset")
  }

  function startFocus(minutes) {
    run("start", "focus", String(minutes))
  }

  function autostartToggle() {
    if (actionProc.running) return
    actionProc.command = ["pomo", "autostart", "toggle"]
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
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyText(text())
    onLoadFailed: root.stateGone()
  }

  FileView {
    path: root.logPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.recount(text())
    onLoadFailed: root.zeroCounts()
  }

  Process {
    id: actionProc
    running: false
  }

  Process {
    id: expiredProc
    running: false
  }
}
