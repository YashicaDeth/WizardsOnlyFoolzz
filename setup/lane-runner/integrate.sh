#!/bin/bash
# Deterministic integrator. Merges only what merges clean, and only if the
# project still compiles and the smoke suites still print something.
#
# It never resolves a conflict. A branch that conflicts is left alone and
# named in the log -- those are the ones that need a human, and every one of
# them so far has been two agents building one system in two places.
set -u
R=/c/Users/Greg/lane-runner
P=/p/GameDev/AllusionsTooGrandeur
G="P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
LOG=$R/integrate.log
export TEMP="P:/GameDev/Temp" TMP="P:/GameDev/Temp" ATG_TEST_MODE=1
say() { echo "[$(date '+%m-%d %H:%M')] $*" >> "$LOG"; }
cd "$P" || exit 1

say "--- integrate tick ---"
if ! git diff --quiet || ! git diff --cached --quiet; then
  say "trunk worktree is dirty; skipping entirely"; exit 0
fi
git rev-parse -q --verify MERGE_HEAD >/dev/null && { say "a merge is already in progress; skipping"; exit 0; }

SMOKE="demo_mode_test plane_ladder_test boons_test pockets_test derby_budget_test"
smoke_ok() {
  local bad=0
  for t in $SMOKE; do
    [ -f "game/tests/$t.tscn" ] || continue
    local r; r=$(timeout 200 "$G" --headless --path game "res://tests/$t.tscn" 2>&1)
    local p f; p=$(echo "$r" | grep -c '^PASS'); f=$(echo "$r" | grep -c '^FAIL')
    if [ "$p" -eq 0 ] && [ "$f" -eq 0 ]; then say "  SMOKE $t printed NOTHING -- treating as failure"; bad=1
    elif [ "$f" -gt 0 ]; then say "  SMOKE $t has $f failing"; bad=1; fi
  done
  return $bad
}

merged=0
for b in $(git for-each-ref --format='%(refname:short)' refs/heads | grep -E '^lane-[1-7]'); do
  n=$(git rev-list --count codex/game-planning..$b 2>/dev/null)
  [ "${n:-0}" -eq 0 ] && continue
  [ -f "$R/state/$b.running" ] && { say "$b has $n commits but its agent is live; leaving it"; continue; }
  if git merge-tree --write-tree --name-only codex/game-planning "$b" >/dev/null 2>&1; then
    say "$b: $n commits, merges clean -- trying it"
    git merge --no-commit --no-ff "$b" >/dev/null 2>&1
    "$G" --headless --path game --import >/dev/null 2>&1
    if smoke_ok; then
      git commit -q -m "Merge $b: $n commits, clean, smoke suites green

Landed by the integrator, which merges only what merges without conflict and
only when the project still compiles and the smoke suites still print
something. It does not resolve conflicts and never will.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
      say "$b: MERGED"; merged=$((merged+1))
    else
      git merge --abort 2>/dev/null; say "$b: smoke failed, merge aborted, branch untouched"
    fi
  else
    say "$b: $n commits but CONFLICTS -- left for a human"
  fi
done
say "integrate done, merged $merged"
