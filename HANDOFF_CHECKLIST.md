# Allusions to Grandeur — cold handoff

Paste this whole file to a coding model starting work on this project. It
assumes no prior conversation. Written 2026-09-11 at commit `138fe4f`.

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

Working directory: `P:\GameDev\AllusionsTooGrandeur`. It is a git repository and
**git is the handoff protocol** — commit after each increment that runs, never
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
4. **Satire targets institutions**, never a real group, a real person, or a real
   company. Conspiracy modifiers are named fictionally (NEURALACE, the mast
   tithe, the full schedule) and the joke is that *this world's* apocalypse made
   the cranks right — never a claim about ours.
5. **Verify before claiming.** Say what you actually checked and what you did
   not.

## 4. How to run things — read this or lose an hour

Godot lives at `P:\GameDev\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe`.
Always set `TEMP`/`TMP` to `P:\GameDev\Temp` first.

**Run one test:**
```
$env:ATG_TEST_MODE='1'
& <godot> --headless --path P:\GameDev\AllusionsTooGrandeur\game res://tests/<name>.tscn
```

**Capture a screen** (no `--headless`, it needs a renderer):
```
& <godot> --path P:\GameDev\AllusionsTooGrandeur\game res://tests/<name>_capture.tscn
```

### Four traps that will cost you time

1. **FMOD deadlocks headless runs.** The FMOD editor plugin is disabled but its
   GDExtension still loads every run and fights for live-update port 9264 with
   any open editor, retrying forever and starving the test's own stdout — the
   run appears to hang. Fix: rename `game/addons/fmod/fmod.gdextension` (and its
   `.uid`) to `.disabled`, and delete the fmod line from
   `game/.godot/extension_list.cfg`. **This fix cannot be committed** —
   `.gitignore` covers both paths — so a fresh checkout hits it again. With the
   extension disabled, the addon's own tool scripts fail to parse on reimport;
   that is harmless and expected.
2. **A new `class_name` is invisible to headless runs** until the class cache is
   rebuilt. After adding one, run
   `& <godot> --headless --editor --quit --path ...\game` once.
3. **GDScript infers `Variant` from dictionary and array lookups.** `var x := DICT[key]`
   and `var x := ["a","b"][i]` are parse errors under this project's warning
   settings. Write `var x: String = ...`. This has bitten roughly ten times.
4. **Two text APIs, two origins.** `CellOutzType.draw_text` places a glyph's
   **cap line** at its y and draws *down*; `draw_string` places the **baseline**
   at its y and draws *up*. Mixing them without accounting for it causes
   overlapping text, and it has caused it repeatedly. When placing body copy
   under a stencil header at `y` with cap `c`, the baseline goes at about
   `y + c + 14`.

### The workflow that actually catches bugs

**Capture the screen and look at it.** Every visual bug in this project was
found by looking at a PNG, not by reasoning about the code: a meter 170px out of
place, names printing through each other, a panel drawing nothing because it had
zero size, a part rendered at a third scale because `queue_free` is deferred and
the outgoing mesh was still being measured. Write a `tests/*_capture.gd` harness
for anything visual and read the image.

**Full suite** — 15 suites, all currently green. Run them all before claiming a
section is done:
`arsenal_test`, `baseline_human_test`, `body_motion_test`,
`combat_integration_test`, `derby_balance_test`, `gore_test`, `grapple_test`,
`impact_test`, `opening_test`, `chunk_test`, `radio_test`, `resolution_test`,
`wire_test`, `witness_test`, `sheet_test`.

## 5. The shape of the code

~18,000 lines of GDScript across 75 files, `game/systems/` is where everything
lives. The pieces you will touch most:

| File | What it is |
| --- | --- |
| `world_history.gd` | **Autoload.** Events and subjects. The world's memory. Everything persists here. |
| `baseline_human.gd` | The shared rig: zones, organs, bones, gore, severing. Every NPC and the player. |
| `anatomy_component.gd` | Zone health, blood, bleed, pain, consciousness, organs, cybernetics. |
| `gore_chunks.gd` | Identified pieces of people — layer, zone, subject, organ, implant. |
| `world_index.gd` | Four-page index: dossier, rank pyramid, Wire, body inspector. |
| `handheld_device.gd` | The device that hosts the panels. Modes, not screens. |
| `wire_net.gd` | The surviving internet: accounts, reach, replies, actions, exposure. |
| `wire_radio.gd` | Tunable radio with terrain shadow. |
| `witness_ledger.gd` | Who saw it, and what factions therefore know. |
| `character_sheet.gd` | Races, traits, chart, instrument, modifiers. |
| `arcade_vehicle.gd` | Four-wheel raycast suspension chassis. |
| `celloutz_type.gd` | The display typeface, drawn in code. Regular, condensed, worn. |
| `celloutz_grunge.gd` | Stains, spatter, stamps, grain, scratches, hatching. |
| `celloutz_motion.gd` | Named easing rates. Nothing snaps. |

