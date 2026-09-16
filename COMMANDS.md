# Commands and prompts

Everything you can type — at a shell, or at one of the four agents. Copy from
here rather than retyping.

---

# 1. Running the game

| What | Command |
| --- | --- |
| **Play it** | `P:\GameDev\PLAY.cmd` |
| **Open the editor** | `P:\GameDev\EDIT.cmd` |
| **Where everything is** | `P:\GameDev\WHERE-IS-EVERYTHING.md` |
| **The exported build** | `P:\GameDev\build\windows\WizardsOnlyFools.exe` |

Run it windowed on the second monitor:

```bash
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --path game --resolution 1280x720 --position 2240,320
```

Export a fresh build to hand somebody:

```bash
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game --export-release "Windows Desktop" P:/GameDev/build/windows/WizardsOnlyFools.exe
```

---

# 2. Checking it still works

Every test is a scene. `ATG_TEST_MODE=1` is required or they refuse to run.

```bash
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game res://tests/<name>.tscn
```

The ones worth knowing:

| Test | What it proves |
| --- | --- |
| `frame_profile` | The frame budget. Prints ms, fps, draw calls, nodes, physics |
| `map_perf_test` | What the map costs, measured against the frame without it |
| `derby_exit_test` | Leaving the derby does not crash — the whole heat and both endings |
| `limb_momentum_test` | The arm's physics: flick versus committed sweep |
| `arm_calibration_test` | Prints the gesture table the damage curve is tuned from |
| `arm_wired_test` | That the arm is actually attached to the game, not just built |
| `ballistics_test` | Bullet drop, drag, pattern spread, brass settling |
| `world_clock_test` | The hour, the phases, and the radio schedule |
| `godhead_test` | Attention, visibility, and what a lesson costs |
| `gameplay_demo` | Captures a run of real gameplay frames to `P:/GameDev/Temp/demo` |

Rebuild the class cache after adding a new `class_name` (or Godot will not see it):

```bash
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game --import
```

Fail the build if editor parsing introduces a project-owned script warning or error (addon and engine-shutdown noise is excluded):

```powershell
./tools/verify-godot-diagnostics.ps1 -Godot P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe
```

---

# 3. The documents

| File | What it is |
| --- | --- |
| `CHECKLIST.md` | The whole plan. 1,574 segments, A to AS, ladders to v10 |
| `BUILD_INDEX.md` / `.json` | The same flattened, one line each, for splitting work |
| `DESIGN/THE_REWORK.md` | What the game is about. Your eighteen pages, organised |
| `DESIGN/FINAL_V.md` | The sixteen rules of the finished build, and the TD pipeline |
| `AGENT_PROMPTS.md` | The current brief for each agent |
| `CHANGES.md` | The build record, generated from the commits |

Regenerate the published pages and the index:

```bash
cd C:/Users/Greg/AppData/Local/Temp/claude/P--GameDev-AllusionsTooGrandeur/c8b7b99d-82aa-42ae-a3e8-08183de92627/scratchpad && python build_index.py && python build_sheet.py && python build_changes.py
```

Cut a lane for an agent out of the index:

```bash
python -c "import json;r=json.load(open('BUILD_INDEX.json',encoding='utf-8'))['segments'];print('\n'.join('%s %s'%(x['id'],x['text']) for x in r if x['section'] in ('AI','AR') and not x['done']))"
```

---

# 4. Keeping four agents out of each other's way

This has cost four incidents now, including one that broke every run and one
torn read today. **Before anything else, every agent:**

```
git -C <your worktree> status
```

If that prints `P:\GameDev\AllusionsTooGrandeur`, you are in the shared tree and
you must move.

Check what is pending from everybody:

```bash
cd P:/GameDev/AllusionsTooGrandeur && for b in agent-b agent-c codex/b6-combat; do echo "== $b: $(git rev-list --count codex/game-planning..$b 2>/dev/null)"; done
```

Merge somebody's finished work in:

```bash
cd P:/GameDev/AllusionsTooGrandeur && git merge --no-edit agent-b
```

**If an agent is behind, it rebases before it commits.** Codex was 146 commits
back this afternoon, which would have reverted a day of work on merge:

```
git fetch && git rebase codex/game-planning
```

---

# 5. What to send each agent

Everyone reads `DESIGN/THE_REWORK.md`, `DESIGN/FINAL_V.md` and their block in
`AGENT_PROMPTS.md` first. These are the short versions to paste.

## The rules every prompt should carry

```
Work in your own worktree, never in P:\GameDev\AllusionsTooGrandeur.
I0: no screen is a list of text in a box — but that never meant no information.
    A gauge is an object. That misreading stripped the derby of every readout.
Rule 3: every hard cut is a bug.
The ladder: vN+1 only fixes what vN exposed. A version that cannot name a real
    fault is not written. v10 is the ceiling.
Never claim a visual result you have not looked at. Capture it, open the PNG.
Wire what you build. M2 was ticked off a screenshot and sat unused for days.
Satire aims at institutions, never at congregations or any group of people.
No assets or implementations from commercial games. Experiential reference only.
```

## Agent A (Claude) — the body, and the opening

