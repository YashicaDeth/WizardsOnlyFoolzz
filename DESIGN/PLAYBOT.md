# PlayBot: an AI playtester bridge

Greg (4 Oct 2026): wants a somewhat smart model to *play* the demo like a human,
at human pace, and report what is engaging, what bugs it hits, and what feels
dumb or breaks immersion (for example constant loading screens instead of one
cohesive map). This file covers the harness. A later task does the playing.

## Pieces

| File | What it does |
|---|---|
| `game/tools/playbot.gd` + `game/tools/playbot.tscn` | In-game bridge. Not an autoload. Does nothing unless `ATG_PLAYBOT=1` |
| `tools/playbot_step.py` | CLI: sends one command, blocks until the matching state comes back, prints it |
| `game/tests/playbot_bridge_test.tscn` (+ `playbot_stub.tscn`) | Headless test of one command round-trip and every event type |

`game/export_presets.cfg` excludes `tools/playbot*`, so a release build never
contains the bridge. Without `ATG_PLAYBOT=1` the scene quits straight away.

## Running it

The bridge only produces screenshots in a **windowed** run, because headless
draws no pixels. Hub rule: a windowed run goes through
`P:/GameDev/AgentHub/render_one.cmd` (one window at a time, right monitor).
That script was not on disk when this was built (4 Oct). Until it exists, ask
the hub before you open a window.

```bash
export ATG_PLAYBOT=1
export ATG_PLAYBOT_DIR=P:/GameDev/AgentHub/playbot      # the default
export ATG_PLAYBOT_START=res://country_town_menu.tscn   # optional; default = project main scene
export APPDATA=P:/GameDev/AgentHub/work/appdata-<lane>
# windowed (through render_one.cmd):
Godot_v4.7.2-stable_win64_console.exe --path game res://tools/playbot.tscn
# headless (state and events only, no screenshots):
Godot_v4.7.2-stable_win64_console.exe --headless --path game res://tools/playbot.tscn
```

`playbot.tscn` puts a PlayBot node on the root, beside the scenes, so it
survives every scene change. Then it loads the start scene. If a `cmd.json`
is left over from a previous run, it is deleted on start. `state.json` is
written straight away with `seq: 0`.

Then loop:

```bash
python tools/playbot_step.py '[{"hold":"move_forward","s":1.5},{"look":[30,0]},{"press":"interact"},{"wait":2}]'
```

The command prints the new state as JSON. Open `screenshot` (a PNG path), pick
the next actions, and run it again. `--state` prints the last state without
acting. `seq` is filled in automatically (one past the last state).

## Actions (`cmd.json`)

`{"seq": N, "actions": [ ... ]}`. The actions run in order. When the last one
has finished, the bridge waits a frame, saves `shot_N.png`, then writes
`state.json` with `seq: N`. The state file is written last, so when it appears
the screenshot is already on disk.

| Action | Effect |
|---|---|
| `{"hold": "move_forward", "s": 1.5}` | Hold an InputMap action, or a key name such as `"E"` or `"Space"`, for up to 10 s. `hold` can be a list, e.g. `["move_forward","sprint"]` |
| `{"press": "interact"}` | Tap for 0.12 s |
| `{"look": [dx, dy]}` | Turn in degrees: +x is right, +y is up. Capped at 220°/s, so a 180° turn takes about 0.8 s |
| `{"pad": "cross", "s": 0.12}` | A PlayStation button (`cross circle square triangle l1 r1 l2 r2 l3 r3 up down left right touchpad create options`). `PadBridge` turns it into the key the game expects |
| `{"click": "left", "s": 0.12}` | A mouse button |
| `{"wait": 2}` | Wait without input, up to 10 s |

Inputs go through the game's own input paths. For an InputMap action, the
bridge sends that action's own bound key event, so code that reads `KEY_E`
directly sees `interact` too. Looking changes the scene's own `yaw` / `pitch`,
the same values mouse-look changes. A scene that has no `yaw` gets mouse-motion
events instead.

Game time keeps running between commands, just as it would while a person
stopped to think.

## `state.json`

`seq`, `clock`, `scene`, `seconds_in_scene`, `position`, `yaw_deg`, `health`,
`objective`, `prompt`, `dialogue`, `dialogue_speaker`, `interstitial_travelling`,
`fps`, `paused`, `mouse_captured`, `log` (the last 20 log lines, errors
included), `events` (anything logged since the last state), and `screenshot`
(a path, or null with `screenshot_note` when headless).

`objective` and `prompt` hold only what is on screen: the text of a visible
Label named `Objective` / `Prompt` (the shared `$HUD/...` convention).
`health` is a `health` / `hp` property on the player body or on the scene.

## `events.jsonl`

One JSON object per line. Each has `type`, `t`, `seq` and `scene`.

| type | When |
|---|---|
| `scene_change` | The current scene changed (`from`, `to`, `seconds_in_previous`) |
| `loading_start` / `loading_end` | `Interstitial.travelling` went up or down. `loading_end.seconds` is how long the plate stayed up |
| `script_error` | Any engine or script error (warnings are skipped), with file, line and text |
| `fell_through_floor` | The player is 40 m below the lowest floor it stood on in this scene |
| `stuck` | 20 s of acting with no change in position (1 m grid), objective, prompt or scene |
| `invisible_wall` | While moving, the player hit a side collider that has nothing visible drawn on it, its parent or its children |
| `bad_action` | An action, key or button name the bridge did not understand |

## Persona prompt for the playing agent

The persona below is an assistant proposal, not Greg's text. Edit it freely.

> You are playing a dark occult horror game for the first time. You have
> never seen it before and nobody has explained it to you. You are not a
> tester. You are a curious, slightly slow player who looks around before
> moving, reads what is on screen, and tries what seems obvious to try.
>
> Each turn, look at the screenshot and the state, then pick a few seconds
> of actions: walk, look, press what a prompt tells you to press. Do not
> speed through it. Stop to look at anything that catches your eye. If you
> do not know what to do, say so and try something reasonable, the way a
> person would. Do not read code or use anything outside the screen.
>
> Every few turns, write one or two plain sentences about how it feels
> right now: what you are curious about, what confused you, what was
> exciting or creepy, what felt cheap, broken or dumb, and anything that
> pulled you out of it (loading screens, walls you could not see, text
> that made no sense, waiting with nothing to do). Use your own words, not
> game-design jargon.
>
> At the end, report: (1) what was most engaging, (2) bugs you hit, with
> what you did just before each, (3) what felt dumb or broke immersion,
> (4) where you got lost or stuck, and for how long.

The bridge's `events.jsonl` provides the hard numbers (load-screen seconds,
errors, stuck spots, invisible walls). They go in the report next to the
player's own impressions.

## Limits

- Headless runs have no screenshots, so playing for real needs a windowed run
  through `render_one.cmd`.
- Scenes that draw their HUD by hand (the Hunt overworld) have no
  `Objective` / `Prompt` Label, so those fields are empty there. The
  screenshot still shows the text.
- In the vat the player has no `health` property, so `health` is null.
- Headless reports the mouse as never captured. Scenes that only accept
  look or attack input while the mouse is captured will ignore `click` when
  headless. `look` still works where the scene exposes `yaw`.
- `invisible_wall` checks only for drawn geometry on the collider, its parent
  and its children. A wall drawn by a sibling or a distant mesh can be a
  false positive.
