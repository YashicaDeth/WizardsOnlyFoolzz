# Underground facility territory slice

Status: **implemented and verified, 17 September 2026**.

This slice connects the opening route that already existed to the territorial
MAP/INDEX loop Greg selected. It does not claim the whole regional liberation
game is finished. It proves its first complete instance in the starting
facility.

## Canonical route

The production route is now:

`vat_chamber.tscn` (the Growing Floor) →
`underground_colosseum.tscn` (the tunnel derby) →
the ringmaster choice → `bone_yard_hunt.tscn` (the Ashbloom Expanse).

The old opening seam accidentally sent the player into `rift_derby.tscn`, the
surface quarry variant. Resuming an unfinished heat made the same mistake.
Both paths now use the authored underground venue. Quarry play remains intact
for any route that selects it directly.

## One authority

`game/systems/facility_territory.gd` is the sole territory authority. It stores
four authored holdings in `WorldHistory.subject("facility_territory")`:

1. the Growing Floor;
2. the Underground Colosseum;
3. the Lockdown Grid, made from the colosseum's existing three tunnels and ring
   corridor (its stable save id remains `service_ring`);
4. the Surface Gate, where the existing ringmaster choice hands the opening to
   the Ashbloom.

Each holding can be corporate-controlled, surveyed, or liberated. Scenes only
report milestones. MAP, INDEX, persistence and corporate reaction read the
same record back.

## Earned change

- Waking reveals the Growing Floor.
- Entering the pit surveys the colosseum and reveals the Lockdown Grid as
  controlled ground.
- Winning the underground derby liberates the colosseum holding. Merely
  entering it or losing does not.
- Liberation unlocks the Underground Colosseum's recovered INDEX file.
- CellOutz reacts once by circulating `REPOSSESSION ORDER 0C-7`, an openly
  corporate bounty that describes the player's body as company inventory.
- Choosing how to leave reveals the Surface Gate and the remaining recovered
  facility records.

## The Lockdown Grid is played, not awarded

The former engineering label “Service Ring” described the outer tunnel layout
but did not tell a player what to do or why. The player-facing name is now
**Lockdown Grid**: its three relays keep the surface exit sealed. The internal
`service_ring` identifiers remain unchanged for save compatibility.

The Underground Colosseum's three existing tunnel chambers each contain one
CellOutz surveillance relay. A live head sweeps a red acquisition cone while
its local light makes the machine readable against the dark masonry. Relays
take three physical contacts and accept both of the derby's existing verbs:
travelling cab rounds and vehicle impacts. Going dark removes the scan and its
light rather than only incrementing a hidden objective counter.

The heat is now compound: eight wreckers clear the bowl, but the player keeps
control until all three relays are disabled. The physical cab cluster carries
three relay lamps and the live acquisition level; after the last wrecker the
only extra screen-space line is the temporary cleanup direction. The final
relay liberates the Lockdown Grid, unseals the exit, unlocks its INDEX record and escalates the
already circulating CellOutz order to priority. It does not create a second
unrelated quest or bounty.

Disabled relay indices live in the territory authority and restore with it, so
re-entering cannot resurrect hardware or duplicate the escalation event.

The reaction is idempotent: replaying the callback cannot farm duplicate
bounties or events.

## Black Mirror behaviour

The first Black Mirror created after the facility route opens on MAP. A player's
subsequent page choice persists with that exact device. MAP initially shows the
facility holdings when a facility record exists; `L` flips between that sheet
and the Ashbloom satellite. Pointer and arrow input both select revealed
holdings.

The facility sheet shows routes, ownership, current objective, approximate
surveillance and the live repossession order. A liberated holding appears as a
selectable recovered file in the existing INDEX FILE register. Place records
use a territory dossier and small floor-plan stamp rather than inventing a
human portrait from sparse data.

The repossession order now acquires the escaped body through the same device.
Opening MAP publishes a coarse 96-metre cell with a 72-metre uncertainty
radius; the true position is somewhere inside the broken red target ring, not
at its centre. A new ledger event is written only after crossing into another
cell. The first area dispatches two persistent CellOutz Ledger Bailiffs at the
edge of that approximate zone through the existing encounter/anatomy pipeline.
A live team prevents duplicate dispatches, while a later area may commission a
replacement only after the prior contract has genuinely resolved.

