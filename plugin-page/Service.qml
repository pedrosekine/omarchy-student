import QtQuick
import Quickshell
import Quickshell.Io

// Today's note: where it is, what it says, and the one place that writes it.
//
// Config comes from ~/.config/omarchy-student/config.json (see
// config.example.json in the repo). The vault path is machine-local and never
// lives in code. The note path is <vault>/<daily.dir>/<date in daily.format>.md,
// the same rule Obsidian's daily-notes plugin uses, so both agree on the file.
//
// Writes: create-if-missing from the template, then whatever the page holds.
// Atomic (temp + rename) so a half-written note never exists on disk, and
// async so a save costs the keystroke nothing. Nothing else in the system may
// write under the daily folder — that rule is what lets the agent say "I never
// touched your prose" and mean it.
Item {
  id: root

  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME")
    || Quickshell.env("HOME") + "/.config") + "/omarchy-student/config.json"

  property var config: ({})
  readonly property bool configured: !!(config && config.vault && config.daily && config.daily.dir)
  property string configError: ""

  // The note currently loaded. `text` mirrors disk after load and after
  // every save; the page compares against it to know if anything is pending.
  property string notePath: ""
  property string noteDate: ""
  property string text: ""
  property bool ready: false
  property bool pending: false
  property bool saving: false
  property string error: ""

  signal loaded()
  signal externalChange()

  property string lastWritten: ""

  // Obsidian's daily-notes format is a moment.js string; Qt wants its own
  // tokens. Only the tokens a date format plausibly uses are mapped.
  function momentToQt(fmt) {
    return fmt.replace(/YYYY/g, "yyyy").replace(/YY/g, "yy").replace(/DD/g, "dd")
      .replace(/ddd/g, "ddd").replace(/HH/g, "HH").replace(/mm/g, "mm")
  }

  function dailyFormat() {
    return (config.daily && config.daily.format) || "YYYY-MM-DD"
  }

  function todayStamp() {
    return Qt.formatDate(new Date(), momentToQt(dailyFormat()))
  }

  function pathFor(stamp) {
    return config.vault + "/" + config.daily.dir + "/" + stamp + ".md"
  }

  function templatePath() {
    return config.daily && config.daily.template ? config.vault + "/" + config.daily.template + ".md" : ""
  }

  // Obsidian template variables: {{date}}, {{date:FMT}}, {{title}}. Enough
  // for a one-line template; anything else passes through untouched.
  function renderTemplate(raw, stamp) {
    var now = new Date()
    return raw
      .replace(/\{\{date:([^}]+)\}\}/g, function (_, f) { return Qt.formatDate(now, momentToQt(f)) })
      .replace(/\{\{date\}\}/g, stamp)
      .replace(/\{\{title\}\}/g, stamp)
      .replace(/\{\{time\}\}/g, Qt.formatTime(now, "HH:mm"))
  }

  // Point at today's file. Same day: re-read it only when nothing is pending
  // or in flight, so an edit made elsewhere while the page was closed shows
  // up, and a save still landing can never be overwritten by its own past.
  // New day (or first open): load fresh.
  function openToday() {
    if (!configured) return
    var stamp = todayStamp()
    var p = pathFor(stamp)
    if (p === notePath && ready) {
      if (!saving && !pending) noteFile.reload()
      return
    }
    root.ready = false
    root.error = ""
    root.noteDate = stamp
    root.notePath = p
    root.lastWritten = ""
    if (noteFile.path === p) noteFile.reload()
    else noteFile.path = p
  }

  // Called by the page with its current text. No-ops when nothing changed
  // since the last write, so a save per keystroke never touches disk twice.
  function save(content) {
    if (!ready || error !== "") return
    if (content === lastWritten) { root.pending = false; return }
    root.lastWritten = content
    root.text = content
    root.saving = true
    noteFile.setText(content)
  }

  function markPending(content) {
    root.pending = content !== lastWritten
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        root.config = JSON.parse(text())
        root.configError = root.configured ? "" : "config.json needs vault and daily.dir"
      } catch (e) {
        root.config = ({})
        root.configError = "config.json is not valid JSON: " + e
      }
    }
    onLoadFailed: function (err) {
      root.config = ({})
      root.configError = "No config at " + root.configPath
    }
    onFileChanged: reload()
  }

  FileView {
    id: templateFile
    path: root.templatePath()
    blockLoading: true
    printErrors: false
  }

  FileView {
    id: noteFile
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var t = text()
      // A load that lands while our own write is in flight, or that reads
      // back exactly what we wrote, carries no news.
      if (root.ready && (root.saving || t === root.lastWritten)) return
      var external = root.ready
      root.lastWritten = t
      root.text = t
      root.ready = true
      root.pending = false
      if (external) root.externalChange()
      else root.loaded()
    }
    onLoadFailed: function (err) {
      if (err === FileViewError.FileNotFound) {
        // First write of the day: seed from the template, if any. This is
        // the one create path; Obsidian would do the same on its side.
        var raw = ""
        try { raw = templateFile.text() } catch (e) { raw = "" }
        var seed = raw ? root.renderTemplate(raw, root.noteDate) : ""
        root.lastWritten = seed
        root.text = seed
        root.ready = true
        root.pending = false
        if (seed !== "") noteFile.setText(seed)
        root.loaded()
        return
      }
      root.error = "Cannot read " + root.notePath + ": " + FileViewError.toString(err)
      root.ready = false
    }
    onSaved: { root.saving = false; root.pending = false }
    onSaveFailed: function (err) {
      root.saving = false
      root.error = "Cannot write " + root.notePath + ": " + FileViewError.toString(err)
    }
  }
}
