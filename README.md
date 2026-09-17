# omarchy-student

Hybrid Pomodoro and deadline tracker for Omarchy: CLI that works in terminal +
thin bar widgets. Keyboard-first v0.1. Next: a diary page in the shell that an
agent reads and answers — reference plan in `docs/diary.md`.

## Why hybrid?

- **Plugin-only** = QML running inside `omarchy-shell`. Dies with shell, no terminal use.
- **Standalone** = CLI/daemon (like `focusd`). Works in terminal, scriptable, survives restarts.
- **Hybrid (this project)** = standalone core + thin plugin that just displays status.
  Best for keyboard shortcuts because bindings call the CLI even when bar is closed.

## Scope v0.1 (keyboard shortcuts only)

- `pomo start [focus|break|up] [minutes|up]|pause|resume|toggle|reset|skip|status` from terminal
  (`pomo start up` runs an open-ended count-up focus session; skipping it logs
  the elapsed time as a completed session)
- `pomo deadline add|set|list|done|reopen|grade|hide|unhide|rm|next` — manual
  deadlines with free-text dates ("next friday 17:00", "in 3 days"); `done`
  takes one off the clock, `grade` records the mark, `hide` keeps the record
  but drops it from the list
- Hypr bindings example in `docs/plan.md`
- State in JSON file, no bar widget yet

## Out of scope for v0.1

- Bar widget, analytics UI, calendar integration

See `docs/plan.md` for full steps.

## The page (phase 14.1)

`plugin-page/` is a full-screen overlay for `omarchy-shell`: today's note as a
blank sheet in the current theme, saved on every keystroke. `SUPER+ALT+J`
opens it, `Esc` closes. Needs `~/.config/omarchy-student/config.json` (copy
`config.example.json`) pointing at your vault; the note lives at
`<vault>/<daily.dir>/<date>.md` exactly where Obsidian's daily notes would.

```bash
cp -r plugin-page ~/.config/omarchy/plugins/student.page   # then add {"id":"student.page"} to plugins[] in ~/.config/omarchy/shell.json
python3 tests/test_blocks.py                                # block splitter, JS and Python must agree (needs node)
```

## Pointing an agent at it

Everything is plain files plus one command, no daemon:

```bash
pomo report --json        # timer state, session counts, every deadline (incl. hidden) with status/done_at/grade
pomo deadline list --all --json
pomo status               # timer only
```

Files live in `~/.local/state/omarchy-student/`:

| File | What |
|------|------|
| `deadlines.tsv` | `id<TAB>due_epoch<TAB>title<TAB>status<TAB>done_at_epoch<TAB>grade` — status is open / done / hidden |
| `pomo.log` | one line per event (`focus completed · 25:00`, `deadline #3 graded 7.5 · Essay`) — the history an agent reasons over |
| `state.json` | current timer |

Ids are stable and never reused, so a log line about `#3` always means the same
deadline. Write through the CLI (`pomo deadline ...`), not to the files, so the
bar widget and the log stay in step. Design notes for the agent side are in
`docs/student-os.md`.
