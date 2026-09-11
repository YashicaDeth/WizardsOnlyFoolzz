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

### Tier 2 — the opening Greg described

4. **Opening sequence.** Wake in a dingy interior; forced to win the derby to
   get out; walk out through a large facility; exit into the Ashbloom
   wasteland. This is the first authored narrative spine and it reuses the
   existing derby → Hunt Grounds transition rather than a new scene graph.
5. **First person and body UI.** Character model visible in first person,
   breathing and health readouts driven by the existing anatomy component
   (blood volume, pain, consciousness already exist and are unused by the HUD).
   Walking must not feel broken — this is a feel pass, not new systems.
6. **Procedural interstitials.** Postal 2-register loading screens: trippy
   screensaver anatomy, skeletons, X-ray plates, drawn in code from the same
   primitives the dossier already uses. No copied assets, and it reinforces
   the anatomy motif at every scene change.

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
