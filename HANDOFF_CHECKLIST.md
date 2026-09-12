# Wizards Only Fools — cold handoff

Paste this whole file to a coding model starting work on this project. It
assumes no prior conversation. Rewritten 2026-09-12.

**Branch `codex/b6-combat`, worktree
`C:\Users\Greg\Documents\ChatGPT\AllusionsTooGrandeur Game\codex-b6-worktree`.**
Sixteen commits ahead of `codex/game-planning`. Everything below is committed
and the tree is clean.

---

## 1. What this is

A dense, violent, surreal living-world sandbox in **Godot 4.7.2**, solo-developed
by Greg, who owns art direction, world, narrative and every final decision. You
are an engineering partner. Offer a creative opinion once, clearly, then build
what he decides.

Not open-world-large — small, interconnected, heavy with consequence. Closer to
Kenshi or Fallout than GTA. **The world existed before the player and remembers
what the player does to it.**

Central motif: **AS ABOVE, SO BELOW.** An ascending realm and a descending realm
flank the playable middle world, Limbo. First region: **The Ashbloom Expanse**, a
post-nuclear Australian wasteland of runaway fungal ecology, decayed cybernetics,
raider roads and buried anatomical industry.

The opening as built: the player wakes submerged in a vat, is decanted onto wet
grating already injured, and is racked into a car for a demolition heat they must
win to clear a debt that is "in the meat."

Tone: grimy, crude, darkly funny. Postal 2's deadpan and early South Park's
bluntness, with Cruelty Squad's body modification and Wrought Flesh's
organ-forward biopunk. A disembowelling and a petty argument about parking in the
same thirty seconds. **Satire aims at institutions and power, never at real
groups of people.**

**Git is the handoff protocol.** Commit after each increment that runs; never
leave the tree uncommitted between sessions.

## 2. Read these first

`AGENTS.md`, `AGENT_BRIEF.md`, `ROADMAP.md`, `DESIGN.md`, `ART-DIRECTION.md`,
`CHECKLIST.md`, and in `DESIGN/`: `HUNT_SYSTEM.md`, `FACTIONS.md`,
`IN_GAME_INTERNET.md`, `INTERFACE_DIRECTION.md`, `CHARACTER_CREATION.md`,
`RITUAL_AND_KARMA.md`.

## 3. Non-negotiables

1. **Originality over imitation.** Every named reference — Shadow of Mordor's
   Nemesis system especially — is a *register* to hit, never a thing to
   reproduce. Warner Bros holds US Patent 10,926,179 on the Nemesis System, in
   force into the mid-2030s. `DESIGN/HUNT_SYSTEM.md` is an entire document about
   building the same *experience* from six original mechanisms. Do not read
   commercial game source; do not reproduce another game's UI or code.
2. **No screen is a list of text in a box.** If a screen's information could be
   a spreadsheet, it is not finished. This is rule I0 and it is absolute.
3. **Every hard cut is a bug.** Panels arrive and leave; pages ease; parts leave
   diagrams rather than opening windows.
4. **Satire targets institutions**, never a real group, person or company.
5. **Verify before claiming.** Say what you actually checked and what you did
   not.
6. **Greg's artwork is read-only.** The collection lives at
   `C:\Users\Greg\Desktop\Art Collections`. Never write to it. Derived textures
   go to `game/art/derived/` and are rebuildable.

## 4. How to run things — read this or lose an hour

Godot lives at `P:\GameDev\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe`.
Always set `TEMP`/`TMP` to `P:\GameDev\Temp` first.

**Run one test:**
```
$env:ATG_TEST_MODE='1'
& <godot> --headless --path <worktree>\game res://tests/<name>.tscn
```

**Capture a screen** (no `--headless`, it needs a renderer):
```
& <godot> --path <worktree>\game res://tests/<name>_capture.tscn
```

### Traps that will cost you time

1. **A new `class_name` is invisible to headless runs** until the class cache is
   rebuilt. After adding one, run
   `& <godot> --headless --editor --quit --path ...\game` once.
2. **GDScript infers `Variant` from dictionary, array and `load()` results.**
   `var x := DICT[key]` and `var x := load(p).instantiate()` are parse errors
   under this project's warning settings. Write `var x: String = ...`.
