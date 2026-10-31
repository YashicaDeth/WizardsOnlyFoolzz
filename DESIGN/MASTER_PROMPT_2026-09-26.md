# Master prompt: the whole playtest, every lane (26 September)

Greg asked for one prompt to give every agent he runs (Claude Code in the
cloud, Codex and OpenCode on his PC, Qoder, Freebuff, Qwen through OmniRoute).
Together they should produce **one playable playtest where everything works**:
performance, gore, every system on the checklist, and the Dust to Bones spine,
with every plugin and the Higgsfield work in. He also asked for **no more zip
files**, and for **question boxes**.

Paste **Part 1** into every agent, then give each agent **its own lane** from
Part 2. Part 3 is the question set: each agent asks Greg the questions for its
lane as question boxes *before* choosing any of those things itself.

---

## Part 1: paste into every agent

```text
You are one of several agents building WIZARDS ONLY FOOLS, a Godot 4.7.2
GDScript horror game (repo YashicaDeth/WizardsOnlyFoolzz). The owner is Greg.
The goal is ONE PLAYABLE PLAYTEST OF THE FIRST 30 MINUTES WHERE EVERYTHING
WORKS: the Dust to Bones spine from the vat to the surface, gore, K/J vision,
jump and climb, the Hunt, at a steady 60+ fps on Greg's RTX (he reads about
160 fps now; do not lose that).

READ FIRST, IN THIS ORDER, AND OBEY THEM:
  AGENTS.md
  DESIGN.md                            (Greg's decisions; his words win)
  DESIGN/CHECKLIST_2026-09-26.md       (what is done, what is open)
  DESIGN/MASTER_PROMPT_2026-09-26.md   (this file: your lane, your questions)
  .claude/skills/goal/SKILL.md         (the work queue and what "done" means)
  .claude/skills/wof-lane-hygiene/SKILL.md      before any edit or commit
  .claude/skills/wof-wire-before-polish/SKILL.md before improving any system
  .claude/skills/wof-verify-by-looking/SKILL.md  for anything visual
  .claude/skills/wof-combat-fx/SKILL.md          for any fighting visual/sound
  .claude/skills/wof-agent-brief/SKILL.md        if you hand work to anyone

HOW TO WORK
- Work only in your lane's files (Part 2). Other files are read-only, except
  shared files, where you may add at most a declaration, a new() and one call.
- Own git worktree and branch: <tool>/<lane>, e.g. codex/hunt-tests.
  Stage files by explicit path. Never `git add -A`, never commit .import or
  .uid churn, never `git clean` without paths, never force-push a shared
  branch. Merge into claude/dust-to-bones-look only when your tests are green.
- Before building anything, search for it. Most systems already exist;
  wire the existing one instead of writing a second.
- Keep dependencies pinned. Editor bridges (godot_mcp) never go into release
  builds. No cracked or pirated software. Greg's own art is never overwritten.
  Every generated asset is logged in game/art/GENERATED.md.
- Performance is a rule, not a phase: no per-frame find_children, allocations
  or node-tree walks; bookkeeping at a few Hz, not 60; new round meshes go
  through MeshBudget (systems/mesh_budget.gd); screen shaders sleep when off.

QUESTIONS (Greg asked for them)
- Anything in Part 3 for your lane is Greg's call. Ask it as a question box
  (AskUserQuestion or your tool's equivalent), recommended option first,
  labelled "(Recommended)", at least the set listed for your lane, before you
  build that part. Record every answer in DESIGN.md in his words.
- If you meet a new design decision, stop and ask it as a box too. Never
  invent lore, names or rules to unblock yourself.

PROOF, OR IT DID NOT HAPPEN
- A player can do it in the real route, not only in a test scene.
- It writes a record (WorldHistory / PlayerActionLedger event).
- One new small test in game/tests/<name>_test.gd/.tscn printing
  <NAME>_RESULT failures=N, run headless:
    ATG_TEST_MODE=1 godot --headless --path game res://tests/<name>_test.tscn
- Anything visual: render it, open the PNG, and say what you saw.
- Before merging, run your lane's suites (Part 2). If a test fails, check
  whether it also fails on the base commit before you touch it; if it does,
  it is pre-existing: list it, don't hide it, don't disable it.

NO ZIP FILES
Greg plays with Play-Latest.bat in the repo root. It pulls
claude/dust-to-bones-look into P:\GameDev\playtest and runs it from source.
So "sending a build" means: merge green work into claude/dust-to-bones-look
and push. Do not make or send zips, split parts or exe bundles unless Greg
asks for one.

REPORT BACK (every time you stop)
1. What a player can now do, and the key to press.
2. Suites run and their results; the PNGs you opened.
3. What you could not verify, and pre-existing failures you met.
4. The questions Greg answered, and where you recorded them.
```

---

## Part 2: the lanes (one agent each, split by files)