```
Read DESIGN/THE_REWORK.md sections 2 and 5 first.

Rework the body model and the X-ray cursor. The body is the first thing a
player meets in this game and it currently reads as a mannequin. It should
read as human that has evolved wrong under this world's story: a demon,
angel and antichrist mix, post-collapse, post-experiment. It is the same
BaselineHuman rig every NPC uses, so whatever you change changes everyone.

Then AP1.1-AP1.7, the opening in the order Greg wrote it: captured
underground as meat and scrap, the quiz (D builds the sheet already, reuse
it — AP1.2 says it matters mystically not statistically), tortured and
experimented on revealed across the game rather than at the start, the gore
festival, the tunnel derby, out.

AP1.5 is the reframe that matters: the derby is the ESCAPE, not a side mode.
rift_derby.gd works and has a cab, instruments, firing and a climb-out. It
does not have a reason. Give it one. Do not rebuild it — re-situate it.

AP2.1-AP2.5: the spirit cannot be banished by violence and the game must
prove that early rather than say it. AP2.2 wants the flame to melt the
screen itself — a real shader.
```

## Agent B (Claude) — the night, and the psychedelic pipeline

```
Read DESIGN/FINAL_V.md section 16 in full before starting.

AS1-AS4: the handheld is a lamp with a battery, raising it costs you a hand,
pocketing it is a movement, and its light is what gives you away at night.
Light warps at night rather than dimming. Storms are a readout of how much
magick is loose — anvil crawlers, the long horizontal crawl, not a flash.

Then the pipeline. TouchDesigner cannot run inside a shipped Godot game, so
TD is the lab, Godot shaders are the engine, Blender supplies the rigs.
Build in this order:
  1. psychedelic.gdshader — one shader, six uniforms, all at zero by
     default: palette LUT, kaleidoscope UV fold, feedback, chromatic
     separation, noise displacement, beat-locked cuts.
  2. A SubViewport feedback rig. Feedback is the one effect that cannot be
     faked and is half of what makes Everhood look like Everhood.
  3. An OSC bridge for development only. It does not ship.
  4. Vertex Animation Textures for Blender deformation Godot cannot rig.

Then the drugs, meditation, shadow realms and the godhead's approach are all
the same shader with different dials.

You are editing the shared tree. Move to your worktree.
```

## Agent C (Claude) — the charts, and the seals

```
AI: the double pyramid. Upright above, inverted below, meeting at a point,
the player at the waist. As above so below — that is not decoration, it is
the two-axis system AA already has. Tiers as strata with real edges, never
indentation. Density carries meaning: the base is crowded, the apex is one
thing. Every tier populated from WorldHistory, never authored.

AR: the tree of life. The pyramid is where power is; the tree is which way
you went. They pin onto the same Board, so build them knowing they share a
wall. Four paths, opening at chapters not levels.

E2.4-E2.7: burn and bind seals animate onto a real motherboard, the sigil
burning into the copper traces. A printed circuit board is already a sigil
drawn in copper and mass-produced. Burning is subtractive and scars the
copper; binding is additive and closes a loop. celloutz_type.gd already has
draw_seal_burning() and it has only ever run in 2D — this is the 3D half.

Take the density from Greg's reference charts, never the payload. He steered
off the QAnon register himself: "just black magick and chaos magick".
```

## Agent D / Astra (GPT) — the room, the cloud, and the body

```
Read DESIGN/THE_REWORK.md before anything else.

First, with Agent A: the body model and the X-ray cursor. The body should
read as human evolved wrong under this world's story — a demon, angel and
antichrist mix. It is the shared BaselineHuman rig, so it changes everyone.
Coordinate with A on who owns which file before you start.

Then AH, which is yours alone and is the largest unbuilt idea in the project:

Opening the Board puts you IN A ROOM rather than on a screen. A bed, a
wall-sized mirror, one window's light. Turn to the wall for the Board —
pin_board.gd is built and bound to P, it needs to be ON A WALL instead of
filling the screen. Turn right for the cloud terminal. Leaving is a
movement, not a menu close.

The mirror shows your body, current, with everything done to it.
BaselineHuman already renders that for the dossier — reuse it.

REMEMBER THE CLOUD: an archive in fragments. A fragment is REPAIRED, not
unlocked — the verb is restoration and it costs something the player has.
The archive is visibly incomplete forever. It talks like cloud software
written by people who are now dead.

The tutorial web: a node web where connections mean something. Each node is
a curved CRT with scanlines playing the mechanic as a short DRAWN loop, a
paragraph in the game's voice, and THE KEYS. That last part is what the
first playtester was actually asking for.
```

---

# 6. Short prompts you can fire at any of us

```
show me the checklist
show me a gameplay demo
what did the other agents land
merge everything and tell me what broke
profile the frame and tell me what is expensive
find me the thing that is built but wired to nothing
tick what is actually done and be honest about what is not
capture <screen> and show me the PNG
what is blocked on me
```

---

# 7. Still blocked on you

1. **The Horsemen's names** (K2) — War, Famine, Pestilence and Death are
   placeholders in the index right now.
2. **AC1.1** — does this game have simulated fluid, or painted fluid done well?
   It is the most expensive item on the list and half-done fluid reads worse
   than none.
3. **"Louka vision"** — you named it beside Everhood and nobody knows what it
   is. Needed before FINAL_V §16 is finished.
