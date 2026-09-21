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

Tests print `PASS `/`FAIL ` per check and end with `<NAME>_TEST_RESULT
failures=N`. A few older ones print `failures: N` instead, so grepping only for
`_TEST_RESULT` will silently miss them. Grep for `^FAIL` as well.

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
you — it is not an error, it is simply absent. This has already happened once in
this repo's history.

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

- `anatomy_traversal_test` — 2 real failures about vaulting a low wall.
  Pre-existing and unrelated to recent gore work. Verified by stashing.
- Weapons do not report their blade edge, so `BaselineHuman._cut_limb()` cuts
  square across a limb. Feeding `BodySlice.plane_from_swing()` the sword's
  frame-to-frame sweep (last frame's tip and base, this frame's tip and base)
  would give cuts at the angle actually swung.
- Blood has wounds, streaks and per-drop splats, but no pooling that grows and
  merges, no footprint tracking, and no soaking into clothing.
- `NPCOllamaBrain` works against a local Ollama (`llama3.2:3b`) but is not wired
  into `npc_conversation_lab`. The model also names itself — the character bible
  says *unnamed* examiner, so the prompt needs a rule against it.
