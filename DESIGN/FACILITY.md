# The underground facility: one place

4 October 2026. Greg: *"The underground facility the player must escape is a
real, coherent, explorable place: one connected space (levels, tunnels, rooms,
elevators/lifts walked in-world), not a chain of separate scenes with splash
transitions. Escaping it IS the demo's spine."* Elevators are real: doors
close, the cab rides a visible shaft, doors open on the new level, no fade.
Facility size: *"agent decides from DESIGN/FACILITY_TERRITORY_SLICE.md."*

This file is the single map. It places every existing room at a true position
in one coordinate frame so the rooms can be joined without loading screens.
Greg's decisions are quoted or cited; everything else is an **assistant
layout** (positions, shaft depths, corridor runs) and can move.

Built from: `DESIGN/ESCAPE_ROUTES.md` (routes and their order),
`DESIGN/FACILITY_TERRITORY_SLICE.md` (holdings, districts, Sublevel 0C),
`DESIGN/FIRST_30_REBUILD.md` (the spine), `game/systems/facility_routes.gd`
(district ids, which this map keeps).

## Frame and grid

- One frame, metres. **+Y up, -Z is "deeper in"** (away from the vat), +X east.
- Origin: the player's vat (`vat_chamber.gd` `VAT_POSITION`).
- The vat floor is **Sublevel 0C, y = 0**. The surface is **y = +20**.
- Corridor and tunnel pieces sit on a **4 m grid** (4 m wide, 4 m tall
  inside). The tunnel kit from `art-tunnels-07` must fit this grid; until it
  lands the skeleton uses placeholder boxes on the same grid.
- A room's position below is where its own scene's local origin sits in the
  facility frame (its scripts keep their local coordinates).

## Levels

| Level | Floor y | What is on it |
|---|---|---|
| Surface | +20 | Heat elevator head-house (first zone exit), doctor's ramp top |
| 0C | 0 | Growing Floor, Examination Room, service artery, Service Arcade |
| 0D | -12 | Lower Works (the pit district), heat elevator foot, drain grate |
| 0D-east | -14 | Support Unit, Doctor's Vehicle Bay |
| 0E | -20 | Old Drains, Drain Cistern, Storm Outfall run |

## Rooms and where they sit

| Room (district id) | Scene | Origin in facility | Footprint (local) |
|---|---|---|---|
| Growing Floor (`growing_floor`) | `vat_chamber.tscn` | (0, 0, 0) | x -8..8, z 6.2..-26 |
| Examination Room (`examination_room`) | built by `doctor_route.gd` | (0, 0, 0) | x -3.5..4.5, z 3.6..10.5 |
| Service Arcade (`service_arcade`) | `service_arcade.tscn` | (28, 0, 0) | x -7.25..7.25, z 5.5..-58.5 |
| Lower Works (`lower_works`) | `buried_city.tscn` | (28, -12, -84) | x -15..15, z 18..-52 |
| Support Unit (`support_unit`) | `support_unit.tscn` | (0.5, -14, 6) | x -7.25..7.25, z 6..-108 |
| Doctor's Vehicle Bay (`doctor_vehicle_bay`) | `doctor_vehicle_bay.tscn` | (0.5, -14, -114) | x -9..9, z 12..-14, ramp beyond |
| Old Drains / Cistern (`waste_gallery`, `maintenance_cistern`) | `old_drains.tscn` | (37, -20, -118) | x -3..3, z 4..-62 |
| Underground Colosseum (`underground_colosseum`) | `underground_colosseum.tscn` | reserved below 0E, west | not placed yet |

No two footprints overlap: the arcade and Lower Works sit east of the vat
column (x 9..43), the doctor's line runs under the vat column at -14, and the
drains run under the Lower Works' east floor.

## Connections (walk order of the first-run spine)

1. **Vat to artery.** The Growing Floor's east staff door (`STAFF_DOOR_AT`,
   local 6.95, 0, -2.5) opens on the **service artery**: a 4 m corridor east
   along z = -2.5 to the Service Arcade's west wall at x = 20.75.
2. **Service Arcade.** The player walks the arcade south-to-north (local z +4
   to -55), past the guard post (-31.5) and the pressure gate (-48). The
   crawlway (local -7, -45) is the first-run way round the jammed gate.
3. **Transit lift (Lift A).** The arcade's north wall (local z -58.5) opens on
   a through-car lift at facility (28, *, -62): boards at 0C facing north,
   rides **12 m down**, opens north into the Lower Works' south end at 0D.
   This replaces "pressure gate open // lower works transit unlocked".
4. **Lower Works.** Entry at local (0, 16); fuse at (11.2, 1.8); the landmark
   **heat elevator** at local (0, -38) = facility (28, -12, -122).
