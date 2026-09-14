#!/bin/bash
# Commits tracked work left sitting in worktrees nobody is watching.
#
# Written because a cleanup pass on 15 September found three stale worktrees
# holding uncommitted source -- wire_net.gd +63, black_mirror.gd +90,
# gothic_field_hud.gd +182 -- all on branches that were fully merged and
# therefore one `git worktree remove` away from gone.
#
# Rules it will not break:
#   - never touches a worktree whose agent is live
#   - never touches the trunk worktree (a human works there)
#   - only tracked modifications, staged by explicit path, never -A
#   - untracked files are reported, never committed
set -u
R=/c/Users/Greg/lane-runner
P=/p/GameDev/AllusionsTooGrandeur
LOG=$R/rescue.log
say() { echo "[$(date '+%m-%d %H:%M')] $*" >> "$LOG"; }
say "--- rescue tick ---"
cd "$P" || exit 1

git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while read -r w; do
  case "$w" in
    "$P") continue;;                      # trunk: a human works here
  esac
  base=$(basename "$w")
  [ -f "$R/state/$base.running" ] && { say "$base: agent live, left alone"; continue; }
  [ -d "$w" ] || continue
  files=$(git -C "$w" diff --name-only 2>/dev/null | grep -vE '\.(import|uid)$')
  [ -z "$files" ] && continue
  n=$(echo "$files" | wc -l)
  stat=$(git -C "$w" diff --shortstat 2>/dev/null | tr -d '\n')
  say "$base: $n tracked files uncommitted ($stat) -- committing"
  ( cd "$w" || exit 1
    echo "$files" | while read -r f; do [ -n "$f" ] && git add -- "$f"; done
    git commit -q -m "Rescue: $n tracked files left uncommitted in $base

$stat

Committed by the rescue pass, unreviewed and unrun. Uncommitted work in a
worktree nobody is watching is one cleanup away from gone, and this project
has already come within one command of losing several hundred lines that way.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
  )
  head=$(git -C "$w" rev-parse --short HEAD)
  if [ "$(git -C "$w" rev-parse --abbrev-ref HEAD)" = "HEAD" ]; then
    git branch "rescue/$base" "$head" 2>/dev/null && say "$base was detached; anchored at rescue/$base"
  fi
  say "$base: committed $head"
done
say "rescue done"
