# The swarm: four agents, one 30-minute demo

25 September 2026. Greg: *"write me the perfect prompt to give you, to give
Coda, to give ChatGPT and to give Freebuff, to make the 30 minute game demo
... as quickly as possible. Make the hugest checklist, split it between all of
you, and make you all help each other."*

## What gets built
- `DESIGN/OPENING_TORTURE_INTAKE.md`: Greg's opening, beat by beat (the
  torture load-in, the doctor, the birthday test, the vat, customization,
  the breakout, the rooms, the X-ray).
- `DESIGN/FIRST_30_MEGA.md`: the 1,003-line checklist for the first 30
  minutes, the demo and the menus.
- `DESIGN/GOAL_LOOP_2.md`: section 0, destruction.

## Why the split is by files, not by topic
The fastest way to lose a day is two agents editing one file. So each lane
**owns** a set of files, and only that lane edits them. More agents inside a
lane is fine only if each takes a slice that touches different files; running
50 agents in the same files just produces 50 merge conflicts. File ownership
is the limit, not the agent count.

## The lanes

| Lane | Agent | Owns (edits only these) | Builds |
|---|---|---|---|
| **A** | Claude Code (this session) and integrator | `game/vat_chamber.gd`, `game/systems/vat_intake.gd`, `doctor_examination.gd`, `examiner_feed.gd`, `opening_audio.gd`, `intake_page_motion.gd`, `intake_direction.gd`, `soul_breakthrough.gd`, `mission_card.gd`, `motherboard*.gd`, new `game/systems/opening_*.gd`; tests `opening_*`, `intake_*`, `speedrun_*` | The torture load-in; the doctor at the glass; the birthday test; real-mic V; the fighting-style choice; the New Vegas intake layout; the breakout (sigil, motherboard hack, BRAIN HACKED, hands, cord, three smashes); horror lighting in the vat room |
| **B** | ChatGPT (Codex) | `game/systems/vat_body_preview.gd`, `face_model.gd`, `body_forms.gd`, `character_sheet.gd`, new `game/systems/vat_liquid.gd`, `game/shaders/vat_liquid*.gdshader`, new `game/systems/cybernetic_preview.gd`; tests `vat_body_*`, `face_*`, `body_forms_*`, `vat_liquid_*` | The big 3D vat on the right with real liquid; the torture shown on your body (wires, implant, tube, zaps with organ flashes); Bloodborne-deep face shaping; skin and clothing on Greg's textures; genitalia options; blood; cybernetics, all changing the body you see |
| **C** | Coda | `game/buried_city.gd`, `service_arcade.gd`, `old_drains.gd`, `support_unit.gd`, `blood_waterfall_exit.gd`, `doctor_vehicle_bay.gd`, `game/systems/lab_dressing.gd`, `lab_vat.gd`, `alarm_director.gd`, `facility_guard_post.gd`, new `game/systems/surveillance_camera.gd`, `game/art/models/`, `CREDITS.md`; tests for those scenes | Real models replacing every capsule "bean"; skins and props; Hitman-smart cameras (sweeps, sight cones, blind spots, feeding the alarm); Alien Isolation and Outlast lighting in the arcade, Lower Works, drains, Support Unit and doctor's bay |
| **D** | Freebuff | `game/systems/interstitial.gd`, `kill_cam.gd`, `world_xray.gd`, `xray_*.gd`, `game/boot_splash.gd`, `country_town_menu.gd`, `menu_*.gd`, `pause_gate.gd`, `demo_wall.gd`, `logo_*.gd`, `game/shaders/logo_fx.gdshader`, new `game/systems/loading_*.gd`, `game/art/sigils/`; tests `logo_*`, `menu_*`, `pause_*`, `demo_*`, `kill_cam_*`, `xray_*` | Sniper Elite 4/5-grade X-ray with full-body organs in every kill cam and cutscene; loading screens with sigil art, sacred geometry and a realistic anatomical body; the rest of the menus and settings; the demo end card |
| **Destruction** | The other Claude session (`claude/destruction-props`) | `world_break.gd`, `breakable_*.gd`, `ground_hole*.gd`, `world_debris.gd`, `world_damage.gd`, `street_light.gd` | Section 0 of `GOAL_LOOP_2.md`. Everyone else leaves these files alone |

**Shared files** (`bone_yard_hunt.gd`, `world_history.gd`,
`baseline_human.gd`, `project.godot`, `DESIGN.md`) are read-only for every
lane. A lane that needs a hook there adds at most one declaration, one
`new()` and one call, and says so on the board first.

## How the agents help each other: `DESIGN/SWARM_BOARD.md`
One file, append-only, one line per entry:
- `CLAIM <lane> <what> <files>`: before starting a slice.
- `DONE <lane> <what> <commit>`: when it's merged.
- `NEED <from lane> -> <to lane>: <what>`: when you need a change in a file
  you don't own. The owning lane does it next.
