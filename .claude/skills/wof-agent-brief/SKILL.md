---
name: wof-agent-brief
description: Write a prompt or task brief that gets a generative coding agent (Claude, Codex/GPT, OpenCode, a subagent) to do one bounded piece of Wizards Only Fools well. Use when dispatching work to another agent or lane, splitting a feature into parallel tasks, or turning Greg's idea into an implementable task.
metadata:
  project: AllusionsTooGrandeur
---

# Writing an agent brief

A coding agent does what the brief makes checkable and invents the rest. In
this repo the costly inventions were: rebuilding something that already
existed, polishing something nothing called, claiming a look nobody saw,
writing lore to unblock itself, and two agents in one file.

## The brief, in this order

```text
GOAL      One player-visible outcome, in Greg's words where he said it.
          "The biometric door opens for a living guard, a dragged body, a
          corpse, or just the hand."
EXISTS    What is already built and must be used, not rebuilt — with paths.
          (Run wof-wire-before-polish first; paste the relevant lines.)
          "BiometricBarrier and FacilityGuardLoadout exist and are tested;
          nothing places them."
OWNS      The files this agent may edit. Everything else is read-only.
          Shared files get at most a declaration + new() + one call.
PROOF     How done is shown: the player action, the persistent record it
          writes, and the visible proof (capture/gallery PNG, looked at).
TESTS     Which existing suites must stay green; the one new test to add.
OPEN      Decisions that belong to Greg. "If you hit one, stop and report;
          do not choose." Link DESIGN/dust-to-bones.html's question boxes.
OUT       Explicitly out of scope, so the agent does not wander.
```

## Rules that make briefs work here

- **One slice, one agent, one worktree.** A slice ends in something a player
  can do and a recording that shows it. Split by file ownership, not by
  topic: two beats that both want the vat run in sequence, never together.
- **Point at the source of truth, do not paraphrase it.** Name the section:
  `DESIGN/PLAYER_DIRECTION_INTERVIEW_2026-09-18.md §Opening`,
  `DESIGN/FINAL_V.md §5`. Paraphrase drifts; paths don't.
- **Quote Greg exactly** where his wording carries intent ("the blow is
  something the player performs, not something they request").
- **References are inspiration, never source.** When Greg supplies reference
  videos or games, the brief says what quality to take (e.g. omnidirectional
  third-person fighting, cable-whip trails) and that all art and code are
  original. Do not ask an agent to reproduce someone else's assets.
- **Ask for evidence, not adjectives.** "Commit message lists suites run and
  names the PNG you opened" beats "make sure it looks good".
- **Load the matching skills by name**: `wof-lane-hygiene`,
  `wof-verify-by-looking`, `wof-wire-before-polish`, plus any engine skill
  (`running-headless-godot`, `maximizing-game-feel`,
  `adversarially-validating-game-repairs`, `create-game-vfx`).
- **Ask the agent to report back** what it could not verify and any
  pre-existing failures it met, as a separate list.

## Before sending

Could the agent finish without asking you anything? If it would have to
guess a design decision, that decision goes in OPEN — or to Greg first.
