# StarNet agent briefs, 28 September

Greg: every StarNet agent should be progressing Wizards Only Fools (and the
Foundry, lighter). One brief per agent, one open box from
`DESIGN/CHECKLIST_2026-09-26.md` each. Paste one brief into one agent.

**Rules for every brief** (put these in StarNet's shared instructions):

- Work in the `WizardsOnlyFoolzz` clone (`P:\GameDev\wof-latest`), on your
  own branch `starnet/<lane>`. Start from `origin/claude/dust-to-bones-look`.
- Read `AGENTS.md`, `DESIGN.md` and the skills it names first:
  `wof-lane-hygiene`, `wof-wire-before-polish`, `wof-verify-by-looking`.
- Stage files by explicit path. Never commit `.import`/`.uid` churn or
  zips. Only the art importer brings in generated assets
  (`tools/import_generated_asset.py`).
- Headless test: `ATG_TEST_MODE=1 godot --headless --path game res://tests/<name>.tscn`
  prints `..._RESULT failures=N`.
- Push the branch; do not merge. Claude (cloud) reviews and merges green
  branches into `claude/dust-to-bones-look`, which `Play-Latest.bat` plays.
- Report back: suites run, the PNG you looked at, what you could not verify,
  and any failures that were there before you.
- A decision that is Greg's (anything marked **(Greg)**): stop and ask; do
  not choose.

---

## 1. `starnet/overlay-route`: DONE by Claude (cloud), 28 September

- **GOAL:** Checklist box "Every opening overlay tested in the real route,
  not only in the test scenes."
- **EXISTS:** `tests/first_thirty_route_test.gd` and
  `tests/doctor_chase_route_test.gd` walk the real scenes. The overlays are
  the brain hack card, K/J (`SignalSight`), the keys card (F1), `RunCard`,
  the `FieldMeds` line, and the `ExaminerFight` bar.
- **OWNS:** one new test, `tests/opening_overlays_route_test.gd` (+ `.tscn`).
- **PROOF:** the test drives the real route and asserts that each overlay
  shows, that nothing is stuck on screen after it, and that input is not
  blocked afterwards.
- **TESTS:** the two route tests above stay green.
- **OUT:** changing any overlay's look.

## 2. `starnet/placeholder-loading`: DONE by Claude (cloud), 28 September

- **GOAL:** Checklist "Placeholder: loading screens".
- **EXISTS:** `Interstitial.travel(scene, line)` shows between scenes. Find
  its drawing code first.
- **OWNS:** the interstitial's drawing script only.
- **PROOF:**
  - A code-drawn plate per destination (vat room, Service Arcade, Support
    Unit, drains, Hunt) in the house palette (bone `ead4ad`, copper
    `dc5827`, blood `a81716`, CellOutz type).
  - Open one render per plate.
- **OUT:** generated images. Those wait for LFS and Greg's picks.

## 3. `starnet/placeholder-killcam`: DONE by Claude (cloud), 28 September

- **GOAL:** Checklist "Placeholder: kill-cam X-rays".
- **EXISTS:** `kill_cam` in `bone_yard_hunt.gd`; the anatomy has organs and
  bones (`BaselineHuman._build_bones`).
- **OWNS:** the kill-cam script, plus one shader if needed.
- **PROOF:**
  - The X-ray shows the struck bone or organ breaking.
  - A gallery PNG, looked at.
  - A frame-cost number (`wof-combat-fx`).

## 4. `starnet/placeholder-breakout`: DONE by Claude (cloud), 28 September

- **GOAL:** Checklist "Placeholder: breakout frames".
- **EXISTS:** `brain_hack` beats (the rune, the die, the hack). Qoder took
  the Higgsfield plates out of the build path (rule 4: nothing generated
  ships).
- **OWNS:** the brain-hack drawing code.
- **PROOF:** code-drawn frames under each beat, keeping the existing
  timeline and the 2.6 s hack card. Render each beat.

## 5. `starnet/placeholder-wire`: phone / the Wire

- **GOAL:** Checklist "Placeholder: phone / the Wire".
- **EXISTS:** `systems/handheld_device.gd` (pages INDEX, MAP, WIRE),
  `SignalField`, BrokenWeb sites.
- **OWNS:** the WIRE page's drawing only.
- **PROOF:** a render of the WIRE page with signal and without.

## 6. `starnet/examiner-model`: the authored examiner (Blender)

- **GOAL:** Checklist "The authored examiner model from the M1 sheet
  replaces the stand-in body."
- **EXISTS:**
  - `systems/examiner_look.gd`: tall and gaunt, bloodied coat, surgical
    mask, loupes (Greg, 26 September).
  - The M1 sheet in Greg's art folder.
- **OWNS:** a new `.blend` and GLB under `game/art/`, plus the one line in
  `ExaminerLook` that swaps the body.
- **PROOF:**
  - Under about 5,000 triangles.
  - Renders at the glass, in the intake feed and in the office fight.
  - `examiner_fight_test` stays green.
- **OPEN (Greg):** whether the M1 sheet is final. Ask before modelling.

## 7. Foundry (light; its own repo, not this one)

- **GOAL:** the first $500, which funds artist commissions for the game.
- **Only Greg can:**
  - Add the Printify / Etsy / Gelato keys in StarNet's Connectors panel.
  - Grant `P:\profit-foundry` as a project root.
- **Until then:** production spec and listing copy only. No publishing.

---

**Claude (cloud) is doing:** (wizard eyes done 28 September) the Ice
King / green line-art reference, and reviewing and merging StarNet branches.