**Design rules that are already load-bearing in code:**

- Connectivity is a property of *place*. `signal_field.gd` decides the Wire's
  grade from where you stand. Never pass a constant grade.
- There are two records: what happened (`WorldHistory`, true) and what is
  *known* (per faction, late, wrong). NPCs act on the second.
- Reach is not combat skill. A terrifying fighter can have no audience.
- A chunk, a carried part and a robbed implant are the same identified object.

## 6. The checklist

`CHECKLIST.md` is the working document and is driven by segment id — say `B5.2`
and build that segment. Status: `[x]` built and verified, `[~]` partial with the
remainder named, `[ ]` not started. **118 of 253 segments done.**

| Section | Done | State |
| --- | --- | --- |
| **A** — visual pass, HUD, map, driving, radio | 53/53 | **complete** |
| **B** — the body as centrepiece | 16/46 | B0–B4 and B6.1–B6.3 built; B5 open |
| **C** — the handheld | 17/21 | C1–C5 built, C3 camera open |
| **D** — character creation in the vat | 25/29 | built bar cutscenes |
| **E** — rituals, karma, the two ladders | 0/23 | designed, unbuilt |
| **F** — the Hunt System | 3/21 | F1 witnesses built |
| **G** — the look, art, sound | 0/22 | **G1 blocked on the art folder** |
| **H** — base building, reduced | 0/5 | designed, unbuilt |
| **I** — interface as its own medium | 2/23 | I0 applied to the index only |
| **J** — infrastructure | 2/10 | FMOD documented, not dropped |

### The critical path to something playable

Greg's measure: *"until it's sharper and sharper so that you can play the game."*
**All seven foundation gates are now complete.** The last gate was:

> ~~**B6.2–B6.3 — dismemberment as a combat verb.**~~ `DONE` Directional cut,
> shear and ballistic force accumulates separately from health; crossing the
> threshold takes the limb off during the fight. The NPC remains alive and
> hostile, then attacks again with anatomy-driven lower damage and a slower
> cadence. Blunt force can disable and fracture a limb but cannot detach it.

### Next most valuable after that

- **F7 — the clinch as a social verb.** Hold someone and talk: rob, abuse, or
  persuade. Four systems that already exist start talking to each other.
  Highest value per line of code in the whole list.
- **B5 — rob cybernetics off a body.** Unblocked: `GoreChunks.take()` already
  returns the identified part and `Carry` already accepts it.
- **F2/F3 — grudges travelling real edges, promotion into real vacancies.** F1
  built the substrate; the rank pyramid already displays the vacancies.
- **E1 — karma from real events.** The Ascent/Descent axis exists, is computed,
  is displayed, and drives nothing.

## 7. Open questions — only Greg can answer

1. **Where is the art folder?** Blocks all of G1 — his own art, cut up and
   glitched, as body textures, map plates and Wire collage. Largest available
   upgrade to the look and it cannot start without the files.
2. **celloutz.xyz — mirror the real site, or fictionalise it?** Blocks I3.
3. **Ephemeris or derived wheel?** The chart currently derives a house wheel
   from sun sign and birth time, which is honest and shipped. Real planetary
   longitudes need an ephemeris table and are what "most accurate" means.
4. **Guns: common, or scarce and improvised?** Built, undecided, changes
   encounter design either way.
5. **What persists between runs?** Roguelike structure was asked for, but
   "bodies remember" is a pillar. These pull against each other.
6. **Does the chassis roll?** Pitch and roll are unlocked with an anti-roll term
   and self-righting. Reversible if it plays badly.

## 8. How Greg works

He fires ideas in bursts, often faster than they can be built, and he is right
about the register far more often than not. The established protocol:

- **Capture whole rather than half-build.** A large idea gets written into a
  `DESIGN/*.md` in full, immediately, with the reasoning — then scheduled. This
  is why the design docs exist and why nothing has been lost.
- **Say what is actually wrong.** When a complaint has a different root cause
  than the one stated, say so and fix the real one. "The derby map is broken"
  was three separate complaints over two sessions; the map was never the
  problem, the car was a rigid box with no suspension.
- **Commit messages explain the why**, including what was tried and rejected.
  They are the project's reasoning log.
- **Flag a renaming rather than doing it silently.** One trait was renamed from
  his phrasing to keep the satire off a real group; that was stated plainly, the
  joke and the numbers kept.
