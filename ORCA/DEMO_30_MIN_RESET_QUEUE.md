# First 30-Minute Demo — Post-Reset Orca Queue

Prepared 19 September 2026 for Orca run `run_6da4e5a9677d`.

## Reset window

Orca reported four Codex weekly resets tonight: **10:22 PM, 10:31 PM,
10:41 PM, and 10:47 PM** Hobart time. These are the four implementation seats.
Two Claude accounts are available for the strike. Claude A owns the read-only
cross-lane design/integration audit. Claude B owns the executable playtest route,
capture plan, and feedback-gate audit. After the four Codex commits arrive, the
two reports govern the final integration/review pass.
Dispatch the four implementation lanes after 10:47 PM so all accounts are
eligible. The integration gate starts only when the four implementation tasks
and Claude audit are complete.

The implementation lanes are deliberately independent. Dispatch each to a clean
worktree from the same base commit. Do not let workers share a worktree. The
Orca coordinator owns dispatch, concise progress updates, user feedback gates,
usage conservation, terminal cleanup, and routing corrections. The integration
gate remains blocked until all four implementation lanes and both Claude audits
have reported accepted results.

Authoritative context, in order:

1. `CHECKLIST.md`
2. `DESIGN.md`
3. `ARCHITECTURE/SYSTEM_MAP.md`
4. the connected ledger map
5. this queue for ownership and acceptance boundaries

Global worker rules:

- Preserve unrelated files and untracked imports.
- Measure or reproduce before changing behavior.
- Use `PlayerActionLedger` and `WorldHistory`; do not create duplicate state.
- Stage explicit paths, commit the owned slice, and report the commit SHA.
- Run relevant Godot tests and provide visual evidence for visual claims.
- Do not invent final lore, final art, or world-scale redesigns.

### Project-scoped autonomy policy

Workers have standing authority to complete routine engineering inside their
assigned worktree and owned paths without asking Greg or waiting at a local
multiple-choice prompt. This includes creating, moving, editing, or removing
files within the owned slice; choosing implementation details; running Godot,
profiling, capture, and test commands; recovering from ordinary tool failures;
and staging and committing explicit owned paths. Workers should make the
smallest reversible decision that satisfies the lane and continue.

If a provider offers a lower-cost supported model because an account is near a
usage limit, accept the economical model automatically and continue at medium
reasoning. The coordinator may instead launch a lane on that economical model
from the outset. A model-choice menu is not a user gameplay decision and must
not be forwarded to Greg. If an update prompt blocks startup, the coordinator
resolves it before dispatch rather than leaving the worker waiting for input.

Ask Greg only when the answer would determine subjective gameplay feel, final
art direction, authored lore, tone, accessibility preference, or a similarly
meaningful player-facing choice. When safe, continue independent work while
that question is pending. Escalate technical matters only for an ownership
conflict or scope expansion that the coordinator must resolve.

Standing authority does **not** include broad or unrelated deletion, Git reset,
rebase or force-push, editing outside the assigned worktree/owned paths,
credentials or account changes, purchases, public publishing, or external
messages. Those remain explicit coordinator/user decisions. No worker may
weaken global machine security or global Codex permissions; autonomy is scoped
to this repository, its isolated worktree, and the assigned lane.

## Lane 1 — AX opening slice

Orca task: `task_12522e9b7299`

Own only `game/vat_chamber.gd`, `game/vat_chamber.tscn`,
`game/systems/vat_intake.gd`, `game/systems/opening_director.gd`, and narrowly
related opening tests/captures.

Build the earliest coherent first-play slice from authored examination and
character-creation beats through soul/implant breakout to immediate player
control and a plainly legible **ESCAPE THE FACILITY** objective. Remove dead
waiting and fast unreadable bottom prose. Teach the first physical acquisition
through existing inventory, anatomy, ledger, and history primitives.