Run these in parallel. Where two lanes list the same file, the second waits
for the first to merge.

### Lane A: the opening spine (Claude Code, cloud)

- **Goal:** the vat room to the surface plays start to finish with nothing
  skipped: intake, brain hack, breakout, Support Unit, drains, Service
  Arcade, Lower Works, Hunt.
- **Exists:**
  - `vat_chamber.gd`, `support_unit.gd`, `old_drains.gd`, `service_arcade.gd`, `buried_city.gd`
  - `systems/signal_sight.gd` (K/J), `systems/jump_climb.gd`, `systems/brain_hack.gd`
  - The weak wall (`weak_wall_test`)
- **Owns:** those scene scripts, `systems/signal_sight.gd`, `systems/jump_climb.gd`, `shaders/signal_sight.gdshader`.
- **Open work:**
  - Wires and power in wizard eyes.
  - Signals in the phone camera. This touches the Hunt's handheld, so wait for Lane B.
  - More hidden things (stashes, secret doors).
  - The darker vat room: red only in the glow. Ask the HouseLook owner first.
  - Every opening overlay in the real route.
  - A timed 0-30 minute run.
- **Suites:** `vat_*`, `opening_*`, `support_*`, `old_drains_*`, `service_arcade_*`, `lower_works_*`, `signal_sight_test`, `jump_climb_test`, `weak_wall_test`, `first_thirty_route_test`, `doctor_route_test`, `brain_hack_test`, `torture_load_in_test`.

### Lane B: the Hunt, broken tests first (Codex on Greg's PC)

- **Goal:** the Hunt's own test suite is green.
- **Fix these, each already failing before 26 September:**
  - `grapple_playability_test`: parse error, `released_from` declared twice.
  - `standing_contact_test`: the talk panel's `close()` and `_close_talk_panel()` call each other forever.
  - `vault_test`: a 0.8 m box within reach is not found.
  - `firearm_aim_test`: RMB commits a heavy melee swing with no firearm equipped.
  - `handheld_world_drop_test`: the deliberate drop is refused.
  - `handheld_world_light_test`: the map's exposure doesn't widen the beam.
  - `melee_cut_plane_test`: the player doesn't wake in the humiliation rig.
- **Then the performance leftovers:**
  - `_update_encounter_actors` costs 1.3 ms.
  - The HUD redraws every frame (0.6 ms).
  - 98 lights: distance-cull them.
  - Idle physics pairs.
- **Owns:** `bone_yard_hunt.gd` and the Hunt-only systems these tests name.
- **Suites:** every test that loads `bone_yard_hunt.tscn` (116 of them). Fix the root cause each time; never skip a test.

### Lane C: gore, end to end (OpenCode on Greg's PC)

- **Goal:** gore works the same in the Gore Sandbox, the vat room, the Support Unit and the Hunt.
  - Blades and bullets cut.
  - Limbs come off as chunks.
  - Organs, wound marks and blood flow, pool and veil.
  - Hitstop.
- **Exists:**
  - `systems/gore_chunks.gd`, `wound_catalog.gd`, `wound_marks.gd`
  - `blood_flow.gd`, `blood_pool.gd`, `blood_veil.gd`, `blood_ledger.gd`, `blood_trees.gd`
  - `gore_demo.gd`
  - About 25 gore and blood tests, all passing on 26 September.
  - `gore_load_test` is a load benchmark; it times out headless, so run it on the PC.
- **Owns:** the gore and blood systems above and `gore_demo.gd`. Hook into scenes only through their existing hit or damage call, one line each.
- **Also:** merge `opencode/base-model-kit` if it still exists.
- **Suites:** `gore_*`, `blood_*`, `wound_*`, `chunk_test`, `organ_*`.

### Lane D: art, Higgsfield and plugins (Qoder / Freebuff / Qwen via OmniRoute)

- **Goal:** placeholder art in every category, curated rather than generic, until Greg's own art lands:
  - breakout frames
  - loading screens
  - the phone and the Wire
  - kill-cam X-rays
- **Exists:**
  - `tools/Import-Higgsfield.ps1`, which copies Greg's Higgsfield downloads onto their own branch.
  - `DESIGN/HIGGSFIELD_ROADMAP.md`, `DESIGN/LOOK_FROM_CONCEPTS.md`, `game/art/GENERATED.md`
- **Owns:** `game/art/**`, `tools/**`, the art-loading lines of each screen's script.
- **Rules:**
  - Media goes through Git LFS. Never convert formats to dodge LFS.
  - Log every piece in `GENERATED.md`.
  - Pick distinct pieces "with a grain of salt": Greg likes a lot and dislikes a lot. Ask.