3. **Two text APIs, two origins.** `CellOutzType.draw_text` places a glyph's
   **cap line** at its y and draws *down*; `draw_string` places the **baseline**
   at its y and draws *up*. Mixing them causes overlapping text.
4. **`queue_free()` is deferred.** A node freed this frame still answers
   `get_node_or_null()`. Use `remove_child()` first when the removal must be
   visible immediately.
5. **A self-rescheduling lambda captures by value.** `var f: Callable; f = func():
   ... connect(f)` closes over `f`'s pre-assignment null, so every reconnect
   after the first silently does nothing. Use an `await` loop instead.
6. **`godot_mcp` and `fmod` are gitignored**, so a fresh worktree has neither.
   The missing `MCPGameBridge` autoload errors on every run here and is harmless
   — do **not** remove it from `project.godot`, it works in Greg's main checkout.
7. **A script error means the test never reaches `get_tree().quit()`** and the
   process spins forever. If a run hangs, look for a SCRIPT ERROR above it and
   kill stray `Godot_v4.7.2*` processes.

### The workflow that actually catches bugs

**Capture the screen and look at it.** Every visual bug in this project was
found by reading a PNG, not by reasoning about code — including, this session, a
blood splat three metres wide that 23 green suites never noticed. Write a
`tests/*_capture.gd` harness for anything visual.

**Full suite — 24 suites, all currently green.** Run them all before claiming a
section is done:
`arsenal_test`, `baseline_human_test`, `body_motion_test`,
`combat_integration_test`, `derby_balance_test`, `gore_test`, `grapple_test`,
`impact_test`, `opening_test`, `chunk_test`, `radio_test`, `resolution_test`,
`wire_test`, `witness_test`, `sheet_test`, `icon_test`, `body_inspector_test`,
`extraction_test`, `karma_test`, `clinch_test`, `propagation_test`,
`world_xray_test`, `camera_test`, `intake_direction_test`.

## 5. The shape of the code

`game/systems/` is where everything lives. The pieces you will touch most:

| File | What it is |
| --- | --- |
| `world_history.gd` | **Autoload.** Events, subjects, karma. The world's memory. `record_event` is news; `amend_subject` is a belief changing and records nothing. |
| `baseline_human.gd` | The shared rig: zones, organs, bones, gore, severing, build factor, X-ray. Every NPC and the player. |
| `anatomy_component.gd` | Zone health, blood, bleed, pain, consciousness, organs, implants. |
| `gore_chunks.gd` | Identified pieces of people — layer, zone, subject, organ, implant, rot. |
| `extraction.gd` | B5. Digging a part out of a body: depth, tool, condition, lien. |
| `clinch.gd` | F7. What a held person will give you. Descent coerces, Ascent persuades. |
| `witness_ledger.gd` | F1/F2. Who saw it, what factions learn, and how it travels the relation graph. |
| `field_camera.gd` | C3. Photographs as evidence with verifiable contents. |
| `world_xray.gd` | B3. The X-ray sweep in the world, through walls, at range. |
| `intake_direction.gd` | D3.4/D8.3. How the intake is delivered and what signing costs. |
| `world_index.gd` | The index: dossier, rank pyramid, Wire, body inspector. |
| `handheld_device.gd` | The device that hosts the panels. Modes, not screens. |
| `wire_net.gd` | The surviving internet: accounts, reach, actions, photograph publishing. |
| `carry.gd` | What you are carrying, with mass, spoilage, lien and install-into-self. |
| `implant_catalog.gd` / `wound_catalog.gd` | Authored hardware and wounds. Names are identities, never parsed. |
| `celloutz_type.gd` / `_grunge.gd` / `_motion.gd` | The display face, the dirt, the easing. Nothing snaps. |

**Design rules already load-bearing in code:**

- Connectivity is a property of *place*. `signal_field.gd` decides the Wire's
  grade from where you stand. Never pass a constant grade.
- There are two records: what happened (`WorldHistory`, true) and what is
  *known* (per faction, late, wrong). NPCs act on the second.
- Reach is not combat skill. A terrifying fighter can have no audience.
- A chunk, a carried part and a robbed implant are the same identified object.
- **Harm is defined once**: `WorldHistory.event_karma()` is both what moves you
  on the Tree and what the world holds against you. Do not add a second table.

## 6. Where the checklist stands

**163 of 253 segments.** `CHECKLIST.md` is the working document, driven by
segment id — say `E1.2` and build that segment.

