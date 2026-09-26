# The checklist, 26 September

Greg asked for "a checklist with heaps of boxes". It covers everything open
across the first thirty minutes, as of build `perf` (the commit after
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
- [ ] **(Greg)** Press F10 in the build and read the FPS in the vat room, Support Unit, drains and Hunt.
- [ ] **(Greg)** Press F11 anywhere it drops under 60 and send the dump file next to the exe.
- [ ] **(Greg)** Check whether VSync is on in Settings. VSync locks fps to your monitor's refresh (60, 144 or 165).
- [ ] **(Greg)** Tell me your GPU and monitor refresh rate.
- [ ] Merge the vat room's static props into fewer draw calls (1,146). Parked until Greg's F10 numbers: each prop's material is deliberately unique, so merging changes the look, and 1,146 calls is about 1 ms on a real GPU.
- [ ] Hunt: `_update_encounter_actors` is now the biggest script cost (1.3 ms).
- [ ] Hunt HUD redraw (0.6 ms) should only redraw on change.
- [ ] Hunt: 98 lights. Cull the far ones by distance.
- [ ] Hunt physics server: 184 collision pairs, 144 islands. Find the idle ones.
- [ ] A real-GPU benchmark on Greg's PC (the cloud renders on the CPU, so absolute fps here means nothing).
- [ ] Fix `standing_contact_test`: the talk panel's close calls itself forever (it already failed before this pass).
- [ ] Make `sandbox_perf_test` skip itself headless instead of reporting a false failure.

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
- [ ] The examiner model from the M1 sheet.
- [ ] Real-mic V, the New Vegas intake (from the opening vision).
- [ ] Vat room darker, red only in the glow (coordinate with the HouseLook lane).
- [ ] Every opening overlay tested in the real route, not only in the test scenes.
- [ ] A timed run through minutes 0 to 30 with nothing skipped.

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
- [ ] The Hunt: K/J wired.
- [ ] Hunt keys: inventory to Tab.
- [ ] Hunt keys: re-decant to hold-K.
- [ ] The phone camera vision shows signals too.
- [ ] Wires and power shown in wizard eyes.
- [ ] Hidden things shown in wizard eyes.
- [ ] The weak wall in the Growing Floor, revealed by wizard eyes, as a shortcut.
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

- [ ] Merge `opencode/base-model-kit` once OpenCode pushes it.
- [ ] Keep `claude/dust-to-bones-look` merged after every piece.
- [ ] A Windows build after every piece, each with a PLAY bat.

## For Greg, the playtest

- [ ] **(Greg)** Run the newest `PLAY-<hash>.bat`.
- [ ] **(Greg)** F10 on, note fps in each room.
- [ ] **(Greg)** Try K and J after the brain hack.
- [ ] **(Greg)** Jump out of the drains channel.
- [ ] **(Greg)** Say what feels slow, ugly or wrong, and where.
