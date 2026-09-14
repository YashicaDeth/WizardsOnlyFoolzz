#!/bin/bash
# Finds suites that print nothing. A GDScript parse error anywhere in a
# dependency chain silences a suite completely -- no PASS, no FAIL, no error --
# and this project has been reading that silence as green for a week.
set -u
P=/p/GameDev/AllusionsTooGrandeur
G="P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
OUT=/c/Users/Greg/lane-runner/sweep.log
export TEMP="P:/GameDev/Temp" TMP="P:/GameDev/Temp" ATG_TEST_MODE=1
cd "$P" || exit 1
: > "$OUT"
echo "sweep started $(date)" >> "$OUT"
for f in game/tests/*.tscn; do
  t=$(basename "$f" .tscn)
  case "$t" in *_capture) continue;; esac
  r=$(timeout 70 "$G" --headless --path game "res://tests/$t.tscn" 2>&1)
  p=$(echo "$r" | grep -c '^PASS'); fl=$(echo "$r" | grep -c '^FAIL')
  pe=$(echo "$r" | grep -c 'Parse Error')
  if [ "$p" -eq 0 ] && [ "$fl" -eq 0 ]; then
    echo "SILENT   $t   parse_errors=$pe" >> "$OUT"
    echo "$r" | grep 'Parse Error' | head -2 | sed 's/^/           /' >> "$OUT"
  elif [ "$fl" -gt 0 ]; then
    echo "FAILING  $t   pass=$p fail=$fl" >> "$OUT"
    echo "$r" | grep '^FAIL' | head -4 | sed 's/^/           /' >> "$OUT"
  else
    echo "ok       $t   pass=$p" >> "$OUT"
  fi
done
echo "SWEEP_DONE $(date)" >> "$OUT"
