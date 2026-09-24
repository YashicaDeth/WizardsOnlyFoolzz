# Black Mirror page-movement comparison

Status: **decision reel, not a production selection**. The mechanical shutter
remains the tested fallback until Greg chooses after seeing the candidates in
motion and hearing them.

All three candidates use the same contract:

- INDEX to MAP;
- 0.52 seconds total;
- the old live page remains until the work surface is fully occluded;
- the page activates and emits `mode_changed` at the hidden midpoint;
- the destination is revealed during the second half;
- digital tearing and cracked-glass resonance are present in every temporary
  sound sketch;
- generated audio is a timing and material concept awaiting authored sound.

## Candidate 1 — mechanical shutter

A ribbed dark plate travels in the direction of page movement. Ratchet teeth,
a low dragging rib and a short glass ring make it feel like damaged salvaged
hardware.

- Strongest quality: immediately readable physical movement.
- Risk: can make the Black Mirror feel like an ordinary industrial terminal.
- Evidence: `game/captures/phase2_transition_shutter.png`.

## Candidate 2 — cracked-glass corruption

Opaque data packets tear across alternating rows while short fracture paths
index the failure. Packet chatter and torn decode noise sit under the same
glass resonance.

- Strongest quality: the information and damaged mirror appear inseparable.
- Risk: without restraint it could become a familiar glitch transition instead
  of a physical property unique to this object.
- Evidence: `game/captures/phase2_transition_corruption.png`.

## Candidate 3 — occult carousel

Eight dark leaves index inward from the exact glass perimeter around a marked
central bearing. Wheel teeth, a detuned bell and glass resonance make page
selection resemble operating an occult instrument.

- Strongest quality: most clearly makes the apps positions inside one object.
- Risk: the large radial gesture is ceremonious and may feel too important for
  frequent navigation.
- Evidence: `game/captures/phase2_transition_carousel.png`.

## Comparison evidence

`game/captures/black_mirror_transition_comparison.mp4` is a 1280×720, 30 FPS,
9.13-second reel with an AAC stereo track. Each candidate receives the same
slate, resting time, movement time and arrival hold. The final slate explicitly
records that no selection has been applied.

Implementation is isolated by `HandheldDevice.page_transition_style` and
`set_page_transition_style()`. Invalid styles are rejected. The default stays
`shutter`, and `handheld_page_grammar_test.gd` verifies equal duration, full
occlusion, hidden midpoint activation, common sound grammar and preserved
fallback.

## Decision needed

Greg can select `shutter`, `corruption`, or `carousel`, or ask for one bounded
hybrid after watching the reel. Until then production code and captures should
continue to use `shutter`.