- **Plugins:** confirm each one loads in the editor and stays pinned:
  - `dialogue_manager`, `proton_scatter`, `gdUnit4` (editor/tests only)
  - LimboAI (GDExtension, shipped in builds)
  - `terrain_3d`: enabled in `project.godot` but its folder is not in the repo. Restore it pinned or remove the entry; ask Greg which.
  - `godot_mcp` stays editor-only.

### Lane E: the playtest itself (whoever finishes first)

- **Goal:** Greg double-clicks `Play-Latest.bat` and plays 0-30 minutes with no crash, no dead end, no skybox fall and no soft-lock.
- **How:**
  - Walk the route in the engine.
  - Capture a PNG at each beat.
  - List every break you meet and hand each one to the owning lane.
  - Update `DESIGN/CHECKLIST_2026-09-26.md` ticks, with proof.

---

## Part 3: the questions (ask as boxes, recommended first)

Each lane asks its own set before building those parts. **(R)** is the
recommendation.

### Opening and vision (Lane A)

1. **Where should the weak wall's crawlway lead?** Past the arcade gate (R, built) / straight to Lower Works / a hidden loot room / behind the Support Unit guards.
2. **How do wires and power look in wizard eyes?** Glowing lines along the conduits, pulsing toward what they feed (R) / sparks at junctions only / colour by what they power.
3. **What can you do with a wire once you see it?** Cut it to kill a light or camera (R) / follow it to a hidden door / information only / overload it to hurt people.
4. **How does the phone camera show signals?** The same rings on the phone screen (R) / only in its depth mode / as audio static.
5. **Strain: 22 seconds to a full nosebleed. Change it?** Keep 22 s (R) / faster (12 s) / slower (40 s) / no strain.
6. **What's in stashes?** Meds and ammo (R) / lore notes / blood currency / cosmetics.
7. **How do secret doors open once seen?** E (R) / a tool / a small puzzle / break them with a weapon.
8. **How many hidden things in the first 30 minutes?** 5-8 (R) / 2-3 / 10+ / one per room.
9. **Hints for plain eyes?** A faint hint, like a draught or a crack (R) / totally invisible / obvious.
10. **How dark is the vat room?** Only the vat glow and your body-cam lamp (R) / dim strip lights / pitch black.
11. **Which red for the vat glow?** Deep blood (R) / orange-red / magenta.
12. **Film grain and look strength?** Keep as is (R) / more / less.

### Movement (Lane A)

13. **Climb height (now 1.55 m)?** Keep (R) / 2 m+ with a pull-up animation / lower.
14. **Sprint in the vat room?** No, the body is fresh out of the tank (R) / yes.
15. **A crouch-slide?** No (R) / yes.
16. **Fall damage?** None (R) / small / can kill.

### The Hunt (Lane B)

17. **The Brain Index hub key (now Shift+Tab)?** Keep Shift+Tab (R) / backtick (`) / only from the phone.
18. **Should Hunt guards notice K and J?** Only hacked cameras notice (R, current) / implanted guards too / everyone nearby.
19. **The seven broken Hunt tests: fix before any new feature?** Yes (R) / alongside new work.
20. **What does re-decant cost?** Current: the tar keeps some items (R) / more / less.

### Gore (Lane C)

21. **Gore level default?** Full (R) / reduced / off with a toggle.
22. **Should severed limbs stay in the world?** Yes, up to a cap, oldest removed first (R) / forever / fade after a minute.
23. **Hitstop strength?** Current (R) / heavier / lighter.
24. **Gore in the vat room tanks too?** Yes (R) / Hunt and sandbox only.

### Art, plugins and sound (Lane D)

25. **How do Higgsfield files get in?** Allow `lfs.github.com` in the cloud environment (R) / Greg runs `tools\Import-Higgsfield.ps1` / skip art for now.
26. **Which placeholder category goes first?** Loading screens (R) / breakout frames / phone and the Wire / kill-cam X-rays.
27. **terrain_3d: restore it or drop it?** Restore, pinned (R) / remove from `project.godot`.
28. **Sound for wizard eyes?** A low choir hum (R) / static / a heartbeat / none.
29. **Sound for the depth scan?** A sonar ping (R) / a hum / none.
30. **Sound and effect for the weak wall breaking?** A plaster crumble with a dust puff (R) / a heavy thud / silence.

### Process (every lane)

31. **How often should work merge into the playtest branch?** After every finished piece (R) / once a day / only when Greg asks.
32. **What should Greg get when something lands?** A one-line message saying what to press (R) / a full report / nothing until he asks.
33. **Question boxes: when?** Before each new piece (R) / at the start of each session / only when blocked.
34. **The checklist: keep the markdown file?** Keep it (R) / a live web page Greg can tick.

---

## What this prompt cannot do by itself

The other tools are not connected to this cloud session. Greg has to paste
Part 1 plus a lane into each of them. None of them can push media until LFS
is reachable (question 25). And no agent here can see Greg's screen: his F10
and his notes are the real playtest.
