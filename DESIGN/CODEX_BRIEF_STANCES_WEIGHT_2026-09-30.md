# Codex brief: ragdoll weight, stances and per-weapon movesets (30 Sep)

```text
Load skills: wof-lane-hygiene, wof-wire-before-polish, wof-combat-fx,
maximizing-game-feel, running-headless-godot, godot-physics. Read
WORKING_NOW.md and DESIGN.md "Stated by Greg, 30 September 2026:
Souls-like third-person combat" first.

WORKTREE  git -C P:/GameDev/AllusionsTooGrandeur worktree add -b codex/stances
          P:/GameDev/worktrees/stances claude/launch-latest
          then Godot --headless --path .../game --import once.
          HEADLESS ONLY: no Godot windows on Greg's screen.

GOAL      Greg, 30 September: "third person fighting where the stances are
          different and we can start making different weapons", "like Dark
          Souls 1 2 3 Bloodborne ... way less buggy, super clean", ragdolls
          "funny, but also have weight", a huge sword sends a body flying
          "not heaps far", realistic but "an anime type fight".

PART 1    RagdollBody kick bug (yours, 6e785fcd). On a plain body and floor
          the torso's peak speed equals the impulse number in m/s (4 -> 4,
          10 -> 10, 16+ -> 16) instead of impulse x 0.12; a cleaver
          finisher slides the corpse 2.4-6 m, one hit 35 m/s. Repro:
          game/tests/zz_ragdoll_probe.gd/.tscn in
          P:/GameDev/worktrees/launch-latest (uncommitted; copy it). Fix it
          first and add impulse 16 and 30 cases to ragdoll_body_test.

PART 2    Weight. A corpse reads heavy: it folds at the joints and drops,
          does not skate or bounce, joint limits a human could reach, no
          jitter at rest. Blows scale it: a light kill slumps (under 0.5 m
          of travel), a heavy or running kill knocks it down and back
          (0.8-1.5 m), a poise-breaking heavy kill "sends it flying, not
          heaps far" (1.5-2.5 m, lifting off the floor briefly). The attack
          id reaches it the same way Knockback's does (Claude passes it in
          the attack dict as "attack"); take it through BaselineHuman's
          last-hit record (additive).

PART 3    Stances and weapons. SwordMoveset becomes a moveset per weapon and
          stance, data-driven: configure(weapon_id, stance) picks the table.
          Weapons already in HunterArsenal.WEAPONS: "sword" (the Ashline
          Cleaver, today's table), "shiv" (fast, short reach, low poise
          damage, a thrust chain), fists (bare: jabs, a hook, a shove that
          breaks poise but cuts nothing). Stances: "one_hand" and
          "two_hand" (Dark Souls' triangle): two-handed is slower, wider,
          more poise damage and stamina, and the running and roll attacks
          differ. Per-attack knockback and poise multipliers move into the
          moveset tables so Knockback reads them from the attack, not from
          its own id list (keep Knockback's API). R2 held charges the heavy
          (Bloodborne): request_heavy_release(held_seconds) with a charged
          version past a threshold that breaks poise outright.
          HunterBodyMotion: a guard/idle pose per stance and a swing pose
          per weapon (a thrust is not a slash), additive.

OWNS      game/systems/ragdoll_body.gd, knockback.gd, sword_moveset.gd,
          hunter_body_motion.gd, baseline_human.gd (last-hit record only),
          new files, their tests.
          Read-only: gore_demo.gd, psy_lab.gd, sandbox_avatar.gd,
          souls_pad.gd, bone_yard_hunt.gd (Claude wires stances and
          weapons into the sandbox and the pad: triangle for the stance).

PROOF     Tests print *_RESULT failures=N: ragdoll travel per blow class in
          the ranges above, nothing faster than 6 m/s, at rest and frozen
          within 3 s; each weapon's table differs (reach, timing, poise) and
          two-handed is slower and heavier than one-handed for the same
          weapon; a charged heavy breaks a full poise, an uncharged one
          does not; Knockback reads the multipliers from the attack.
          Existing suites stay green: --core, souls_roll, sword_moveset,
          knockback, ragdoll_body, body_motion, third_person_dodge,
          sparring, baseline_human, body_cut, gore_ (known headless
          timeouts: knockdown_test, gore_load_test, fight_sandbox_capture).

OPEN      Greg's (stop and report): exact weapon numbers beyond "the shiv is
          fast, the fists shove"; whether downed-but-alive bodies ragdoll.

OUT       No new weapon models or art, no aerial combat yet, no scene
          wiring, no VFX.

REPORT    What you could not verify, and pre-existing failures, as a list.
```
