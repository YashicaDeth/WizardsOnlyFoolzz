# Codex brief: ragdolls and Souls knockback (30 Sep)

```text
Load skills: wof-lane-hygiene, wof-wire-before-polish, wof-combat-fx,
maximizing-game-feel, running-headless-godot, godot-physics. Read
WORKING_NOW.md first.

WORKTREE  git -C P:/GameDev/AllusionsTooGrandeur worktree add -b codex/ragdoll
          P:/GameDev/worktrees/ragdoll claude/launch-latest
          then Godot --headless --path .../game --import once.
          HEADLESS ONLY: no Godot windows on Greg's screen.

GOAL      Greg, 30 September: "add ragdoll mechanics to the game" and
          "knockback to blows in third person like it's Dark Souls or
          Bloodborne". A heavy blow shoves a body back along the blow; enough
          of them (or one big one) breaks its footing into a stagger or a
          knockdown; a body that dies falls as a ragdoll in the direction it
          was hit, not as one stiff piece.

WHAT IS THERE NOW (measured)
          BaselineHuman (systems/baseline_human.gd, 2.3k lines) is a Node3D
          of zone parts in `rig.parts` (head, torso, arms, legs); there is
          NO Skeleton3D, so PhysicalBone3D does not apply. Going down is
          `_on_went_down()` (l.842): the whole rig tweens rotation.x to
          -0.46 PI, always forward, with optional `knockdown_travel` along
          its facing. Hits call HunterBodyMotion.trigger_stagger(from_local,
          severity) (systems/hunter_body_motion.gd l.203): a pose only, the
          body does not move. hit()/hit_at() already take `impulse` and
          `hit_direction` and return a result dict (damage, severed, zone).
          Severed limbs become physics chunks (systems/gore_chunks.gd): read
          how they are made and reuse that, do not invent a second path.
          The sandbox (gore_demo.gd) keeps bodies in `holder` Node3Ds on
          y 0.9 with the rig at -0.9; the floor is y 0.

OWNS      - new game/systems/knockback.gd (class_name Knockback, RefCounted):
            per body poise and shove. apply(impulse, direction, attack_id)
            -> {"shove": Vector3 metres, "stagger": 0..1, "knockdown": bool};
            tick(delta) -> the displacement to add this frame (eased, with
            ground friction), poise regen. Named consts at the top: poise,
            regen, shove per unit impulse, heavy multipliers by attack id
            ("light_1".."light_3", "heavy", "running_attack",
            "roll_attack" from systems/sword_moveset.gd), knockdown
            threshold. Pure: the owner moves its own holder.
          - new game/systems/ragdoll_body.gd (class_name RagdollBody): built
            from a BaselineHuman's zone parts at death: one RigidBody3D per
            zone with collision shapes sized from the part meshes, joints
            (ConeTwist/Generic6DOF, limits that read as a human, not a
            noodle), an initial impulse from the killing blow on the zone
            that was hit, settles and sleeps, then freezes to static after
            it settles so a room of corpses costs nothing.
          - game/systems/baseline_human.gd: ONE opt-in hook only. A config
            key "ragdoll": true makes death (anatomy.dead) hand the parts to
            RagdollBody instead of the tween; downed-but-alive keeps the
            tween. Everything else in the file is read-only. The killing
            blow's direction/impulse/zone must reach it (store the last
            hit's values in hit()/hit_at(), additive).
          - tests: knockback_test.gd/.tscn, ragdoll_body_test.gd/.tscn.
          Read-only for Codex: gore_demo.gd, psy_lab.gd, bone_yard_hunt.gd,
          sandbox_avatar.gd (Claude wires both components into the sandbox,
          then the Hunt).

RULES     Gore, anatomy, organs, dismemberment and the X-ray kill cam must
          never get worse (WORKING_NOW.md). A ragdolled body still reports
          its zones, still shows organs under X-ray, a limb severed before
          death stays severed, and hitting a ragdolled corpse still cuts
          (hit_at on a ragdoll part finds its zone).

PROOF     knockback_test: a light shoves less than a heavy; three lights in
          a row can break poise, one light cannot; the shove is along the
          blow; poise regenerates; displacement eases to a stop.
          ragdoll_body_test (headless physics, step the world): a body killed
          by a blow from +X ends on the floor on the -X side of where it
          stood; no part below y -0.05 or flying off (> 3 m) after 3 s;
          parts sleep then freeze; zones and X-ray still answer; a body
          without "ragdoll" in its config still uses the old tween
          unchanged; a limb severed before death is not re-attached.
          Commit message lists suites run; say nothing about how it looks
          unless it was rendered.

TESTS     Green before commit: tools/run_tests.sh --core, plus
          tools/run_tests.sh gore_ baseline_human anatomy kill_cam
          knockdown body_cut severed. knockdown_test, gore_load_test and
          fight_sandbox_capture time out headless on the base already
          (pre-existing, 30 Sep): report them, do not fix them in passing.

OPEN      Greg's (stop and report, do not choose): whether the player's own
          body ragdolls on death; whether downed-but-alive bodies ragdoll
          too; how far a heavy should shove (default: light 0.25 m, heavy
          0.9 m, running 0.6 m).

OUT       No new animations, no enemy AI, no wiring into scenes, no VFX, no
          edits outside OWNS.

REPORT    What you could not verify, and pre-existing failures, as a list.
```
