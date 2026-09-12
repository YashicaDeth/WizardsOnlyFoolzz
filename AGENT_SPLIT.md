# Four agents, one game — the split

Written 2026-09-12. Greg is running three Claude accounts plus Codex. This is
how the remaining work divides so that four agents can grind in parallel without
fighting over the same files.

**Give each agent the section below that names it, and nothing else.** Each one
is written to be read cold, without any of another session's history.

---

## The rules that apply to everyone

1. **One worktree per agent.** Never two agents in the same working tree.
   ```
   git worktree add ../atg-agent-b -b agent-b
   ```
2. **One owner per file family.** The tables below are the authority. If you
   need to change a file you do not own, say so first and wait.
3. **Narrow commits.** Never `git add -A` — this repo has several agents with
   work in flight, and a blanket add sweeps somebody else's half-finished
   change into your commit.
4. **Tick your own checklist lines in your own commits.** `CHECKLIST.md` and
   `CHANGELOG.md` are shared. Conflicts there are trivial to resolve; a single
   maintainer is a bottleneck at this pace.
5. **Merge often.** After each commit, fast-forward the main checkout:
   ```
   git -C P:/GameDev/AllusionsTooGrandeur merge --ff-only <your-branch>
   ```
6. **Verify before you claim.** Never say a visual result is done without
   looking at the screenshot. Every windowed Godot run needs
   `--position 2240,320` so it opens on Greg's second monitor.
7. **Read `AGENT_BRIEF.md` and `CHECKLIST.md` first.** The house rules — I0
   ("no screen is a list of text in a box"), Rule 3 ("every hard cut is a bug"),
   the originality non-negotiables — are not optional and are not repeated here.

---

## Agent A — interface, camera and combat feel

**Sections: M, O, and the tail of I.**

The lane is *how the game feels in the hand*: what the player looks through,
what a hit feels like, and what the screens do.

| Owns | |
| --- | --- |
| `game/bone_yard_hunt.gd` | camera, input, combat resolution |
| `game/systems/impact_feel.gd` | hitstop and contact |
| `game/systems/world_index.gd`, `living_map.gd`, `handheld_device.gd` | the screens |
| `game/systems/pin_board.gd` | The Board |
| `game/systems/celloutz_type.gd`, `code_rain.gd`, `black_mirror.gd` | the interface vocabulary |

Order of work:

1. **M4.1 / M4.4 / M4.5** — perspective. Scale consistency (a door, a car and a
   person agreeing how big a person is), weapon and hand framing at the wide
   FOV, and the rules applied everywhere. M4.2 and M4.3 are done.
2. **M2** — in-car first person: one hand on the wheel, the other holding a gun,
   shooting out through your own windscreen, glass degrading as the car does.
   ⚠ Touches `rift_derby.gd` — coordinate with Agent B, who owns its visuals.
3. **M1.5 / M1.6** — the third-person unlock as a felt event, and a diegetic
   first-person HUD with nothing floating in a corner.
4. **O3 / O4** — the body as the health bar, and enemies that read your
   commitment and punish it.
5. **M3** — the seams: cutscene into driving, derby into foot, with no hard cut.
6. **I0.6 / I0.7 / I0.8** if Codex has not taken them.

---

## Agent B — the look

**Section G, and H1 when G is clear.**

The lane is *what the world is made of*. Greg's standing complaint is
"everything looks like boxes", and three passes at textures did not fix it
because a texture does not change an outline.

