#!/usr/bin/env python3
"""Merge CuriosityBot runs into one ranked table.

    python3 tools/curiosity_report.py runs/*/curiosity_*.json > merged.md

Reads the JSON reports `game/tests/curiosity_run.gd` writes and ranks, across
all runs, the kinds of thing that held the bot's attention, the events that
held it longest, what it walked away from, and where it got stuck. Measures
only; it decides nothing.
"""
import json
import sys
from collections import defaultdict


def merge(paths):
    runs = [json.load(open(p)) for p in paths]
    kinds = defaultdict(lambda: {"runs": set(), "count": 0, "attend_s": 0.0, "near_s": 0.0, "visits": 0, "verbs": 0, "left": defaultdict(int)})
    events = defaultdict(lambda: {"runs": set(), "count": 0, "hold_s": 0.0, "after_verb": 0})
    stuck = []
    for index, run in enumerate(runs):
        scene = run.get("target_scene", paths[index])
        for row in run.get("thing_kinds", []):
            k = kinds[row["kind"]]
            k["runs"].add(scene)
            for key in ("count", "attend_s", "near_s", "visits", "verbs"):
                k[key] += row[key]
            for reason, n in row.get("left", {}).items():
                k["left"][reason] += n
        for row in run.get("events", []):
            e = events[row["type"]]
            e["runs"].add(scene)
            e["count"] += row["count"]
            e["hold_s"] += row["hold_s"]
            e["after_verb"] += row["after_verb"]
        for row in run.get("stuck_spots", []):
            stuck.append((scene, row))
    return runs, kinds, events, stuck


def pairs(d):
    return ", ".join(f"{k} x{v}" for k, v in sorted(d.items(), key=lambda kv: -kv[1])[:4]) or "-"


def main(paths):
    if not paths:
        print(__doc__)
        return 2
    runs, kinds, events, stuck = merge(paths)
    out = ["# Curiosity runs, merged", ""]
    out.append("| Scene | Simulated s | Cells | Coverage % | Walked m | Things | Event types |")
    out.append("|---|---:|---:|---:|---:|---:|---:|")
    for run in runs:
        out.append(f"| {run.get('target_scene', '?')} | {run['sim_seconds']} | {run['cells_visited']} | {run['coverage_pct']} | {run['distance_walked_m']} | {run['things_seen']} | {len(run['events'])} |")
    out += ["", "## Kinds of thing, by attention", "", "| Kind | Scenes | n | Attending s | Near s | Visits | Verbs | How it left |", "|---|---|---:|---:|---:|---:|---:|---|"]
    for kind, k in sorted(kinds.items(), key=lambda kv: -(kv[1]["attend_s"] + kv[1]["near_s"] * 0.25))[:40]:
        out.append(f"| {kind} | {len(k['runs'])} | {k['count']} | {k['attend_s']:.1f} | {k['near_s']:.1f} | {k['visits']} | {k['verbs']} | {pairs(k['left'])} |")
    out += ["", "## Events, by how long they held it", "", "| Event | Scenes | Count | Held s | Mean held s | After a verb |", "|---|---|---:|---:|---:|---:|"]
    for etype, e in sorted(events.items(), key=lambda kv: -kv[1]["hold_s"]):
        out.append(f"| {etype} | {len(e['runs'])} | {e['count']} | {e['hold_s']:.1f} | {e['hold_s'] / max(1, e['count']):.1f} | {e['after_verb']} |")
    out += ["", "## Stuck spots", "", "| Scene | Position | Blocked | Stale | Chasing |", "|---|---|---:|---:|---|"]
    for scene, row in sorted(stuck, key=lambda sr: -(sr[1]["blocked"] + sr[1]["stale"]))[:30]:
        out.append(f"| {scene} | {row['pos']} | {row['blocked']} | {row['stale']} | {pairs(row['pursuing'])[:80]} |")
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
