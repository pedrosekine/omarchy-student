# Student OS — design notes

**Status:** reflection phase, started 2026-09-08. Not an implementation plan.
Each decision is tagged **decided**, **leaning**, or **open**. Nothing here is
built until it moves to a numbered step in `plan.md`.

The pomodoro became a deadline tracker. This document is about what it becomes
next: a small "student OS" inside Omarchy that an agent can read, reason over,
and ask questions about — to help a student not miss deadlines, organise, and
study well. Not to do the work for them.

## Principles

1. **Agentic-first.** Everything the agent needs is plain files plus
   `pomo <cmd> --json`. No API, no auth, no daemon. Already true today.
2. **The log is the truth.** The agent computes; it is not told. Per-deadline
   effort, per-subject hours, spacing, neglect — all derived from `pomo.log`.
3. **Effort and commitments, not artifacts.** The agent sees timestamps,
   titles, intentions, estimates, one-line answers. It never sees the essay.
   "Not cheat" is a property of the data model, not a policy.
4. **Speak only with evidence.** The agent talks when it has something specific
   about *this* student. Never a broadcast reminder.
5. **Design to become less needed.** Track self-initiated vs. prompted sessions.
   A rising ratio is success; a falling one means we built a crutch.

## Decisions

### D1 · Unit of attachment — **decided**: the deadline is the atom
Small assignments exist without a larger deliverable or module behind them, so
anything above the deadline is optional grouping. Subjects are a tag on the
deadline, not a table. Focus sessions attach to a deadline id, or to a bare
subject when there is no deliverable ("stats reading").

### D2 · The lever — **open**
A deadline gets an optional `link` (file path, URL, markdown deep link) that
opens on click. Cheap. The real question is a boundary: does the *agent* follow
the link? Leaning **no by default** — the link is for the human. If the student
wants the agent to see a plan, that is an explicit, separate field. This keeps
principle 3 intact. Also open: whether the link becomes the door into a wider
notes/OS layer, or stays a convenience.

### D3 · Friction budget — **leaning**: before, not after
Typing after a 25-minute session is unwelcome. The forethought moment is where
the evidence says the leverage is anyway (see research §1). So:
- **Before:** pick target + one line "what I'll do this session". Optional
  obstacle clause ("if I reach for my phone, then …").
- **After:** no typing. At most one keystroke answering the intention:
  did it happen — yes / partly / no. This is nearly free and feeds D4.
- The next session's intention implicitly reports on the last one.

### D4 · Progress — **decided**: no percentages
Students systematically overestimate their own progress and the least-prepared
are the most miscalibrated (research §4). A percentage is a self-judgment we
already know is wrong. Replacements, **leaning**:
- **Intention → outcome pairs** (from D3). Progress is the trajectory of
  "I'll do X" / "did X happen", not a number.
- **Student-defined milestones** at add-time: "what does done look like?"
  Two to four named checkpoints, no percentages between them.
- **Next concrete action.** If the student can't name it, that is the signal.
- **Calibration as an outcome.** Showing a student their own intention/outcome
  record is itself a learning intervention, not just tracking.

### D5 · Cadence — **leaning**, research-informed
One rule: the agent speaks only when it has something specific and
evidence-based about this student (research §2, §3). Three moments:
1. **Session start** — the planning prompt. The heavy lifter.
2. **Evening** — "what's tomorrow's first session?" The exact design that
   worked in a micro-randomised trial, with the caveat that it decays unless
   the prompt carries new, adaptive information each time.
3. **Weekly review** — the agent-run analogue of an academic coaching session.
   Short, optional. Human coaching lands at 4–6 sessions a semester; an agent
   can afford weekly because the cost is zero, but it must stay opt-in.

Never: unsolicited "time to study" pings. Watch the dependence trap
(principle 5).

### D6 · Agent interface — **leaning**: a skill, not code
`pomo report --json` dumps everything above in one call. The agent side is a
skill file — *how to run a study review, what to notice, what to ask* — not
software. Notice-absence heuristics live there: a subject with nothing due,
a cadence break, a deadline inside five days with zero sessions, estimates
running consistently low, sessions massed the night before.

### D7 · Session target — **leaning**
One optional field on `pomo start`: `--for <deadline id>` or `--on <subject>`.
Lands in `state.json` and on the log line. This is the one field that makes
everything else computable — including real spacing detection, which only
counts when the *same material* is revisited (research §5).

## What the research says (surveyed 2026-09-08)

### §1 Planning beats reminding
- Implementation intentions: d ≈ .27–.66 across 642 tests; stronger when
  if-then, rehearsed, and the person is motivated. Sheeran et al. 2024,
  doi:10.1080/10463283.2024.2334563
- Evening planning prompts raised next-day study; effect depended on plan
  quality (specific, salient cue). Schaaf et al. 2025,
  doi:10.1016/j.cedpsych.2025.102422
- A planning prompt alone: homework earlier and more spread out. Felker et al.
  2023, doi:10.1103/physrevphyseducres.19.010123
