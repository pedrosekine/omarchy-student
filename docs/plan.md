# Plan — omarchy-student-pomodoro

## Architecture: Hybrid
- `cli/` — single-source timer core (bash/python first, Rust later if needed)
  - state file: `~/.local/state/omarchy-student-pomodoro/state.json`
  - commands: start, pause, resume, toggle, reset, skip, status
- `plugin/` — thin Omarchy bar widget (v0.2+) that calls `pomo status`
  - `manifest.json`, `BarWidget.qml`, `Service.qml`

## Steps (one at a time)
- [x] Step 1 — folder + README + this plan
- [ ] Step 2 — `gh repo create pedrosekine/omarchy-student-pomodoro --public --source .`
- [ ] Step 3 — v0.1 CLI prototype: `cli/pomo` bash script + state file
- [ ] Step 4 — Hypr bindings: `SUPER+P` toggle, `SUPER+N` skip in `~/.config/hypr/bindings.lua`
- [ ] Step 5 — v0.2 thin bar plugin reading CLI status
- [ ] Later — daily counter, analytics (`history`, `stats`), calendar (CalDAV/ICS)

## v0.1 Keyboard contract
```bash
pomo toggle  # start/pause/resume
pomo skip    # next phase
pomo status  # JSON for scripts/bar
```

Hypr example (for later):
```lua
o.bind("SUPER", "P", "exec, pomo toggle")
o.bind("SUPER", "N", "exec, pomo skip")
```

## Decisions
- 2026-09-05: Hybrid, name omarchy-student-pomodoro, v0.1 = keyboard shortcuts
