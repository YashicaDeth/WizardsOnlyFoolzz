# Roadmap

## How this project is worked

Greg owns art direction, world, taste and every final decision. AI agents are
engineering partners, per the Master Codex Handoff §26.

**Git is now the handoff protocol.** The repository sat at zero commits while
three divergent copies of the same scripts accumulated in an older workspace.
That is the failure mode to avoid: two agents editing the same tree with no
history, and no way to tell current work from abandoned work. Rules that follow
from it:

- Commit after each increment that runs. Never leave a working tree uncommitted
  between agent sessions.
- One agent in the tree at a time. Before handing to another agent, commit.
- `P:\GameDev\AllusionsTooGrandeur` is the only source of truth. The
  `C:\Users\Greg\Documents\ChatGPT\AllusionsTooGrandeur Game` copy is superseded
  and should not be edited.
- Verify before claiming. `--headless --quit-after` runs catch runtime errors;
  say what was actually checked and what was not.

**Picking up interrupted work.** The prior agent stopped mid-task on the vehicle
physics rework: the player chassis was converted to force-based rigid-body
control, the AI cars were not. Recovering that required reading the chassis
docstring against the AI update loop, not re-deriving the design. Unfinished
handoffs should be recorded here, in this file, at the point they are dropped.

## Current milestone

World Zero foundations. In fiction the first region is **The Ashbloom Expanse**,
inside the wasteland realm **Limbo**: the Bone Yard derby opens into a
post-nuclear Australian landscape of runaway fungal ecology, decayed
cybernetics, raider roads, stalker territories and buried anatomical industry.

### Implemented foundation

- Persistent universal event/history store with save-safe subject migration.
- Mara Voss's continuing rival state, injury, grudge, ELO and encounter memory.
- Faction/character seed population: Ashline Wreckers, Black Mile, Soft Rot
  Communion, Choir of Marrow, and the ascending Gate Lanterns.
- Zoomable Living Kinship Web with Vessel / Deep X-ray dossiers.
- Tree of Life axis on the X-ray scan: the anatomy view doubles as an
  as-above-so-below reading, with faction Sin-pulls and personal bond/grudge
  drift deciding where a subject sits between Ascent and Descent.
- Deterministic Ashbloom districts, 40+ enterable shells, 18 Reality Misfires.
- Anatomy component: zone health, blood volume, bleed rate, pain,
  consciousness, treatment, limb disability, persistent snapshots.
- Hostile escape behaviour, loot caches, collision-aware hunter, dodge, melee.
- Authored Bone Yard environment kit (233 meshes) with selective collision.
- Physical AI wreckers on the player's chassis, and the shared `WorldLook`
  environment/material system.

## Sequenced backlog

Ordered so each tier makes the next one look and feel better. Their own §30
rule applies: one system at a time, proven in gameplay.

### Tier 1 — make the core loop feel good

Nothing else is worth polishing until a ram feels like a ram.

1. **Sound rework.** Every player is currently non-positional
   `AudioStreamPlayer`, so engine, impacts, crowd and wind all play flat
   regardless of location. Move to `AudioStreamPlayer3D` with attenuation and
   a reverb bus for the quarry; layer engine by load rather than pitching one
   sine; separate impact layers by severity and material (panel, glass, meat).
   Do not block this on FMOD — see plugin strategy below.
2. **Gore and the ram payoff.** Front-end destruction that escalates to
   crushing the driver inside the cab: frontal high-speed impacts after the
   bumper and hood have shed should kill and gore the driver, with the death
   written into world history like any other. Ragdoll response on detached
   parts and bodies. Postal 2 excess, Wrought Flesh/Kenshi biopunk interiors.
3. **Driving feel.** Now that impacts persist: weight transfer, tire slip,
   speed-linked camera shake and FOV, brake/scrape effects, and a decision on
   whether the upright angular lock stays (it currently prevents rolling).

### Tier 1a — impact feel, added 2026-09-11, **completed 2026-09-11**

Cars ground into each other at near-zero speed and stayed there, draining every
collision of meaning. Three causes, all in `arcade_vehicle.gd`, all fixed:

- **Grip was eating the hit.** The lateral tire force was an uncapped spring —
  a car T-boned at 8 m/s generated 40 m/s² of counter-force and cancelled the
  knock inside one frame. Grip is now a friction limit. This was the single
  biggest cause and was not the one originally diagnosed here.
- **Sustained drive turned contact into a shove**, so restitution never acted.
  Drive and steering are now cut briefly on impact.
- **Nothing broke a stalemate.** Two cars leaning on each other never reach the
  impact threshold. A continuous repulsion force does not fix this — the drive
  servo out-pushes it and re-closes the gap. After a sustained press the pair is
  now kicked apart as a discrete event with a slew, so they part and re-engage
  as a scored blow.
