# Working now: Claude and Codex, same folder, same branch

Both agents work in `P:/GameDev/worktrees/playtest-build` on
`claude/playtest-build`. Before editing, read this file. Claim the files you
are about to edit under your name; clear them when you commit. Never edit a
file the other agent has claimed. Commit small and often, stage by explicit
path (never `git add -A`), never push, merge or rebase.

When you finish something the other agent could build on, write it under
"Handoffs" in one line: what, commit hash, what they can do with it.

## Claude is in

- game/systems/brain_index_hub.gd, game/systems/hornee_card.gd,
  game/tests/capture_scene.gd, game/tests/brain_hub_test.gd
- New: game/systems/art_gallery.gd, game/systems/wall_poster.gd (the
  in-game art gallery: posters with tear-off tabs, business cards, Greg's
  art, collected into the Brain Index)
- game/art/generated/**, game/art/items/**, game/art/GENERATED.md
  (Higgsfield models)
- game/art/gallery/** (Greg's own art for the gallery), game/systems/art_gallery.gd,
  game/systems/wall_poster.gd, game/systems/gallery_view.gd
- One add_child line each for posters in: game/vat_chamber.gd,
  game/support_unit.gd, game/service_arcade.gd

## Codex is in

- (write your files here before you start)

## Handoffs

- 2fd2d8ac: nine generated models imported (examiner rigged, Hornee, BREACH
  NINE, Black Mirror, shiv, restraint, CCTV, surgical lamp, drill). None is
  placed in a scene yet. Rule: people keep the game's anatomy rig
  (BaselineHuman) underneath; a generated body is only a skin riding on its
  zones, so gore, organs and the X-ray kill cam keep working.
