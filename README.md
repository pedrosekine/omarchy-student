# omarchy-student-pomodoro

Hybrid Pomodoro for Omarchy Quattro: CLI that works in terminal + thin bar display.
Keyboard-first v0.1.

## Why hybrid?

- **Plugin-only** = QML running inside `omarchy-shell`. Dies with shell, no terminal use.
- **Standalone** = CLI/daemon (like `focusd`). Works in terminal, scriptable, survives restarts.
- **Hybrid (this project)** = standalone core + thin plugin that just displays status.
  Best for keyboard shortcuts because bindings call the CLI even when bar is closed.

## Scope v0.1 (keyboard shortcuts only)

- `pomo start|pause|resume|toggle|reset|skip|status` from terminal
- Hypr bindings example in `docs/plan.md`
- State in JSON file, no bar widget yet

## Out of scope for v0.1

- Bar widget, analytics UI, calendar integration

See `docs/plan.md` for full steps.
