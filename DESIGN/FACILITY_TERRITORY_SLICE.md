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
3. the Service Ring, made from the colosseum's existing three tunnels and ring
   corridor;
4. the Surface Gate, where the existing ringmaster choice hands the opening to
   the Ashbloom.

Each holding can be corporate-controlled, surveyed, or liberated. Scenes only
report milestones. MAP, INDEX, persistence and corporate reaction read the
same record back.

## Earned change

- Waking reveals the Growing Floor.
- Entering the pit surveys the colosseum and reveals the Service Ring as
  controlled ground.
- Winning the underground derby liberates the colosseum holding. Merely
  entering it or losing does not.
- Liberation unlocks the Underground Colosseum's recovered INDEX file.
- CellOutz reacts once by circulating `REPOSSESSION ORDER 0C-7`, an openly
  corporate bounty that describes the player's body as company inventory.
- Choosing how to leave reveals the Surface Gate and the remaining recovered
  facility records.

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

## Persistence contract

Territory, unlocked files and the CellOutz order are ordinary WorldHistory
subjects. They therefore survive normal save/load and quantum snapshot restore
without a parallel save format. A genuinely new quantum world does not carry
territorial ownership across: the player persists under the existing body
rules, while the facility begins controlled again.

## Evidence

- `game/tests/facility_territory_test.tscn`: 15/15 checks, including
  idempotence, quantum reset and branch restore.
- `game/tests/facility_device_integration_test.tscn`: 7/7 checks, including
  pointer/keyboard-facing selection contract, INDEX unlock and device page
  memory.
- `game/tests/opening_stage_wiring_test.tscn`: 6/6 checks against the real
  opening scene transitions.
- Relevant regressions: `map_perf_test`, `index_link_rebuild_test`,
  `handheld_satellite_test`, and `handheld_page_grammar_test` pass.
- Stills:
  `game/captures/phase3_facility_liberated.png`,
  `game/captures/phase3_facility_index.png`, and
  `game/captures/phase3_facility_reloaded.png`.
- Gameplay evidence:
  `game/captures/facility_territory_loop.mp4` — 1280×720, 30 FPS, 14.09
  seconds, H.264/AAC. It shows progressive reveal, liberation, INDEX unlock,
  corporate reaction, a fresh branch resetting ownership, and restoration of
  the saved branch.

## Honest boundary

The facility plan is schematic because the four production scenes do not share
one continuous 3D coordinate space. The routes and holdings correspond to real
scene adjacency and existing colosseum geometry; the plan does not pretend to
be a surveyed architectural blueprint. Material art for the facility remains
blocked on Greg's choice recorded in `ART-DIRECTION-MINDMAP.md`.
