# The checklist, 26 September

Greg asked for "a checklist with heaps of boxes". It covers everything open
across the first thirty minutes (100 boxes since 27 September, at Greg's ask), as of build `perf` (the commit after
`0883665`). A ticked box was done and checked in this repo. An unticked box is
still open. **(Greg)** marks something only Greg can do or decide.

## Performance: 60 to 160 fps

- [x] Measure before touching anything. Vat chamber: 608k triangles, 1,146 draw calls. Support Unit: 178k. Drains: 53k. Hunt: 11 ms of script per physics tick.
- [x] Cap round-mesh detail by size (`MeshBudget`, run on every mesh as it enters the tree). Only lowers segment counts, never raises them.
- [x] Vat chamber: 608k → 151k triangles.
- [x] Support Unit: 178k → 48k triangles.
- [x] Drains: 53k → 10k triangles.
- [x] The specimen curled in each lab vat: 255k → 25k triangles.
- [x] Baseline human heads: 119k → 18k triangles.
- [x] K/J vision layer sleeps when off (it was copying the screen every frame even when invisible).
- [x] The graphics tier's render scale actually reaches the window now (it was never applied).
- [x] PERFORMANCE tier upscales with FSR 1 instead of a blurry stretch.
- [x] Hunt line-of-sight: stop re-walking every body's node tree for every hunter, every frame (2.2 ms → 0.2 ms).
- [x] Hunt world bookkeeping at 4 times a second instead of 60 (2.1 ms → off the table).
- [x] Hunt script cost: 7.3 ms → 3.5 ms per physics tick.
- [x] Checked by eye: the lab renders the same after the cuts.
- [x] **(Greg)** F10 on build `a866957`: about 160 fps in the vat room, Support Unit, sewers, Hunt and menu (NVIDIA RTX, 144 Hz+).
- [ ] **(Greg)** Press F11 anywhere it drops under 60 and send the dump file next to the exe.
- [ ] **(Greg)** Check whether VSync is on in Settings. VSync locks fps to your monitor's refresh (60, 144 or 165).
- [x] Vat room draw calls (1,146): decided not to merge. Greg's F10 reads about 160 fps there, and merging would change the look (each prop's material is unique) and break props the scene still drives (the weak wall, the dark bays).
- [x] Hunt: bodies over 35 m pose every 4th tick on saved-up time (`_update_encounter_actors` 0.90 → 0.69 ms, 12 actors).
- [x] Hunt HUD: the held-item reliquary only redraws on change (it was redrawing 9 times a frame).
- [x] Hunt lights: every light without its own fade fades out past 36 m or 4× its reach (59 of 100). Rendered with and without: the same near you.
- [x] Hunt physics checked: the 184 pairs are characters on floors and props, 1 active object; nothing idle to cut.
- [x] A real-GPU benchmark on Greg's PC: his F10 reading, about 160 fps everywhere (the cloud renders on the CPU).
- [x] `standing_contact_test`: the talk panel's close only announces the first close now.
- [x] `sandbox_perf_test` skips itself headless.
- [x] The six Hunt tests failing before 26 September all pass: `firearm_aim`, `handheld_world_light`, `melee_cut_plane`, `vault`, `grapple_playability`, `handheld_world_drop`.

## The opening, beat by beat (OPENING_TORTURE_INTAKE.md)

