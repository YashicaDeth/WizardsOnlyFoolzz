# The spine

**What this fixes:** one row per thing the player does. The row names the system
that owns it, the record it leaves, the screen it appears on, the object it is in
the world, and the art and sound it needs.

It exists because the same three questions keep being answered three times:

- art needs a list of things to draw, in the order they appear;
- writing needs a list of moments where a line is spoken and by whom;
- build needs a list of verbs that must work before the slice is done.

This table is all three. If a mechanic has no row and is not named in the
backlog at the end, it is not in the game yet, whatever is in `systems/`.

**Rules**

1. One verb per row. "Fight" is not a verb; "land a blow", "block", "parry" are.
2. The **owner** is the one file allowed to decide it. If two files decide it,
   that is a bug in the row.
3. The **record** is what survives the scene. When nothing survives, the cell
   says what the absence is and where it lives (`scene state only`, `nothing
   filed`) — a bare `none` means nobody looked.
4. The **object** is where it physically is. Law 14: every screen is a thing in
   the world. If the object column says "menu", the row is not finished.
5. The **asset** column is the commission list. The **sound** column is what a
   listener must be able to identify with their eyes shut.

---

## Vertebra 1 — Data contracts

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Spend a minute | `world_clock.gd` | world minute, hour, phase | HUD clock strip | the sky through the firmament | sky states | per-room bed |
| Die | `vat_rebirth.gd` | death, killer, claim | death beat | the vat that claims you | vat body, cord | liquid, heartbeat stop |