| Owns | |
| --- | --- |
| `game/rift_derby.gd` | derby scene and its visuals |
| `game/systems/arcade_vehicle.gd` | chassis and car build |
| `game/systems/ashbloom_world_generator.gd` | region geometry |
| `game/systems/world_look.gd`, `silhouette.gd`, `celloutz_grunge.gd` | materials and dressing |
| `game/art/derived/**` | generated textures (never write to Greg's source art) |

Order of work:

1. **G2.1–G2.4** — derby cars stripped and biopunk. They are currently boxes
   with wheels. Read `silhouette.gd` first: the lesson from G4 is that the
   outline is what reads at distance, not the surface.
2. **G3.1–G3.3** — arena re-authoring and contamination surfaces. Note the
   failed experiment already recorded: `ARENA_SCALE` 2.15 and 2.45 both emptied
   the heat out of the fight. It needs authored geometry, not a scale factor.
3. **G1** — the art pipeline, once Greg answers where the art folder is.
4. **G6** — the opening, directed, if Codex has not finished it.
5. **H1.1–H1.3** — the camp: an environment recruits actually live in.

Constraint that is not negotiable: **never write to
`C:\Users\Greg\Desktop\Art Collections`.** It is read-only source. Derived
textures go to `game/art/derived/` and must be rebuildable from scratch.

---

## Agent C — the two ladders and the cosmology

**Sections E and K. This is the biggest hole in the project: E is 2/23 and K is
1/15, both almost entirely designed and almost entirely unbuilt.**

| Owns | |
| --- | --- |
| `game/systems/wire_net.gd` | reach, rank, exposure |
| `game/systems/carry.gd` | selling, liens, faction pricing |
| new files under `game/systems/` for factions, ranks, the Sins, the Horsemen | |
| `DESIGN/COSMOLOGY.md`, `DESIGN/FACTIONS.md`, `DESIGN/RITUAL_AND_KARMA.md` | |

Read `DESIGN/COSMOLOGY.md` before writing a line. The shape Greg has specified:

- **CellOutz** are the underground demon faction; **wizardsonlyfoolz** are the
  ascending mage collective. As above, so below.
- The player is a **CellOut wizard, half demon and half angel**, and a Hunter
  trying to get God's attention in order to fix the earth.
- The **Four Horsemen** are bosses who rotate through CellOutz leadership.
- The **Seven Deadly Sins** are a lesser tier; lesser demons roam the world.
- Karma and magic deliberately **bastardise Thelema** — they are explicitly not
  Crowley's reading.

Order of work:

1. **E1–E2** — rank, standing and the seal vocabulary. `world_history.gd`
   already has `FACTION_TREE_AXIS` with an axis and a principle per faction, and
   `faction_price_factor` already prices a deal by how far apart you are. Build
   on that rather than inventing a second standing model.
2. **E3** — the camera ritual presentation.
3. **K1.2 / K1.3** — CellOutz and wizardsonlyfoolz as a felt presence in the
   world rather than two names in a table.
4. **K4.1 / K4.2** — the Sins, and the factions that are named but missing.
5. **K2** — the Horsemen. ⚠ Blocked: Greg has not given their names yet. Ask.

Coordination: you will want to read `world_history.gd`. **Codex owns it.** Ask
for an API rather than adding fields to it yourself.

---

## Codex — the living-world spine

**Sections F and J.** Already agreed and in progress.

| Owns | |
| --- | --- |
| `game/systems/world_history.gd` | the ledger everything reads |
| `game/systems/rival_registry.gd` | rivals born from real events |
| Hunt, defeat, capture, recruitment logic | |
| `game/tests/` for the above | |

Order of work: F4 (done — rivals from recorded harm), F5 (defeat becomes
capture, conscription or re-decanting), F6 (mind-stamping and taskable
recruits), J2 (remove shipping debug controls).

Codex exposes new `WorldHistory` APIs that the other three ask for. Nobody else
adds fields to the ledger.

---

## Still blocked on Greg

None of these stop work, but each one changes what gets built:

1. The **four Horsemen's names** — blocks K2.
2. **Cast display names** — blocks I0.9.
3. Is the Board a **physical wall** you walk to, or does it live on the black
   mirror?
4. **celloutz.xyz** — mirror the real site, or fictionalise it? Blocks I3.
5. **What persists between runs?** Roguelike structure and "bodies remember"
   pull against each other.
6. Working title: keep *Allusions to Grandeur* or move to **wizardsonlyfoolz**?
