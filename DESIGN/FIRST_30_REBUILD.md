# Rebuilding the first 30 minutes: the checklist

24 September 2026. This file combines the Dust to Bones map (its eight vertebrae,
its sixteen laws and the parts lying unwired beside them), everything Greg asked
for in both walkthroughs, and the assistant's recommendations. Assistant
recommendations are marked **(rec)**: they are proposals until Greg says yes.
Greg's own decisions live in `DESIGN.md`.

To run it, paste this into Claude:

> /goal Rebuild the first 30 minutes of Wizards Only Fools from
> `DESIGN/FIRST_30_REBUILD.md`. Work top-down and tick each line with its
> commit. Ask me question boxes, with the recommended option first, for
> anything that is mine to decide. Send a versioned Windows build after each
> piece.

## Done means

A line is ticked only when all of these hold:

1. A player can do it in the real route, not only in a test scene.
2. `WorldHistory` or the ledger records it.
3. It was rendered and the PNG opened; motion gets a clip.
4. It has a small test, and `tools/run_tests.sh --core` passes.
5. It is merged into `claude/dust-to-bones-look`.
6. Greg has a Windows build with the commit in its file names.

---

## 0. First, before any new work

- [ ] **Greg plays the current build and narrates it.** Log it in
      `playtests/2026-09-24.md`, with Greg's notes kept apart from his
      friends'. Turn every issue into a line in this file.
- [ ] **Merge what is waiting, once Greg says yes:**
  - the body-cam OSD HUD (`4acfb0b`)
  - the cybernetic spine (`c4853df`)
  - the two websites (`8abba5a`)

  All three are on `claude/cloud-session-handoff-hliuts`.
- [ ] **Make the site go live.** These are Greg's steps: Pages from `/docs`,
      the DNS records, a Release with the zip. The issue forms also have to
      reach the default branch.
- [ ] **(rec) Put a stopwatch on it.** Time each route from the first frame
      to the surface on the current build, and write the times here. "30
      minutes" should be a measured number.

---

## I. The spine: eight vertebrae, vat to surface

### 1. Data contracts: one world, one clock, one ledger
- [x] WorldHistory, WorldClock and the action ledger are read by every screen.
- [x] Death and revival fiction: you are regrown in the vat of whoever claims
      you (`VatRebirth`, `17557ec`).
- [ ] Retire or rename `RunLifecycle`. It still models "runs", and Greg said
      there are none.
- [ ] **(rec)** Replace `OpeningDeath` with `VatRebirth`, or wire it as
      VatRebirth's honest reload. Don't leave two death systems.

### 2. The examination: character creation as the institution making you
- [x] Full-height vat and reply panel; V thinks out loud (`6e5efb0`).
- [x] The examiner has an ordinary face, a bloodied coat and lip sync, plus
      the SUBJECT / TANK header (`ee7b9fa`).
- [x] Tabs print like receipts, blink icons, a transcript and stat gauges
      (`bda84ff`).
- [x] Each face slider moves only its own feature (`fd3e3dd`).
- [x] The examiner comes and goes by his own door behind the vat (`da96036`).
- [ ] A better 3D examiner model: authored or CC-BY, not the rig head.
- [x] Animated intake pages (first pass, drawn in the engine):
  - ink, blood, metal, and parts swinging out on gears
  - After Effects and Photoshop pieces allowed
  - *Built:* each page swings in on a riveted steel arm from a gear train at
    the form's edge, overshoots and settles. Ink bleeds behind the print
    head. Every page change runs blood down from the clip, and it dries
    there (up to four runs). `intake_pages_test`, clip from
    `intake_gui_capture -- --clip`. Hand-made After Effects or Photoshop
    pieces can replace any part of it.
- [ ] Use the intake's blank space (Walkthrough 2).
- [ ] Wire `AnatomyPresentation` (the explicit / mosaic option, equally
      complete).
- [ ] The doctor's name, history and vehicle. **Greg decides.**

### 3. The soul rewrites the chip
- [x] The wires beat: END ALL SUFFERING, three tugs per wire, then GET REVENGE
      (`e437d5c`), with the animated title card (`749449e`).
- [ ] Make the breakthrough readable as the soul seizing the implant:
  - the wetwire feeding back
  - the chaos-magick interface waking
  - not only "the glass breaks"

  This is the least-connected idea in the design graph. **Greg decides the
  exact beat.**
- [ ] When third person unlocks. **Greg decides.**

### 4. Learning by holding: no tutorial cards
- [x] Carry, inspection and held gear. The clothes come off failed subject
      0C-4.
- [x] The breach tool is visible, can be inspected, and breaches the gate
      (`cfa0cd2`, `da9b56a`).
- [ ] Carry icons: every item still shows the same placeholder.
- [ ] Breach-tool melee (part of the combat overhaul).
- [ ] How humiliating the jester outfit is, and how funny. **Greg decides.**

### 5. The biometric door
- [x] Hollis: coerce him or put him down, his hand opens the door, and his
      gun goes into Carry (`c068775`).
- [x] He escalates: a warning shot, then wounds, then lethal. After a death
      he greets you with "You again" (`17557ec`).
- [ ] Hollis gets a real model. **Greg picks it** (CC-BY, credited).
- [ ] Taking only his hand needs a blade the facility has not given you yet.
      **Greg decides where it comes from.**

### 6. The Black Mirror
- [x] Night vision and depth camera, once you hold the phone (`20747c2`).
- [ ] Confirm `BlackMirrorCamera` is called in the route. The map lists it
      as unwired.