## Persistence contract

Territory, unlocked files and the CellOutz order are ordinary WorldHistory
subjects. They therefore survive normal save/load and quantum snapshot restore
without a parallel save format. A genuinely new quantum world does not carry
territorial ownership across: the player persists under the existing body
rules, while the facility begins controlled again.

## Escape network

`game/systems/facility_routes.gd` is the persistent adjacency and handoff
authority for the ways through and out of Sublevel 0C. It keeps the canonical
derby spine and adds three mastery routes through shared facility districts:

- the Waste Gallery, Maintenance Cistern and Storm Outfall support stealth and
  exploration;
- the Ossuary Exchange and Undercroft Settlement support an honoured compact
  or a later betrayal, with different lifts and faction consequences;
- the Containment Concourse and Executive Transit support an extraordinarily
  difficult direct breach whose three played control points cannot be skipped.

Recapture is not selectable as a route. It accepts only a named containment
mechanism demonstrated in play, remembers the interrupted attempt and feeds
the existing Underground Colosseum. Once an exit handoff exists, the authority
refuses to revoke that successful escape with another recapture.

The Storm Outfall, Lantern Lift, stolen Freight Spur, Executive Blast Shaft
and derby Vehicle Sallyport each own a distinct Ashbloom coordinate and faction
standing change. `bone_yard_hunt.gd` consumes that handoff before building the
surface world, so all exits enter the same persistent scene without collapsing
to one spawn or one relationship state.

## Evidence

- `game/tests/facility_territory_test.tscn`: 21/21 checks, including
  idempotence, quantum reset and branch restore.
- `game/tests/facility_device_integration_test.tscn`: 8/8 checks, including
  pointer/keyboard-facing selection contract, INDEX unlock and device page
  memory.
- `game/tests/opening_stage_wiring_test.tscn`: 6/6 checks against the real
  opening scene transitions.
- Relevant regressions: `map_perf_test`, `index_link_rebuild_test`,
  `handheld_satellite_test`, and `handheld_page_grammar_test` pass.
- `game/tests/service_ring_relay_test.tscn`: 7/7 physical target and scan
  checks. `game/tests/service_ring_objective_test.tscn`: 13/13 integration
  checks across real chamber placement, vehicle impact, compound completion,
  INDEX unlock and one-shot CellOutz escalation.
- `game/tests/celloutz_bounty_response_test.tscn`: 7/7 checks covering coarse
  arrival, named persistent responders, one live-team cap and resolved-team
  replacement. `facility_territory_test` covers cell idempotence and quantum
  restore; `facility_device_integration_test` covers the MAP publication seam.
- Target-area still: `game/captures/celloutz_target_area.png`.
- Stills:
  `game/captures/phase3_facility_liberated.png`,
  `game/captures/phase3_facility_index.png`, and
  `game/captures/phase3_facility_reloaded.png`.
- Gameplay evidence:
  `game/captures/facility_territory_loop.mp4` — 1280×720, 30 FPS, 14.09
  seconds, H.264/AAC. It shows progressive reveal, liberation, INDEX unlock,
  corporate reaction, a fresh branch resetting ownership, and restoration of
  the saved branch.
- Physical gameplay evidence:
  `game/captures/service_ring_liberation.mp4` — 1280×720, 30 FPS, 14.23
  seconds, H.264. The real cab fires nine travelling rounds into all three
  chamber relays; their live signatures go dark, the cab counter advances and
  the last relay completes liberation.
- `game/tests/facility_stealth_route_test.tscn`: 11/11 checks.
- `game/tests/facility_cooperation_route_test.tscn`: 20/20 checks across both
  honour and betrayal.
- `game/tests/facility_assault_route_test.tscn`: 14/14 checks.
- `game/tests/facility_recapture_route_test.tscn`: 17/17 checks, including the
  demonstrated-cause rule and the prohibition on revoking a successful escape.

## Honest boundary

The facility plan is schematic because the four production scenes do not share
one continuous 3D coordinate space. The routes and holdings correspond to real
scene adjacency and existing colosseum geometry; the plan does not pretend to
be a surveyed architectural blueprint. Material art for the facility remains
blocked on Greg's choice recorded in `ART-DIRECTION-MINDMAP.md`.