- **Destruction scales with the square of closing speed**, so a committed ram
  strips panels on the first contact. Impacts also carry a `self_share` so the
  car that drove into the other wears the damage.
- **No reset key.** Per Greg's play test, a wedged car backs itself out and the
  heat resolves on a count rather than waiting on ENTER.

Covered by `tests/impact_test.gd` (10 checks). Note the bounds are part of the
contract: separation is asserted from both sides so a later tune cannot quietly
turn the pit into pinball.

### Tier 1a-next — captured from Greg 2026-09-11

Fired mid-session, recorded here rather than half-built.

- **Guns.** Ranged weapons alongside the melee work in Tier 1b — currently
  nowhere in this plan. Needs a decision on whether firearms are common enough
  to change encounter design, or scarce, jamming and mostly improvised, which
  fits a world where nothing is new. Ammunition is an economy item either way.
- **One baseline human model for every NPC.** This is the prerequisite hiding
  underneath the gore, prosthetic and voice-chat ambitions: every person in the
  world built from a single rig with the same named zones, so
  `anatomy_component.gd` injuries, organ damage, amputation and limb
  replacement apply universally instead of per-character. Without it, "bodies
  remember" only works on hand-authored characters, and proximity voice has
  nothing consistent to attach a speaking head to. Schedule this before Tier
  1b.13 rather than after.

### Tier 1b — combat, added 2026-09-11

10. **Physical melee.** Half Sword's register — momentum-driven swings, real
    contact, unglamorous brutality and heavy dismemberment — but it has to
    actually *work*, which Half Sword's first-person control notably does not.
    Swing direction and force from input, weapon mass and reach mattering,
    contact resolved against the anatomy zones that already exist.
11. **Dodge and roll.** DS3/Elden Ring vocabulary — i-frames, stamina cost,
    directional commitment — with more player control than either: cancel
    windows, shorter recovery, and a step distinct from a full roll.
12. **Seamless first/third person.** Not a camera toggle. Per Codex §19 the
    perspective carries meaning: first person is Self/Perception, third is
    Body/Spatial. The transition should be continuous, and combat must be fully
    usable in both.
13. **Weapons, limbs and organ upgrades.** HAVKER-MAN X-style bionics and
    Cruelty Squad implants, but far more customisable. Every weapon, limb and
    organ is a distinct part with its own trade-offs, compatibility and social
    reading, feeding `anatomy_component.gd`'s existing cybernetics slots and the
    prosthetic economy in `DESIGN/HUNT_SYSTEM.md`.

### Tier 1c — the inspection interface, added 2026-09-11

The dossier and the vehicle readout become one interaction pattern: a schematic
you can point at, where the hovered part lifts out of the diagram as a real 3D
object turning in place.

- Hovering a zone on the body diagram pops that part — organ, limb, bone — out
  of the flat schematic into a small 3D viewport beside it, rotating slowly,
  showing its real condition from `anatomy_component.gd`.
- The same pattern serves the car: hover a panel on the hull schematic and that
  part lifts out as a turning 3D component with its own damage state.
- The transition between flat diagram and popped 3D part is the interaction, so
  it must be continuous — the part appears to leave the diagram, not to open a
  window. No hard cuts, no separate modal.
- This unifies the X-ray dossier, the cab hull screen and the upgrade interface
  under one verb: point at a part, inspect the part.

### Tier 2 — the opening Greg described

4. **Opening sequence.** Wake in a dingy interior; forced to win the derby to
   get out; walk out through a large facility; exit into the Ashbloom
   wasteland. This is the first authored narrative spine and it reuses the
   existing derby → Hunt Grounds transition rather than a new scene graph.
5. **First person and body UI.** Character model visible in first person,
   breathing and health readouts driven by the existing anatomy component
   (blood volume, pain, consciousness already exist and are unused by the HUD).
   Walking must not feel broken — this is a feel pass, not new systems.
6. **Procedural interstitials and menus.** Postal 2-register loading screens:
   trippy screensaver anatomy, skeletons, X-ray plates, drawn in code from the
   same primitives the dossier and `kill_cam.gd` already use. The start and
   pause menus move to the same register — crude, grimy, funny, closer to a
   Postal 2 menu than to a clean engine front end.

### Derby art pass — outstanding

The toybox brief is superseded and the venue has been rescaled, regrimed and
relit, but the authored geometry itself is unchanged. Still outstanding:

- **The cars are karts.** `scrap_skiff.glb` is a smooth box silhouette. Per the
  new direction they need stripped chassis, exposed mechanism, bone and sinew
  lashings, fungal bloom in the wheel wells and dried spatter. This is Blender
  work on `art/scrap_skiff_v1/`, not a material swap.
