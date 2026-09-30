# Working now: Claude and Codex, same folder, same branch

Both agents work in `P:/GameDev/worktrees/playtest-build` on
`claude/playtest-build`, at the same time. Before editing, read this file.
Claim the files you are about to edit under your name; clear them when you
commit. Never edit a file the other agent has claimed.

## Rules for sharing one folder

- Stage by explicit path only (never `git add -A` / `git add .`), commit
  small and often. Never push, merge, rebase, `git stash`, `git reset`, or
  `git checkout -- <file>` on a file you did not write this session: the
  other agent's uncommitted work lives in the same folder.
- If `git commit` fails on `.git/index.lock`, the other agent is committing:
  wait a few seconds and retry. Never delete the lock.
- If a test fails in a file the other agent has claimed, write it under
  Handoffs instead of fixing it.
- `.import` and `.uid` files churn on every open; never stage them.
- Gore, anatomy, organs, dismemberment and the X-ray kill cam must never get
  worse. A generated model on a person is a skin riding on BaselineHuman's
  zones, never a replacement for the rig.

## Queue (take the top unclaimed item for your name; move it to Done)

Codex:
1. Brief A, the Hunt at 160 fps: DESIGN/CODEX_BRIEFS_2026-09-29.md.
2. Brief B, finish switchable fighting styles from claude/look-styles:
   same file (cherry-pick onto this branch instead of a new worktree).
3. OVERNIGHT_GOALS.md items marked LEFT that are not Greg's decisions.

Claude:
1. Generated models into the game: the examiner as a skin on his anatomy
   rig (walk/idle from Higgsfield), BREACH NINE / shiv / Black Mirror /
   restraint in the hands, CCTV / surgical lamp / drill in the lab.
2. Rebuild Hollis, the numbered guard and the player from Greg's turnaround
   sheets the same way.
3. More of Greg's art into the gallery.

## Claude is in

- game/systems/brain_index_hub.gd, game/systems/hornee_card.gd,
  game/systems/art_gallery.gd, game/systems/wall_poster.gd,
  game/systems/gallery_view.gd, game/tests/capture_scene.gd,
  game/tests/brain_hub_test.gd
