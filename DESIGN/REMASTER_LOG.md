# Remaster log

One entry per remaster pass (see the dispatcher's remaster loop). Newest last.
Each entry: date, job, pass, the three gaps seen, what changed, PNG paths, what is still weak.

## 2026-10-05, Job 1 (mechanics lab), look before pass 1 (Claude, Opus)
Rendered with `tests/mechanics_lab_capture.tscn`, PNGs in `P:/GameDev/Temp/mechanics_lab/`.
- Works: all five stations load; the tank breaks and pools (16 pools); rain, wind, etch and the covered/open acid test run; ground holes and broken crates show.
- Weak: the liquid is a flat red decal plus loose red beads, not liquid (no surface, no flow, no splash; SPLASHES 0); no visible glass tank after the break; the weather shot reads as white streaks on a dark box; the yard is an untextured brown tray; placeholder text HUD in the corner; the held weapon is not visible; the melee is a camera ray, not the moveset (job 3 replaces it).

## Manager notes, 2026-10-05 02:18

- Merged since last entry: nothing. Running: 0. Every Claude account parked until 03:04 (alt2 04:54); codex-allusions-team 04:42, -plus 07:51, sircuteskingdom-team 07:14 (out of credits).
- Weak spot: `codex-sircuteskingdom-plus` shows "ready" in `hub.py status`, but its job5 log (01:14) says its usage limit lasts until **Oct 11, 12:21 PM**. The hub has handed job5 to it three times; the limit text ("Oct 11th, 2026 12:21 PM") seems not to be parsed into a park. Greg: check the park-time parser in hub.py (manager does not edit hub.py).
- Failures: `job2-rigged-bodies` superseded by pending `job2b-land-rigged-bodies` (priority 100). `lane-exit-routes` is an old lane task, left alone.
- Priority headers match the order (job2b 100 > lab-46 99 > lab-48 98 > lab-47 97 > job3 96 > job4/job5 95 > job6 94 > job9 93 > job7 92 > art-49 85 > backlog 40-46). No new task queued: pending already covers every account.
- Top three: (1) land job2b first when Claude accounts unpark at 03:04; (2) fix the codex park parser so job5 stops burning attempts; (3) job5/job7 are the only codex work, so with codex mostly parked until ~07:00 the facility map may slip; consider flipping job5 to `agent: any` if still pending at 07:00.

## 2026-10-05, Job 3 (moving and fighting), build pass (Claude, Opus)
Not rendered: `render_one.cmd` is not on this machine. `tests/v01_weapons_capture.tscn` is ready (writes held_*.png, cleaver_swing_NN, cleaver_hot, staff_shock_NN, pistol_ads, sparring_NN into `--shots=`).
- Built: HOTLINE CLEAVER and PRODSTAFF (Greg's working names) in `HunterArsenal`, `SwordMoveset` and `HeldGear`; `MeleeDriver` (buffer, hitstop, kick, stagger, heat, shock, block/parry); `SoulsMover` (tilt walk/run, sprint, crouch, roll); lab ADS and R3 lock-on; a sparring partner; the Growing Floor's fire axe is the cleaver.
- Dials (Greg's to decide, defaults mine): `MeleeDriver.heat_cost = "none"` ("overheat" built); `MeleeDriver.world_hitstop = true`; staff running/roll moves; parry window 0.24 s. Questions: `AgentHub/queue/questions/moving-and-fighting-01.md`, `-02.md`.
- Still weak: models are built in code, not CC0 downloads; the Hunt still issues the old `sword` (labelled ASHLINE CLEAVER) in its slot; the facility route has the cleaver in hand for the door but no melee fight wired yet (jobs 5/6 own those rooms; `MeleeDriver` is the piece to use); no sound on swings or hits; first-person swing is a pose offset, not an animated arm.
