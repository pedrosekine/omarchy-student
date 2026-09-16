# Plan — omarchy-student

## Architecture: Hybrid
- `cli/` — single-source timer core (bash/python first, Rust later if needed)
  - state file: `~/.local/state/omarchy-student/state.json`
  - commands: start, pause, resume, toggle, reset, skip, status
- `plugin/` — thin Omarchy bar widget (v0.2+) that calls `pomo status`
  - `manifest.json`, `BarWidget.qml`, `Service.qml`

## Steps (one at a time)
- [x] Step 1 — folder + README + this plan
- [x] Step 2 — `gh repo create pedrosekine/omarchy-student --public --source .` (done, origin set)
- [x] Step 3 — v0.1 CLI prototype: `cli/pomo` bash script + state file — on PATH via `ln -sfn "$PWD/cli/pomo" ~/.local/bin/pomo` (absolute target: re-link after moving the repo, or the bindings and both widgets fail with "binary could not be found")
- [x] Step 4 — Hypr bindings: `SUPER+ALT+P` toggle, `SUPER+ALT+N` skip in `~/.config/hypr/bindings.lua` (SUPER+P was taken by Pseudo window)
- [x] Step 5 — v0.2 bar widget: `plugin/` QML (`student.pomo`: countdown label + progress popup, left=popup, right=toggle, middle=skip). Installed as real files in `~/.config/omarchy/plugins/student.pomo` (symlinks not allowed there — copy on change, shell auto-reloads).
- [x] Step 6 — session counter: `pomo stats [day|week|month|--json]` (calendar week Mon–Sun) + popup segmented Day/Week/Month selector with live count. Counts `focus started` lines in `pomo.log`.
- [x] Step 7 — finish cue: `pomo bell` (desktop notification + bell sound), auto-fired once by the widget on running→expired edge. Sound: `sounds/done.wav` (Mixkit "Uplifting flute notification", free license, see sounds/README.md).
- [x] Step 8 — auto-start flow: `auto` flag in state.json, `pomo autostart [on|off|toggle]`, `pomo expired` edge handler (bell + auto-advance), popup switch. Provisional name "auto-start" — naming decision tracked in issue #1.
- [x] Step 9 — popup controls: icon buttons (play/pause, skip, reset) side by side; tap-timer duration picker (15/25/45/60 min chips when idle, tap toggles picker, tap while running pauses/resumes). CLI `pomo start [focus|break] [minutes]` with per-phase default persisted (`focus_len`/`break_len`/`total` in state.json).
- [x] Step 10 — typed minutes (idle timer is a minutes field, Enter starts) + completions-only counting (`focus completed` logged at expiry; CLI stats + popup recount).
- [x] Step 11 — microwave-style entry, no caret: plain focusable Text (cursor impossible), digits shift in (--:-2 → --:25 → 25:00 → 250:00), Backspace deletes, Enter starts, Escape blurs.
- [x] Step 12 — deadlines (manual): `pomo deadline add|list|rm|next`, stored as
      `deadlines.tsv` (`id<TAB>epoch<TAB>title`). Free-text dates via `date -d`
      ("next friday 17:00", "in 3 hours", "3d", "by friday"); a bare day snaps to
      23:59 because a deadline means the end of that day. New `student.deadline`
      bar widget (`plugin-deadline/`): calendar glyph + countdown to the next
      deadline, urgent-coloured inside 24h, popup lists the next 6 with `x` to
      remove. Installed alongside `student.pomo` in the bar's center section.
- [x] Step 13a — deadline identity: ids are handed out once and never reused
      (high-water mark in `deadlines.seq`, self-healing from the store when the
      file is missing), and `pomo deadline set <id> [--title <text>] [<when...>]`
      edits in place. Also fixed `parse_when`: GNU date reads today/tomorrow/
      yesterday as now +/- 24h, so those never hit the end-of-day snap and
      "tomorrow" landed at whatever o'clock you typed it.
