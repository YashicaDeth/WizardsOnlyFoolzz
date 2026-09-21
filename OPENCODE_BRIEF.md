# Brief for OpenCode (or any agent that is not Claude Code)

Paste this whole file as your first message. It assumes no prior conversation.

---

## 1. Read these first, in this order

1. `AGENT_BRIEF_CURRENT.md` — who you are, what the game is, how to behave.
   Everything about the project lives there. **This file does not repeat it.**
2. `COMMANDS.md` — how to run the game and the suites.
3. `AGENTS.md`, then whichever of `DESIGN/` or `ARCHITECTURE/` your task touches.

`AGENT_BRIEF.md` is superseded. Ignore it.

Work at `P:\GameDev\AllusionsTooGrandeur`. Godot 4.7.2 is at
`P:\GameDev\Tools\Godot-4.7.2\`. Git is the handoff protocol.

## 2. Running a test

Every test is a scene. `ATG_TEST_MODE=1` is required or they refuse to run.

```bash
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe" --headless --path game res://tests/<name>.tscn
```

Use the `_console` binary — the other one swallows stdout on Windows.

Or run a set and have them reported uniformly:

```bash
tools/run_tests.sh --core
```

Only 268 of the 495 scenes end with `<NAME>_RESULT failures=N`. The rest print
`failures: N`, or a sentence, or only `ok`/`PASS` lines with no summary at all,
so grepping the suite for failures finds nothing and says nothing -- which
reads exactly like everything passing. The runner goes by exit code and counts
`^FAIL` lines too. If you run a scene by hand, do both.

## 3. Traps that cost real time

**A new `class_name` script does not exist until Godot imports it.** Write
`systems/foo.gd` with `class_name Foo`, and every reference to `Foo` is a parse
error until you run:

```bash
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe" --headless --path game --import
```

That pass writes `foo.gd.uid` and registers the class in
`.godot/global_script_class_cache.cfg`. **Commit the `.uid` with the script.**
A script committed without it is a type nobody can reference, and nothing warns
you — it is not an error, it is simply absent. This has happened twice in this
repo's history, to `npc_ollama_brain.gd` and to `cavity.gd`.

The first `--import` after adding files takes minutes. It is not hung.

**`BodyMesh` profiles are normalised `-1..1`, and `scaled()` takes *half*
height.** `BodyMesh.leg(0.84)` spans y −0.42…+0.42 about the origin, not
0…0.84. Assuming otherwise puts your cut plane off the end of the limb.

**There is no `Skeleton3D` anywhere in the body rig.** Bodies are revolved
`ArrayMesh` parts. Do not port skinned-mesh techniques (SkinGore-style UV damage
buffers, active ragdolls, bone-weight slicing) — they solve problems this
project does not have, and they need a skeleton it does not have.

**Another agent (Codex) commits to this repo concurrently.** Run `git log
--oneline -5` and `git status` before you start and before you commit. Expect
untracked `.uid` files that are not yours; do not stage them.

## 4. The working rule that matters most

**When a test fails, find out whether the test is lying before you change game
code.**

`opening_handoff_test` reported six failures and looked like a broken opening.
The opening was fine. The test sent one keypress a frame after load, while three
deliberate gates stood in front of filing (a form that arms after 5.5s, a
requirement to confirm every tab, and a procedure that swallows keys while it
runs). All six failures had one cause, and the fix was entirely in the test.

Changing the game to satisfy a wrong test destroys design that was argued for.
Read the code the test is driving, and make the test do what a player does.

Related: state results exactly. If two checks fail, say two failed and quote
them. Do not report a suite as passing because most of it did.

## 5. House style

Comments explain **why**, not what. The codebase's own comments name the defect
that made the code necessary — read `systems/wound_marks.gd` or
`systems/npc_dialogue_contract.gd` for the register before writing any.

Commit messages: sentence-style subject, no `feat:`/`fix:` prefixes. Body
explains the reasoning and states test results. See `git log`.

Prefer adding a system beside the existing one over rewriting it. Anything that
changes what a body does needs a test in `game/tests/` with its own `.tscn`.

## 6. Open items

Checked and correct as of the last commit on this file. If you finish one,
delete it -- a stale brief is worse than no brief, because this is the file
people read instead of looking.

- `anatomy_traversal_test` — 2 real failures about vaulting a low wall.
  Pre-existing and unrelated to the gore work. Verified by stashing, so they
  are not a side effect of anything recent. `_vault_target()` in
  `bone_yard_hunt.gd` is where they live. **Nobody has claimed these.**
- Three finished systems are waiting on one call each, all of them in
  `bone_yard_hunt.gd`:
  - `Cavity.open_zone()` — `_update_extraction()` runs a nine-second dig over
    a torso that never opens. This cuts the wall away and reveals the organs.
  - `KillShot.earned()` — the kill camera only fires on melee executions. This
    decides when a shot earns one, and refuses over survivable wounds.
  - `SpokenContact` — `_voice_captured()` has no transcript, so a downed NPC
    answers the *fact* of being spoken to. This adds the words.
- The local model names itself. `npc_conversation_lab`'s character bible says
  *unnamed* examiner and `llama3.2:3b` introduced itself as "Dr. Thompson".
  That is a prompt rule, not a code bug.
- Performance, measured rather than suspected: 39 fps, `process` 20.16ms
  against a 16.67ms budget, `physics` 10.94ms. `ProceduralAshbloomDistricts`
  owns 2141 visible meshes -- more than everything else in the scene combined
  -- and nothing anywhere uses a `MultiMesh`. `tools/run_tests.sh` will not
  help here; `game/tests/sandbox_perf_probe.tscn` is the thing to re-run, and
  it must run windowed because headless skips rendering entirely.
