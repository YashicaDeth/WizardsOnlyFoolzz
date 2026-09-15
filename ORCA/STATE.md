# State — measured 16 September 2026

Every number here was measured on the day, not carried forward. **Re-measure
before you quote any of it.** The commands are given so you can.

Trunk: `codex/game-planning` at `642e1b5`.

---

## Quota — read this first

**The account was at 100% weekly usage on 16 September. It resets Sep 19, 5am
(Australia/Hobart).**

This is not a footnote; it is the governing constraint. On 16 September four
agents were dispatched to four lanes and **none of them did any work** — they
were out of quota, and the sessions closed within a minute or two of starting.
Before dispatching, check that there is quota to dispatch into. An agent with no
quota is not a slow agent, it is a dead one, and it will look idle rather than
blocked.

Codex accounts have been hitting the same wall: three exhausted on 15 September,
the fourth refilling Sep 19.

## Unmerged work

    git rev-list --count HEAD..<branch>

| Branch | Unmerged | Status |
|---|---|---|
| `codex/sol-agent-1` | 8 | Blocked — but **answerable now**, see `DECISIONS.md` #3. |
| `integration-check-agent-a` | 5 | Folds into the same save-slot decision. |
| `codex/controls-ui-repair` | 4 | **Dead as a merge source** by Greg's call. Redo on trunk. |
| `agent-a-help` | 1 | Not yet looked at. |
| `claude/b-ladder` | **0** | Merged 16 Sep at `642e1b5`. Was 15. |
| `agent-c` | **0** | Merged. The Sephiroth question is moot. |
| `agent-b` | 0 | Merged. |

**18 commits across 4 branches.** The trajectory: 99 (miscounted) → 77 across 10
→ 43 across 5 → 32 across 4 → 18 across 4.

Check containment before quoting a count — `origin/agent-b`'s 20 commits were an
ancestor of `agent-b`'s 26 and were double-counted for a whole day:

    git merge-base --is-ancestor origin/agent-b agent-b

## Worktrees — 19 of them

**This is sprawl and it is worth a cleanup pass.** Nine `P:/GameDev/atg-*`
worktrees are left over from older agent rounds and no current lane uses them.

The ones that matter:

| Worktree | Branch | State on 16 Sep |
|---|---|---|
| `P:/GameDev/AllusionsTooGrandeur` | `codex/game-planning` | **Primary.** Shared — only ever put one agent here. |
| `…/orca/workspaces/…/lane-1-body` | `lane-1-body` | Clean, at trunk. **Free.** |
| `…/lane-2-world` | `lane-2-world` | Clean, at trunk. **Free.** |
| `…/lane-4-demo` | `lane-4-demo` | Clean, at trunk. **Free.** |
| `…/lane-5-getting-in` | `lane-5-getting-in` | Clean, at trunk. **Free.** |
| `…/lane-6-handheld` | `lane-6-handheld` | Clean, at trunk. **Free.** |
| `…/lane-7-merge` | `lane-7-merge` | The merge lane. At `dcec158`. |
| `…/lane-8-guns` | `lane-8-guns` | Created 16 Sep, clean. **Free.** |
| `…/lane-3-guns` | `lane-3-guns` | **Stale** — 43 behind, ~249 dirty `.import`/`.uid` files. Superseded by `lane-8-guns`. Clean up or delete. |

Fast-forward a free lane to trunk before dispatching into it:

    git -C <worktree> merge --ff-only codex/game-planning

## Uncommitted work sitting in the main worktree

Still untracked as of `642e1b5`, and at risk:

- `game/underground_colosseum.tscn`
- `game/systems/ringmaster_card.gd` (+ `.uid`)
- `game/tests/vehicle_condition_test.gd` (+ `.uid`), `.tscn`
- `MORNING_BRIEF_2026-09-15.md`

The `vehicle_condition_test` files are **V1.1's test suite, orphaned**. V1.1's
implementation already shipped and is committed — `arcade_vehicle.gd` has
`condition`, `_condition_scale()` at `:207` and impact-driven degradation at
`:432` — but its test never made it into git. See `QUEUE.md`.

## Progress

`CHECKLIST.md`: **762 closed, 1022 open** (42.7%).

    grep -c '^- \[x\]' CHECKLIST.md ; grep -c '^- \[ \]' CHECKLIST.md

## Operational gotchas

**Cross-session messages are held by default.** A message from one Claude
session to another is *not delivered* if the sending session's permission-mode
class differs from the receiving one — it shows as "Held peer message" and waits
for a human to click through. This silently ate four dispatches on 16 September.

Fixed by setting `"crossSessionInbound": "accept"` in
`C:/Users/Greg/.claude/settings.json` (done 16 Sep).

**Session permission mode is per-session.** `settings.json` already sets
`"defaultMode": "bypassPermissions"`, but the desktop app overrides it per
session. Shift+Tab cycles the mode in each window; it does not inherit.
