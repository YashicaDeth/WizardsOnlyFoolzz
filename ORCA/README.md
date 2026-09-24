# ORCA — how this project runs many agents without them eating each other

Start here. This folder is the operating manual for running parallel agents on
Allusions Too Grandeur. It replaces nothing you already know about the game; it
is only about **how work is split, dispatched, verified and merged**.

Built 16 September 2026, from the tree as it actually was that day — every
number in `STATE.md` was measured, not inherited. That matters, because the
single most expensive recurring failure in this project is not agents fighting
over files. It is **agents trusting a document that had gone stale.**

## The five files

| File | What it is for | Read it when |
|---|---|---|
| `OWNERSHIP.md` | Which lane owns which files. | **Before dispatching anything.** This is the file that prevents collisions. |
| `STATE.md` | What is true right now: branches, worktrees, counts, quota. | Start of any session. Re-measure before you quote it. |
| `DECISIONS.md` | Calls Greg has made, and the ones still waiting on him. | Before you "resolve" anything that looks like a design disagreement. |
| `QUEUE.md` | Bounded, verified, ready-to-dispatch tasks. | When an agent is free. |
| `RULES.md` | The house rules that keep drawing blood. | Before your first commit or test run. |

## The one-paragraph version

Each agent gets **its own git worktree** and **its own file family**. The
worktree stops two agents writing one file in the same instant. The ownership
table stops two agents building one *system* in two places, which is the failure
git cannot see and cannot fix. An agent commits by explicit path, never
`git add -A`, verifies by running suites rather than by reading its own diff,
and ticks `CHECKLIST.md` in a separate final commit so seven agents ticking
seven lines produce seven trivial conflicts instead of one ugly one.

## The order of operations for a dispatch

1. Read `STATE.md`. Re-measure anything you are about to quote.
2. Pick a task from `QUEUE.md`, or write one — bounded, with success criteria.
3. **Verify the task is actually open against the code**, not against
   `CHECKLIST.md`'s prose. See `RULES.md` rule 6; this has cost real sessions.
4. Pick a free worktree from `STATE.md` and fast-forward it to trunk.
5. Dispatch using the template at the bottom of `QUEUE.md`. Name the files the
   agent owns AND the files it must not touch.
6. When it reports, merge through lane-7, verify, and update `STATE.md`.

## What this folder deliberately does not do

It does not duplicate `CHECKLIST.md`, `DESIGN.md` or the `DESIGN/` notes. The
checklist is the measurement of the game; this folder is the measurement of the
*process*. When they disagree about whether something is done, **the code
wins**, then the checklist, then this folder.

`setup/ORCA_LANES.md` is the ancestor of this folder and is now partly stale —
its guns brief lists five closed items as "buildable now". Prefer
`OWNERSHIP.md` and `QUEUE.md` over it, and treat anything it says about *state*
as a claim to be re-measured.
