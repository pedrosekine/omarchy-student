# Diary capture — end-to-end plan

**Status:** planning, 2026-09-16. Supersedes the todo-list draft that used to
live in this file. Nothing here is built.

## What changed

The project is no longer "pomodoro + deadlines, plus a todo list." It is a
**daily note that an agent reads and answers** — a writing surface that is also
a trigger and a dashboard. Sessions and deadlines stay, but they become
features *inside* that surface: the timer is the frame a focus session runs in,
and deadlines are one kind of thing a note can produce.

The shipped timer and deadline work is not wasted — it becomes the focus-mode
layer and the structured store the agent writes through.

## The picture

```
one device
  write freely in today's note
    → local watcher (debounced)
      → deterministic context builder   [strips private, logs payload]
        → opencode run, cloud model     [short-lived, no daemon]
          → reply appended as a faded block
            → agent-owned knowledge files persist
```

Nothing is resident between triggers. The agent wakes, does one pass, writes,
exits.

## Where it lives

- The daily note lives in the student's existing Obsidian daily-notes folder.
  The vault path is machine-local config and is deliberately **not** recorded in
  this public repo.
- One file per day, the vault's existing date format.
- The vault already separates `human/` from `agents/` and has a secrets area;
  that structure is the starting point for consent (below), not something to
  reinvent.

## Principles (revised)

1. **Agentic-first.** Plain files plus one command. Unchanged.
2. **The log is the truth.** Strengthened: the diary *is* the log, and it is
   written by the student, not the system.
3. **Consent is per block; the context is built locally.** This replaces
   "effort and commitments, not artifacts." The agent may see the essay — but
   only what the student has not marked private, and the removal happens in
   local code before inference, never by the model's judgement.
4. **Speak only with evidence.** Unchanged. The agent replies when it has
   something specific about this student, not on a schedule.
5. **Design to become less needed.** Unchanged, and now with a trap to name: a
   beautiful surface is an engagement machine. Success is measured by outcomes
   (commitments met, self-initiated sessions), never by time in the app.
6. **One device is enough.** New. No always-on relay, home server, or second
   computer in the loop. Anything that only works with a second device is out.
7. **Rich on the surface, clean underneath.** New. The surface may be as
   polished as we like, but it may only write a defined markdown dialect
   (GFM + callouts + highlights) so git, Obsidian, and the agent all still read
   the same file.
8. **The agent reads everything and produces nothing.** The boundary that
   survives from the old principle 3: it may see drafts, notes, and the essay,
   but its output is questions, plans, and observations — never anything
   submittable.

## Capture and consent

- A block inside a private callout, or tagged private, is stripped from the
  context.
- Hard exclusions: the vault's secrets area, always.
- Local-only payload log: every context sent to the model is written verbatim
  to a local file first, so "the private block was not sent" is a testable
  claim rather than a promise.
- **Open:** does the whole `human/` area default to private, with per-block
  opt-in sharing? (Leaning yes, given this vault's history.)

## The loop (MVP)

1. Today's note is created on first write if missing.
2. A watcher debounces on idle, Enter, or a checkbox change.
3. The context builder (local code) assembles: today's note, minus private
   blocks, plus the agent's knowledge files. It writes the payload log.
4. `opencode run` executes one pass with a cloud model and an allowlisted tool
   set.
5. The reply is appended to the note as an agent callout — faded in Obsidian
   today; natively styled once we own the surface.
6. The agent updates only its own knowledge files. **It never edits the
   student's prose.**

### Acceptance tests

- A written line produces a reply in under a minute.
- A private block is provably absent from the payload log.
- Closing the lid loses no trigger; the run happens on resume.
- Each run reports its token cost.
- Nothing is resident between runs.

## Modes

One file, two presentations, prepared for from the start:
- **Companion** — summoned, non-focus-stealing; replies wait for you.
- **Focus** — full-screen, timer running, the agent quietly facilitates.

The MVP is headless (any editor works), so both modes cost nothing yet; it only
constrains the file format.

## Runtime decisions

- **Runs on the laptop.** Decided. A second always-awake machine would mean two
  writers over file sync — conflict copies in a vault that has already survived
  one cleanup. One writer, one filesystem. It also honours principle 6.
- Consequence: while the lid is shut, triggers and phone captures wait, and are
  processed at next open. "Seamless" means "already answered when you return."
- **Cloud model, via opencode.** Chosen for openness and because it does
  non-interactive one-shots, MCP tools, subagents, and skills. The model stays
  one config line so the choice is reversible. Alternatives considered: Claude
  Code (strongest, closed), goose and Codex CLI (open).
- **External reading** (university pages, email) is later and read-only outside
  the vault. Portal logins and 2FA are the fragile part; they must not gate the
  MVP.

## Phases

- [ ] Phase 0 — decisions: `human/` default, autonomy boundary, model/budget
- [ ] Phase 1 — headless loop: watcher, context builder, payload log, opencode
      pass, reply appended
- [ ] Phase 2 — knowledge: agent-owned files that accumulate across days
- [ ] Phase 3 — private-block enforcement as a test in CI, not a convention
- [ ] Phase 4 — surface: a Quickshell diary panel (companion + full-screen),
      theme-bound, no Chromium, riding in the already-running shell
- [ ] Phase 5 — focus mode: the timer as the session frame, agent facilitation
- [ ] Phase 6 — phone capture: store-and-forward into the same daily note
- [ ] Phase 7 — external reading, gated and read-only

## Open questions

1. Does `human/` default to private for the agent (opt-in sharing per block)?
2. May the agent write outside its own knowledge files — e.g. update the
   structured deadline store directly, or only propose?
3. Once it can read email and pages, what may it do autonomously versus ask
   first?
4. How rich does the surface go? The floor is native QML text with live
   markdown; the ceiling is hand-built block editing. No Chromium either way.
5. Which model, and is there a per-run token cap so a runaway context can never
   surprise the student?
