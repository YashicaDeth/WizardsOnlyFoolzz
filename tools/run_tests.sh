#!/usr/bin/env bash
# Run this project's test scenes and report them the same way, whatever they
# print.
#
# There are 495 test scenes. 268 of them end with `<NAME>_RESULT failures=N`;
# the rest do not. Some print `failures: N`, some print a sentence, and some --
# handheld_satellite_test is the one that caught me -- print only `ok` and
# `PASS` lines with no summary at all. So grepping the suite for failures finds
# nothing and says nothing, which reads exactly like everything passing.
#
# The authority here is the exit code, because every one of them ends with
# `get_tree().quit(0 if failures.is_empty() else 1)` however it chose to talk
# about it on the way. FAIL lines are counted as well, so a suite that returns
# zero while printing failures is still reported rather than believed.
#
# Usage:
#   tools/run_tests.sh npc_ gore          run every scene matching either
#   tools/run_tests.sh --core             the ones worth running before a commit
#   tools/run_tests.sh --all              all 495, which takes hours
#   tools/run_tests.sh --list npc_        show what would run, run nothing

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
export TEMP="P:/GameDev/Temp"
export TMP="$TEMP"
export ATG_TEST_MODE=1

# Per-scene ceiling. The opening takes ~35s of real time by construction, so
# this is generous; it exists to stop one hung scene eating the whole run.
TIMEOUT="${ATG_TEST_TIMEOUT:-200}"

# What to run before committing: the spine of the game plus whatever has been
# touched most. Not a substitute for --all, just the set worth the wait.
CORE=(
  baseline_human_test body_slice_test body_cut_test cavity_test
  bone_fragment_test chunk_test gore_demo_test lab_dressing_test gore_sandbox_systems_parity_test
  combat_stance_test blade_read_test
  npc_conversation_test npc_relationship_test npc_async_turn_test
  npc_voice_test spoken_contact_test standing_contact_test npc_ruling_test facility_characters_test kill_shot_test sniper_killcam_test
  skull_burst_test
  world_clock_test opening_handoff_test opening_direction_test
  arsenal_test armor_resolution_test blood_flow_test
)

list_only=0
patterns=()
for arg in "$@"; do
  case "$arg" in
    --list) list_only=1 ;;
    --core) patterns+=("${CORE[@]}") ;;
    --all)  patterns+=("") ;;
    *)      patterns+=("$arg") ;;
  esac
done

if [ ${#patterns[@]} -eq 0 ]; then
  echo "usage: tools/run_tests.sh [--core|--all|--list] [pattern ...]" >&2
  echo "       refusing to guess; --all runs all 495 and takes hours" >&2
  exit 2
fi

# Collect matching scenes once, de-duplicated, so overlapping patterns do not
# run the same suite twice.
scenes=()
for pattern in "${patterns[@]}"; do
  while IFS= read -r scene; do
    name="$(basename "$scene" .tscn)"
    found=0
    for seen in ${scenes[@]+"${scenes[@]}"}; do
      [ "$seen" = "$name" ] && found=1 && break
    done
    [ $found -eq 0 ] && scenes+=("$name")
  done < <(ls "$ROOT"/game/tests/*.tscn | grep -- "$pattern" || true)
done

if [ ${#scenes[@]} -eq 0 ]; then
  echo "no test scenes matched" >&2
  exit 2
fi

if [ $list_only -eq 1 ]; then
  printf '%s\n' "${scenes[@]}"
  echo "(${#scenes[@]} scenes)"
  exit 0
fi

printf '%-34s %6s %6s  %s\n' "SUITE" "EXIT" "FAILS" "REPORTED"
printf '%.0s-' {1..78}; echo

broken=0
ran=0
for name in "${scenes[@]}"; do
  output="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$ROOT/game" "res://tests/$name.tscn" 2>&1)"
  code=$?
  fails="$(printf '%s' "$output" | grep -c '^FAIL' || true)"
  # Whatever it chose to say about itself, if it said anything.
  marker="$(printf '%s' "$output" | grep -oE '([A-Z0-9_]+_RESULT failures=[0-9]+|failures: [0-9]+)' | tail -1)"
  [ -z "$marker" ] && marker="(no marker)"
  [ "$code" = "124" ] && marker="TIMED OUT after ${TIMEOUT}s"
  ran=$((ran + 1))
  if [ "$code" != "0" ] || [ "$fails" != "0" ]; then
    broken=$((broken + 1))
    printf '%-34s %6s %6s  %s\n' "$name" "$code" "$fails" "$marker"
    # Only failing suites print their failures, or a green run is unreadable.
    printf '%s' "$output" | grep '^FAIL' | sed 's/^/    /'
  else
    printf '%-34s %6s %6s  %s\n' "$name" "$code" "$fails" "$marker"
  fi
done

printf '%.0s-' {1..78}; echo
if [ $broken -eq 0 ]; then
  echo "$ran suites, all green"
  exit 0
fi
echo "$ran suites, $broken with failures"
exit 1
