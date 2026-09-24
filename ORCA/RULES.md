# House rules

Six rules. Every one of them is here because it already cost somebody a
session. They override any target, any brief, and anything `CHECKLIST.md` or
`setup/ORCA_LANES.md` says.

---

## 1. Never `git add -A`. Stage by explicit path.

Roughly 140 `.import`/`.uid` files churn constantly, and two blanket adds in one
day swept other agents' uncommitted work into unrelated commits.

This matters most when you are in the **shared main worktree**, where a blanket
add reaches other people's files.

## 2. A suite that prints nothing has not passed.

A GDScript file that fails to parse makes **unrelated** suites print nothing at
all, which reads exactly like a pass.

`substance_objects.gd` compiled for the first time on 15 September (`4ec77a6`).
Before that it had never parsed. **Every baseline taken in this repo before that
commit was measured against silence.**

If a suite prints nothing, do not assume it passed. Run `--check-only` over the
scripts it touches.

## 3. `--check-only` does not register autoloads.

So `Identifier not found: WorldHistory` from `--check-only` is an **artifact,
not a break**. Confirmed again on 16 September: after the b-ladder merge,
`country_town_menu.gd` reported exactly that and the file was fine.

It also does not see `class_name` registrations until the class cache is built —
a merge that adds a new `class_name` file will report "Identifier not declared"
until you import. That happened the same day with `SupportMail`.

## 4. Never measure in the same breath as `--import`.

A suite run immediately after the class cache is rebuilt reports failures that
do not exist. `weapon_jam_test` said 5 of 23 failed that way, then passed 23 of
23 seven times in a row on the same tree.

This is the same cold-cache trap as the phantom "function not found", wearing
the opposite face — there it invents missing functions, here it invents failing
checks. **Let the import finish. Then measure, as a separate run.**

## 5. A merge is not finished when git says it is finished.

It is finished when the project compiles and the suites print something.

`agent-b` merged `silhouette.gd` with no conflict at all and the result did not
compile: its five-parameter `dress_vehicle` beat HEAD's six-parameter one, and
the caller passes six. **Git cannot see a signature change as a conflict** —
there is no marker to resolve, the merge reports success, and the build is
broken.

Every conflict resolution must be decided from the code and then **verified by
running the suites, not by reading the diff**.

## 6. Verify against the code, never against the checklist's prose.

This is the newest rule and it fired three times on 16 September alone:

- `setup/ORCA_LANES.md` called AF10.1, AF10.3, AF10.4, AF10.5 and AF10.12 "all
  buildable now" — every one of them was already closed.
- `CHECKLIST.md`'s own note on `AD10.7` said there was "no crouch or slide verb"
  — crouch had existed since `8b2bdb5`. Only slide was actually missing.
- `AGENT_BRIEF_CURRENT.md` listed `gothic_field_hud.gd` as needing font
  conversion. It was already fully converted.

The checklist's **tick boxes** are reliable. Its **notes** go stale, in both
directions — claiming work is open when it shipped, and claiming a thing does
not exist when it does. Before you build, grep for the thing.

## 7. Commit early, by explicit path.

The three commits before `f376d7c` are named, verbatim, *"Rescue: N tracked
files left uncommitted."* Work has repeatedly been left untracked in the main
worktree and swept up later by somebody else's rescue pass.

If your work is coherent, commit it. If it is mid-build, commit it as an
explicit WIP and say so. Do not leave it untracked.
