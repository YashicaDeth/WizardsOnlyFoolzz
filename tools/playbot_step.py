#!/usr/bin/env python3
"""Send one command to a running PlayBot and wait for what it saw.

    python tools/playbot_step.py '{"actions":[{"hold":"move_forward","s":1.5}]}'
    python tools/playbot_step.py --state          # print the last state only

The game side is game/tools/playbot.gd (usage: DESIGN/PLAYBOT.md). This writes
cmd.json with the next seq (one past state.json's, unless the JSON gives one),
then blocks until state.json comes back with that seq. state.json is written
after the screenshot, so when it arrives the shot is already on disk. Prints
the state as JSON; the screenshot path is in "screenshot" (null headless).
Exit 0 on success, 2 on timeout.
"""

import argparse
import json
import os
import sys
import time

DEFAULT_DIR = os.environ.get("ATG_PLAYBOT_DIR", "P:/GameDev/AgentHub/playbot")


def read_state(folder):
    try:
        with open(os.path.join(folder, "state.json"), encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("cmd", nargs="?", help='JSON: {"actions":[...]} or a bare [...] list of actions')
    parser.add_argument("--dir", default=DEFAULT_DIR)
    parser.add_argument("--timeout", type=float, default=120.0, help="seconds to wait for the state")
    parser.add_argument("--state", action="store_true", help="print the last state and exit")
    args = parser.parse_args()

    if args.state or not args.cmd:
        state = read_state(args.dir)
        print(json.dumps(state, indent=2))
        return 0 if state is not None else 2

    cmd = json.loads(args.cmd)
    if isinstance(cmd, list):
        cmd = {"actions": cmd}
    if "seq" not in cmd:
        state = read_state(args.dir) or {}
        cmd["seq"] = int(state.get("seq", 0)) + 1
    seq = int(cmd["seq"])

    os.makedirs(args.dir, exist_ok=True)
    temp = os.path.join(args.dir, "cmd.json.tmp")
    with open(temp, "w", encoding="utf-8") as handle:
        json.dump(cmd, handle)
    os.replace(temp, os.path.join(args.dir, "cmd.json"))

    deadline = time.time() + args.timeout
    while time.time() < deadline:
        state = read_state(args.dir)
        if state is not None and int(state.get("seq", -1)) >= seq:
            print(json.dumps(state, indent=2))
            return 0
        time.sleep(0.2)
    print(json.dumps({"error": "timeout", "seq": seq, "dir": args.dir}), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
