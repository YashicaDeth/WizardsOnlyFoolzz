# greg-08 notes

Scope note: this chunk is almost entirely orchestration boilerplate and repeated agent-authored plans pasted into Greg's messages. Those pasted plans are context, not attributed to Greg below.

## 1. REQUIREMENTS

- 2026-09-19 — Live supervision must be fast enough not to create queues: "run quicker supervision so that it wont queue bs".
- 2026-09-19 — He wants active work made observable: "i want to see all the terminals going on".
- 2026-09-19 — He wants plain gameplay-status updates tied to actual engine activity: "upadting me gameplay with if anything is changed when goodt gets opened".
- 2026-09-19 — Keep checking the work rather than merely dispatching it: "keep checking and making sure its working".
- 2026-09-19 — Resume only preserved work relevant to the active task: "resume all the things in here that need to be resumed please that fit into this task".
- 2026-09-19 — Put the vat breakout in front of him to inspect: "launch this for to me to see the vat breakout stuff".
- 2026-09-19 — Use the ledger's efficient route to control work: "mack sure everything in the legder effucebnt route".
- 2026-09-19 — The management role is continuous, not a one-shot status report: "be a live manager".
- 2026-09-19 — No new direct requirements for world/map/tunnels/exits/weapons/combat/Black Mirror/characters/HUD/sound/art/performance appear in Greg's own words in this chunk.

## 2. DISLIKES / REJECTIONS

- 2026-09-19 — He dislikes opaque orchestration: "i honestly have no idea whats going on can you fix this".
- 2026-09-19 — Background work that looks unstable is unacceptable: "codex is doing stuff in the backround but its freaking out".
- 2026-09-19 — Queued supervisory churn is rejected: "so that it wont queue bs".
- 2026-09-19 — Exhausted Claude capacity must not stall the project: "all my claudes are used and i thinki its blocking progress".
- 2026-09-19 — A silently stopped headline task is unacceptable: "why is the demo strike task now not running".

## 3. DECISIONS

- 2026-09-19 — Put Codex, not the exhausted Claude pool, in charge: "switch so one of the codex agents is just in conyrtrol".
- 2026-09-19 — Keep the current ledger/Efficient Route as the organising authority: "mack sure everything in the legder effucebnt route".
- 2026-09-19 — The immediate user-facing review target is the vat breakout: "launch this for to me to see the vat breakout stuff".
- 2026-09-19 — No multiple-choice design answers appear in this chunk.

## 4. STILL OPEN?

- 2026-09-19 — **BUILT — vat breakout playable/visible.** Request: "launch this for to me to see the vat breakout stuff". Later session `01a0a9a2` records a responsive visible integration build at 13:59. Current route evidence: `game/vat_chamber.gd` owns the hands-on breakout and persists `opening_breakout`; `game/tests/hands_on_breakout_test.gd` covers it; `game/tests/first_thirty_route_test.gd` drives it in the real first-30 route. Historical visibility is evidenced by chat; this reading task did not render it.
- 2026-09-19 — **PARTLY — live manager, visible terminals, continuing gameplay updates.** Requests: "i want to see all the terminals going on" and "be a live manager". Session `01a0a9a2` shows a visible worker-owned build at 13:59, but by 14:30 reports the live-management layer as stale/unreliable and at 14:32 identifies replayed stale instructions. This was temporarily achieved, not durably reliable.
- 2026-09-19 — **PARTLY — resume everything relevant through the Efficient Route.** Request: "resume all the things in here that need to be resumed please that fit into this task". Current production evidence includes `game/vat_chamber.gd` and the real-route `game/tests/first_thirty_route_test.gd`; later searches show the vat-to-breakout route remained the canonical target. No repo or later-session evidence can prove the unbounded word "everything", and the same-day orchestration became stale.

## 5. WORLD / LORE / NAMES

- 2026-09-19 — **vat breakout** is the only game-world phrase Greg himself uses here: "the vat breakout stuff". He adds no place, faction, character, cosmology, or item name in this chunk.
- 2026-09-19 — Names such as Mara, Doctor, Derby, CellOutz, and the detailed 30-minute sequence occur only inside pasted agent-authored material here; they are not new Greg coinages in this chunk.

## 6. STYLE OF WORKING

- 2026-09-19 — Prefer rapid, active supervision over queued background churn: "run quicker supervision so that it wont queue bs".
- 2026-09-19 — Make parallel work legible to him: "i want to see all the terminals going on".
- 2026-09-19 — Explain current project/gameplay state in plain language: "what updates have happend so far gamewise".
- 2026-09-19 — Keep watching after dispatch: "keep checking and making sure its working".
- 2026-09-19 — Reuse relevant preserved work rather than indiscriminately restarting everything: "need to be resumed please that fit into this task".
- 2026-09-19 — Change coordinator when provider usage blocks progress: "switch so one of the codex agents is just in conyrtrol".
- 2026-09-19 — Show the real game when a gameplay checkpoint exists: "launch this for to me to see".
- 2026-09-19 — Follow the ledger's efficient route and keep a live manager: "be a live manager".

## 7. CONTRADICTIONS INSIDE THIS CHUNK

- 2026-09-19 — **None in Greg's own words.** Wanting faster supervision, visible terminals, gameplay updates, Codex control, and Efficient Route discipline is mutually consistent.
- 2026-09-19 — Apparent tensions in the pasted plan (quiet internal heartbeats versus visible status, or paused feedback gates versus continuous work) are agent-authored text and therefore are not counted as Greg contradicting himself.