- [x] Torture load-in.
- [x] Intake pages: route, race, traits, face, body, birth, schedule, style.
- [x] Birthday reading from the chart.
- [x] Fighting style page.
- [x] Opening greeting lines.
- [x] Brain hack: the rune, the die, "BRAIN HACKED SOUL OVERTAKEN".
- [x] The hands-on breakout: cord, three blows, the glass.
- [x] The examiner in the bloodied coat, tapping the glass.
- [x] The watchers replace the static hung cameras.
- [x] The examiner's look from Greg's answers: tall, gaunt, bloodied coat, surgical mask (at his throat while he talks, up to fight) and loupe glasses. Same man at the glass, on the intake feed and in his office.
- [ ] The authored examiner model from the M1 sheet replaces the stand-in body.
- [x] Real-mic V intake (optional): hold V and say the answer, the page ("next"), a row ("two"), "confirm" or "file it"; typing still works.
- [x] Vat room darker, red only in the glow: neutral black sky and fog, lower ambient, a desaturated grade (a data-only change to HouseLook's vat-room entry), a neutral exit light, a stronger red vat glow. The red checker floor and the pillars keep their own texture colour.
- [ ] **(Greg)** Is the vat room dark enough, or too dark?
- [x] The examiner fight in his office (behind the door you break): scalpel cuts and a syringe that slows you. Win: his keycard and coat. Lose: back in the vat, he keeps the coat, your old body stays in his office. His keycard opens the staff door on his cupboard (two dressings, eight rounds).
- [x] Meds on hold-4: a FIELD DRESSING takes 2.5 s, heals 20, no fighting while you bandage; in every opening area and the Hunt. Loose rounds load into the gun you take.
- [ ] Every opening overlay tested in the real route, not only in the test scenes.
- [x] Minutes 0-30 are timed (hidden); surfacing into the Hunt shows a card with the time per area and whether it was under 30. A death does not restart the clock.
- [ ] **(Greg)** Play a full run and read your card.

## K and J vision modes

- [x] K = wizard eyes (toggle). J = depth scan (hold).
- [x] Both unlock from the brain hack.
- [x] Cameras send invisible signals, seen only in K/J as pulsing wave rings.
- [x] Tracking cameras' rings turn red.
- [x] Spirits as glowing green figures.
- [x] Bodies through walls in the depth scan.
- [x] Strain: static, blur, nosebleed; clears when you leave the mode.
- [x] Only hacked cameras notice.
- [x] Vat chamber, Support Unit and drains wired.
- [x] The Hunt: K/J wired (tap K wizard eyes, hold J depth; enemies show through walls).
- [x] Hunt keys: inventory to Tab (the Brain Index hub moved to Shift+Tab).
- [ ] **(Greg)** Is Shift+Tab right for the Brain Index hub?
- [x] Hunt keys: re-decant to hold-K (1.2 s, with a progress prompt).
- [x] The phone camera shows signals too: raise the Black Mirror and its masts, terminals and any camera signals pulse in infrared, named with their distance.
- [x] Wires and power in wizard eyes and depth: pulses run along each line; seen once, E at the junction cuts it. Vat room: that bay goes dark. Support Unit: that camera goes blind, quietly.
- [x] Hidden things shown in wizard eyes and the depth scan (a general list any scene can fill).
- [x] Stashes and secret doors: 7 hidden things across the opening (Greg: 5-8), faint seam for plain eyes, found in K/J, opened with E; meds and ammo.
- [x] The weak wall in the Growing Floor: wizard eyes show cracks, depth shows HOLLOW, E breaks it, the crawlway drops you past the Service Arcade gate.
- [ ] **(Greg)** Is past-the-arcade-gate the right place for the shortcut to lead?
- [ ] Wizard-eyes shader pass against the Ice King / green line-art reference.
- [ ] **(Greg)** Play K and J and say if the look is right.

## Jump and climb everywhere

- [x] Drains: SPACE jumps, climbs out of the channel and the cistern.
- [x] Vat chamber (once you are on your feet; a body fresh out of the tank jumps weakly).
- [x] Support Unit.
- [x] Service Arcade.
- [x] Lower Works (already had a jump).
- [x] The Hunt (it already had its own jump, vault, wall-run and climb).
- [x] One shared jump/climb component (`JumpClimb`); the drains use it too.
- [x] A climb test on a built stage (`jump_climb_test`), plus the drains climb test.
- [x] Lower Works: ledge climbing as well as its jump.
- [x] Sprint in the vat room (weak, grows as the body recovers) and in the Service Arcade.
- [x] Crouch-slide everywhere in the opening: sprint + Ctrl, about 1 s, the view drops; a little noise in the Support Unit and drains.
- [x] Small fall damage: only over 2.5 m, at most 15 blood, never lethal.
- [x] Sounds, made in code: K choir hum that swells with strain, J sonar ping, weak-wall and secret-door crumble, hatch creak, wire spark.
- [ ] **(Greg)** Listen to the five WAVs and say which to change.

## Art and look

- [x] HouseLook screen grade (another lane).
- [x] Interface curation from the Higgsfield concepts (LOOK_FROM_CONCEPTS.md).
- [ ] **(Greg)** Allow `lfs.github.com` in the environment, or run `tools\Import-Higgsfield.ps1`, so media can be pushed.
- [ ] Placeholder: breakout frames.
- [ ] Placeholder: loading screens.
- [ ] Placeholder: phone / the Wire.
- [ ] Placeholder: kill-cam X-rays.
- [ ] Log every placed piece in `game/art/GENERATED.md`.
- [ ] Code-and-effects GFX pass over the placeholder art (Godot shaders).
- [ ] TouchDesigner loops (later).
- [ ] **(Greg)** Your own art replaces the placeholders as it's ready.

## Branches and handoff

- [x] `opencode/base-model-kit` (and `opencode/gore`) are in the playtest branch.
- [ ] Hand `DESIGN/MASTER_PROMPT_2026-09-26.md` Part 1 + a lane to each agent (Claude, Codex, OpenCode, Qoder, Freebuff, Qwen).
- [x] `claude/dust-to-bones-look` merged after every piece.
- [x] No more zips (Greg, 26 September: "stop making zip files, it's pointless"). `Play-Latest.bat` in the repo root pulls the newest integration branch and plays it from source.

## For Greg, the playtest

- [ ] **(Greg)** Double-click `Play-Latest.bat` in the repo folder on your PC.
- [ ] **(Greg)** F10 on, note fps in each room.
- [ ] **(Greg)** Try K and J after the brain hack.
- [ ] **(Greg)** Jump out of the drains channel.
- [ ] **(Greg)** Say what feels slow, ugly or wrong, and where.
