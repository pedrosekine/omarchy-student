# Plan — omarchy-student-pomodoro

## Architecture: Hybrid
- `cli/` — single-source timer core (bash/python first, Rust later if needed)
  - state file: `~/.local/state/omarchy-student-pomodoro/state.json`
  - commands: start, pause, resume, toggle, reset, skip, status
- `plugin/` — thin Omarchy bar widget (v0.2+) that calls `pomo status`
  - `manifest.json`, `BarWidget.qml`, `Service.qml`

## Steps (one at a time)
- [x] Step 1 — folder + README + this plan
- [x] Step 2 — `gh repo create pedrosekine/omarchy-student-pomodoro --public --source .` (done, origin set)
- [x] Step 3 — v0.1 CLI prototype: `cli/pomo` bash script + state file
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
- [ ] Later — deadline entry from the popup, `.ics` import for whoever *does*
      have a working feed, analytics (`history`), daily counter

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
```

## Decisions
- 2026-09-05: Hybrid, name omarchy-student-pomodoro, v0.1 = keyboard shortcuts
- 2026-09-07: Deadlines are manual-first and stay that way. Import was weighed
  and rejected for now: over years of study the feeds were "nothing but chaotic",
  and the deadlines that drive a study week (read ch.7, draft by Sunday, meet
  supervisor) never live in an LMS anyway. So entry has to be forgiving, and the
  store is deliberately shaped for a later read-only ICS sync — imported items
  would land in a separate file, keyed by UID, never written back, so "sync" is
  refetch-and-replace with no merge logic.
- 2026-09-05: Calendar parked — direct Google/Outlook sync needs two OAuth flows, too heavy. When revisited, start with local `.ics` export (importable anywhere), not live sync. Next: daily counter.