- `BROKE <lane> <test> <commit>`: when you find a failing test that isn't
  yours. The owner fixes it first, before new work.

Read the board at the start of every slice. Answer NEEDs to your lane before
starting anything new.

## Rules every lane follows
- **Branch and merge:** work on `lane-<letter>-<agent>`. Merge
  `origin/claude/dust-to-bones-look` into your branch before you start and
  before every push. Push to `claude/dust-to-bones-look` only as a
  fast-forward; if it's rejected, merge again and re-test.
- **Engine:** Godot 4.7.2, GDScript. LimboAI 1.8.1 stays. No editor bridges
  in release builds.
- **Tests:** `tools/run_tests.sh --core` green before every push, plus your
  lane's tests. A new behaviour gets one small `game/tests/<name>_test`.
- **Seen, not claimed:** render it (`--write-movie` or a capture scene),
  open the image, and describe it in the commit.
- **Assets are human-made:** CC0 or CC-BY only, from Kenney, Quaternius,
  Poly Haven, ambientCG, OpenGameArt, Freesound, itch.io free packs, or
  Sketchfab CC-BY. Credit each one in `CREDITS.md`. No generated art ships.
  Greg's textures replace placeholders when he sends them.
- **Tools:**
  - (rec, Greg hasn't answered) Higgsfield is for prototypes and reference
    only; nothing it generates ships.
  - Open-weight models (Qwen and others) are fine as coding helpers.
  - No cracked or pirated software.
- **Greg decides lore, names, placement and feel.** If a slice needs one of
  those, write the question on the board as `NEED <lane> -> GREG`, build the
  simplest neutral version behind it, and move on.
- **Stage by explicit path.** Never commit `.import` or `.uid` churn. Never
  run `git clean` without paths.
- **Report honestly:** each merge message lists the suites run, the image
  opened, and what you couldn't verify.

---

## The prompts (paste one into each agent)

### Lane A: Claude Code (this session)
> /goal Wizards Only Fools, Lane A (the opening) and integrator, per
> `DESIGN/SWARM.md`. Read `AGENTS.md`, `DESIGN.md`,
> `DESIGN/OPENING_TORTURE_INTAKE.md` and `DESIGN/SWARM_BOARD.md` first.
>
> Build beats 1-7 and 10 of the opening doc, in order:
> 1. the torture load-in
> 2. the doctor tapping the glass and appearing on the left screen
> 3. "hurry up now, I'm being watched too", with the cameras zooming in on
>    the X-ray
> 4. real-mic V through the existing `VoiceInput`, and "we own you, brain
>    chip"
> 5. the birthday test, reading `CharacterSheet.birth` back
> 6. the fighting-style choice, opening that blood tree
> 7. the New Vegas intake layout
> 8. the breakout: the sigil, the motherboard hack, BRAIN HACKED, the hands,
>    the cord, three smashes, the pour, the knees
>
> Then Alien Isolation-grade lighting in the vat room.
>
> You own only Lane A's files. Use what exists; don't rebuild it. After each
> beat: tests green, a recording looked at, merged, and a Windows build named
> `WOF-<commit>`.
>
> As integrator, after any lane merges: run the core suite, answer `BROKE`
> lines, and build. Log Greg's playtest notes to `playtests/<date>.md` and
> turn them into board lines for the right lane. Ask Greg question boxes for
> anything that's his to decide. Go.

### Lane B: ChatGPT (Codex)
> /goal Wizards Only Fools, Lane B (the vat panel and customization), per
> `DESIGN/SWARM.md`. Repo `YashicaDeth/WizardsOnlyFoolzz`; work on branch
> `lane-b-codex`, and merge into `claude/dust-to-bones-look` as the rules
> say. Read `AGENTS.md`, `DESIGN.md`, `DESIGN/OPENING_TORTURE_INTAKE.md`
> beats 8-9, and `DESIGN/SWARM_BOARD.md` first. Godot 4.7.2, GDScript.
>
> **Goal:** the intake's right panel becomes one big 3D vat with you inside
> it. Real liquid: blood, water and fluids that move, lit and refracting, at
> full frame rate. No stacked rings.
> - You're tortured in it: wires in your head, the implant, a tube in your
>   mouth, and zaps that flash your organs X-ray style.
> - Then customization as deep as Bloodborne: many face shape controls, each
>   moving only its own feature; skin and clothing on Greg's textures;
>   genitalia (none, asexual, chosen with size, and the existing blur); your
>   blood; and cybernetics.
> - Every choice visibly changes the body in the vat.
>
> **Exists (use it; don't rebuild):** `game/systems/vat_body_preview.gd`,
> `face_model.gd`, `body_forms.gd`, `character_sheet.gd`,
> `anatomy_presentation.gd`, `BaselineHuman` with organs, and the censor
> glitch.
>
> **You own only Lane B's files** (see the table). The intake screen itself
> (`vat_intake.gd`) is Lane A's: if you need a hook there, post
> `NEED B -> A` on the board.
>
> **Proof per slice:**
> - a capture of the panel, opened and described
> - one new test
> - `tools/run_tests.sh --core` green
> - a performance number: the vat panel's frame time at 1080p
>
> Human-made assets only, credited in `CREDITS.md`. Report what you couldn't
> verify. Go.

### Lane C: Coda
> /goal Wizards Only Fools, Lane C (the facility rooms, models, cameras and
> lighting), per `DESIGN/SWARM.md`. Repo `YashicaDeth/WizardsOnlyFoolzz`;
> work on branch `lane-c-coda`, and merge into `claude/dust-to-bones-look` as
> the rules say. Read `AGENTS.md`, `DESIGN.md`,
> `DESIGN/OPENING_TORTURE_INTAKE.md` beat 11, and `DESIGN/SWARM_BOARD.md`
> first. Godot 4.7.2, GDScript.
>
> **Goal:**
> - **Models:** every capsule "bean" body and placeholder prop in the Service
>   Arcade, Lower Works, old drains, Support Unit, doctor's bay and dry falls
>   becomes a real, human-made model with proper skins. Find them:
>   `grep -n CapsuleMesh` in those files.
> - **Cameras:** as smart as Hitman. They sweep, track the player, have
>   sight cones and blind spots, can be broken or looped, and report what
>   they see to `AlarmDirector`. No more static blue lights.
> - **Lighting:** Alien Isolation and Outlast. Mostly dark, small hot pools
>   of practical light, the body-cam light doing the work. Measure each room's
>   luminance and write it down.
>
> **Exists (use it; don't rebuild):** `alarm_director.gd`, `camera_hack`,
> `facility_guard_post.gd`, `lab_dressing.gd`, `lab_vat.gd`, `LabSurface`,
> `WorldLook`.
>
> **You own only Lane C's files.** Put a new camera in the vat room by
> posting `NEED C -> A`.
>
> **Assets:** CC0 or CC-BY from Kenney, Quaternius, Poly Haven, ambientCG
> or Sketchfab CC-BY, each credited in `CREDITS.md`. No generated art.
>
> **Proof per room:**
> - before and after captures, opened and described
> - one test (cameras detect, blind spots hold)
> - the core suite green
>
> Report what you couldn't verify. Go.

### Lane D: Freebuff
> /goal Wizards Only Fools, Lane D (X-ray, kill cam, loading screens and
> menus), per `DESIGN/SWARM.md`. Repo `YashicaDeth/WizardsOnlyFoolzz`; work
> on branch `lane-d-freebuff`, and merge into `claude/dust-to-bones-look` as
> the rules say. Read `AGENTS.md`, `DESIGN.md`,
> `DESIGN/OPENING_TORTURE_INTAKE.md` beat 11, `DESIGN/FIRST_30_MEGA.md`
> sections A, B and II.1-II.4, and `DESIGN/SWARM_BOARD.md` first. Godot
> 4.7.2, GDScript.
>
> **Goal:**
> - **X-ray:** as good as Sniper Elite 4 and 5, with full-body organs,
>   bones and wound paths in every kill cam and cutscene, on realistic
>   anatomy.
> - **Loading screens:** no longer "newbie". Insane sigil art, sacred
>   geometry, and a realistic anatomical X-ray body, animated.
> - **Menus:** finish the settings rows still open in
>   `DESIGN/FIRST_30_MEGA.md` B5 (subtitles, head bob, and the audio and
>   accessibility rows), a save-and-quit, and the demo end card's open
>   fields.
>
> **Exists (use it; don't rebuild):**
> - `kill_cam.gd`, `world_xray.gd`, `xray_*.gd`, `interstitial.gd`
> - `logo_fx.gdshader`, `logo_embers.gd`, `logo_audio.gd`
> - `pause_gate.gd`, `menu_blood.gd`, `menu_plate.gd`, `demo_wall.gd`
> - `BaselineHuman`'s organs, and `CellOutzType`
>
> **You own only Lane D's files.**
>
> **Assets:** sigil and sacred-geometry art drawn in code or human-made
> (CC0 or CC-BY, credited). No generated images. Greg's own art replaces
> placeholders when he sends it.
>
> **Proof per slice:**
> - a `--write-movie` clip or capture, opened and described
> - one test
> - the core suite green
>
> Report what you couldn't verify. Go.
