# One prompt per agent (26 September)

Each prompt is self-contained: paste it as the agent's first message. They
share the rules in `DESIGN/MASTER_PROMPT_2026-09-26.md` (Part 1) and each owns
one lane, so they don't edit the same files.

## 1. Codex (on Greg's PC): the Hunt, broken tests first

```text
You are Codex working on WIZARDS ONLY FOOLS (Godot 4.7.2, GDScript), repo
YashicaDeth/WizardsOnlyFoolzz. Read AGENTS.md, DESIGN.md and
DESIGN/MASTER_PROMPT_2026-09-26.md (Part 1 is your rules; Lane B is yours).
Work in your own git worktree on branch codex/hunt-tests, made from
origin/claude/dust-to-bones-look.

YOUR JOB: make the Hunt's test suite green, fixing root causes. These seven
were already failing before 26 September:
  grapple_playability_test   parse error: `released_from` declared twice
  standing_contact_test      talk panel close() and _close_talk_panel() recurse forever
  vault_test                 a 0.8 m box within reach is not found
  firearm_aim_test           RMB commits a heavy melee swing with no firearm equipped
  handheld_world_drop_test   the deliberate drop is refused
  handheld_world_light_test  the map's exposure doesn't widen the phone beam
  melee_cut_plane_test       the player doesn't wake in the humiliation rig
Run each one: ATG_TEST_MODE=1 godot --headless --path game res://tests/<name>.tscn
Then run every test that loads bone_yard_hunt.tscn and keep them all green.
Never skip, disable or weaken a test.

THEN, performance: keep Greg's ~160 fps. _update_encounter_actors costs
1.3 ms: cut it. Redraw the HUD only on change. Distance-cull the Hunt's 98
lights. No per-frame find_children or allocations.

YOU OWN: game/bone_yard_hunt.gd and the Hunt-only systems these tests name.
Do not touch the opening scenes (vat_chamber, support_unit, old_drains,
service_arcade, buried_city) or the gore systems.

Before choosing anything Greg hasn't decided, ask him as a question box with
the recommended option first: see Part 3, questions 17-20.

DONE = all Hunt tests green, merged into claude/dust-to-bones-look and pushed.
No zips: Greg plays with Play-Latest.bat. Report what you fixed, the suites you
ran, and anything you could not verify.
```

## 2. OpenCode (on Greg's PC): gore everywhere

```text
You are OpenCode working on WIZARDS ONLY FOOLS (Godot 4.7.2, GDScript), repo
YashicaDeth/WizardsOnlyFoolzz. Read AGENTS.md, DESIGN.md and
DESIGN/MASTER_PROMPT_2026-09-26.md (Part 1 is your rules; Lane C is yours).
Own worktree, branch opencode/gore, from origin/claude/dust-to-bones-look.

YOUR JOB: gore works the same in the Gore Sandbox, the vat room, the Support
Unit and the Hunt:
- blades and bullets cut
- limbs come off as chunks
- organs, wound marks
- blood flow, pool and veil
- hitstop
The systems exist and pass their tests: systems/gore_chunks.gd,
wound_catalog.gd, wound_marks.gd, blood_flow.gd, blood_pool.gd,
blood_veil.gd, blood_ledger.gd, blood_trees.gd, gore_demo.gd. Find each place
a scene deals damage and confirm it reaches them. Hook in with one line
through the existing hit/damage call. Don't write a second gore system.

PROOF: for each scene, render a hit and open the PNG. Add one test proving
the vat room and the Support Unit produce a wound and blood on a hit.
Keep gore_*, blood_*, wound_*, chunk_test and organ_* green.
gore_load_test is a benchmark: run it on the PC, not headless.

ALSO: if the branch opencode/base-model-kit exists, merge it (tests green).

YOU OWN: the gore and blood systems and gore_demo.gd, plus one hook line per
scene. Nothing else.
Ask Greg questions 21-24 from Part 3 as question boxes (recommended first)
before changing gore defaults.
DONE = merged into claude/dust-to-bones-look and pushed. No zips. Report the
PNGs you opened and the suites you ran.
```

## 3. Qoder: placeholder art, wired in

