# The spine

**What this fixes:** one row per thing the player does. The row names the system
that owns it, the record it leaves, the screen it appears on, the object it is in
the world, and the art and sound it needs.

It exists because the same three questions keep being answered three times:

- art needs a list of things to draw, in the order they appear;
- writing needs a list of moments where a line is spoken and by whom;
- build needs a list of verbs that must work before the slice is done.

This table is all three. If a mechanic has no row, it is not in the game yet,
whatever is in `systems/`.

**Rules**

1. One verb per row. "Fight" is not a verb; "land a blow", "block", "parry" are.
2. The **owner** is the one file allowed to decide it. If two files decide it,
   that is a bug in the row.
3. The **record** is what survives the scene. If nothing survives, the word is
   `none` and that is a design smell worth looking at.
4. The **object** is where it physically is. Law 14: every screen is a thing in
   the world. If the object column says "menu", the row is not finished.
5. The **asset** column is the commission list. The **sound** column is what a
   listener must be able to identify with their eyes shut.

---

## Vertebra 1 — Data contracts

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Wake in a world that remembers | `world_history.gd` | subjects, places, receipts | none (invisible) | the save itself | none | none |
| Spend a minute | `world_clock.gd` | world minute, hour, phase | HUD clock strip | the sky through the firmament | sky states | per-room bed |
| Die | `vat_rebirth.gd` | death, killer, claim | death beat | the vat that claims you | vat body, cord | liquid, heartbeat stop |

## Vertebra 2 — The examination

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Answer him | `vat_intake.gd` | `character_sheet.gd` fields | intake pages | the form under your hands | page furniture, ink, stamp | pen, paper, his voice |
| Shape a face | `face_model.gd` | sheet: face keys, build, height | FACE tab | the body in the vat | 3 model sheets minimum | none |
| Be studied | `examiner_feed.gd` | none | the feed above the glass | the camera watching the tank | examiner head, camera rig | his voice, tape hiss |

## Vertebra 3 — The soul rewrites the chip

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Tear the cords out | `brain_hack.gd` | `opening_director.gd` beat | the card | the umbilicals in your throat | cords, mouth, tube | wet tearing, choke |
| Break the glass | `glass_tank.gd` | beat, shard count | the card | the tank | glass stages, 48 shards | crack, burst, flood |
| Choose two disciplines | `brain_screen.gd` | sheet: pair | brain screen | the open brain, chip in cortex | wet brain, CRT, chip | chip boot, modem chirp |

## Vertebra 4 — Learning by holding

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Take a thing | `carry.gd` | carried items, mass | CARRY | the object in the reliquary | item kit per class | pick up, settle |
| Turn it over | `body_inspector.gd` | inspection seen | inspect overlay | the thing in your hands | close-up detail pass | cloth, metal |
| Put it on | `garments.gd` | zone layers | the mirror | the cloth on your body | garment shells | fabric |

## Vertebra 5 — The biometric door

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Coerce him | `facility_guard_post.gd` | `player_action_ledger` event | his speech | the guard, the reader | guard body, reader | voice, breath |
| Drag a body | `carry.gd` + ragdoll | smear, millilitres | none | the corridor floor | corpse drag poses | drag, wet |
| Offer a hand | `biometric_barrier.gd` | door opened | the reader's lamp | the reader | reader, lamp | accept, refuse |
| Take his gun | `facility_guard_loadout.gd` | carried weapon | held gear | BREACH NINE | gun model, hands | charging handle, three rounds |

## Vertebra 6 — The Black Mirror

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Raise it | `handheld_device.gd` | battery, wear | the pages | the slab in your hand | phone, jester back | servo, glass tap |
| See in the dark | `black_mirror_camera.gd` | none | camera page | the lens | green feed, gain | sensor whine |
| Read the map | `satellite_view.gd` | place read | MAP | the sky's own photograph | chart, contour | static |
| Take a photograph | `field_camera.gd` | `photo_album.gd` | album | the print | paper stock | shutter, print |

## Vertebra 7 — The escape branches

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Ride the lift | `facility_elevator.gd` | route taken | floor readout | the cab, the shaft | cab, lintel, shaft | motor, cable, chime |
| Walk the drains | `old_drains.tscn`, `drain_stalker.gd` | route taken, blood lost | none | the outfall | drain kit, stalker | water, stalker |
| Die honestly early | `opening_death.gd` | death reason | card | the tank | none new | none |

## Vertebra 8 — The surface handoff

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Surface | `surfacing.gd`, `exit_reveal.gd` | place, hour | arrival reveal | the gate, the daylight | gate, yard, sky | wind, silence |
| Read a body | `world_xray.gd` | wounds, hardware | X-ray | the body in front of you | X-ray shell, organs | scan sweep |
| Land a blow | `melee_driver.gd` | wound, zone, cause | hit marker | the blade, the body | weapons, impact | whoosh, crack, wet |
| Be seen | `witness_ledger.gd` | who saw, did they live | awareness box | the person looking | none | breath, step |

---

## Verbs that have no row yet

Written down so they are not lost, and not built by accident:

- **Publish** a theory (`pin_board.gd` is a wall; publishing is noted, not built).
- **Petition** a plane (`plane_ladder.gd` exists; the verb is design).
- **Trade** with a person (`carry.gd` can price; there is no counter).
- **Drive** (`arcade_vehicle.gd` is a lab chassis, not a route).
- **Command** a follower (`player_faction.gd` waits past the handoff).

A verb joins this table when its row has all seven columns filled — including the
object, and including the sound.

## Using it

- **Before building:** find the row. If it is missing, the work is design, not
  build, and the row gets written first.
- **Before commissioning art:** the asset column, top to bottom, is the order.
- **Before writing script:** the screen column shows every moment a line lands,
  and the record column shows what the line is allowed to know.
- **In review:** a build that adds a verb without a row is incomplete even if the
  test is green.
