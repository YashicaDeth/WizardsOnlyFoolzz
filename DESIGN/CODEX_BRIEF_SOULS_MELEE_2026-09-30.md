# Codex brief: the Souls roll and the third-person sword moveset (30 Sep)

```text
Load skills: wof-lane-hygiene, wof-wire-before-polish, wof-combat-fx,
maximizing-game-feel, running-headless-godot. Read WORKING_NOW.md first.

WORKTREE  git -C P:/GameDev/AllusionsTooGrandeur worktree add -b codex/souls-melee
          P:/GameDev/worktrees/souls-melee claude/launch-latest
          then run Godot --headless --path .../game --import once.
          HEADLESS ONLY: Greg asked for no Godot windows on his screen.
          Render captures only if he asks, one at a time.

GOAL      Greg, 30 September: "a different style like a darksouls rolling
          dodging with good sword fighting", testable in the psychophrenia
          sandbox (psy_lab.tscn wraps gore_demo.tscn) in first AND third
          person. "Currently ... there is decent sword combat but it breaks
          in third person."

WHY IT BREAKS (measured, not guessed)
          The sword is LimbMomentum (systems/limb_momentum.gd) fed by mouse
          deltas: the swing's side, speed and commitment ARE the mouse.
          In third person the mouse orbits the camera, so the arm reads the
          camera turn as a swing. First person keeps drag swings (Greg's
          design, gore_demo "FIRST PERSON // DRAG YOUR SWINGS"). Third
          person needs authored attacks from buttons, aimed by movement
          input or the lock, never by the mouse.
          The dodge in both scenes is a 0.28 s slide (bone_yard_hunt.gd
          _dodge l.4856, gore_demo.gd _begin_dodge l.1620). HunterBodyMotion
          has a "dodge" state that only leans the torso 0.30 rad. The Hunt
          skips damage while dodge_remaining > 0 (l.5772, l.6150).

EXISTS    Use, do not rebuild: HunterBodyMotion (states, trigger_attack,
          set_combat_pose), BladeRead (sides, guard read, committed_side),
          HUNTER_MOTOR.dodge_direction, _combat_dodge_direction (lock-
          relative dodge, bone_yard_hunt.gd l.4886), StrikeHeading,
          HunterArsenal.begin_attack() (windup, range, damage per weapon),
          BaselineHuman.hit_at(), LockRing.

OWNS      New files only, plus one existing file:
          - game/systems/souls_roll.gd (class_name SoulsRoll, RefCounted or
            Node): start(direction, stamina) -> bool; tick(delta);
            is_invulnerable(); is_rolling(); velocity(); recovering().
            Numbers as named consts at the top: duration, i-frame window,
            distance, stamina cost, recovery, buffer window. Direction
            comes in from the caller (camera- or lock-relative).
          - game/systems/sword_moveset.gd (class_name SwordMoveset):
            light and heavy chains from button presses (light, light,
            light; heavy; running attack; roll attack), each with windup,
            active, recovery, stamina cost, a BladeRead side and an arc
            (start/end angle, reach, height) swept around the BODY's facing,
            not a camera ray. Input buffered in the last part of recovery.
            Returns what the owner needs to call hit_at(): the hit points
            along the arc per active frame and the side.
          - game/systems/hunter_body_motion.gd: a real roll pose for the
            existing "dodge" state (tuck, full forward rotation over the
            duration, recover), plus poses for each moveset swing
            (windup / strike / recovery, read from a moveset phase you pass
            in). Additive: existing states and their tests stay unchanged.
          - tests: souls_roll_test.gd/.tscn, sword_moveset_test.gd/.tscn.
          Read-only for Codex: gore_demo.gd, bone_yard_hunt.gd, psy_lab.gd
          (Claude owns those and wires your components in).

PROOF     Tests print SOULS_ROLL_TEST_RESULT / SWORD_MOVESET_TEST_RESULT
          failures=N and cover: i-frames only inside the window; no roll
          without stamina; roll input buffered during a swing's recovery
          fires on the first free frame; a chain resets after its window;
          a heavy costs more and hits later than a light; arc points sit
          in front of the body for yaw 0 and yaw PI/2 (so they follow the
          body, not the camera); the roll pose's torso turns a full
          rotation over the roll and ends upright.
          Commit message lists the suites run and says nothing about how
          anything looks unless you rendered it.

TESTS     Green before you commit: tools/run_tests.sh --core, plus
          tools/run_tests.sh body_motion third_person_dodge sparring
          fight_sandbox strike_heading.

OPEN      Greg's to decide (stop and report, do not choose): exact
          keybinds beyond the defaults below; whether first person also
          gets the moveset or keeps drag swings only; stamina regen rate.
          Defaults to build against: SPACE roll (existing), LMB light,
          hold LMB 0.35 s heavy, RMB guard (existing), Z lock (Hunt).

OUT       No parry rework, no enemy AI, no new weapons, no VFX beyond
          what wof-combat-fx says a swing already gets, no edits to the
          Hunt or the sandbox scenes.

REPORT    Back to Greg: what you could not verify, and any pre-existing
          failures you met, as a separate list.
```