- [ ] Map glitching (Walkthrough 2). Needs detail from Greg.
- [ ] Is the Board a wall in a room, or on the Mirror? **Greg decides.**

### 7. The escape branches
- [x] Heat elevator up to the overworld (`796903d`).
- [x] Old drains to the blood waterfall (`ca1353f`), with the bingyanger
      that hunts by sound (`34197f7`).
- [x] The doctor's route and his vehicle bay, a third way out (`0e968db`,
      `d085d5e`).
- [x] The derby as the secret route, out at the dry falls (`b362680`).
- [x] Support Unit: cameras, alarm, reinforcements, camera hacking
      (`c0c4559`, `0274a0d`).
- [ ] Every lethal thing in minutes 0-30 kills through `VatRebirth`: the
      sentinel, the bingyanger, the derby, the Support Unit. Only Hollis
      does now.
- [ ] Rooms for the other claimants' vats (a rival, a cult). They share the
      Growing Floor now.
- [ ] **(rec)** Extend `first_thirty_route_test` to the doctor's route and
      the derby route, so all four exits are played end to end.
- [ ] The derby:
  - brings every new system into it
  - its kill cam becomes a slow-motion cutscene of the real body being
    gored, not the green X-ray card (Walkthrough 2)

### 8. The surface handoff
- [x] Every route rises over the overworld and marks nearby settlements. The
      white light is gone (`6db3275`).
- [x] You surface at 10:00, and the decant pain eases over a minute
      (`60b7d87`).
- [x] Overworld random events (`89e292b`, `e3274fb`).
- [ ] The first minute on the surface asks something of you: a person, a
      job poster, a threat. It should not be empty ground.

---

## II. Greg's jobs from the walkthroughs that are still open

- [x] **The lab's cables:** intricate Lain / Evangelion wiring, not one long
      tube.
  - *Built:* the side conduit is gone. In its place are 336 cables in five
    sheaths: ceiling bundles hung from every bay, drops into every tank,
    slack across the floor to the walls, heavy swags over the aisle, and
    deep loops down the sides. A few lines glow. None hang below 2.95 m
    over the aisle, and none are solid (`lab_cables_test`).
- [ ] **More cameras,** and every door you can reach answers when you use it.
- [ ] **Brain Index hub:**
  - a large opaque overlay, with your 3D body in a vat on the right that you
    spin with the mouse
  - loadout on the left
  - tabs: Carry, Combat, Brain Index, Tasks, Map
  - kinship becomes a tab, which frees T
- [ ] **Handheld:** carry gets its own key. Make clear what I and U open.
- [ ] **Combat overhaul:**
  - omnidirectional swings on both sides
  - a skill curve you can learn and read
  - AI difficulty tuned to what is achievable
  - blood trees already exist (`d0afc4a`); wire them to the four styles
- [ ] **The spine,** futuristic and cybernetic (built, `c4853df`). Greg judges
      it in play.

---

## III. Recommendations (assistant proposals, not rules)

- [ ] **(rec) A sound pass per beat** (law 15): the vat draining, the wires
      tearing, Hollis's post, the lift, the drains, the falls. Anything
      silent now gets a sound that exists in the world.
- [ ] **(rec) A frame-time budget:** measure each scene in Forward+, write
      the numbers here, and fix anything over budget before adding more.
- [ ] **(rec) One controls sheet:** the same key caps in every scene, and
      the stranded `ControlBindings` branch decided on (merge or drop).
- [ ] **(rec) A build pipeline:**
  - one command that exports, zips with the commit in the file name, and
    writes the release notes
  - so every piece ends with a Release the site picks up
- [ ] **(rec) Fix the stale briefs:** the parts of `START_HERE.md` that
      describe a project that no longer exists (Dust to Bones section V).
- [ ] **(rec) A `wof-playtest` skill** for logging narrated playtests, and a
      `wof-build` skill for the release steps.
- [ ] **(rec) Before merging anything visual,** a clip of it in the real
      route goes on the site's footage section.

---

## IV. The sixteen laws, as a check on every line above

From `DESIGN/FINAL_V.md`. Before ticking a line, check it against the laws
that apply to its beat:

| Beat | Laws it must keep |
|---|---|
| The examination | 1 one anatomical truth · 9 two charts, one document · 14 every screen is an object |
| The wires / soul | 5 the blow is performed · 16 the psychedelic layer is a pipeline |
| Learning by holding | 8 the tutorial is a place · 6 a round is an object |
| The biometric door | 1 · 2 the world keeps two records · 7 everything breaks |
| The Black Mirror | 4 light is the resource · 14 |
| The escape branches | 3 time is real · 7 · 15 sound belongs to the world |
| The surface handoff | 2 · 3 · 11 the gods are what is worshipped |
| Death and rebirth | 13 the universe restarts; you do not |

---

## V. Waiting on Greg, not an agent

- Hollis's model.
- The Sketchfab anatomy downloads for the X-ray loading screen, saved to
  `P:\GameDev\Incomingnatomy`.
- The doctor's name, history and vehicle.
- The breakthrough beat, and when third person unlocks.
- The jester outfit.
- Where the Board lives.
- Where the blade for Hollis's hand comes from.
- The sky agency (the one merge-audit decision left).

## VI. After minutes 0-30 are right

- Start minutes 30-60: furthering the tutorial and the first settlement.
- Job posters with tear-off tabs on the Hunt's walls, and business cards from
  people you meet. The `ThermalPrint` flyer and card stocks are already built
  for them.
