# The authored facility escape, as a route

AX is 0 of 30 and it is the demo. Everything in section P was the scaffolding
around it — PLAY and DEMO as two doors, an isolated save slot, the ACCOUNT
CLOSED wall at the end. P is 75% done, which is why the numbers have looked
healthy while the game still opens into nothing.

This file is the order the beats have to be built in, and **who owns which
files while they are being built**. The ownership half matters more. Every
agent-on-agent failure in this repo has been two writers in one file, and the
vat is about to have three agents interested in it at once.

## The route

| # | Beat | Items | Owns |
|---|---|---|---|
| 1 | The examination | AX1.1, AX1.3, AX1.4, AX1.5 | `vat_intake.gd`, decanting prologue, D-section scenes |
| 2 | The doctor | AX1.2, AX2.1, AX2.5, AX2.6 | dialogue and the doctor actor — **a writing pass, not a systems one** |
| 3 | The breakout | AX2.2, AX2.3, AX2.4 | restraints, mouth tube, the vat as a physical object |
| 4 | The first objects | AX3.1, AX3.2, AX3.6 | inspection and carry, garments |
| 5 | The barrier and the gun | AX3.3, AX3.4 | doors, guards, `hunter_arsenal.gd`, `penetration.gd` |
| 6 | The Black Mirror | AX3.5 | `black_mirror.gd`, restricted storage |
| 7 | The exits | AX4.1–AX4.6 | route branching, the ledger record |
| 8 | The contracts | AX5.1–AX5.6 | performance, population budget, the recording |

Beats 1 and 3 both want the vat. **They cannot run at the same time.** Beat 1
wraps the vat in an examination; beat 3 breaks the vat. Build 1, merge it,
then start 3 against what 1 left.

Beats 5 and 6 touch nothing beats 1–4 touch and can run in parallel with any
of them. That is where a second agent goes.

## What already exists and must not be rebuilt

The escape is mostly assembly, not invention:

- **Character creation** — D is 67%. The vat works. Beat 1 wraps it; it does
  not rebuild it.
- **Ballistics, penetration, arsenal** — AF is 63%. Beat 5 spends them.
- **Anatomy, wounds, encounter actors** — AN is high. The guard at the
  biometric door is an actor that already exists.
- **The Black Mirror** — `black_mirror.gd` exists and was rescued from an
  unwatched worktree on 15 September. Beat 6 steals it, it does not write it.

Before building anything in a beat, `grep` for what it calls. The most common
bug class in this repo is not a missing system, it is a finished system nobody
wired up.

## The one that is not a systems job

AX1.2 — *"the unidentified visiting doctor is personally cruel, strangely
sympathetic"* — and AX2.1, where the doctor's conclusion is that they now know
how to break or kill the player. That is writing. It should not be handed to an
agent alongside a mechanical slice, because the mechanical half will eat it.
It is its own commit and probably Greg's to steer.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