Do not invent final doctor lore, final character art, the full facility map, a
phone redesign, or edit `bone_yard_hunt.gd`.

Done means relevant headless tests pass, a deterministic regression proves the
player reaches control and the escape objective without the old stall, the
examination-to-breakout handoff has evidence, and the lane reports SHA, files,
commands, evidence, and honest gaps.

## Lane 2 — Combat and perspective

Orca task: `task_523bd099a4e2`

Own only `game/bone_yard_hunt.gd`, directly used grapple/perspective/movement
helpers, and narrowly related grapple, combat-traversal, and third-person tests.

Make the first combat lesson dependable: `C` begins a nearby readable clinch;
movement creates stable push, pull, and turn intent; release always restores
collision and control; perspective switching works after the existing unlock,
respects camera clearance, and never leaves a stuck state.

Both perspectives use the same anatomy, ballistics, weapon condition, wound,
and damage results. First person remains precise; third person adds awareness
and choreography. Add no new combat system and do not edit opening, UI, phone,
map, or lore files.

Done means the grapple/playability/zone/mass, combat-traversal, and third-person
HUD tests pass, plus a regression covers acquire, directional pressure,
release, perspective toggle, and reacquire without frozen velocity or collision
exceptions.

## Lane 3 — Controls and contextual HUD

Orca task: `task_5a158bfda68b`

Own only `game/systems/keys_card.gd`,
`game/systems/gothic_field_hud.gd`, `game/tests/gameplay_demo.gd`, its scene,
demo-route and keys-card tests, controls-recovery capture, and directly required
UI tests.

Replace the overwhelming F1 wall with readable contextual groups or pages.
Prevent objectives and interaction prompts from covering the HUD. Make the
gameplay-demo harness exercise the same controls and route as the real game.
Prefer removing or timing unexplained prose instead of inventing more prose.

Preserve bindings unless a conflict is reproduced. Every live binding remains
discoverable. Keep controller use and 1280×720 safe zones. Do not edit opening,
combat, phone/map internals, or final art.

Done means the keys-card, controls-recovery, demo-route, gameplay-demo,
HUD-transience, and settings tests pass, with a 1280×720 capture and a concise
before/after inventory.

## Lane 4 — Performance and audio budget

Orca task: `task_9cdc737d158e`

Own profiling and tightly scoped fixes for the real first-30-minute route plus
performance/audio tests. Avoid files owned by lanes 1–3 unless a conflict is
reported first.

Measure before editing. Target a stable 60 FPS default-performance experience
on an RTX 2060 Super-class machine where feasible. Keep 5–20 nearby people fully
simulated; distant NPCs retain identity and destinations while temporarily
simplifying animation, organ/wound work, conversational reasoning, and path
recalculation.

Diagnose runaway physics bodies, persistent gore/casings/wreckage, repeated
audio sources, and smoke/status stacking that creates progressive slowdown or
distortion. Fix demonstrated hotspots with distance/simulation budgets and
cleanup lifetimes. Do not remove core systems, fake populations, or redesign
art.

Done means before/after counters and a reproducible route exist, relevant
headless/performance/audio tests pass, and no debug explosion binding leaks into
the player route.

## Gate 5 — Integration and gameplay evidence

Orca task: `task_eb7b433a9f3d`

Dependencies: all four lanes above.

Use a clean integration worktree. Review and integrate each reported commit in
dependency-safe order, resolve only real cross-lane conflicts, and rerun the
complete relevant suite. Then exercise the actual 1280×720 route: splash/new
game, examination/creation, breakout and first acquisition, escape objective,
first combat, grapple, perspective switch, contextual controls, and the handoff
toward Derby or surface.

Produce a truthful 30–60 second gameplay capture or deterministic capture
sequence, record performance counters and warnings, and update the ledger only
for verified landed behavior. Add no features at this gate.

The final report must include input SHAs, final integration SHA, exact commands,
evidence paths, failures, remaining blockers, and a short user playtest route.
