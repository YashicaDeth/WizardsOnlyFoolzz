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

## Codex is in

- Brief A / Hunt render cost: game/systems/ashbloom_world_generator.gd,
  new game/tests/hunt_render_cost_probe.gd,
  new game/tests/hunt_render_cost_probe.tscn

## Handoffs

- 97fd657f, e5b2954a, 830ce828: Hornee's card and the art gallery. To put
  more of Greg's art in the world: add the piece to ArtGallery.PIECES, then
  `WallPoster.place(scene, id, position, yaw)` in any scene (one line).
- 2fd2d8ac: nine generated models imported (examiner rigged, Hornee, BREACH
  NINE, Black Mirror, shiv, restraint, CCTV, surgical lamp, drill). None is
  placed in a scene yet.

## Done

- (move finished queue items here with their commit)
