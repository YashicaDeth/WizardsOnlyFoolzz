# Combat loop: keep improving the sandbox fight until it is Souls-clean

Greg, 30 September: third-person combat "kind of like a Souls-like and
omnidirectional ... like Dark Souls 1 2 3 Bloodborne ... except make it way
less buggy, super clean", played on a PS4 pad, tested in the psychophrenia
sandbox (psy_lab.tscn) first and then brought into the full game. "Keep
smashing this out and refining it and doing performance checks and refining
combat, so you just cycle on continually improving where you find mistakes,
playtest it yourself." Full direction: DESIGN.md "Stated by Greg, 30
September 2026: Souls-like third-person combat".

## One iteration (both agents)

1. Sync: read WORKING_NOW.md; `git log --oneline -10` on claude/launch-latest;
   merge the other agent's finished branch into yours if it touches your
   files.
2. Measure before choosing: run the evidence below. Pick the ONE worst
   problem it shows in your lane (a failing check, the biggest ms, a
   visible bug in a capture, something Greg reported). Write it in
   WORKING_NOW.md under your name before editing.
3. Fix the root cause, smallest diff. Add or extend a test that fails
   without the fix.
4. Prove it: the suite you touched, the sandbox suites, `--core`. For
   anything visual, render it and open the PNG (wof-verify-by-looking);
   say in the commit what you looked at.
5. Commit by explicit path, message says what was measured before and
   after. Clear your claim in WORKING_NOW.md, add one handoff line.
6. Next iteration. Stop only when Greg says so, or when a decision is his
   (write it under "Greg decides" in WORKING_NOW.md and move on to the next
   problem).

## Evidence (run what applies, every iteration)

- `tools/run_tests.sh third_person_sandbox_test souls_pad_test
  sandbox_duel_test fight_sandbox_test gore_sandbox_combat_parity_test
  gore_sandbox_training_test souls_roll_test sword_moveset_test
  knockback_test ragdoll_body_test sparring_test` and `--core`.
- Frame time, windowed, real GPU: `tests/psy_lab_perf.tscn` (per-part
  cost) and `tests/psy_lab_soak.tscn` (a scripted two-minute fight that
  logs frame time every 10 s; the 30 Sep playtest dropped to 7 fps during
  real play while a fresh scene measures 160+). Budget: 6.25 ms (160 fps)
  idle, under 10 ms in a fight. A number that grows over the soak is a
  leak: find what accumulates.
- Captures: render the fight in third person (roll, light chain, heavy,
  block, parry, a poise break, a kill) and look at the PNGs.

## Windows

Headless by default. Playtesting yourself is allowed: ONE windowed Godot
at a time, on the right-hand monitor (`--position 2240,120`), closed when
done, and never while Greg's own game window is open unless you tell him
first. Use `APPDATA=P:/GameDev/Temp/<agent>` so agents do not share
user://.

## Lanes (split by file; never edit the other's files)

- Claude: game/gore_demo.gd, game/psy_lab.gd, game/systems/sandbox_avatar.gd,
  game/systems/souls_pad.gd, the sandbox enemy behaviour, the perf and soak
  harnesses, wiring every component into the sandbox and then the Hunt,
  refreshing P:/GameDev/playtest-latest after each green iteration.
- Codex: game/systems/sword_moveset.gd, souls_roll.gd, knockback.gd,
  ragdoll_body.gd, hunter_body_motion.gd (poses), baseline_human.gd
  (last-hit record only), the field HUD cost (gothic_field_hud.gd,
  Brief A), new combat components and their tests.
- A problem in the other lane goes under Handoffs in WORKING_NOW.md with
  the repro, not into their file.

## Quality bar (what "clean" means here)

- No input ever eaten, doubled or ignored; every verb works from pad and
  keyboard.
- Nothing merges into anything: bodies, weapons, the camera, the floor.
- Every blow reads: a telegraph before, hitstop and a reaction on contact,
  a shove along it, a sound. A miss costs something.
- Deaths have weight: the corpse folds and drops, never skates.
- 160 fps idle, no frame over 16 ms in a fight, no growth over the soak.
- Gore, anatomy, organs, dismemberment and the X-ray kill cam never get
  worse.