```text
You are Qoder working on WIZARDS ONLY FOOLS (Godot 4.7.2), repo
YashicaDeth/WizardsOnlyFoolzz. Read AGENTS.md, DESIGN.md,
DESIGN/MASTER_PROMPT_2026-09-26.md (Lane D), DESIGN/HIGGSFIELD_ROADMAP.md
and DESIGN/LOOK_FROM_CONCEPTS.md. Own worktree, branch qoder/art.

YOUR JOB: put curated placeholder art in the game until Greg's own art lands,
in this order:
1. loading screens
2. breakout frames
3. the phone and the Wire
4. kill-cam X-rays
Use Greg's Higgsfield downloads (tools/Import-Higgsfield.ps1 puts them on
their own branch). Pick distinct pieces "with a grain of salt": Greg likes a
lot and dislikes a lot. Nothing that looks generic or AI-slick.

RULES: media goes through Git LFS; never convert formats to dodge it. Log
every piece in game/art/GENERATED.md. Never overwrite Greg's own art. Wire
each piece into the screen that shows it and render that screen to prove it.

YOU OWN: game/art/**, tools/**, and the art-loading lines of each screen.
Ask Greg questions 25-26 from Part 3 as question boxes first.
DONE = each category visible in game, merged into claude/dust-to-bones-look.
No zips.
```

## 4. Freebuff: plugins and project health

```text
You are Freebuff working on WIZARDS ONLY FOOLS (Godot 4.7.2), repo
YashicaDeth/WizardsOnlyFoolzz. Read AGENTS.md and
DESIGN/MASTER_PROMPT_2026-09-26.md (Lane D, plugins). Own worktree, branch
freebuff/plugins.

YOUR JOB: every plugin loads, is pinned and does its job.
- dialogue_manager and proton_scatter: enabled, load cleanly.
- gdUnit4: editor and tests only.
- LimboAI (GDExtension): present and shipped in builds.
- terrain_3d: enabled in game/project.godot but its folder is not in the
  repo. Ask Greg (question 27): restore it pinned, or remove the entry.
- godot_mcp: editor only; export_presets.cfg must keep excluding it.
Open the project in the editor headless (godot --headless --editor --quit)
and clear every plugin error and warning. Don't upgrade a plugin without
asking Greg.

YOU OWN: game/addons/**, game/project.godot plugin lines,
game/export_presets.cfg.
DONE = a clean editor load, pinned versions written in DESIGN.md, merged and
pushed. No zips.
```

## 5. Qwen 3.8 via OmniRoute: the playtest walk-through

```text
You are Qwen working on WIZARDS ONLY FOOLS (Godot 4.7.2), repo
YashicaDeth/WizardsOnlyFoolzz. Read AGENTS.md, DESIGN.md,
DESIGN/CHECKLIST_2026-09-26.md and DESIGN/MASTER_PROMPT_2026-09-26.md
(Lane E). Own worktree, branch qwen/playtest.

YOUR JOB: prove the first 30 minutes play start to finish:
intake, brain hack, breakout, vat room, Support Unit, drains, Service
Arcade, Lower Works, Hunt. Walk it in the engine (existing *_capture and
*_route tests help). Capture a PNG at each beat and open it. Log every crash,
dead end, skybox fall, soft-lock or missing prompt as a line in
DESIGN/PLAYTEST_LOG_2026-09-26.md, naming the owning lane:
  Lane A  opening scenes  (Claude)
  Lane B  the Hunt        (Codex)
  Lane C  gore            (OpenCode)
  Lane D  art and plugins (Qoder / Freebuff)
Fix only what is in no lane's files. Tick checklist boxes only with proof.
Ask Greg questions 31-34 from Part 3 as question boxes.
DONE = the log pushed, merged into claude/dust-to-bones-look. No zips.
```

## 6. Claude Code (cloud): the opening spine

```text
Continue as Lane A of DESIGN/MASTER_PROMPT_2026-09-26.md on
YashicaDeth/WizardsOnlyFoolzz: develop on your session branch, merge green
work into claude/dust-to-bones-look.
Next, in order:
1. Stashes and secret doors: hidden things in SignalSight, found in K/J,
   opened with E.
2. Signals in the phone camera, once Codex's Hunt lane has merged.
3. A timed run of minutes 0-30 with every opening overlay in the real route.
Ask Greg questions 1-16 from Part 3 as question boxes before each piece.
Render and look at every visual change. No zips.
```

## 7. Higgsfield (art prompts, not code)

```text
Wizards Only Fools: a first-person body-horror escape from a buried
cloning facility. Look: PS1-era crunch, low-poly, sun-bleached copper and
teal salvage, bone and dried blood, heavy grain, body-cam footage. Not
glossy, not generic. No text or logos in the image.
Make: [one of]
  a loading screen of a vat aisle, cloned bodies curled in cracked tanks,
    one red vat glow in the dark
  a breakout frame: a hand punching through tank glass, fluid and shards
    frozen mid-air
  the Black Mirror phone lying face-up in rust, its screen showing a
    grainy green night-vision feed
  a kill-cam X-ray: a skeleton in cold blue line-art, a blade path through
    the ribs
16:9, 1920x1080.
```
