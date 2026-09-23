---
name: wof-lane-hygiene
description: Safe working procedure for any agent changing Wizards Only Fools alongside other agents - own worktree, staging by explicit path, running the right test suites, and telling a pre-existing failure from one you caused. Use before editing code in this repo, before committing, and whenever a test fails.
metadata:
  project: AllusionsTooGrandeur
---

# Lane hygiene

Several agents (Claude and GPT lanes) work this repo at once. Every
agent-on-agent failure so far was two writers in one file or one blanket add.

## Start

```bash
git -C P:/GameDev/AllusionsTooGrandeur worktree add -b <agent>/<topic> P:/GameDev/worktrees/<topic> codex/primary
"$G" --headless --path P:/GameDev/worktrees/<topic>/game --import   # once, ~1 min
git log --oneline -15   # did someone just do this?
```

Never work directly in `P:\GameDev\AllusionsTooGrandeur` — it broke the build
three times.

## Edit

- Prefer additive components (a new `class_name` node the owner instantiates)
  over growing a shared file. `bone_yard_hunt.gd` is touched by four
  branches: keep edits there to a declaration, a `new()` and one call.
- Each change states its **player action, persistent record and visible
  proof** (`ARCHITECTURE/SYSTEM_MAP.md`). No lane invents lore to unblock
  itself; open questions go to Greg.
- GDScript traps: `draw_string` takes a baseline but `CellOutzType` a
  top-left; `event.pressed` off a base `InputEvent` needs an explicit
  `var x: bool =` or the whole file silently fails to compile.
- Mixed-case text in `CellOutzType` reads as missing glyphs: it is caps only.
- Labels, headers and numerals go in `CellOutzType`
  (`draw_string_compat` / `string_size_compat` take `draw_string`'s own
  arguments). **Wrapped prose stays in a real font** — `world_index.gd`,
  `pin_board.gd` and `character_archive._draw_wrapped` state this rule;
  converting a paragraph breaks it.

## Test

```bash
tools/run_tests.sh --list <words>        # find suites by name
tools/run_tests.sh <suite> <suite> ...   # exit code is the authority
tools/run_tests.sh --core                # before merging
```

A new behaviour gets one small `tests/<name>_test.gd/.tscn` that prints
`<NAME>_RESULT failures=N` and quits non-zero on failure.

**Is a failure yours?** Stash only your edits and rerun the one suite:

```bash
git stash push -- <your files> && tools/run_tests.sh <suite>; git stash pop
```

Fails either way = pre-existing; say so in the commit, do not "fix" it in
passing. Known on `codex/primary` 2026-09-24: `hud_night_camera_test`
times out, `momentum_carry_test` fails "a real vault target is found".

## Commit

- **Never `git add -A`.** 120–140 `.import`/`.uid` files churn on every open.
  Stage by explicit path, including the `.uid` files of *your new* scripts.
- The message says what was seen rendered (see `wof-verify-by-looking`) and
  which suites ran, including any that were already red.
- Tick only your own lines in `CHECKLIST.md` — seven branches touch it.
