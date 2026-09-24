---
name: goal
description: The current goal for Wizards Only Fools and the ordered work queue that serves it - the first 30 minutes (Dust to Bones spine), Greg's build order, and what counts as done for each piece. Use when starting a session, when asked "what's next", "keep going", "continue the game" or "/goal", and before picking any new piece of work.
metadata:
  project: AllusionsTooGrandeur
---

# The goal

**The first 30 minutes of Wizards Only Fools play end to end**, from the vat
to the overworld, "a strong story and gameplay bond" (Greg, DESIGN.md):
character creation and the examination, the breakout, a facility escape that
teaches the basics by doing, and both routes out: the heat elevator and the
drain tunnels the derby became. Nothing in minutes 30-60 starts before
minutes 0-30 are right.

The Dust to Bones page is the map of this: one spine (the vat to the surface),
sixteen laws from `DESIGN/FINAL_V.md`, and finished systems lying unwired
beside the spine. **Assembly before invention**: wiring a built system into
the route is worth more than polishing anything that already runs
(`wof-wire-before-polish`).

## The queue, in Greg's order (24 September 2026)

Work top-down. Tick a line in this file when its piece is merged; add the
commit. Decisions behind every line are in `DESIGN.md` under the 24 September
answers.

- [x] **Hollis and the biometric door** (AX beat 5, AX3.3-AX3.4) in the Service
      Arcade: coerce him or put him down, his hand opens the door, his gun goes
      into Carry. `FacilityGuardPost`, merged at `c068775`.
- [x] **Death is rebirth in a vat.** You wake in the vat of whoever claims you
      (CellOutz, a rival, a cult). Nothing carried survives: gear, gun and
      clothes stay where you died to be looted or recovered. The character
      preset, memories and the world's record carry over. `VatRebirth`;
      filing the examination now saves the preset. Merged at `17557ec`.
      Still open: only Hollis can kill you on the route so far (the Lower
      Works sentinel and the derby do not), and the other claimants' vats
      share the Growing Floor scene until their rooms exist.
- [x] **Hollis escalates**: one warning shot, then wounds, then lethal; after
      killing you he knows you ("You again") and skips the warning. Merged at
      `17557ec`.
- [x] **The opening's wires beat**: END ALL SUFFERING, the player tears the
      umbilicals out (three tugs each), GET REVENGE, then the glass goes,
      instead of the automatic breach. Merged at `e437d5c`.
- [x] **Clothing renders on every rig.** Garments drew only their far inside
      (inward-wound shells, back-face culled); they now draw both faces.
      Merged at `1ff6af6`.
- [x] **The lab**: the floor light glitch (the breakout puddle's pale pixel
      disc) is a dark wet puddle at `3d03fa6`; Lower Works went from 2.8/255
      mean luminance (95% near-black, Forward+) to 15.3 at `2a7db79`.
- [x] **The VFX pack**: already built by earlier lanes (X-ray loading screen
      on failing film `41b4841`/`78f9071`, datamosh in place of the pixel wipe
      `6d3f092`, held-phone night vision `20747c2`, Wire and contract receipt
      paper `1d84e6e`, BlockTracker and Nerve Rig in the Hunt). The one fight in
      minutes 0-30 now has block-tracked hit markers too (`2a7db79`). Job
      posters and business cards wait (below).
- [x] **The heat elevator goes up to the overworld** (Greg, 24 September):
      `FacilityRoutes.ROUTE_HEAT_ELEVATOR`, surfacing at the old sallyport
      point. Merged at `796903d`.
- [x] **The drain tunnels route**: `old_drains.tscn` (waste gallery, cistern,
      storm outfall) walks the existing maintenance ascent and surfaces west of
      the start. Merged at `796903d`. `first_thirty_route_test` plays both
      routes end to end, into the Hunt.
- [ ] **Hollis gets a real model**, one Greg provides or picks (CC-BY credited).

After minutes 0-30 work end to end (Greg, 24 September): job posters with
tear-off tabs pasted on the Hunt's walls, and business cards handed over by
people you meet (kept in Carry, adding a Wire contact); the receipt-paper
`flyer` and `card` stocks in `ThermalPrint` are built for them and unused.

Waiting on Greg, not on an agent: removing Hollis's hand needs a blade the
facility has not given the player yet; where the D-section door should
finally sit; the Sketchfab anatomy downloads for the loading screen
(`P:\GameDev\Incomingnatomy`).

## Done means

A piece is done only when all of these hold:

1. **A player can do it** in the real route, not only in a test scene.
2. **It is recorded**: the world (`WorldHistory`, the ledger) remembers what
   the player did.
3. **It was seen**: rendered, the PNG opened and described
   (`wof-verify-by-looking`). Motion gets a clip.
4. **It is tested**: one small `tests/<name>_test` for the new behaviour, plus
   `tools/run_tests.sh --core` green (`wof-lane-hygiene`).
5. **It is merged** into `claude/dust-to-bones-look` once verified, then that
   branch goes into `codex/primary`.
6. **Greg can play it**: a Windows build is sent after each piece. Keep the
   editor bridge out of release; include LimboAI 1.8.1.

## How to run the loop

- Read the next unticked line, `grep` for what it calls, build the smallest
  version that satisfies "done", then tick it here.
- Anything that is Greg's to decide (lore, placement, feel) goes to him as
  question boxes with a recommended option first, and the answer goes into
  `DESIGN.md` the same turn. Never promote an assistant proposal to a rule.
- Stage by explicit path; never commit `.import`/`.uid` churn.