- Planning for *obstacles* produced follow-through where planning for goals
  didn't. Walck-Shannon et al. 2024, doi:10.1187/cbe.23-05-0092
- Preflective prompts work best for novices. Lehmann et al. 2014,
  doi:10.1016/j.chb.2013.07.051
- In SRL training, planning/goal-setting is the strongest component (g=.55).
  Theobald 2021, doi:10.1016/j.cedpsych.2021.101976

### §2 Reminders alone: null, and sometimes harmful
- 25,000 students, five years of nudges: no effect on outcomes; students study
  5–8 h/week less than planned; coaching led some to lower expectations rather
  than work harder. Oreopoulos & Petronijevic 2019, doi:10.3386/w26059
- Weekly reminders + planning module, 9,000 students: precise nulls.
  Oreopoulos et al. 2018, doi:10.3386/w25036
- Goal-setting + reminders, 1,400 students: nothing. Dobronyi et al. 2017,
  doi:10.1080/19345747.2018.1517849
- Reminder dependence: less study on non-reminded days than a never-reminded
  control. Nobbe et al. 2024, doi:10.1038/s41539-024-00253-7
- Reminders crowd out non-reminded actions; the negative spillover persists.
  Koch et al. 2024, doi:10.1073/pnas.2322549121
- Notification burden is about intrusion, not count. Khanday et al. 2025,
  doi:10.9734/ajess/2025/v51i122743

### §3 Prompts decay unless adaptive; targeted outreach works
- Prompt effects build over consecutive days and fade when stopped.
  Breitwieser et al. 2020, doi:10.31234/osf.io/bz49m
- Long-term journal prompting: no effect once novelty wore off. Gentner et al.
  2024, doi:10.1007/s11251-024-09671-x
- Metacognitive prompts g=.50 (SRL) / .40 (outcomes), moderated by feedback,
  specificity, adaptivity. Guo 2022, doi:10.1111/jcal.12650
- Proactive outreach works when: trusted source, data-targeted to the person,
  discrete acute tasks. Page et al. 2024, doi:10.1080/19345747.2025.2481219
- Personalised reminders: +0.2 SD, by shifting study earlier. O'Connell &
  Lang 2018, doi:10.1080/15391523.2017.1408438

### §4 Coaching works; calibration is the lever
- InsideTrack RCT: regular contact linking daily activity to long-term goals;
  persistence held a year after. Bettinger & Baker 2014,
  doi:10.3102/0162373713500523
- Effective coaching: ≥12 h over 4+ weeks. Campbell et al. 2024,
  doi:10.1080/14703297.2024.2417173
- Early and often: first contact before week 6, 4–6 sessions/semester.
  Dahan et al. 2023, doi:10.1080/19496591.2023.2247374
- Coaching raises metacognition. Howlett et al. 2021,
  doi:10.1007/s10755-020-09533-7
- Students overestimate (g=.21, 160 studies); feedback and experience shrink
  it. León et al. 2023, doi:10.1007/s10648-023-09819-0
- Overconfidence produces underachievement. Dunlosky & Rawson 2012,
  doi:10.1016/j.learninstruc.2011.08.003
- Weekly goal → confidence → self-evaluation cycle reduced overconfidence.
  Hadwin & Webster 2013, doi:10.1016/j.learninstruc.2012.10.001

### §5 Spacing needs a target to be visible
- Classroom spacing effect d=.54. Mawson et al. 2025, doi:10.3390/bs15060771
- Self-reported spacing only predicts grades when it means revisiting the same
  concepts. Malain et al. 2026, doi:10.1037/xap0000562
- 72% believed massing had worked better right after it hadn't. Kornell 2009,
  doi:10.1002/acp.1537
- Deadlines don't prevent cramming. Theobald et al. 2021,
  doi:10.1016/j.lindif.2021.101994
- Spaced practice also reduces overconfidence. Emeny et al. 2021,
  doi:10.1002/acp.3814

### What companies do
- Duolingo: notification timing and copy run as a bandit over ~200M sends;
  optimises engagement, which is the reminder-dependence pattern above.
- Focusmate: declare intention at start, check in at end, 50 min, social
  presence. Evidence for body doubling itself is mixed.
- Khanmigo: "guide, not teacher" framing to lower resistance.
- GTD weekly review: practitioner evidence only; components align with
  cognitive-offloading research.

## Candidate primitives (not committed)

```
pomo start focus 25 --for 3 "outline section 2"     # target + intention
pomo start focus --on stats "ch.7 problems"
pomo outcome yes|partly|no                           # one key, after bell
pomo deadline add "Essay" friday --subject stats --link ~/notes/essay.md
pomo deadline milestones 3 "outline" "draft" "revised"
pomo report --json                                   # everything, one call
```

## Open questions (grill material)

1. Does the post-session keystroke survive contact, or is even that too much?
2. Is the evening prompt a notification, a bar glyph, or nothing until asked?
3. Who owns the weekly review — the student summons it, or it appears Sunday?
4. Does the agent ever read a linked note? Under what explicit consent?
5. What is the minimum viable "notice absence" list for the skill file?
6. How do we measure whether the system is becoming less needed?