- **Runtime regrime is a stopgap.** `WorldLook.REGRIME` remaps the old material
  names at load. Re-exported assets should carry the biopunk palette natively
  and simply stop matching those keys.
- The pit still reads close to monochrome red. Contamination colour — spore
  green, bruise purple — needs to arrive through authored surfaces, not only
  through light colour.

### Tier 3 — systemic depth

7. **Hunt/Nemesis rework.** Today Mara is one hardcoded character whose state
   is mutated by ad-hoc dict writes in two scenes. It needs to become a system:
   rivals generated from real events, tactic adaptation, promotion and
   recruitment, grudges that propagate through factions. This is what LimboAI
   is for and it is currently unused.
8. **Ashbloom exterior.** Terrain3D for real landscape instead of procedural
   boxes; Proton Scatter for the grime and debris fields that make a wasteland
   read as inhabited.
9. **Proximity voice chat with NPCs.** Pipeline below.

### Deferred intentionally

Large-scale economy simulation, simulation-grade organ damage, multiplayer,
BeamNG-scale deformation, and seamless traversal of all Limbo.

## Plugin strategy

Seven plugins are installed and **none are referenced by any script**. 415MB of
that is three GDExtensions doing nothing. This is the cheapest available
upgrade to the project.

| Plugin | Size | Status | Call |
| --- | --- | --- | --- |
| LimboAI | 109MB | Unused | **Adopt** for the nemesis rework (Tier 3.7). Behaviour trees are the right shape for rival tactics and adaptation, and hand-rolling that again would be the larger cost. |
| Terrain3D | 68MB | Unused | **Adopt** for the Ashbloom exterior (Tier 3.8). |
| Proton Scatter | 1.4MB | Unused | **Adopt** alongside Terrain3D for set dressing. |
| Dialogue Manager | 1.1MB | Unused | **Adopt** at Tier 2.4 when NPCs first speak. |
| gdUnit4 | 2MB | Unused | Optional. The hand-rolled `check()` asserts in `tests/opening_test.gd` work; migrate only if suites grow. |
| FMOD | 238MB | **Failing to load**, panel disabled | **Defer or drop.** It needs FMOD Studio plus authored banks, and its GDExtension currently errors on load. Native `AudioStreamPlayer3D` and audio buses deliver most of Tier 1.1 immediately. Revisit only when real authored audio exists. |
| Godot MCP | 476KB | Dev bridge | Keep, exclude from release builds. |

Note: the three GDExtensions also fail to copy their DLLs while the editor holds
them open, so headless runs load without them.

## Proximity voice chat pipeline

Greg's reference is Rust's proximity chat, redirected from multiplayer to NPCs.
Reduced-scope version that can ship inside single-player, staged so each step is
useful on its own:

1. **Positional speech.** NPC voice lines on `AudioStreamPlayer3D` with
   attenuation and an audible radius. Delivers the proximity feel before any
   microphone work, and is a prerequisite for everything below.
2. **Push-to-talk capture.** `AudioStreamMicrophone` into `AudioEffectCapture`
   on a dedicated bus. Hold a key, capture a buffer, release to submit. Gate it
   on an NPC being inside the conversational radius and facing the player.
3. **Local speech to text.** whisper.cpp as a subprocess or GDExtension over
   the captured buffer. Local keeps it free, offline and private; no per-word
   API cost during long playtests.
4. **Intent match, not open chat.** Map the transcript onto Dialogue Manager
   topics plus the subject's real `WorldHistory` state — grudge, bond, wounds,
   faction, Tree axis. Asking Mara about her arm should hit her actual recorded
   injury. This keeps NPCs in-world and inside their own knowledge rather than
   becoming a general chatbot, which matters for a world whose whole premise is
   that information is partial and sometimes false.
5. **Voice out.** Local TTS per faction/species timbre, played back through
   step 1, degraded through the existing audio treatment so it sits in the mix.

Failure handling is a design surface, not an error path: unrecognised speech
should get an in-character non-answer, because a world of dead forums and
half-working infrastructure is allowed to mishear.

## Open technical risks

- FMOD's GDExtension errors on load; the sound rework must not depend on it.
- Untextured procedural primitives carry the whole look. `WorldLook` triplanar
  noise mitigates it, but authored material work is still outstanding.
- The upright angular lock on the chassis prevents cars rolling; good arcade
  behaviour, possibly wrong for a demolition derby. Needs a feel decision.
- Only `rift_derby` has been migrated to `WorldLook`. The Hunt Grounds, menu
  and showcase still hand-roll environments and should be migrated with visual
  review on each.