**Opening death is that last row with a different owner.** `opening_death.gd`
reloads and records nothing on purpose (`opening_death.gd:36-39`: *"a death
that writes into the ledger is a death the world has taken a position on"*). Its
screen is the reload, which is the absence of a death beat, so it has no card to
draw and no new sound. It is not a second row: one verb, two owners, and the
empty columns are the design rather than an unlooked-up field.

## Vertebra 2 — The examination

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Answer him | `vat_intake.gd` | `character_sheet.gd` fields | intake pages; the feed above the glass | the form under your hands; the camera watching the tank | page furniture, ink, stamp; examiner head, camera rig | pen, paper, his voice, tape hiss |
| Shape a face | `face_model.gd` | sheet: face keys, build, height | FACE tab | the body in the vat | 3 model sheets minimum | the vat room's bed (`opening_audio.gd`, started at `vat_chamber.gd:385`); no per-slider voice |

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
| Ready a weapon | `hunter_arsenal.gd` (`select_slot`, `cycle`) | the held slot, scene state only — no world record | the HUD's weapon well (`gothic_field_hud.gd:721`) | the weapon in your hands | held weapon and arms models | holster, safety, slide |

## Vertebra 5 — The biometric door

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Coerce him | `facility_guard_post.gd` | `player_action_ledger` event | his speech | the guard, the reader | guard body, reader | voice, breath |
| Drag a body | `carry.gd` + ragdoll | smear, millilitres | the smear trail behind you (`blood_smear.gd`); no panel | the corridor floor | corpse drag poses | drag, wet |
| Offer a hand | `biometric_barrier.gd` | door opened | the reader's lamp | the reader | reader, lamp | accept, refuse |
| Take his gun | `facility_guard_loadout.gd` | carried weapon | held gear | BREACH NINE | gun model, hands | charging handle, three rounds |

## Vertebra 6 — The Black Mirror

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Raise it | `handheld_device.gd` | battery, wear | the pages | the slab in your hand | phone, jester back | servo, glass tap |
| See in the dark | `black_mirror_camera.gd` | `mirror_power.charge` (`black_mirror_camera.gd:61,83`) | the camera page's readout (`:41`), re-recorded at 10 Hz | the lens | green feed, gain | sensor whine |
| Read the map | `satellite_view.gd` | place read | MAP | the sky's own photograph | chart, contour | static |
| Take a photograph | `field_camera.gd` | `photo_album.gd` | album | the print | paper stock | shutter, print |

## Vertebra 7 — The escape branches

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Ride the lift | `facility_elevator.gd` | route taken | floor readout | the cab, the shaft | cab, lintel, shaft | motor, cable, chime |
| Walk the drains | `old_drains.tscn`, `drain_stalker.gd` | route taken, blood lost | the drains' own HUD — objective, status, prompt (`old_drains.gd:60-62`) | the outfall | drain kit, stalker | water, stalker |
| Haul yourself up | `jump_climb.gd` | what was climbed and how high: `drains_climbed_out` with its rise (`old_drains.gd:412`, `jump_climb.gd:58`) | the drains' prompt line (`old_drains.gd:62`) | the ledge | mantle cycle, ledge-grab poses | boot scuff, breath |

## Vertebra 8 — The surface handoff

| Verb | Owner | Record | Screen | Object | Asset | Sound |
| --- | --- | --- | --- | --- | --- | --- |
| Surface | `surfacing.gd`, `exit_reveal.gd` | place, hour | arrival reveal | the gate, the daylight | gate, yard, sky | wind, silence |
| Read a body | `world_xray.gd` | wounds, hardware | X-ray | the body in front of you | X-ray shell, organs | scan sweep |
| Land a blow | `melee_driver.gd` | wound, zone, cause | hit marker | the blade, the body | weapons, impact | whoosh, crack, wet |
| Guard against a blow | `melee_driver.gd` (`guard_held`, `receive_blow`) | stamina spent at 0.9 per damage; a guard at zero breaks and lets 60% through instead of 10% | the HUD's STA vessel (`gothic_field_hud.gd:486`) | the weapon held across your body | guard pose, caught-blow spark | blade-on-blade clang |
| Parry a blow | `melee_driver.gd` (`press_parry`, 0.24 s window) | `player_parried`, with the place, in the Hunt (`bone_yard_hunt.gd:5079`); the route writes nothing yet | the arms' answer (`first_person_arms.gd:120-125`) | the blade meeting the other one | parry pose and bounce | the ring of a turned blow |
| Roll out of a blow | `souls_mover.gd` (`start_roll`), `souls_roll.gd` | stamina spent (`souls_roll.stamina_cost()`, charged in `start_roll`, `souls_mover.gd:62-74`); no event | the HUD's STA vessel | the floor you roll across | roll cycle, dust | cloth, boot scuff |
| Break their poise | `melee_driver.gd` (`_stagger`, `STAGGER_AT` 0.45) | the `staggered` signal and the reel (`MeleeDriver.reel`); nothing filed | the reel and the smear it drags (`BloodSmear.follow_while`) | their body going down | reel and knockdown poses | grunt, ground impact |
| Catch your breath | `melee_driver.gd` (`_tick_resources`: 30/s after 0.55 s, none while guarding) | stamina only; nothing filed | the HUD's STA vessel | your own chest | breathing loop | breath, held and let go |
| Dress a wound | `field_meds.gd` | `field_dressing_used` with the heal (`field_meds.gd:47`) | the dressing line and its hold bar (`field_meds.gd:109,133`) | the dressing on the wound | dressing, tape, blood soaking through | tape, cloth |
| Be seen | `witness_ledger.gd` | who saw, did they live | awareness box | the person looking | the awareness box itself — faint amber corners and dashes (`block_tracker.gd:12,161`) | breath, step |

**On the record column for combat.** Only the Hunt's parry and the drains' climb
reach `WorldHistory`; guard, roll, poise and stamina are scene state. That is a
real gap in the fate ledger, not something to paper over with a field nobody
writes — the art and script lists still come out of the screen, object, asset and
sound columns, which are all filled here.

---

## Post-vertical-slice backlog

Written down so they are not lost, and not built by accident. Each is a real
system that cannot be a row yet, and the reason is the thing that has to change
before it can have one:

| Verb | What already exists | Why it is not a row yet |
| --- | --- | --- |
| **Publish a theory** | `pin_board.gd:528` calls the Wire's `expose`/`fabricate`; the board files `theory_published` and its own `published` list | The board is a `Control` opened by the capture (`tests/board_capture.gd:64`); nothing in the route opens it, so no player can reach the verb |
| **Petition a plane** | `plane_ladder.gd:205` prices an offering, checks the seal and the floor | Only tests call it (`tests/plane_ladder_test.gd:84-94`); there is no place, seal or altar for the player to stand at |
| **Trade with a person** | `carry.gd:303` prices an item, `:352` sells it, `skin_market.sell` and `witness_ledger.buy` exist | There is no counter and no person behind it — a buyer is a scene, not a system |
| **Drive** | `arcade_vehicle.gd` is a working chassis with tyre and engine forces | It is a derby lab body; no route has a vehicle the player can enter and the chase is not built |
| **Command a follower** | `player_faction.gd` can found a faction, recruit, lose a member and read its standing | Recruiting adds a name; nothing makes a recruit follow, stand or obey |
| **Sleep** | `world_clock.gd:224` can advance the clock and name the hour it lands on | Nothing in the game calls it outside tests; there is no bed or chair, so time advances by scene rather than by the player |

A verb joins the tables above when its row has all seven columns filled —
including the object, and including the sound — and at least one scene the player
can reach calls it.

## Using it

- **Before building:** find the row. If it is missing, the work is design, not
  build, and the row gets written first.
- **Before commissioning art:** the asset column, top to bottom, is the order.
- **Before writing script:** the screen column shows every moment a line lands,
  and the record column shows what the line is allowed to know.
- **In review:** a build that adds a verb without a row is incomplete even if the
  test is green.
