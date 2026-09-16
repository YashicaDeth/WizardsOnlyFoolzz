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

## Worktrees — 11, down from 19

**Cleaned up 16 September.** The nine `P:/GameDev/atg-*` leftovers from older
agent rounds were removed with `git worktree remove --force`. Every branch and
every commit survives — a worktree is a checkout, not the history. Recreate one
with `git worktree add <path> <branch>` if you need to work on it again.

They were also cluttering the Godot Project Manager, which is where the sprawl
actually hurt: thirteen entries all named "Wizards Only Fools", only one of them
the real build. Godot holds that list in memory and rewrites `projects.cfg` on
exit, so editing that file while the editor is open achieves nothing — use the
Project Manager's own **Remove** button, which drops the entry without touching
any files.

Two pieces of genuinely stranded work were rescued onto their own branches
first, because deleting the folders would have lost them for good:
- `game/systems/night_vision.gd` -> `85d180a` on `agent-a-help`
- `game/systems/black_mirror_camera.gd` + the HUD settings suite -> `253be51`
  on `codex/hud-release-20260914`. That branch's PREVIOUS commit was itself
  named "Rescue: the black mirror and the pause gate, uncommitted in a stale
  worktree" — these three files survived that sweep and were still untracked.

**Do not trust a dirty-file count on a worktree here.** `atg-hud-release`
reported 641 dirty files and `atg-sol-agent-1` reported four modified gun
scripts; staging them produced *nothing*. It was CRLF/LF line-ending churn and
regenerated `.import` files, not work. Before concluding a worktree holds
something, check whether the changes survive `git add` — and filter `.import`
and `.uid` out of any count you quote.

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

## Progress — measured 16 September

`CHECKLIST.md`: **762 closed of 1784 — 42.7%.** The per-section table below
accounts for all 1784 items exactly; nothing is unclassified.

Regenerate it with:

    sed -n 's/^- \[\([x ]\)\] *~*\*\*\([A-Z][A-Z]*\)[0-9].*/\2 \1/p' CHECKLIST.md \
      | awk '{if($2=="x")c[$1]++; else o[$1]++; s[$1]=1} END{for(k in s){t=c[k]+o[k]; printf "%-3s %4d %4d %5.1f%%\n", k, c[k], t, (c[k]*100.0/t)}}' \
      | sort -k4 -rn

| Section | Done | Total | % | | Section | Done | Total | % |
|---|---|---|---|---|---|---|---|---|
| A | 95 | 98 | 96.9% | | K | 18 | 48 | 37.5% |
| B | 78 | 83 | 94.0% | | J | 11 | 30 | 36.7% |
| AV | 32 | 38 | 84.2% | | N | 13 | 41 | 31.7% |
| AD | 25 | 30 | 83.3% | | AU | 16 | 53 | 30.2% |
| AN | 27 | 37 | 73.0% | | Q | 6 | 21 | 28.6% |
| E | 39 | 55 | 70.9% | | W | 6 | 22 | 27.3% |
| D | 33 | 48 | 68.8% | | R | 5 | 20 | 25.0% |
| C | 37 | 54 | 68.5% | | AE | 7 | 29 | 24.1% |
| O | 37 | 57 | 64.9% | | U | 4 | 20 | 20.0% |
| AF | 16 | 27 | 59.3% | | AL | 6 | 31 | 19.4% |
| F | 21 | 36 | 58.3% | | Y | 6 | 33 | 18.2% |
| G | 25 | 44 | 56.8% | | AB | 7 | 39 | 17.9% |
| AJ | 22 | 39 | 56.4% | | AT | 5 | 29 | 17.2% |
| AG | 25 | 47 | 53.2% | | AQ | 3 | 23 | 13.0% |
| **P** | **23** | **45** | **51.1%** | | T | 2 | 20 | 10.0% |
| I | 32 | 63 | 50.8% | | AH | 3 | 41 | 7.3% |
| AS | 18 | 36 | 50.0% | | Z, X, V | 1 | 20 ea | 5.0% |
| L | 27 | 56 | 48.2% | | AC | 1 | 23 | 4.3% |
| AI | 12 | 28 | 42.9% | | AR | 1 | 27 | 3.7% |
| M | 15 | 39 | 38.5% | | S, H, AW, AP, AO, AM, AK, AA | **0** | 234 total | **0.0%** |

### What the table says that the briefs do not

- **P is 51.1%, not 15%.** Every doc in this repo quoted "7 of 45" — that was
  stale before it was written down. P1.1, P1.4, P3, P4.3, P4.5, P5.2, P5.3 and
  P5.4 had all landed. The demo lane is mid-pack, not nearly-empty.
- **Eight sections are at literal zero** — S, H, AW, AP, AO, AM, AK, AA, and
  together they are **234 items**, 23% of everything still open. No lane in
  `OWNERSHIP.md` owns any of them. That is the real gap in the lane structure:
  not that lanes collide, but that a quarter of the remaining work has no lane
  at all.
- The body (`B` 94%, `A` 96.9%, `AD` 83.3%, `AN` 73%) is close to finished. The
  world and the frame budget (`X` 5%, `V` 5%, `AB` 17.9%) are barely started.

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
