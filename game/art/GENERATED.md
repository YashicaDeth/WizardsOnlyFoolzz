# Generated assets

Greg, 25 September 2026: "let them all use Higgsfield to generate." Every
generated asset in the game gets one line here, so it can always be told
apart from Greg's own art and replaced by it.

| File | Tool | Prompt | Date | Lane | For |
|---|---|---|---|---|---|
| `generated/sigils/rune_demonic.png` | Higgsfield | 1a, the rune, demonic | 2026-09-25 | A (breakout) | The sigil that takes your brain. Checkerboard was baked in; keyed by colour (red iron kept) and hole-filled. |
| `generated/sigils/metatron_plate.png` | Higgsfield | 1d, Metatron's cube | 2026-09-25 | D (loading screens) | Sacred-geometry loading plate. Baked checker cut with a circle mask. |
| `generated/sigils/sri_yantra_plate.png` | Higgsfield | 1d variation, Sri Yantra | 2026-09-25 | D (loading screens) | Sacred-geometry loading plate. Baked checker cut with a circle mask. |
| `generated/anatomy/xray_skull_bullet.png` | Higgsfield | 3b, skull and brain | 2026-09-25 | D (kill cam) | X-ray kill-cam plate. Black background, no alpha needed. |
| `generated/anatomy/xray_ribcage_bullet.png` | Higgsfield | 3b, ribcage and heart | 2026-09-25 | D (kill cam) | X-ray kill-cam plate. Black background, no alpha needed. |

Still to bring in (shared in chat as previews only; drop the files into
`game/art/generated/`): the doctor portrait (2a; crop the garbled text), the
full-body X-ray with chip (3a; crop the stamps), the septagram plate, the
natal chart, the Tree of Life and the heart X-ray.

Second set (25 September), waiting on `lfs.github.com` to push. Converted
and held outside the repo until then:

| File | Tool | Prompt | Date | Lane | For |
|---|---|---|---|---|---|
| `generated/video/loop_rune_pulse.ogv` | Higgsfield (Seedance) | V2, rune heartbeat | 2026-09-25 | A | Breakout sigil, load-in flash, title |
| `generated/video/loop_vat_xray_body.ogv` | Higgsfield (Seedance) | V1, X-ray body in the vat | 2026-09-25 | A | Torture load-in, intake right panel |
| `generated/video/loop_pyramid_orbit.ogv` | Higgsfield (Seedance) | V3, 33-tier pyramid orbit | 2026-09-25 | D | Pyramid loading screen, World Index |
| `generated/video/loop_satellite_scan.ogv` | Higgsfield (Seedance) | V4, satellite scan | 2026-09-25 | D | Phone MAP page |
| `generated/video/killcam_kidney.ogv` | Higgsfield (Seedance) | G7, kidney kill cam | 2026-09-25 | D | Kill cam |
| `audio/generated/hf_*.wav` (8) | Higgsfield (Seed Audio) | Section 9 sound list | 2026-09-25 | A | Names to confirm with Greg |

## Correction, 26 September (lane D)

None of the eleven files in the two tables above is in the repo. `git ls-files
| grep art/generated/` returns zero hits and `game/art/generated/` does not
exist here or in the main checkout. Treat those rows as a wish list, not a
record of assets that shipped. The real Higgsfield downloads were found at
`C:\Users\Greg\Downloads\yo\` (154 files); `tools/Import-Higgsfield.ps1` never
saw them because its `Get-ChildItem` is non-recursive over the Downloads root.

## Phase 3 breakout plates, 26 September (lane D)

From `yo\`, triaged against `DESIGN/HIGGSFIELD_ROADMAP.md` by eye. All are
2752x1536 RGBA, 5.5-9 MB, imported through LFS with no format conversion.
Source IDs are the untouched Higgsfield filenames.

| File | Tool | Roadmap ID | Date | Lane | For |
|---|---|---|---|---|---|
| `higgsfield/breakout/b1_seal_in_skull.png` | Higgsfield | B1 | 2026-09-26 | D | Seal inside a skull, veins, cracks glowing. Wired under the rune-in beat of `systems/brain_hack.gd`. |
| `higgsfield/breakout/b2_seal_to_die.png` | Higgsfield | B2 | 2026-09-26 | D | Seal shrinking into a CPU die, one acid-green path. Wired under the shrink beat. |
| `higgsfield/breakout/b3_die_hacked.png` | Higgsfield | B3 | 2026-09-26 | D | Die hacked, RGB split, tracking boxes. Wired under the hack beat. **Not cleared**: carries baked text "THE DIE HACKED: TERMINAL FAILURE DETECTED" plus garbled readouts, which breaks roadmap rule 2 (canon lines only) and contradicts the in-game card. Awaiting keep / re-roll / crop from Greg. |
| `higgsfield/breakout/b4_feed_cord.png` | Higgsfield | B4 | 2026-09-26 | D | Hands tearing the feed cord. Imported, **not wired** - see note below. |
| `higgsfield/breakout/b4b_forearm_wires.png` | Higgsfield | B4b | 2026-09-26 | D | Hands ripping forearm wires. Imported, **not wired**. |
| `higgsfield/breakout/b5_glass_burst.png` | Higgsfield | B5 | 2026-09-26 | D | Fist through tank glass. Imported, **not wired**. |

B4, B4b and B5 are first-person shots of hands doing the thing the player is
about to do in real 3D (`CORD_TUGS`, `WIRE_TUGS`, `GLASS_BLOWS` in
`vat_chamber.gd`). Dropping a still over those beats would hide the player's
own actions, so they are staged as material and the call is left to Greg.

## Proof

`tests/breakout_plate_capture.tscn` drives the real `vat_chamber.tscn` to the
hack and writes five frames windowed:

    Godot --path game res://tests/breakout_plate_capture.tscn -- --out=DIR

B1/B2/B3 are drawn under the procedural rune on the existing timeline; the
sequence still carries the beat on its own if the plates are removed.

Source files are in `DESIGN/HIGGSFIELD_ROADMAP.md` order. No piece here
overwrites Greg's own art: `game/art/higgsfield/` was an empty tree before
this commit.