| Section | Done | State |
| --- | --- | --- |
| **A** — visual pass, HUD, map, driving, radio | 53/53 | **complete** |
| **B** — the body as centrepiece | 46/46 | **complete** |
| **C** — the handheld | 21/21 | **complete** |
| **D** — character creation in the vat | 28/29 | complete bar D5.4 (Greg's call) |
| **E** — rituals, karma, the two ladders | 1/23 | E1.1 built; the rest designed |
| **F** — the Hunt System | 10/21 | F1, F2, F7 built |
| **G** — the look, art, sound | 2/22 | G1.1/G1.2 built, G1.3–1.5 assets exist unwired |
| **H** — base building, reduced | 0/5 | designed, unbuilt |
| **I** — interface as its own medium | 2/23 | I0 applied to the index only |
| **J** — infrastructure | 2/10 | FMOD documented, not dropped |

### Cheapest high-value work remaining

1. **E1.2 — factions price you by where you sit.** `FACTION_TREE_AXIS` already
   holds every faction's own position on the axis and `tree_alignment()` already
   returns yours; pricing is comparing the two. Perhaps 40 lines.
2. **F3 — promotion into real vacancies.** The rank pyramid already draws
   vacancies *and* computes who is positioned to fill one (A3.2, A3.3). A death
   needs to trigger that machinery.
3. **G1.3–G1.5 — wire the textures in.** The sheets exist in
   `game/art/derived/`; no material or panel loads them yet.
4. **F4.3 — the wound as the memory.** The rig already persists wounds and Mara
   already carries `next_adaptation`.

### Genuinely expensive

**E2** (72 Goetic seals drawn in code), **E6** (drugs, minigames, economy),
**I2** (per-site web layouts) and the rest of **G** are each multi-session.

## 7. Controls as they now stand

WASD move, Shift sprint, Ctrl crouch, Space dodge (or break a clinch), LMB
strike, RMB heavy, 1–3 weapons, 4 carried limb, R reload, F camera toggle,
G handheld, Tab index/mode, M map, T tree, J artwork, Z lock, C clinch,
E interact, **H dig/rob (hold)**, **B X-ray sweep (hold → radial)**,
**N photograph**, **V talk in a clinch**, **X lean in a clinch**, Q surge.

> **Check `_unhandled_input` before adding a key.** `KEY_F` was bound twice for
> a whole session; the first branch wins in a `match`, so the entire B5 dig was
> unreachable from the keyboard while every test passed, because tests call the
> functions directly. `world_xray_test` now fails on any duplicate binding.

## 8. Open questions — only Greg can answer

1. **D5.4 — ephemeris or derived wheel?** The honest derived wheel is shipped.
   Real planetary longitudes need a table.
2. **celloutz.xyz — mirror the real site, or fictionalise it?** Blocks I3.
3. **Guns: common, or scarce and improvised?** Built, undecided.
4. **What persists between runs?** Roguelike structure was asked for, but
   "bodies remember" is a pillar. These pull against each other.
5. ~~**Working title:** keep *Allusions to Grandeur*, or move to
   **wizardsonlyfoolz**?~~ **Answered 2026-09-12** — Greg calls it **Wizards
   Only Fools**. In-game title cards and `config/name` updated; the repo path,
   folder names and save-data identifiers keep the old name.
6. ~~Where is the art folder?~~ **Answered 2026-09-12** — `Desktop/Art
   Collections`, 43 artworks, catalogued.

## 9. How Greg works

He fires ideas in bursts, often faster than they can be built, and he is right
about the register far more often than not. The established protocol:

- **Capture whole rather than half-build.** A large idea gets written into a
  `DESIGN/*.md` in full, immediately, with the reasoning — then scheduled.
- **One segment at a time.** Say a segment id, build it, test it, commit it.
  Large "do everything" prompts produce shallow work that does not run; every
  good increment in this project came from the segment loop.
- **Say what is actually wrong.** When a complaint has a different root cause
  than the one stated, say so and fix the real one. "The derby map is broken"
  was three complaints over two sessions; the map was never the problem, the car
  was a rigid box with no suspension. Likewise "the sound is blaring" was not a
  mix problem — the radio had no stop path at all and had never been switchable.
- **Commit messages explain the why**, including what was tried and rejected.
  They are the project's reasoning log.
- **Flag a renaming rather than doing it silently.**
