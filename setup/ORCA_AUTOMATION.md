# The lane automation

Orca's UI is not in this loop. Seven agents across seven accounts, dispatched
by two scheduled tasks, because the UI cannot do the one thing this project
actually needs: **notice that an account's quota came back and start working
again without anybody being awake.**

Everything lives in `C:\Users\Greg\lane-runner\`.

## Why it exists

On 15 September all four Codex accounts and all three Claude accounts hit
their walls within the same hour. Three Codex accounts do not reset until
**Sep 19**; the Claude accounts reset **Sep 19, 5am**. The single most
valuable commit of that night -- `188c83a`, the first P-section work in the
project's history -- was produced by a scheduled task firing six minutes
after one account refilled, while nobody was at the keyboard.

That is the whole thesis. Authoring has never been the bottleneck; **being
awake at the moment quota returns** is.

## `dispatch.sh` — every 20 minutes

Task `ATG-lane-dispatch`.

- Walks `lanes.tsv` in priority order (4 demo, 7 merge, 3 guns, 2 world,
  1 body, 5 getting-in, 6 handheld).
- For each lane not already running, claims the first account in
  `accounts.tsv` that is neither running nor parked, and starts an agent in
  that lane's worktree.
- Before starting, it clears the `.import`/`.uid` churn and fast-forwards the
  worktree onto trunk, so no agent begins on stale code.
- When an agent exits, it reads the exit log and **parks the account using
  the reset time in the CLI's own error message** -- "try again at Sep 19th,
  2026 10:31 PM", "resets Sep 19, 5am (Australia/Hobart)". "Out of credits"
  parks for six hours and is flagged `needs-credits`, because that one is not
  a clock, it is a payment.
- Does nothing at all when everything is busy or parked. That is the normal
  state and it costs nothing.

State is one file per account in `state/`: `.running`, `.blocked` (an epoch),
`.reason` (human-readable).

## `integrate.sh` — hourly

Task `ATG-integrate`.

Merges what merges. Nothing else.

- Skips a dirty trunk and skips any branch whose agent is still live.
- For each `lane-*` branch with commits: if `git merge-tree` reports no
  conflict, merge, rebuild the class cache, run the smoke suites.
- **A suite that prints nothing counts as a failure, not a pass.** That single
  rule is why this exists -- a GDScript parse error silences unrelated suites,
  and this project spent a week reading silence as green.
- Any failure aborts the merge and leaves the branch untouched.
- It never resolves a conflict and never should. Every conflict left in this
  repo is two agents having built one system in two places.


## `rescue.sh` — every 2 hours

Task `ATG-rescue`. Commits tracked work left sitting in worktrees nobody is
watching, staged by explicit path.

It exists because the cleanup pass on 15 September found three stale
worktrees holding uncommitted source -- `wire_net.gd` +63, `black_mirror.gd`
+90, `gothic_field_hud.gd` +182 -- every one of them on a branch that was
already fully merged, and therefore one `git worktree remove` from gone. One
of those worktrees had 293 changed files by `git status` and four by `git
diff`; the other 289 were line-ending noise. A tidy-up that trusted the first
number would have deleted the work behind the second.

It will not touch a worktree whose agent is live, will not touch trunk, and
will not commit untracked files.

## `report.sh` — every 30 minutes

Task `ATG-report`. Writes `STATUS.md`: what landed, which lanes are running,
which accounts are walled and until when, which branches still carry work and
whether each merges clean, the current test signal, and the decisions still
waiting on Greg. It is the one file to read after being away.

## `sweep.sh` — on demand

Runs all 252 assertion suites (the 72 `*_capture` scenes are screenshot
scenes, not assertions) and classifies each as ok, FAILING, or **SILENT**.
Silent is the one that matters: a suite printing no PASS, no FAIL and no
error is not passing, it is a parse error somewhere in its dependency chain.
Results land in `sweep.log`, and `report.sh` summarises them.

## Stopping it

    powershell -Command "Get-ScheduledTask -TaskName 'ATG-*' | Unregister-ScheduledTask -Confirm:\$false"

To park an account by hand, write a unix timestamp into
`state/<account-id>.blocked`. To free one, delete that file.

## Logs

| File | What |
|---|---|
| `dispatch.log` | every tick, every start, every parking and why |
| `integrate.log` | every merge attempt and its verdict |
| `lane-N-*.log` | one agent's full session output |

## The accounts

Four Codex (`sircuteskingdom` Team and Plus, `allusions` Team and Plus) and
three Claude (`bartenderidiot`, `sircuteskingdom`, `allusionstoograndeur`).
Codex accounts are per-`CODEX_HOME`; Claude accounts are per-
`CLAUDE_CONFIG_DIR`. Both point at the homes Orca already manages, so signing
in through Orca's Accounts pane is still how an account gets here -- the
dispatcher only borrows what Orca stores.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