- game/art/generated/**, game/art/items/**, game/art/gallery/**,
  game/art/GENERATED.md
- For the model work: game/systems/held_gear.gd, game/systems/baseline_human.gd
  (additive skin support only), game/systems/security_camera.gd,
  game/systems/doctor_route.gd, game/systems/doctor_examination.gd,
  game/vat_chamber.gd, new game/systems/model_skin.gd
- 29 Sep, TWO agents are on the model lane now (Claude, and Codex running the
  Claude prompt). Split by file so nobody collides:
  * Codex: the restraint in hand, the surgical lamp and the bone drill:
    game/systems/doctor_route.gd, game/tests/doctor_route_test.gd, and the
    FIT entries for restraint / surgical_lamp / bone_drill in
    game/systems/generated_model.gd (it owns that file until it commits them).
  * Claude: the examiner skin (new game/systems/model_skin.gd,
    game/systems/baseline_human.gd, examiner_fight.gd, examiner_look.gd, the
    terminal examiner in game/vat_chamber.gd) and the CCTV
    (game/systems/security_camera.gd, support_unit.gd). Claude adds the cctv
    FIT entry to generated_model.gd only AFTER Codex's commit lands.
  * Either: game/tests/model_capture.gd, model_held_items_test.gd,
    model_world_props_test.gd (append, do not reorder).
  Released: dropped_handheld.gd, den_capture.gd, hunter_arsenal.gd,
  vat_body_preview.gd. Greg's frozen playtest copy is P:/GameDev/playtest-stable
  (104b90ad): no agent works or edits there.

## Melee lane (30 Sep, Greg: Souls rolling and good sword fighting, FP and TP)

- Claude: game/gore_demo.gd, game/psy_lab.gd, new game/systems/sandbox_avatar.gd
  (a real third-person body and camera in the sandbox, lock-on), and wiring
  Codex's components into the sandbox (then the Hunt).
- Codex: DESIGN/CODEX_BRIEF_SOULS_MELEE_2026-09-30.md, worktree souls-melee:
  new game/systems/souls_roll.gd, game/systems/sword_moveset.gd, their
  tests, and game/systems/hunter_body_motion.gd (roll and swing poses).

## Codex is in

- Ragdoll and knockback (DESIGN/CODEX_BRIEF_RAGDOLL_KNOCKBACK_2026-09-30.md,
  worktree ragdoll): new game/systems/knockback.gd, game/systems/ragdoll_body.gd,
  their tests, and one opt-in hook in game/systems/baseline_human.gd.
- Done: souls_roll.gd, sword_moveset.gd, hunter_body_motion.gd poses (7bfea594,
  merged into claude/launch-latest at c587a8b5).

## Handoffs

- 97fd657f, e5b2954a, 830ce828: Hornee's card and the art gallery. To put
  more of Greg's art in the world: add the piece to ArtGallery.PIECES, then
  `WallPoster.place(scene, id, position, yaw)` in any scene (one line).
- 2fd2d8ac / 2c822815 / f246d263, generated models. PLACED: the BREACH NINE
  (Hollis's gun: hand, reliquary, hub body) and the shiv (hand, reliquary, den
  floor). NOT PLACED, next agent take these top first:
  Tool: `game/systems/generated_model.gd` (preload it; no class_name).
  `make("name")` -> Node3D, +Z forward, +Y up, metres, pivot at the origin,
  null when the file is missing (keep the drawn fallback). Add an entry to its
  FIT table from numbers printed by
  `Godot --path game res://tests/model_capture.tscn -- --mode=axes --glb=res://art/generated/items/x.glb`
  (also --mode=stats: triangles, bones, materials; --mode=turntable|prop|hunt|hub
  render PNGs, see the header). PCA is right for LINEAR things (shiv, strap,
  phone slab) and WRONG for L-shapes (drill, CCTV, lamp): those came out
  upright already, so they need only yaw and scale. Every model is a unit box
  (longest side 1.0), 5.5-7.5k triangles, 2048 maps. make() caps metal: full
  metal renders black in the Hunt (dark sky, no reflection probes).
  Measured, in model space:
  - black_mirror: right (-0.024,0.069,0.997) = width, up (0.976,0.216,0.008) =
    screen normal (the screen faces +up), forward (-0.214,0.974,-0.073) = the
    top; pivot ~0; 1.036 units long -> scale 0.328 = a 0.34 m phone. Wire:
    dropped_handheld.gd `_build()` (RigidBody, box collider 0.18x0.035x0.34;
    handheld_world_drop_test needs the nodes "Case" and "MirrorGlass" to stay
    MeshInstance3D, so hide the boxes and add the model beside them) and
    vat_chamber.gd `_build_den()` `DenMirror` (still a drawn slab).
  - restraint: long axis (0.955,-0.269,-0.125), 1.05 units, a buckle at each
    end; scale ~0.48 (a 0.5 m strap). Wire: doctor_route.gd shows a held axe
    (`_take_axe`, `LabSurface.hold_in_view`, `_swing_held`) but the restraint has
    no picture at all, though `held_weapon()` returns "restraint": show it when
    `_carries(RESTRAINT_LABEL)` and there is no axe, and swing it too.
  - cctv: lens toward +Z, bracket below and behind; scale ~0.45. Wire:
    security_camera.gd (Support Unit cameras sit on pillars, support_unit.gd
    ~l.425); keep its lens, cone and hack nodes.
  - surgical_lamp: ceiling plate up, head faces roughly +X and tilted; measure
    the head disc normal from the lowest 60% of vertices. Wire: doctor_route.gd
    `_dress_his_life` (SurgeryLamp dish and spot above the gurney); aim the
    SpotLight along the head normal.
  - bone_drill: bit toward +Z, grip down, ~0.28 m. Put it on his tray
    (`tray_at` in `_dress_his_life`).
  - examiner.glb (20.7k tris, 24 bones, 1 AnimationPlayer; examiner_walk/idle
    share the skeleton, copy their clips): NOT STARTED. Rule above applies: a
    skin on BaselineHuman's zones, gore/anatomy/X-ray never worse, so keep the
    rig for hits, wounds and blood and do not just hide its meshes. Its
    material reports emission_enabled=true: check before use. Wire:
    examiner_fight.gd (his room), the terminal examiner in vat_chamber.gd;
    new model_skin.gd.
  Seen / not seen: BREACH NINE and shiv were rendered (turntable, first-person
  hand, reliquary, den floor). Not recaptured after the metal cap: the hub
  body. The den doorway shot in den_capture falls back to another camera.
  Gotchas: the machine renders on the RTX 2060 SUPER; first-person weapons are
  foreshortened (judge them in the reliquary, or `--mode=hunt --acquire=shiv`);
  equip with `arsenal.select_weapon(id)`; run Godot with its own
  `APPDATA=P:/GameDev/Temp/<name>` so two agents do not share user://.
- 7245f77e: the existing roamer distance tiers now actually reduce Hunt AI
  cadence (4 Hz reduced, 0.67 Hz dormant; nearby/named actors unchanged).
  `hunt_roamer_tick_test` is the focused contract. Perf is green; current Hunt
  probe is 11.54 ms on Greg's RTX 2060 SUPER, so Brief A remains open.
- Codex wrap-up for the next agent: Brief A remains open at 11.54 ms against
  the 6.25 ms / 160 fps target. Measured hotspots were the Hunt root physics
  tick (~3.27 ms), field HUD (~3.5 ms), and ~2,030 shadow casters outside the
  district shells. The cached-field-HUD idea was only inspected, never coded;
  the required empty WIP record is `P:/GameDev/Temp/codex-wip.patch`.
  Rejected experiments: shared material-seed batching washed the rust-black
  buildings pale; exact-material grouping preserved the look but regressed to
  13.97 ms / 3,566 draws; disabling hidden panels added draw work. Core's
  pre-existing `gore_demo_test` failures remain: “blast at your feet takes
  limbs off” and the room limb count (not caused by Codex); the other gore,
  anatomy and kill-cam suites passed. Brief B has not been started. First next
  step: prototype the field HUD in a 30 Hz cached SubViewport, behind a test
  switch, then compare pinned-hour PNGs and perf before keeping any code.
- 7ed53e34: generated Black Mirror placed as the dropped Hunt device and the
  den phone. `Case`/`MirrorGlass`, collider, serial, wear and battery contracts
  remain. Use `model_capture --mode=drop` for the real Hunt view;
  `model_world_props_test`, world-drop, weak-wall and all 32 core suites green.

## Done

- Claude queue 1 is finished: the examiner skin (b553a6c3), the CCTV (2fe20b1e),
  and the surgical lamp and bone drill in the doctor's room (on
  claude/launch-latest). The lamp's head faces +X in the file, so its FIT turns
  the head normal to -Y and the arm slants up to a short ceiling pole. The
  drill's grip is slanted, so it lies on its side on the tray. Both were
  measured headless, not looked at in a window yet: `model_world_props_test`
  checks size, placement and that the head is over the SurgeryLamp light.
  Next: queue 2 (Hollis, the guard and the player need Greg's turnaround
  sheets, which are not in the repo or ArtReference), and hornee_plush.glb is
  still unplaced.
