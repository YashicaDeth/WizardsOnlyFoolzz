# Ownership — which lane owns which files

**This table is the most important thing in the folder.** Read the reason
before you read the table, or you will treat it as bureaucracy and route around
it.

## Why this exists, and why worktrees alone are not enough

Every agent-on-agent problem in this project has been **two writers in one
file**, or worse, **two builders of one system in two places**.

Orca gives each task its own git worktree, which stops two agents editing the
same file in the same instant. It does **not** stop two agents building the same
system in two different places under the same name. That is what happened with
`sephiroth.gd`, and with `body_mirror.gd`, where two complementary designs
arrived under one `class_name` and one would have silently destroyed the other
on merge. Git cannot see that class of problem. Only this table prevents it.

A worked example of how invisible it gets: `agent-b` merged `silhouette.gd`
with **no conflict at all**, and the result did not compile. Its five-parameter
`dress_vehicle` beat HEAD's six-parameter one, and the caller passes six. There
was no marker to resolve. Git reported success. The build was broken.

## The table

| Lane | Owns | Standing note |
|---|---|---|
| **1 — the body** | `baseline_human.gd`, `anatomy_component.gd`, `wound_marks.gd`, `blood_flow.gd`, `penetration.gd`, `body_mesh.gd`, `gore_chunks.gd`, `body_mirror.gd`, `carrion_scavenger.gd`, `bone_yard_hunt.gd`, `gore_demo.gd`, `hunter_motor.gd`, `hunter_body_motion.gd` | Reads `ballistics.gd`, never writes it. |
| **2 — the breakable world and the frame budget** | `silhouette.gd`, `ashbloom_world_generator.gd`, `world_look.gd`, `arcade_vehicle.gd`, `rift_derby.gd`, `derby_ai_driver.gd`, prop and building files, `shaders/`, the perf overlay and benchmarks | **Never open a body file.** |
| **3 — guns** | `ballistics.gd`, `hunter_arsenal.gd`, `held_gear.gd`, `launcher_actor.gd`, weapon models | Coordinate with Lane 1 before touching `ballistics.gd` — listed in both. |
| **4 — the demo** | `P`-section scenes, the opening sequence, objective and pacing scripts | The most important lane and the least glamorous. See below. |
| **5 — getting in** | `country_town_menu.gd`, `boot_splash.gd`, settings and input files, `pause_gate.gd`, `celloutz_type.gd`, `crt_glass.gd`, `regal_frame.gd`, `character_archive.gd`, `implant_catalog.gd` | First thing anyone handed a build will touch. |
| **6 — the handheld and the brain** | `handheld_device.gd`, `world_index.gd`, `brain_index.gd`, `black_mirror.gd`, `wire_net.gd` | |
| **7 — merging** | **Nothing. Writes no features.** | The only lane that should ever resolve a conflict. |

### Shared files — the collision points that are not in the table

- **`CHECKLIST.md`** — every lane ticks its own lines here. Always make it a
  **separate final commit touching only `CHECKLIST.md`**. Seven trivial
  conflicts beat one unresolvable one.
- **`ballistics.gd`** — Lane 3 writes, Lane 1 reads.
- **`project.godot`** — nobody edits it casually; an autoload or input-map
  change is a coordinated act, not a side effect.

### Why Lane 4 is called the most important

Every other section is a system. P is the only one that *is the game* — what a
player does in the first ten minutes and why they keep going. In Greg's own
words: *"there needs to be a point of the game because right now it just seems
really sandboxy."* P was 0 of 45 on 14 September and measured **23 of 45** on
16 September — the "7 of 45" that `MERGE_STATUS.md` and the first draft of this
folder both quoted was stale on arrival.

## If you need to cross a boundary

Stop and ask. Do not edit a file another lane owns because your change is
"only one line" — the one-line changes are exactly the ones that merge cleanly
and break the build. Ask the merge lane to sequence it instead.
