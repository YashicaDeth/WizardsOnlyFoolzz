# Destruction — the honest scope

AB1.1: *"Decide the scope honestly before building anything — full voxel
destruction is not a feature, it is a second project."* This is that
decision, written down before anything in AB gets built on top of it.

## What this is not

**No per-voxel or volumetric fracture.** Simulating a building's material as
a field of breakable cells — the Teardown/Red Faction register — is a
physics-engine project in its own right: broad-phase collision against
thousands of live fragments, a fracture solver, and a rendering path built
around chunky low-poly meshes that were never authored to survive being cut
through at arbitrary planes. This game's whole visual register is PS1/PS2
low-poly with deliberate technical limitations (`ART-DIRECTION.md`); voxel
destruction is not a scaled-down version of that register, it is a different
one, borrowed from games with a completely different silhouette language.
Chasing it would cost more engineering than every other open Lane 2 item
combined and buy a look that fights the rest of the game.

## What this is

**Condition, not fracture.** Every breakable thing carries one number, 0..1,
the same shape `condition` already takes on the handheld (`handheld_device.gd`,
C1.8) and on a weapon's own wear. Damage moves that number down; nothing
about the object's actual geometry changes continuously with it. What the
player sees change is a small, **authored** set of break states per object
*class* — a streetlight has "intact," "flickering," "sparking, glass gone,"
"hanging by its cable" — not a physically simulated crack propagating through
a mesh. Four states is enough to read as damage happening in stages; twelve
would not read as more damage, only as more art.

**Debris is real objects, not particles.** When a break state sheds
something — the streetlight's glass, a wall's blown-out section — that
becomes a physical, persistent piece the player can stand on, kick, or be
hurt by, using the exact pattern `gore_chunks.gd` already proved for bodies:
an *identified* object (what it came off, what it is) rather than a generic
VFX chunk that despawns. AB1.4 already named this the model to reuse. A
capped, aged pool (`MAX_CHUNKS`/`ROT_SECONDS` in `gore_chunks.gd` is the
existing precedent) keeps a long fight's debris from becoming an unbounded
cost — the same trade X1.4 will eventually ask every system in the game to
make.

**The record is the object.** A breakable thing's condition lives in
`WorldHistory` exactly the way `clothing.gd`'s worn layer does — no second
store, no scene-local flag that disagrees with the saved world the moment a
scene reloads. Reading "how wrecked is this street" (AB2.3) is a lookup, not
a walk of the scene tree, because the answer was never anywhere else.

**Repair is somebody's job, not a timer resetting a flag.** AB2.4/AB2.5 fold
into AA's holding-ownership model directly: a holding nobody holds does not
get fixed, because there is nobody whose job that is. This is not new
machinery once AA exists — it is one more thing a holding's owner does with
game time and resources, the same shape as everything else that ledger
already prices.

## What this actually unlocks, in order

1. **AB2.1/AB2.2/AB2.3 — the primitive.** One small file, the `Clothing`
   pattern exactly: static functions over `WorldHistory` subjects, no local
   state, no visuals. This is buildable today and everything else in AB reads
   or writes through it. Landed in this session — see `world_damage.gd`.
2. **AB1.2/AB2.6 — one object class, all the way through.** Pick the
   cheapest, most visible target (a streetlight, not a building) and build
   its full state ladder: condition → break state → shed debris → recorded →
   queryable → (later) repaired. Proves the whole loop end to end on
   something small before it is asked to hold up a building.
3. **AB1.3 — debris as `gore_chunks.gd`'s pattern, generalised.** Only once
   more than one object class exists to shed it; premature to build a shared
   debris pool for a single streetlight's glass.
4. **AB1.5 — vehicles.** Explicitly deferred to Lane 2's own vehicle work
   (`arcade_vehicle.gd`) rather than built here first: a car already has a
   damage concept in progress, and duplicating "condition, 0..1, WorldHistory-
   backed" as a second implementation would be exactly the second store this
   design refuses everywhere else.
5. **AB3 (raiding) and AB1.6 (profiling)** — both depend on more than one
   real object existing in the world first. Not started.

## What stays a wish for now

Building collapse, bullets-vs-explosions on one ledger (AB10.12), destruction
visible from the satellite (AB10.13/AK) — all real, all v10-tier, all
depending on this primitive existing and on Lane 4's satellite/AK work
existing. Named here so nobody re-derives the scope question from scratch
later; not attempted this session.
