# Prompts for the agents — 12 September 2026, after the rework

**Read `DESIGN/THE_REWORK.md` before anything else.** Greg wrote eighteen pages
setting out what this game is actually about, and it is the first document in the
project that answers *why* rather than *what*. It answers four of the five
questions that were formally blocked on him. Everything below assumes you have
read it.

Copy one block per agent. Each is self-contained.

**Every agent, first:** work in your own worktree, not in
`P:\GameDev\AllusionsTooGrandeur`. This has now cost us three separate incidents,
one of which left a half-finished merge that broke every run.
`git -C <your worktree> status` is the first thing you type.

Rules that apply to all of you:

- **I0**: no screen is a list of text in a box. It does *not* mean the player gets
  no information — that misreading stripped every readout out of the derby and
  produced the second playtest's first complaint. A gauge is not a text box.
- **Rule 3**: every hard cut is a bug.
- **The version ladder**: ticking `vN` means writing `vN+1` with a real fault it
  exposed. A version that cannot name a fault is not written.
- **Never claim a visual result you have not looked at.** Capture it, open the
  PNG, describe what is actually in it.
- **Wire what you build.** M2 was ticked off a screenshot and sat unused for
  days while the thing it was built for stayed broken. Do not repeat that.
- Satire aims at institutions — the agency, the bank, the military, the elite
  class, the godhead — and **never** at congregations, believers, or any group of
  actual people. Greg drew this line himself: *"not as much qanon shit, but just
  black magick and chaos magick."*
- No assets or implementations from commercial games. Experiential reference only.

---

## Agent A — the opening, and the body that cannot be killed

You have the spine of the game. Until now this project has been a sandbox with no
reason to be in it; the rework gives it a first hour, and AP1 is that hour written
down in order.

> *"you start as a captured spirit in the government facility underground, to be
> meat for the elites and scrap"* … *"they see the essence of his spirit as it
> can't be banished by torturing, killing, violence — it stays in pure bright
> flames that are vibrant and melt the game's screen"*

**The premise to hold on to: you are not powerful, you are unkillable, and that is
worse for everyone.** It is why an institution that could simply shoot you spends
the whole game trying to own you instead. Do not make the player strong early.
Make them impossible to get rid of.

1. **AP1.1–AP1.7 — the opening, in the order Greg gives it.** Captured underground
   as meat and scrap; the quiz (D already builds the intake sheet, reuse it, and
   AP1.2 says it must matter *mystically* rather than statistically); tortured and
   experimented on, revealed across the game rather than dumped at the start; the
   gore festival; the tunnel derby; out.
2. **AP1.5 is the big reframe. The derby is the escape, not a side mode.**
   `rift_derby.gd` already works and now has a cab, instruments, firing and a
   climb-out (AG3). What it does not have is a reason. Give it one: reptilians,
   aliens and bunker AI dwellers, and you are executing your way out of a
   facility. Do not rebuild the derby; re-situate it.
3. **AP2.1–AP2.5 — undying.** The spirit survives violence, and the game must
   prove this to the player early rather than telling them. AP2.2 wants the flame
   to *melt the screen itself* — that is a real shader, not a colour overlay.
4. **AN1.2–AN1.7 — wire up `limb_momentum.gd`.** It is built and tested (ten
   checks: a flick is worth 0.013, a committed sweep 0.346, same button). It is
   attached to nothing. Feed it the mouse delta the camera turns by plus the
   player's own velocity; draw the weapon through `pose()`; have damage ask
   `commitment()` instead of reading a constant off the weapon. **AN1.8: leave the
   old swing system in place until the new one is better**, side by side behind a
   flag.

Greg's pacing rule governs all of it: *"keep game super digestible segment to
segment, but also a possible playground if you want."*

---

## Agent B — the world at night

Everything in your block is immediately visible, and all of it now has something
to read from: `world_clock.gd` landed today, so there is a real hour, a real
night, a daylight curve and a month.

### AS — the lamp, the dark, and what you are wearing

> *"the light can become really warped at night and distorted. Phone has a %
> possibly, or just really minimal lighting, and you can wave it around showing
> lighting — as well as having light coming off the phone when you have it in
> your hand, then you can wave it around or pocket it… pockets and clothes should
> be integral, or at least a part of the world system, layers and strategy to
> everything."*

1. **AS1.1–AS1.5 — the handheld becomes a lamp.** It throws real light into the
   world when raised. Holding it up costs you the hand. A battery percentage that
   genuinely runs out. Pocketing it is a movement and the light goes with it. And
   AS1.5 is the one that makes it a mechanic rather than a torch: **its light is
   what gives you away at night.**
2. **AS2.1–AS2.4 — night.** Light *warps and distorts* rather than dimming.
   Minimal lighting is the default and a light source is a decision.
3. **AS3.1–AS3.4 — clothes and pockets as a world system**, not a paperdoll:
   weather, radiation, and who is willing to talk to you.
4. **AS4.1–AS4.5 — storms that answer the occult.** *"consistent crazy storms
   depending on spirits levels, chaos magick levels… the lightning needs to have
   anvil crawlers, all the crazy red lighting-esque things."* Weather is a
   **readout of how much magick is loose**, not ambience. Anvil crawlers are the
   long horizontal crawl across the underside of a storm, not a flash — get that
   right and it will be the best-looking thing in the build.

### AO2 and AO4 — the broken sky and what is out there

5. **AO2.1–AO2.5.** The firmament is visibly broken. A god for each planet, the
   moon and the sun, visible at certain hours — `WorldClock.hour()` gives you
   that for free.
6. **AO4.2–AO4.3.** Areas can be **haunted at night, and it is not permanent**.
   Demons, spirits and jinn infest parts of the map and *move*.

Do not touch `living_map.gd`, `satellite_view.gd`, `ballistics.gd`,
`blood_veil.gd`, `dash_cluster.gd`, `vehicle_interior.gd` or `rift_derby.gd`.

---

## What I am taking, so nobody duplicates it

- **AI + AR — the two charts.** The double pyramid (where power is) and the tree
  of life (which way you went). They are one document with two renderings and
  should be built by one person.
- **AQ — the godhead.** The taunting, the accumulating visibility, the summons.
- The build record page, which Greg has said looks bad and does.

## Already done today, do not redo

The derby cab and its instruments (AG3), blood on the lens, real ballistics with
casings and drop (AF1), the world clock (W1.1), station schedules (A9.7 v2),
kerning (A1.6 v2), run-salted grime (A5.6 v2), intermittent panel failure
(A6.6 v2), the gore/hitstop hole, the map's frame cost, the satellite being
invisible under its own chart, and the sprint jitter.

## Still blocked on Greg

1. **The Horsemen's names** (K2).
2. **AC1.1** — does this game have simulated fluid, or painted fluid done well?
