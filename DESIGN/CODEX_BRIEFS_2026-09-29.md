# Briefs for Codex, 29 September 2026

Paste one brief per Codex session. Each works in its own worktree and owns
its own files; Claude is working the same day on the Higgsfield assets
(generated models, the Brain Index hub, the vat room's props and the
examiner's model), so those files are off limits below.

## Where things stand (read this first)

- The playable build is branch `claude/playtest-build`
  (worktree `P:/GameDev/worktrees/playtest-build`). The first thirty minutes
  run end to end: `game/tests/first_run_walk_test` walks every gate.
- Last night's run and every open item with its reason:
  `OVERNIGHT_GOALS.md` at the worktree root. The friends' demo checklist is
  `DESIGN/CHECKLIST_FRIENDS_DEMO_2026-09-28.md` (92/100 before last night).
- Greg's decisions live in `DESIGN.md` (dated sections). Open questions
  that are his are in `DESIGN/dust-to-bones.html` (section VII). Do not
  answer any of them; stop and report instead.
- Test runner: `tools/run_tests.sh <suites>`, `--core` (32 suites, all green
  now), `--perf` (windowed frame budget over the route). The exit code is the
  authority.
- House rules: `.claude/skills/wof-lane-hygiene/SKILL.md`,
  `wof-verify-by-looking`, `wof-wire-before-polish`. Read them first. Never
  `git add -A`; `.uid` files are ignored by git; never push, merge or rebase
  another branch.

## Files Claude owns today (do not edit)

`game/systems/brain_index_hub.gd`, `game/systems/vat_body_preview.gd`,
`game/systems/photo_album.gd`, `game/vat_chamber.gd`,
`game/systems/doctor_route.gd`, `game/systems/held_gear.gd`,
`game/art/generated/**`, `game/art/items/hornee/**`,
`game/tests/glb_turntable.*`, `game/art/GENERATED.md`.

---

## Brief A: the Hunt at 160 fps

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish,
running-headless-godot, performance-profiling.

WORKTREE  git -C P:/GameDev/AllusionsTooGrandeur worktree add -b
          codex/hunt-frame P:/GameDev/worktrees/hunt-frame claude/playtest-build
          then: Godot --headless --path game --import  (once)

GOAL      The Bone Yard Hunt holds 6.25 ms a frame (160 fps) on Greg's
          RTX 2060 SUPER, windowed. It is 13.6 ms alone and 16.5 ms in the
          --perf run today. Greg asked for the frame rate to be fixed.

EXISTS    Measured last night (OVERNIGHT_GOALS.md, items 8-13):
          - tests/perf_probe (wall-clock frame, draws, per-child cost),
            tests/script_cost_probe (ScriptCost laps inside
            bone_yard_hunt._physics_process, ATG_TEST_MODE=1, windowed),
            tests/process_cost_probe (switch each script's process off),
            tests/viewport_audit (hidden SubViewports: 0 now).
          - The Hunt's own calls are ~2.6 ms of a ~6.3 ms physics step:
            _update_encounter_actors 0.78, _update_hud 0.42, _update_player
            0.30. The rest of physics is the engine (Jolt made no difference).
          - Draws ~3,190; ProceduralAshbloomDistricts owns 1,547 meshes and
            already fog-culls (FOG_CULL) and batches some with MultiMesh.
          - HUDs already redraw at 20-30 Hz, not every frame.

OWNS      game/systems/ashbloom_world_generator.gd, game/systems/*actor*.gd
          and encounter/roamer systems, physics layer/mask settings, new
          files. bone_yard_hunt.gd: small edits only (a declaration, a new(),
          one call per change), because other work touches it.

PROOF     tools/run_tests.sh --perf green with the Hunt under 6.25 ms, plus
          perf_probe numbers before/after in each commit message. A capture
          of the Hunt from the spawn (capture_scene) that looks the same as
          before -- open it; nothing may pop, vanish or go dark.

TESTS     --core green. hunt_*, roamer*, population_budget_test,
          map_perf_test green.

OPEN      Anything that changes what the player sees or plays (fewer
          people, shorter view distance, less gore) is Greg's call: measure
          it, propose it, do not ship it.

OUT       The vat room, the Brain Index, art assets, combat numbers.

REPORT    What you could not verify, and any suite that was already red.
```

---

## Brief B: finish switchable fighting styles (look-styles)

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish,
wof-combat-fx, maximizing-game-feel.

WORKTREE  git -C P:/GameDev/AllusionsTooGrandeur worktree add -b
          codex/styles P:/GameDev/worktrees/styles claude/playtest-build
          then bring the rescued work across from claude/look-styles
          (4 commits, "WIP rescue: switchable combat styles, blood growth,
          loot preservation") by cherry-picking onto this branch. Resolve
          conflicts; do not merge any other branch.

GOAL      Greg, 24 September (DESIGN.md "Stated by Greg, 24 September
          2026"): "switchable martial-art, sword and gun styles, with
          stealth as its own; blood XP from use and kills; a tree per style;
          weapons evolve through blood; overkill destroys organs and
          cybernetics, clean kills keep them." Make the rescued WIP real:
          a style switches live in the Hunt, earns blood from use and kills,
          and a clean kill leaves organs lootable while an overkill does not.

EXISTS    claude/look-styles (unreviewed, untested rescue commits).
          BloodTrees (game/systems/blood_trees.gd) already runs a tree and
          blood per hit; character_presets saves a fighting style;
          the intake has a STYLE page. Read them before writing anything.

OWNS      game/systems/blood_trees.gd, new style files, the look-styles
          files you bring over, their tests. bone_yard_hunt.gd: declaration,
          new(), one call per change.

PROOF     In the Hunt: switch style, land hits, see blood rise for that
          style, kill one enemy cleanly and one with overkill, and loot the
          difference. Record it (capture_scene or Movie Maker) and look.

TESTS     --core, blood_tree*, character_presets_test, disarm_test,
          gore_sandbox_* green. One new test per rule you make real.

OPEN      Tree contents, costs and names beyond what the WIP and DESIGN.md
          already say are Greg's. Combat numbers (mass, reach, disarm) are
          reserved for Greg's hands (DESIGN/dust-to-bones.html briefs).

OUT       The vat room, the Brain Index hub, art assets, the Hunt's frame
          rate (Brief A owns that).

REPORT    What you could not verify, and any suite that was already red.
```
