#!/bin/bash
# Quota-aware lane dispatcher.
#
# Runs one agent per free lane on one free account. An account that reports a
# usage wall is parked until the reset time in its own error message; a lane
# already running is skipped by its lock. Meant to be fired on a schedule --
# it does nothing at all when everything is busy or blocked, which is the
# point: work restarts by itself the minute quota comes back.
set -u
R=/c/Users/Greg/lane-runner
W=/c/Users/Greg/orca/workspaces/AllusionsTooGrandeur
S=$R/state
LOG=$R/dispatch.log
NOW=$(date +%s)
mkdir -p "$S"
say() { echo "[$(date '+%m-%d %H:%M')] $*" >> "$LOG"; }

# --- park an account, reading the reset out of what the CLI actually said ---
park() {
  local acct="$1" logf="$2" until=""
  if grep -qi "out of credits" "$logf"; then
    until=$((NOW + 21600)); echo "needs-credits" > "$S/$acct.reason"
  elif grep -qi "usage limit\|weekly limit\|session limit" "$logf"; then
    local when
    when=$(grep -oiE "try again at [^\"]{4,40}|resets [A-Z][a-z]+ [0-9]{1,2}[^\"]{0,30}" "$logf" | head -1)
    local secs
    secs=$(python -c "
import sys,re,datetime
s=sys.argv[1] if len(sys.argv)>1 else ''
now=datetime.datetime.now()
m=re.search(r'(\d{1,2}):(\d{2})\s*(AM|PM)',s,re.I)
d=re.search(r'([A-Z][a-z]{2})[a-z]*\s+(\d{1,2})',s)
t=None
if d:
    months={'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12}
    mo=months.get(d.group(1),now.month); day=int(d.group(2))
    hh,mm=(0,0)
    if m:
        hh=int(m.group(1))%12+(12 if m.group(3).upper()=='PM' else 0); mm=int(m.group(2))
    y=now.year+(1 if mo<now.month-6 else 0)
    t=datetime.datetime(y,mo,day,hh,mm)
elif m:
    hh=int(m.group(1))%12+(12 if m.group(3).upper()=='PM' else 0)
    t=now.replace(hour=hh,minute=int(m.group(2)),second=0,microsecond=0)
    if t<=now: t+=datetime.timedelta(days=1)
print(int((t-now).total_seconds())+300 if t else 3600)
" "$when" 2>/dev/null)
    [ -z "$secs" ] && secs=3600
    until=$((NOW + secs)); echo "quota: $when" > "$S/$acct.reason"
  fi
  if [ -n "$until" ]; then
    echo "$until" > "$S/$acct.blocked"
    say "parked $acct until $(date -d @$until '+%m-%d %H:%M' 2>/dev/null || echo $until) ($(cat "$S/$acct.reason"))"
  fi
}

free_account() {
  local kind="$1"
  while IFS=$'\t' read -r k id label; do
    [ "$k" = "$kind" ] || continue
    [ -f "$S/$id.running" ] && continue
    if [ -f "$S/$id.blocked" ]; then
      local u; u=$(cat "$S/$id.blocked")
      [ "$NOW" -lt "$u" ] && continue
      rm -f "$S/$id.blocked" "$S/$id.reason"
    fi
    echo "$id $label"; return 0
  done < "$R/accounts.tsv"
  return 1
}

run_lane() {
  local lane="$1" wt="$2" note="$3" kind="$4" id="$5" label="$6"
  touch "$S/$id.running" "$S/$wt.running"
  # Detached through Start-Process so this script -- and the scheduled task
  # wrapping it -- can exit straight away. Backgrounding with & kept bash
  # alive until the agent finished, which under MultipleInstances=IgnoreNew
  # meant the task blocked its own next tick. The 09:45 tick never ran.
  powershell -NoProfile -Command "Start-Process -FilePath 'C:\Program Files\Git\bin\bash.exe' -ArgumentList '-lc','\"/c/Users/Greg/lane-runner/lane_agent.sh $wt $kind $id $label \\\"$note\\\"\"' -WindowStyle Hidden" >/dev/null 2>&1
  say "started $wt on $kind/$label"
}

say "--- tick ---"
started=0
while IFS=$'\t' read -r lane wt note; do
  [ -f "$S/$wt.running" ] && continue
  [ -d "$W/$wt" ] || continue
  got=""
  for kind in codex claude; do
    if got=$(free_account "$kind"); then
      run_lane "$lane" "$wt" "$note" "$kind" ${got% *} "${got#* }"
      started=$((started+1)); break
    fi
  done
  [ -z "$got" ] && { say "no free account left; $wt waits"; break; }
done < "$R/lanes.tsv"
say "tick done, started $started"