5. **Heat elevator (Lift H)**: Greg's first way out (`796903d`). Rides
   **32 m up** from 0D to the surface head-house. Its doors open on the
   **Surface Gate**, the first zone exit. Past that door is the Ashbloom
   (`bone_yard_hunt.tscn`), a true scene boundary where `Interstitial` stays.

## The escape routes in this map

Greg's routes (`ESCAPE_ROUTES.md`), placed:

- **Heat elevator** (first run): steps 1-5 above.
- **Chasing the doctor**: back past the vat, break his door (z 3.6), cross the
  Examination Room, take **his lift (Lift D)** at facility (0.5, 12.6) **14 m
  down** (`doctor_route.gd` `DESCENT`) to the Support Unit at -14. The hall
  runs north to the Vehicle Bay; its ramp climbs to the surface.
- **The old drains**: the drain grate in the Lower Works at local (9, -35) =
  facility (37, -12, -119) drops 8 m to the Old Drains at 0E, which run north
  to the cistern and the Storm Outfall.
- **The derby** (secret route): the Underground Colosseum is reserved below
  0E, west of the drains, reached by the Reprocessing Chute
  (`processing_chute`). Not in the skeleton until its venue is placed.

The three mastery routes in `facility_routes.gd` (Undercroft Compact,
Executive Breach, Old Drains) keep their district ids; only the Old Drains has
built rooms, so only it is placed.

## Factions' ground

- **CellOutz** (the corporation, Hollis, the sentinels) holds 0C and 0D: the
  Growing Floor, the arcade's guard post, the Lower Works sentinel, the
  Lockdown Grid.
- **The doctor's private wing** (Examination Room, his lift, the Support Unit,
  his bay) is CellOutz officer ground: breaking in costs `celloutz -12`.
- **Ashline Wreckers** run the colosseum (reserved cell).
- **Gate Lanterns / Undercroft Freehold** sit beyond the Ossuary Exchange
  (unplaced; no rooms built).

## Landmarks you navigate by

- The vat column and the observation glass behind it (0C).
- The arcade's thirteen arches and the pressure gate (0C).
- The Lower Works landmark lift cage, visible across the district (0D).
- The lift shafts themselves: Lift A and the heat elevator are glimpsed
  through the cab's slots, with light strips passing every 3 m.

## In the engine

- `game/facility.tscn` / `facility.gd`: the master skeleton. Every room above
  that is on the first-run spine (Growing Floor, artery, Service Arcade,
  Lift A, Lower Works, Lift H, Surface Gate) plus the doctor's line (Lift D,
  Support Unit, Vehicle Bay) and the drain drop are placed at their true
  positions as placeholder shells with collision and lighting, on one player,
  with no scene change between them.
- `game/systems/facility_elevator.gd` (`FacilityElevator`): a real lift. The
  cab is an `AnimatableBody3D` riding a shaft built in the same scene; landing
  and cab doors slide shut and open; a floor indicator in the cab and at each
  landing; a motor hum; the player is carried physically by the moving floor.
- `game/tests/facility_walk_test.tscn`: walks a body from the vat to the
  Surface Gate through both lifts with zero `Interstitial.travel`.
- **Tunnel kit** (`art-tunnels-07`): `game/systems/facility_tunnel_kit.gd`
  builds pieces on the 4 m grid (straight, corner, T, cross, dead end, door,
  pipe run, vent) as exact shells with collision, wearing the house-style
  tileable textures (`art/generated/textures/tunnel_*_512.png`, world-mapped
  so tiling runs on across joints) and dressed with Higgsfield models
  (`art/generated/tunnels/`: a steel rib on every joint, lamp cages, pipe run,
  vent grate, bulkhead, door frame; FIT entries in `generated_model.gd`).
  `facility_tunnel_door.gd` is the in-world sliding door (opens as a body
  comes near, shuts behind it). `dress_lift()` puts the wall texture on each
  lift shaft and the generated cage inside each car.
- `game/facility_tunnel_network.tscn` (assistant layout, inside
  `facility.tscn`): the service artery from the staff door through a
  crossroads and a sliding door to the arcade's west wall, plus side tunnels
  (south vent, north pipe run to a T, west bulkhead, east corner to a second
  vent). Lamps alternate with dark cells: light pools for the Shade.
  `tests/facility_tunnel_network_test.tscn` checks joints, floors and walls and
  walks every cell.

## Not done yet (honest boundary)

- The placeholders are boxes on the grid. The real rooms (`vat_chamber.tscn`
  and the rest) are still separate scenes with their own player and HUD;
  the cutscenes and the intro live in `vat_chamber.tscn` and are untouched.
  Moving each room's content into its cell (one shared player) is the next
  step, room by room, and is where `tunnels-06-seamless-facility` overlaps.
- The tunnel kit now builds the service artery and dresses all three lift
  shafts. The other corridors (Lift A and heat-elevator vestibules) and the
  room shells are still placeholder boxes on the grid; the kit can replace
  them cell by cell (`KIT.build(kind, open_sides)`).