- [x] Step 13b — closing deadlines out. Store grows three columns
      (`status<TAB>done_at<TAB>grade`; old three-column lines read as open).
      CLI: `pomo deadline done|reopen|grade|hide|unhide <id>`, `list --all`,
      and `pomo report --json` (timer + stats + every deadline incl. hidden,
      the one call an agent needs). Grading an open deadline marks it done;
      hiding keeps the record for the agent but drops it from list and popup;
      `rm` still deletes. Bar counts down to the next *open* deadline only
      (`✓` when everything is handed in). Popup is a keyboard grid: rows are
      deadlines, columns are the row itself (Enter = done/undo), grade (inline
      editor), hide, remove; `d` `g` `x` shortcuts; done rows strike through
      and sink to the bottom. `SUPER+ALT+D` summons it. Gotcha: the shell's
      plugin hot-reload keeps the old compiled component, so after copying
      QML into `~/.config/omarchy/plugins/` run `omarchy restart shell`.
- [ ] Later — deadline entry from the popup, `.ics` import for whoever *does*
      have a working feed, analytics (`history`), daily counter
- [ ] Step 14 — the diary: today's note is the capture surface, a local watcher
      triggers a cloud agent that replies inline, consent is per block. Timer and
      deadlines become features inside this surface. End-to-end plan with phases
      and open questions: `docs/todo-capture.md`

## v0.1 Keyboard contract
```bash
pomo toggle  # start/pause/resume
pomo skip    # next phase
pomo status  # JSON for scripts/bar
```

Hypr bindings (active):
```lua
o.bind("SUPER + ALT + P", "Pomo toggle", "pomo toggle")
o.bind("SUPER + ALT + N", "Pomo skip", "pomo skip")
o.bind("SUPER + ALT + O", "Pomo popup", "omarchy-shell student.pomo toggle")
o.bind("SUPER + ALT + D", "Deadlines popup", "omarchy-shell student.deadline toggle")
```

## Decisions
Longer-form design thinking lives in `docs/student-os.md` (agentic-first, cadence, progress, research).

- 2026-09-05: Hybrid, name omarchy-student, v0.1 = keyboard shortcuts
- 2026-09-07: Deadlines are manual-first and stay that way. Import was weighed
  and rejected for now: over years of study the feeds were "nothing but chaotic",
  and the deadlines that drive a study week (read ch.7, draft by Sunday, meet
  supervisor) never live in an LMS anyway. So entry has to be forgiving, and the
  store is deliberately shaped for a later read-only ICS sync — imported items
  would land in a separate file, keyed by UID, never written back, so "sync" is
  refetch-and-replace with no merge logic.
- 2026-09-09: Deadline ids are stable references, not row numbers. Sessions
  will attach to a deadline id (student-os.md D7), so a recycled id would make
  old log lines silently point at a different deadline, and rm+add to fix a
  wrong time would orphan a deadline's own history — hence `set`. Plain
  integers are enough because there is one writer: sync is parked and ICS
  import is read-only into a separate file keyed by UID, so the two namespaces
  stay distinguishable on sight (integer = manual, UID = imported). Revisit
  only if a second writer ever appears.
- 2026-09-05: Calendar parked — direct Google/Outlook sync needs two OAuth flows, too heavy. When revisited, start with local `.ics` export (importable anywhere), not live sync. Next: daily counter.
- 2026-09-15: GitHub for phone capture goes in as an *inbox*, not the truth.
  Reasons: no daemon, no API, no auth on this machine (student-os.md principle
  1); Tailscale on a phone is not free (~9%/day typical, known spikes); and
  GitHub can't push to a sleeping laptop, so the laptop pulls on a timer.
  Priority vocabulary is must/should/could — consequence, not date. Full
  reasoning in `docs/todo-capture.md`.
- 2026-09-16: The plan pivots. Daily note, not a todo app: the agent reads and
  answers in the note, and consent is per block, enforced by local code that
  logs every payload before inference. The agent may see drafts and essays but
  produces nothing submittable. The loop runs on the laptop only — one device
  must be enough, and a second always-awake machine would mean two writers over
  file sync. Cloud model through opencode; the surface comes after the loop.
  Details and phases in `docs/todo-capture.md`.
