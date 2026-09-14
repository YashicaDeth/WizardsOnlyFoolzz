#!/bin/bash
# One lane, one account, start to finish. Launched detached by dispatch.sh so
# the scheduled task can exit immediately -- a task that stays alive while its
# agents run blocks its own next tick under MultipleInstances=IgnoreNew, which
# is exactly what stalled the 09:45 tick.
set -u
R=/c/Users/Greg/lane-runner
W=/c/Users/Greg/orca/workspaces/AllusionsTooGrandeur
S=$R/state
wt="$1"; kind="$2"; id="$3"; label="$4"; note="$5"
logf="$R/$wt.log"
say() { echo "[$(date '+%m-%d %H:%M')] $*" >> "$R/dispatch.log"; }
NOW=$(date +%s)

{
  echo "=== $wt | $kind $label | $(date) ==="
  cd "$W/$wt" || exit 1
  git ls-files --others --exclude-standard | grep -E '\.(uid|import)$' | while read -r f; do rm -f "$f"; done
  git restore -- '*.import' '*.uid' 2>/dev/null
  git merge --ff-only codex/game-planning 2>&1 | tail -1
} > "$logf" 2>&1

prompt="Read START_HERE.md and begin. This is $wt: $note. Work one coherent change at a time; run the suites before every commit and stage by explicit path, never -A. If a suite prints nothing at all, that is a parse error somewhere, not a pass."

cd "$W/$wt" || exit 1
export PATH="$PATH:/c/Users/Greg/AppData/Roaming/npm"
if [ "$kind" = codex ]; then
  export CODEX_HOME="C:/Users/Greg/AppData/Roaming/orca/codex-accounts/$id/home"
  codex exec </dev/null --dangerously-bypass-approvals-and-sandbox "$prompt" >> "$logf" 2>&1
else
  export CLAUDE_CONFIG_DIR="C:/Users/Greg/AppData/Roaming/orca/claude-accounts/$id/auth"
  claude -p "$prompt" --dangerously-skip-permissions </dev/null >> "$logf" 2>&1
fi
echo "[exit=$?]" >> "$logf"

# park the account on whatever wall it reported, using its own words
until=""
if grep -qi "out of credits" "$logf"; then
  until=$(( $(date +%s) + 21600 )); echo "needs-credits" > "$S/$id.reason"
elif grep -qi "usage limit\|weekly limit\|session limit" "$logf"; then
  when=$(grep -oiE "try again at [^\"]{4,40}|resets [A-Z][a-z]+ [0-9]{1,2}[^\"]{0,30}" "$logf" | head -1)
  secs=$(python -c "
import sys,re,datetime
s=sys.argv[1] if len(sys.argv)>1 else ''
now=datetime.datetime.now(); m=re.search(r'(\d{1,2}):(\d{2})\s*(AM|PM)',s,re.I); d=re.search(r'([A-Z][a-z]{2})[a-z]*\s+(\d{1,2})',s); t=None
if d:
    months={'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12}
    mo=months.get(d.group(1),now.month); day=int(d.group(2)); hh,mm=(0,0)
    if m: hh=int(m.group(1))%12+(12 if m.group(3).upper()=='PM' else 0); mm=int(m.group(2))
    t=datetime.datetime(now.year,mo,day,hh,mm)
elif m:
    hh=int(m.group(1))%12+(12 if m.group(3).upper()=='PM' else 0)
    t=now.replace(hour=hh,minute=int(m.group(2)),second=0,microsecond=0)
    if t<=now: t+=datetime.timedelta(days=1)
print(int((t-now).total_seconds())+300 if t else 3600)
" "$when" 2>/dev/null)
  [ -z "$secs" ] && secs=3600
  until=$(( $(date +%s) + secs )); echo "quota: $when" > "$S/$id.reason"
fi
[ -n "$until" ] && { echo "$until" > "$S/$id.blocked"; say "parked $label until $(date -d @$until '+%m-%d %H:%M' 2>/dev/null)"; }
rm -f "$S/$id.running" "$S/$wt.running"
say "$wt finished on $label"
