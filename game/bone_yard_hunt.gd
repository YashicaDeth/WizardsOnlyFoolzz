extends Node3D

# Ashbloom Expanse vertical slice. World Zero is the development milestone;
# Limbo is the realm; Ashbloom is this first irradiated region.
const PLAYER_SPEED := 7.0
const SPRINT_SPEED := 12.0
## AD1.1. Jumping worth doing. `HunterMotor.move_body()` already runs real
## gravity, air acceleration and floor-stick every physics frame and nothing
## ever gave it an upward velocity to work with — the whole vertical half of
## a platformer was sitting there unused. Tuned against `HunterMotor.GRAVITY`
## (22.0) for roughly a one-metre apex: `sqrt(2 * 22 * 1.0) ≈ 6.6`.
const JUMP_IMPULSE := 6.6
## AD1.2. "Waist-high things stop being walls." Three raycasts decide it: a
## low one finds a real obstacle in front of the player at all, a high one
## tells a low obstacle from a real wall, and a downward one finds exactly
## where the thing's top actually is rather than guessing one fixed height
## for every crate, rail and curb in the world. Scoped to obstacles a body
## can plausibly get a hand on and be past a moment later — a real wall
## keeps failing the high check and stays a wall (AD1.3's problem, not this
## one's).
const VAULT_MIN_TOP := 0.32
const VAULT_MAX_TOP := 1.35
## AD3.2. What a leg with drive hardware in it raises that ceiling to.
## Chest height rather than head height on purpose: augmented legs make a
## chest-high barrier passable, they do not make walls stop being walls,
## which would take AD1.3's wall-running away from itself.
const VAULT_MAX_TOP_AUGMENTED := 1.95
const VAULT_REACH := 0.85
const VAULT_FAR_SIDE := 0.55
const VAULT_HEAD_CLEARANCE := 1.55
const VAULT_DURATION := 0.34
## AD1.3. "Earned the way third person is earned rather than given" —
## `third_person_unlocked()` gates on real boss kills; this gates on real
## traversal, tied to the mechanic it is a step up from rather than to
## combat, since wall-running is a movement skill and vaulting is the
## movement skill just before it. Counted straight off `player_vaulted`
## (AD1.2's own event), not a new counter invented for this one.
const WALL_RUN_UNLOCK_VAULTS := 3
## How far sideways the wall can be and still count, how tall it has to
## keep going to be a wall rather than something AD1.2 would have vaulted,
## how fast the player has to already be moving to grab one, how long a
## run lasts before gravity wins anyway, and how much gravity still applies
## while it does — full weightlessness reads as flying, not running.
const WALL_RUN_REACH := 0.9
const WALL_RUN_MIN_HEIGHT := 1.7
const WALL_RUN_MIN_SPEED := 4.0
const WALL_RUN_DURATION := 1.1
const WALL_RUN_GRAVITY_SCALE := 0.16
const WALL_RUN_KICKOFF_UP := 5.2
const WALL_RUN_KICKOFF_OUT := 5.0
## AD1.4. A wall too tall for `_vault_target()`'s own high check, dead ahead
## rather than to the side — the third rung of the same ladder vaulting and
## wall-running already are. Gated on real kickoffs rather than a new
## invented counter, since climbing is what wall-running was training for.
## Duration is a real cap, not a promise of free climbing to any height —
## the honest route up a tall building chains a climb into a mantle the
## instant one comes within reach, same as `_wall_run_surface()`'s own wall
## running into `_vault_target()` never needed a run system that could climb
## forever either.
const CLIMB_UNLOCK_KICKOFFS := 2
const CLIMB_REACH := 0.85
const CLIMB_SPEED := 5.4
const CLIMB_MAX_DURATION := 2.6
const CLIMB_STAMINA_DRAIN := 30.0
## Worst case a wrecked body can move or swing at, as a share of healthy. The
## soulslike register wants injury to hurt; it does not want a player who has
## lost a leg to be unable to disengage from the thing that took it.
const PLAYER_INJURY_FLOOR := 0.55
## The person the hunt is about. Generated per save — see `cast_names.gd`.
const CAPTAIN_SLOT := "derby_captain"
## AP1.6. Matches `rift_derby.gd`'s own `RINGMASTER_SLOT` — the same
## `CastNames` slot string, so `CAST.id_for()` resolves to the same generated
## person on both sides of the scene change.
const RINGMASTER_SLOT := "ringmaster"
const CAST := preload("res://systems/cast_names.gd")
const FRIEND_ID := "nix_arden"
const HUNT_LOCATION := "ashbloom_bone_yard"
## H10.8. Rest is attached to one reachable thing in the world, not a menu
## button that can advance the ledger from anywhere.
const SLEEP_SITE_POSITION := Vector3(2.6, 0.05, 18.0)
const SLEEP_REACH := 3.4
const SLEEP_WAKE_HOUR := 7.0
const HANDHELD := preload("res://systems/handheld_device.gd")
const ANATOMY_COMPONENT := preload("res://systems/anatomy_component.gd")
const WORLD_GENERATOR := preload("res://systems/ashbloom_world_generator.gd")
const MISFIRE_DIRECTOR := preload("res://systems/reality_misfire_director.gd")
## AP1.6. Was `preload()` — evaluated at script compile time, which meant
## every load of `bone_yard_hunt.gd` (this script is often compiled on a
## background thread as part of `Interstitial.travel()`'s threaded scene
## load) raced `rift_derby.gd`'s own independent `preload()` of the exact
## same resource in the scene being left. Confirmed as the cause of a real,
## pre-existing bug: derby -> Hunt transitions failed to load at all
## ("Could not preload resource file res://art/scrap_skiff.glb"), reproduced
## on the original, unmodified derby's own win path, unrelated to anything
## the colosseum added. `load()` at the one real call site below happens at
## runtime, long after both scripts have finished compiling, which removes
## the race entirely rather than only hiding it.
const SCRAP_SKIFF_PATH := "res://art/scrap_skiff.glb"
const HUNTER_MOTOR := preload("res://systems/hunter_motor.gd")
const LIVE_BODY_MIRROR := preload("res://systems/live_body_mirror.gd")
const BLOOD_VEIL := preload("res://systems/blood_veil.gd")
const PSYCHEDELIC_RIG := preload("res://systems/psychedelic_rig.gd")
const FIELD_LENS := preload("res://systems/field_lens.gd")
const HELD_ITEM_RELIQUARY := preload("res://systems/held_item_reliquary.gd")
const DROPPED_HANDHELD := preload("res://systems/dropped_handheld.gd")
const STORM_WEATHER := preload("res://systems/storm_weather.gd")
const PERCEPTION := preload("res://systems/perception.gd")
const GLITCH_SPIDER := preload("res://systems/glitch_spider.gd")
## AE1.1. Beyond this, nobody hunting the player needs a light/noise/cover
## verdict at all — the same reason `storm_weather.gd`'s exposure only
## starts mattering past a real severity, not from the first drop of rain.
const PERCEPTION_MAX_RANGE := 30.0
## The screen spills some light back onto its holder, but much less than the
## beam broadcasts its own source. That gap is C7.1's warning interval: a
## hunter can notice the light before resolving the body behind it.
const HANDHELD_BODY_LIGHT := 0.25
const PSYCHEDELIC_OSC := preload("res://systems/psychedelic_osc.gd")
const KEYS_CARD := preload("res://systems/keys_card.gd")
## AS1.1. Bright enough to actually read as a light source against
## `world_look.gd`'s low-ambient presets rather than a glow nobody would notice.
const HANDHELD_LAMP_ENERGY := 6.0
const HANDHELD_LAMP_BASE_POSITION := Vector3(0.16, -0.14, -0.15)
const HANDHELD_LAMP_BASE_ROTATION := Vector3(-6.0, 4.0, 0.0)
const HANDHELD_WAVE_POSITION := Vector2(0.28, 0.16)
const HANDHELD_WAVE_ANGLE := Vector2(18.0, 10.0)
const BALLISTICS := preload("res://systems/ballistics.gd")
const LIMB_MOMENTUM := preload("res://systems/limb_momentum.gd")
const HUNTER_ARSENAL := preload("res://systems/hunter_arsenal.gd")
const HUNTER_BODY_MOTION := preload("res://systems/hunter_body_motion.gd")
const RIVAL_REGISTRY := preload("res://systems/rival_registry.gd")
const RIVAL_TACTICS := preload("res://systems/rival_tactics.gd")
const HUNT_MEMORY := preload("res://systems/hunt_memory.gd")
const OFFSCREEN_HUNTS := preload("res://systems/offscreen_hunts.gd")
const DEFEAT_ROUTER := preload("res://systems/defeat_router.gd")
const ASSET_NETWORK := preload("res://systems/asset_network.gd")
const COMBAT_RESPONSE := preload("res://systems/combat_response.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")
const HELD_GEAR := preload("res://systems/held_gear.gd")
const SMOKEABLES := preload("res://systems/smokeables.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")
const LIVING_MAP := preload("res://systems/living_map.gd")
const ASHBLOOM_HOLDINGS := preload("res://systems/ashbloom_holdings.gd")
const LOCAL_LAW := preload("res://systems/local_law.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")
const WORLD_INDEX := preload("res://systems/world_index.gd")
const PIN_BOARD := preload("res://systems/pin_board.gd")
const DEMO_WALL := preload("res://systems/demo_wall.gd")
const IMPACT_FEEL := preload("res://systems/impact_feel.gd")
const CARRION_SCAVENGER := preload("res://systems/carrion_scavenger.gd")
const RITUAL_LEDGER := preload("res://systems/ritual_ledger.gd")
const SUBSTANCE_STATION := preload("res://systems/substance_station.gd")

var player := Vector3(0, 1.5, 19)
var sleep_site: Node3D
var sleep_prompt_hold := 0.0
var yaw := PI
var pitch := -0.12
## Greg, 2026-09-12: *"the game should start probably in first person with the
## insane fov style cruelty squad"* — *"you unlock third person once you get
## melee weapons and bossfights through the nemesis system"*.
##
## So the camera is progression rather than a preference. You begin locked
## inside your own head at a field of view wide enough to be uncomfortable, and
## the game only lets you step outside yourself once you have earned it. That is
## the right way round for this project: third person is the abstract view, the
## one where you look at yourself as an object, and it should cost something.
##
## The condition is read out of `WorldHistory`, never stored — the same rule the
## Board runs on, so there is nothing to get out of sync.
var third_person := false
## M1.5. `third_person_unlocked()` is a pure read of history, so it can flip
## from false to true on any frame — usually the instant a boss-tier kill
## resolves — with nobody pressing anything. Left alone that is a permission
## quietly granted in the background: you would only ever find out by trying
## the key. This edge-triggers once, off that same read, so the moment itself
## gets a beat instead of waiting to be discovered.
var third_person_unlock_announced := false
## M4.3. Wide, and deliberately so — but stated correctly, which the first pass
## was not. Godot's `Camera3D.fov` is the **vertical** angle (keep_aspect
## defaults to KEEP_HEIGHT), so the 106 written here first meant 134 degrees
## horizontal at 16:9. That is a fisheye lens, not a wide lens, and it is well
## past anything Cruelty Squad does.
##
## These are the vertical angles that produce the horizontal ones actually
## wanted: 78 gives ~110 degrees across, 63 gives ~95. Keeping the vertical
## angle fixed is also the correct choice for ultrawide monitors — they then
## show *more* of the world at the sides rather than cropping off the top.
const FIRST_PERSON_FOV := 78.0
const THIRD_PERSON_FOV := 63.0

## M4.2. Where the eye actually is. The capsule is 1.8 m tall with its origin at
## the centre, so the feet are at -0.90 and the camera at +0.60 was looking out
## from 1.50 m — the eye line of someone about 1.6 m tall wearing a 1.8 m body.
## That is a sixth of a metre of error on every judgement of scale the player
## makes, and at a wide FOV it reads as the world being slightly too big.
const EYE_ABOVE_CENTRE := 0.78
const STANDING_HEIGHT := 1.8
## The two things that unlock it.
const UNLOCK_BOSSES := 1
var stamina := 100.0
var health := 100
var attack_cooldown := 0.0
## O2.4. Guarding. Dodging already existed and was already consulted on
## incoming damage, which made evasion real — but it was the *only* defensive
## option, and one option is a reflex rather than a decision. A guard you hold
## gives the player a second answer with a different shape: safer, slower, and
## it costs you the initiative instead of costing you stamina in a burst.
##
## The first fraction of a second of raising it is a parry rather than a block,
## which is where the decision actually lives: hold early and you are merely
## safe, time it and you take the initiative back.
## O5.1. A swing has to come from somewhere. Until now every blow was identical
## regardless of what the body was doing when it was thrown: the same damage
## standing still, backpedalling, or running somebody down. That is what makes
## melee read as a button rather than as a weight on the end of an arm.
##
## Two things carry the momentum. **Where the weapon was**: swings alternate
## sides on their own, so continuing the natural arc is quick and cheap while
## re-swinging the same side has to drag the blade back first. And **where the
## body was going**: stepping into a blow lends it your own mass, backing away
## takes it out again.
## O5.7. Footing. Enemies have had a `staggered` state for a while; the player
## has had nothing. That asymmetry is what makes a brawl read as a player
## hitting statues rather than as two bodies leaning on each other — you could
## over-commit, whiff, get blocked and take a shove, and still be standing
## exactly as square as when you started.
##
## Footing is spent by things that should cost balance and recovers by standing
## in it. Below `STUMBLE_AT` you are stumbling: the guard will not hold, the
## swing has nothing behind it, and moving is a negotiation.
## O5.8. Bare hands. The arsenal hands the player three weapons at spawn and
## never takes them away, so "unarmed" was not a state this game could be in —
## which makes "the body is the weapon system" a claim the build could not
## actually support. Pressing 5 puts the weapons down.
##
## Viable and horrible, in those words. **Viable**: fast, cheap in stamina, and
## it reads through the same anatomy, footing and momentum every other blow
## does, so a fit body in a good stance is genuinely dangerous with nothing in
## its hands. **Horrible**: a third of the reach of a cleaver, so you have to
## stand inside somebody to use it, and it breaks rather than opens — no cuts,
## no severing, just blunt damage to a face at arm's length.
var bare_handed := false

var footing := 1.0
const STUMBLE_AT := 0.3
const FOOTING_RECOVERY := 0.55
const FOOTING_WHIFF := 0.14
const FOOTING_BLOCKED := 0.2
const FOOTING_SHOVED := 0.34
## O6.1. "You can be disarmed, and so can they" — AN2.2 built the player's
## own half off `arm.fatigue`; an encounter actor has no arm object, but it
## already has the same shape of number in `footing` (O5.10 v2's own "same
## meter, same constants, now on both bodies"). Barely standing (below the
## line a stumble already uses) and hit hard enough to stagger is the NPC
## reading of "barely held and hit hard"; footing recovering back past the
## same line is them getting a grip on it again, the same way stamina
## recovering lets the player draw a weapon back out.
const NPC_UNARMED_DAMAGE_SCALE := 0.35
const NPC_UNARMED_CYCLE_SCALE := 0.7
## AN2.1. Scales `last_commitment` (0..1) into a footing cost paid the instant
## a swing is thrown, hit or miss — a flick costs about what a whiff already
## does; a hard committed sweep costs as much as being shoved. Whiffing still
## adds its own `FOOTING_WHIFF` on top, so a committed swing that also misses
## pays for both, which is the whole point: a flick has nothing to lose twice.
const FOOTING_COMMITTED_SWING := 0.32

## AN2.2. `arm.fatigue` (AN1.6, straight off stamina) is already "how loosely
## you are holding it" as a real number. Deterministic rather than a coin
## flip on top of it — the same hit, the same fatigue, the same outcome every
## time — because this project's other thresholds (severing, footing) all
## work the same way and a random disarm would be the one hit in the game a
## player could never learn to read.
const DISARM_FATIGUE_THRESHOLD := 0.75
const DISARM_DAMAGE_THRESHOLD := 14.0

var swing_side := 1
var last_swing_at := 0.0
const SWING_CHAIN_WINDOW := 0.9
const SWING_REVERSE_PENALTY := 1.4
const STEP_IN_BONUS := 0.55
## O5.11 v2. Smaller than STEP_IN_BONUS on purpose: stepping into a target is
## the dominant read of a committed swing, and arc alignment is a real but
## secondary refinement of it, not a second axis worth as much as the first.
const ARC_STEP_BONUS := 0.25

var guarding := false
var guard_raised := 0.0
var guard_stamina_drain := 14.0
## AG4.1. Out of breath. Set when stamina bottoms out, cleared only once enough
## has come back to be worth spending — see `_move_player`.
## AG4.2. Blood on the lens. Fed by `_spawn_blood`, which every blood event in
## the scene already goes through.
var blood_veil: Control = null
## AF1. Rounds in flight, brass on the floor, holes in the walls.
var ballistics: Node3D = null
## AF1.1. One trigger pull's worth of rounds still in flight, keyed by an
## id unique to that pull. A pellet lands on a body, lands on the world, or
## runs out of range — `_settle_shot()` counts down `remaining` regardless
## of which, and the miss/hit feedback (and the aggregate `weapon_fired`
## record) fires once, when the last pellet's fate is actually known,
## rather than on the frame the trigger went down.
var _shot_counter := 0
var _pending_shots: Dictionary = {}
## AN1.2. The arm the weapon hangs off. Fed the same mouse delta the camera
## turns by, so the weapon is thrown by you turning rather than by a curve.
var arm: LimbMomentum = null
## Mouse movement this frame, in radians, accumulated in `_unhandled_input` and
## spent in `_physics_process`. It has to be a frame total rather than a
## per-event value: a 1000Hz mouse delivers several motion events per frame and
## handing the arm each one separately throws it several times as hard.
var _look_delta := Vector2.ZERO
## AN1.4/AN1.8/O5.1 v5. Whether `commitment()` reaches the damage number.
## Judged with a controller in hand rather than in a commit, per Greg,
## 2026-09-14: flipped on. The old flat click-to-swing number is no longer
## authoritative — a flick now measurably underperforms a committed sweep
## instead of matching it, which is the entire point O v5 was raised for.
var momentum_damage := true
## What the arm was worth at the moment of contact, kept so the HUD and the
## record can read the blow that actually happened rather than the intent.
var last_commitment := 0.0
var winded := false
## How much stamina it takes to break into a run again after being winded. Well
## clear of the floor, so the two thresholds can never be crossed in one frame.
const SPRINT_RECOVER := 22.0
## The speed the legs are actually doing, as opposed to the speed being asked
## for. Smoothed, so a gait change is a change rather than a jump.
var _gait_speed := 0.0
const PARRY_WINDOW := 0.18
const GUARD_DAMAGE_SCALE := 0.28
var dodge_cooldown := 0.0
var story_step := 0
var panel_mode := ""
var enemy: Node3D
var friend: Node3D
## O3.1. Was decremented by a flat number per hit regardless of where — or
## even whether — the blow touched `enemy_rig`, which meant a fight resolved
## by damage total rather than by where you actually put it. This is now
## derived from her real zone health every time a hit lands, and does not
## track any wound of its own, so a devastated zone genuinely stops paying
## out and where you spread the damage decides how the fight goes.
var enemy_health := 100
var enemy_health_max := 100
var enemy_retreating := false
var pulse := 0.0
var generated_world: Node3D
var misfire_director: Node3D
var encounter_actors: Array[Dictionary] = []
var loose_loot: Array[Node3D] = []
## AU3.5/AU3.6. The same station the shed and the sandbox drop. Nothing
## here lays substances out on its own, so the Hunt Grounds cannot fall
## behind what the sandbox offers - it is the same object in all three.
var substance_station: Node3D
var mara_encounter_number := 1
var player_body: CharacterBody3D
var player_rig: BaselineHuman
var player_collider: CollisionShape3D
var player_capsule: CapsuleShape3D
var body_motion: Node
var hunter_appearance: Node
var crouching := false
var strike_windup := -1.0
var rival_attack_clock := 0.0
var dodge_remaining := 0.0
## AD1.1. Set on the keypress, consumed the next physics step. Not applied
## directly in `_unhandled_input` — the impulse has to reach
## `HunterMotor.move_body()` itself and ride the same `move_and_slide()` call
## that will actually carry the body off the ground; see that function's own
## comment for why a frame's delay either way stomps it back to the floor.
var jump_queued := false
## AD3.2. How many mid-air kick-offs have been spent since the last time the
## body was on the ground. Reset by touching down, so the hardware grants one
## extra departure rather than flight.
var kick_off_spent := 0
var dodge_direction := Vector3.ZERO
## AD1.2. How long is left of the current vault, counting down from
## `VAULT_DURATION`; the body is not under normal movement control for as
## long as this is positive (see `_update_player()`'s own early branch).
var vaulting_time := 0.0
var vault_from := Vector3.ZERO
var vault_to := Vector3.ZERO
## AD1.5. The horizontal speed the body was carrying the instant it left
## the ground for this vault, handed straight back the moment the lerp
## ends. A vault is a scripted position takeover, not a physics flight, so
## `player_body.velocity` sits unread for its whole duration; without this,
## it also sat unread at zero, and normal movement's own `move_toward`
## acceleration had to rebuild a run from a dead stop on the far side of
## every single obstacle — a stutter this segment's own wording names
## directly ("run into vault... is one motion").
var vault_entry_velocity := Vector3.ZERO
## AD1.6. The actual duration this specific vault was given, scaled by
## anatomy at the moment it started — `vaulting_time` counts down against
## this, never against the flat `VAULT_DURATION` constant, since a hobbled
## vault is deliberately handed more than that.
var vault_duration := VAULT_DURATION
## AD1.3. Positive for as long as the wall is still carrying the player;
## re-checked and re-set every frame it runs rather than only at the start,
## since the wall the player is running along can curve or end mid-run.
var wall_running_time := 0.0
var wall_run_normal := Vector3.ZERO
var wall_run_kickoff_queued := false
var wall_run_unlock_announced := false
## AD1.4. Positive for as long as the wall is still there to climb;
## re-checked every frame the same way `wall_running_time` is, and the
## direction it started with is what both the re-check and the mid-climb
## mantle attempt read, since the player is not steering sideways off a
## climb the way they can steer along a wall run.
var climbing_time := 0.0
var climb_direction := Vector3.ZERO
var climb_normal := Vector3.ZERO
## AD1.5. The run speed the climb itself replaced — while climbing,
## `player_body.velocity`'s horizontal part is only ever the small press
## into the wall, not the sprint that got the player here, so a mantle
## chained straight off it (see the `climbing_time` block) hands that back
## to `_vault()` instead, the same way a running vault would.
var climb_entry_speed := 0.0
var climb_unlock_announced := false
var handheld: Control
var dropped_handheld: RigidBody3D
var dropped_handheld_save_timer := 0.0
## FINAL_V.md §16. The one screen-space layer AS2's night warp, and later the
## drugs and shadow realms, all reach for instead of building their own effect.
var psychedelic: Control
var field_lens: Control
var held_reliquary: Control
## AG2. What can be pressed, when somebody asks.
var keys_card: Control
## AS1.1. The one real light the handheld throws into the world. Lives on the
## camera rather than on `handheld` itself — `handheld` is a `Control`, drawn
## in the HUD layer, and has nothing to attach a `Light3D` to.
var handheld_lamp: SpotLight3D
## A4.2. The handheld beam's own warp shell, kept rather than looked up: it is
## driven off the battery every frame and a per-frame group query for one node
## would be a search for something this scene already has in hand.
var handheld_warp: LightWarp

## A4.1. The lights somebody in the pit actually paid for, written as places
## rather than as a loop. The gate is the one the player walks in under and the
## only one that casts shadows, since it is the only one close enough for a
## shadow to be read as anything but cost.
## A4.1. How hard a fixture glows after dark. One number, because a bulb that
## is brighter than the light it stands in reads as a sticker on the frame.
const BULB_GLOW := 5.0

const GATE_LIGHTS := [
	{"at": Vector3(-6, 6, -17), "color": "ec6d2e", "energy": 4.2, "reach": 15.0, "shadows": true},
	{"at": Vector3(7, 6, 6), "color": "ec6d2e", "energy": 3.6, "reach": 14.0},
	{"at": Vector3(0, 7, -54), "color": "e8a24a", "energy": 3.2, "reach": 18.0},
	{"at": Vector3(2, 7, -96), "color": "c9722c", "energy": 3.0, "reach": 18.0},
	{"at": Vector3(-31, 5, 18), "color": "d8552a", "energy": 2.6, "reach": 12.0},
	{"at": Vector3(26, 5, -30), "color": "d8552a", "energy": 2.6, "reach": 12.0},
]

## AE.1 - AE.4. The yard's own population.
##
## The Bone Yard has been a one-person world since it was built: the player, Nix
## at the gate, and the captain. Every other body in the region either arrived
## from a reality misfire or came to keep the captain's second body alive. Greg
## asked for the world repopulated with killable characters, so this is a work
## party already standing in the place the fight happens - the hunt is now a
## hunt among people rather than a duel in an empty pit.
##
## AE.1. The slot prefix every one of these resolves through. Nothing in this
## block is a person's name: `cast_names.gd` derives one from
## `WorldHistory.run_salt` plus the slot, so a post is the same person inside a
## save and somebody else entirely in the next one - the same rule the captain
## has been on since v10.1.
const POPULATION_SLOT_PREFIX := "boneyard_worker_"
## AE.2. Where they stand: an offset from a lamp this scene already placed, so a
## post is somewhere with a light and a route rather than a coordinate typed in
## once and never revisited. `lamp` indexes `GATE_LIGHTS` above - the gate pair
## the player walks in under, the mid-road pair further north, and one out on
## the wreck line. Every post is more than `_update_encounter_actors()`'s own
## 24 m engage radius from the player's spawn point, so the yard is populated
## when you arrive rather than already on top of you.
## `tint`, `variation` and `implant` go straight into the rig config
## `baseline_human.gd` already reads, which is the only thing that makes two
## bodies out of one model: different flesh, a different procedural head and
## face, and a named piece of hardware on a named zone. A worker with a ceramic
## sternum and a worker with a shoulder brace are not the same person with a
## different label over them, and a hit that lands on an implant is recorded
## against a real part rather than against "unknown hardware".
const POPULATION_POSTS := [
	{"lamp": 0, "offset": Vector2(-5.0, 4.5), "post": "gate west", "role": "Yard salvage hand",
		"loot": ["gate scrip", "brass knuckle"], "tint": "6f5f4b", "variation": 3, "grudge": 0,
		"implant": {"zone": "left_arm", "name": "loader brace", "armor": 0.14}},
	{"lamp": 0, "offset": Vector2(4.5, -5.0), "post": "gate east", "role": "Wreck line cutter",
		"loot": ["cutting torch", "soot rag"], "tint": "7a6350", "variation": 11, "grudge": 2,
		"implant": {"zone": "torso", "name": "ceramic sternum", "armor": 0.12}},
	{"lamp": 2, "offset": Vector2(-6.0, 2.0), "post": "mid road west", "role": "Haul foreman",
		"loot": ["haul ledger", "spare chain"], "tint": "6b4f3a", "variation": 19, "grudge": 6,
		"implant": {"zone": "head", "name": "quota ledger plate", "armor": 0.16}},
	{"lamp": 2, "offset": Vector2(6.5, -3.0), "post": "mid road east", "role": "Signal keeper",
		"loot": ["relay coil", "tinned meat"], "tint": "5f5a44", "variation": 27, "grudge": 0,
		"implant": {"zone": "right_arm", "name": "relay spool", "armor": 0.1}},
	{"lamp": 4, "offset": Vector2(4.0, -6.0), "post": "wreck line", "role": "Rig mechanic",
		"loot": ["torque wrench", "battery cell"], "tint": "7c5744", "variation": 5, "grudge": 3,
		"implant": {"zone": "left_leg", "name": "pile-driver shin", "armor": 0.18}},
]
## AE.2. The yard floor is y = 0 (`_build_world()` lays the ground slab at -0.6
## with its top at 0), so a post takes its x/z from its lamp and its height from
## the floor rather than from the lamp's own mounting height.
const POPULATION_STAND_Y := 0.0
## AE.5. Walk into the yard after dusk and these five would be five names in the
## dark - the clock runs a game minute a second and dusk is a minute and a half
## from the opening 16:30. Each of them carries a lantern instead: made through
## `_place_night_light()` like every other light in the region, parented to the
## body so it travels with whoever is holding it, and driven by
## `_update_day_night()` off the same hour as the gate lamps. You find people
## here because you can see them, not because you walked the grid blind.
const POPULATION_LANTERN_ENERGY := 2.8
const POPULATION_LANTERN_REACH := 12.0
## Offset in the carrier's own frame: out to one side and at hand height, the
## way a lantern is actually held rather than a lamp mounted on their spine.
const POPULATION_LANTERN_AT := Vector3(0.42, 1.05, 0.0)
## AE.4. The yard's people work for one of the four factions `cast_names.gd`
## already hands out; this is the one that is theirs, registered as a
## WorldHistory subject of kind "faction" the way every other faction in this
## world is. It is not a parallel roster - a death in the yard then has a real
## consequence through F3, where `wire_net.gd`'s `open_vacancy()` finds the post
## the dead worker held and `promote_successor()` fills it from whoever of the
## roster is still standing. The yard reorganises around its losses instead of
## quietly forgetting them. The id and name are the ones already in
## `CastNames.FACTIONS`, so a generated worker's faction and this subject can
## never be two different things.
const POPULATION_FACTION_ID := "bonewright_union"
const POPULATION_FACTION_NAME := "Bonewright Union"

## A4.1. Every placed light, so `_update_day_night()` can put them out at dawn
## without holding a second list of where they are.
var night_lights: Array[OmniLight3D] = []
## B2.1. How often the rig reports itself while somebody is reading it. Half a
## second: fast enough that a wound appears on the chart while the chart is
## open, slow enough that it is not a snapshot every frame of a body that
## mostly is not changing.
const BODY_RECORD_INTERVAL := 0.5
## A9.2. How fast the haze follows the air. Eased rather than set, because
## `_update_day_night()` writes the same value off the hour and the two would
## otherwise fight frame by frame.
const AIR_FOG_BLEND := 0.08
## W1.2. "Contamination has weather — it moves, it settles, it gets worse."
## Days (of the 30-day month `WorldClock`/AB2.4/W10.11 already treat as the
## game's one calendar unit) for the calendar term alone to reach its worst.
## Shorter than the month itself so a lived-in save reads as measurably
## worse before the month turns over and repairs land.
const AIR_WORSENING_DAYS := 18.0
## However bad the calendar term gets on its own, loose chaos-magick can push
## the rest of the way — the ecology and the occult are named as the same rot
## in this world ("runaway fungal ecology, decayed cybernetics").
const AIR_CHAOS_CONTRIBUTION := 0.35
## A7.1. Who is up, and the hour that decides it.
var gods: Gods
## A8.1. The spirit on the body, and the frame melting around it.
var flame: UndyingFlame
## A9.1. What is in the air between the player and everything else.
var air: ContaminatedAir
## B2.1. Counts down while the handheld is up, so the body chart the player is
## reading is the body they are standing in.
var body_record_timer := 0.0
## AS2. Built once in `_build_world()`, driven every frame in
## `_update_day_night()` off `world_clock.gd` — it used to sit at one fixed
## angle and brightness no matter the hour, which is why W1.1 existing made no
## visible difference until this read off it.
var sun: DirectionalLight3D
## AS4. Storms that answer the occult — severity is a read of
## `WorldHistory.chaos_magick()`, never authored here.
var storm_weather: StormWeather
## PiFrac-DEV Studio's "Glitch Spider particle system" reference. The one
## burst `_on_reality_misfire()` fires — see `glitch_spider.gd`.
var glitch_spider: Node3D
## AE1.1. How loud the player is being right now, 0..1 — one of
## `perception.gd`'s four real inputs. No noise system existed anywhere in
## the project before this; sprinting is the one real, if simple, source of
## it for a first pass.
var player_noise := 0.0
## AE1.1. The worst-case (most exposed) verdict against any live hostile
## this frame, and the boolean AS1.5/AU1.10's AE1.4 were both waiting on.
var player_visibility := 0.0
var player_unseen := true
var pathfinder = preload("res://systems/ashbloom_pathfinder.gd").new()
var social_markers: Array[Node3D] = []
var resolution_ui: Control
var resolution_target := ""
var living_map: Control
var natal_sigil: Control
## I0.1. The real index. Hunt Grounds was drawing its own text list instead.
var world_index: Control
## L. The Board was built across twenty-odd segments and instantiated only in
## tests — there has never been a key that opens it, which is why Greg could not
## remember how to reach it. There is one now.
var pin_board: Control
var demo_wall: Control
## The cursor the game draws for itself while the OS one is hidden.
var _pointer: Control
## O2.2. The moment of contact. There was none — see impact_feel.gd.
var impact_feel: Node
var viscera_fx := true
var enemy_rig: BaselineHuman
var grapple_target := ""
var grapple_advantage := 0.0
var grapple_clock := 0.0
## O3.3. Which limb the hold actually has. Set once, at the moment you take
## hold, to whichever arm or leg is already worst off — the clinch had no
## opinion about this at all before, so grabbing somebody was identical
## whether their arm was fine or already broken. Leaning on the limb you
## actually grabbed now saps their resistance harder than the generic
## combat/mobility ratios already did, and costs that limb condition of its
## own while you press it.
var grapple_zone := ""
## B6.2. Which of the player's own limbs is holding. Severing it ends the
## hold — the item's own claim, and the reason this is tracked at all rather
## than a grapple being something the whole body does abstractly.
var grapple_with := "right_arm"
const GRAPPLE_PRESSURE_INTERVAL := 0.4
var grapple_pressure_clock := 0.0
## Test hook: set true/false to force the press state `_update_grapple` reads,
## since it is the one clinch input read as a raw button rather than an
## action and there is no display server to raise a real one against in a
## headless run. Leave null for real input to decide it, as normal play does.
var grapple_pushing_override: Variant = null
## AN1.9. Mirrors `_update_grapple()`'s own local `pushing` each frame, since
## `_carry_current_weapon()` needs to read it from outside that function to
## pick "grapple" or the heavier "shove" mass.
var grapple_pushing_now := false
var friend_rig: BaselineHuman
var lock_target := ""
var lock_screen := Vector2(-1, -1)
var camera_position := Vector3.ZERO
var camera_ready := false
## M1.5/M3. 0 = fully first person, 1 = fully third person. The toggle in
## `_input` only sets the *target* (`third_person`); this is what the camera
## transform actually reads every frame, so stepping outside your body is a
## half-second slide rather than a teleport. Rule 3: every hard cut is a bug.
var perspective_blend := 0.0
const PERSPECTIVE_BLEND_RATE := 3.2
## M1.5. Polled rather than hooked to every place a boss could theoretically
## die, because the boss condition depends on faction state the Hunt System
## mutates in more than one file. A once-a-second check against a one-shot
## WorldHistory event is cheap and cannot miss the moment or refire it.
var _unlock_feel_timer := 0.0
var kill_cam: Control
var voice_channel: Node
var arsenal: Node
## AU7.6/AU7.9. Six cycles through the five smokeables. RMB then belongs to a
## real held draw until it is released; selecting a weapon puts the object away.
const SMOKEABLE_ORDER := ["cigarette", "vape", "joint", "spliff", "bong"]
const SMOKE_REST := Vector3(0.02, -0.19, -0.18)
const SMOKE_AT_MOUTH := Vector3(-0.03, 0.13, -0.04)
const SMOKE_FP_REST := Vector3(0.10, -0.23, -0.66)
## The first-person mouth sits just above the low diegetic reticle. Keeping the
## lit end here lets the cherry itself become the last centimetre of the aim
## picture instead of hiding below the HUD.
const SMOKE_FP_AT_MOUTH := Vector3(-0.26, -0.015, -0.31)
var smoke_index := -1
var smoke_model: Node3D
var smoke_grip_hand: Node3D
var smoke_support_hand: Node3D
var smoke_lighter: Node3D
var smoke_lighter_hand: Node3D
var smoke_lighter_lid: Node3D
var smoke_lighter_flame: MeshInstance3D
var smoke_lighter_light: OmniLight3D
var smoke_ignition := 0.0
var smoke_bong_audio: AudioStreamPlayer
var smoke_lighter_audio: AudioStreamPlayer
var smoke_held := 0.0
var smoke_drawing := false
var smoke_spent: Dictionary = {}
var smoke_draw_start_spent := 0.0
var smoke_pose := 0.0
var smoke_mouth_held := false
var smoke_mouth_blend := 0.0
var smoke_breath_phase := 0.0
var smoke_ash_flick := 0.0
var smoke_exhale_delay := 0.0
var smoke_pending_exhale: Dictionary = {}
var smoke_cough := 0.0
## What the contextual X-ray is showing inside the actual lungs. It fills with
## the held draw and drains through the automatic exhale; permanent darkness
## is stored by AnatomyComponent on the organs themselves.
var smoke_lung_fill := 0.0
const SMOKE_TRICKS := ["O", "DOUBLE O", "GHOST"]
var smoke_trick_index := 0
var smoke_trick_window := 0.0
var smoke_last_exhale: Dictionary = {}
## Hold I to turn whichever object is actually in the player's hands through a
## slow, close reading. This is a pose rather than a separate inventory screen:
## the object, its wear and the hands holding it remain in the live world.
var inspect_held := false
## A ground object enters the same inspection grammar while I is held. This
## keeps the live source rather than manufacturing a UI-only representation.
var inspected_world_item: Dictionary = {}
## Hold V outside a grapple to pull the same live lungs shown by the contextual
## X-ray into a rotatable 3D field specimen. V remains persuade inside clinches.
var pulmonary_held := false
var inspect_blend := 0.0
var inspect_time := 0.0
var inspection_light: OmniLight3D
var pending_attack: Dictionary = {}
## AN2.3. Set by `_attack_nearest_encounter_actor()` right before it returns
## true, read once by `_resolve_strike()` immediately after — a throat and a
## skull do not stop a blade the same amount, and `arm.strike()` was never
## told which one it had just hit.
var _last_melee_resistance := 0.65
var carried_limb_index := -1
var carried_limb_model: MeshInstance3D
var asset_network := ASSET_NETWORK.new()
## Bodies the fight is finished with. `_kill_encounter_actor` drops them out of
## `encounter_actors` so the AI stops paying for them, but a corpse is still a
## thing you can rob (B5), so it keeps its rig here rather than being forgotten.
var dead_bodies: Array[Dictionary] = []
var carrion_scavengers: Array[Node3D] = []
var extraction_session: Dictionary = {}
var witness_ledger := WitnessLedger.new()
## B3.3/B3.6. Hold G and you are looking through people; keep holding and the
## ring the X-ray has always been one seat of opens into the full wheel.
var xray_held := 0.0
## One wheel per hold. Set when a wheel opens, cleared when the key comes up.
var wheel_spent := false
var xray_active := false
## How long the button has to be down before the segment becomes the radial.
const XRAY_HOLD_TO_WHEEL := 0.35

@onready var camera: Camera3D = $CameraRig/Camera3D
## Agent 1 brief. "Do not solve darkness by merely increasing ambient
## brightness. Night should remain dark. The Black Mirror camera should
## become the meaningful navigation tool in extreme darkness." The real
## world's own lighting (`sun`, `WorldEnvironment`, AS2's whole night curve)
## is untouched either way — this swaps only the camera's own `environment`,
## the same seam Godot already gives a lens for looking differently at an
## unchanged world, to a steep brightness lift and a washed, near-monochrome
## grade. Amplifying what little light is really there, not adding light
## that was never there, is the actual difference between this and turning
## the world's own lamps up.
var black_mirror_active := false
var _black_mirror_env: Environment
@onready var title: Label = $HUD/Title
@onready var status: Label = $HUD/Status
@onready var vitals: Label = $HUD/VitalsPanel/Vitals
@onready var prompt: Label = $HUD/Prompt
@onready var panel: PanelContainer = $HUD/ArchivePanel
@onready var archive: Label = $HUD/ArchivePanel/Margin/Archive
@onready var field_interface: Control = $HUD/FieldInterface
@onready var character_archive: Control = $HUD/CharacterArchive
@onready var allusions_artwork: Control = $HUD/AllusionsArtwork


func _ready() -> void:
	# The gore setting was only ever applied in the derby, so OFF did nothing
	# once the player walked into the Hunt Grounds and REDUCED leaked across as
	# a static the hunt never reset.
	BaselineHuman.clear_gore()
	viscera_fx = BaselineHuman.apply_gore_setting()
	_build_world()
	handheld = HANDHELD.new()
	handheld.name = "Handheld"
	$HUD.add_child(handheld)
	handheld.load_device()
	handheld.dropped.connect(_on_handheld_dropped)
	# AS1.1. Parented to the camera so it always points where the player is
	# looking, the way a phone held up in front of you actually would. Range is
	# `HandheldDevice.LAMP_RANGE` — the one constant AS1.5's `light_radius()`
	# hook shares with it, so a stealth check reading that hook can never
	# disagree with how far the light drawn here actually reaches.
	handheld_lamp = SpotLight3D.new()
	handheld_lamp.name = "HandheldLamp"
	handheld_lamp.light_color = Color("cfe6d6")
	handheld_lamp.light_energy = 0.0
	handheld_lamp.spot_range = HANDHELD.LAMP_RANGE
	handheld_lamp.spot_angle = 34.0
	handheld_lamp.spot_angle_attenuation = 1.6
	# Kept from the other implementation of this: off-centre and slightly
	# rotated, because a phone in a raised hand does not sit dead centre
	# like a headlamp, and it casts shadows so the light has edges.
	handheld_lamp.position = HANDHELD_LAMP_BASE_POSITION
	handheld_lamp.rotation_degrees = HANDHELD_LAMP_BASE_ROTATION
	handheld_lamp.shadow_enabled = true
	camera.add_child(handheld_lamp)
	# A4.2. The handheld is a light like any other, so it warps the air like any
	# other — and being the one you carry, it is the first warping most players
	# will ever see. Out of the day/night group on purpose: this one answers its
	# own battery in `_update_handheld_lamp()`, not the hour, because a light
	# somebody is holding is not a light the world turned on.
	handheld_warp = LightWarp.attach(handheld_lamp, -1.0, false)
	resolution_ui = preload("res://systems/downed_resolution.gd").new()
	resolution_ui.name = "DownedResolution"
	$HUD.add_child(resolution_ui)
	resolution_ui.selected.connect(_resolve_downed)
	resolution_ui.cancelled.connect(_resolution_cancelled)
	resolution_ui.voice_capture_requested.connect(_voice_capture)
	living_map = LIVING_MAP.new()
	living_map.name = "LivingMap"
	$HUD.add_child(living_map)
	natal_sigil = preload("res://systems/natal_sigil.gd").new()
	natal_sigil.name = "NatalSigil"
	$HUD.add_child(natal_sigil)
	# I0.1. Every rework of the index went into `world_index.gd`, and this scene
	# never used it: TAB opened a Label full of "- weapon fired" instead. That is
	# why the tutorial look kept coming back no matter how many times the index
	# was rebuilt — the rebuilt one was not the one the player was opening.
	world_index = WORLD_INDEX.new()
	world_index.name = "WorldIndex"
	$HUD.add_child(world_index)
	pin_board = PIN_BOARD.new()
	pin_board.name = "PinBoard"
	$HUD.add_child(pin_board)
	world_index.pin_requested.connect(_pin_index_record)
	handheld.pin_requested.connect(_pin_index_record)
	demo_wall = DEMO_WALL.new()
	demo_wall.name = "DemoWall"
	$HUD.add_child(demo_wall)
	demo_wall.front_door_requested.connect(_leave_demo_wall)
	# An ended demo remains ended when its dedicated save is resumed. The front
	# door routes a won opening to this real scene, which immediately restores
	# the wall instead of dropping the player back behind the authored stop.
	if WorldHistory.is_demo() and str(WorldHistory.subject("demo_run").get("status", "")) == "ended":
		demo_wall.call_deferred("open_wall")
	# AG1.7, from the first playtest: "when I'm looking through the Tree section
	# I can't see my mouse cursor." B3.5 hid the OS pointer so the game could own
	# it, and then only the index ever drew a replacement — so every other panel
	# handed the player an invisible cursor. One layer above all of them, drawn
	# whenever a panel is up, fixes it for the Tree, the Board, the map and
	# anything added later without each one having to remember.
	# AG4.2. Under the pointer and over everything else in the world: blood on
	# the lens sits between the player and the scene, not between the player
	# and the panel they opened.
	# AN1.2. The arm exists before the first swing does.
	arm = LIMB_MOMENTUM.new()
	_carry_current_weapon()
	# AF1. Rounds and brass live in the world, not in the HUD.
	ballistics = BALLISTICS.new()
	add_child(ballistics)
	ballistics.round_hit.connect(_on_round_hit)
	ballistics.round_expired.connect(_on_round_expired)
	storm_weather = STORM_WEATHER.new()
	storm_weather.name = "StormWeather"
	add_child(storm_weather)
	glitch_spider = GLITCH_SPIDER.new()
	glitch_spider.name = "GlitchSpider"
	add_child(glitch_spider)
	blood_veil = BLOOD_VEIL.new()
	$HUD.add_child(blood_veil)
	_pointer = Control.new()
	_pointer.name = "Pointer"
	_pointer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.top_level = true
	_pointer.draw.connect(_draw_pointer)
	_pointer.visible = false
	$HUD.add_child(_pointer)
	impact_feel = IMPACT_FEEL.new()
	# The kill cam already owns time deliberately; an impact inside one is part
	# of its timing, not a competitor for it.
	impact_feel.blocked_by = func() -> bool: return kill_cam != null and kill_cam.active
	add_child(impact_feel)
	kill_cam = preload("res://systems/kill_cam.gd").new()
	kill_cam.name = "KillCam"
	$HUD.add_child(kill_cam)
	field_lens = FIELD_LENS.new()
	field_lens.name = "FieldLens"
	$HUD.add_child(field_lens)
	held_reliquary = HELD_ITEM_RELIQUARY.new()
	held_reliquary.name = "HeldItemReliquary"
	$HUD.add_child(held_reliquary)
	# A close, restrained reflection for reading dark metal and gloved fingers at
	# night. It exists only during inspection and reaches no further than the
	# hands; this is presentation light, not a free flashlight.
	inspection_light = OmniLight3D.new()
	inspection_light.name = "InspectionGlint"
	inspection_light.position = Vector3(-0.12, 0.10, -0.34)
	inspection_light.light_color = Color("d7b18a")
	inspection_light.light_energy = 0.0
	inspection_light.omni_range = 2.2
	inspection_light.shadow_enabled = false
	camera.add_child(inspection_light)
	psychedelic = PSYCHEDELIC_RIG.new()
	psychedelic.name = "Psychedelic"
	$HUD.add_child(psychedelic)
	# DESIGN/FINAL_V.md §16, Path C. Frees itself immediately unless dev tools
	# are on and `--osc` was actually asked for, so this costs nothing in a
	# normal run — see `psychedelic_osc.gd`.
	var osc := PSYCHEDELIC_OSC.new()
	osc.name = "PsychedelicOSC"
	add_child(osc)
	osc.attach(psychedelic)
	keys_card = KEYS_CARD.new()
	keys_card.name = "KeysCard"
	$HUD.add_child(keys_card)
	_build_keys_card()
	_order_hud_layers()
	voice_channel = preload("res://systems/proximity_voice.gd").new()
	voice_channel.name = "ProximityVoice"
	add_child(voice_channel)
	voice_channel.capture_finished.connect(_voice_captured)
	voice_channel.capture_failed.connect(func(reason: String): resolution_ui.set_voice_state(reason))
	_build_expanse_systems()
	_register_people()
	player_body = CharacterBody3D.new()
	player_body.name = "HunterController"
	player_collider = CollisionShape3D.new()
	player_capsule = CapsuleShape3D.new()
	player_capsule.radius = 0.36
	player_capsule.height = 1.8
	player_collider.shape = player_capsule
	player_body.add_child(player_collider)
	HUNTER_MOTOR.configure(player_body)
	add_child(player_body)
	player_body.position = player - Vector3.UP * 0.6
	_restore_dropped_handheld()
	_build_player_rig()
	# The old red witness mirror was a body-inspection prototype left standing
	# directly in the opening sightline. The real room mirror remains tested and
	# reusable, but the Hunt no longer begins beside an unexplained red rectangle.
	arsenal = HUNTER_ARSENAL.new()
	arsenal.name = "HunterArsenal"
	player_body.add_child(arsenal)
	arsenal.configure(player_rig)
	arsenal.reload_finished.connect(_on_weapon_reload_finished)
	body_motion = HUNTER_BODY_MOTION.new()
	body_motion.name = "HunterBodyMotion"
	player_body.add_child(body_motion)
	body_motion.configure(player_rig)
	body_motion.set_perspective(not third_person)
	WorldHistory.register_subject("inventory", {"items": []})
	_spawn_friend()
	# AE.1. The captain is still spawned exactly as she always was, and this
	# runs alongside her rather than instead of her or through her. The order
	# matters: `_spawn_rival()` owns the Ashline captain and stays untouched,
	# and the yard's own people are built after it, so if the population ever
	# fails to build the canonical hunt is already standing.
	_spawn_rival()
	_spawn_yard_population()
	_restore_local_law_teams()
	# AP1.6. "Attempt to kill him" hands off here rather than fighting the
	# ringmaster inside `rift_derby.gd`, which has no player body or combat
	# system at all — this is a forced encounter through the same real actor
	# `_spawn_encounter_actor()` already builds for every other named
	# hostile, not a random misfire roll and not a new fight system.
	var ringmaster_id := CAST.id_for(RINGMASTER_SLOT)
	var ringmaster_subject := WorldHistory.subject(ringmaster_id)
	if bool(ringmaster_subject.get("challenge_pending", false)):
		WorldHistory.update_subject(ringmaster_id, {"challenge_pending": false}, "ringmaster_challenge_spawned")
		_spawn_encounter_actor({
			"instance_id": "ringmaster_boss",
			"kind": "boss",
			"elo": 1800,
			"display_name": str(ringmaster_subject.get("name", "The Ringmaster")),
			"tint": "3a1414",
			"variation": 41,
			"blood": 5800.0,
		}, player + Vector3(4.0, 0, -6.0))
	_update_camera()
	WorldHistory.record_event("player_entered_hunt_ground", {"location": HUNT_LOCATION, "hunt_id": CAST.id_for(CAPTAIN_SLOT)})
	# A wreck in the derby already routed the player through `DefeatRouter`
	# before this scene loaded (`rift_derby.gd::_finish_round`), so a lost heat
	# and a lost fight land in the same captivity rather than one of them being
	# a same-shape scene change with a different label. Excludes "redecanted":
	# once the player has paid that exit, walking back into this scene later is
	# a fresh arrival, not a second capture of the one that already ended.
	var arriving_player := WorldHistory.subject("player")
	if str(arriving_player.get("status", "")) in ["shackled", "stamped", "conscripted"]:
		_enter_captivity({
			"outcome": arriving_player.get("status", ""),
			"destination": arriving_player.get("held_at", HUNT_LOCATION),
		})


## The player had no body at all — only a `health` integer, the same defect the
## derby drivers carried. `health` stays the coarse survivability meter the loop
## and HUD are balanced around; the rig records *where* the damage is, renders it
## on the player's own limbs in first person, and persists it. Unifying the two
## numbers means rebalancing the whole hunt loop and is tracked in ROADMAP.md.

## B8.2. The body ran out. Nothing here heals it and nothing here ends the run —
## the spirit is still holding it, so what happens is that the player is on the
## ground, wrecked, and gets up worse than they were.
func _on_player_body_failed(report: Dictionary) -> void:
	WorldHistory.record_event("body_failed", {
		"subject_id": "player",
		"cause": str(report.get("type", "unknown")),
		"failure_index": int(report.get("failure_index", 1)),
		"spirit_burden": player_rig.anatomy.spirit_burden,
	})
	# Straight to the flame rather than waiting for the next frame's poll, so the
	# moment it happens is the moment it shows.
	if flame != null:
		flame.set_condition(player_rig.anatomy.flame_condition())

func _build_player_rig() -> void:
	player_rig = BaselineHuman.new()
	player_rig.name = "HunterBody"
	player_body.add_child(player_rig)
	# The capsule is centred on the controller origin, so drop the rig by half
	# its height to stand the feet on the floor rather than mid-shin.
	player_rig.position = Vector3(0, -0.9, 0)
	# A8.1. Lit at build, on the rig itself rather than on the camera or the
	# HUD: what burns here is the body, and every previous attempt at this was
	# an overlay that stayed exactly as bright when the body was not in frame.
	flame = UndyingFlame.new()
	flame.name = "UndyingFlame"
	player_rig.add_child(flame)
	flame.ignite(player_rig)
	var saved: Dictionary = WorldHistory.subject("player")
	# D4.2. The race you were decanted as is a silhouette, not just a stat block.
	# A Marrow-Cut stands bigger than an Unreset, and until now every body in the
	# world was the same size whatever the sheet said.
	#
	# B10.1. The derivation from papers to body used to live here, in the hunt,
	# which meant the hunt was the only thing in the game that could build this
	# person. "Recognisably itself across a restart" is a claim about two bodies
	# built from one record at two different times, and it cannot even be stated
	# while only one scene knows how to read the record. It moved to the rig.
	var appearance: Dictionary = saved.get("appearance", {})
	var config := BaselineHuman.config_from_subject(saved)
	config["gore"] = viscera_fx
	player_rig.gore = viscera_fx
	player_rig.build("player", config)
	# B8.1. The one thing that makes this body different from the one lying in
	# the road: it takes every wound through the same anatomy, and death does not
	# take. AP2.1, "the spirit cannot be banished by violence."
	#
	# After `build()`, not before it. `build()` is what creates `anatomy`, and the
	# first version of this sat up beside `flame.ignite()` twenty-seven lines
	# earlier, touching a null and aborting the rest of the rig — which showed up
	# as the player being unable to fire at all rather than as anything to do
	# with dying. Set here rather than inside BaselineHuman because undying is a
	# fact about this character in this scene, not a property of being a body.
	player_rig.anatomy.undying = true
	player_rig.anatomy.body_failed.connect(_on_player_body_failed)
	if not config.has("restore"):
		# N5.2/N5.8. Only on a genuine first decanting — a restored body already
		# carries whatever CellOutz's hardware became (still locked, or pulled
		# and gone), and re-running this would silently re-lock a slot the
		# player already went rogue on. left_arm excluded: see
		# `install_factory_loadout()`'s own comment — B6.5/B6.6 needs that zone
		# free of any installed part or the player's arm can never be severed.
		player_rig.anatomy.install_factory_loadout(["left_arm"])
	hunter_appearance = HUNTER_APPEARANCE.new()
	hunter_appearance.name = "HunterAppearance"
	player_rig.add_child(hunter_appearance)
	# B4.1. The sheet's marks travel with the appearance it already drives.
	hunter_appearance.configure(player_rig, appearance)
	_dress_player_humiliation_outfit()


## The elites did not decant the hunter naked; they issued a joke of a uniform.
## Shoulder puffs and a locked ruff make the humiliation readable on the body
## witness and in third person, while the matching glove cuffs carry that story
## all the way into the first-person smoking and weapon animations.
func _dress_player_humiliation_outfit() -> void:
	var wine := _smoke_prop_material(Color("541825"), 0.78, false)
	var bone_cloth := _smoke_prop_material(Color("bda877"), 0.82, false)
	for zone_id in ["left_arm", "right_arm"]:
		var arm_part := player_rig.parts.get(zone_id) as Node3D
		if arm_part == null:
			continue
		var sleeve := Node3D.new()
		sleeve.name = "ForcedJesterSleeve"
		sleeve.position.y = 0.225
		arm_part.add_child(sleeve)
		for index in 5:
			var angle := TAU * float(index) / 5.0
			var puff := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.075
			mesh.height = 0.115
			mesh.radial_segments = 12
			mesh.rings = 7
			puff.mesh = mesh
			puff.position = Vector3(cos(angle) * 0.070, 0.0, sin(angle) * 0.062)
			puff.material_override = wine if index % 2 == 0 else bone_cloth
			sleeve.add_child(puff)
	var torso := player_rig.parts.get("torso") as Node3D
	if torso != null:
		var ruff := MeshInstance3D.new()
		ruff.name = "ForcedJesterRuff"
		var ruff_mesh := TorusMesh.new()
		ruff_mesh.inner_radius = 0.125
		ruff_mesh.outer_radius = 0.205
		ruff_mesh.rings = 18
		ruff_mesh.ring_segments = 12
		ruff.mesh = ruff_mesh
		ruff.rotation.x = PI * 0.5
		ruff.position = Vector3(0.0, 0.285, 0.0)
		ruff.material_override = bone_cloth
		torso.add_child(ruff)


## B9.1/B9.2.  This is a physical fixture in the hunt, rather than a HUD
## portrait.  The `LiveBodyMirror` shares this World3D and watches HunterBody,
## letting the player inspect the rear of their real rig and its current damage.
func _build_body_witness() -> void:
	var mirror := LIVE_BODY_MIRROR.new()
	mirror.name = "BodyWitnessMirror"
	mirror.position = Vector3(2.3, 1.55, 15.8)
	mirror.rotation.y = PI
	add_child(mirror)
	mirror.set_target(player_rig)


## Both of these are the rig's now — see `BaselineHuman.config_from_subject`.
## Kept as delegates rather than deleted because blood volume and what you were
## grown with are two of the things D's audit asks this scene directly, and a
## body-level fact should not stop being askable of the scene that decants one.
func _blood_volume(blood_type: String) -> float:
	return BaselineHuman.blood_volume(blood_type)


func _grown_cybernetics(sheet_anatomy: Dictionary) -> Dictionary:
	return BaselineHuman.grown_cybernetics(sheet_anatomy)


## Damage to the player, routed through the body so it lands on a real zone,
## bleeds from a real organ, and is still there next time.
func _wound_player(from: Vector3, damage: float, damage_type := "cut") -> void:
	if player_rig == null:
		return
	# One incoming blow may crack the held mirror, change anatomy, sever a limb
	# and force a drop. Those are consequences of one physical impact.
	WorldHistory.begin_ledger_batch()
	# C10.8. The raised Black Mirror is physically in the exchange. A blow only
	# marks it while it is actually exposed in the hand, and its crack starts on
	# the side of the glass the attacker occupied on screen rather than at a
	# cosmetic random point.
	if handheld != null and is_instance_valid(handheld) and handheld.possessed and handheld.raised > 0.5:
		handheld.take_wear(clampf(damage / 400.0, 0.008, 0.08), "%s impact while raised" % damage_type, _handheld_impact_point(from))
	var toward := (from - player)
	toward.y = 0.0
	var aim := player_rig.global_position + Vector3(0, 1.1, 0) + toward.normalized() * 0.3
	var result := player_rig.hit_at(aim, damage, damage * 0.8, damage_type)
	hunter_appearance.sync_from_anatomy()
	WorldHistory.update_subject("player", {"anatomy_state": player_rig.snapshot()}, "anatomy_changed")
	WorldHistory.record_event("player_wounded", {
		"zone": str(result.get("zone", "torso")),
		"organ": str((result.get("organ", {}) as Dictionary).get("zone", "")),
		"location": HUNT_LOCATION,
	})
	if bool(result.get("severed", false)):
		_player_lost_limb(str(result.get("zone", "")))
	elif _should_disarm(damage):
		_disarm_player()
	WorldHistory.commit_ledger_batch()


func _handheld_impact_point(from: Vector3) -> Vector2:
	if camera == null or not is_instance_valid(camera):
		return Vector2(0.5, 0.5)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or camera.is_position_behind(from):
		return Vector2(0.5, 0.5)
	var projected := camera.unproject_position(from) / viewport_size
	return Vector2(clampf(projected.x, 0.1, 0.9), clampf(projected.y, 0.1, 0.9))


## AN2.2. A weapon you are barely holding is a weapon somebody can take. Both
## halves have to be real: a fresh grip does not give this up to a light
## tap, and a hard blow does not shake loose a weapon held with everything
## the arm has left.
func _should_disarm(damage: float) -> bool:
	if bare_handed or carried_limb_index >= 0 or arm == null:
		return false
	return arm.fatigue >= DISARM_FATIGUE_THRESHOLD and damage >= DISARM_DAMAGE_THRESHOLD


func _disarm_player() -> void:
	var lost := str(arsenal.current_id) if arsenal != null else ""
	_put_the_weapons_down()
	prompt.text = "DISARMED // [1-3] TO DRAW AGAIN"
	WorldHistory.record_event("player_disarmed", {"weapon": lost, "fatigue": snappedf(arm.fatigue, 0.01), "location": HUNT_LOCATION})


## How much of a healthy swing and a healthy run the player has left. Both read
## the same ratios the NPC AI already uses, so "the fight continues with them
## still in it, fighting worse" means the same thing whichever side of it you
## are on.
func _player_swing_scale() -> float:
	# O5.7. A blow thrown off your feet has your arm behind it and nothing else.
	return lerpf(PLAYER_INJURY_FLOOR, 1.0, player_rig.anatomy.combat_ratio()) * lerpf(0.45, 1.0, clampf(footing, 0.0, 1.0))


func _player_speed_scale() -> float:
	return lerpf(PLAYER_INJURY_FLOOR, 1.0, player_rig.anatomy.mobility_ratio()) * lerpf(0.6, 1.0, clampf(footing, 0.0, 1.0))


## B6.5. Losing a limb is not a death and not a cutscene. The player keeps
## playing, worse: the stump bleeds on the same clock everyone else's does, the
## swing and the run are already scaled off the rig, and an arm that is gone
## cannot hold what it was holding.
func _player_lost_limb(zone: String) -> void:
	if zone == "":
		return
	WorldHistory.begin_ledger_batch()
	if zone.ends_with("_arm"):
		# The hand that was carrying it is on the floor.
		if carried_limb_index >= 0:
			var dropped: Dictionary = handheld.carry.drop(carried_limb_index)
			_clear_carried_limb_model()
			WorldHistory.record_event("player_dropped_carried_part", {"item": dropped, "cause": "lost the arm holding it"})
		arsenal.select_slot(0)
	WorldHistory.update_subject("player", {
		"anatomy_state": player_rig.snapshot(),
		"memory": "Lost a %s in the Bone Yard and kept moving." % zone.replace("_", " "),
	}, "player_maimed")
	WorldHistory.record_event("player_limb_severed", {
		"zone": zone,
		"location": HUNT_LOCATION,
		"combat_ratio": snappedf(player_rig.anatomy.combat_ratio(), 0.01),
		"mobility_ratio": snappedf(player_rig.anatomy.mobility_ratio(), 0.01),
		"alive": not player_rig.anatomy.dead,
	})
	WorldHistory.commit_ledger_batch()
	prompt.text = "YOUR %s IS GONE — BLEEDING HARD, STILL STANDING" % zone.replace("_", " ").to_upper()


func _register_people() -> void:
	# Authored cast schema is one scene bootstrap, not ten independent acts.
	WorldHistory.begin_ledger_batch()
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor", "faction": "Unbound",
		"elo": 1000, "grudge": 0, "status": "awake", "memory": "The derby door opened into Limbo.",
		"wounds": [], "anatomy": {"blood_type": "unresolved", "cybernetics": ["salvaged torque arm"]},
		"relations": {FRIEND_ID: {"kind": "bond", "strength": 12}, CAST.id_for(CAPTAIN_SLOT): {"kind": "grudge", "strength": 1}},
	})
	WorldHistory.register_subject(FRIEND_ID, {
		"name": "Nix Arden", "kind": "person", "role": "Scrap medic", "faction": "Gate Lanterns", "faction_id": "gate_lanterns",
		"elo": 930, "bond": 12, "grudge": 0, "status": "waiting", "memory": "Kept a gate open for you.",
		"wounds": ["spore-burned right lung"], "anatomy": {"blood_type": "A-ASH", "cybernetics": ["copper lung bellows", "dose counter"]},
		"relations": {"player": {"kind": "saved", "strength": 22}, "moth_jerrow": {"kind": "ally", "strength": 35}},
	})
	WorldHistory.register_subject("gate_lanterns", {
		"name": "Gate Lanterns", "kind": "faction", "role": "Ascending counter-order", "threat": "LOW", "territory": "Waystations between the tunnels and the surface",
		"doctrine": "Carry a light for whoever comes after. A kept promise outlasts a kept grudge.",
		"relations": {"nix_arden": {"kind": "command", "strength": 40}},
	})
	CAST.ensure(CAPTAIN_SLOT, {
		"elo": 1180,
		"grudge": 0, "injury": "none", "status": "active", "memory": "Watching the derby", "wounds": [],
		"anatomy": {"blood_type": "O-RUST", "cybernetics": ["jaw telemetry nail", "left clavicle rail"]},
		"relations": {"player": {"kind": "hunts", "strength": 8}, "ashline_wreckers": {"kind": "command", "strength": 72}, "rook_sable": {"kind": "grudge", "strength": 31}},
	})
	WorldHistory.register_subject("ashline_wreckers", {
		"name": "Ashline Wreckers", "kind": "faction", "role": "Road murder syndicate", "threat": "SEVERE", "territory": "Bone Yard / Burnt Highway",
		"doctrine": "Every machine is a coffin awaiting an owner. Rank is won by remembered impact.",
		"relations": {"" + CAST.id_for(CAPTAIN_SLOT) + "": {"kind": "command", "strength": 72}, "rook_sable": {"kind": "enemy", "strength": 46}},
	})
	WorldHistory.register_subject("rook_sable", {
		"name": "Rook Sable", "kind": "person", "role": "Rail-gang adjudicator", "faction": "Black Mile", "faction_id": "black_mile", "elo": 1325,
		"grudge": 18, "status": "unlocated", "memory": "Paid three drivers to lose the same race.", "wounds": ["missing left eye"],
		"anatomy": {"blood_type": "B-9", "cybernetics": ["rangefinder eye", "ceramic sternum"]},
		"relations": {"" + CAST.id_for(CAPTAIN_SLOT) + "": {"kind": "grudge", "strength": 31}, "iris_coil": {"kind": "command", "strength": 61}},
	})
	WorldHistory.register_subject("iris_coil", {
		"name": "Iris Coil", "kind": "person", "role": "Sporeline scout", "faction": "Black Mile", "faction_id": "black_mile", "elo": 1096,
		"grudge": 0, "status": "roaming", "memory": "Photographed the fungus moving against the wind.", "wounds": ["glass scars"],
		"anatomy": {"blood_type": "AB-", "cybernetics": ["optic spool", "ankle compass"]},
		"relations": {"rook_sable": {"kind": "bond", "strength": 17}, "vale_nine": {"kind": "enemy", "strength": 44}},
	})
	WorldHistory.register_subject("moth_jerrow", {
		"name": "Moth Jerrow", "kind": "person", "role": "Fungus shepherd", "faction": "Soft Rot Communion", "faction_id": "soft_rot", "elo": 1004,
		"grudge": 0, "status": "cultivating", "memory": "Claims the great caps remember rain from before the flash.", "wounds": ["mycelial graft"],
		"anatomy": {"blood_type": "SAP", "cybernetics": ["filter trachea"]},
		"relations": {"nix_arden": {"kind": "ally", "strength": 35}, "vale_nine": {"kind": "bond", "strength": 13}},
	})
	WorldHistory.register_subject("vale_nine", {
		"name": "Vale Nine", "kind": "person", "role": "Storm stalker", "faction": "None", "elo": 1244, "grudge": 7,
		"status": "following", "memory": "Leaves clean footprints through radioactive mud.", "wounds": ["thoracic puncture", "burned fingertips"],
		"anatomy": {"blood_type": "UNKNOWN", "cybernetics": ["quiet-heart regulator", "heel anchors"]},
		"relations": {"moth_jerrow": {"kind": "bond", "strength": 13}, "choir_of_marrow": {"kind": "enemy", "strength": 58}},
	})
	WorldHistory.register_subject("choir_of_marrow", {
		"name": "Choir of Marrow", "kind": "faction", "role": "Anatomical faith", "threat": "UNKNOWN", "territory": "Subsurface ossuary",
		"doctrine": "Metal forgets. Bone records. Their surgeons replace healthy parts to rewrite allegiance.",
		"relations": {"vale_nine": {"kind": "enemy", "strength": 58}, "doctor_vanta": {"kind": "command", "strength": 83}},
	})
	WorldHistory.register_subject("doctor_vanta", {
		"name": "Doctor Vanta", "kind": "person", "role": "Relic anatomist", "faction": "Choir of Marrow", "faction_id": "choir_of_marrow", "elo": 1460,
		"grudge": 0, "status": "rumoured", "memory": "A voice below the quarry is pricing Mara's replacement arm.", "wounds": [],
		"anatomy": {"blood_type": "NULL", "cybernetics": ["six-finger surgical crown", "blackbox liver", "remote pulse cage"]},
		"relations": {"choir_of_marrow": {"kind": "command", "strength": 83}, "" + CAST.id_for(CAPTAIN_SLOT) + "": {"kind": "known", "strength": 26}},
	})
	WorldHistory.commit_ledger_batch()


func _unhandled_input(event: InputEvent) -> void:
	if resolution_ui.visible or kill_cam.active:
		return
	if event is InputEventKey and event.keycode == KEY_V and not event.echo:
		if event.pressed and grapple_target.is_empty() and panel_mode.is_empty():
			pulmonary_held = true
			prompt.text = "PULMONARY RELIQUARY // MOVE MOUSE / WHEEL // RELEASE V"
		elif not event.pressed:
			pulmonary_held = false
	if _pulmonary_diagnostic_active() and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			field_interface.zoom_pulmonary(1.12)
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			field_interface.zoom_pulmonary(0.89)
			return
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.pressed:
			if smoke_trick_window > 0.0:
				_shape_smoke_trick()
			else:
				_attack()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		_toggle_lock()
	if event is InputEventMouseButton and event.pressed and not lock_target.is_empty():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_lock(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_lock(-1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if smoke_model != null and is_instance_valid(smoke_model):
			if event.pressed:
				_begin_smoking_draw()
			else:
				_finish_smoking_draw()
		elif event.pressed:
			_attack(true)
	if event is InputEventKey and event.keycode == KEY_I and not event.echo:
		inspect_held = event.pressed
		if inspect_held and panel_mode.is_empty():
			prompt.text = "INSPECT // RELEASE I TO LOWER"
			# The receipt must name what the animation is actually raising. A
			# proximity-first lookup let a bedroll or passer-by steal the event
			# while the player's hands visibly turned their bong or gun. Held
			# things own I; slot 5 puts the hands down and exposes world inspection.
			inspected_world_item.clear()
			var inspected_id := ""
			var inspected_event := "held_item_inspected"
			if smoke_model != null and is_instance_valid(smoke_model):
				inspected_id = str(smoke_model.get_meta("device_id", ""))
			elif carried_limb_model != null and is_instance_valid(carried_limb_model):
				inspected_id = "carried_limb"
			elif arsenal != null and not bare_handed:
				inspected_id = str(arsenal.current_id)
			if inspected_id.is_empty():
				inspected_world_item = _nearest_world_item_for_inspection()
				inspected_id = str(inspected_world_item.get("item_id", ""))
			if not inspected_world_item.is_empty():
				match str(inspected_world_item.get("kind", "")):
					"person": inspected_event = "world_subject_inspected"
					"fixture": inspected_event = "world_fixture_inspected"
					_: inspected_event = "world_item_inspected"
				prompt.text = "%s // INSPECT // RELEASE I TO LOWER" % str(inspected_world_item.get("label", "OBJECT"))
			if not inspected_id.is_empty():
				PLAYER_ACTION_LEDGER.record(inspected_event, {
					"subject_id": "player", "item": inspected_id, "location": HUNT_LOCATION,
				})
		else:
			inspected_world_item.clear()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _equip_weapon(0)
			KEY_2: _equip_weapon(1)
			KEY_3: _equip_weapon(2)
			KEY_4: _equip_carried_limb()
			KEY_5: _put_the_weapons_down()
			KEY_6: _cycle_smokeable()
			KEY_Y: _toggle_mouth_hold()
			KEY_B:
				if not grapple_target.is_empty():
					_buy_witness_report()
				else:
					_cycle_grip()
			KEY_R:
				if handheld.is_open:
					_cycle_asset_task()
				else:
					_reload_weapon()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				if not panel_mode.is_empty():
					_toggle_panel(panel_mode)
			KEY_F:
				if not third_person and not third_person_unlocked():
					prompt.text = third_person_refusal()
				else:
					third_person = not third_person
					body_motion.set_perspective(not third_person)
					_update_camera()
			# C2.6 v2. Straight to a page, for somebody who knows the device.
			#
			# AG2. F1 is the key somebody who does *not* know it will press, so
			# it opens the keys card unless the device is actually up — the same
			# rule Tab already runs on: the handheld owns its function keys
			# while it is raised, and nothing else while it is pocketed.
			KEY_F1:
				if handheld.is_open:
					handheld.jump_to_mode(0)
				else:
					keys_card.toggle()
			KEY_F2: handheld.jump_to_mode(1)
			KEY_F3: handheld.jump_to_mode(2)
			KEY_F4: handheld.jump_to_mode(3)
			KEY_F5: handheld.jump_to_mode(4)
			KEY_G:
				handheld.toggle_device()
				if handheld.is_open:
					prompt.text = asset_network.roster_line() + " // [R] ISSUE NEXT ORDER"
			KEY_TAB:
				# The handheld owns Tab while raised: one object, modes on it.
				if handheld.is_open:
					handheld.cycle_mode(1)
				else:
					_toggle_panel("index")
			KEY_M: _toggle_panel("map")
			KEY_T: _toggle_panel("tree")
			KEY_J: _toggle_artwork()
			KEY_P: _toggle_panel("board")
			# Agent 1 brief. The Black Mirror as a lens, not just a shutter — N
			# still snaps a photo instantly, unchanged; L holds the view amplified
			# so looking through it is a real choice you can hold rather than a
			# single instant.
			KEY_L: _toggle_black_mirror()
			KEY_C: _start_grapple()
			KEY_Z: _toggle_lock()
			KEY_E: _interact()
			# H, not F: F has toggled the camera since the hunt was built, and a
			# second KEY_F branch in this match is simply never reached.
			KEY_H: _begin_extraction()
			KEY_N: _take_photograph()
			KEY_V:
				if not grapple_target.is_empty():
					_clinch_persuade()
			KEY_X:
				if not grapple_target.is_empty():
					_clinch_threaten()
			KEY_SPACE:
				if not grapple_target.is_empty():
					_break_grapple("YOU LET GO")
				elif wall_running_time > 0.0:
					# AD1.3. Its own outcome, not routed through `_jump()` —
					# that function refuses outright the instant it sees the
					# player is not on the floor, which a wall run always
					# is. Leaving a wall on purpose is a real push away from
					# it, not a fall dressed up as one.
					wall_run_kickoff_queued = true
				else:
					var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
					# AD1.2. Checked before the dodge/jump split, not after —
					# a waist-high thing in front of the player is exactly
					# the situation a plain dodge or a plain jump both
					# handle badly, and the whole point of AD1.2 is that
					# pressing the traversal button should not require
					# knowing which of the three you need.
					var vault := _vault_target(HUNTER_MOTOR.wish_direction(move, yaw))
					if not vault.is_empty():
						_vault(vault.landing)
					elif move.length() > 0.1:
						# A dodge is a directional evasion; standing still
						# and pressing space is not "dodge in place", it is
						# a jump.
						_dodge()
					else:
						_jump()
			KEY_Q: _use_prosthetic_surge()
			KEY_K: _deliberate_redecant()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _pulmonary_diagnostic_active():
			field_interface.rotate_pulmonary(event.relative)
		else:
			apply_look(Vector2(event.relative.x * 0.0026, event.relative.y * 0.0024))


func _pulmonary_diagnostic_active() -> bool:
	return pulmonary_held and grapple_target.is_empty() and panel_mode.is_empty() and not resolution_ui.visible


## The captain's name, upper case, read off the record rather than written
## into a string. Every label that used to carry a hardcoded captain name
## calls this instead.
func _captain_name() -> String:
	var who: Dictionary = WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT))
	return str(who.get("name", "THE CAPTAIN")).to_upper()


func _physics_process(delta: float) -> void:
	if kill_cam.active:
		return
	# The resolution window does not stop the world. Standing over someone
	# deciding what to do with them is supposed to be a risk, so everyone else
	# keeps moving and the body under the form keeps bleeding — only the
	# player's own combat input is suspended, in `_update_player` and `_attack`.
	if resolution_ui.visible:
		_update_resolution_window()
	if not panel_mode.is_empty():
		_update_hud()
		return
	pulse += delta
	_update_smoking(delta)
	_update_handheld_lamp(delta)
	_update_dropped_handheld_persistence(delta)
	_update_flame()
	_update_air()
	_update_body_record(delta)
	# W1.1. The world keeps time, and exactly one place advances it — a clock
	# that two scenes both wind runs at double speed the moment anybody
	# builds a third.
	WorldClock.advance(delta)
	_update_day_night()
	_update_storm_exposure(delta)
	_update_altered_perception()
	_update_perception(delta)
	dodge_remaining = maxf(0.0, dodge_remaining - delta)
	# O2.7 v3. scale_for() only ever reached the encounter loop's actor_delta —
	# the player is the other half of every exchange they are in and kept
	# ticking at full speed through their own hitstop, which is backwards: the
	# whole point of a local freeze is that both bodies in contact feel it.
	var player_delta: float = delta * impact_feel.scale_for("player")
	_advance_arm(player_delta)
	_update_held_inspection(delta)
	_update_first_person_forearms()
	# O2.7 v4. And the gore. Greg: *"gore and chunk physics still run at full
	# speed through a hit, so a limb can leave a body that has not moved
	# yet"*. The rig's own spray and organs take the exchange's clock;
	# severed limbs are RigidBodies the physics server owns, so they are
	# frozen for the length of the hold and handed their velocity back.
	if impact_feel.holding():
		GoreChunks.hold()
	else:
		GoreChunks.release()
	if player_rig != null and is_instance_valid(player_rig):
		player_rig.motion_scale = impact_feel.scale_for("player")
	if strike_windup >= 0.0:
		strike_windup -= player_delta
		if strike_windup < 0.0:
			_resolve_strike()
	attack_cooldown = maxf(0.0, attack_cooldown - player_delta)
	arsenal.tick(player_delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - player_delta)
	# O5.7. You get your feet back by standing in them. Recovery is slower while
	# sprinting, because running is not the same as being balanced.
	var recovery := FOOTING_RECOVERY * (0.55 if Input.is_action_pressed("sprint") else 1.0)
	footing = clampf(footing + recovery * delta, 0.0, 1.0)
	# O2.4. Holding a guard up is work. It drains while raised so a guard cannot
	# simply be left on, and it drops on its own when there is nothing left.
	# X leans on somebody while a clinch is up, so the guard only claims the key
	# when there is nobody in your hands. A control that does two things at once
	# is worse than a control that does nothing.
	var wants_guard := Input.is_key_pressed(KEY_X) and panel_mode.is_empty() and not resolution_ui.visible and grapple_target.is_empty()
	if wants_guard and guard_strength() > 0.0 and stamina > 1.0 and not stumbling():
		if not guarding:
			guard_raised = 0.0
		guarding = true
		guard_raised += delta
		stamina = maxf(0.0, stamina - guard_stamina_drain * delta)
	else:
		guarding = false
		guard_raised = 0.0
	_update_player(delta)
	_update_rival(delta)
	_update_encounter_actors(delta)
	_maintain_roamers(delta)
	_update_carrion(delta)
	_update_extraction(delta, Input.is_key_pressed(KEY_H))
	# Q, not B. B is a stretch away from WASD with the left hand, and this is a
	# *hold* — you are meant to be moving while you do it. Greg: "make the b
	# slider change to like e or idk r or q"; E is interact and R is reload, so
	# Q is the one of the three that is actually free.
	_update_xray(delta, Input.is_key_pressed(KEY_Q))
	# Reports walk home in real time; F1.3's window only exists if it ticks.
	# A report that reaches the faction holding the ground is also the only door
	# into local unrest — the global event log never dispatches law by itself.
	_answer_local_reports(witness_ledger.tick(delta))
	if misfire_director != null:
		misfire_director.call("update_player_position", player)
	if not grapple_target.is_empty():
		_update_grapple(delta)
	_steer_lock(delta)
	_unlock_feel_timer -= delta
	if _unlock_feel_timer <= 0.0:
		_unlock_feel_timer = 1.0
		_check_third_person_unlock_feel()
	_update_camera()
	_update_hud()
	_update_sleep_prompt(delta)
	_update_dropped_handheld_prompt()


## B4.10v2. The world notices unattended flesh. This is deliberately part of
## the Hunt Grounds loop, not a test-only consumer: a scavenger is drawn to the
## same rotten, identified chunks that the player could otherwise rob.
func _update_carrion(delta: float) -> void:
	for index in range(carrion_scavengers.size() - 1, -1, -1):
		var scavenger := carrion_scavengers[index]
		if scavenger == null or not is_instance_valid(scavenger):
			carrion_scavengers.remove_at(index)
			continue
		scavenger._process(delta)
	if not carrion_scavengers.is_empty() or GoreChunks.scent_sources().is_empty():
		return
	var carrion := CARRION_SCAVENGER.new()
	carrion.name = "CarrionEater"
	add_child(carrion)
	carrion.global_position = player + Vector3(8.0, 0.0, -5.0)
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.26
	mesh.height = 0.62
	body.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4a3d20")
	material.roughness = 0.9
	body.material_override = material
	carrion.add_child(body)
	carrion_scavengers.append(carrion)
	# Charted by walking, not by opening the map.
	living_map.observe(player, yaw)


func _update_player(delta: float) -> void:
	if player_rig.is_downed() or player_rig.anatomy.dead:
		return
	# AD1.2. Under scripted motion rather than normal control for the
	# vault's short duration — the eased position itself is the whole
	# animation, and normal gravity/floor-stick would just fight it.
	if vaulting_time > 0.0:
		vaulting_time = maxf(0.0, vaulting_time - delta)
		var progress := 1.0 - vaulting_time / vault_duration
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		player_body.position = vault_from.lerp(vault_to, eased)
		if vaulting_time <= 0.0:
			player_body.position = vault_to
			# AD1.5. Handed back rather than left at the zero `_vault()`
			# set it to — the run this vault interrupted keeps going on
			# the far side instead of rebuilding from a standing start.
			player_body.velocity = vault_entry_velocity
		player = player_body.position + Vector3.UP * 0.6
		return
	# AD1.4. A scripted takeover the same way the vault above is — real
	# gravity and floor-stick would fight straight vertical motion exactly
	# as they would a lerp.
	if climbing_time > 0.0:
		# AD1.5. The climb does not stop to ask: `_vault_target()` is read
		# from wherever the climb has actually got to, `false` waiving its
		# own on-floor gate since a body mid-climb is airborne against a
		# wall by definition. The instant a ledge is within reach it hands
		# straight into the identical scripted mantle a running vault would
		# use — one motion, not two verbs meeting at a seam.
		var mantle := _vault_target(climb_direction, false)
		if not mantle.is_empty():
			climbing_time = 0.0
			# AD1.5. `_vault()` is about to capture `player_body.velocity` as
			# what the far side lands with; left alone that would be the
			# climb loop's own small into-the-wall vector, not the run that
			# led into the climb in the first place.
			player_body.velocity = climb_direction * climb_entry_speed
			_vault(mantle.landing)
			return
		var still_climbing := _climb_wall(climb_direction, false)
		if still_climbing.is_empty() or stamina <= 0.0:
			# The wall ran out, curved away, or the body is spent. Falling
			# is the honest outcome — there is no ledge to catch and no
			# cutscene papering over it.
			climbing_time = 0.0
		else:
			climbing_time = maxf(0.0, climbing_time - delta)
			climb_normal = still_climbing.normal
			stamina = clampf(stamina - CLIMB_STAMINA_DRAIN * delta, 0, 100)
			# AD1.6. Pressed lightly into the wall so the body reads as
			# climbing it rather than floating in front of it, at a speed
			# the same `mobility_ratio()` floor every other traversal verb
			# already answers to scales down.
			player_body.velocity = -climb_normal * 0.6
			player_body.velocity.y = CLIMB_SPEED * lerpf(0.6, 1.0, player_rig.anatomy.mobility_ratio())
			player_body.move_and_slide()
			player = player_body.position + Vector3.UP * 0.6
			return
	# AD1.3. Also a scripted takeover rather than something layered on top of
	# HUNTER_MOTOR.move_body() — re-finding the wall every frame (it can
	# curve or run out mid-attempt) and redirecting velocity along it, with
	# only a fraction of real gravity rather than none, so a run reads as a
	# body fighting to stay up rather than flight.
	if wall_running_time > 0.0:
		var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var wish: Vector3 = HUNTER_MOTOR.wish_direction(move_input, yaw)
		var surface := _wall_run_surface(wish if not wish.is_zero_approx() else wall_run_normal.cross(Vector3.UP))
		if surface.is_empty() or player_body.is_on_floor() or wall_run_kickoff_queued:
			wall_running_time = 0.0
		else:
			wall_running_time = maxf(0.0, wall_running_time - delta)
			wall_run_normal = surface.normal
			var tangent: Vector3 = surface.tangent
			var wall_speed: float = maxf(Vector2(player_body.velocity.x, player_body.velocity.z).length(), WALL_RUN_MIN_SPEED)
			var desired: Vector3 = tangent * wall_speed
			player_body.velocity.x = desired.x
			player_body.velocity.z = desired.z
			player_body.velocity.y -= HUNTER_MOTOR.GRAVITY * WALL_RUN_GRAVITY_SCALE * delta
			player_body.move_and_slide()
			player = player_body.position + Vector3.UP * 0.6
			return
		if wall_run_kickoff_queued:
			# Kicking off, not merely falling off: a real impulse away from
			# the wall and up, so leaving one on purpose (its own key,
			# checked in `_unhandled_input` before the dodge/jump split)
			# reads differently from simply running off the end of it.
			wall_run_kickoff_queued = false
			player_body.velocity += wall_run_normal * WALL_RUN_KICKOFF_OUT
			player_body.velocity.y = WALL_RUN_KICKOFF_UP
			WorldHistory.record_event("player_wall_run_kickoff", {"location": HUNT_LOCATION})
			player_body.move_and_slide()
			player = player_body.position + Vector3.UP * 0.6
			return
	# Standing over a downed body with the form open costs you your footwork,
	# and so does having hold of someone.
	if resolution_ui.visible or not grapple_target.is_empty():
		player_body.velocity = Vector3.ZERO
		return
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = HUNTER_MOTOR.wish_direction(move, yaw)
	crouching = Input.is_action_pressed("crouch") and dodge_remaining <= 0.0
	# AG4.1. TaKeS, second playtest: *"when running and the stamina bar depletes,
	# the screen becomes super jittery — i assume since its trying to set it to
	# the run speed, then checks to see if the stamina is low"*. That is exactly
	# the bug, and exactly the cause.
	#
	# The flag was gated on `stamina > 1.0`, and the same frame spends 26/s while
	# sprinting and recovers 18/s while not. At the bottom of the bar that is a
	# loop: over the line, sprint, drop under the line, walk, recover over the
	# line, sprint — flipping every two or three frames, taking the movement
	# speed and the animation state with it.
	#
	# One threshold cannot express "running out of breath"; two can. You sprint
	# until there is nothing left, and then you are winded until you have got a
	# real amount of it back. No oscillation is possible because the two
	# thresholds cannot both be crossed in the same frame, and it is a better
	# mechanic than the one it replaces.
	var wants_sprint := Input.is_action_pressed("sprint") and not crouching and move.length() > 0.0
	if winded and stamina >= SPRINT_RECOVER:
		winded = false
	elif not winded and stamina <= 0.5:
		winded = true
	var sprinting := wants_sprint and not winded
	var speed := 3.4 if crouching else (SPRINT_SPEED if sprinting else PLAYER_SPEED)
	# AD1.5. And even a legitimate change of gait is eased into rather than
	# stepped, so starting and stopping a run reads as a body doing it.
	_gait_speed = move_toward(_gait_speed, speed, delta * 26.0)
	speed = _gait_speed
	# B6.5. The rig has been recording where the player is hurt since it was
	# built and nothing ever read it back, so the player was the one body in the
	# world that fought and ran exactly as well with one leg as with two. Floored
	# rather than scaled straight off `mobility_ratio`, because a game you cannot
	# retreat from is a game that is over.
	speed *= _player_speed_scale()
	# A melee press is one committed swing, not an automatic attack repeated by
	# holding the mouse. You can still steer it, but not sprint through its tell.
	speed *= COMBAT_RESPONSE.movement_scale(pending_attack, strike_windup)
	player_capsule.height = move_toward(player_capsule.height, 1.2 if crouching else 1.8, delta * 4.0)
	player_collider.position.y = (player_capsule.height - 1.8) * 0.5
	# AD1.1. Handed to move_body() rather than applied after it: is_on_floor()
	# only turns false once a move_and_slide() has actually carried the body
	# up off the ground, so an impulse set the frame after this one reads a
	# still-grounded body and gets overwritten straight back to -FLOOR_STICK.
	# The jump and the slide that proves it happen in the same physics step.
	var jumping := jump_queued and player_body.is_on_floor()
	# AD3.2. A leg with drive hardware can kick off nothing. Binary, not a
	# multiplier: a bare body simply cannot leave the ground a second time,
	# and an augmented one can, once, until it touches down again. Gated on
	# the same `capable_limbs()` route B6.1 established, so a severed leg
	# takes the move with it (B6.2) without this line hearing about it.
	var kicking_off := false
	if jump_queued and not jumping and not player_body.is_on_floor():
		if kick_off_spent <= 0 and player_rig != null and is_instance_valid(player_rig) and not player_rig.capable_limbs("kick_off").is_empty():
			kicking_off = true
			kick_off_spent += 1
	if player_body.is_on_floor():
		kick_off_spent = 0
	jump_queued = false
	# AD1.6. The same floor B6.5 already put under running speed and combat
	# strength, not a new one invented for jumping — a hobbled body should
	# leave the ground with a hobbled body's own jump, not a healthy one's.
	var leaving_ground := jumping or kicking_off
	HUNTER_MOTOR.move_body(player_body, direction, speed, delta, dodge_direction if dodge_remaining > 0.0 else Vector3.ZERO, 16.0, JUMP_IMPULSE * _player_speed_scale() if leaving_ground else 0.0)
	if jumping:
		WorldHistory.record_event("player_jumped", {"location": HUNT_LOCATION})
	if kicking_off:
		WorldHistory.record_event("player_kicked_off", {"location": HUNT_LOCATION})
	# AD1.3. Starting a run needs no key at all — the body grabs the wall
	# the instant it is airborne, fast, and next to one, the same way real
	# momentum would. Only leaving one on purpose (the kickoff, above) is a
	# deliberate act; falling into one is not.
	if wall_running_time <= 0.0 and not player_body.is_on_floor() and not jumping:
		var starting_surface := _wall_run_surface(direction if not direction.is_zero_approx() else HUNTER_MOTOR.wish_direction(Vector2(0, -1), yaw))
		if not starting_surface.is_empty():
			_begin_wall_run(starting_surface)
	# AD1.4. Also needs no key — the Prototype reference is a body that runs
	# at a building and keeps going up it, not one that stops to press
	# something first. Unlike the wall run above, this fires from the
	# ground too: the whole point is a sprint straight into a wall turning
	# into a climb with no seam, not only a jump that happened to land
	# against one.
	if climbing_time <= 0.0 and wall_running_time <= 0.0 and vaulting_time <= 0.0 and sprinting and move.length() > 0.1:
		var climb_start := _climb_wall(direction)
		if not climb_start.is_empty():
			_begin_climb(direction, climb_start.normal)
	if player_body.position.y < -10.0:
		player_body.position = Vector3(0, 1.0, 19)
	player = player_body.position + Vector3.UP * 0.6
	stamina = clampf(stamina + (-26.0 if sprinting else 18.0) * delta, 0, 100)
	# O2.7 v3. Movement itself stays on the real clock — hitstop is not meant
	# to take your feet out from under you — but the rig's own animation (the
	# swing pose, the raised arm, the walk cycle) is the visible half of "the
	# blow met resistance" and was still posing at full speed through it.
	var animation_delta: float = delta * impact_feel.scale_for("player")
	body_motion.update(animation_delta, player_body.velocity, player_body.is_on_floor(), sprinting, crouching, dodge_remaining > 0.0)
	hunter_appearance.set_mouth(player_rig.anatomy.pain / 180.0, sin(pulse * 0.7) * player_rig.anatomy.pain / 100.0)


## AN1.2. Where the camera turns, in radians, and the one seam the arm is
## driven through. Split out of `_unhandled_input` because the mouse branch
## there is gated on MOUSE_MODE_CAPTURED, which a headless run can never be —
## so a test feeding it motion events was exercising nothing and passing on
## the weapon's gravity sag. Same reason `lean_override` and
## `grapple_pushing_override` exist.
func apply_look(turn: Vector2) -> void:
	yaw -= turn.x
	pitch = clamp(pitch - turn.y, -0.75, 0.42)
	# Accumulated rather than applied: several motion events arrive per frame
	# and handing the arm each one separately throws it several times as hard.
	_look_delta += turn


## AN1.5. Mass and reach per weapon — the entire firearms-and-melee balance
## conversation, expressed as two numbers rather than as a table of constants.
## A bare hand is about 0.4kg, a cleaver 1.4, a sledge 6.
const ARM_WEIGHTS := {
	"sword": {"mass": 1.45, "reach": 0.62},
	"shotgun": {"mass": 3.2, "reach": 0.5},
	"sidearm": {"mass": 0.95, "reach": 0.22},
	"severed_limb": {"mass": 2.6, "reach": 0.58},
	"bare": {"mass": 0.4, "reach": 0.28},
	# AN1.9. A held body is not a free hand — both arms are committed to it,
	# heavier than anything carried one-handed. Pushing for advantage
	# (`grapple_pushing_now`) commits the whole body's weight into the hold
	# rather than just maintaining it, which is why it outweighs even the
	# severed limb.
	"grapple": {"mass": 1.8, "reach": 0.5},
	"shove": {"mass": 2.4, "reach": 0.55},
}


## AN2.4. A weapon's own base stiffness before condition takes anything off
## it — `LimbMomentum.carry()`'s own former default, named here because a
## worn weapon now needs a real number to be worn *from*.
const WEAPON_BASE_STIFFNESS := 58.0
## AN2.5. Which grips a weapon actually offers, in the order `B` cycles them.
## Only the sword has a real choice to make — a shotgun and a sidearm each
## have exactly one grip already (`HeldGear._default_grip`), so cycling them
## would be a key that does nothing every time it is pressed.
const GRIP_CYCLE := {
	"sword": ["two_hand", "one_hand", "half_sword"],
}
## `HeldGear`'s own default for the sword — kept in sync by `_cycle_grip()`
## rather than duplicated, since a fresh sword pull should start exactly
## where `_default_grip()` already puts it.
var current_grip := "two_hand"

## AN2.5. "Two-handing changes the numbers, not just the pose." `held_gear.gd`'s
## `GRIPS` table already carried `reach`, `damage_type` and now `control` per
## grip — its own header comment names the claim directly — and nothing ever
## read them outside that file. This is the read: three real grips for the
## one weapon that has a real choice between them, cycled rather than a
## dedicated key each, because a fourth key for a weapon nobody has drawn yet
## is exactly the kind of binding that never gets discovered.
func _cycle_grip() -> void:
	var id := str(arsenal.current_id) if arsenal != null else ""
	var options: Array = GRIP_CYCLE.get(id, [])
	if options.is_empty():
		return
	var index := options.find(current_grip)
	current_grip = options[(index + 1) % options.size()] if index >= 0 else options[0]
	var spec: Dictionary = HeldGear.GRIPS.get(current_grip, {})
	prompt.text = "%s // %s GRIP" % [str(arsenal.current().label), current_grip.to_upper().replace("_", "-")]
	WorldHistory.record_event("grip_changed", {"weapon": id, "grip": current_grip, "location": HUNT_LOCATION})
	_carry_current_weapon(true)


func _carry_current_weapon(force := false) -> void:
	if arm == null:
		return
	var id := "bare"
	# AN1.9. Holding somebody takes both hands regardless of what is
	# holstered, so this is checked ahead of the weapon and the bare-hand
	# state rather than beside them.
	if not grapple_target.is_empty():
		id = "shove" if grapple_pushing_now else "grapple"
	elif bare_handed:
		id = "bare"
	elif carried_limb_index >= 0:
		id = "severed_limb"
	elif arsenal != null:
		id = str(arsenal.current_id)
	var spec: Dictionary = ARM_WEIGHTS.get(id, ARM_WEIGHTS["sword"])
	# AN2.4. Bare hands and a carried limb are not entries in the arsenal's own
	# condition table — `weapon_condition` reads 1.0 for anything it has never
	# heard of, which is exactly "unworn" and asks for nothing special here.
	var condition: float = arsenal.weapon_condition(id) if arsenal != null else 1.0
	var target_stiffness := WEAPON_BASE_STIFFNESS * lerpf(0.45, 1.0, condition)
	var reach: float = float(spec["reach"])
	# AN2.5. Only the weapons `GRIP_CYCLE` actually offers a choice for read
	# their own grip's numbers — everything else keeps exactly the reach and
	# stiffness it always had, unaffected by a grip nothing lets it change.
	if GRIP_CYCLE.has(id):
		var grip_spec: Dictionary = HeldGear.GRIPS.get(current_grip, {})
		reach *= float(grip_spec.get("reach", 1.0))
		target_stiffness *= float(grip_spec.get("control", 1.0))
	if not force and is_equal_approx(arm.mass, float(spec["mass"])) and is_equal_approx(arm.reach, reach) and is_equal_approx(arm.stiffness, target_stiffness):
		return
	arm.carry(float(spec["mass"]), reach, target_stiffness)


## AN1.2/AN1.6. One call a frame. The arm is given what the player did — how far
## they turned, how fast their body is moving, how much is left in them — and it
## works out where the weapon ended up.
func _advance_arm(step: float) -> void:
	if arm == null:
		return
	_carry_current_weapon()
	# AN1.6. A tired arm cannot hold the weapon where it wants it. Straight off
	# stamina, so the guard degrades rather than being switched off at a
	# threshold.
	arm.fatigue = clampf(1.0 - stamina / 100.0, 0.0, 1.0)
	# The body's own motion, in view space: walking into a blow counts.
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var moving := player_body.velocity
	arm.advance(step, _look_delta, Vector3(moving.dot(right), moving.y, -moving.dot(forward)))
	_look_delta = Vector2.ZERO
	_pose_weapon()


## AN1.3. The weapon is drawn where the physics put it. The model hangs off the
## rig's right arm, so this is a local offset on that node rather than a second
## transform chain — the hand still animates, and the weapon lags the hand.
func _pose_weapon() -> void:
	if arsenal == null or arsenal.hand == null or not is_instance_valid(arsenal.hand):
		return
	var model: Node3D = arsenal.models.get(str(arsenal.current_id)) as Node3D
	if model == null or not is_instance_valid(model):
		return
	var lag := arm.at - arm.anchor
	if not model.has_meta("rest_position"):
		model.set_meta("rest_position", model.position)
	# The rest *rotation*, cached the same way the rest position already was.
	#
	# This line is the floating sword. The position below adds sway to an
	# authored rest; the rotation used to simply be assigned, which threw away
	# the counter-rotation `hunter_arsenal._build_weapon_model` writes — the one
	# whose whole job is to cancel the arm pitch `hunter_body_motion` applies in
	# first person, and which carries a comment explaining that it is read from
	# `FIRST_PERSON_ARM_RAISE` so retuning the pose cannot lay the blade across
	# the view. Every frame, that cancellation was discarded and replaced with a
	# sway-only rotation, so the weapon inherited the full forward pitch of the
	# arm and hung in the air at an angle nobody had chosen. Two passes at
	# re-tuning the mount could not fix it, because the mount was not what was
	# wrong.
	if not model.has_meta("rest_rotation"):
		model.set_meta("rest_rotation", model.rotation)
	var rest: Vector3 = model.get_meta("rest_position")
	var rest_rotation: Vector3 = model.get_meta("rest_rotation")
	# Scaled down from view space to hand space: the arm swings through 0.42m at
	# full stretch and a weapon model that moved that far would leave the screen.
	model.position = rest + lag * 0.38
	model.rotation = rest_rotation + Vector3(arm.tilt.x * 0.5, arm.tilt.y * 0.5, -arm.tilt.y * 0.3)
	# Inspection may temporarily move or re-pose fingers (a pistol press-check is
	# not a shotgun receiver check). Restore authored contact before the current
	# frame's inspection choreography is layered on, so release cannot leave a
	# hand stranded away from its grip.
	_restore_grip_hand(model.get_node_or_null("RightGripHand") as Node3D, "trigger" if str(arsenal.current_id) in ["shotgun", "sidearm"] else "wrap")
	_restore_grip_hand(model.get_node_or_null("LeftGripHand") as Node3D, "cup" if str(arsenal.current_id) == "sidearm" else "wrap")


func _attack(heavy := false) -> void:
	if resolution_ui.visible or kill_cam.active or player_rig.is_downed() or player_rig.anatomy.dead:
		return
	if smoke_model != null and is_instance_valid(smoke_model):
		return
	# In a clinch the strike button is the press, not a swing.
	if not grapple_target.is_empty():
		return
	if not panel_mode.is_empty():
		return
	# AS1.2. Holding the handheld up is a real cost, not a free extra hand —
	# raised past the halfway point of its own blend is the same threshold
	# `is_lit()` uses for the lamp, so a hand is busy exactly when the light is on.
	if handheld.raised > 0.5:
		return
	var report: Dictionary = _begin_carried_limb_attack(heavy) if carried_limb_index >= 0 else arsenal.begin_attack(heavy)
	if not bool(report.get("accepted", false)):
		if str(report.get("reason", "")) == "empty":
			prompt.text = "DRY / [R] RELOAD"
		elif str(report.get("reason", "")) == "jammed":
			prompt.text = "JAMMED / [R] CLEAR"
		return
	var cost := float(report.get("stamina", 0.0))
	if stamina < cost:
		# Refund a firearm round if a future ranged weapon gains a stamina cost.
		if str(report.kind) == "firearm":
			var rounds: Dictionary = arsenal.ammo[arsenal.current_id]
			rounds.loaded = int(rounds.loaded) + 1
			arsenal.ammo[arsenal.current_id] = rounds
		return
	stamina -= cost
	# B6.5/B6.6. The same `combat_ratio` that already slows a one-armed NPC now
	# slows the player's own swing and takes the weight out of it. Reciprocity is
	# the whole point of B6: a fight that continues after a limb comes off has to
	# continue that way in both directions.
	if bare_handed:
		var fists := bare_hand_attack(bool(report.get("heavy", false)))
		if not bool(fists.get("accepted", false)):
			if str(fists.get("reason", "")) == "no arms":
				prompt.text = "NOTHING LEFT TO SWING"
			return
		report = fists
	# AN2.5. The grip decides what kind of blow this actually is — a
	# half-sworded thrust is not a cut that happens to be shorter, it is a
	# different `damage_type` reaching `strike()`'s own AN2.3 answer for
	# armour, bone and wall. Melee only, and only a weapon `GRIP_CYCLE` has
	# a real choice for: bare hands and a carried limb have no grip to read.
	if not bare_handed and carried_limb_index < 0 and str(report.get("kind", "")) != "firearm" and GRIP_CYCLE.has(str(arsenal.current_id)):
		var grip_spec: Dictionary = HeldGear.GRIPS.get(current_grip, {})
		if grip_spec.has("damage_type"):
			report["damage_type"] = grip_spec["damage_type"]
	var swing := _player_swing_scale()
	# O5.1. The body's own motion is part of the blow.
	var momentum := swing_momentum(player_body.velocity)
	# AN1.4. What the arm was actually doing, measured. Recorded either way so
	# the two systems can be compared against the same swings; it only reaches
	# the damage number when `momentum_damage` says so (AN1.8).
	last_commitment = arm.commitment() if arm != null else 0.0
	report["commitment"] = last_commitment
	# AN2.1. Committing to a heavy blow leaves you open whether or not it
	# lands — the vulnerability is in throwing it, not in missing with it.
	# Firearms carry no such wind-up; `arm.commitment()` still measures barrel
	# drift for AN1.7, and that is not the same thing as being off balance.
	if str(report.get("kind", "")) != "firearm" and last_commitment > 0.0:
		lose_footing(last_commitment * FOOTING_COMMITTED_SWING, "")
	# O5.1/O5.2 v5. The weapon sets the ceiling and the player earns how much
	# of it they get. Floored well above zero: a game where a mistimed swing
	# does nothing at all is a game that feels broken rather than demanding.
	# Melee only — `commitment()`'s reference was calibrated against melee
	# gestures (AN1.4's own table), and a firearm's low, steady aim would read
	# as low commitment too, quietly halving gun damage on every shot that
	# wasn't thrown around like a swing.
	if momentum_damage and arm != null and str(report.get("kind", "")) != "firearm":
		report["damage"] = float(report.get("damage", 0.0)) * lerpf(0.35, 1.35, last_commitment)
	report["damage"] = float(report.get("damage", 0.0)) * swing * float(momentum["power"])
	report["impulse"] = float(report.get("impulse", 0.0)) * float(momentum["power"])
	report["momentum"] = momentum
	register_swing()
	attack_cooldown = float(report.get("cooldown", arsenal.cooldown)) / maxf(0.35, swing) * float(momentum["recovery"])
	pending_attack = report
	body_motion.trigger_attack(maxf(float(report.get("windup", 0.0)), attack_cooldown * 0.62), str(report.kind))
	if str(report.weapon) == "severed_limb":
		_wear_carried_limb(bool(report.get("heavy", false)))
	if str(report.kind) == "firearm":
		body_motion.trigger_recoil(float(report.impulse))
		_resolve_firearm(report)
		pending_attack = {}
	else:
		strike_windup = float(report.windup)


func _resolve_strike() -> void:
	var report := pending_attack
	# AN2.1. Whatever happens next, the swing is spent. Landing bounces the
	# weapon back off what stopped it; missing carries it through, which is why
	# a miss costs footing.
	var connected := false
	if report.is_empty():
		report = {"damage": 24.0, "impulse": 18.0, "damage_type": "cut", "range": 4.1, "weapon": "sword"}
	pending_attack = {}
	# AD3.3. A round crossing the arc is a physical thing that can be met.
	# Checked before anything else the swing could reach, because a round in
	# the path is the most immediate thing in it — and because a build that
	# answers a shot with a blade has to be allowed to, or "the distance is
	# the puzzle" (AD3.1) has no answer available to it at all.
	if ballistics != null and is_instance_valid(ballistics):
		var reach := float(report.get("range", 4.1))
		var facing_now := Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
		var met: int = ballistics.intercept_near(player + facing_now * reach * 0.6, reach * 0.5, str(report.get("weapon", "")))
		if met > 0:
			if arm != null:
				arm.strike(ROUND_MELEE_RESISTANCE, -facing_now)
			# Less than the stone of a wall (AN2.4) and more than air: meeting
			# an edge against something small and fast marks the edge.
			_wear_current_weapon(str(report.get("weapon", "")), 0.6)
			PLAYER_ACTION_LEDGER.record("melee_met_round", {
				"weapon": str(report.get("weapon", "")), "rounds": met, "location": HUNT_LOCATION,
			})
			prompt.text = "CUT IT OUT OF THE AIR" if met == 1 else "CUT %d OF THEM OUT OF THE AIR" % met
			return
	if _attack_nearest_encounter_actor(report):
		if arm != null:
			# AN2.3. Set by the call above, from what that specific blow actually
			# hit — armour and bone answer through the arm differently now.
			arm.strike(_last_melee_resistance, Vector3(sin(yaw), 0.0, cos(yaw)))
		connected = true
		return
	var wall_hit := _attack_wall(float(report.get("range", 4.1)))
	if not wall_hit.is_empty():
		# AN2.3. The half that stayed open: a wall answers too, harder than
		# any body zone, and takes the same kind of edge off the weapon
		# armour already does (AN2.4) — a blade stopped dead by stone should
		# not come away in the same condition a clean miss leaves it in.
		if arm != null:
			arm.strike(WALL_MELEE_RESISTANCE, wall_hit.normal)
		_wear_current_weapon(str(report.get("weapon", "")), 1.0)
		ballistics.mark_impact(wall_hit.position, wall_hit.normal, float(report.get("damage", 24.0)) * 0.05)
		PLAYER_ACTION_LEDGER.record("melee_struck_wall", {"weapon": str(report.get("weapon", "")), "location": HUNT_LOCATION})
		prompt.text = "STEEL ON STONE"
		connected = true
		return
	if enemy == null or not enemy.visible or enemy_retreating:
		if arm != null and not connected:
			arm.whiff()
		return
	var distance := player.distance_to(enemy.global_position)
	if distance > 4.1:
		if arm != null and not connected:
			arm.whiff()
		return
	var facing := Vector3(sin(yaw), 0, cos(yaw)).normalized().dot((enemy.global_position - player).normalized())
	if facing < 0.18:
		return
	var damage := 22 if story_step > 0 else 15
	# Anatomy, the landed-action receipt, rival memory and a possible retreat
	# are all consequences of this one completed swing.
	WorldHistory.begin_ledger_batch()
	# Mara's wounds used to be picked from her remaining health — "left arm"
	# below 55, "leg" below 28 — so where the player aimed never mattered and
	# nothing landed on her body. She has a rig now, so the blow resolves
	# against it exactly the way it does for everyone else in the region.
	var body_zone := "torso"
	if enemy_rig != null and is_instance_valid(enemy_rig):
		var look := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
		var along := player + look * clampf((enemy.global_position - player).dot(look), 0.6, 4.1)
		var lateral := along - enemy.global_position
		lateral.y = 0.0
		if lateral.length() > 0.45:
			lateral = lateral.normalized() * 0.45
		var aim := enemy.global_position + Vector3(lateral.x, look.y * 4.1 * 1.2, lateral.z)
		var hit_record := enemy_rig.hit_at(aim, float(damage), float(damage) * 0.8, "cut", look)
		body_zone = str(hit_record.get("zone", "torso"))
		WorldHistory.update_subject(CAST.id_for(CAPTAIN_SLOT), {"anatomy_state": enemy_rig.snapshot()}, "anatomy_changed")
	if enemy_rig != null and is_instance_valid(enemy_rig):
		enemy_health = roundi(float(enemy_health_max) * _rig_health_ratio(enemy_rig))
	else:
		enemy_health = maxi(0, enemy_health - damage)
	_spawn_blood(enemy.global_position + Vector3(0, 1.2, 0), damage)
	PLAYER_ACTION_LEDGER.record("melee_body_hit", {"target": CAST.id_for(CAPTAIN_SLOT), "body_zone": body_zone, "damage": damage, "location": HUNT_LOCATION})
	# Untyped rebuild rather than .duplicate(): the stored array can already be
	# a TypedArray[Dictionary] by the time some other subject touched "wounds"
	# first, and .duplicate() carries that runtime type over — has()/append()
	# with this plain string then fail the type check instead of just working.
	var wounds: Array = []
	for existing in WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT)).get("wounds", []):
		wounds.append(existing)
	var wound := "cut %s" % body_zone
	if not wounds.has(wound):
		wounds.append(wound)
	WorldHistory.update_subject(CAST.id_for(CAPTAIN_SLOT), {"injury": wound, "wounds": wounds, "grudge": mini(100, int(WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT)).get("grudge", 0)) + 14), "status": "fighting"}, "rival_injured")
	if enemy_health <= 0:
		_rival_retreats("You left Mara alive. She will return altered.")
	WorldHistory.commit_ledger_batch()


func _attack_nearest_encounter_actor(attack: Dictionary = {}) -> bool:
	if attack.is_empty():
		attack = {"damage": 24.0, "impulse": 18.0, "damage_type": "cut", "range": 4.1, "weapon": "sword"}
	var nearest_index := -1
	var nearest_distance := 99999.0
	var best_aim_score := INF
	var reach := float(attack.get("range", 4.1))
	var view := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	for index in encounter_actors.size():
		var candidate: Dictionary = encounter_actors[index]
		var node := candidate.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(candidate.get("dead", false)):
			continue
		if candidate.anatomy.downed or str(candidate.get("disposition", "hostile")) != "hostile":
			continue
		var distance := player.distance_to(node.global_position)
		if distance > reach:
			continue
		# A locked target wins regardless of who has wandered closer, which is
		# the entire reason to have a lock.
		if not lock_target.is_empty() and str(candidate.subject_id) == lock_target:
			nearest_distance = distance
			nearest_index = index
			break
		# Melee was choosing the nearest eligible body, even if the player's
		# weapon and camera were aimed at somebody standing beside it. The attack
		# now selects within a real forward arc; dead-centre aim wins over a body
		# a few centimetres nearer off the shoulder. The later `hit_at()` still
		# decides the exact zone, so this is target intent, not aim assist.
		# Measured from `player` and flattened, for two separate reasons.
		#
		# From `player`, because `view` is built out of `yaw`/`pitch` — the
		# hunter's own facing — while this was measuring from `camera`, the node.
		# Those agree only once the camera has been positioned for the frame, so
		# any caller reaching this before that (or with physics off, which is how
		# `opening_test` drives it) compared a direction taken from the hunter
		# against an origin taken from wherever the camera node happened to sit.
		# The arc then rejected a body standing two metres dead ahead.
		#
		# Flattened, because the arc exists to choose between two bodies standing
		# beside one another, which is a question about yaw. Pitch chooses the
		# *zone* on the body already picked — `hit_at()` reads it to tell a head
		# from a thigh — so folding pitch in here means looking up or down
		# refuses the body you are standing in front of.
		var flat_view := Vector3(view.x, 0.0, view.z)
		var flat_to := Vector3(node.global_position.x - player.x, 0.0, node.global_position.z - player.z)
		var aim_dot := 1.0
		if flat_view.length_squared() > 0.0001 and flat_to.length_squared() > 0.0001:
			aim_dot = flat_view.normalized().dot(flat_to.normalized())
		if aim_dot < 0.32:
			continue
		var aim_score := distance + (1.0 - aim_dot) * reach * 2.4
		if aim_score < best_aim_score:
			best_aim_score = aim_score
			nearest_distance = distance
			nearest_index = index
	if nearest_index < 0 or nearest_distance > reach:
		return false
	var actor: Dictionary = encounter_actors[nearest_index]
	var target: Node3D = actor.node as Node3D
	var facing := Vector3(sin(yaw), 0, cos(yaw)).normalized().dot((target.global_position - player).normalized())
	if facing < 0.12:
		return false
	var anatomy: Node = actor.anatomy as Node
	var rig := actor.get("rig") as BaselineHuman
	var zone := "torso"
	var result: Dictionary = {}
	WorldHistory.begin_ledger_batch()
	if rig != null and is_instance_valid(rig):
		# Where you are looking decides what you open. The zone used to come from
		# (event_count + index) % 6 — a round-robin, so aiming at a head and
		# aiming at a knee produced the same sequence of wounds.
		var look := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
		# A melee swing connects with the body in front of you; what the aim
		# chooses is *where on that body*. Resolving a free world-space point
		# instead made the zone depend on how far off-axis or how much higher
		# the target happened to be standing, so a level swing at someone on a
		# kerb opened an arm when the player was looking at a head.
		var along := player + look * clampf((target.global_position - player).dot(look), 0.6, reach)
		var lateral := along - target.global_position
		lateral.y = 0.0
		if lateral.length() > 0.45:
			lateral = lateral.normalized() * 0.45
		var aim := target.global_position + Vector3(lateral.x, look.y * reach * 1.2, lateral.z)
		result = rig.hit_at(aim, float(attack.damage), float(attack.impulse), str(attack.damage_type), look)
		zone = str(result.get("zone", "torso"))
	else:
		result = anatomy.call("apply_hit", zone, float(attack.damage), float(attack.impulse), str(attack.damage_type))
	_last_melee_resistance = _melee_resistance(zone, result)
	_wear_current_weapon(str(attack.get("weapon", "")), float(result.get("absorbed", 0.0)))
	var organ_hit := str((result.get("organ", {}) as Dictionary).get("zone", ""))
	if not organ_hit.is_empty() and bool((result.get("organ", {}) as Dictionary).get("ruptured", false)):
		prompt.text = "%s IS OPENED UP" % str(actor.display_name).to_upper()
	WorldHistory.update_subject(str(actor.subject_id), {"anatomy_state": anatomy.call("snapshot")}, "anatomy_changed")
	_spawn_blood(target.global_position + Vector3(0, 1.1, 0), roundi(float(attack.damage)))
	# One committed swing can open one body. Route that intentional boundary;
	# anatomy_changed and any gore remain consequences, not extra player acts.
	PLAYER_ACTION_LEDGER.record("npc_anatomy_hit", {"subject_id": actor.subject_id, "weapon": attack.weapon, "zone": zone, "result": result, "location": HUNT_LOCATION})
	if bool(result.get("severed", false)) and not anatomy.dead and not anatomy.downed:
		_apply_maiming_state(actor, [zone], result.get("sever_direction", Vector3.ZERO))
	elif anatomy.critical or anatomy.pain >= 68.0:
		actor.state = "fleeing"
		actor.loot_at_risk = true
		prompt.text = "%s IS BLEEDING OUT AND ESCAPING — CHASE FOR THEIR LOOT OR LET THEM GO." % str(actor.display_name).to_upper()
	else:
		_apply_combat_response(actor, attack, result)
	if anatomy.dead:
		_kill_encounter_actor(nearest_index, "combat_trauma")
	WorldHistory.commit_ledger_batch()
	return true


## AN2.3. What the arm actually feels through the weapon, from what it hit
## rather than a constant every blow shared. `BASE` is bone density, not
## damage — the head stops a blade harder than a limb does whether or not
## either is armoured, which is what makes an armoured hit *and* a skull hit
## both read as more resistant than an unarmoured torso without conflating
## the two causes into one number.
const MELEE_RESISTANCE_BASE := {
	"head": 0.72, "torso": 0.55,
	"left_arm": 0.48, "right_arm": 0.48, "left_leg": 0.5, "right_leg": 0.5,
}

## AN2.3. The half the note above left open: a wall, unlike bone, does not
## flex or bleed, so it sits above every zone `MELEE_RESISTANCE_BASE` names —
## harder than even an armoured skull.
const WALL_MELEE_RESISTANCE := 0.85
## AD3.3. What meeting a round feels like through the arm. Below stone —
## a bullet is small and gives — but well above air, because something that
## fast stopping against an edge is a real jolt, not a whiff.
const ROUND_MELEE_RESISTANCE := 0.55

func _melee_resistance(zone: String, result: Dictionary) -> float:
	var base: float = MELEE_RESISTANCE_BASE.get(zone, 0.55)
	var absorbed := float(result.get("absorbed", 0.0))
	return clampf(base + absorbed * 0.35, 0.0, 0.95)


## AN2.4. Every connecting hit takes something off the edge; hitting whatever
## the blow's own `absorbed` says was resistant (armour, bone) takes more —
## a blade that keeps meeting plate dulls faster than one that keeps meeting
## an unarmoured back. Bare hands and a carried limb are not in the arsenal's
## own catalog, so this is a no-op for both; the limb already wears through
## `_wear_carried_limb` instead. `_carry_current_weapon()` is called
## immediately rather than left for next frame's `_advance_arm`, so the
## degraded stiffness is real the instant the hit lands, not one frame late.
const WEAPON_WEAR_BASE := 0.01
const WEAPON_WEAR_ABSORBED := 0.05

func _wear_current_weapon(weapon_id: String, absorbed: float) -> void:
	if arsenal == null or not HunterArsenal.WEAPONS.has(weapon_id):
		return
	arsenal.wear_weapon(WEAPON_WEAR_BASE + absorbed * WEAPON_WEAR_ABSORBED, weapon_id)
	_carry_current_weapon()


## AF1.1/AF1.2. Where a round ended up. The world keeps the hole (the
## projectile draws that itself) and the record keeps the fact — and, if the
## round hit a body, this is now also the *only* place the shot that fired it
## finds out. `_resolve_firearm()` no longer resolves anatomy damage itself;
## it fires a round with its damage riding along as `payload` and waits.
func _on_round_hit(hit: Dictionary) -> void:
	var struck: Variant = hit.get("collider")
	var payload: Dictionary = hit.get("payload", {})
	# AF1.7's own lookup, not a group membership no code in this project ever
	# assigns — a body's zones are `Area3D` hitboxes (`baseline_human.gd`),
	# walked up to whichever encounter actor actually owns the one this round
	# reached, exactly the way `_trace_actor()`'s instant raycast already did.
	if struck != null and struck is Node and _resolve_body_hit(struck as Node, hit, payload):
		return
	WorldHistory.record_event("round_struck_world", {
		"calibre": str(hit.get("calibre", "")),
		"energy": snappedf(float(hit.get("energy", 0.0)), 0.01),
		"shooter": str(hit.get("shooter", "")),
		"location": HUNT_LOCATION,
	})
	if not payload.is_empty():
		_settle_shot(int(payload.get("shot_id", 0)), false)


## AF1.1. A round that ran out of range or fell out of the world without ever
## arriving anywhere — still a real outcome, not a hit `Ballistics` swallowed.
func _on_round_expired(payload: Dictionary) -> void:
	if not payload.is_empty():
		_settle_shot(int(payload.get("shot_id", 0)), false)


## AF1.1. What used to happen inline in `_resolve_firearm()`, the instant the
## trigger went down, now happens here — whenever `Ballistics` reports that
## *this* round actually reached a body, however many frames after it was
## fired that turns out to be. One round, one hit, one event: a shotgun's
## pellets no longer land as a single pre-batched summary, because they no
## longer arrive as one — each is its own real impact now, on its own frame.
func _resolve_body_hit(struck: Node, hit: Dictionary, payload: Dictionary) -> bool:
	var shot_id := int(payload.get("shot_id", 0))
	var actor := Dictionary()
	for candidate in encounter_actors:
		if not is_instance_valid(candidate.node) or candidate.anatomy.dead:
			continue
		var cursor: Node = struck
		while cursor != null:
			if cursor == candidate.node:
				actor = candidate
				break
			cursor = cursor.get_parent()
		if not actor.is_empty():
			break
	if actor.is_empty():
		# Not an actor at all — the caller's own world-hit branch settles
		# this pellet as a miss; settling it here too would count it twice.
		return false
	var direction: Vector3 = hit.get("direction", Vector3.FORWARD)
	var rig := actor.rig as BaselineHuman
	var damage := float(payload.get("damage", 0.0))
	var impulse := float(payload.get("impulse", 0.0))
	var damage_type := str(payload.get("damage_type", "ballistic"))
	var weapon := str(payload.get("weapon", "firearm"))
	# A delayed round is resolved on its impact frame, but its anatomy, response,
	# death and loot still form one physical outcome on that frame.
	WorldHistory.begin_ledger_batch()
	var result := rig.hit_at(hit.get("position", actor.node.global_position), damage, impulse, damage_type, direction)
	var zones: Array[String] = [str(result.get("zone", "torso"))]
	var severed: Array[String] = []
	var ruptures: Array[String] = []
	var organ := result.get("organ", {}) as Dictionary
	if bool(organ.get("ruptured", false)):
		ruptures.append(str(organ.get("zone", "internal")))
	if bool(result.get("severed", false)):
		severed.append(str(result.get("zone", "limb")))
	(actor.node as CharacterBody3D).velocity += direction * minf(6.0, impulse * 0.075)
	# O2.2. Time, camera and sound on the same frame the round actually lands,
	# same as a melee blow gets. Severity is measured against the zone's own
	# health so a round through a head reads heavier than the same round
	# through a thigh.
	var zone_id := str(result.get("zone", "torso"))
	var zone_max: float = float((AnatomyComponent.DEFAULT_ZONES.get(zone_id, {}) as Dictionary).get("health", 100.0))
	impact_feel.strike(
		damage / maxf(zone_max, 1.0),
		damage_type,
		bool(result.get("severed", false)),
		# O2.5 v2. Only the two of you are in this. Everyone else in the
		# region keeps fighting at full speed.
		["player", str(actor.subject_id)]
	)
	if actor.rig != null and is_instance_valid(actor.rig):
		actor.rig.favour_injuries()
	WorldHistory.update_subject(str(actor.subject_id), {"anatomy_state": actor.rig.snapshot()}, "anatomy_changed")
	WorldHistory.record_event("firearm_anatomy_hit", {
		"subject_id": actor.subject_id, "weapon": weapon, "zones": zones,
		"damage": snappedf(float(result.get("damage", 0.0)), 0.1), "ruptures": ruptures, "severed": severed,
		"location": HUNT_LOCATION,
	})
	var fake_attack := {"damage": damage, "impulse": impulse, "damage_type": damage_type, "weapon": weapon, "heavy": bool(payload.get("heavy", false))}
	if actor.anatomy.dead:
		_kill_encounter_actor(encounter_actors.find(actor), weapon)
	elif actor.anatomy.downed:
		actor.state = "downed"
	elif not severed.is_empty():
		_apply_maiming_state(actor, severed, direction)
	elif actor.anatomy.critical or actor.anatomy.pain >= 68.0:
		actor.state = "fleeing"
		actor.loot_at_risk = true
	else:
		_apply_combat_response(actor, fake_attack, {"pain": actor.anatomy.pain})
	_settle_shot(shot_id, true, str(actor.subject_id))
	WorldHistory.commit_ledger_batch()
	return true


## AF1.1. One trigger pull can fire several rounds (a shotgun's pellets),
## each resolving on its own real frame as it lands, hits the world, or runs
## out of range. The pull's own hit/miss feedback — the HUD line, and the
## whiff and footing loss on a clean miss — decides itself the instant the
## first pellet connects, or once every pellet has missed; `weapon_fired`
## itself is not an anatomy question and is recorded eagerly, back in
## `_resolve_firearm()`, the moment the trigger actually goes down.
func _settle_shot(shot_id: int, hit_body: bool, subject_id := "") -> void:
	if not _pending_shots.has(shot_id):
		return
	var shot: Dictionary = _pending_shots[shot_id]
	shot.remaining = int(shot.remaining) - 1
	if hit_body:
		(shot.hit_ids as Array).append(subject_id)
	_pending_shots[shot_id] = shot
	# A clean miss has to wait for every pellet to actually miss before it is
	# one — but a shotgun's spread means some pellets can sail on well past
	# the ones that connected, into open air with no wall behind the target
	# to end their flight quickly. A hit does not need to wait on them: the
	# instant one pellet connects the shot already has an answer, and the
	# stragglers still land their own real damage through `_resolve_body_hit`
	# — they just no longer hold up the HUD line and the `weapon_fired`
	# record waiting to hear from them.
	if not hit_body and int(shot.remaining) > 0:
		return
	_pending_shots.erase(shot_id)
	var hit_ids: Array = shot.hit_ids
	if hit_ids.is_empty():
		impact_feel.whiff()
		# O2.3 / O5.7. A miss was already free of damage; it is no longer free of
		# balance. Swinging at air is how you end up on your heels.
		lose_footing(FOOTING_WHIFF, "SWUNG AT NOTHING")
		prompt.text = "%s / MISS" % str(shot.label)
	else:
		prompt.text = "%s / %d BODY%s HIT" % [str(shot.label), hit_ids.size(), "IES" if hit_ids.size() != 1 else ""]


func _resolve_firearm(attack: Dictionary) -> void:
	var forward := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	var origin := camera.global_position + forward * 0.48
	var directions: Array[Vector3] = arsenal.shot_directions(forward, Vector3.UP)
	# AF1.1. A round is a thing that travels, and now so is what it does: the
	# damage payload rides on the round itself and is only ever spent when
	# `_on_round_hit()`/`_on_round_expired()` reports that round's own real
	# outcome, a few frames from now — never here, on the frame the trigger
	# went down. `_resolve_body_hit()`, `_on_round_hit()`'s world branch and
	# `_on_round_expired()` are the three ways a pellet's fate gets decided;
	# `_settle_shot()` is where the pull as a whole finds out.
	_shot_counter += 1
	var shot_id := _shot_counter
	_pending_shots[shot_id] = {
		"weapon": str(attack.weapon),
		"label": str(arsenal.current().label),
		"remaining": directions.size(),
		"hit_ids": [],
	}
	if ballistics == null or not is_instance_valid(ballistics):
		# No projectile system to hand this to, and so no round that could
		# ever report back and settle it — a shot that never happened rather
		# than one stuck pending forever.
		_pending_shots.erase(shot_id)
		return
	var calibre := "buck" if directions.size() > 1 else "pistol"
	for direction in directions:
		var payload := {
			"shot_id": shot_id,
			"damage": float(attack.damage),
			"impulse": float(attack.impulse),
			"damage_type": str(attack.damage_type),
			"weapon": str(attack.weapon),
			"heavy": bool(attack.get("heavy", false)),
		}
		ballistics.fire(origin, direction, calibre, 0.0, 1, "player", payload)
	# The trigger going down is not an anatomy question — it happens here,
	# on this frame, same as it always did. What it hit is a separate record
	# (`firearm_anatomy_hit`/`round_struck_world`, both per-pellet, both
	# already deferred to when each round actually lands) rather than a
	# "hits" list bolted onto this one, which would otherwise have to wait
	# on whichever pellet takes longest to resolve.
	# One receipt per trigger pull, never one per pellet or wound. The deferred
	# firearm_anatomy_hit records remain consequences of this eager action.
	PLAYER_ACTION_LEDGER.record("weapon_fired", {"weapon": attack.weapon, "location": HUNT_LOCATION})


func _trace_actor(origin: Vector3, direction: Vector3, distance: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance)
	query.exclude = _player_collision_exclusions()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider := hit.collider as Node
	for actor in encounter_actors:
		if not is_instance_valid(actor.node) or actor.anatomy.dead:
			continue
		var cursor := collider
		while cursor != null:
			if cursor == actor.node:
				return {"actor": actor, "position": hit.position, "normal": hit.normal}
			cursor = cursor.get_parent()
	return {}


## AN2.3. The half `_resolve_strike()` used to leave open: `_attack_nearest_encounter_actor()`
## can only ever see an actor, so a swing that met a wall instead had nothing
## to report and read back as a whiff. `collide_with_areas` stays false rather
## than mirroring `_trace_actor()` — every zone hitbox in this game is an
## `Area3D` (AF1.1's own finding), so leaving areas out of the query entirely
## is what keeps a body from ever being mistaken for a wall here.
func _attack_wall(reach: float) -> Dictionary:
	var look := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	var query := PhysicsRayQueryParameters3D.create(player, player + look * reach)
	query.exclude = _player_collision_exclusions()
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	return {"position": hit.position, "normal": hit.normal}


func _player_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [player_body.get_rid()]
	for zone_id in BaselineHuman.ZONES:
		var hitbox := player_rig.get_node_or_null("%s_hitbox" % zone_id) as CollisionObject3D
		if hitbox != null:
			exclusions.append(hitbox.get_rid())
	return exclusions


## O5.8. Put everything down. Not a weapon slot — the absence of one.
func _put_the_weapons_down() -> void:
	_put_smokeable_away(false)
	_clear_carried_limb_model()
	bare_handed = true
	pending_attack = {}
	strike_windup = -1.0
	prompt.text = "HANDS"


## AU7.6/AU7.9. Six is a held-object slot rather than five separate hidden
## binds. Repeated presses walk the five authored objects; RMB belongs to the
## selected object until a weapon key takes the hand back.
func _cycle_smokeable() -> void:
	if smoke_drawing:
		_finish_smoking_draw()
	smoke_index = (smoke_index + 1) % SMOKEABLE_ORDER.size()
	_equip_smokeable(str(SMOKEABLE_ORDER[smoke_index]))


func _toggle_mouth_hold() -> void:
	if smoke_model == null or not is_instance_valid(smoke_model) or smoke_drawing:
		return
	var device_id := str(smoke_model.get_meta("device_id", ""))
	if device_id == "bong":
		prompt.text = "THE BONG NEEDS BOTH HANDS"
		return
	smoke_mouth_held = not smoke_mouth_held
	inspect_held = false
	var label := str((SMOKEABLES.CATALOG.get(device_id, {}) as Dictionary).get("label", device_id)).to_upper()
	prompt.text = "%s // %s" % [label, "HELD AT THE LIPS // Y TO TAKE IT" if smoke_mouth_held else "BACK IN HAND // Y TO LIP-HOLD"]
	PLAYER_ACTION_LEDGER.record("smokeable_mouth_hold", {
		"subject_id": "player", "device": device_id, "held": smoke_mouth_held,
		"location": HUNT_LOCATION,
	})


func _equip_smokeable(device_id: String) -> void:
	if not SMOKEABLES.CATALOG.has(device_id):
		return
	_put_smokeable_away(false)
	_clear_carried_limb_model(false)
	bare_handed = false
	for model in arsenal.models.values():
		(model as Node3D).visible = false
	smoke_model = SMOKEABLES.build(device_id, float(smoke_spent.get(device_id, 0.0)))
	smoke_model.name = "HeldSmokeable"
	smoke_model.set_meta("device_id", device_id)
	# The rig's real arm owns it. Its own HeldGear anchor, rather than the
	# object's origin, lands at the authored rest point in the palm.
	var grip := smoke_model.get_node_or_null("anchor_grip") as Node3D
	smoke_model.rotation = Vector3(1.05, -0.28, -0.42) if device_id != "bong" else Vector3(-0.15, 0.2, -0.18)
	smoke_model.set_meta("rest_rotation", smoke_model.rotation)
	var anchored_rest := SMOKE_REST
	if grip != null:
		anchored_rest -= smoke_model.transform.basis * grip.position
	smoke_model.position = anchored_rest
	smoke_model.set_meta("rest_position", anchored_rest)
	smoke_model.set_meta("grip_correction", smoke_model.transform.basis * grip.position if grip != null else Vector3.ZERO)
	(player_rig.parts.right_arm as Node3D).add_child(smoke_model)
	# The prop no longer floats at the end of an implied arm. Cigarettes and
	# hand-rolls sit in a relaxed pinch; the vape and bong get a full wrap.
	if grip != null:
		smoke_grip_hand = HELD_GEAR.build_humiliation_hand(1)
		smoke_grip_hand.name = "SmokingGripHand"
		var rolled := device_id in ["cigarette", "joint", "spliff"]
		HELD_GEAR.set_pose(smoke_grip_hand, "smoke" if rolled else "wrap")
		# Rolled objects sit above the palm between two fingers. Viewmodel hands
		# need to be slightly smaller than weapon hands at this camera distance or
		# an anatomically correct 84mm cigarette disappears behind the glove.
		if rolled:
			smoke_grip_hand.scale *= 0.80
			# The paper passes through the index/middle cradle, above the palm. A
			# slightly larger clearance for the fat hand-rolls keeps their ember and
			# paper visible instead of letting the glove swallow half the model.
			var roll_clearance := 0.016 if device_id in ["joint", "spliff"] else 0.012
			smoke_grip_hand.position = grip.position + Vector3(0.006, -0.054, roll_clearance)
		else:
			smoke_grip_hand.position = grip.position + Vector3(0.018, -0.012, 0.0)
		smoke_grip_hand.rotation = grip.rotation + Vector3(-PI * 0.5, 0.0, PI * 0.5)
		smoke_grip_hand.set_meta("grip_rest_position", smoke_grip_hand.position)
		smoke_grip_hand.set_meta("grip_rest_rotation", smoke_grip_hand.rotation)
		smoke_grip_hand.set_meta("forearm_entry", Vector3(0.48, -0.53, -0.30) if device_id != "bong" else Vector3(0.42, -0.55, -0.34))
		smoke_model.add_child(smoke_grip_hand)
	# A bong's second hand is not a text claim: a real hand closes at its
	# support anchor. One-hand objects have no support hand at all.
	if bool(smoke_model.get_meta("two_handed", false)):
		var support := smoke_model.get_node_or_null("anchor_grip_support") as Node3D
		if support != null:
			smoke_support_hand = HELD_GEAR.build_humiliation_hand(-1)
			smoke_support_hand.name = "BongSupportHand"
			smoke_support_hand.position = support.position + Vector3(-0.026, 0.0, 0.0)
			smoke_support_hand.rotation = Vector3(0.0, 0.0, -PI * 0.5)
			smoke_support_hand.set_meta("grip_rest_position", smoke_support_hand.position)
			smoke_support_hand.set_meta("grip_rest_rotation", smoke_support_hand.rotation)
			smoke_support_hand.set_meta("forearm_entry", Vector3(-0.43, -0.55, -0.34))
			smoke_model.add_child(smoke_support_hand)
	var label := str((SMOKEABLES.CATALOG[device_id] as Dictionary).get("label", device_id)).to_upper()
	prompt.text = "%s // HOLD RMB TO DRAW" % label


func _put_smokeable_away(show_arsenal := true) -> void:
	if smoke_model != null and is_instance_valid(smoke_model):
		SMOKEABLES.set_draw(smoke_model, 0.0)
		smoke_model.queue_free()
	smoke_model = null
	smoke_grip_hand = null
	smoke_support_hand = null
	if smoke_lighter != null and is_instance_valid(smoke_lighter):
		smoke_lighter.queue_free()
	smoke_lighter = null
	smoke_lighter_hand = null
	smoke_lighter_lid = null
	smoke_lighter_flame = null
	smoke_lighter_light = null
	smoke_ignition = 0.0
	if smoke_bong_audio != null:
		smoke_bong_audio.stop()
	smoke_drawing = false
	smoke_held = 0.0
	smoke_draw_start_spent = 0.0
	smoke_pose = 0.0
	smoke_mouth_held = false
	smoke_mouth_blend = 0.0
	smoke_breath_phase = 0.0
	smoke_ash_flick = 0.0
	smoke_exhale_delay = 0.0
	smoke_pending_exhale = {}
	smoke_cough = 0.0
	smoke_lung_fill = 0.0
	smoke_trick_window = 0.0
	smoke_last_exhale = {}
	if body_motion != null:
		body_motion.set_smoking_pose(0.0, false)
	if show_arsenal and arsenal != null and carried_limb_index < 0 and not bare_handed:
		arsenal._update_models()


func _begin_smoking_draw() -> void:
	if smoke_model == null or not is_instance_valid(smoke_model) or not panel_mode.is_empty():
		return
	var device_id := str(smoke_model.get_meta("device_id", ""))
	if float(smoke_spent.get(device_id, 0.0)) >= 0.999:
		prompt.text = "SPENT // PRESS 6 FOR ANOTHER OBJECT"
		return
	smoke_held = 0.0
	smoke_draw_start_spent = float(smoke_spent.get(device_id, 0.0))
	smoke_drawing = true
	_begin_smoke_ignition(device_id)


func _update_smoking(delta: float) -> void:
	if smoke_model == null or not is_instance_valid(smoke_model):
		return
	var device_id := str(smoke_model.get_meta("device_id", ""))
	var rolled := device_id in ["cigarette", "joint", "spliff"]
	smoke_breath_phase += delta
	# Deliberately slower than the draw lift: placing something between the lips
	# is a handoff with a small settling beat, not a slot toggle.
	smoke_mouth_blend = move_toward(smoke_mouth_blend, 1.0 if smoke_mouth_held else 0.0, delta * 3.0)
	_restore_grip_hand(smoke_grip_hand, "smoke" if rolled else "wrap")
	_restore_grip_hand(smoke_support_hand, "wrap")
	if smoke_grip_hand != null:
		smoke_grip_hand.visible = smoke_mouth_blend < 0.96
	if smoke_drawing:
		smoke_held += delta
		var live_ideal := float((SMOKEABLES.CATALOG.get(device_id, {}) as Dictionary).get("draw_ideal", 1.0))
		# The coal advances while air is actually moving through it. The stored
		# charge is committed on release, but the geometry previews that same
		# amount continuously so a cigarette never waits for a one-frame event to
		# become shorter.
		var live_burn := SMOKEABLES.spend_per_hit(device_id) * clampf(smoke_held / maxf(live_ideal, 0.01), 0.0, 1.0)
		SMOKEABLES.set_spent(smoke_model, clampf(smoke_draw_start_spent + live_burn, 0.0, 1.0))
		var draw_percent := roundi(clampf(smoke_held / maxf(live_ideal, 0.01), 0.0, 1.35) * 100.0)
		prompt.text = ("SINK THE CONE // %d%% // RELEASE AS IT CLEARS" if device_id == "bong" else "INHALE // %d%% // RELEASE ON THE SWEET SPOT") % draw_percent
		smoke_lung_fill = move_toward(smoke_lung_fill, clampf(float(draw_percent) / 100.0, 0.0, 1.0), delta * 1.8)
	elif smoke_exhale_delay <= 0.0:
		smoke_lung_fill = move_toward(smoke_lung_fill, 0.0, delta * 1.35)
	var live_heat := SMOKEABLES.draw_heat(device_id, smoke_held) if smoke_drawing else 0.0
	var breath_pulse := (sin(smoke_breath_phase * 2.1) + 1.0) * 0.5
	SMOKEABLES.set_draw(smoke_model, live_heat, _close_prop_light_scale(), breath_pulse)
	if smoke_exhale_delay > 0.0:
		smoke_exhale_delay = maxf(0.0, smoke_exhale_delay - delta)
		if smoke_exhale_delay <= 0.0:
			_exhale_smoke()
	smoke_trick_window = maxf(0.0, smoke_trick_window - delta)
	var ideal := float((SMOKEABLES.CATALOG.get(device_id, {}) as Dictionary).get("draw_ideal", 1.0))
	var at_mouth := smoke_drawing or smoke_exhale_delay > 0.0 or smoke_mouth_held
	# A cigarette comes up quickly but settles into the last centimetre. The
	# slower descent after release is the breath beat; it never snaps between
	# hand and face just because a button changed state.
	var raise_speed := 2.45 if device_id == "bong" else (3.7 if device_id == "spliff" else 5.8)
	smoke_pose = move_toward(smoke_pose, 1.0 if at_mouth else 0.0, delta * (raise_speed if at_mouth else 2.7))
	var lift := smoothstep(0.0, 1.0, smoke_pose)
	var rest: Vector3 = smoke_model.get_meta("rest_position", SMOKE_REST)
	var mouth_target := SMOKE_AT_MOUTH
	if body_motion != null and body_motion.first_person:
		var grip_correction: Vector3 = smoke_model.get_meta("grip_correction", Vector3.ZERO)
		rest = SMOKE_FP_REST - grip_correction
		mouth_target = SMOKE_FP_AT_MOUTH - grip_correction
		if device_id == "bong":
			rest = Vector3(0.18, -0.40, -0.78) - grip_correction
			mouth_target = Vector3(-0.02, -0.20, -0.55) - grip_correction
		elif device_id == "spliff":
			mouth_target += Vector3(0.015, -0.012, -0.035)
	var draw_ratio := clampf(smoke_held / maxf(ideal, 0.01), 0.0, 1.4) if smoke_drawing else 0.0
	_update_smoke_ignition(delta, device_id, draw_ratio, lift)
	# Tiny pull-back and tremor at the lips: enough movement for the inhale to
	# read without turning a cigarette into a lever waving across the screen.
	var breath_pull := Vector3(0.0, 0.004 * draw_ratio, 0.012 * draw_ratio)
	var ember_tremor := Vector3(sin(smoke_held * 10.0) * 0.0018, cos(smoke_held * 7.0) * 0.0012, 0.0) if smoke_drawing else Vector3.ZERO
	var cough_kick := Vector3(0.0, -sin(smoke_cough * 24.0) * smoke_cough * 0.035, smoke_cough * 0.04)
	var ash_flick_kick := Vector3.ZERO
	var ash_flick_roll := 0.0
	if smoke_ash_flick > 0.0:
		var flick_progress := 1.0 - clampf(smoke_ash_flick / 0.58, 0.0, 1.0)
		var flick_arc := sin(flick_progress * PI)
		ash_flick_kick = Vector3(-0.030 * flick_arc, 0.018 * flick_arc, 0.008 * flick_arc)
		ash_flick_roll = -0.24 * flick_arc + sin(flick_progress * PI * 2.0) * 0.055
		smoke_ash_flick = maxf(0.0, smoke_ash_flick - delta)
	var device_gesture := Vector3.ZERO
	if device_id == "spliff":
		# A loose, slow arc and a small roll between the fingers. It should not
		# share the machine-straight cigarette lift.
		device_gesture = Vector3(sin(lift * PI) * 0.032, sin(lift * PI) * 0.018, 0.0)
	elif device_id == "bong":
		# Weight first, mouthpiece second: the base dips as both hands take it,
		# then steadies during the pull with a tiny water-driven tremor.
		device_gesture = Vector3(0.0, -sin(lift * PI) * 0.045, sin(smoke_held * 7.0) * draw_ratio * 0.003)
	smoke_cough = maxf(0.0, smoke_cough - delta * 2.4)
	if body_motion != null and body_motion.first_person:
		# A first-person held object belongs to the camera composition while its
		# node still belongs to the real arm. This keeps the cigarette at the
		# mouth/reticle and lets the player look down the bong instead of seeing
		# its tube inherit a sideways whole-arm rotation.
		smoke_model.top_level = true
		var view_rest := Vector3(0.20, -0.30, -0.58)
		var view_mouth := Vector3(-0.035, -0.095, -0.265)
		var view_rotation := Vector3(0.18, -0.98, -0.18)
		if device_id == "spliff":
			view_mouth = Vector3(-0.045, -0.10, -0.29)
			view_rotation = Vector3(0.12, -0.90, -0.30 + sin(smoke_held * 3.2) * 0.06)
		elif device_id == "bong":
			view_rest = Vector3(0.22, -0.48, -0.72)
			view_mouth = Vector3(0.04, -0.34, -0.56)
			view_rotation = Vector3(0.34, 0.0, -0.06)
		var held_breath := Vector3(sin(smoke_breath_phase * 1.25) * 0.0015, cos(smoke_breath_phase * 1.25) * 0.0028, 0.0)
		var view_position := view_rest.lerp(view_mouth, lift) + Vector3(0.0, 0.0, ember_tremor.x * 0.35) + held_breath + ash_flick_kick
		view_rotation += Vector3(cos(smoke_breath_phase * 1.25) * 0.007, sin(smoke_breath_phase * 0.72) * 0.006, ash_flick_roll)
		if smoke_mouth_blend > 0.0 and device_id != "bong":
			# Transfer the live object from the finger cradle to an implied lip point
			# just beneath the reticle. The hand travels with it, releases, and leaves
			# the frame; taking it back plays the same movement in reverse.
			var lip_position := Vector3(-0.008, -0.032, -0.220) if rolled else Vector3(0.010, -0.052, -0.240)
			var lip_rotation := Vector3(0.04, -1.10, -0.08) if rolled else Vector3(0.10, -0.94, -0.03)
			var transfer := smoothstep(0.0, 1.0, smoke_mouth_blend)
			var mouth_anchor := smoke_model.get_node_or_null("anchor_mouth") as Node3D
			if mouth_anchor != null:
				lip_position -= Basis.from_euler(lip_rotation) * mouth_anchor.position
			# The fingers carry it on a shallow arc, then the last few millimetres
			# settle with the player's breath once the hand has released.
			lip_position += Vector3(0.0, -sin(transfer * PI) * 0.012, 0.0)
			lip_position += held_breath * smoothstep(0.72, 1.0, transfer)
			view_position = view_position.lerp(lip_position, transfer)
			view_rotation = view_rotation.lerp(lip_rotation, transfer)
		if inspect_blend > 0.0 and not smoke_drawing:
			var inspection := _smoke_inspection_pose(device_id, inspect_time)
			var target_position: Vector3 = inspection.get("position", view_position)
			var rotation_offset: Vector3 = inspection.get("rotation", Vector3.ZERO)
			view_position = view_position.lerp(target_position, inspect_blend)
			view_rotation += rotation_offset * inspect_blend
		smoke_model.global_transform = camera.global_transform * Transform3D(Basis.from_euler(view_rotation), view_position)
	else:
		smoke_model.top_level = false
		smoke_model.position = rest.lerp(mouth_target, lift) + breath_pull + ember_tremor + cough_kick + device_gesture + ash_flick_kick
		if device_id == "bong":
			smoke_model.rotation = Vector3(-0.15 + lift * 0.16, 0.20 - lift * 0.08, -0.18 + lift * 0.12)
		elif device_id == "spliff":
			smoke_model.rotation = Vector3(1.02 + lift * 0.12, -0.34, -0.52 + lift * 0.20 + sin(smoke_held * 3.2) * 0.035)
		else:
			smoke_model.rotation.z = -0.42 + lift * 0.18 + sin(smoke_held * 6.0) * 0.008 + ash_flick_roll
	if body_motion != null:
		body_motion.set_smoking_pose(lift, bool(smoke_model.get_meta("two_handed", false)), device_id)


func _finish_smoking_draw() -> Dictionary:
	if not smoke_drawing or smoke_model == null or not is_instance_valid(smoke_model):
		return {}
	smoke_drawing = false
	var device_id := str(smoke_model.get_meta("device_id", ""))
	if smoke_bong_audio != null:
		smoke_bong_audio.stop()
	SMOKEABLES.set_draw(smoke_model, 0.0, _close_prop_light_scale())
	if smoke_held < 0.05:
		SMOKEABLES.set_spent(smoke_model, smoke_draw_start_spent)
		smoke_held = 0.0
		return {}
	# One physical draw mutates dose, tolerance, anatomy, consumed prop and event
	# history. Keep every normal signal/event, but persist that cluster once.
	WorldHistory.begin_ledger_batch()
	var result: Dictionary = SMOKEABLES.hit("player", device_id, smoke_held, Time.get_ticks_msec() / 1000.0)
	var spent := clampf(smoke_draw_start_spent + SMOKEABLES.spend_per_hit(device_id), 0.0, 1.0)
	smoke_spent[device_id] = spent
	SMOKEABLES.set_spent(smoke_model, spent)
	if bool(result.get("ok", false)):
		# The dose/history lives in Smokeables; the tissue cost belongs to the
		# live anatomy in this scene. Persist its snapshot immediately so the
		# dossier, save and contextual X-ray all read the same two lungs.
		if player_rig != null and is_instance_valid(player_rig):
			var lung_report: Dictionary = player_rig.anatomy.inhale_smoke(
				float(result.get("exhale", 1.0)), float(result.get("harsh", 0.0)), device_id)
			result["lungs"] = lung_report
			WorldHistory.amend_subject("player", {"anatomy_state": player_rig.snapshot()})
		prompt.text = "%s DRAW // %s" % [str(result.get("grade", "")).to_upper(), "SPENT" if spent >= 0.999 else "%d%% LEFT" % roundi((1.0 - spent) * 100.0)]
		smoke_pending_exhale = result.duplicate(true)
		smoke_exhale_delay = 0.26
		if str(result.get("grade", "")) == SMOKEABLES.HARSH:
			smoke_cough = clampf(float(result.get("harsh", 0.0)), 0.25, 1.0)
			PLAYER_ACTION_LEDGER.record("smoke_coughed", {
				"subject_id": "player", "device": device_id,
				"intensity": smoke_cough, "location": HUNT_LOCATION,
			})
		PLAYER_ACTION_LEDGER.record("smoke_draw_resolved", {
			"subject_id": "player", "device": device_id,
			"grade": str(result.get("grade", "")),
			"consumed": SMOKEABLES.spend_per_hit(device_id), "spent": spent,
			"lungs": result.get("lungs", {}), "location": HUNT_LOCATION,
		})
		if smoke_draw_start_spent < 0.999 and spent >= 0.999:
			PLAYER_ACTION_LEDGER.record("smokeable_consumed", {
				"subject_id": "player", "device": device_id, "location": HUNT_LOCATION,
			})
		# Every third completed rolled draw ends with a small wrist snap and real
		# falling ash. It is deterministic per object, never a random interruption.
		if device_id in ["cigarette", "joint", "spliff"]:
			var completed_draws := roundi(spent / maxf(SMOKEABLES.spend_per_hit(device_id), 0.001))
			if completed_draws > 0 and completed_draws % 3 == 0:
				smoke_ash_flick = 0.58
				_emit_smoke_ash()
	WorldHistory.commit_ledger_batch()
	smoke_held = 0.0
	return result


func _emit_smoke_ash() -> void:
	if smoke_model == null or not is_instance_valid(smoke_model) or not smoke_model.has_meta("parts"):
		return
	var parts: Dictionary = smoke_model.get_meta("parts")
	var coal := parts.get("coal") as Node3D
	if coal == null:
		return
	var fall := GPUParticles3D.new()
	fall.name = "AshFlick"
	fall.one_shot = true
	fall.amount = 9
	fall.lifetime = 1.25
	fall.explosiveness = 0.96
	fall.visibility_aabb = AABB(Vector3(-0.35, -0.8, -0.35), Vector3(0.7, 1.0, 0.7))
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.006
	motion.direction = Vector3(-0.35, 0.45, 0.15)
	motion.spread = 38.0
	motion.initial_velocity_min = 0.10
	motion.initial_velocity_max = 0.28
	motion.gravity = Vector3(0.0, -0.72, 0.0)
	motion.scale_min = 0.45
	motion.scale_max = 1.15
	fall.process_material = motion
	var fleck := SphereMesh.new()
	fleck.radius = 0.0018
	fleck.height = 0.0036
	fleck.radial_segments = 5
	fleck.rings = 3
	var ash_material := StandardMaterial3D.new()
	ash_material.albedo_color = Color("8b8174")
	ash_material.roughness = 1.0
	fleck.material = ash_material
	fall.draw_pass_1 = fleck
	add_child(fall)
	fall.global_position = coal.global_position
	fall.emitting = true
	get_tree().create_timer(fall.lifetime + 0.25).timeout.connect(fall.queue_free)


## Release is the end of the draw, not another input prompt. The breath leaves
## automatically after one short hold at the mouth and becomes part of the same
## contaminated air already moving through the region.
func _exhale_smoke() -> void:
	if smoke_pending_exhale.is_empty():
		return
	var emission := _smoke_emission_pose()
	var forward: Vector3 = emission.forward
	var mouth: Vector3 = emission.mouth
	var device_id := str(smoke_pending_exhale.get("device", ""))
	air.emit_exhale(mouth, forward, float(smoke_pending_exhale.get("exhale", 1.0)), _smoke_tint(device_id))
	smoke_last_exhale = smoke_pending_exhale.duplicate(true)
	smoke_trick_window = 1.15
	prompt.text = "%s // CLICK TO SHAPE THE SMOKE" % str(smoke_pending_exhale.get("grade", "")).to_upper()
	PLAYER_ACTION_LEDGER.record("smoke_exhaled", {
		"subject_id": "player",
		"device": str(smoke_pending_exhale.get("device", "")),
		"density": float(smoke_pending_exhale.get("exhale", 1.0)),
		"location": HUNT_LOCATION,
	})
	smoke_pending_exhale = {}


func _shape_smoke_trick() -> void:
	if smoke_trick_window <= 0.0 or smoke_last_exhale.is_empty():
		return
	var trick := str(SMOKE_TRICKS[smoke_trick_index % SMOKE_TRICKS.size()])
	smoke_trick_index = (smoke_trick_index + 1) % SMOKE_TRICKS.size()
	var emission := _smoke_emission_pose(0.06)
	var forward: Vector3 = emission.forward
	var mouth: Vector3 = emission.mouth
	var device_id := str(smoke_last_exhale.get("device", ""))
	air.emit_smoke_trick(mouth, forward, trick, float(smoke_last_exhale.get("exhale", 1.0)), _smoke_tint(device_id))
	PLAYER_ACTION_LEDGER.record("smoke_trick", {
		"subject_id": "player", "trick": trick,
		"device": str(smoke_last_exhale.get("device", "")), "location": HUNT_LOCATION,
	})
	prompt.text = "%s // SMOKE TRICK" % trick
	smoke_trick_window = 0.0


## Herb smoke is only green enough to distinguish beside tobacco smoke. It is
## still grey air under the region's light, never a neon gameplay marker.
func _smoke_tint(device_id: String) -> Color:
	match device_id:
		"joint", "spliff": return Color(0.68, 0.75, 0.65)
		"bong": return Color(0.66, 0.75, 0.63)
		_: return Color(0.72, 0.74, 0.69)


## Close prop lights answer the exposure already in the world. Noon suppresses
## their cast light and hard shadows; darkness restores their full authored
## reach. A severe storm partially darkens the effective day, so flame becomes
## useful again beneath an overcast sky without a second weather-specific tune.
func _close_prop_light_scale() -> float:
	var daylight := WorldClock.daylight()
	var storm := storm_weather.severity() if storm_weather != null and is_instance_valid(storm_weather) else 0.0
	var exposed_daylight := daylight * (1.0 - storm * 0.55)
	# Direct sun already exposes the hand and prop. Leave only a trace of local
	# warmth there, otherwise the tiny flame reads like a floodlight and paints
	# a hard moving shadow across the whole foreground. Overcast and darkness
	# continuously restore the authored night strength.
	return lerpf(1.0, 0.04, smoothstep(0.0, 1.0, clampf(exposed_daylight, 0.0, 1.0)))


func _begin_smoke_ignition(device_id: String) -> void:
	if device_id == "vape":
		return
	if smoke_lighter != null and is_instance_valid(smoke_lighter):
		smoke_lighter.queue_free()
	smoke_lighter = _build_zippo()
	(player_rig.parts.left_arm as Node3D).add_child(smoke_lighter)
	smoke_lighter_hand = HELD_GEAR.build_humiliation_hand(-1)
	smoke_lighter_hand.name = "LighterHand"
	HELD_GEAR.set_pose(smoke_lighter_hand, "lighter")
	smoke_lighter_hand.scale *= 0.80
	# The thumb rides by the flint wheel; the other fingers close around the
	# case. Because it is a child of the Zippo it follows the whole flip and
	# bowl-lighting arc without ever lagging behind the prop.
	smoke_lighter_hand.position = Vector3(-0.010, -0.006, 0.012)
	smoke_lighter_hand.rotation = Vector3(-PI * 0.5, -0.08, -PI * 0.42)
	smoke_lighter_hand.set_meta("grip_rest_position", smoke_lighter_hand.position)
	smoke_lighter_hand.set_meta("grip_rest_rotation", smoke_lighter_hand.rotation)
	smoke_lighter_hand.set_meta("forearm_entry", Vector3(-0.48, -0.52, -0.30))
	smoke_lighter.add_child(smoke_lighter_hand)
	smoke_lighter_lid = smoke_lighter.get_node("LidPivot") as Node3D
	smoke_lighter_flame = smoke_lighter.get_node("Flame") as MeshInstance3D
	smoke_lighter_light = smoke_lighter.get_node("FlameLight") as OmniLight3D
	smoke_ignition = 0.0
	if smoke_support_hand != null:
		smoke_support_hand.visible = device_id != "bong"
	if smoke_lighter_audio == null:
		smoke_lighter_audio = AudioStreamPlayer.new()
		smoke_lighter_audio.name = "ZippoFlip"
		if AudioServer.get_bus_index("Bodies") >= 0:
			smoke_lighter_audio.bus = "Bodies"
		add_child(smoke_lighter_audio)
	smoke_lighter_audio.stream = _lighter_click_stream()
	smoke_lighter_audio.play()
	if device_id == "bong":
		if smoke_bong_audio == null:
			smoke_bong_audio = AudioStreamPlayer.new()
			smoke_bong_audio.name = "BongRip"
			if AudioServer.get_bus_index("Bodies") >= 0:
				smoke_bong_audio.bus = "Bodies"
			add_child(smoke_bong_audio)
		smoke_bong_audio.stream = _bong_rip_stream()
		smoke_bong_audio.volume_db = -7.0
		smoke_bong_audio.play()


func _update_smoke_ignition(delta: float, device_id: String, draw_ratio: float, lift: float) -> void:
	if smoke_lighter == null or not is_instance_valid(smoke_lighter):
		return
	smoke_ignition += delta
	var flip := smoothstep(0.0, 1.0, clampf(smoke_ignition / 0.24, 0.0, 1.0))
	smoke_lighter_lid.rotation.z = -flip * 2.18
	var stays_lit := smoke_drawing and (device_id == "bong" or smoke_ignition < 0.95)
	smoke_lighter_flame.visible = stays_lit and smoke_ignition > 0.12
	smoke_lighter_light.visible = smoke_lighter_flame.visible
	if smoke_lighter_flame.visible:
		var flutter := 0.88 + sin(smoke_held * 31.0) * 0.12
		var light_scale := _close_prop_light_scale()
		var visible_flame_scale := lerpf(0.42, 0.82, light_scale)
		smoke_lighter_flame.scale = Vector3(visible_flame_scale, flutter * visible_flame_scale / 0.82, visible_flame_scale)
		var flame_material := smoke_lighter_flame.material_override as StandardMaterial3D
		if flame_material != null:
			flame_material.emission_energy_multiplier = lerpf(0.38, 4.2, light_scale)
		# A Zippo is the stronger improvised light. The flicker moves warmth over
		# nearby surfaces without pulsing the exposure of the entire scene. In
		# daylight its cast light falls away with the world's existing exposure.
		smoke_lighter_light.light_energy = (5.2 + sin(smoke_held * 47.0) * 0.45) * light_scale
		smoke_lighter_light.omni_range = 7.2 * lerpf(0.45, 1.0, light_scale)
	if smoke_support_hand != null:
		smoke_support_hand.visible = not (device_id == "bong" and smoke_drawing)
	if body_motion != null and body_motion.first_person:
		smoke_lighter.top_level = true
		var lighter_position := Vector3(-0.12, -0.16, -0.34)
		var lighter_rotation := Vector3(0.08, -0.12, 0.10)
		if device_id == "bong":
			# Follow the bowl as the bong reaches the mouth; the flame is the
			# moving half of the cone-sink timing game.
			lighter_position = Vector3(0.005, -0.255, -0.49).lerp(Vector3(-0.015, -0.205, -0.47), lift)
			lighter_rotation = Vector3(-0.42, 0.10, 0.34)
		smoke_lighter.global_transform = camera.global_transform * Transform3D(Basis.from_euler(lighter_rotation), lighter_position)
	else:
		smoke_lighter.top_level = false
		smoke_lighter.position = Vector3(-0.035, -0.24, -0.46)
		smoke_lighter.rotation = Vector3(0.25, 0.1, 0.4)


func _build_zippo() -> Node3D:
	var root := Node3D.new()
	root.name = "HeldZippo"
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.034, 0.052, 0.012)
	body.mesh = body_mesh
	body.material_override = _smoke_prop_material(Color("6d777b"), 0.24, true)
	body.position.y = 0.026
	root.add_child(body)
	var hinge := Node3D.new()
	hinge.name = "LidPivot"
	hinge.position = Vector3(-0.017, 0.052, 0.0)
	root.add_child(hinge)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.034, 0.018, 0.012)
	lid.mesh = lid_mesh
	lid.material_override = _smoke_prop_material(Color("788287"), 0.20, true)
	lid.position = Vector3(0.017, 0.009, 0.0)
	hinge.add_child(lid)
	var chimney := MeshInstance3D.new()
	var chimney_mesh := CylinderMesh.new()
	chimney_mesh.top_radius = 0.006
	chimney_mesh.bottom_radius = 0.006
	chimney_mesh.height = 0.013
	chimney_mesh.radial_segments = 10
	chimney.mesh = chimney_mesh
	chimney.material_override = _smoke_prop_material(Color("34393b"), 0.35, true)
	chimney.position.y = 0.058
	root.add_child(chimney)
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.007
	flame_mesh.height = 0.026
	flame_mesh.radial_segments = 10
	flame_mesh.rings = 6
	var flame_node := MeshInstance3D.new()
	flame_node.name = "Flame"
	flame_node.mesh = flame_mesh
	var flame_material := _smoke_prop_material(Color("ffc25e"), 0.18, false)
	flame_material.emission_enabled = true
	flame_material.emission = Color("ff7a2c")
	flame_material.emission_energy_multiplier = 4.2
	flame_node.material_override = flame_material
	flame_node.position.y = 0.078
	flame_node.visible = false
	root.add_child(flame_node)
	var flame_light := OmniLight3D.new()
	flame_light.name = "FlameLight"
	flame_light.light_color = Color("ffad58")
	flame_light.light_energy = 5.2
	flame_light.omni_range = 7.2
	flame_light.position.y = 0.078
	flame_light.visible = false
	root.add_child(flame_light)
	return root


func _restore_grip_hand(hand: Node3D, pose_name: String) -> void:
	if hand == null or not is_instance_valid(hand):
		return
	if hand.has_meta("grip_rest_position"):
		hand.position = hand.get_meta("grip_rest_position")
	if hand.has_meta("grip_rest_rotation"):
		hand.rotation = hand.get_meta("grip_rest_rotation")
	HELD_GEAR.set_pose(hand, pose_name)


## Smokeables are read differently because they answer different questions.
## Rolled paper turns its seam and ember into the light, a vape shows its cell
## window, and a bong is tipped just enough to inspect bowl and water chamber.
func _smoke_inspection_pose(device_id: String, time: float) -> Dictionary:
	var breathe := sin(time * 1.35)
	var fine := sin(time * 2.7 + 0.8)
	match device_id:
		"cigarette":
			return {
				"position": Vector3(-0.018, -0.075 + fine * 0.004, -0.345),
				"rotation": Vector3(0.08 + breathe * 0.07, 0.44 + fine * 0.16, -0.10 + breathe * 0.06),
			}
		"joint", "spliff":
			return {
				"position": Vector3(-0.006, -0.090 + fine * 0.005, -0.365),
				"rotation": Vector3(0.16 + breathe * 0.09, 0.68 + fine * 0.20, -0.28 + breathe * 0.08),
			}
		"vape":
			return {
				"position": Vector3(0.025, -0.095 + fine * 0.004, -0.355),
				"rotation": Vector3(-0.12 + breathe * 0.08, 0.92 + fine * 0.18, 0.12 + breathe * 0.06),
			}
		"bong":
			return {
				"position": Vector3(0.035, -0.285 + fine * 0.006, -0.585),
				"rotation": Vector3(-0.18 + breathe * 0.07, 0.50 + fine * 0.13, 0.19 + breathe * 0.05),
			}
	return {"position": Vector3(0.0, -0.08, -0.38), "rotation": Vector3(0.1, 0.5, 0.0)}


## One inspection verb, but not one canned animation. Weapon mounts are reset by
## `_pose_weapon()` immediately before this runs; hands then perform the action
## appropriate to the object: edge reading, receiver check or press-check.
func _update_held_inspection(delta: float) -> void:
	var allowed := panel_mode.is_empty() and not smoke_drawing and not smoke_mouth_held and grapple_target.is_empty()
	inspect_blend = move_toward(inspect_blend, 1.0 if inspect_held and allowed else 0.0, delta * 5.2)
	if inspection_light != null:
		inspection_light.visible = inspect_blend > 0.01
		inspection_light.light_energy = inspect_blend * 1.55 * _close_prop_light_scale()
	if inspect_blend > 0.001:
		inspect_time += delta
	var turn := sin(inspect_time * 1.15)
	if smoke_model != null and is_instance_valid(smoke_model):
		# First-person smokeables are composed inside `_update_smoking`; third
		# person still receives the same class-specific intention without drift.
		if body_motion == null or not body_motion.first_person:
			var smoke_rest: Vector3 = smoke_model.get_meta("rest_rotation", smoke_model.rotation)
			var smoke_inspection := _smoke_inspection_pose(str(smoke_model.get_meta("device_id", "")), inspect_time)
			var smoke_offset: Vector3 = smoke_inspection.get("rotation", Vector3.ZERO)
			smoke_model.rotation = smoke_rest + smoke_offset * inspect_blend
		return
	if carried_limb_model != null and is_instance_valid(carried_limb_model):
		var limb_rest_position: Vector3 = carried_limb_model.get_meta("inspect_rest_position", carried_limb_model.position)
		var limb_rest_rotation: Vector3 = carried_limb_model.get_meta("inspect_rest_rotation", carried_limb_model.rotation)
		# Heft it, turn the cut end toward the eye, then let its dead weight sag.
		var heft := (0.5 + turn * 0.5) * inspect_blend
		if body_motion != null and body_motion.first_person:
			carried_limb_model.top_level = true
			var limb_view_rest := Vector3(0.20, -0.37, -0.64)
			var limb_view_inspect := Vector3(0.025, -0.19 + heft * 0.018, -0.49)
			var limb_view_position := limb_view_rest.lerp(limb_view_inspect, inspect_blend)
			var limb_view_rotation := Vector3(0.12, -0.48, -0.32) + Vector3(0.18 + heft * 0.10, 0.64 + turn * 0.20, 0.12 + heft * 0.14) * inspect_blend
			carried_limb_model.global_transform = camera.global_transform * Transform3D(Basis.from_euler(limb_view_rotation), limb_view_position)
		else:
			carried_limb_model.top_level = false
			carried_limb_model.position = limb_rest_position + Vector3(-0.025, 0.13 + heft * 0.025, -0.11) * inspect_blend
			carried_limb_model.rotation = limb_rest_rotation + Vector3(0.16 + heft * 0.10, inspect_blend * (0.62 + turn * 0.22), -0.12 + heft * 0.16)
		var limb_hand := carried_limb_model.get_node_or_null("CarriedLimbGripHand") as Node3D
		_restore_grip_hand(limb_hand, "wrap")
		if limb_hand != null:
			HELD_GEAR.blend_pose(limb_hand, "wrap", "fist", heft * 0.34)
		return
	if arsenal == null:
		return
	var model := arsenal.models.get(str(arsenal.current_id)) as Node3D
	if model == null or not is_instance_valid(model) or not model.visible:
		return
	var weapon_id := str(arsenal.current_id)
	var right_hand := model.get_node_or_null("RightGripHand") as Node3D
	var left_hand := model.get_node_or_null("LeftGripHand") as Node3D
	match weapon_id:
		"sword":
			# Present the edge diagonally, then let the off hand open and travel a
			# short safe distance toward the forte as if checking damage by light.
			model.position += Vector3(-0.035, 0.090, -0.105) * inspect_blend
			model.rotation += Vector3(-0.06 + turn * 0.05, 0.43 + turn * 0.16, 0.30 + sin(inspect_time * 0.8) * 0.10) * inspect_blend
			if left_hand != null:
				var sword_left: Vector3 = left_hand.get_meta("grip_rest_position", left_hand.position)
				left_hand.position = sword_left + Vector3(-0.018, 0.045, -0.075) * inspect_blend
				HELD_GEAR.blend_pose(left_hand, "wrap", "pinch", inspect_blend)
		"shotgun":
			# Roll the receiver into view; the support hand slides back along the
			# forend and squeezes once, reading as a physical chamber/pump check.
			model.position += Vector3(-0.075, 0.115, -0.120) * inspect_blend
			model.rotation += Vector3(0.18 + turn * 0.05, 0.48 + turn * 0.13, 0.22 + sin(inspect_time * 1.5) * 0.07) * inspect_blend
			if left_hand != null:
				var shotgun_left: Vector3 = left_hand.get_meta("grip_rest_position", left_hand.position)
				left_hand.position = shotgun_left + Vector3(0.0, 0.008, 0.065 + turn * 0.018) * inspect_blend
				HELD_GEAR.blend_pose(left_hand, "wrap", "fist", inspect_blend * (0.28 + absf(turn) * 0.20))
		"sidearm":
			# Cant the ejection port toward the eye. The support hand leaves its cup
			# and pinches the slide for a restrained press-check.
			model.position += Vector3(-0.085, 0.125, -0.135) * inspect_blend
			model.rotation += Vector3(0.24 + turn * 0.05, 0.78 + turn * 0.15, -0.18 + sin(inspect_time * 1.4) * 0.06) * inspect_blend
			if left_hand != null:
				var pistol_left: Vector3 = left_hand.get_meta("grip_rest_position", left_hand.position)
				left_hand.position = pistol_left + Vector3(-0.010, 0.070, -0.035 + turn * 0.010) * inspect_blend
				left_hand.rotation += Vector3(0.20, -0.10, 0.24) * inspect_blend
				HELD_GEAR.blend_pose(left_hand, "cup", "pinch", inspect_blend)
		_:
			model.position += Vector3(-0.055, 0.105, -0.095) * inspect_blend
			model.rotation += Vector3(0.10, 0.62 + turn * 0.20, 0.08) * inspect_blend


## The actual body's arms own the third-person silhouette. In first person the
## props are camera-composed, so their costume sleeves need the same honest
## seam: each begins outside a lower corner and ends exactly at its own wrist.
## This is recomputed after weapon lag, smoking lift and inspection have all
## moved the hands, which prevents the arm from arriving one frame late.
func _update_first_person_forearms() -> void:
	if body_motion == null:
		return
	var hands: Array = []
	if smoke_model != null and is_instance_valid(smoke_model):
		if smoke_grip_hand != null and smoke_grip_hand.visible:
			hands.append(smoke_grip_hand)
		if smoke_support_hand != null and smoke_support_hand.visible:
			hands.append(smoke_support_hand)
		if smoke_lighter_hand != null and smoke_lighter_hand.visible:
			hands.append(smoke_lighter_hand)
	elif carried_limb_model != null and is_instance_valid(carried_limb_model):
		var limb_hand := carried_limb_model.get_node_or_null("CarriedLimbGripHand") as Node3D
		if limb_hand != null:
			hands.append(limb_hand)
	elif arsenal != null:
		var model := arsenal.models.get(str(arsenal.current_id)) as Node3D
		if model != null and model.visible:
			for hand_name in ["RightGripHand", "LeftGripHand"]:
				var weapon_hand := model.get_node_or_null(hand_name) as Node3D
				if weapon_hand != null:
					hands.append(weapon_hand)
	for hand in hands:
		_pose_first_person_forearm(hand as Node3D)


func _pose_first_person_forearm(hand: Node3D) -> void:
	if hand == null or not is_instance_valid(hand):
		return
	var forearm := hand.get_node_or_null("FirstPersonForearm") as Node3D
	if forearm == null:
		return
	if not body_motion.first_person:
		forearm.visible = false
		return
	forearm.visible = true
	forearm.top_level = true
	var side := int(hand.get_meta("screen_entry_side", 1))
	# A bong's broad two-arm brace, a centred pistol grip and a loose smoking
	# hand do not share an elbow. The hand supplies its authored off-screen entry;
	# old callers retain the former corner as a safe default.
	var entry: Vector3 = hand.get_meta("forearm_entry", Vector3(0.43 * float(side), -0.49, -0.30))
	var start := camera.to_global(entry)
	var end := hand.to_global(Vector3(0.0, 0.0, -0.035))
	var along := end - start
	var length := maxf(along.length(), 0.08)
	var basis := Basis(Quaternion(Vector3.UP, along.normalized()))
	forearm.global_transform = Transform3D(basis, start)
	var sleeve := forearm.get_node_or_null("TaperedSleeve") as MeshInstance3D
	if sleeve != null:
		(sleeve.mesh as CylinderMesh).height = length
		sleeve.position.y = length * 0.5


func _smoke_prop_material(tint: Color, roughness: float, metallic: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = 0.85 if metallic else 0.0
	return material


func _lighter_click_stream() -> AudioStreamWAV:
	var rate := 22050
	var sample_count := int(rate * 0.24)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 62017
	for index in sample_count:
		var t := float(index) / rate
		var click_one := exp(-absf(t - 0.025) * 180.0)
		var click_two := exp(-absf(t - 0.135) * 150.0)
		var ring := sin(TAU * 2350.0 * t) * click_one + sin(TAU * 1280.0 * t) * click_two * 0.72
		var grit := rng.randf_range(-1.0, 1.0) * (click_one + click_two) * 0.20
		var sample := clampi(roundi((ring * 0.42 + grit) * 32767.0), -32768, 32767)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream


func _bong_rip_stream() -> AudioStreamWAV:
	var rate := 22050
	var sample_count := int(rate * 1.2)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 420710
	var smoothed_noise := 0.0
	for index in sample_count:
		var t := float(index) / rate
		smoothed_noise = lerpf(smoothed_noise, rng.randf_range(-1.0, 1.0), 0.055)
		var bubble_phase := fmod(t * 7.3, 1.0)
		var bubble_env := exp(-bubble_phase * 8.5)
		var bubble := sin(TAU * (82.0 + bubble_phase * 210.0) * t) * bubble_env
		var water := sin(TAU * 46.0 * t) * 0.16 + smoothed_noise * 0.74
		var sample := clampi(roundi((water + bubble * 0.34) * 0.48 * 32767.0), -32768, 32767)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


## First person breath begins just beyond the lens; third person breath begins
## on the body's actual face. Emitting from the camera in an exterior view was
## the reason the first gameplay take filled the screen with smoke while the
## character stood several metres behind it.
func _smoke_emission_pose(extra_forward := 0.0) -> Dictionary:
	var forward := (-camera.global_transform.basis.z + Vector3.UP * 0.04).normalized()
	if perspective_blend > 0.5:
		var head := player_rig.parts.get("head") as Node3D
		if head != null and is_instance_valid(head):
			return {
				"mouth": head.global_position + forward * (0.16 + extra_forward) + Vector3.DOWN * 0.035,
				"forward": forward,
			}
	return {
		"mouth": camera.global_position + forward * (0.48 + extra_forward) + Vector3.DOWN * 0.06,
		"forward": forward,
	}


## What a punch is worth. Kept beside the arsenal's own table rather than inside
## it, because bare hands are not a weapon the player owns — they are what is
## left when they own nothing.
func bare_hand_attack(heavy := false) -> Dictionary:
	if attack_cooldown > 0.0:
		return {"accepted": false, "reason": "busy"}
	# O5.9. Thrown by an arm. If both arms are gone there is nothing to throw.
	if guard_strength() <= 0.0:
		return {"accepted": false, "reason": "no arms"}
	return {
		"accepted": true, "weapon": "hands", "kind": "melee",
		# Low, but not a tickle — and it stacks with a step-in and good footing
		# the same way a cleaver does.
		"damage": 17.0 if heavy else 11.0,
		"impulse": 16.0 if heavy else 9.0,
		"damage_type": "blunt",
		# A third of a cleaver's reach. This is the horrible part: you have to be
		# inside their arms to land it, which is also where they can hold you.
		"range": 1.55,
		"windup": 0.20 if heavy else 0.09,
		"stamina": 9.0 if heavy else 4.0,
		"cooldown": 0.42 if heavy else 0.26,
		"heavy": heavy,
	}


func _equip_weapon(slot: int) -> void:
	_put_smokeable_away(false)
	bare_handed = false
	_clear_carried_limb_model()
	if arsenal.select_slot(slot):
		pending_attack = {}
		strike_windup = -1.0
		# The ammo well and the model in the player's hand already show the new
		# weapon. A persistent READY subtitle duplicated both of them.
		prompt.text = ""
		# AN2.5. A fresh draw starts from the grip `HeldGear` itself defaults
		# to, not whatever the last sword pull happened to be left in —
		# holstering is not the same act as choosing a stance.
		var options: Array = GRIP_CYCLE.get(str(arsenal.current_id), [])
		if not options.is_empty():
			current_grip = options[0]


func _reload_weapon() -> void:
	if carried_limb_index >= 0:
		prompt.text = "THAT IS AN ARM, NOT A GUN"
		return
	# AF10.12. `reload()` clears a jam instead of swapping the magazine when
	# the current weapon is jammed — same input, a different real duration.
	var was_jammed := bool(arsenal.jammed.get(arsenal.current_id, false))
	if arsenal.reload():
		var duration: float = arsenal.JAM_CLEAR_TIME if was_jammed else float(arsenal.current().reload)
		body_motion.trigger_reload(duration)
		# Reloading is visible as a cartridge travelling through the well.
		prompt.text = ""


## AF1.4. Record the completed physical swap, not the key press that requested
## it. Full magazines, empty reserves and interrupted requests create no act.
func _on_weapon_reload_finished(weapon_id: String) -> void:
	var state: Dictionary = arsenal.state()
	PLAYER_ACTION_LEDGER.record("weapon_reloaded", {
		"weapon": weapon_id,
		"loaded": int(state.get("loaded", 0)),
		"reserve": int(state.get("reserve", 0)),
		"location": HUNT_LOCATION,
	})


## O5.7. Something took your balance. Shoves, blocked blows and your own
## over-commitment all land here rather than each inventing their own knock.
func lose_footing(amount: float, reason := "") -> void:
	var before := footing
	footing = clampf(footing - amount, 0.0, 1.0)
	if before >= STUMBLE_AT and footing < STUMBLE_AT:
		# The moment it goes is the moment worth telling the player about.
		impact_feel.strike(0.45, "blunt", false)
		guarding = false
		prompt.text = "OFF BALANCE" if reason.is_empty() else reason
		WorldHistory.record_event("player_off_balance", {"location": HUNT_LOCATION, "reason": reason})


func stumbling() -> bool:
	return footing < STUMBLE_AT


## O5.1. What the swing is worth, given where the weapon was and where the body
## was going. Returns the multiplier on damage and the multiplier on recovery,
## so a committed step-in hits harder and a dragged-back reversal costs time.
##
## `heading` is the direction the player is actually travelling; the dot against
## where they are looking is the whole of "did you step into it".
func swing_momentum(heading: Vector3) -> Dictionary:
	var look := Vector3(sin(yaw), 0.0, cos(yaw))
	var flat := Vector3(heading.x, 0.0, heading.z)
	var into := 0.0
	# O5.11 v2. `swing_side` alternated every swing and was returned in this
	# same dictionary already, but nothing ever read it — the bonus below
	# only ever asked whether you stepped toward where you were looking, not
	# whether you moved with the arc the weapon was actually travelling on.
	# side == 1 is a rightward arc (left hand to right), -1 the reverse, which
	# is the convention register_swing() has been silently keeping since the
	# arc's own alternation was written.
	var with_arc := 0.0
	if flat.length() > 0.2:
		var normalized_flat := flat.normalized()
		into = clampf(normalized_flat.dot(look), -1.0, 1.0) * clampf(flat.length() / 6.0, 0.0, 1.0)
		var right := Vector3(look.z, 0.0, -look.x)
		with_arc = clampf(normalized_flat.dot(right) * float(swing_side), -1.0, 1.0) * clampf(flat.length() / 6.0, 0.0, 1.0)
	# Stepping in lends the blow your mass; backing away takes it out of the
	# swing, and a blow thrown while retreating should feel like one. Moving
	# with the arc lends a smaller amount again — a real cut is carried by
	# footwork on both axes, not only the one toward the target.
	var power := 1.0 + into * STEP_IN_BONUS + with_arc * ARC_STEP_BONUS
	var recovery := 1.0
	var now := float(Time.get_ticks_msec()) * 0.001
	var chained := (now - last_swing_at) <= SWING_CHAIN_WINDOW
	if chained:
		# The arc continues on its own. Alternating is free; the alternative is
		# hauling the weapon back through the arc it just finished.
		recovery *= 1.0
	else:
		# Cold start from rest: no stored momentum to spend.
		power *= 0.88
	return {
		"power": clampf(power, 0.5, 1.7),
		"recovery": recovery,
		"side": swing_side,
		"chained": chained,
		"into": into,
		"with_arc": with_arc,
	}


## Records that a swing happened, and flips the arc for the next one. Called
## after the swing is thrown rather than when it lands, because the arc has
## moved whether or not it hit anything.
func register_swing() -> void:
	swing_side = -swing_side
	last_swing_at = float(Time.get_ticks_msec()) * 0.001


## O2.4 / O5.9. How much guard the body can actually hold up, read from the arms
## that would be holding it. A shattered forearm cannot block, which is the same
## rule the brawl runs on: everything reads through the anatomy already built.
func guard_strength() -> float:
	if player_rig == null or not is_instance_valid(player_rig):
		return 1.0
	var arms := 0.0
	var count := 0
	for zone_id: String in ["left_arm", "right_arm"]:
		if player_rig.severed.has(zone_id):
			continue
		var maximum: float = float((AnatomyComponent.DEFAULT_ZONES.get(zone_id, {}) as Dictionary).get("health", 65.0))
		arms += clampf(player_rig.zone_health(zone_id) / maxf(maximum, 1.0), 0.0, 1.0)
		count += 1
	if count == 0:
		return 0.0
	return clampf(arms / float(count), 0.0, 1.0)


## O2.6. How far off your front the guard still holds. A guard raised toward
## whatever you are looking at cannot also be covering your back — 100 degrees
## either side of where you are actually facing, which is generous for a
## frontal guard but still a real cone rather than a sphere.
const GUARD_ARC_DOT := -0.17


## Applied to anything that lands on the player while the guard is up.
## `attacker_position` decides whether the guard was even facing the blow —
## it used to hold equally in every direction, which meant there was no such
## thing as flanking the player. Returns the surviving fraction of the
## damage, and whether it was parried — a parry is the first moments of the
## guard and gives the initiative straight back.
func guard_absorb(damage: float, attacker_position: Vector3 = Vector3.INF) -> Dictionary:
	if not guarding:
		return {"damage": damage, "blocked": false, "parried": false}
	if attacker_position != Vector3.INF:
		var facing := Vector3(sin(yaw), 0, cos(yaw))
		var to_attacker := attacker_position - player
		to_attacker.y = 0.0
		if to_attacker.length_squared() > 0.001 and facing.dot(to_attacker.normalized()) < GUARD_ARC_DOT:
			# Behind the arc the guard covers: it was never raised toward this,
			# so it does nothing for it — the same blow a guard from the front
			# would have turned goes through whole.
			prompt.text = "STRUCK FROM OUTSIDE YOUR GUARD"
			return {"damage": damage, "blocked": false, "parried": false}
	var parried := guard_raised <= PARRY_WINDOW
	if parried:
		# Nothing gets through a parry, and it costs the attacker instead of you.
		impact_feel.strike(0.85, "cut", false)
		prompt.text = "TURNED IT"
		WorldHistory.record_event("player_parried", {"location": HUNT_LOCATION})
		return {"damage": 0.0, "blocked": true, "parried": true}
	# A block is not free: it scales with what the arms can actually hold, and
	# the rest of it still arrives.
	# Blocking is not standing still: the blow still moves you.
	lose_footing(FOOTING_BLOCKED * clampf(damage / 20.0, 0.3, 1.6), "")
	var through: float = damage * lerpf(1.0, GUARD_DAMAGE_SCALE, guard_strength())
	stamina = maxf(0.0, stamina - damage * 0.45)
	impact_feel.strike(0.3, "blunt", false)
	WorldHistory.record_event("player_blocked", {"location": HUNT_LOCATION})
	return {"damage": through, "blocked": true, "parried": false}


## AS1.1/AS1.3. Whether the torch is lit and how strong is entirely
## `handheld.torch_active()`/`battery_percent()`'s call — this only paints
## the result, so the device and the light bolted to it can never disagree
## about whether it is on. AS2.1's "warps and distorts" gets a down payment
## here too: a real torch on a device this beaten up does not hold perfectly
## steady, and it should say so more as the charge that is running it drops.
func _update_handheld_lamp(_delta: float) -> void:
	if handheld_lamp == null or not is_instance_valid(handheld_lamp):
		return
	var lit: bool = handheld.has_method("torch_active") and handheld.torch_active()
	handheld_lamp.visible = lit
	if not lit:
		# A4.2. Dark beam, still air.
		if handheld_warp != null and is_instance_valid(handheld_warp):
			handheld_warp.set_amount(0.0)
		return
	var charge: float = handheld.battery_percent() if handheld.has_method("battery_percent") else 1.0
	var output: float = handheld.emitted_light_multiplier() if handheld.has_method("emitted_light_multiplier") else 1.0
	var wave: Vector2 = handheld.wave_vector() if handheld.has_method("wave_vector") else Vector2.ZERO
	var waver := 1.0 + sin(pulse * 11.0) * 0.03 * (1.0 + (1.0 - charge) * 2.5)
	# Below a fifth of a charge it starts guttering rather than merely dimming.
	if charge < 0.2:
		var gutter := 1.0 if fmod(pulse * (5.0 + (0.2 - charge) * 40.0), 1.0) > 0.5 else 0.0
		waver *= 0.7 + 0.3 * gutter
	handheld_lamp.spot_range = handheld.light_radius()
	handheld_lamp.light_energy = 9.0 * charge * output * waver
	handheld_lamp.position = HANDHELD_LAMP_BASE_POSITION + Vector3(wave.x * HANDHELD_WAVE_POSITION.x, -wave.y * HANDHELD_WAVE_POSITION.y, 0.0)
	handheld_lamp.rotation_degrees = HANDHELD_LAMP_BASE_ROTATION + Vector3(-wave.y * HANDHELD_WAVE_ANGLE.y, -wave.x * HANDHELD_WAVE_ANGLE.x, 0.0)
	# A4.2. The air the beam bends answers the same battery the beam does, so a
	# guttering torch bends it in the same stutter rather than holding a steady
	# shimmer over a dying light.
	if handheld_warp != null and is_instance_valid(handheld_warp):
		handheld_warp.set_amount(clampf(handheld_lamp.light_energy / 9.0, 0.0, 1.0))


## AD1.2. Empty means "not vaultable", never a crash — every one of these
## rays is allowed to simply miss, because most things in front of the
## player most of the time are not a low wall.
## AD1.4. `require_floor` waives its own on-floor gate for exactly one
## caller: the mid-climb mantle check in `_update_player()`, where the body
## is airborne against a wall by definition and the ledge it is reaching
## for is not on the ground either. Every other caller — the SPACE-pressed
## vault a walking player takes over a crate — keeps the gate, unchanged.
## AD3.2. How high a thing can be and still be vaultable *for this body*.
## A bare one is capped at `VAULT_MAX_TOP` and everything above it is a wall
## (AD1.2's own line). A leg carrying drive hardware raises the ceiling, so
## obstacles in the band between the two are not "vaulted faster" — they are
## vaultable at all, where for a bare body they were simply walls. That is
## the item's own "not just the numbers": the same obstacle answers a
## different question depending on what is in your leg.
func _vault_ceiling() -> float:
	if player_rig == null or not is_instance_valid(player_rig):
		return VAULT_MAX_TOP
	if player_rig.capable_limbs("vault_high").is_empty():
		return VAULT_MAX_TOP
	return VAULT_MAX_TOP_AUGMENTED


func _vault_target(direction: Vector3, require_floor: bool = true) -> Dictionary:
	if not panel_mode.is_empty() or resolution_ui.visible or not grapple_target.is_empty():
		return {}
	if direction.is_zero_approx() or crouching or vaulting_time > 0.0:
		return {}
	if require_floor and not player_body.is_on_floor():
		return {}
	# AD1.6. "A broken leg cannot vault" — literally: `mobility_ratio()`
	# reads 0.5 for one leg destroyed and the other untouched, so the same
	# `PLAYER_INJURY_FLOOR` (0.55) B6.5 already uses for how far a wrecked
	# body can move or swing draws the line here too, rather than a second
	# number invented for this one verb. Below it, this is a wall again.
	if player_rig.anatomy.mobility_ratio() < PLAYER_INJURY_FLOOR:
		return {}
	var space := get_world_3d().direct_space_state
	var exclusions := _player_collision_exclusions()
	var feet: Vector3 = player_body.position + Vector3.UP * -0.9
	var low_query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.4, feet + Vector3.UP * 0.4 + direction * VAULT_REACH)
	low_query.exclude = exclusions
	var low_hit := space.intersect_ray(low_query)
	if low_hit.is_empty():
		return {}
	var ceiling := _vault_ceiling()
	var high_query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * ceiling, feet + Vector3.UP * ceiling + direction * VAULT_REACH)
	high_query.exclude = exclusions
	if not space.intersect_ray(high_query).is_empty():
		# Something is still in the way above the vaultable band — a real
		# wall, not an obstacle. AD1.3's problem, not this one's.
		return {}
	# Exactly where the top is, found rather than assumed: straight down at
	# a point just past the low hit, in world height terms so the noisy Y of
	# a hit against the obstacle's own front face never leaks into it.
	var low_pos: Vector3 = low_hit.position
	var probe_x: float = low_pos.x + direction.x * 0.1
	var probe_z: float = low_pos.z + direction.z * 0.1
	var top_query := PhysicsRayQueryParameters3D.create(
		Vector3(probe_x, feet.y + ceiling + 0.2, probe_z),
		Vector3(probe_x, feet.y + VAULT_MIN_TOP - 0.1, probe_z))
	top_query.exclude = exclusions
	var top_hit := space.intersect_ray(top_query)
	if top_hit.is_empty():
		return {}
	var top_pos: Vector3 = top_hit.position
	var obstacle_height: float = top_pos.y - feet.y
	if obstacle_height < VAULT_MIN_TOP or obstacle_height > ceiling:
		return {}
	# The far side has to have a floor of its own and room to stand once
	# there — a vault is landing past the thing, not standing on top of it.
	var landing_x: float = low_pos.x + direction.x * VAULT_FAR_SIDE
	var landing_z: float = low_pos.z + direction.z * VAULT_FAR_SIDE
	var floor_query := PhysicsRayQueryParameters3D.create(
		Vector3(landing_x, top_pos.y + 0.6, landing_z),
		Vector3(landing_x, feet.y - 0.6, landing_z))
	floor_query.exclude = exclusions
	var floor_hit := space.intersect_ray(floor_query)
	if floor_hit.is_empty():
		return {}
	var floor_pos: Vector3 = floor_hit.position
	var landing: Vector3 = floor_pos + Vector3.UP * 0.05
	var clearance_query := PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 0.3, landing + Vector3.UP * VAULT_HEAD_CLEARANCE)
	clearance_query.exclude = exclusions
	if not space.intersect_ray(clearance_query).is_empty():
		return {}
	return {"landing": landing + Vector3.UP * 0.9}


func _vault(landing: Vector3) -> void:
	# AD1.6. Cleared the gate in `_vault_target()`, so mobility here is
	# somewhere in (PLAYER_INJURY_FLOOR, 1.0] rather than the full range —
	# a body that can still vault at all takes longer over it the worse off
	# it is, rather than clearing every obstacle at the same one healthy
	# speed right up until the gate simply refuses it outright.
	vault_duration = VAULT_DURATION * lerpf(1.6, 1.0, player_rig.anatomy.mobility_ratio())
	vaulting_time = vault_duration
	vault_from = player_body.position
	vault_to = landing
	# AD1.5. Captured before the zero below erases it — whatever speed got
	# the player to this obstacle is what they land with on the far side.
	vault_entry_velocity = Vector3(player_body.velocity.x, 0.0, player_body.velocity.z)
	player_body.velocity = Vector3.ZERO
	WorldHistory.record_event("player_vaulted", {"location": HUNT_LOCATION})


## AD1.3. Looks to both sides rather than assuming which one, since the wall
## that matters is whichever one the player is actually running alongside.
## Empty means "no wall run here" for any of several honest reasons: not
## earned yet, nothing within reach, or something within reach that AD1.2's
## own vault would rather have handled — a low ledge fails the second cast
## the same way a real wall fails `_vault_target()`'s high one.
func _wall_run_surface(direction: Vector3) -> Dictionary:
	if not wall_run_unlocked():
		return {}
	if not panel_mode.is_empty() or resolution_ui.visible or not grapple_target.is_empty():
		return {}
	# AD1.6. The same real floor `_vault_target()` gates on — a leg wrecked
	# past this point cannot hold weight sideways against a wall any more
	# than it can throw the body up and over one.
	if player_rig.anatomy.mobility_ratio() < PLAYER_INJURY_FLOOR:
		return {}
	if direction.is_zero_approx():
		return {}
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		return {}
	horizontal = horizontal.normalized()
	var speed := Vector2(player_body.velocity.x, player_body.velocity.z).length()
	if speed < WALL_RUN_MIN_SPEED:
		return {}
	var space := get_world_3d().direct_space_state
	var exclusions := _player_collision_exclusions()
	var chest: Vector3 = player_body.position
	for side in [Vector3(horizontal.z, 0.0, -horizontal.x), Vector3(-horizontal.z, 0.0, horizontal.x)]:
		var near_query := PhysicsRayQueryParameters3D.create(chest, chest + side * WALL_RUN_REACH)
		near_query.exclude = exclusions
		var near_hit := space.intersect_ray(near_query)
		if near_hit.is_empty():
			continue
		# It has to keep going well above where a vault would already have
		# put the player on top of it, or this is a ledge, not a wall.
		var high_from: Vector3 = player_body.position + Vector3.UP * (WALL_RUN_MIN_HEIGHT - 0.9)
		var high_query := PhysicsRayQueryParameters3D.create(high_from, high_from + side * WALL_RUN_REACH)
		high_query.exclude = exclusions
		if space.intersect_ray(high_query).is_empty():
			continue
		var normal: Vector3 = near_hit.normal
		var tangent: Vector3 = horizontal.slide(normal)
		if tangent.is_zero_approx():
			continue
		return {"normal": normal, "tangent": tangent.normalized()}
	return {}


## AD1.4. `_vault_target()`'s own low/high pair already says "a wall too
## tall to vault" — this reuses exactly that shape rather than a second
## obstacle scanner, casting straight ahead instead of `_wall_run_surface()`'s
## sideways pair, since a climb is a wall the player is facing, not one
## they are running alongside.
## AD1.4/AD1.5. `require_tall` is the whole fix for a real race the mantle
## chain exposed: the initial trigger and the per-frame "is the wall still
## there" recheck used to share this one function outright, and both the
## high check here and `_vault_target()`'s own top band key off the exact
## same `VAULT_MAX_TOP` line relative to the player's current height. A
## climb closing in on a ledge crosses that line once — the frame it does,
## the high check here can go empty (correctly: there is no longer a wall
## above the vault band) on the *same* frame `_vault_target()`'s own
## discrete top-scan is a hair outside its band and also returns empty,
## and the climb ended in a fall a tick before the mantle it was chaining
## into would have fired. The per-frame recheck (`false`) only needs to
## know a wall is still within reach at all; deciding "too tall to vault"
## is a question this function only needs to answer once, at the start.
func _climb_wall(direction: Vector3, require_tall: bool = true) -> Dictionary:
	if not climb_unlocked():
		return {}
	if not panel_mode.is_empty() or resolution_ui.visible or not grapple_target.is_empty():
		return {}
	if direction.is_zero_approx() or stamina <= 0.0:
		return {}
	# AD1.6. The same real floor every other traversal verb answers to — a
	# leg wrecked past this point cannot hold weight against a wall any
	# more than it can throw the body up and over one.
	if player_rig.anatomy.mobility_ratio() < PLAYER_INJURY_FLOOR:
		return {}
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		return {}
	horizontal = horizontal.normalized()
	var space := get_world_3d().direct_space_state
	var exclusions := _player_collision_exclusions()
	var feet: Vector3 = player_body.position + Vector3.UP * -0.9
	var low_query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.4, feet + Vector3.UP * 0.4 + horizontal * CLIMB_REACH)
	low_query.exclude = exclusions
	var low_hit := space.intersect_ray(low_query)
	if low_hit.is_empty():
		return {}
	if not require_tall:
		return {"normal": low_hit.normal}
	# Nothing above the vaultable band means this is `_vault_target()`'s
	# obstacle, not this one's — a crate gets stepped over, not climbed.
	var high_query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * VAULT_MAX_TOP, feet + Vector3.UP * VAULT_MAX_TOP + horizontal * CLIMB_REACH)
	high_query.exclude = exclusions
	if space.intersect_ray(high_query).is_empty():
		return {}
	return {"normal": low_hit.normal}


## AD1.4. `wall_run_unlocked()`'s own pattern one rung further up the same
## ladder — climbing is what wall-running was training the body for, so it
## is gated on a real kickoff rather than a fresh counter invented for it.
func climb_unlocked() -> bool:
	return WorldHistory.event_count("player_wall_run_kickoff") >= CLIMB_UNLOCK_KICKOFFS


func _announce_climb_unlock() -> void:
	prompt.text = "YOUR BODY CAN CLIMB NOW. RUN AT SOMETHING TALL."
	if impact_feel != null:
		impact_feel.kick += Vector2(0, -1.0) * 0.05
		impact_feel.shake = maxf(impact_feel.shake, 0.5)
	WorldHistory.record_event("climb_unlocked", {"location": HUNT_LOCATION})


## AD1.4/AD1.6. Duration scaled the same way `_vault()`/`_begin_wall_run()`
## already scale theirs — cleared the gate in `_climb_wall()`, so mobility
## here is always somewhere a climb is still possible at all, just a
## shorter or slower one the worse off the body is.
func _begin_climb(direction: Vector3, normal: Vector3) -> void:
	climbing_time = CLIMB_MAX_DURATION * lerpf(0.5, 1.0, player_rig.anatomy.mobility_ratio())
	climb_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	climb_normal = normal
	# AD1.5. Recorded before the climb loop overwrites velocity every frame
	# with its own small into-the-wall vector.
	climb_entry_speed = maxf(WALL_RUN_MIN_SPEED, Vector2(player_body.velocity.x, player_body.velocity.z).length())
	player_body.velocity.y = maxf(player_body.velocity.y, 0.0)
	WorldHistory.record_event("player_climb_started", {"location": HUNT_LOCATION})


func _begin_wall_run(surface: Dictionary) -> void:
	# AD1.6. Cleared the gate in `_wall_run_surface()` already, so this is
	# always shortening a run rather than ever lengthening past the healthy
	# baseline — a body that can still hold a wall does not hold it as
	# long the worse off it is.
	wall_running_time = WALL_RUN_DURATION * lerpf(0.5, 1.0, player_rig.anatomy.mobility_ratio())
	wall_run_normal = surface.normal
	# Whatever vertical velocity got the player here (a jump, a fall) is not
	# what a wall run is — leaving it alone let a fresh jump's own impulse
	# carry straight through, rocketing the body up past the top of the
	# wall over the run's own duration instead of tracking roughly level
	# along it. Capped rather than zeroed, so stepping onto one already
	# falling still reads as catching momentum, not a hard reset.
	player_body.velocity.y = minf(player_body.velocity.y, 1.0)
	WorldHistory.record_event("player_wall_run_started", {"location": HUNT_LOCATION})


func _dodge() -> void:
	if not panel_mode.is_empty() or dodge_cooldown > 0.0 or stamina < 25.0:
		return
	dodge_cooldown = 0.75
	stamina -= 25.0
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	dodge_direction = HUNTER_MOTOR.dodge_direction(move, yaw)
	dodge_remaining = 0.28
	WorldHistory.record_event("player_dodged", {"location": HUNT_LOCATION})


## AD1.1. Free rather than costing stamina like a dodge does — jumping is
## basic traversal, not a combat maneuver, and B6.5's own injury floor
## already answers "should a wrecked body be doing this" through
## `_player_speed_scale()`'s effect on how far a jump actually carries.
## Queued rather than applied here; see `jump_queued`'s own comment.
func _jump() -> void:
	if not panel_mode.is_empty() or resolution_ui.visible or not grapple_target.is_empty():
		return
	# AD3.2. Airborne is no longer an automatic refusal: a leg with drive
	# hardware in it gets one kick off nothing, which `_update_player()`
	# spends and the ground resets. A bare body is refused here exactly as
	# it always was, so nothing about jumping changes without the hardware.
	if not player_body.is_on_floor():
		if kick_off_spent > 0 or player_rig == null or not is_instance_valid(player_rig):
			return
		if player_rig.capable_limbs("kick_off").is_empty():
			return
	jump_queued = true


func _use_prosthetic_surge() -> void:
	if stamina < 35.0:
		return
	stamina -= 35.0
	WorldHistory.record_event("prosthetic_surge_used", {"implant": "salvaged torque arm", "location": HUNT_LOCATION})
	if enemy != null and not enemy_retreating and player.distance_to(enemy.global_position) < 7.0:
		# O3.1. Used to subtract a flat 30 with no wound at all — the one
		# attack in the fight that hit nothing you could ever see on her body.
		if enemy_rig != null and is_instance_valid(enemy_rig):
			var look := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
			var wound := enemy_rig.hit_at(enemy.global_position + Vector3.UP * 1.0, 30.0, 34.0, "blunt", look)
			WorldHistory.update_subject(CAST.id_for(CAPTAIN_SLOT), {"anatomy_state": enemy_rig.snapshot()}, "anatomy_changed")
			PLAYER_ACTION_LEDGER.record("melee_body_hit", {"target": CAST.id_for(CAPTAIN_SLOT), "body_zone": str(wound.get("zone", "torso")), "damage": 30, "location": HUNT_LOCATION})
			enemy_health = roundi(float(enemy_health_max) * _rig_health_ratio(enemy_rig))
		else:
			enemy_health = maxi(0, enemy_health - 30)
		_spawn_blood(enemy.global_position + Vector3(0, 1.0, 0), 30)
		if enemy_health <= 0:
			_rival_retreats("Mara's arm breaks. Her crew drag her into the tunnel.")


func _interact() -> void:
	if not panel_mode.is_empty():
		return
	body_motion.trigger_interaction()
	if dropped_handheld != null and is_instance_valid(dropped_handheld) and player.distance_to(dropped_handheld.global_position) <= 3.2:
		_pick_up_handheld()
		return
	if _try_sleep_at_site():
		return
	var downed := _nearest_downed()
	if not downed.is_empty():
		# F6.1. Raising the handheld changes E from an offer into an overwrite.
		# The consensual resolution remains a different, plainly labelled act.
		if handheld.is_open:
			_mind_stamp(downed)
			return
		_open_resolution(downed)
		return
	var chunk := _nearest_takeable_chunk(3.2)
	if chunk != null:
		var carried: Dictionary = handheld.carry.take_chunk(GoreChunks.take(chunk))
		if not carried.is_empty():
			prompt.text = "%s SECURED // [4] WIELD // CARRY %0.1f KG" % [str(carried.label), handheld.carry.total_mass()]
			return
	# AU3.2. The station decides what is in reach; this decides what taking it
	# means here, which is the same inventory path a loot cache already uses.
	if substance_station != null and is_instance_valid(substance_station):
		var lifted: Dictionary = substance_station.take_nearest(player)
		if not lifted.is_empty():
			var carried_items: Array = WorldHistory.subject("inventory").get("items", []).duplicate()
			carried_items.append(str(lifted["label"]))
			# One lift used to emit `substance_lifted` twice (once from the
			# inventory update and once explicitly) and persist each write. Keep
			# the established event name, but make the inventory mutation and its
			# compact receipt one atomic player act.
			WorldHistory.begin_ledger_batch()
			WorldHistory.amend_subject("inventory", {"items": carried_items})
			PLAYER_ACTION_LEDGER.record("substance_lifted", {
				"kind": str(lifted["kind"]), "item": str(lifted["id"]), "location": HUNT_LOCATION,
			})
			WorldHistory.commit_ledger_batch()
			prompt.text = "%s // TAKEN" % str(lifted["label"])
			return

	for marker in social_markers.duplicate():
		if is_instance_valid(marker) and player.distance_to(marker.global_position) < 4.0:
			var kind := str(marker.get_meta("kind"))
			var inventory: Array = WorldHistory.subject("inventory").get("items", []).duplicate()
			if kind == "trade":
				var sold := _sell_first_carried_part()
				if not sold.is_empty():
					prompt.text = "SOFT ROT BROKER // %s BOUGHT FOR %d RUST SCRIP" % [str((sold.item as Dictionary).label), int(sold.price)]
					return
				if not inventory.has("rust scrip"):
					prompt.text = "SOFT ROT BROKER: ONE RUST SCRIP FOR A FIELD DRESSING."
					return
				inventory.erase("rust scrip")
				inventory.append("field dressing")
				prompt.text = "TRADE COMPLETE // FIELD DRESSING ACQUIRED"
			elif kind in ["friendly", "bond"]:
				health = mini(100, health + 25)
				var friend_bond := int(WorldHistory.subject(FRIEND_ID).get("bond", 0))
				WorldHistory.update_subject(FRIEND_ID, {"bond": friend_bond + 5}, "misfire_bond")
				prompt.text = "A SMALL KINDNESS // BODY RESTORED; NIX HEARS OF IT."
			else:
				inventory.append("impossible testimony")
				prompt.text = "TESTIMONY RECORDED // YOUR WORLD INDEX REMEMBERS."
			WorldHistory.update_subject("inventory", {"items": inventory}, "misfire_reward")
			misfire_director.resolve(str(marker.get_meta("instance_id")), "interacted")
			social_markers.erase(marker)
			marker.queue_free()
			return
	for cache in loose_loot.duplicate():
		if is_instance_valid(cache) and player.distance_to(cache.global_position) < 3.5:
			var cache_items: Array = cache.get_meta("items", []).duplicate()
			var items: Array = WorldHistory.subject("inventory").get("items", []).duplicate()
			items.append_array(cache_items)
			# Inventory, receipt and any holding-work resolution belong to one
			# physical pickup. `complete_work` safely nests its own ledger batch,
			# leaving this outer commit as the only persistence boundary.
			WorldHistory.begin_ledger_batch()
			WorldHistory.amend_subject("inventory", {"items": items})
			PLAYER_ACTION_LEDGER.record("loot_collected", {
				"location": HUNT_LOCATION, "items": cache_items,
				"cache_id": cache.get_instance_id(),
			})
			var work_job_id := str(cache.get_meta("holding_work_job", ""))
			if not work_job_id.is_empty():
				ASHBLOOM_HOLDINGS.complete_work(work_job_id, {
					"method": "cache_collected", "items": cache_items,
				})
			WorldHistory.commit_ledger_batch()
			loose_loot.erase(cache)
			cache.queue_free()
			prompt.text = "SALVAGE SECURED // %d ITEMS" % items.size()
			return
	if friend != null and player.distance_to(friend.global_position) < 4.0:
		var bond := int(WorldHistory.subject(FRIEND_ID).get("bond", 12)) + 10
		WorldHistory.update_subject(FRIEND_ID, {"bond": bond, "status": "ally", "memory": "You listened at the Bone Yard gate."}, "bond_strengthened")
		prompt.text = "NIX: Mara is not the quarry. Something below is paying for her repairs."
		story_step = maxi(story_step, 1)
		return
	if player.distance_to(Vector3(0, 0, -24)) < 7.0 and story_step >= 1:
		_begin_canonical_encounter()
		return
	prompt.text = "Nothing answers. Find Nix or follow the floodlights to the tunnel."


## H10.8. Returns true whenever the bedroll owned the interaction, including a
## refused rest, so the same press cannot also resolve a body or conversation.
func _try_sleep_at_site() -> bool:
	if sleep_site == null or not is_instance_valid(sleep_site):
		return false
	if player.distance_to(sleep_site.global_position) > SLEEP_REACH:
		return false
	var danger := _sleep_danger()
	if not danger.is_empty():
		prompt.text = "TOO CLOSE TO SLEEP // %s" % danger
		sleep_prompt_hold = 2.5
		return true
	var before := WorldClock.minutes()
	WorldClock.set_hour(SLEEP_WAKE_HOUR)
	var passed := (WorldClock.minutes() - before) / WorldClock.MINUTES_PER_HOUR
	PLAYER_ACTION_LEDGER.record("player_slept", {
		"location": HUNT_LOCATION,
		"hours": passed,
		"woke_at": WorldClock.stamp(),
		"calendar": WorldClock.calendar_stamp(),
	})
	prompt.text = "SLEPT %.1f HOURS // %s // %s" % [passed, WorldClock.stamp(), WorldClock.calendar_stamp()]
	sleep_prompt_hold = 3.0
	_update_day_night()
	return true


func _sleep_danger() -> String:
	if enemy != null and is_instance_valid(enemy) and enemy.visible and not enemy_retreating and player.distance_to(enemy.global_position) < 18.0:
		return "%s IS HUNTING NEARBY" % _captain_name()
	for actor: Dictionary in encounter_actors:
		if str(actor.get("disposition", "hostile")) != "hostile" or bool(actor.get("dead", false)):
			continue
		var body: Node3D = actor.get("node")
		if body != null and is_instance_valid(body) and player.distance_to(body.global_position) < 18.0:
			return "%s IS WITHIN EARSHOT" % str(actor.get("display_name", "SOMETHING")).to_upper()
	return ""


func _update_sleep_prompt(delta: float) -> void:
	sleep_prompt_hold = maxf(0.0, sleep_prompt_hold - delta)
	if sleep_prompt_hold > 0.0 or sleep_site == null or not is_instance_valid(sleep_site):
		return
	if panel_mode.is_empty() and player.distance_to(sleep_site.global_position) <= SLEEP_REACH:
		prompt.text = "[E] REST AT THE BEDROLL // WAKE AT 07:00"


## C1.7. The device owns identity and possession; this scene owns 3D space.
## The signal is the seam between them, producing one physical, colliding body
## whose payload is the exact serial/condition/charge that just left the HUD.
func _on_handheld_dropped(payload: Dictionary) -> void:
	if dropped_handheld != null and is_instance_valid(dropped_handheld):
		return
	var forward := -camera.global_transform.basis.z.normalized()
	_spawn_dropped_handheld(payload, camera.global_position + forward * 0.85 + Vector3.DOWN * 0.32, true)
	_persist_dropped_handheld()
	prompt.text = "BLACK MIRROR DROPPED // [E] TO RECOVER"


func _spawn_dropped_handheld(payload: Dictionary, at: Vector3, tossed: bool) -> void:
	dropped_handheld = DROPPED_HANDHELD.new()
	dropped_handheld.name = "DroppedBlackMirror"
	dropped_handheld.configure(payload)
	add_child(dropped_handheld)
	dropped_handheld.global_position = at
	dropped_handheld.rotation_degrees = Vector3(18.0, 12.0, -9.0)
	if tossed:
		var forward := -camera.global_transform.basis.z.normalized()
		dropped_handheld.linear_velocity = forward * 2.1 + Vector3.UP * 1.0
		dropped_handheld.angular_velocity = Vector3(2.4, -1.3, 3.1)


func _restore_dropped_handheld() -> void:
	if handheld.possessed:
		return
	var record := WorldHistory.subject("handheld")
	if str(record.get("dropped_scene", "")) != HUNT_LOCATION:
		return
	var saved_position: Array = record.get("dropped_position", [])
	if saved_position.size() != 3:
		return
	var payload := {
		"serial": handheld.serial, "condition": handheld.condition,
		"battery": handheld.battery, "wear_log": handheld.wear_log.duplicate(),
		"impacts": handheld.impacts.duplicate(true),
	}
	_spawn_dropped_handheld(payload, Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2])), false)


func _persist_dropped_handheld() -> void:
	if dropped_handheld == null or not is_instance_valid(dropped_handheld):
		return
	var at := dropped_handheld.global_position
	WorldHistory.amend_subject("handheld", {
		"dropped_scene": HUNT_LOCATION,
		"dropped_position": [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)],
	})


func _update_dropped_handheld_persistence(delta: float) -> void:
	if dropped_handheld == null or not is_instance_valid(dropped_handheld):
		return
	dropped_handheld_save_timer -= delta
	if dropped_handheld_save_timer <= 0.0:
		dropped_handheld_save_timer = 0.75
		_persist_dropped_handheld()


func _update_dropped_handheld_prompt() -> void:
	if dropped_handheld != null and is_instance_valid(dropped_handheld) and panel_mode.is_empty() and player.distance_to(dropped_handheld.global_position) <= 3.2:
		prompt.text = "[E] RECOVER BLACK MIRROR // %06d" % handheld.serial


func _pick_up_handheld() -> void:
	if dropped_handheld == null or not is_instance_valid(dropped_handheld):
		return
	var serial: int = handheld.serial
	handheld.repossess({"location": HUNT_LOCATION})
	WorldHistory.amend_subject("handheld", {"dropped_scene": "", "dropped_position": []})
	dropped_handheld.queue_free()
	dropped_handheld = null
	prompt.text = "BLACK MIRROR %06d RECOVERED // CONDITION %d%%" % [serial, roundi(handheld.condition * 100.0)]


func _mind_stamp(actor: Dictionary) -> void:
	var subject_id := str(actor.get("subject_id", ""))
	var stamped := asset_network.mind_stamp(subject_id, actor.rig.snapshot())
	if stamped.is_empty():
		prompt.text = "MIND-STAMP REFUSED // NO LIVING SUBJECT"
		return
	actor.rig.spare()
	actor.state = "mind_stamped"
	actor.disposition = "asset"
	actor.attack_time = 0.0
	var order := asset_network.task(subject_id, "observe", HUNT_LOCATION)
	asset_network.execute_task(subject_id)
	var label := actor.node.get_node_or_null("Identity") as Label3D
	if label != null:
		label.text = "%s / ASSET" % str(actor.display_name).to_upper()
	prompt.text = "%s // %s" % [asset_network.roster_line(), str(order.command).to_upper()]


func _cycle_asset_task() -> void:
	var roster := asset_network.assets()
	if roster.is_empty():
		prompt.text = asset_network.roster_line()
		return
	var asset: Dictionary = roster[0]
	var current: Dictionary = asset.get("remote_task", {})
	var index := ASSET_NETWORK.TASKS.find(str(current.get("command", "")))
	var command: String = ASSET_NETWORK.TASKS[(index + 1) % ASSET_NETWORK.TASKS.size()]
	asset_network.task(str(asset.id), command, HUNT_LOCATION)
	asset_network.execute_task(str(asset.id))
	prompt.text = asset_network.roster_line() + " // REMOTE ORDER EXECUTING"


## B5.1. A body you can open: downed and alive, or dead and still warm. The
## resolution form (E) decides what happens to a person; this is the other
## question you can ask a body, and it is held rather than pressed because
## B5.2 says you have to dig.
func _nearest_robbable(radius := 3.4) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := radius
	var candidates: Array = dead_bodies.duplicate()
	# F7.2. Somebody you have hold of is robbable while still on their feet and
	# entirely awake for it, which is the version of this that costs karma.
	if not grapple_target.is_empty():
		var held := _actor_by_id(grapple_target)
		if not held.is_empty() and bool(_clinch_options(held).rob):
			candidates.append({"subject_id": str(held.subject_id), "display_name": str(held.display_name), "node": held.node, "rig": held.rig})
	for actor in encounter_actors:
		if actor.get("rig") != null and actor.rig.is_downed():
			candidates.append({"subject_id": str(actor.subject_id), "display_name": str(actor.display_name), "node": actor.node, "rig": actor.rig})
	for body in candidates:
		var node := body.get("node") as Node3D
		var rig := body.get("rig") as BaselineHuman
		if node == null or not is_instance_valid(node) or rig == null or not is_instance_valid(rig):
			continue
		# AU1.2. A body with nothing worth cutting open can still have
		# something worth taking out of its pocket.
		var has_substance: bool = not str(WorldHistory.subject(str(body.subject_id)).get("carried_substance", "")).is_empty()
		if Extraction.robbable_zones(rig.anatomy.snapshot()).is_empty() and not has_substance:
			continue
		var distance := player.distance_to(node.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = body
	return nearest


func _begin_extraction() -> void:
	if not panel_mode.is_empty() or resolution_ui.visible:
		return
	var body := _nearest_robbable()
	if body.is_empty():
		prompt.text = "NOTHING WITHIN REACH WORTH OPENING"
		extraction_session = {}
		return
	# AU1.2. A pocket, not a wound: checked and taken in one motion, before
	# whatever the body's actual anatomy might also be worth digging for.
	# The same key finishes the job on a second press if there is still a
	# real dig left, rather than needing a control of its own to discover.
	var carried_substance := str(WorldHistory.subject(str(body.subject_id)).get("carried_substance", ""))
	if not carried_substance.is_empty():
		var body_node := body.get("node") as Node3D
		var at := body_node.global_position if body_node != null and is_instance_valid(body_node) else player
		var witnesses := WitnessLedger.witnesses_of(at, _witness_candidates(), str(body.subject_id))
		var item: Dictionary = handheld.carry.take_from_subject(str(body.subject_id))
		if not item.is_empty():
			witness_ledger.record("substance_stolen", {
				"actor_id": "player", "target_id": str(body.subject_id), "substance_id": str(item.get("substance_id", "")),
			}, witnesses)
			prompt.text = "%s TAKEN FROM THEIR POCKET // %s" % [
				str(item.get("label", "")), ("SEEN BY %d" % witnesses.size()) if not witnesses.is_empty() else "NOBODY SAW",
			]
			return
	var rig := body.rig as BaselineHuman
	var snapshot: Dictionary = rig.anatomy.snapshot()
	var targets := Extraction.robbable_zones(snapshot, rig.zone_depth)
	if targets.is_empty():
		return
	var target: Dictionary = targets[0]
	var zone := str(target.zone)
	# Resuming the same dig rather than restarting it: letting go of the key to
	# deal with someone should not cost you the cut you already made.
	if str(extraction_session.get("subject_id", "")) == str(body.subject_id) and str(extraction_session.get("zone", "")) == zone and not bool(extraction_session.get("complete", false)):
		return
	var tool := Extraction.tool_for(str(arsenal.current_id), handheld.carry.items)
	extraction_session = Extraction.begin(str(body.subject_id), snapshot, zone, tool, rig.exposed_layer(zone), str(target.get("organ_id", "")))
	if extraction_session.is_empty():
		return
	extraction_session["display_name"] = str(body.display_name)
	body_motion.trigger_interaction()
	prompt.text = "HOLD [H] // %s INTO %s WITH %s" % [
		str(target.label).to_upper(), zone.replace("_", " ").to_upper(),
		str(Extraction.profile(tool).label),
	]


## `holding` is passed in rather than polled here: whether the key is down is
## the caller's business, and reading global Input inside the update made the
## dig impossible to drive from a test.
func _update_extraction(delta: float, holding: bool) -> void:
	if extraction_session.is_empty():
		return
	var body := _robbable_by_id(str(extraction_session.subject_id))
	if body.is_empty() or player.distance_to((body.node as Node3D).global_position) > 4.2:
		extraction_session = {}
		prompt.text = "THE DIG IS ABANDONED"
		return
	if not holding:
		return
	var rig := body.rig as BaselineHuman
	Extraction.dig(extraction_session, delta)
	# The zone opens while you work, so a half-finished dig is visible on the
	# body rather than being a number in a meter nobody can see.
	rig.mark_opened(str(extraction_session.zone), Extraction.reached_layer(extraction_session))
	if not bool(extraction_session.complete):
		prompt.text = "DIGGING // %d%%" % roundi(float(extraction_session.progress) / maxf(0.01, float(extraction_session.required)) * 100.0)
		return
	_finish_extraction(body)


func _finish_extraction(body: Dictionary) -> void:
	var rig := body.rig as BaselineHuman
	var snapshot: Dictionary = rig.anatomy.snapshot()
	var extracted := Extraction.extract(extraction_session, snapshot)
	extraction_session = {}
	if extracted.is_empty():
		return
	var owner_alive: bool = not rig.anatomy.dead
	var seen := Extraction.notice(witness_ledger, extracted, (body.node as Node3D).global_position, _witness_candidates(), owner_alive, HUNT_LOCATION)
	extracted["stolen"] = bool(seen.get("stolen", false))
	Extraction.strip_from_rig(rig, extracted)
	var carried: Dictionary = handheld.carry.take_chunk(extracted)
	WorldHistory.update_subject(str(body.subject_id), {"anatomy_state": rig.snapshot()}, "robbed")
	var witnesses: Array = seen.get("witnesses", [])
	prompt.text = "%s TAKEN // %d%% // %s" % [
		str(carried.label), roundi(float(carried.condition) * 100.0),
		("SEEN BY %d" % witnesses.size()) if not witnesses.is_empty() else "NOBODY SAW",
	]


func _robbable_by_id(id: String) -> Dictionary:
	for body in dead_bodies:
		if str(body.subject_id) == id and is_instance_valid(body.get("node")):
			return body
	for actor in encounter_actors:
		if str(actor.subject_id) == id and is_instance_valid(actor.get("node")):
			return {"subject_id": id, "display_name": str(actor.display_name), "node": actor.node, "rig": actor.rig}
	return {}


## Who is present and able to report, as plain data — the shape
## `WitnessLedger.witnesses_of` asks for, so the ledger never reaches into the
## hunt loop for it.
func _witness_candidates() -> Array:
	var out: Array = []
	for actor in encounter_actors:
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		out.append({
			"id": str(actor.subject_id), "at": node.global_position,
			"alive": not bool(actor.get("dead", false)) and not actor.anatomy.dead and not actor.anatomy.downed,
		})
	if friend != null and is_instance_valid(friend):
		out.append({"id": FRIEND_ID, "at": friend.global_position, "alive": true})
	return out


func _answer_local_reports(reports: Array) -> void:
	for report: Dictionary in reports:
		var response := LOCAL_LAW.answer_report(witness_ledger, report)
		if not bool(response.get("ok", false)):
			continue
		if bool(response.get("dispatched", false)):
			var place := WorldHistory.subject(str(response.get("place_id", "")))
			prompt.text = "%s HAS REMEMBERED ENOUGH // ITS HOLDER IS MOVING" % str(place.get("name", "THIS GROUND")).to_upper()
			_dispatch_local_law_team(response)


## AE1.7. A threshold crossing is not just a grudge number. Two generated,
## persistent people from the faction that actually holds the ground enter the
## ordinary encounter pipeline: same anatomy, AI, wounds, loot and resolution
## choices as everybody else. They are sent to the recorded scene, not given
## omniscient access to the player's current position.
func _dispatch_local_law_team(response: Dictionary) -> void:
	var sequence := int(response.get("source_sequence", -1))
	var place_id := str(response.get("place_id", ""))
	var faction_id := str(response.get("faction_id", ""))
	if sequence < 0 or place_id == "" or faction_id == "":
		return
	if WorldHistory.events.any(func(event: Dictionary):
		return str(event.get("type", "")) == "local_law_team_dispatched" and int((event.get("details", {}) as Dictionary).get("source_sequence", -2)) == sequence):
		return
	var at_data: Dictionary = response.get("at", {}) if response.get("at", {}) is Dictionary else {}
	var target := Vector3(float(at_data.get("x", player.x)), 0.0, float(at_data.get("z", player.z)))
	var subjects := _restore_local_law_team(sequence, place_id, faction_id, target)
	var contract := {
		"status": "active", "source_sequence": sequence, "faction_id": faction_id,
		"target": {"x": target.x, "z": target.z}, "subjects": subjects,
	}
	WorldHistory.amend_subject(place_id, {"active_law_dispatch": contract})
	WorldHistory.record_event("local_law_team_dispatched", {
		"source_sequence": sequence, "place_id": place_id, "faction_id": faction_id,
		"target": {"x": target.x, "z": target.z}, "subjects": subjects,
	})


func _restore_local_law_teams() -> void:
	# Events are a rolling historical window; the active contract belongs on
	# the place and therefore survives after its dispatch event ages out.
	ASHBLOOM_HOLDINGS.ensure()
	for definition: Dictionary in ASHBLOOM_HOLDINGS.DEFINITIONS:
		var place_id := str(definition.record)
		var contract: Dictionary = WorldHistory.subject(place_id).get("active_law_dispatch", {})
		if str(contract.get("status", "")) != "active":
			continue
		var sequence := int(contract.get("source_sequence", -1))
		if sequence < 0:
			continue
		if not _local_law_team_unresolved(sequence):
			contract["status"] = "resolved"
			WorldHistory.amend_subject(place_id, {"active_law_dispatch": contract})
			continue
		var target_data: Dictionary = contract.get("target", {})
		_restore_local_law_team(sequence, place_id, str(contract.get("faction_id", "")), Vector3(float(target_data.get("x", 0.0)), 0.0, float(target_data.get("z", 0.0))))


func _local_law_team_unresolved(sequence: int) -> bool:
	var found := false
	for slot in 2:
		var subject_id := "local_law_%d_%d_actor" % [sequence, slot]
		var record := WorldHistory.subject(subject_id)
		if record.is_empty():
			return true
		found = true
		if str(record.get("status", "")) not in ["dead", "escaped", "spared", "recruited"]:
			return true
	return not found


func _restore_local_law_team(sequence: int, place_id: String, faction_id: String, target: Vector3) -> Array[String]:
	var subjects: Array[String] = []
	if place_id == "" or faction_id == "":
		return subjects
	var place := WorldHistory.subject(place_id)
	var place_at: Dictionary = place.get("at", {})
	var centre := Vector3(float(place_at.get("x", target.x)), 0.0, float(place_at.get("z", target.z)))
	var faction := WorldHistory.subject(faction_id)
	var faction_name := str(faction.get("name", faction_id)).replace("_", " ")
	var toward := target - centre
	toward.y = 0.0
	if toward.length_squared() < 0.01:
		toward = Vector3(1, 0, 0)
	toward = toward.normalized()
	var across := Vector3(-toward.z, 0, toward.x)
	for slot in 2:
		var instance_id := "local_law_%d_%d" % [sequence, slot]
		var subject_id := "%s_actor" % instance_id
		if str(WorldHistory.subject(subject_id).get("status", "")) in ["dead", "escaped", "spared", "recruited"]:
			continue
		if encounter_actors.any(func(actor: Dictionary): return str(actor.get("encounter_id", "")) == instance_id):
			subjects.append(subject_id)
			continue
		var who := CAST.person(instance_id)
		var spawn_at := centre - toward * 18.0 + across * (-5.0 if slot == 0 else 5.0)
		var spawned := _spawn_encounter_actor({
			"instance_id": instance_id, "kind": "hostile", "display_name": str(who.name),
			"role": "%s CLAIM ENFORCER" % faction_name.to_upper(),
			"elo": 1080 + slot * 45, "variation": 520 + sequence * 3 + slot,
			"tint": "664238", "loot": ["local claim writ", "field restraint"],
			"summary": "Sent by %s to answer a witnessed wrong on %s." % [faction_name, str(place.get("name", place_id))],
		}, spawn_at)
		if spawned.is_empty():
			continue
		spawned["law_target"] = target
		spawned["law_dispatch_sequence"] = sequence
		spawned["law_arrived"] = false
		WorldHistory.amend_subject(str(spawned.subject_id), {
			"faction": faction_name, "faction_id": faction_id, "law_dispatch": sequence,
			"contract_place": place_id, "memory": "Sent to answer a witnessed wrong on %s." % str(place.get("name", place_id)),
		})
		HUNT_MEMORY.remember(str(spawned.subject_id), "local_law", "%s:%d" % [place_id, sequence])
		subjects.append(str(spawned.subject_id))
	return subjects


func _nearest_takeable_chunk(radius: float) -> Node3D:
	var nearest: Node3D
	var nearest_distance := radius
	for candidate in GoreChunks.live:
		if not is_instance_valid(candidate) or bool(GoreChunks.identify(candidate).get("taken", false)):
			continue
		var distance := player.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _equip_carried_limb() -> void:
	var index: int = handheld.carry.first_index("limb")
	if index < 0:
		prompt.text = "CARRY HAS NO WHOLE LIMB"
		return
	_put_smokeable_away(false)
	_clear_carried_limb_model(false)
	carried_limb_index = index
	for model in arsenal.models.values():
		(model as Node3D).visible = false
	var item: Dictionary = handheld.carry.items[index]
	carried_limb_model = MeshInstance3D.new()
	carried_limb_model.name = "CarriedLimbWeapon"
	carried_limb_model.mesh = BodyMesh.leg(0.82) if str(item.zone).ends_with("leg") else BodyMesh.arm(0.72)
	carried_limb_model.material_override = WorldLook.surface(Color("6b3d34"), "flesh", 44)
	carried_limb_model.position = Vector3(0.0, -0.48, 0.18)
	carried_limb_model.rotation = Vector3(PI * 0.5, 0.0, -0.18)
	carried_limb_model.set_meta("inspect_rest_position", carried_limb_model.position)
	carried_limb_model.set_meta("inspect_rest_rotation", carried_limb_model.rotation)
	# A severed limb is still held by the player's hand. Previously it was the
	# only equipped class parented directly to the arm with no hand at all, which
	# made both the weapon and its inspection pose float. Grip near the narrow end
	# and leave most of the improvised club beyond the knuckles.
	var limb_hand := HELD_GEAR.build_humiliation_hand(1)
	limb_hand.name = "CarriedLimbGripHand"
	HELD_GEAR.set_pose(limb_hand, "wrap")
	limb_hand.position = Vector3(-0.20, -0.052, 0.0)
	limb_hand.rotation = Vector3(-PI * 0.5, 0.0, PI * 0.5)
	limb_hand.set_meta("grip_rest_position", limb_hand.position)
	limb_hand.set_meta("grip_rest_rotation", limb_hand.rotation)
	limb_hand.set_meta("forearm_entry", Vector3(0.47, -0.54, -0.31))
	carried_limb_model.add_child(limb_hand)
	(player_rig.parts.right_arm as Node3D).add_child(carried_limb_model)
	prompt.text = "%s // IMPROVISED WEAPON // %d%%" % [str(item.label), roundi(float(item.condition) * 100.0)]


func _begin_carried_limb_attack(heavy: bool) -> Dictionary:
	if carried_limb_index < 0 or carried_limb_index >= handheld.carry.items.size() or attack_cooldown > 0.0:
		return {"accepted": false, "reason": "busy"}
	var item: Dictionary = handheld.carry.items[carried_limb_index]
	return {
		"accepted": true, "weapon": "severed_limb", "kind": "melee",
		"damage": 31.0 if heavy else 21.0, "impulse": 34.0 if heavy else 24.0,
		"damage_type": "blunt", "range": 3.25, "windup": 0.30 if heavy else 0.20,
		"stamina": 24.0 if heavy else 14.0, "cooldown": 0.92 if heavy else 0.68,
		"heavy": heavy, "carried_label": str(item.label),
	}


func _wear_carried_limb(heavy: bool) -> void:
	if carried_limb_index < 0:
		return
	var remaining: float = handheld.carry.damage_item(carried_limb_index, 0.28 if heavy else 0.16)
	if remaining > 0.0:
		return
	var broken: Dictionary = handheld.carry.drop(carried_limb_index)
	WorldHistory.record_event("carried_limb_destroyed", {"item": broken, "location": HUNT_LOCATION})
	_clear_carried_limb_model()
	prompt.text = "THE IMPROVISED LIMB COMES APART"


func _clear_carried_limb_model(show_arsenal := true) -> void:
	if carried_limb_model != null and is_instance_valid(carried_limb_model):
		carried_limb_model.queue_free()
	carried_limb_model = null
	carried_limb_index = -1
	if show_arsenal:
		arsenal._update_models()


func _sell_first_carried_part() -> Dictionary:
	var index: int = handheld.carry.first_index("limb")
	if index < 0:
		index = handheld.carry.first_index("organ")
	if index < 0:
		index = handheld.carry.first_index("cybernetic")
	if index < 0:
		return {}
	if index == carried_limb_index:
		_clear_carried_limb_model()
	return handheld.carry.sell(index)


func _begin_canonical_encounter() -> void:
	if story_step >= 2:
		return
	story_step = 2
	enemy_retreating = false
	enemy.visible = true
	enemy.global_position = Vector3(0, 1.2, -16)
	var mara := WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT))
	mara_encounter_number = 2 if bool(mara.get("is_rival", false)) and not (mara.get("rival_adaptation", {}) as Dictionary).is_empty() else 1
	enemy_health_max = 150 if mara_encounter_number == 2 else 100
	enemy_health = enemy_health_max
	WorldHistory.update_subject(CAST.id_for(CAPTAIN_SLOT), {"status": "hunting", "encounter_number": mara_encounter_number, "memory": "Mara returned rebuilt to settle the Bone Yard debt." if mara_encounter_number == 2 else "Mara came to settle the Bone Yard debt."}, "hunt_arc_started")
	var offscreen_hunt := OFFSCREEN_HUNTS.start(CAST.id_for(CAPTAIN_SLOT), "player", HUNT_LOCATION)
	WorldHistory.record_event("canonical_hunt_encounter_started", {"hunter": "player", "target": CAST.id_for(CAPTAIN_SLOT), "location": HUNT_LOCATION, "encounter_number": mara_encounter_number})
	HUNT_MEMORY.remember(CAST.id_for(CAPTAIN_SLOT), "canonical_rival")
	if mara_encounter_number == 2:
		_spawn_ashline_reinforcements()
		prompt.text = "SECOND HUNT // %s: INDUSTRIAL ARM, REBUILT WRECKER, TWO ASHLINE KNIVES." % _captain_name()
	else:
		prompt.text = "HUNT ARC: %s has found you. Do not kill the story; make them remember." % _captain_name()
	if int(offscreen_hunt.get("hunt_offscreen_turns", 0)) > 0:
		prompt.text += "\nKEPT HUNTING WHILE YOU WERE GONE // %s // %d TURNS" % [str(offscreen_hunt.get("hunt_phase", "searching")).to_upper(), int(offscreen_hunt.hunt_offscreen_turns)]


func _update_rival(delta: float) -> void:
	if enemy == null or enemy_retreating or story_step < 2:
		return
	var to_player := player - enemy.global_position
	to_player.y = 0
	var distance := to_player.length()
	# F10.3. This is deliberately a local value, asked for at the decision and
	# discarded. The next frame reads WorldHistory again, so a wound that lands
	# during the fight can change the captain's spacing without a cached tactic
	# on this scene or on her body.
	var tactic := _fresh_rival_tactic(CAST.id_for(CAPTAIN_SLOT))
	var approach := RIVAL_TACTICS.approach(tactic, distance) if not tactic.is_empty() else "close"
	if approach == "withdraw":
		var away := -to_player.normalized() if distance > 0.1 else Vector3.FORWARD
		enemy.global_position += away * delta * 4.3
		enemy.look_at(player, Vector3.UP)
	elif approach == "hold" and distance > 3.2:
		# Holding is active: keep the player in front rather than freezing in the
		# last travel pose. The player can close the distance and force the melee.
		enemy.look_at(player, Vector3.UP)
	elif distance > 3.2:
		enemy.global_position += to_player.normalized() * delta * 4.3
		enemy.look_at(player, Vector3.UP)
	else:
		rival_attack_clock += delta
		if rival_attack_clock < 1.25:
			if rival_attack_clock > 0.8:
				prompt.text = "MARA DRAWS BACK — DODGE"
			return
		rival_attack_clock = 0.0
		if dodge_remaining > 0.0:
			return
		health = maxi(0, health - 7)
		stamina = maxf(0, stamina - 12)
		_wound_player(enemy.global_position, 17.0, "cut")
		WorldHistory.record_event("rival_struck_player", {"rival": CAST.id_for(CAPTAIN_SLOT), "location": HUNT_LOCATION})
		if health <= 0:
			_route_player_defeat(CAST.id_for(CAPTAIN_SLOT))
	if enemy_health <= 25:
		_rival_retreats("Mara escapes through the tunnel. Her next body will not be the same.")


func _route_player_defeat(captor_id: String) -> void:
	var result := DEFEAT_ROUTER.route(captor_id, HUNT_LOCATION)
	_enter_captivity(result)


## Shared by a defeat that happens in this scene and one the player already
## carried in from a lost derby heat (see `_ready()`) — the captivity state
## is the same either way, so it has one place to be set rather than two.
func _enter_captivity(result: Dictionary) -> void:
	health = 1
	stamina = 0.0
	enemy_retreating = true
	if enemy != null:
		enemy.visible = false
	player = Vector3(-31.0, 1.5, 26.0)
	player_body.position = player - Vector3.UP * 0.6
	prompt.text = "%s // HELD AT %s // [K] DIE DELIBERATELY" % [str(result.outcome).to_upper(), str(result.destination).replace("_", " ").to_upper()]


func _deliberate_redecant() -> void:
	var result := DEFEAT_ROUTER.redecant()
	if result.is_empty():
		return
	health = 65
	stamina = 70.0
	player_rig.anatomy.configure("player")
	player_rig.restore({})
	WorldHistory.amend_subject("player", {"anatomy_state": player_rig.snapshot()})
	player = Vector3(0, 1.5, 19)
	player_body.position = player - Vector3.UP * 0.6
	enemy_retreating = true
	prompt.text = "RE-DECANTED // THE TAR KEPT %d THINGS" % (result.forfeited as Array).size()


## O4.2. Whether somebody already has the melee opening this frame. Read once,
## ahead of the per-actor loop, so a second and third hostile arriving at the
## same time see the slot as taken and go to O4.2's orbit rather than every
## actor checking a stale picture of its own making.
func _melee_slot_taken() -> bool:
	for actor: Dictionary in encounter_actors:
		if str(actor.get("disposition", "hostile")) != "hostile":
			continue
		if str(actor.get("state", "")) in ["staggered", "fleeing", "downed"]:
			continue
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if player.distance_to(node.global_position) <= 3.0:
			return true
	return false


## F10.3. The only production door into rival tactics. RivalRegistry decides
## whether a real person earned the role; RivalTactics derives the answer from
## the event record right now. Nothing returned here is written onto `actor`,
## which keeps a long-lived encounter dictionary from becoming a stale second
## source of truth.
func _fresh_rival_tactic(subject_id: String) -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	if not bool(subject.get("is_rival", false)):
		return {}
	return RIVAL_TACTICS.tactic_for(subject_id)


func _update_encounter_actors(delta: float) -> void:
	var melee_slot_taken := _melee_slot_taken()
	for index in range(encounter_actors.size() - 1, -1, -1):
		var actor: Dictionary = encounter_actors[index]
		# O2.5 v2. Each body runs on its own clock during a hit: the one that was
		# struck slows, the rest of the region does not notice. Named apart from
		# `actor_delta` because GDScript will not let a local shadow a parameter.
		var actor_delta: float = delta * impact_feel.scale_for(str(actor.get("subject_id", "")))
		# O2.7 v4. Their rig animates and bleeds on the same clock their state
		# machine runs on, so the spray coming out of somebody freezes with
		# the body it is coming out of.
		var actor_rig := actor.get("rig") as BaselineHuman
		if actor_rig != null and is_instance_valid(actor_rig):
			actor_rig.motion_scale = actor_delta / maxf(delta, 0.00001)
		var node := actor.get("node") as Node3D
		var anatomy: Node = actor.get("anatomy") as Node
		if node == null or not is_instance_valid(node) or anatomy == null:
			encounter_actors.remove_at(index)
			continue
		if anatomy.dead and not bool(actor.get("dead", false)):
			_kill_encounter_actor(index, "bleed_out")
			continue
		# O5.10 v2. Recovers regardless of state, same as the player's own —
		# standing in a stagger is still standing, and balance comes back on
		# its own rather than only when the fight lets up.
		actor["footing"] = clampf(_actor_footing(actor) + FOOTING_RECOVERY * actor_delta, 0.0, 1.0)
		# O6.1. A grip regained rather than a weapon regained — the same
		# threshold that took it decides when it comes back.
		if bool(actor.get("disarmed", false)) and float(actor.footing) >= STUMBLE_AT:
			actor["disarmed"] = false
			prompt.text = "%s RECOVERS THEIR GRIP" % str(actor.display_name).to_upper()
		if anatomy.downed:
			(node as CharacterBody3D).velocity = Vector3.ZERO
			actor.attack_time = 0.0
			if str(actor.get("state", "")) != "downed":
				actor.state = "downed"
				WorldHistory.update_subject(str(actor.subject_id), {"status": "downed", "anatomy_state": actor.rig.snapshot()}, "npc_downed")
			if player.distance_to(node.global_position) <= 4.0:
				prompt.text = "[E] %s / DOWNED, ALIVE — DECIDE THEIR FATE" % str(actor.display_name).to_upper()
			continue
		if str(actor.get("state", "")) == "staggered":
			actor["stagger_remaining"] = maxf(0.0, float(actor.get("stagger_remaining", 0.0)) - actor_delta)
			(node as CharacterBody3D).velocity = Vector3.ZERO
			actor.attack_time = 0.0
			if float(actor.stagger_remaining) <= 0.0:
				actor.state = "hunting"
			continue
		if str(actor.get("disposition", "hostile")) != "hostile":
			actor.attack_time = 0.0
			continue
		var offset := player - node.global_position
		offset.y = 0
		var distance := offset.length()
		var rival_tactic := _fresh_rival_tactic(str(actor.get("subject_id", "")))
		var rival_approach := RIVAL_TACTICS.approach(rival_tactic, distance) if not rival_tactic.is_empty() else ""
		if str(actor.get("state", "idle")) == "maimed":
			actor["maimed_remaining"] = maxf(0.0, float(actor.get("maimed_remaining", 0.0)) - actor_delta)
			if float(actor.maimed_remaining) <= 0.0:
				actor.state = "hunting"
		if str(actor.get("state", "idle")) == "fleeing":
			var away := -offset.normalized() if distance > 0.1 else Vector3.FORWARD
			_move_actor_on_route(actor, node.global_position + away * 40.0, actor_delta)
			if distance > 72.0:
				misfire_director.resolve(str(actor.get("encounter_id", "")), "escaped")
				WorldHistory.update_subject(str(actor.subject_id), {"status": "escaped", "memory": "Escaped the Hunter while bleeding.", "anatomy_state": anatomy.call("snapshot")}, "npc_escaped_bleeding")
				RIVAL_REGISTRY.consider(str(actor.subject_id))
				node.queue_free()
				encounter_actors.remove_at(index)
		elif actor.get("law_target") is Vector3 and not bool(actor.get("law_arrived", false)):
			# A dispatched team knows the scene it was sent to, not where the
			# player moved afterward. Walk the real route there; normal perception
			# takes over only after arrival.
			var law_target: Vector3 = actor.law_target
			if node.global_position.distance_to(law_target) > 2.5:
				_move_actor_on_route(actor, law_target, actor_delta)
			else:
				actor["law_arrived"] = true
				WorldHistory.amend_subject(str(actor.subject_id), {"status": "searching_dispatched_scene"})
				WorldHistory.record_event("local_law_enforcer_arrived", {
					"subject_id": str(actor.subject_id), "source_sequence": int(actor.get("law_dispatch_sequence", -1)),
					"at": {"x": law_target.x, "z": law_target.z},
				})
		elif LauncherActor.is_launcher(actor) and LauncherActor.in_envelope(distance) and (bool(actor.get("tracking_player", false)) or bool(actor.get("tracking_light", false))):
			# AD3.1. A launcher holds its ground and works the tube; all of the
			# decision lives in `launcher_actor.gd` so this branch stays a hook
			# rather than a second copy of the rule. Closing inside the arming
			# ring drops it out of this branch entirely — which is the counterplay
			# being the distance rather than a damage number.
			var shot := LauncherActor.advance(actor, distance, actor_delta)
			match str(shot.state):
				"winding":
					prompt.text = "%s SHOULDERS THE TUBE" % str(actor.display_name).to_upper()
				"fire":
					_fire_launcher(actor, node)
		elif not rival_tactic.is_empty() and distance < 24.0 and (bool(actor.get("tracking_player", false)) or bool(actor.get("tracking_light", false))) and rival_approach == "withdraw":
			# A remembered close-range wound has an immediate physical answer: get
			# outside the remembered distance instead of walking into the shared
			# three-metre melee ring like an ordinary hostile.
			var away := -offset.normalized() if distance > 0.1 else Vector3.FORWARD
			_move_actor_on_route(actor, node.global_position + away * 10.0, actor_delta)
		elif not rival_tactic.is_empty() and distance > 3.0 and distance < 24.0 and (bool(actor.get("tracking_player", false)) or bool(actor.get("tracking_light", false))) and rival_approach == "hold":
			# Circling and stand-off memories use their own recorded distance. A
			# stable per-person phase prevents multiple rivals sharing one point;
			# the tactic itself is still read fresh above and never stored.
			var start_angle := fposmod(float(hash(str(actor.get("subject_id", index)))), TAU)
			actor["orbit_angle"] = fposmod(float(actor.get("orbit_angle", start_angle)) + actor_delta * 0.15, TAU)
			var radius := float(rival_tactic.get("keep_distance", 4.0))
			var orbit_point := player + Vector3(cos(actor.orbit_angle), 0, sin(actor.orbit_angle)) * radius
			_move_actor_on_route(actor, orbit_point, actor_delta)
		elif not rival_tactic.is_empty() and distance > 3.0 and distance < 24.0 and (bool(actor.get("tracking_player", false)) or bool(actor.get("tracking_light", false))) and rival_approach == "close":
			# A rival whose record says press does not inherit the ordinary crowd's
			# melee queue. Their remembered tactic wins this one decision.
			_move_actor_on_route(actor, player, actor_delta)
		elif str(actor.get("disposition", "hostile")) == "hostile" and distance < 24.0 and distance > 3.0 and (bool(actor.get("tracking_player", false)) or bool(actor.get("tracking_light", false))):
			# O4.2. A naive approach put every hostile in single file toward the
			# same 3 m ring, which reads as a queue rather than a fight. Whoever
			# does not already hold the melee opening orbits at a stand-off
			# distance instead of stacking into it — the fight surrounds you
			# rather than lining up for a turn.
			if melee_slot_taken:
				# Slow enough that the actor's own move speed (3.7 m/s) can
				# still close the gap to the target ring while tracking it —
				# at 6.5 m radius, 0.5 rad/s asked for 3.25 m/s of tangential
				# speed alone, leaving almost nothing to actually get there,
				# which is why it spiralled straight into the player instead
				# of settling into orbit.
				var start_angle := fposmod(float(hash(str(actor.get("subject_id", index)))), TAU)
				actor["orbit_angle"] = fposmod(float(actor.get("orbit_angle", start_angle)) + actor_delta * 0.15, TAU)
				# Wider than the stand-off actually needs to read at, because the
				# route itself only ever lands on a 2 m pathfinding grid cell —
				# a tight radius rounds down into the same ring it is meant to
				# avoid often enough to be the whole bug again.
				var orbit_point := player + Vector3(cos(actor.orbit_angle), 0, sin(actor.orbit_angle)) * 6.5
				_move_actor_on_route(actor, orbit_point, actor_delta)
			else:
				_move_actor_on_route(actor, player, actor_delta)
		elif distance <= 3.0 and not _actor_stumbling(actor):
			# O4.1. A player mid-swing cannot cancel or guard, so an enemy who
			# is actually watching presses that opening instead of ticking down
			# on its own clock regardless of what you just committed to.
			# O5.10 v2. A stumbling fighter cannot wind up an attack at all —
			# the same "the guard will not hold" rule the player's own footing
			# already enforces, on the other side of the fight.
			var pressing := 2.2 if strike_windup >= 0.0 else 1.0
			actor["attack_time"] = float(actor.get("attack_time", 0.0)) + actor_delta * pressing
			var attack_cycle := _actor_attack_cycle(actor)
			if float(actor.attack_time) > attack_cycle * 0.57:
				prompt.text = "%s RAISES THEIR WEAPON" % str(actor.display_name).to_upper()
			if float(actor.attack_time) >= attack_cycle:
				actor.attack_time = 0.0
				if dodge_remaining <= 0.0:
					# O2.4. Through the guard first. A parry takes none of it and
					# hands the initiative back; a block takes the edge off and
					# spends stamina instead of blood.
					var incoming := float(_actor_attack_damage(actor))
					var guarded: Dictionary = guard_absorb(incoming, node.global_position)
					if bool(guarded.get("parried", false)):
						# The attacker eats their own commitment. This wrote to
						# "stagger" and "cooldown" — neither of which anything
						# ever read — so a parry cost the enemy nothing beyond
						# the damage it already blocked. Real footing loss now.
						_actor_lose_footing(actor, 0.45, "%s LOSES THEIR FOOTING // PRESS THE OPENING" % str(actor.display_name).to_upper())
					var health_after := health - roundi(float(guarded.get("damage", incoming)))
					_wound_player(node.global_position, maxf(5.0, 15.0 * _actor_combat_ratio(actor)), "cut")
					# AE10.13. Ordinary hostiles keep the old one-health floor: the
					# undying player is not silently killed by a roaming damage tick.
					# A physical law team is different. Its finishing blow performs the
					# arrest it was commissioned for through the existing persistent
					# defeat route, with this exact officer and issuing jurisdiction.
					if health_after <= 0 and actor.has("law_dispatch_sequence"):
						_complete_local_law_arrest(actor)
						return
					health = maxi(1, health_after)


func _complete_local_law_arrest(actor: Dictionary) -> void:
	var player_record := WorldHistory.subject("player")
	if str(player_record.get("status", "")) in ["shackled", "stamped", "conscripted"]:
		return
	var captor_id := str(actor.get("subject_id", ""))
	if captor_id.is_empty():
		return
	var captor := WorldHistory.subject(captor_id)
	var place_id := str(captor.get("contract_place", ""))
	var sequence := int(actor.get("law_dispatch_sequence", -1))
	_route_player_defeat(captor_id)
	if not place_id.is_empty():
		var place := WorldHistory.subject(place_id)
		var contract: Dictionary = (place.get("active_law_dispatch", {}) as Dictionary).duplicate(true)
		if int(contract.get("source_sequence", -2)) == sequence:
			contract["status"] = "arrested"
			contract["arrested_by"] = captor_id
			WorldHistory.amend_subject(place_id, {"active_law_dispatch": contract})
	WorldHistory.record_event("local_law_arrested_player", {
		"actor": captor_id, "subject_id": "player", "place_id": place_id,
		"faction_id": str(captor.get("faction_id", "")), "source_sequence": sequence,
	})


func _actor_combat_ratio(actor: Dictionary) -> float:
	var anatomy := actor.get("anatomy") as AnatomyComponent
	return anatomy.combat_ratio() if anatomy != null else 1.0


## O5.10 v2. Enemies had the older binary `staggered` lock and nothing else —
## a hit either interrupted them outright or left no mark on their poise at
## all. The player has had a continuous `footing` meter since O5.7 that whiffs,
## blocks and shoves all chip away at, with real consequences below
## `STUMBLE_AT` rather than a fixed lockout window. Same meter, same constants,
## now on both bodies in the fight rather than one.
func _actor_footing(actor: Dictionary) -> float:
	return float(actor.get("footing", 1.0))


func _actor_stumbling(actor: Dictionary) -> bool:
	return _actor_footing(actor) < STUMBLE_AT


func _actor_lose_footing(actor: Dictionary, amount: float, reason := "") -> void:
	var before := _actor_footing(actor)
	actor["footing"] = clampf(before - amount, 0.0, 1.0)
	if before >= STUMBLE_AT and float(actor.footing) < STUMBLE_AT:
		# The moment it goes, not the ongoing state, is the one worth a beat —
		# the player gets the same treatment in lose_footing().
		var node := actor.get("node") as Node3D
		if node != null and is_instance_valid(node):
			(node as CharacterBody3D).velocity = Vector3.ZERO
		actor.attack_time = 0.0
		if not reason.is_empty():
			prompt.text = reason


## O3.1. What fraction of a body is actually still standing, read off every
## zone rather than only the arms (`combat_ratio`) or only the legs
## (`mobility_ratio`) — the canonical Mara fight needed the whole picture
## since a fighter who only ever gets hit in the torso is not "at full
## strength" just because her limbs are untouched.
func _rig_health_ratio(rig: BaselineHuman) -> float:
	if rig == null or not is_instance_valid(rig):
		return 0.0
	var current := 0.0
	var ceiling := 0.0
	for zone_id in BaselineHuman.ZONES:
		var max_health := float((AnatomyComponent.DEFAULT_ZONES[zone_id] as Dictionary).health)
		ceiling += max_health
		current += clampf(float((rig.anatomy.zones.get(zone_id, {}) as Dictionary).get("health", max_health)), 0.0, max_health)
	return clampf(current / maxf(1.0, ceiling), 0.0, 1.0)


## AD3.1. Fires through the same `Ballistics` every other round in this game
## leaves a barrel through, carrying the same payload shape `_on_round_hit()`
## already resolves — so a warhead finds a zone through the anatomy (AF1.7)
## and can be met in the air (AD3.3) without either of those knowing a
## launcher exists.
func _fire_launcher(actor: Dictionary, node: Node3D) -> void:
	if ballistics == null or not is_instance_valid(ballistics):
		return
	var muzzle: Vector3 = node.global_position + Vector3.UP * 1.1
	var toward := (player - muzzle)
	if toward.length() < 0.01:
		return
	ballistics.fire(muzzle, toward.normalized(), LauncherActor.CALIBRE, 0.0, 1, str(actor.get("subject_id", "launcher")), LauncherActor.payload(actor))
	WorldHistory.record_event("launcher_fired", {
		"subject_id": str(actor.get("subject_id", "")), "location": HUNT_LOCATION,
	})
	prompt.text = "INCOMING"


func _actor_attack_cycle(actor: Dictionary) -> float:
	# O5.10 v2. Off-balance on top of whatever their arms already cost them —
	# a fighter who is barely standing winds up slower than their combat_ratio
	# alone would say, the same way a player who is stumbling swings softer.
	# O6.1. A fist comes back faster than a weapon does — the same reason the
	# player's own bare-hand attacks run at a shorter cooldown than a cleaver.
	var unarmed := NPC_UNARMED_CYCLE_SCALE if bool(actor.get("disarmed", false)) else 1.0
	return lerpf(2.4, 1.4, _actor_combat_ratio(actor)) * lerpf(1.6, 1.0, _actor_footing(actor)) * unarmed


func _actor_attack_damage(actor: Dictionary) -> int:
	# O6.1. Low, but not a tickle — the same ratio bare hands hit for against
	# the player's own cleaver (11 of 44 is a hair under a third).
	var unarmed := NPC_UNARMED_DAMAGE_SCALE if bool(actor.get("disarmed", false)) else 1.0
	return maxi(1, roundi(9.0 * unarmed * _actor_combat_ratio(actor) * lerpf(0.55, 1.0, _actor_footing(actor))))


func _apply_combat_response(actor: Dictionary, attack: Dictionary, hit: Dictionary) -> void:
	var response := COMBAT_RESPONSE.from_hit(attack, actor.anatomy, hit)
	# O5.10 v2. Every landed hit costs footing on its own scale — this used to
	# leave no mark at all below the stagger threshold, so a fighter chipped
	# by three medium blows fought exactly as well as one who had taken none,
	# right up until the fourth one crossed the line.
	_actor_lose_footing(actor, clampf(float(response.severity) / COMBAT_RESPONSE.STAGGER_THRESHOLD * 0.3, 0.05, 0.5))
	# O6.1. The other half of AN2.2: hit hard enough to stagger them while
	# they are already barely standing, and the weapon goes the same way a
	# barely-held one does in the player's own hand.
	if not bool(actor.get("disarmed", false)) and bool(response.staggered) and _actor_footing(actor) < STUMBLE_AT:
		actor["disarmed"] = true
		WorldHistory.record_event("npc_disarmed", {"subject_id": actor.subject_id, "location": HUNT_LOCATION})
		prompt.text = "%s'S GRIP GIVES OUT" % str(actor.display_name).to_upper()
	if not bool(response.staggered):
		return
	actor.state = "staggered"
	actor["stagger_remaining"] = float(response.duration)
	actor.attack_time = 0.0
	WorldHistory.record_event("attack_interrupted", {
		"actor": "player", "subject_id": actor.subject_id,
		"weapon": attack.get("weapon", "unknown"), "severity": response.severity,
		"location": HUNT_LOCATION,
	})
	prompt.text = "%s LOSES THEIR FOOTING // PRESS THE OPENING" % str(actor.display_name).to_upper()


func _apply_maiming_state(actor: Dictionary, zones: Array, direction: Vector3) -> void:
	if zones.is_empty() or actor.anatomy.dead or actor.anatomy.downed:
		return
	actor.state = "maimed"
	actor["maimed_remaining"] = 2.4
	actor["loot_at_risk"] = false
	var ratio := _actor_combat_ratio(actor)
	WorldHistory.update_subject(str(actor.subject_id), {
		"status": "maimed_fighting",
		"anatomy_state": actor.rig.snapshot(),
		"memory": "Lost %s and kept fighting." % ", ".join(PackedStringArray(zones)),
	}, "limb_severed_in_combat")
	WorldHistory.record_event("limb_severed_in_combat", {
		"subject_id": actor.subject_id,
		"zones": zones.duplicate(),
		"direction": direction,
		"combat_ratio": snappedf(ratio, 0.01),
		"alive": true,
		"location": HUNT_LOCATION,
	})
	prompt.text = "%s LOSES %s — STILL FIGHTING AT %d%%" % [str(actor.display_name).to_upper(), str(zones[0]).replace("_", " ").to_upper(), roundi(ratio * 100.0)]

func _move_actor_on_route(actor: Dictionary, destination: Vector3, delta: float) -> void:
	var body := actor.node as CharacterBody3D
	actor["route_time"] = float(actor.get("route_time", 0.0)) - delta
	if float(actor.route_time) <= 0.0:
		actor.route_time = 0.8
		actor["route"] = pathfinder.route(body.position, destination)
		actor["waypoint"] = 1
	var points: PackedVector2Array = actor.get("route", PackedVector2Array())
	var waypoint := int(actor.get("waypoint", 1))
	if waypoint >= points.size():
		return
	var target := Vector3(points[waypoint].x, body.position.y, points[waypoint].y)
	if body.position.distance_to(target) < 0.8:
		actor.waypoint = waypoint + 1
	var direction := (target - body.position).normalized()
	var mobility := float(actor.anatomy.call("mobility_ratio"))
	body.velocity = direction * float(actor.speed) * mobility
	body.velocity.y = -2.0
	body.move_and_slide()
	if direction.length_squared() > 0.01:
		body.look_at(body.position + direction, Vector3.UP)


func _kill_encounter_actor(index: int, cause: String) -> void:
	if index < 0 or index >= encounter_actors.size():
		return
	var actor: Dictionary = encounter_actors[index]
	actor.dead = true
	misfire_director.resolve(str(actor.get("encounter_id", "")), "defeated")
	var node := actor.node as Node3D
	var anatomy: Node = actor.anatomy as Node
	# F1.3 / AE10.10. A report in this live scene belongs to the body carrying
	# it. The ledger has always known how to cut that report, but production
	# deaths never told it a witness had died, so their testimony arrived after
	# their corpse hit the floor. Any real death route converges here: execution,
	# bleed-out or ordinary combat all silence exactly this subject before law can
	# tick the report home.
	witness_ledger.silence(str(actor.subject_id))
	# AE.1 / AE.4. Death, as the world's record rather than the scene's. The
	# status string is read off `RivalRegistry.DEAD` rather than typed here, so
	# the file that decides what "dead" means and the record that says somebody
	# is dead can never drift into disagreeing - and the two fields beside it
	# are what makes the death attributable later, since a status change on its
	# own does not say who did it or where.
	var dead_status := str(RivalRegistry.DEAD[0])
	WorldHistory.update_subject(str(actor.subject_id), {"status": dead_status, "killed_by": "player", "killed_at": HUNT_LOCATION, "memory": "The Hunter caught them before escape.", "anatomy_state": anatomy.call("snapshot")}, "npc_killed")
	var succession := WireNet.new(WireNet.SIGNAL_SURFACE)
	var vacancy := succession.open_vacancy(str(actor.subject_id))
	if not vacancy.is_empty():
		# The vacancy is written first and remains a separate historical fact;
		# succession resolves on the following idle turn from the existing roster.
		call_deferred("_fill_faction_vacancy", str(WorldHistory.subject(str(actor.subject_id)).get("faction_id", "")), str(vacancy.rank), str(actor.subject_id))
	WorldHistory.record_event("loot_dropped", {"subject_id": actor.subject_id, "items": actor.loot, "cause": cause})
	_spawn_loot_cache(node.global_position, actor.loot)
	var label := node.get_node_or_null("Identity") as Label3D
	if label != null:
		label.text = "%s // DEAD\nLOOT DROPPED" % str(actor.display_name).to_upper()
	dead_bodies.append({
		"subject_id": str(actor.subject_id), "display_name": str(actor.display_name),
		"node": node, "rig": actor.get("rig"),
	})
	encounter_actors.remove_at(index)


func _fill_faction_vacancy(faction_id: String, rank: String, fallen_id: String = "") -> void:
	if faction_id.is_empty():
		return
	var succession := WireNet.new(WireNet.SIGNAL_SURFACE)
	# Promotion, exact hunt transfer and the player's retained hunter memory are
	# one deferred world turn. The subsystem batches remain nested beneath it.
	WorldHistory.begin_ledger_batch()
	var promoted := succession.promote_successor(faction_id, rank)
	if promoted.is_empty() or fallen_id.is_empty():
		WorldHistory.commit_ledger_batch()
		return
	var successor_id := str(promoted.get("id", ""))
	var inherited := OFFSCREEN_HUNTS.inherit(fallen_id, successor_id)
	if bool(inherited.get("ok", false)):
		HUNT_MEMORY.remember(successor_id, "inherited_hunt", fallen_id)
	WorldHistory.commit_ledger_batch()

func _actor_by_id(id: String) -> Dictionary:
	for actor in encounter_actors:
		if str(actor.subject_id) == id and is_instance_valid(actor.node):
			return actor
	return {}

func _nearest_downed() -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 4.0
	for actor in encounter_actors:
		if is_instance_valid(actor.node) and actor.rig.is_downed():
			var candidate: float = player.distance_to(actor.node.global_position)
			if candidate <= distance:
				distance = candidate
				nearest = actor
	return nearest

func _accepts_recruitment(subject: Dictionary) -> bool:
	return int(subject.get("bond", 0)) >= 20 or bool(subject.get("recruitment_consent", false)) or float(subject.get("debt_to_player", 0)) > 0


func _recruitment_reason(subject: Dictionary) -> String:
	if int(subject.get("grudge", 0)) >= 40:
		return "They hate you too much to take the offer."
	return "No bond, no debt, no reason to follow you."


## Which zone the finishing blow goes into, and the organ inside it. Executing
## someone reads as finishing the wound that dropped them rather than as a
## generic heart shot, so the kill cam plate differs per victim.
func _execution_target(actor: Dictionary) -> Array:
	var worst := "torso"
	var lowest := 2.0
	for zone_id in AnatomyComponent.DEFAULT_ZONES:
		var ceiling := float((AnatomyComponent.DEFAULT_ZONES[zone_id] as Dictionary).health)
		var ratio: float = float(actor.rig.zone_health(zone_id)) / ceiling
		if ratio < lowest:
			lowest = ratio
			worst = zone_id
	if worst == "head":
		return ["head", "brain"]
	if worst in ["torso", "left_arm", "right_arm"]:
		return ["torso", "heart"]
	# A ruined leg is not where you finish someone; the spine is the nearest
	# structure that ends it from behind a kneeling body.
	return ["torso", "spine"]


func _open_resolution(actor: Dictionary) -> void:
	resolution_target = str(actor.subject_id)
	strike_windup = -1.0
	dodge_remaining = 0.0
	player_body.velocity = Vector3.ZERO
	if handheld.is_open:
		handheld.close_device()
	var identity := actor.node.get_node_or_null("Identity") as Label3D
	if identity != null:
		identity.visible = false
	var subject := WorldHistory.subject(resolution_target)
	resolution_ui.open_for(str(actor.display_name), actor.rig.snapshot(), {
		"subject_id": resolution_target,
		"role": str(subject.get("role", actor.get("disposition", "unfiled"))),
		"recruit": _accepts_recruitment(subject),
		"recruit_reason": _recruitment_reason(subject),
	})
	_update_resolution_window()


func _resolution_cancelled() -> void:
	var actor := _actor_by_id(resolution_target)
	if not actor.is_empty():
		var identity := actor.node.get_node_or_null("Identity") as Label3D
		if identity != null:
			identity.visible = true
	voice_channel.cancel()
	resolution_target = ""


## Keeps the open form honest while the world runs underneath it: the readout
## follows the real body, and the window closes itself if the subject dies of
## their wounds or the player walks away mid-decision.
func _update_resolution_window() -> void:
	var target := _actor_by_id(resolution_target)
	if target.is_empty() or not target.rig.is_downed():
		resolution_ui.cancel_menu()
		prompt.text = "THEY WERE DECIDED FOR YOU."
		return
	if player.distance_to(target.node.global_position) > 5.5:
		resolution_ui.cancel_menu()
		prompt.text = "OUT OF REACH / DECISION ABANDONED"
		return
	resolution_ui.anatomy = target.rig.snapshot()
	resolution_ui.set_voice_state(voice_channel.status, voice_channel.level)
	var head: Node3D = target.rig.head_anchor
	var at: Vector3 = head.global_position if head != null and is_instance_valid(head) else target.node.global_position + Vector3.UP
	if camera.is_position_behind(at):
		resolution_ui.set_world_anchor(Vector2(-1, -1))
	else:
		resolution_ui.set_world_anchor(camera.unproject_position(at))


func _resolve_downed(outcome: String) -> void:
	voice_channel.cancel()
	var actor := _actor_by_id(resolution_target)
	resolution_target = ""
	if actor.is_empty() or not actor.rig.is_downed() or player.distance_to(actor.node.global_position) > 5.5:
		return
	var identity := actor.node.get_node_or_null("Identity") as Label3D
	if identity != null:
		identity.visible = true
	var id := str(actor.subject_id)
	var subject := WorldHistory.subject(id)
	if outcome == "recruit" and not _accepts_recruitment(subject):
		return
	if outcome not in ["execute", "spare", "recruit"]:
		return
	var act_at: Vector3 = actor.node.global_position
	var jurisdiction := ASHBLOOM_HOLDINGS.jurisdiction_at(Vector2(act_at.x, act_at.z))
	var witnesses := WitnessLedger.witnesses_of(act_at, _witness_candidates(), id)
	var resolution_details := {
		"subject_id": id,
		"outcome": outcome,
		"actor": "player",
		"location": HUNT_LOCATION,
		"holding_id": str(jurisdiction.get("holding_id", "")),
		"place_id": str(jurisdiction.get("place_id", "")),
		"held_by": str(jurisdiction.get("held_by", "")),
		"at": {"x": act_at.x, "z": act_at.z},
	}
	if outcome == "execute":
		var finish := _execution_target(actor)
		actor.rig.hit(str(finish[0]), 100.0, 30.0, "puncture", str(finish[1]))
		actor.rig.execute()
		var snapshot: Dictionary = actor.rig.snapshot()
		resolution_details["zone"] = finish[0]
		resolution_details["organ"] = finish[1]
		resolution_details["anatomy_state"] = snapshot
		# Preserve the original chronology: the decision is the fact; death,
		# vacancy and dropped loot are its consequences.
		witness_ledger.record("npc_resolution", resolution_details, witnesses)
		kill_cam.trigger(str(actor.display_name), str(finish[0]), actor.node.global_position - player, "EXECUTION / %s" % str(finish[1]).to_upper().replace("_", " "), snapshot)
		_kill_encounter_actor(encounter_actors.find(actor), "execution")
	else:
		actor.rig.spare()
		actor.state = "recruited" if outcome == "recruit" else "spared"
		actor.disposition = "ally" if outcome == "recruit" else "neutral"
		actor.attack_time = 0.0
		var relations: Dictionary = subject.get("relations", {}).duplicate(true)
		if outcome == "recruit":
			relations["player"] = {"kind": "bond", "strength": maxi(20, int(subject.get("bond", 0))), "consensual": true}
		WorldHistory.update_subject(id, {"status": actor.state, "disposition": actor.disposition, "relations": relations, "grudge": int(subject.get("grudge", 0)) + (5 if outcome == "spare" else 0), "memory": "The Hunter offered shelter; I agreed to join." if outcome == "recruit" else "The Hunter spared me. I remember the wounds.", "anatomy_state": actor.rig.snapshot()}, "npc_recruited" if outcome == "recruit" else "npc_spared")
		# Somebody left alive carries their own outcome even when everybody else
		# looked away. Executed subjects cannot report themselves.
		if not witnesses.has(id):
			witnesses.append(id)
		resolution_details["anatomy_state"] = actor.rig.snapshot()
		if outcome == "spare":
			RIVAL_REGISTRY.consider(id)
		misfire_director.resolve(str(actor.get("encounter_id", "")), actor.state)
		var label := actor.node.get_node_or_null("Identity") as Label3D
		if label != null:
			label.text = "%s / %s" % [str(actor.display_name).to_upper(), str(actor.state).to_upper()]
		witness_ledger.record("npc_resolution", resolution_details, witnesses)
	if outcome in ["spare", "recruit"]:
		_refresh_ascent_job_market()
	prompt.text = "DISPOSITION RECORDED / " + outcome.to_upper()
	attack_cooldown = 0.72


## Mercy already has one canonical production fact above: npc_resolution. Ask
## each existing ascent entity to read that same ledger, then open the
## reciprocal top-tier market only on the transition from unnoticed to noticed.
## Nothing is awarded per button press and repeated checks cannot duplicate an
## offer; HuntContracts reads the current CROWN holder fresh after succession.
func _refresh_ascent_job_market() -> void:
	for entity_id in AscentEntities.ENTITIES:
		var before := bool(WorldHistory.subject(str(entity_id)).get("has_noticed", false))
		var entity := AscentEntities.regard(str(entity_id), "player")
		if not before and bool(entity.get("has_noticed", false)):
			HuntContracts.publish_opposition(str(entity_id))


func _voice_capture(holding: bool) -> void:
	var actor := _actor_by_id(resolution_target)
	if actor.is_empty() or player.distance_to(actor.node.global_position) > 5.5:
		resolution_ui.set_voice_state("NO SUBJECT IN VOICE RANGE")
		return
	if holding:
		voice_channel.begin(str(actor.subject_id), actor.rig.head_anchor)
	else:
		voice_channel.finish()


func _voice_captured(subject_id: String, result: Dictionary) -> void:
	var actor := _actor_by_id(subject_id)
	if actor.is_empty() or not bool(result.get("sent", false)):
		resolution_ui.set_voice_state(voice_channel.status)
		return
	var subject := WorldHistory.subject(subject_id)
	var reply := "You have my attention. Make the offer." if _accepts_recruitment(subject) else "I heard you. It changes nothing yet."
	if int(subject.get("grudge", 0)) >= 40:
		reply = "I know your voice. I still hate you."
	WorldHistory.begin_ledger_batch()
	var contact := PLAYER_ACTION_LEDGER.record("proximity_voice_addressed", {"speaker": "player", "listener": subject_id, "duration": result.duration, "location": HUNT_LOCATION, "raw_audio_saved": false})
	WorldHistory.amend_subject(subject_id, {"last_voice_contact": int(contact.get("sequence", WorldHistory.event_count())), "memory": "The Hunter spoke to me while I was downed."})
	WorldHistory.commit_ledger_batch()
	voice_channel.play_positional_acknowledgement(actor.rig.head_anchor)
	resolution_ui.set_voice_state("VOICE RECEIVED / POSITIONAL REPLY", float(result.peak), reply)


func _rival_retreats(message: String) -> void:
	if enemy_retreating:
		return
	enemy_retreating = true
	enemy.visible = false
	WorldHistory.update_subject(CAST.id_for(CAPTAIN_SLOT), {"status": "escaped"}, "rival_survived_hunt")
	WorldHistory.record_event("hunt_arc_first_beat_complete", {"target": CAST.id_for(CAPTAIN_SLOT), "outcome": "escaped", "location": HUNT_LOCATION})
	RIVAL_REGISTRY.consider(CAST.id_for(CAPTAIN_SLOT))
	prompt.text = message
	if WorldHistory.complete_demo("ashline_captain_repulsed", {
		"after": "hunt_arc_first_beat_complete",
		"location": HUNT_LOCATION,
		"next": ["outer_ashbloom_road", "ashline_second_hunt", "board_contracts"],
	}):
		demo_wall.open_wall()


func _leave_demo_wall() -> void:
	Interstitial.travel("res://country_town_menu.tscn", "leaving this universe on the board")


## INDEX offers a record; the room's one physical Board decides whether there
## is space for it. The handheld and full-size reader both arrive here through
## the same signal, preventing two invisible collections of pinned evidence.
func _pin_index_record(ref: String, kind: String, title: String) -> void:
	if pin_board.pin(ref, kind):
		prompt.text = "%s // FILED ON THE BOARD" % title.to_upper()
		return
	var refusal := str(pin_board.get("last_refusal"))
	prompt.text = refusal if not refusal.is_empty() else "%s // ALREADY ON THE BOARD" % title.to_upper()


## Live contacts for the map, expressed as plain data so the map never reaches
## into the hunt loop for them.
func _map_contacts() -> Array:
	var contacts: Array = []
	# Accepted work is a place-bound objective first and a set of spawned nodes
	# second. One contract marker sits at its saved coordinate, while the people
	# involved remain ordinary moving contacts around it.
	for job: Dictionary in ASHBLOOM_HOLDINGS.active_work():
		var target: Dictionary = job.get("target", {}) if job.get("target", {}) is Dictionary else {}
		contacts.append({
			"at": Vector2(float(target.get("x", 0.0)), float(target.get("z", 0.0))),
			"state": "work_%s" % str(job.get("work_type", "job")),
			"name": "RAID ORDER" if str(job.get("work_type", "")) == "raid" else "RECOVERY ORDER",
			"job_id": str(job.id),
		})
	for actor in encounter_actors:
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(actor.get("dead", false)):
			continue
		var state := str(actor.get("disposition", "hostile"))
		if actor.get("anatomy") != null and bool(actor.anatomy.downed):
			state = "downed"
		contacts.append({"at": Vector2(node.global_position.x, node.global_position.z), "state": state, "name": str(actor.get("display_name", ""))})
	for cache in loose_loot:
		if is_instance_valid(cache):
			if not str(cache.get_meta("holding_work_job", "")).is_empty():
				continue
			contacts.append({"at": Vector2(cache.global_position.x, cache.global_position.z), "state": "loot", "name": ""})
	if enemy != null and is_instance_valid(enemy) and enemy.visible and not enemy_retreating:
		contacts.append({"at": Vector2(enemy.global_position.x, enemy.global_position.z), "state": "hostile", "name": _captain_name()})
	return contacts


## Lock-on. The Souls verb the third person was missing: combat could only be
## aimed with the free camera, so a swing at someone circling you was guesswork.
## Locked, the camera holds the pair, the body faces the target and the strike
## resolves against them rather than against whoever happens to be nearest.
func _lock_node() -> Node3D:
	if lock_target.is_empty():
		return null
	var actor := _actor_by_id(lock_target)
	if not actor.is_empty():
		var node := actor.node as Node3D
		if is_instance_valid(node) and not bool(actor.get("dead", false)):
			return node
	if lock_target == CAST.id_for(CAPTAIN_SLOT) and enemy != null and is_instance_valid(enemy) and enemy.visible and not enemy_retreating:
		return enemy
	lock_target = ""
	return null


func _lock_candidates() -> Array:
	var found: Array = []
	for actor in encounter_actors:
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(actor.get("dead", false)):
			continue
		var gap: float = player.distance_to(node.global_position)
		if gap <= 26.0:
			found.append({"id": str(actor.subject_id), "node": node, "gap": gap})
	if enemy != null and is_instance_valid(enemy) and enemy.visible and not enemy_retreating:
		var mara_gap: float = player.distance_to(enemy.global_position)
		if mara_gap <= 26.0:
			found.append({"id": CAST.id_for(CAPTAIN_SLOT), "node": enemy, "gap": mara_gap})
	found.sort_custom(func(a, b): return float(a.gap) < float(b.gap))
	return found


func _toggle_lock() -> void:
	if not lock_target.is_empty():
		lock_target = ""
		prompt.text = "LOCK RELEASED"
		return
	var candidates := _lock_candidates()
	if candidates.is_empty():
		prompt.text = "NOTHING TO LOCK"
		return
	# Prefer what the player is already looking at; fall back to the nearest.
	var forward := Vector3(sin(yaw), 0, cos(yaw)).normalized()
	var best: Dictionary = candidates[0]
	var best_score := -2.0
	for candidate in candidates:
		var toward: Vector3 = (candidate.node.global_position - player)
		toward.y = 0.0
		var score: float = forward.dot(toward.normalized()) - float(candidate.gap) * 0.012
		if score > best_score:
			best_score = score
			best = candidate
	lock_target = str(best.id)
	prompt.text = "LOCKED / %s" % lock_target.to_upper().replace("_", " ")


func _cycle_lock(direction: int) -> void:
	var candidates := _lock_candidates()
	if candidates.size() < 2:
		return
	var index := 0
	for position in candidates.size():
		if str(candidates[position].id) == lock_target:
			index = position
			break
	lock_target = str(candidates[(index + direction + candidates.size()) % candidates.size()].id)


## Locked, the camera is steered rather than mouse-driven, which is what makes
## circling a target readable. Mouse input still nudges it so it never feels
## taken away from the player.
func _steer_lock(delta: float) -> void:
	var node := _lock_node()
	lock_screen = Vector2(-1, -1)
	if node == null:
		return
	if player.distance_to(node.global_position) > 30.0:
		lock_target = ""
		prompt.text = "LOCK LOST"
		return
	var toward := node.global_position - player
	var desired_yaw := atan2(toward.x, toward.z)
	var flat := Vector2(toward.x, toward.z).length()
	var desired_pitch := clampf(-atan2(toward.y + 0.6, maxf(flat, 0.5)) - 0.06, -0.75, 0.42)
	yaw = lerp_angle(yaw, desired_yaw, clampf(delta * 7.0, 0.0, 1.0))
	pitch = lerpf(pitch, desired_pitch, clampf(delta * 5.0, 0.0, 1.0))
	if camera != null and not camera.is_position_behind(node.global_position + Vector3.UP * 1.1):
		lock_screen = camera.unproject_position(node.global_position + Vector3.UP * 1.1)


## The clinch. Half Sword's register is bodies actually colliding, and this
## combat had no equivalent: everything resolved at sword range or not at all,
## so two people standing on top of each other just swung through one another.
##
## A grapple is a stamina contest at contact range. It costs a lot, it can be
## lost, and winning it puts the other person in the downed window rather than
## killing them — which makes it the unarmed route into the execute / spare /
## recruit decision the game is built around.
const GRAPPLE_RANGE := 2.5
const GRAPPLE_DRAIN := 22.0


func _grapple_candidate() -> Dictionary:
	var forward := Vector3(sin(yaw), 0, cos(yaw)).normalized()
	for actor in encounter_actors:
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(actor.get("dead", false)):
			continue
		if actor.anatomy.downed or str(actor.get("disposition", "hostile")) != "hostile":
			continue
		var toward := node.global_position - player
		toward.y = 0.0
		if toward.length() > GRAPPLE_RANGE:
			continue
		if forward.dot(toward.normalized()) < 0.25:
			continue
		return actor
	return {}


func _start_grapple() -> void:
	if not grapple_target.is_empty() or resolution_ui.visible or kill_cam.active:
		return
	if player_rig.is_downed() or player_rig.anatomy.dead or stamina < 20.0:
		prompt.text = "NOT ENOUGH LEFT IN YOU TO TAKE HOLD"
		return
	var actor := _grapple_candidate()
	if actor.is_empty():
		prompt.text = "NOTHING IN REACH TO GRAB"
		return
	grapple_target = str(actor.subject_id)
	grapple_advantage = 0.0
	grapple_clock = 0.0
	grapple_pressure_clock = 0.0
	grapple_zone = _worst_limb(actor.anatomy as AnatomyComponent)
	# B6.1/B6.2. Which of *your* arms is doing the holding. A limb with
	# grappling hardware in it takes the hold if you have one — that is the
	# hardware doing something rather than sitting in the limb being drawn —
	# and otherwise it is the right arm, the same default the rest of this
	# file assumes. Recorded because B6.2 needs to know which limb to miss
	# when it comes off.
	var capable: Array[String] = player_rig.capable_limbs("grapple")
	grapple_with = capable[0] if not capable.is_empty() else "right_arm"
	strike_windup = -1.0
	PLAYER_ACTION_LEDGER.record("grapple_started", {"subject_id": grapple_target, "zone": grapple_zone, "location": HUNT_LOCATION})


## O3.3. Whichever limb is worst off right now, out of the four you could
## plausibly grab somebody by. Ties resolve arm before leg, left before
## right — an arbitrary but stable order, so the same body picks the same
## limb twice rather than flickering between equally-hurt ones.
func _worst_limb(anatomy: AnatomyComponent) -> String:
	var worst := "right_arm"
	var worst_ratio := 2.0
	for zone_id in ["right_arm", "left_arm", "right_leg", "left_leg"]:
		var ratio := _zone_health_ratio(anatomy, zone_id)
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst = zone_id
	return worst


## What fraction of max health one specific zone has left. Used both to pick
## which limb a fresh grapple grabs (`_worst_limb`) and to weigh how much that
## grip is worth once the hold is already running.
func _zone_health_ratio(anatomy: AnatomyComponent, zone_id: String) -> float:
	if anatomy == null or not AnatomyComponent.DEFAULT_ZONES.has(zone_id):
		return 1.0
	var max_health := float((AnatomyComponent.DEFAULT_ZONES[zone_id] as Dictionary).health)
	return clampf(float((anatomy.zones.get(zone_id, {}) as Dictionary).get("health", max_health)) / maxf(1.0, max_health), 0.0, 1.0)


## O5.4. Somebody held in front of you is in the way of whatever is coming at
## you, which is the whole reason to hold a person rather than hit them. Returns
## what is left of the damage after their body took it, and puts the wound on
## them properly — this is not a damage reduction, it is somebody else being
## shot.
##
## Deliberately indiscriminate: it does not check whether the shooter is an ally
## or whether the player meant it. If you are holding a person and a bullet
## arrives, it hits the person.
func grapple_shield(damage: float, from: Vector3) -> Dictionary:
	if grapple_target.is_empty():
		return {"damage": damage, "shielded": false}
	var actor := _actor_by_id(grapple_target)
	if actor.is_empty() or actor.anatomy == null:
		return {"damage": damage, "shielded": false}
	var node := actor.node as Node3D
	if node == null or not is_instance_valid(node):
		return {"damage": damage, "shielded": false}
	# Only if they are actually between you and it. Holding somebody behind you
	# shields nothing.
	var toward_threat := (from - player)
	toward_threat.y = 0.0
	var toward_body := (node.global_position - player)
	toward_body.y = 0.0
	if toward_threat.length() < 0.01 or toward_body.length() < 0.01:
		return {"damage": damage, "shielded": false}
	if toward_threat.normalized().dot(toward_body.normalized()) < 0.35:
		return {"damage": damage, "shielded": false}
	var rig := actor.get("rig") as BaselineHuman
	if rig != null and is_instance_valid(rig):
		var hit: Dictionary = rig.hit_at(node.global_position + Vector3.UP * 0.9, damage, 0.0, "ballistic", (node.global_position - from).normalized())
		rig.favour_injuries()
		if bool(hit.get("severed", false)):
			impact_feel.strike(1.0, "cut", true)
		else:
			impact_feel.strike(clampf(damage / 60.0, 0.1, 1.0), "ballistic", false)
	else:
		actor.anatomy.apply_hit("torso", damage, 0.0, "ballistic")
	WorldHistory.record_event("human_shield", {"subject": grapple_target, "damage": roundi(damage), "location": HUNT_LOCATION})
	prompt.text = "%s TOOK IT FOR YOU" % str(actor.display_name).to_upper()
	# A little still gets through — a body is cover, not a wall.
	return {"damage": damage * 0.18, "shielded": true}


func _break_grapple(message := "") -> void:
	grapple_target = ""
	grapple_advantage = 0.0
	grapple_pushing_now = false
	if not message.is_empty():
		prompt.text = message


## Advantage runs from -1 to 1. The player pushes by holding the strike button;
## the opponent pushes back with whatever their arms and their pain leave them.
func _update_grapple(delta: float) -> void:
	var actor := _actor_by_id(grapple_target)
	if actor.is_empty() or bool(actor.get("dead", false)) or actor.anatomy.downed:
		_break_grapple()
		return
	# B6.2. A grappling limb that is severed stops grappling. Checked here
	# rather than only off `limb_severed` so it is true of the state itself —
	# however the arm came off, and whoever took it, the hold is over on the
	# next tick rather than only when a signal happened to be connected.
	if player_rig != null and is_instance_valid(player_rig) and player_rig.severed.has(grapple_with):
		_break_grapple("THE ARM HOLDING THEM IS GONE")
		return
	var node := actor.node as Node3D
	var gap := player.distance_to(node.global_position)
	if gap > GRAPPLE_RANGE + 1.2:
		_break_grapple("THEY TORE FREE")
		return
	grapple_clock += delta

	# Locked together: both bodies hold position and face each other, which is
	# what makes a clinch read as a clinch rather than two people overlapping.
	var toward := node.global_position - player
	toward.y = 0.0
	if toward.length() > 0.01:
		yaw = atan2(toward.x, toward.z)
	# O5.4. You can walk while holding somebody, and they come with you. Slowly,
	# and more slowly the worse you are winning — dragging a person who is still
	# fighting you is most of the work. This is what turns the clinch from a
	# conversation into a position you can move.
	var drag := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var drag_speed := lerpf(0.9, 2.4, clampf(grapple_advantage * 0.5 + 0.5, 0.0, 1.0))
	if drag.length() > 0.05 and stamina > 0.0:
		var flat_forward := Vector3(sin(yaw), 0, cos(yaw))
		# Same inversion as `HunterMotor.wish_direction` had, and the same fix:
		# dragging somebody with A and D went the wrong way for the same reason
		# walking with them did.
		var flat_right := Vector3(-flat_forward.z, 0, flat_forward.x)
		var shove := (flat_right * drag.x + flat_forward * -drag.y).normalized() * drag_speed
		player_body.velocity = shove
		# They are dragged in front of you rather than pulled through you: the
		# hold keeps its own spacing, which is what stops the two bodies from
		# occupying the same metre.
		var offset := (node.global_position - player).normalized() * 1.15
		(node as CharacterBody3D).velocity = shove + (player + offset - node.global_position) * 4.0
		stamina = maxf(0.0, stamina - GRAPPLE_DRAIN * 0.25 * delta)
	else:
		player_body.velocity = Vector3.ZERO
		(node as CharacterBody3D).velocity = Vector3.ZERO
	actor.attack_time = 0.0

	# A real Input press cannot be raised headless, and this is the one clinch
	# input read as a raw button rather than an action, so tests need a way in
	# that does not depend on a display server existing.
	var pushing: bool = grapple_pushing_override if grapple_pushing_override != null else (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_C))
	grapple_pushing_now = pushing
	var player_force: float = player_rig.anatomy.combat_ratio() * (1.35 if pushing else 0.3)
	# O3.3. combat_ratio() already softens their resistance for arm damage in
	# general; this softens it further, specifically, for the one limb you
	# actually have hold of. Grabbing somebody by the arm you already broke is
	# not the same as grabbing them by the one that is fine.
	var grip_zone_ratio := _zone_health_ratio(actor.anatomy as AnatomyComponent, grapple_zone)
	var their_force: float = float(actor.anatomy.combat_ratio()) * (1.0 - float(actor.anatomy.pain) * 0.006) * lerpf(0.5, 1.0, grip_zone_ratio)
	grapple_advantage = clampf(grapple_advantage + (player_force - their_force) * delta * 0.85, -1.0, 1.0)
	stamina = maxf(0.0, stamina - (GRAPPLE_DRAIN if pushing else GRAPPLE_DRAIN * 0.35) * delta)
	if stamina <= 0.0:
		grapple_advantage -= delta * 0.9

	# O3.3. Pressing the hold leans on the limb you actually grabbed — a real
	# cost that lands on the same rig everything else damages, not a number
	# only the clinch itself ever sees.
	if pushing:
		grapple_pressure_clock += delta
		if grapple_pressure_clock >= GRAPPLE_PRESSURE_INTERVAL:
			grapple_pressure_clock = 0.0
			actor.rig.hit(grapple_zone, 3.0, 2.0, "blunt")

	# F7.1. The hold is a negotiation you are winning, so it reports what it is
	# currently worth rather than only how hard you are squeezing.
	var offer := _clinch_options(actor)
	var grip_note := " BY THE %s" % grapple_zone.replace("_", " ").to_upper() if grip_zone_ratio < 0.6 else ""
	var buy_report := "  [B] BUY REPORT" if witness_ledger.reports_carried_by(str(actor.subject_id)) > 0 else ""
	prompt.text = "CLINCH / %s%s   %+d   [LMB] PRESS  [WASD] WALK THEM  [V] TALK  [X] LEAN%s  [H] TAKE  [SPACE] BREAK" % [
		str(actor.display_name).to_upper(), grip_note, roundi(grapple_advantage * 100.0), buy_report,
	]
	if bool(offer.surrender):
		prompt.text = "%s IS GIVING UP — [V] TAKE THE SURRENDER" % str(actor.display_name).to_upper()

	if grapple_advantage >= 1.0:
		_finish_grapple(actor)
	elif grapple_advantage <= -1.0:
		# Losing a clinch is not merely failing to win one.
		health = maxi(1, health - 11)
		_wound_player(node.global_position, 16.0, "blunt")
		player_body.velocity = (player - node.global_position).normalized() * 7.0
		lose_footing(FOOTING_SHOVED, "")
		_break_grapple("THEY PUT YOU DOWN AND STEPPED BACK")


## C3.1. Raise the camera and take the picture. What gets stored is not an
## image — it is what was actually in shot and what state those bodies were
## actually in, which is what makes it evidence a ritual can be held to.
## Agent 1 brief. Builds the graded look once, off whatever the real
## WorldEnvironment currently is, rather than a hardcoded resource that could
## drift from `world_look.gd`'s own ashbloom preset or disagree with the hour
## AS2 has already set. Cached rather than rebuilt every toggle — the
## adjustment values are the point, not the sky/fog underneath them, which is
## why this duplicates once and only ever edits its own copy from then on.
func _black_mirror_environment() -> Environment:
	if _black_mirror_env == null:
		var base: Environment = $WorldEnvironment.environment
		_black_mirror_env = base.duplicate() if base != null else Environment.new()
		_black_mirror_env.adjustment_enabled = true
		_black_mirror_env.adjustment_saturation = 0.15
	return _black_mirror_env


## Agent 1 brief. "The Black Mirror camera should become the meaningful
## navigation tool in extreme darkness." A camera's own `environment`
## overrides the scene's `WorldEnvironment` for exactly that camera, so this
## touches nothing the naked eye sees — `sun`, ambient, fog and every other
## real light in `_update_day_night()` are exactly as dark as AS2 already
## made them, on and off. What changes is only the amplification applied to
## whatever light already reached the lens: real night vision brightens what
## little is there rather than adding light that was never there, and that
## distinction is the whole point being asked for. Scaled by how dark it
## actually is (`1.0 - daylight`) so the lens does something worth reaching
## for at night and reads as barely more than a tint at noon, rather than one
## fixed amplification regardless of the hour.
func _toggle_black_mirror() -> void:
	black_mirror_active = not black_mirror_active
	if not black_mirror_active:
		camera.environment = null
		return
	var graded := _black_mirror_environment()
	var darkness := 1.0 - WorldClock.daylight()
	graded.adjustment_brightness = lerpf(1.05, 3.4, darkness)
	camera.environment = graded


func _take_photograph() -> Dictionary:
	if not panel_mode.is_empty() or resolution_ui.visible:
		return {}
	var photo := FieldCamera.capture(camera, _all_rigs(), HUNT_LOCATION)
	# One shutter press may also satisfy a ritual. Album storage, the identified
	# player act and that consequence must survive together or not at all.
	WorldHistory.begin_ledger_batch()
	FieldCamera.store(photo, true)
	# E3.3. A rite is satisfied by doing the thing and recording it. The photo is
	# submitted as it is taken; there is no separate acceptance screen or button
	# that could make the evidence into a menu chore.
	var ritual_result := RITUAL_LEDGER.submit_photo(photo)
	WorldHistory.commit_ledger_batch()
	var completed: Array = ritual_result.get("completed", []) as Array
	var count: int = (photo.contents as Array).size()
	if not completed.is_empty():
		var ritual: Dictionary = completed[0]
		prompt.text = "RITE FILED / %s" % str(ritual.get("label", "EVIDENCE ACCEPTED"))
	else:
		prompt.text = "PHOTOGRAPH / %s" % (str(photo.caption) if count > 0 else "NOTHING IN FRAME")
	return photo


## Every body in the world that owns a rig, including the corpses the AI has
## stopped tracking — being able to look into what is left of somebody is most
## of the point.
func _all_rigs() -> Array:
	var rigs: Array = []
	for actor in encounter_actors:
		if actor.get("rig") != null and is_instance_valid(actor.rig):
			rigs.append(actor.rig)
	for body in dead_bodies:
		if body.get("rig") != null and is_instance_valid(body.rig):
			rigs.append(body.rig)
	if enemy_rig != null and is_instance_valid(enemy_rig):
		rigs.append(enemy_rig)
	if friend_rig != null and is_instance_valid(friend_rig):
		rigs.append(friend_rig)
	return rigs


## B3.3, B3.4 and B3.6 in one place: the sweep, the range, and the point at
## which holding the button stops being an X-ray and becomes the wheel.
func _update_xray(delta: float, holding: bool) -> void:
	if holding and panel_mode.is_empty() and not resolution_ui.visible:
		xray_held += delta
		if not xray_active:
			xray_active = true
			WorldHistory.record_event("xray_swept", {"location": HUNT_LOCATION})
		var lit := WorldXray.sweep(player, _all_rigs(), true)
		# The second half of the same playtest bug: with B still held, the moment
		# the wheel closed this reopened it, so the world slowed, fired, sped up
		# and slowed again in a loop. One wheel per hold — the key has to come
		# up before another one opens.
		if xray_held >= XRAY_HOLD_TO_WHEEL and not handheld.radial.is_open and not wheel_spent:
			wheel_spent = true
			# B3.6. This is where B3 becomes C2 — the empty seats on the cursor
			# ring were always the rest of this wheel.
			handheld.open_radial()
		if not lit.is_empty():
			prompt.text = "XRAY / %d BODIES IN REACH" % lit.size()
		return
	if xray_active:
		xray_active = false
		xray_held = 0.0
		wheel_spent = false
		WorldXray.sweep(player, _all_rigs(), false)
		if handheld.radial.is_open:
			handheld.close_radial()


## What the current hold affords, asked in one place so the prompt, the input
## handler and the tests all read the same answer.
func _clinch_options(actor: Dictionary) -> Dictionary:
	return Clinch.options(
		grapple_advantage,
		actor.anatomy.call("snapshot"),
		WorldHistory.subject(str(actor.subject_id)),
		float(WorldHistory.subject("player").get("karma", 0.0)),
	)


## F7.2, talking. A player the world trusts can get something given to them;
## one it fears cannot, and has to lean instead.
func _clinch_persuade() -> void:
	var actor := _actor_by_id(grapple_target)
	if actor.is_empty():
		return
	var subject := WorldHistory.subject(str(actor.subject_id))
	var result := Clinch.persuade(subject, grapple_advantage, actor.anatomy.call("snapshot"), float(WorldHistory.subject("player").get("karma", 0.0)))
	_apply_clinch_result(actor, result, "persuaded")


## F7.2, leaning on them. Reliable where persuasion is not, and it buys what it
## gets with a grudge that outlives the hold.
func _clinch_threaten() -> void:
	var actor := _actor_by_id(grapple_target)
	if actor.is_empty():
		return
	var subject := WorldHistory.subject(str(actor.subject_id))
	var result := Clinch.threaten(subject, grapple_advantage, actor.anatomy.call("snapshot"), float(WorldHistory.subject("player").get("karma", 0.0)))
	_apply_clinch_result(actor, result, "threatened")


## AE10.10. Buying a witness is a physical exchange with the exact person
## carrying the report, not a police-menu option. B is otherwise the smoking
## grip key; the clinch owns it while a body is actually in your hands.
func _buy_witness_report() -> void:
	var actor := _actor_by_id(grapple_target)
	if actor.is_empty():
		return
	var result := witness_ledger.buy(str(actor.subject_id), "player")
	if not bool(result.get("ok", false)):
		prompt.text = str(result.get("reason", "THEY WILL NOT TAKE IT"))
		return
	prompt.text = "%s TAKES %d RUST SCRIP // %d REPORT%s BURIED" % [
		str(actor.display_name).to_upper(), int(result.price), int(result.reports),
		"" if int(result.reports) == 1 else "S",
	]


## One place where a clinch outcome is written into the record, so persuading
## and threatening cannot drift apart in what they mean.
func _apply_clinch_result(actor: Dictionary, result: Dictionary, verb: String) -> void:
	var id := str(actor.subject_id)
	var subject := WorldHistory.subject(id)
	var changes := {}
	if int(result.get("grudge", 0)) != 0:
		changes["grudge"] = mini(100, int(subject.get("grudge", 0)) + int(result.get("grudge", 0)))
	if int(result.get("bond", 0)) != 0:
		changes["bond"] = mini(100, int(subject.get("bond", 0)) + int(result.get("bond", 0)))
	if float(result.get("debt", 0.0)) > 0.0:
		changes["debt_to_player"] = float(subject.get("debt_to_player", 0.0)) + float(result.debt)
	if bool(result.get("consent", false)):
		# F7.3. This is the seam into the downed window: `_accepts_recruitment`
		# already reads consent and debt, and had no way of ever being given
		# either. Talking somebody down in a clinch is that way.
		changes["recruitment_consent"] = true
	if bool(result.get("accepted", false)):
		changes["memory"] = "The Hunter had hold of me and %s me into it." % verb
	WorldHistory.begin_ledger_batch()
	if not changes.is_empty():
		WorldHistory.amend_subject(id, changes)
	PLAYER_ACTION_LEDGER.record("clinch_%s" % verb, {
		"subject_id": id,
		"accepted": bool(result.get("accepted", false)),
		"advantage": snappedf(grapple_advantage, 0.01),
		"location": HUNT_LOCATION,
		"witnesses": witness_ledger.witnesses_of((actor.node as Node3D).global_position, _witness_candidates(), "player"),
	})
	var line := str(result.get("line", ""))
	prompt.text = "%s: \"%s\"" % [str(actor.display_name).to_upper(), line] if line != "" else str(result.get("reason", ""))
	# Giving up is not being knocked out: they go into the downed window awake,
	# having decided, which is the state the resolution form was built for.
	if bool(result.get("accepted", false)) and (bool(result.get("consent", false)) or bool(result.get("yields", false))):
		if not actor.anatomy.downed and not actor.anatomy.dead:
			actor.anatomy.go_down()
		WorldHistory.amend_subject(id, {"status": "surrendered", "anatomy_state": actor.rig.snapshot()})
		_break_grapple("%s GIVES UP — [E] DECIDE" % str(actor.display_name).to_upper())
	WorldHistory.commit_ledger_batch()


## Winning drops them into the downed window rather than killing them. The
## takedown itself is blunt trauma to the head and torso, so the body carries a
## record of how it was beaten and the resolution form shows it.
##
## The guard is a body-state read rather than a call count: a body that is
## already down or already dead must not be sent down a second time, because
## that would overwrite the closed state the resolution form is showing with a
## fresh one and lose what actually happened to them.
func _finish_grapple(actor: Dictionary) -> void:
	WorldHistory.begin_ledger_batch()
	var rig := actor.rig as BaselineHuman
	rig.hit("head", 26.0, 18.0, "blunt")
	rig.hit("torso", 30.0, 20.0, "blunt")
	var body_state = actor["anatomy"]
	if body_state != null and not bool(body_state.get("downed")) and not bool(body_state.get("dead")):
		body_state.call("go_down")
	PLAYER_ACTION_LEDGER.record("grapple_takedown", {"subject_id": str(actor.subject_id), "location": HUNT_LOCATION})
	WorldHistory.amend_subject(str(actor.subject_id), {"anatomy_state": rig.snapshot()})
	WorldHistory.commit_ledger_batch()
	_break_grapple("%s IS ON THE GROUND — [E] DECIDE" % str(actor.display_name).to_upper())
	attack_cooldown = 0.5


## Whether the player has earned the outside view. Two conditions, both of them
## things they did rather than flags somebody set: a melee weapon in hand, and a
## named rival put down. The Hunt System supplies the second — a boss here means
## somebody the world had already decided was dangerous.
func third_person_unlocked() -> bool:
	if WorldHistory.event_count("melee_body_hit") <= 0:
		return false
	# A boss is a rival the world already knew by name when you put them down.
	# Was reading a `"subject"` key. Every `npc_resolution` this file records
	# (the only two writers, both in `_resolve_downed`) writes `"subject_id"`,
	# so this loop always found an empty string and never counted a single
	# kill — third person could not unlock no matter what you did, and M1.2
	# was checked off on the strength of the refusal message, not the unlock.
	var bosses := 0
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) not in ["npc_resolution", "execution"]:
			continue
		var subject := str((event.get("details", {}) as Dictionary).get("subject_id", ""))
		if subject == "":
			continue
		var record: Dictionary = WorldHistory.subject(subject)
		if int(record.get("elo", 0)) >= 1100 or int(record.get("grudge", 0)) >= 30 or bool(record.get("rival", false)):
			bosses += 1
	return bosses >= UNLOCK_BOSSES


## AD1.3. "Earned the way third person is earned rather than given" — the
## same shape as `third_person_unlocked()` just above, a real thing the
## player did rather than a flag, counted straight off `player_vaulted`
## (AD1.2's own event) since wall-running is the next rung of the same
## traversal skill vaulting is, not a combat unlock like third person's own.
func wall_run_unlocked() -> bool:
	return WorldHistory.event_count("player_vaulted") >= WALL_RUN_UNLOCK_VAULTS


## M1.5's pattern, not its wording: the moment the count crosses, not the
## moment a key is pressed, because a passive movement skill has no key to
## press early against — the body simply starts trusting the wall the
## instant it has earned the right to.
func _announce_wall_run_unlock() -> void:
	prompt.text = "YOUR BODY TRUSTS THE WALL NOW. RUN AT ONE."
	if impact_feel != null:
		impact_feel.kick += Vector2(0, -1.0) * 0.05
		impact_feel.shake = maxf(impact_feel.shake, 0.5)
	WorldHistory.record_event("wall_run_unlocked", {"location": HUNT_LOCATION})


## M1.5. The unlock has to land as something that happened to the player, not
## a silent permission flip they only discover by trying the key. The moment
## the two conditions are both true — regardless of whether `F` is pressed
## yet — the world marks it the same way it marks a killing blow: a stop, a
## kick, and a line of content. `third_person_unlock_felt` is recorded once
## and only once, so replaying this scene, or the check re-running every
## second, can never trigger the feeling twice.
func _check_third_person_unlock_feel() -> void:
	if WorldHistory.event_count("third_person_unlock_felt") > 0:
		return
	if not third_person_unlocked():
		return
	WorldHistory.record_event("third_person_unlock_felt", {"location": HUNT_LOCATION})
	if impact_feel != null:
		impact_feel.strike(0.85, "unlock", false)
	prompt.text = "SOMETHING IN YOU STEPS BACK, LOOKING — [F] TO LEAVE YOUR BODY"


## What the player is told when they press the key too early. Never a silent
## refusal: a control that does nothing reads as a bug, and this one is content.
func third_person_refusal() -> String:
	if WorldHistory.event_count("melee_body_hit") <= 0:
		return "YOU HAVE NOT PUT ANYTHING IN REACH YET. SWING AT SOMEBODY FIRST."
	return "NOTHING HAS LOOKED BACK AT YOU YET. PUT DOWN SOMEONE WHO MATTERS."


## M1.5. Called the one frame the unlock condition first reads true. The prompt
## line is the same voice as the refusal it replaces, the camera gets the kind
## of jolt a real hit gets (through `impact_feel`, not a fresh effect system),
## and the moment is written to history so the Board can pin it like anything
## else that happened to the player, rather than it living only in a flag.
func _announce_third_person_unlock() -> void:
	prompt.text = "SOMETHING IN YOU STEPS BACK. [F] LEAVES YOUR OWN EYES NOW."
	if impact_feel != null:
		impact_feel.kick += Vector2(0, -1.0) * 0.05
		impact_feel.shake = maxf(impact_feel.shake, 0.6)
	WorldHistory.record_event("third_person_unlocked", {"location": HUNT_LOCATION})


## AG2. The card's contents, written here rather than inside the card, because
## this scene is the only thing that knows what this scene binds. A card that
## held its own table would go stale the first time a key moved and nobody would
## find out until a playtester could not find the Board again.
##
## Grouped by what the player is trying to do, not by keyboard row. The Board is
## in here by name because AG2.1 is specifically that nobody — including Greg —
## could remember it existed, and holding B is in here because AG2.2 is
## specifically that the wheel teaches itself to nobody.
func _build_keys_card() -> void:
	keys_card.configure("F1", [
		{"group": "MOVING", "rows": [
			["WASD", "MOVE"],
			["SHIFT", "SPRINT"],
			["CTRL", "CROUCH"],
			["SPACE", "JUMP / VAULT / DODGE"],
			["F", "FIRST / THIRD PERSON"],
		]},
		{"group": "FIGHTING", "rows": [
			["LMB", "ATTACK"],
			["RMB", "HEAVY"],
			["HOLD X", "GUARD"],
			["Z", "LOCK ON"],
			["WHEEL", "CYCLE TARGET"],
			["1 2 3", "SWORD / SHOTGUN / PISTOL"],
			["4", "CARRIED LIMB"],
			["5", "PUT THEM DOWN"],
			["B", "CYCLE GRIP"],
			["R", "RELOAD"],
			["Q", "PROSTHETIC SURGE // COSTS STAMINA"],
			["HOLD Q", "X-RAY, THEN THE WHEEL"],
		]},
		{"group": "HANDS ON", "rows": [
			["E", "INTERACT"],
			["HOLD I", "INSPECT HELD OBJECT"],
			["C", "GRAPPLE"],
			["HOLD V", "LUNG RELIQUARY / CLINCH: PERSUADE"],
			["X", "THREATEN"],
			["H", "EXTRACTION"],
			["N", "PHOTOGRAPH"],
			["6", "CYCLE SMOKEABLE"],
			["Y", "HAND / LIP-HOLD SMOKEABLE"],
			["HOLD RMB", "DRAW / RELEASE TO EXHALE"],
			["LMB EXHALE", "O / DOUBLE O / GHOST"],
		]},
		{"group": "WHAT YOU CARRY", "rows": [
			["G", "THE DEVICE"],
			["TAB", "WORLD INDEX"],
			["M", "LIVING MAP"],
			["T", "CHARACTER TREE"],
			["P", "THE BOARD"],
			["J", "ALLUSIONS / SIGIL"],
			["HOLD L + WASD", "LEAN / WAVE DEVICE LIGHT"],
			[HANDHELD.DROP_KEY_LABEL, "DROP DEVICE"],
			["K", "RE-DECANT // A RESET THAT COSTS YOU"],
			["ESC", "CLOSE"],
		]},
	])


## Which of the HUD's children are lens and which are interface.
##
## The derby's index is clean and the hunt's was not, which is the whole of
## "the menus are broken once you get out of the car": this scene is the only
## one that owns a blood veil and a psychedelic rig, and both were added to
## `$HUD` *after* the index, the map, the board and the archive. A CanvasLayer
## draws its children in tree order, so both were painting over every panel the
## player opened. The trip is worse than the veil, because the shader samples
## `hint_screen_texture` — everything drawn earlier in the frame — so an open
## index was not merely tinted, it was displaced, and the page tabs ended up
## somewhere other than where they are actually clickable.
##
## Neither effect is wrong to exist; both were simply in the wrong half of the
## stack. Blood is on the lens and the warp is in the air, so both belong
## between the player and the *world*. A panel is held in the hand, in front of
## both. Ordering it here, once, rather than by moving the `add_child` calls
## around, because the construction order above is grouped by what each thing
## needs from what came before it, and that is a separate concern from what
## ends up in front of what.
func _order_hud_layers() -> void:
	# Everything above the world and below the interface, in this order.
	var lens: Array = [field_lens, blood_veil, psychedelic]
	# `ScreenTreatment` is authored as the first child and is world-level too,
	# so the lens stacks directly on top of it rather than at index 0.
	var treatment := $HUD.get_node_or_null("ScreenTreatment")
	var slot: int = (treatment.get_index() + 1) if treatment != null else 0
	for effect in lens:
		if effect == null or not is_instance_valid(effect):
			continue
		$HUD.move_child(effect, slot)
		slot += 1


func _toggle_panel(mode: String) -> void:
	allusions_artwork.close_artwork()
	panel_mode = "" if panel_mode == mode else mode
	character_archive.visible = panel_mode == "tree"
	# The map is a chart now, not a paragraph, so it owns its own surface.
	living_map.visible = panel_mode == "map"
	if living_map.visible:
		# A10. The map looks at the region the player is standing in, so it is
		# handed this scene's world rather than building one of its own.
		living_map.attach_world(get_world_3d())
		living_map.open_map()
	if panel_mode == "index":
		world_index.open()
	elif world_index.visible:
		world_index.close()
	if panel_mode == "board":
		pin_board.open()
	elif pin_board.visible:
		pin_board.close()
	# A full sheet, chart or index; the field labels underneath it are noise.
	#
	# `prompt` alone, because it is the only one of the four left alive. I3
	# retired `title`, `status` and the vitals panel in favour of
	# `gothic_field_hud.gd`, and the scene authors all three as `visible =
	# false` — but this loop turned them back *on* every time a panel closed.
	# `_update_hud` re-hides `status` each frame and says nothing about the
	# other two, so opening the index once and shutting it left the old orange
	# title and the old vitals box stuck over the real interface for the rest
	# of the run. That is the interface "breaking once you get out of the car":
	# nothing breaks on arrival, it breaks the first time you open a panel.
	var covering: bool = living_map.visible or world_index.visible or pin_board.visible
	prompt.visible = not covering
	# The old ArchivePanel is dead. It was a Label in a box and it is exactly
	# what "no more of this tutorial look" was about.
	panel.visible = false
	if character_archive.visible:
		character_archive.open_archive(CAST.id_for(CAPTAIN_SLOT))
	else:
		character_archive.close_archive()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if panel_mode.is_empty() else Input.MOUSE_MODE_HIDDEN
	if _pointer != null and is_instance_valid(_pointer):
		_pointer.visible = not panel_mode.is_empty()


## `J` cycles the Allusions archive: the artwork study, then the natal sigil,
## then closed. The sigil is the chaos-magick half of the same archive — the
## Tree axis the dossier already reads on, drawn as a bound mark.
func _toggle_artwork() -> void:
	if allusions_artwork.visible:
		allusions_artwork.close_artwork()
		natal_sigil.open_chart()
		panel_mode = "artwork"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if natal_sigil.visible:
		natal_sigil.close_chart()
		panel_mode = ""
	else:
		panel.visible = false
		character_archive.close_archive()
		living_map.close_map()
		panel_mode = "artwork"
		allusions_artwork.open_artwork()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if panel_mode.is_empty() else Input.MOUSE_MODE_HIDDEN
	if _pointer != null and is_instance_valid(_pointer):
		_pointer.visible = not panel_mode.is_empty()


func _update_hud() -> void:
	if not third_person_unlock_announced and third_person_unlocked():
		third_person_unlock_announced = true
		_announce_third_person_unlock()
	if not wall_run_unlock_announced and wall_run_unlocked():
		wall_run_unlock_announced = true
		_announce_wall_run_unlock()
	if not climb_unlock_announced and climb_unlocked():
		climb_unlock_announced = true
		_announce_climb_unlock()
	title.text = "WIZARDS ONLY FOOLS // LIMBO: ASHBLOOM EXPANSE"
	# I3. The second control strip is gone. `gothic_field_hud.gd` draws the one
	# the player reads, in the game's own face, and it is contextual — this was
	# a permanent list of every key in the game, in the engine default font,
	# drawn on top of it.
	#
	# All three of the retired nodes are held down here rather than only
	# `status`, so nothing that flips one of them on can leave it on. The
	# panel is what carries the box, not the label inside it, which is why
	# `vitals.get_parent()` is what gets hidden.
	title.visible = false
	status.visible = false
	var vitals_panel := vitals.get_parent() as Control
	if vitals_panel != null:
		vitals_panel.visible = false
	vitals.text = "BODY  %03d%%\nSTAMINA  %03d%%\nPROSTHETIC  TORQUE ARM\nHUNT  %s" % [health, roundi(stamina), str(WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT)).get("status", "dormant")).to_upper()]
	prompt.visible = not resolution_ui.visible and not living_map.visible and not world_index.visible
	_update_held_reliquary()
	if field_interface.has_method("set_state"):
		var blood_ratio := 1.0
		var lung_state := {"health": 1.0, "stain": 0.0}
		var pain := 0.0
		var consciousness := 100.0
		if player_rig != null and is_instance_valid(player_rig):
			blood_ratio = clampf(player_rig.anatomy.blood_remaining / maxf(player_rig.anatomy.blood_capacity, 1.0), 0.0, 1.0)
			lung_state = player_rig.anatomy.lung_state()
			pain = player_rig.anatomy.pain
			consciousness = player_rig.anatomy.consciousness
		var local_map: Texture2D = living_map.update_minimap(get_process_delta_time()) if living_map != null else null
		field_interface.set_state({
			"health": health,
			"blood": blood_ratio,
			"stamina": stamina,
			"pain": pain,
			"consciousness": consciousness,
			"smoking": smoke_drawing or smoke_exhale_delay > 0.0 or smoke_lung_fill > 0.01,
			"lung_inhaling": smoke_drawing,
			"lung_fill": smoke_lung_fill,
			"lung_cough": smoke_cough,
			"lung_health": float(lung_state.get("health", 1.0)),
			"lung_stain": float(lung_state.get("stain", 0.0)),
			"pulmonary_expanded": _pulmonary_diagnostic_active(),
			"magick_unlocked": WorldHistory.event_count("ritual_completed") > 0,
			"magick": WorldHistory.chaos_magick(),
			"world_stamp": "%s // %s" % [WorldClock.calendar_stamp(), WorldClock.stamp()],
			"air": air.severity() if air != null and is_instance_valid(air) else 0.0,
			"minimap_texture": local_map,
			"minimap_heading": yaw,
			"rival_status": WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT)).get("status", "dormant"),
			"rival_name": _captain_name(),
			"menu_open": world_index.visible or character_archive.visible or allusions_artwork.visible or living_map.visible,
			"menu_mode": panel_mode,
			"weapon": arsenal.state() if arsenal != null else {},
			"wound_regions": _interface_wound_regions(),
			"lock_screen": lock_screen,
		})


## I4.3v2/I10.9. Collapse the anatomy's six physical zones into the four
## instruments they can disrupt. This is derived every frame from the body;
## there is no interface-only damage state to drift away from a healed limb.
func _interface_wound_regions() -> Dictionary:
	var result := {"head": 0.0, "torso": 0.0, "arms": 0.0, "legs": 0.0}
	if player_rig == null or not is_instance_valid(player_rig):
		return result
	var zones: Dictionary = player_rig.anatomy.zones
	var loss := func(zone_id: String) -> float:
		var baseline: Dictionary = ANATOMY_COMPONENT.DEFAULT_ZONES.get(zone_id, {"health": 1.0})
		var current: Dictionary = zones.get(zone_id, baseline)
		return 1.0 - clampf(float(current.get("health", 0.0)) / maxf(float(baseline.get("health", 1.0)), 1.0), 0.0, 1.0)
	result.head = loss.call("head")
	result.torso = loss.call("torso")
	result.arms = maxf(loss.call("left_arm"), loss.call("right_arm"))
	result.legs = maxf(loss.call("left_leg"), loss.call("right_leg"))
	return result


## I9. Every presently takeable object in the Hunt enters through the exact
## same I verb and reliquary as held gear. Each owning system still supplies
## identity; this scene only chooses the nearest reachable live object.
func _nearest_world_item_for_inspection() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	if substance_station != null and is_instance_valid(substance_station):
		var station_item: Dictionary = substance_station.inspection_nearest(player)
		var station_source: Node3D = station_item.get("source") as Node3D
		if station_source != null and is_instance_valid(station_source):
			best = station_item
			best_distance = player.distance_to(station_source.global_position)
	if dropped_handheld != null and is_instance_valid(dropped_handheld):
		var device_distance := player.distance_to(dropped_handheld.global_position)
		if device_distance <= 3.2 and device_distance < best_distance:
			best_distance = device_distance
			best = {
				"source": dropped_handheld, "item_id": "black_mirror",
				"kind": "device", "label": "BLACK MIRROR",
				"detail": "%06d // %d%%" % [handheld.serial, roundi(handheld.condition * 100.0)],
			}
	var chunk := _nearest_takeable_chunk(3.2)
	if chunk != null:
		var chunk_distance := player.distance_to(chunk.global_position)
		if chunk_distance < best_distance:
			var info: Dictionary = GoreChunks.identify(chunk)
			var identity := str(info.get("implant", ""))
			if identity.is_empty():
				identity = str(info.get("organ_id", ""))
			if identity.is_empty():
				identity = "%s %s" % [str(info.get("zone", "body")), str(info.get("layer_name", "piece"))]
			best_distance = chunk_distance
			best = {
				"source": chunk, "item_id": "chunk:%s:%s" % [str(info.get("subject_id", "unknown")), identity],
				"kind": "body_part", "label": identity.replace("_", " ").to_upper(),
				"detail": str(info.get("subject_id", "unclaimed")),
			}
	for cache in loose_loot:
		if cache == null or not is_instance_valid(cache):
			continue
		var cache_distance := player.distance_to(cache.global_position)
		if cache_distance <= 3.5 and cache_distance < best_distance:
			var items: Array = cache.get_meta("items", [])
			best_distance = cache_distance
			best = {
				"source": cache, "item_id": "salvage_cache:%d" % cache.get_instance_id(),
				"kind": "cache", "label": "SALVAGE CACHE",
				"detail": "%d ITEMS" % items.size(),
			}
	for actor: Dictionary in encounter_actors:
		var subject_node: Node3D = actor.get("node") as Node3D
		if subject_node == null or not is_instance_valid(subject_node):
			continue
		var subject_distance := player.distance_to(subject_node.global_position)
		if subject_distance <= 3.2 and subject_distance < best_distance:
			var subject_id := str(actor.get("subject_id", actor.get("instance_id", "unknown")))
			var condition := "DEAD" if bool(actor.get("dead", false)) else str(actor.get("state", "STANDING")).to_upper()
			best_distance = subject_distance
			best = {
				"source": subject_node, "item_id": subject_id,
				"kind": "person", "label": str(actor.get("display_name", subject_id)),
				"detail": condition,
			}
	if friend != null and is_instance_valid(friend):
		var friend_distance := player.distance_to(friend.global_position)
		if friend_distance <= 3.2 and friend_distance < best_distance:
			best_distance = friend_distance
			best = {
				"source": friend, "item_id": FRIEND_ID, "kind": "person",
				"label": str(WorldHistory.subject(FRIEND_ID).get("name", "NIX")),
				"detail": str(WorldHistory.subject(FRIEND_ID).get("status", "ALLY")),
			}
	if enemy != null and is_instance_valid(enemy) and enemy.visible:
		var rival_distance := player.distance_to(enemy.global_position)
		if rival_distance <= 3.2 and rival_distance < best_distance:
			best = {
				"source": enemy, "item_id": CAST.id_for(CAPTAIN_SLOT), "kind": "person",
				"label": _captain_name(), "detail": "RETREATING" if enemy_retreating else "HOSTILE",
			}
	if sleep_site != null and is_instance_valid(sleep_site):
		var bedroll_distance := player.distance_to(sleep_site.global_position)
		if bedroll_distance <= SLEEP_REACH and bedroll_distance < best_distance:
			best = {
				"source": sleep_site, "item_id": "hunt_bedroll", "kind": "fixture",
				"label": "BEDROLL", "detail": "REST SITE",
			}
	return best


func _update_held_reliquary() -> void:
	if held_reliquary == null or not is_instance_valid(held_reliquary):
		return
	held_reliquary.set_arm_damage(float(_interface_wound_regions().arms))
	var covered := world_index.visible or character_archive.visible or allusions_artwork.visible or living_map.visible or pin_board.visible
	if covered:
		held_reliquary.clear_item()
		return
	if inspect_held and not inspected_world_item.is_empty():
		var world_source: Node3D = inspected_world_item.get("source") as Node3D
		if world_source != null and is_instance_valid(world_source):
			held_reliquary.show_item(world_source, str(inspected_world_item.get("label", "object")), str(inspected_world_item.get("detail", "ground")))
			return
		inspected_world_item.clear()
	if smoke_model != null and is_instance_valid(smoke_model):
		var smoke_label := str((SMOKEABLES.CATALOG.get(str(smoke_model.get_meta("device_id", "")), {}) as Dictionary).get("label", "smokeable"))
		var smoke_left := roundi((1.0 - SMOKEABLES.spent_of(smoke_model)) * 100.0)
		held_reliquary.show_item(smoke_model, smoke_label, "%d%%" % smoke_left)
		return
	if carried_limb_model != null and is_instance_valid(carried_limb_model) and carried_limb_index >= 0 and carried_limb_index < handheld.carry.items.size():
		var limb: Dictionary = handheld.carry.items[carried_limb_index]
		held_reliquary.show_item(carried_limb_model, str(limb.get("label", "severed limb")), "%d%%" % roundi(float(limb.get("condition", 1.0)) * 100.0))
		return
	if arsenal != null and arsenal.models.has(arsenal.current_id):
		var held_weapon := arsenal.models[arsenal.current_id] as Node3D
		if held_weapon != null and held_weapon.visible:
			var state: Dictionary = arsenal.state()
			var detail := "EDGE" if int(state.get("loaded", -1)) < 0 else "%02d // %02d" % [int(state.get("loaded", 0)), int(state.get("reserve", 0))]
			held_reliquary.show_item(held_weapon, str(state.get("label", arsenal.current_id)), detail)
			return
	held_reliquary.clear_item()


func _update_camera() -> void:
	if resolution_ui != null and resolution_ui.visible:
		# M4.5. Was a bare 72.0 — a third FOV value with no relationship to the
		# 78/63 pair M4.3 stated, so this one external-framing shot would have
		# quietly drifted out of scale the next time either constant was
		# retuned. This view is already the "look at the body from outside"
		# register, so it takes the third-person figure rather than its own.
		camera.fov = THIRD_PERSON_FOV
		var subject := _actor_by_id(resolution_target)
		if not subject.is_empty():
			var subject_focus: Vector3 = subject.node.global_position + Vector3.UP * 0.65
			var away := player - subject_focus
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3.BACK
			away = away.normalized()
			var subject_shoulder := Vector3(-away.z, 0, away.x) * 1.05
			var subject_desired := player + away * 3.1 + subject_shoulder * 0.85 + Vector3.UP * 1.55
			var ray := PhysicsRayQueryParameters3D.create(subject_focus, subject_desired)
			var excluded: Array[RID] = [player_body.get_rid()]
			if subject.node is CollisionObject3D:
				excluded.append((subject.node as CollisionObject3D).get_rid())
			ray.exclude = excluded
			var obstruction := get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstruction.is_empty():
				subject_desired = obstruction.position + (subject_focus - obstruction.position).normalized() * 0.35
			camera.global_position = subject_desired
			camera.look_at(subject_focus, Vector3.UP)
			var player_head := player_rig.parts.get("head") as Node3D
			if player_head != null and is_instance_valid(player_head):
				player_head.visible = false
			return
	var look := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	var physical_offset := Vector3.ZERO
	var fov_add := 0.0
	if body_motion != null:
		var local_offset: Vector3 = body_motion.camera_offset
		var flat_forward := Vector3(sin(yaw), 0, cos(yaw))
		var flat_right := Vector3(flat_forward.z, 0, -flat_forward.x)
		physical_offset = flat_right * local_offset.x + Vector3.UP * local_offset.y + flat_forward * local_offset.z
		fov_add = body_motion.fov_add
	# M1.5/M3.3/Rule 3. Both poses are computed every frame, whichever one is
	# "current" — the camera sits at a lerp between them driven by
	# `perspective_blend` sliding toward whatever `third_person` asked for.
	# This used to be an `if third_person: ... else: ...` that snapped the
	# camera's position and FOV on the same frame the key was pressed, which
	# is exactly the hard cut Rule 3 names as a bug. Wide inside your own
	# head, ordinary outside it — the change between the two is the reward,
	# and a reward you can watch happen reads better than one you only notice
	# has already happened.
	perspective_blend = move_toward(perspective_blend, 1.0 if third_person else 0.0, PERSPECTIVE_BLEND_RATE * get_physics_process_delta_time())
	camera.fov = lerpf(FIRST_PERSON_FOV, THIRD_PERSON_FOV, perspective_blend) + fov_add

	# M4.2. The eye, not the chest. Crouching lowers it by exactly as much as
	# the body actually shortens, so the view and the collider agree.
	var crouch_drop: float = (STANDING_HEIGHT - player_capsule.height) * 0.5
	var fp_position := player + Vector3.UP * (EYE_ABOVE_CENTRE - 0.6 - crouch_drop) + physical_offset
	var fp_target := fp_position + look * 12.0

	# Souls framing rather than a chase cam parked behind the head: the body
	# sits off-centre over one shoulder and low in frame, the rig is close
	# enough to read a swing on, and the whole thing is spring-damped so it
	# trails the player instead of snapping to a computed point each frame.
	var locked := _lock_node()
	var focus := player + Vector3.UP * 0.95
	var shoulder := Vector3(cos(yaw), 0, -sin(yaw)) * 0.62
	var distance := 4.4 if locked != null else 3.8
	if locked != null:
		# Framing holds the pair, so backing off a locked target widens the
		# shot instead of losing them behind the player's own shoulder.
		var gap: float = player.distance_to(locked.global_position)
		distance = clampf(3.6 + gap * 0.22, 3.6, 6.2)
		focus = focus.lerp(locked.global_position + Vector3.UP * 0.9, 0.32)
	var desired := player - look * distance + Vector3.UP * 0.85 + shoulder + physical_offset * 0.35
	if not camera_ready:
		camera_position = desired
		camera_ready = true
	var responsiveness := 15.0 if locked != null else 11.0
	camera_position = camera_position.lerp(desired, clampf(get_physics_process_delta_time() * responsiveness, 0.0, 1.0))
	# The wall test is the last thing that happens, on the position actually
	# used. Testing the *target* and then smoothing toward it let the camera
	# sit inside a building for every frame of the blend, which is how the
	# spawn view ended up as a wall of brown.
	var tp_position := HUNTER_MOTOR.collision_safe_camera(
		get_world_3d().direct_space_state,
		focus,
		camera_position,
		[player_body.get_rid()]
	)
	# Locked, the shot is about the pair, so aim between them. Unlocked, aim
	# parallel to the look heading rather than at the player — aiming *at*
	# the player cancels the shoulder offset and re-centres the body, which
	# is what made this read as a chase cam parked behind the head instead
	# of an over-the-shoulder shot.
	var tp_target := focus if locked != null else tp_position + look * 12.0

	camera.global_position = fp_position.lerp(tp_position, perspective_blend)
	camera.look_at(fp_target.lerp(tp_target, perspective_blend), Vector3.UP)
	if body_motion != null:
		camera.rotation.x -= body_motion.smoking_look_down * (1.0 - perspective_blend)
		camera.rotation.z += body_motion.camera_roll * lerpf(1.0, 0.45, perspective_blend)
		# O2.2. The kick from whatever you just hit, applied here so the derby
		# and the hunt can each carry it in their own rig's terms.
		if impact_feel != null:
			var felt: Vector2 = impact_feel.camera_offset()
			camera.rotation.x += felt.y
			camera.rotation.y += felt.x
			camera.rotation.z += impact_feel.roll
	if player_rig != null and is_instance_valid(player_rig):
		var facing := yaw + PI
		var locked_body := _lock_node()
		if locked_body != null and third_person:
			var toward := locked_body.global_position - player
			facing = atan2(toward.x, toward.z) + PI
		player_rig.rotation.y = lerp_angle(player_rig.rotation.y, facing, clampf(get_physics_process_delta_time() * 12.0, 0.0, 1.0))
		# The first-person camera sits inside the skull, so the head would fill
		# the view. Fading this on the blend instead of the toggle means the
		# head does not pop in or out at the instant nothing has visibly moved
		# yet — it appears once the camera has actually pulled back far enough
		# to have a reason to.
		var head := player_rig.parts.get("head") as Node3D
		if head != null and is_instance_valid(head):
			head.visible = perspective_blend > 0.5


## The pointer, in the project's own hand rather than the operating system's. A
## ring with a bite out of it and a cross in the middle, so it reads on a dark
## plate and over a photograph without a drop shadow.
func _draw_pointer() -> void:
	if _pointer == null or not is_instance_valid(_pointer):
		return
	var at := _pointer.get_local_mouse_position()
	var brass := Color("c8a13a")
	_pointer.draw_arc(at, 9.0, 0.55, TAU - 0.55, 22, brass, 1.6)
	_pointer.draw_arc(at, 9.0, 0.55, TAU - 0.55, 22, Color(0, 0, 0, 0.5), 3.2)
	_pointer.draw_arc(at, 9.0, 0.55, TAU - 0.55, 22, brass, 1.6)
	for axis in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_pointer.draw_line(at + axis * 3.0, at + axis * 6.2, brass, 1.4)
	_pointer.draw_circle(at, 1.6, brass)


func _build_world() -> void:
	# Was a hand-rolled Environment on a near-black background with a flat colour
	# ambient, which rendered the Expanse as an unreadable brown murk — the same
	# fault the menu had. The roadmap already listed this scene as un-migrated.
	$WorldEnvironment.environment = WorldLook.environment("ashbloom")
	# A7.1. The gods sit outside the firmament v6 broke open, so they are bound
	# to the same sky material and driven by the same clock as everything else
	# in A. `camera` is an `@onready`, which resolves before `_ready()` calls
	# this, so it is safe to hand over here.
	# AU3.6. Reachable in the real world rather than from a dev menu: a working
	# table under the wrecks, where a hunt already brings you.
	substance_station = SUBSTANCE_STATION.new()
	substance_station.name = "SubstanceStation"
	substance_station.position = Vector3(-6.4, 0.0, 9.2)
	substance_station.rotation = Vector3(0, deg_to_rad(-24.0), 0)
	add_child(substance_station)
	substance_station.build()

	gods = Gods.new()
	gods.name = "Gods"
	add_child(gods)
	gods.bind($WorldEnvironment.environment.sky.sky_material as ShaderMaterial, camera)
	gods.god_seen.connect(_on_god_seen)
	# A9.1. The air, which for nine passes was empty. Added to the scene rather
	# than to the player so its particles live in world space and the player
	# walks through them instead of towing them.
	air = ContaminatedAir.new()
	add_child(air)
	_add_mesh(BoxMesh.new(), Vector3(0, -0.6, 0), Vector3(470, 1, 370), Color("17150f"), 0.0)
	var floor_body := StaticBody3D.new()
	var floor_collider := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(470, 1, 370)
	floor_collider.shape = floor_shape
	floor_body.position.y = -0.6
	floor_body.add_child(floor_collider)
	add_child(floor_body)
	_build_sleep_site()
	_add_mesh(BoxMesh.new(), Vector3(0, 0, -24), Vector3(13, 5, 1.5), Color("2b2119"), 0.0)
	# G4. This was twenty-six identical bare cubes on a regular nine-column grid,
	# standing exactly where the player spawns — which is the real answer to
	# "everything looks like boxes". The generated districts were dressed and
	# settled while *these* sat in front of the camera being a spreadsheet made
	# of geometry. They are wreck piles now: jittered off the grid, varied in
	# mass, hung with junk and knocked off plumb.
	var wreck_rng := RandomNumberGenerator.new()
	wreck_rng.seed = 55117
	for index in 26:
		var x := -31.0 + float(index % 9) * 7.5 + wreck_rng.randf_range(-3.4, 3.4)
		@warning_ignore("integer_division")
		var z := -24.0 + float(index / 9) * 22.0 + wreck_rng.randf_range(-6.5, 6.5)
		var bulk := Vector3(
			wreck_rng.randf_range(1.6, 4.8),
			wreck_rng.randf_range(1.4, 5.6),
			wreck_rng.randf_range(1.6, 4.4)
		)
		var pile := Node3D.new()
		pile.position = Vector3(x, bulk.y * 0.5, z)
		add_child(pile)
		var core := MeshInstance3D.new()
		var core_mesh := BoxMesh.new()
		core_mesh.size = bulk
		core_mesh.material = WorldLook.surface(Color("3d291d"), "rust", index + 7)
		core.mesh = core_mesh
		pile.add_child(core)
		Silhouette.dress(pile, bulk, index + 31, Callable(WorldLook, "surface"))
		Silhouette.settle(pile, index + 31)
	# Vast readable landmarks: original fungal towers, shattered pylons and
	# radioactive caps turn the former circular test pen into a traversable region.
	for index in 72:
		var angle := float(index) * 2.39996
		var radius := 45.0 + float((index * 47) % 145)
		var fungus_pos := Vector3(cos(angle) * radius * 1.25, 2.0, sin(angle) * radius)
		var stalk_height := 4.0 + float(index % 8) * 1.4
		_add_mesh(CylinderMesh.new(), fungus_pos, Vector3(1.2 + float(index % 3) * 0.3, stalk_height, 1.2), Color("59603b"), 0.0)
		_add_mesh(SphereMesh.new(), fungus_pos + Vector3(0, stalk_height + 1.2, 0), Vector3(3.2 + float(index % 4), 0.8, 3.2 + float(index % 4)), Color("8da442"), 0.25 if index % 6 == 0 else 0.0)
	for index in 34:
		var side := -1.0 if index % 2 == 0 else 1.0
		var pylon_pos := Vector3(side * (58 + (index % 5) * 25), 5, -155 + index * 9)
		# Pylons lean and carry crossarms rather than standing as plumb posts.
		var pylon := Node3D.new()
		pylon.position = pylon_pos
		add_child(pylon)
		var pylon_size := Vector3(2.2, 12 + index % 7, 2.2)
		var shaft := MeshInstance3D.new()
		var shaft_mesh := BoxMesh.new()
		shaft_mesh.size = pylon_size
		shaft_mesh.material = WorldLook.surface(Color("352b26"), "rust", index + 61)
		shaft.mesh = shaft_mesh
		pylon.add_child(shaft)
		Silhouette.dress(pylon, pylon_size, index + 91, Callable(WorldLook, "surface"))
		Silhouette.settle(pylon, index + 91)
	# A4.1. Light in this world is scarce and it belongs to something. These nine
	# stood in an arithmetic row — `-24 + index * 6`, eight metres apart at the
	# origin — which is the whole reason night read as one lit clearing in a black
	# region rather than as a region at night. They are placed now: the pit gate
	# somebody walks in through, two along the road out, and a pair over the
	# wreck line. Fewer lamps, further apart, each on a thing that would have
	# power.
	for spot: Dictionary in GATE_LIGHTS:
		_place_night_light(spot["at"], Color(spot["color"]), float(spot["energy"]), float(spot["reach"]), bool(spot.get("shadows", false)))
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_color = Color("c89572")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)


## H10.8. A low, battered sleeping place close to the opening route. Its long
## silhouette, rolled foot blanket and pillow read as somewhere a body lies;
## the bone placard carries the interaction without turning it into HUD décor.
func _build_sleep_site() -> void:
	sleep_site = Node3D.new()
	sleep_site.name = "AshbloomBedroll"
	sleep_site.position = SLEEP_SITE_POSITION
	add_child(sleep_site)
	_add_mesh_to(sleep_site, BoxMesh.new(), Vector3(0, 0.04, 0), Color("291612"), 0.0, Vector3(2.4, 0.10, 1.15))
	_add_mesh_to(sleep_site, BoxMesh.new(), Vector3(-0.08, 0.10, 0), Color("54251f"), 0.0, Vector3(2.0, 0.08, 0.92))
	_add_mesh_to(sleep_site, BoxMesh.new(), Vector3(-0.82, 0.19, 0), Color("a69a76"), 0.0, Vector3(0.42, 0.16, 0.72))
	var roll := MeshInstance3D.new()
	var roll_mesh := CylinderMesh.new()
	roll_mesh.top_radius = 0.23
	roll_mesh.bottom_radius = 0.23
	roll_mesh.height = 1.0
	roll_mesh.radial_segments = 10
	roll_mesh.material = _material(Color("301d18"), 0.0)
	roll.mesh = roll_mesh
	roll.position = Vector3(0.94, 0.24, 0)
	roll.rotation_degrees.z = 90.0
	sleep_site.add_child(roll)
	for side in [-1.0, 1.0]:
		_add_mesh_to(sleep_site, CylinderMesh.new(), Vector3(0, 0.08, side * 0.72), Color("7b6750"), 0.0, Vector3(0.07, 0.16, 0.07))
	var marker := Label3D.new()
	marker.text = "BEDROLL  //  REST TO DAWN"
	marker.font_size = 28
	marker.modulate = Color("c7b77b")
	marker.outline_modulate = Color("170b09")
	marker.outline_size = 8
	marker.position = Vector3(0, 0.78, -0.72)
	sleep_site.add_child(marker)


## A4.1. One place a light is made, so every light in the region is in the same
## system: it is recorded for the hour to drive, and it gets its warp shell
## (A3.2) at birth rather than from a later sweep that could miss one.
func _place_night_light(at: Vector3, color: Color, energy: float, reach: float, shadows := false, bulb_size := 0.4) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = shadows
	# The air here is bad enough to have volumetric fog in it, so a lamp should
	# have a throw you can see from outside the circle it lights. This is the
	# difference between a light and a lit patch of ground.
	lamp.light_volumetric_fog_energy = 1.8
	lamp.set_meta("night_energy", energy)
	add_child(lamp)
	# The fixture itself. A light with no visible source is only its effect on
	# whatever it reaches, and at any distance through this fog that is nothing:
	# the first build of A4.1 photographed a black region with five lights in it
	# and five lights' worth of nothing to see. A lamp has a bulb.
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = bulb_size
	bulb_mesh.height = bulb_size * 2.0
	bulb_mesh.radial_segments = 10
	bulb_mesh.rings = 6
	var glass := StandardMaterial3D.new()
	glass.albedo_color = color
	glass.emission_enabled = true
	glass.emission = color
	glass.emission_energy_multiplier = BULB_GLOW
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mesh.material = glass
	bulb.mesh = bulb_mesh
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(bulb)
	lamp.set_meta("glass", glass)
	night_lights.append(lamp)
	LightWarp.attach(lamp)
	return lamp


## A8.1 / A8.2. The spirit shows through as the body fails, which is the one
## reading in this game that gets stronger the worse things are going. Driven
## off the same `combat_ratio()` the damage model already keeps, so the flame
## can never disagree with the body it is burning on.
func _update_flame() -> void:
	if flame == null or not is_instance_valid(flame):
		return
	if player_rig == null or not is_instance_valid(player_rig):
		return
	# B8.1's "visibly". `flame_condition()` folds the burden of every previous
	# failure into the same number the flame already read, so a body that has run
	# out three times burns harder than its current wounds alone would say —
	# which is exactly what it is. No second effect, no counter.
	flame.set_condition(player_rig.anatomy.flame_condition())


## B2.1. The rig, kept current while the player is looking at it.
##
## `anatomy_state` was written in exactly two places — on taking a wound and on
## being re-decanted — so the World Index's BODY page showed whatever the last
## fight had left behind. Anything that changed the body without going through
## `_take_damage()` (a limb picked up or dropped, an implant, a heal, a graft,
## anything a future system does to the rig) simply never reached the chart:
## the body was inspectable only under damage, which is this segment's
## complaint in its own words.
##
## Amended rather than updated, because `update_subject()` records a history
## event and a player standing still reading their own chart has not done
## anything the world needs to remember. Only while the device is up, so a
## closed handheld costs nothing.
func _update_body_record(delta: float) -> void:
	if handheld == null or not is_instance_valid(handheld) or not handheld.is_open:
		body_record_timer = 0.0
		return
	if player_rig == null or not is_instance_valid(player_rig):
		return
	body_record_timer -= delta
	if body_record_timer > 0.0:
		return
	body_record_timer = BODY_RECORD_INTERVAL
	WorldHistory.amend_subject("player", {"anatomy_state": player_rig.snapshot()})


## A9.1 / A9.2 / W1.2. The volume follows the player in steps, and its severity
## is `WorldWeather.contamination()` — an ambient floor that rises with elapsed
## days, worse at night than by day, with whatever storm AS4.2 eventually
## builds (currently `chaos_magick()`, sitting near zero on a quiet run and
## climbing with rituals and the gods A7 put in the sky) folded in on top. A
## clear, ritual-free night now reads as something rather than nothing, which
## is the whole point of W1.2: contamination was a static paint job until now.
func _update_air() -> void:
	if air == null or not is_instance_valid(air):
		return
	air.follow(player)
	air.set_severity(WorldWeather.contamination())
	# B7.1. Standing in it costs something. The air doses whatever it is
	# touching, and what the player is wearing decides how much of it gets
	# through — which is what makes a filter mask a decision rather than a
	# cosmetic.
	if player_rig != null and is_instance_valid(player_rig):
		player_rig.anatomy.expose(air.severity(), get_physics_process_delta_time())
		# B10.9. The same body, answering the hour as well as the air. The two
		# arrive as separate factors on purpose — the dark is what makes it cold
		# and the storm is what gives it teeth — so neither can hide inside a
		# single pre-mixed "badness" and a test can move one while holding the
		# other. What the player has on decides how much of it lands, inside
		# `chill()`, off the same `Garments` figure that stops a bullet.
		player_rig.anatomy.chill((1.0 - WorldClock.daylight()) * air.severity(), get_physics_process_delta_time())
	var env: Environment = $WorldEnvironment.environment
	if env != null:
		# The haze thickens with it. Motes say there is something in the air;
		# the fog is what makes the far side of the region disappear into it.
		env.volumetric_fog_density = env.volumetric_fog_density * (1.0 - AIR_FOG_BLEND) 			+ float(WorldLook.PRESETS.ashbloom.volumetric) * (1.0 + air.severity() * 2.2) * AIR_FOG_BLEND


## A7.2. A sighting is not decoration: `gods.gd` has already written it into
## `WorldHistory` by the time this runs, and this is where the scene answers.
## The line goes to the status readout rather than a bespoke banner, because the
## one thing this world does with an omen is note it and carry on.
func _on_god_seen(body: Dictionary) -> void:
	if status != null and is_instance_valid(status):
		status.text = "%s IS UP // %s" % [String(body.get("name", "SOMETHING")), WorldClock.long_stamp()]


## AS2. The sun and the base ambient used to be set once in `_build_world()`
## and never touched again — a fixed 1.4-energy noon that never dimmed no
## matter how many hours `world_clock.gd` had actually advanced. Driven every
## physics frame instead, off `WorldClock.daylight()` alone rather than the
## raw hour, so anything already using `daylight()` as its single source of
## "how lit is it right now" — this included — can never quietly disagree.
func _update_day_night() -> void:
	if sun == null or not is_instance_valid(sun):
		return
	var daylight := WorldClock.daylight()
	# AS2.2. Minimal lighting is the default night settles to; full daylight
	# is the brief exception at the top of the curve, not the baseline dusk
	# fades down from.
	sun.light_energy = lerpf(0.08, 1.4, daylight)
	sun.light_color = Color("39445a").lerp(Color("c89572"), daylight)
	var env: Environment = $WorldEnvironment.environment
	if env != null:
		# A3.1. The sky and the fog move with the hour too. Without this the
		# sun dimmed, the ground went black and the horizon stayed exactly as
		# bright as it is at noon — verified by capture, the 01:00 and 12:00
		# skies were identical. Kept in `world_look.gd` so the derby and the
		# hunt cannot end up with two different nights.
		WorldLook.apply_hour(env, daylight, "ashbloom")
	# AS2.1 said "the light can become really warped at night and distorted",
	# and this read it literally: every night pushed the psychedelic shader's
	# displacement dial up, so a sober player walking around after dark got a
	# permanently moving screen. Greg, twice, unprompted: the trippy filter, and
	# then "fixing the wobbly screen like you smoked weed or nicotine — even tho
	# at the start you get a random drug."
	#
	# That second half is the actual design. The warp is what being on something
	# looks like, and the game already hands you a substance at the start; if
	# nightfall does it too then the one state the shader exists to express
	# stops being legible, because the screen was already moving. So the hour no
	# longer drives this dial at all. It is left where it is, for
	# `substances.gd`, `meditation.gd` and the shadow realms to move — which is
	# FINAL_V.md §16's own argument (one shader, many dials) applied properly
	# rather than spent on the time of day.
	#
	# A3.2 is the same statement built where it does belong. The lamps bend the
	# air around themselves, full after dark and nothing at midday, and the fade
	# between the two is `daylight()`'s own dusk curve rather than a second one
	# invented here. A frame with no lamp in it is not warped at all, which is
	# the whole difference between a property and a filter.
	LightWarp.set_all(self, 1.0 - daylight)
	# A4.1. Nothing here burns in daylight. Every lamp sat at a constant energy
	# around the clock, which is invisible at noon and means night never has a
	# moment of coming on. Each one keeps its own full value in `night_energy`,
	# since a gate lamp and a district glow are not the same light turned down.
	for light in night_lights:
		if is_instance_valid(light):
			light.light_energy = float(light.get_meta("night_energy", 3.5)) * (1.0 - daylight)
			if light.has_meta("glass"):
				var glass := light.get_meta("glass") as StandardMaterial3D
				glass.emission_energy_multiplier = BULB_GLOW * (1.0 - daylight)
				# And the albedo with it. The fixture is unshaded, which means
				# it draws its own colour whatever the light is doing — so a
				# lamp that was correctly off at noon still had a bright orange
				# bulb hanging in the daylight.
				glass.albedo_color = light.light_color * (1.0 - daylight)


## AS4.5/AS3.3. Being caught out in a real storm costs something — stamina
## here, rather than a new damage type, so this stays a real cost without
## reaching into the anatomy/wound systems a weather pass has no business
## touching. AS3.3: what you are wearing is strategy, so a real layer's
## warmth cuts a real storm's cost — applied here, not inside
## storm_weather.gd itself, since the weather does not know or care who is
## standing in it, only the one getting rained on does. Split out from
## `_physics_process` (the same reason `_update_day_night` and
## `_update_altered_perception` already are) so a test can call it directly
## without first satisfying every earlier gate in that function.
func _update_storm_exposure(delta: float) -> void:
	if storm_weather == null or not is_instance_valid(storm_weather):
		return
	storm_weather.follow(player)
	var warmth := float(Clothing.stats("player").get("warmth", 0.0))
	stamina = clampf(stamina - storm_weather.exposure_cost(delta) * (1.0 - warmth), 0.0, 100.0)


## AE1.1. "Unseen is a real state with real inputs — light, noise, cover,
## distance." `perception.gd`'s `visibility()` is a pure function of those
## four; this is what actually supplies them from the live world, against
## every hostile still hunting, and keeps the worst (most exposed) verdict —
## the one a hostile closest to noticing you would actually see.
##
## Noise is the one input with no existing system behind it anywhere in the
## project: sprinting is a real, if simple, first source, decaying rather
## than switching instantly so a sprint's noise does not vanish the exact
## frame you stop. Light reads `WorldClock.daylight()` and the handheld's
## own `is_lit()` — AS1.5's light_radius() hook finally has a caller. Cover
## is one raycast per live hostile, the same exclude-both-ends convention
## `_update_camera()`'s own obstruction check already uses: nothing in the
## way reads as a clear sightline, anything else in the way reads as full
## cover.
func _update_perception(delta: float) -> void:
	var sprinting_now := Input.is_action_pressed("sprint") and player_body.velocity.length() > 0.5
	player_noise = move_toward(player_noise, 1.0 if sprinting_now else 0.0, delta * 2.0)

	var light := clampf(maxf(WorldClock.daylight(), HANDHELD_BODY_LIGHT if handheld.is_lit() else 0.0), 0.0, 1.0)
	var target := player + Vector3.UP * 0.2

	var worst := 0.0
	for actor: Dictionary in encounter_actors:
		if bool(actor.get("dead", false)):
			continue
		var hostile: Node3D = actor.get("node")
		if hostile == null or not is_instance_valid(hostile):
			continue
		var eye := hostile.global_position + Vector3.UP * 1.5
		var distance := eye.distance_to(target)
		var excluded: Array[RID] = [player_body.get_rid()]
		if hostile is CollisionObject3D:
			excluded.append((hostile as CollisionObject3D).get_rid())
		var query := PhysicsRayQueryParameters3D.create(eye, target)
		query.exclude = excluded
		var cover := 0.0 if get_world_3d().direct_space_state.intersect_ray(query).is_empty() else 1.0
		var body_visibility := PERCEPTION.visibility(light, player_noise, cover, distance, PERCEPTION_MAX_RANGE)
		var saw_body: bool = body_visibility >= PERCEPTION.UNSEEN_THRESHOLD
		var saw_light: bool = handheld.is_lit() and PERCEPTION.sees_emitted_light(distance, handheld.light_radius(), cover) and not saw_body
		var was_tracking_light := bool(actor.get("tracking_light", false))
		actor["tracking_player"] = saw_body
		actor["tracking_light"] = saw_light
		if saw_light and not was_tracking_light:
			WorldHistory.record_event("hunter_noticed_handheld_light", {
				"hunter": str(actor.get("subject_id", "unknown")),
				"distance": snappedf(distance, 0.1),
				"location": HUNT_LOCATION,
			})
		worst = maxf(worst, body_visibility)
	player_visibility = worst
	player_unseen = worst < PERCEPTION.UNSEEN_THRESHOLD


## E6/E8. `substances.gd` and `meditation.gd` have both paid into
## `anatomy_state.consciousness` since before either system existed, and
## neither one has ever had anything on screen to show for it — the entire
## cost was invisible. Perception distorting as consciousness fades is the
## same shader at a different dial (FINAL_V.md §16's own argument), not a
## fourth system: whatever actually caused the drop, a substance, a
## meditation session, blood loss, the fiction does not care which, only the
## player's own state does.
##
## Always sets every dial it owns, even back to zero, rather than only ever
## pushing them up — `storm_weather.gd`'s lightning flash already taught this
## build what happens to a value nothing ever resets: it freezes wherever it
## last was instead of actually relaxing when the state that raised it passes.
## This must assign from current anatomy, not add to the previous frame. The
## old `dial() + altered * 0.05` compounded sixty times a second: one mildly
## harsh draw became a fully liquefied screen before an inspection finished.
## Night deliberately owns no fullscreen displacement (A3.2 uses local light
## shells), so consciousness is the complete live source for this dial here.
func _update_altered_perception() -> void:
	if player_rig == null or not is_instance_valid(player_rig):
		return
	if psychedelic == null or not is_instance_valid(psychedelic):
		return
	var altered := 1.0 - clampf(player_rig.anatomy.consciousness / 100.0, 0.0, 1.0)
	psychedelic.set_dial("displacement_strength", altered * 0.05)
	psychedelic.set_dial("chromatic_offset", altered * 0.012)
	psychedelic.set_dial("kaleidoscope_segments", lerpf(0.0, 5.0, clampf(inverse_lerp(0.5, 1.0, altered), 0.0, 1.0)))


func _build_expanse_systems() -> void:
	generated_world = WORLD_GENERATOR.new()
	generated_world.name = "ProceduralAshbloomDistricts"
	add_child(generated_world)
	generated_world.call("generate", 774013)
	# A4.1. One light per settlement, read from the generator's own centres so a
	# district that moves takes its light with it rather than leaving a lamp over
	# empty ground. Wide and low: this is the glow you steer by from two hundred
	# metres out across a dark region, not a lamp anybody reads under.
	for centre: Vector3 in WORLD_GENERATOR.DISTRICT_CENTERS:
		_place_night_light(centre + Vector3(0, 13, 0), Color("d8973f"), 9.0, 85.0, false, 1.6)
	pathfinder.build(generated_world.lots)
	misfire_director = MISFIRE_DIRECTOR.new()
	misfire_director.name = "RealityMisfires"
	add_child(misfire_director)
	misfire_director.connect("misfire_triggered", _on_reality_misfire)
	misfire_director.call("generate", 774013, Vector2(470, 370), 18)
	if living_map != null:
		living_map.bind(generated_world, misfire_director, _map_contacts)
		# The field radar and the opened map share this one sleeping satellite.
		# It renders only on their explicit request, never twice in parallel.
		living_map.attach_world(get_world_3d())
	# The region is inhabited on arrival rather than filling in over the first
	# two minutes. Half the target standing at the start, the rest arriving on
	# the ordinary interval, so walking out of the gate finds a populated world
	# without every one of them appearing in the same breath.
	for _initial in int(ROAMER_TARGET * 0.5):
		_spawn_roamer(true)


func _on_reality_misfire(encounter: Dictionary, at: Vector3) -> void:
	WorldHistory.record_event("reality_misfire_triggered", {"encounter": encounter.duplicate(true), "location": HUNT_LOCATION})
	var title_text := str(encounter.get("title", "REALITY MISFIRE"))
	var summary := str(encounter.get("summary", "Something impossible notices you."))
	prompt.text = "REALITY MISFIRE // %s\n%s" % [title_text, summary]
	# A system named "Reality Misfire" had never once made reality visibly
	# misfire — a text prompt was the whole event. One burst, world-space and
	# on the screen at once, rather than a fabricated new meaning for the name.
	if glitch_spider != null and is_instance_valid(glitch_spider):
		glitch_spider.trigger(at + Vector3.UP, player, psychedelic)
	var kind := str(encounter.get("kind", "mystery"))
	if kind in ["hostile", "boss"]:
		_spawn_encounter_actor(encounter, at)
	else:
		_spawn_misfire_marker(title_text, summary, at, kind, str(encounter.instance_id))


## Any actor the world puts in front of the player, built out of the same parts:
## a body, a collision capsule, an identity label, and a `BaselineHuman` rig with
## an anatomy component on it. Returns the actor dictionary it appended, or an
## empty dictionary when the caller asked for somebody who is already dead or
## already gone - `_spawn_ashline_reinforcements()` and the misfire director
## ignore the return, the Bone Yard population uses it to finish dressing the
## worker it just created.
func _spawn_encounter_actor(encounter: Dictionary, at: Vector3) -> Dictionary:
	var subject_id := "%s_actor" % str(encounter.get("instance_id", "misfire"))
	var saved_actor := WorldHistory.subject(subject_id)
	var returning_rival := bool(encounter.get("returning_rival", false)) and bool(saved_actor.get("is_rival", false)) and str(saved_actor.get("status", "")) == "escaped"
	if str(saved_actor.get("status", "")) == "dead" or (str(saved_actor.get("status", "")) == "escaped" and not returning_rival):
		return {}
	# AE.3. A caller that already knows who this is says so, and is believed.
	# The population resolves its own people through `cast_names.gd` and passes
	# the name in; everything that existed before this - reality misfires, the
	# captain's reinforcements - passes nothing and keeps the two authored
	# stand-ins it has always had. The saved record is read first, so a worker
	# who was already in the yard when it was last written comes back as
	# themselves rather than as a stranger standing in their post.
	var display_name := str(saved_actor.get("name", ""))
	if display_name.is_empty():
		display_name = str(encounter.get("display_name", ""))
	if display_name.is_empty():
		display_name = "Ashline Tollkeeper" if str(encounter.kind) == "hostile" else "Dead Weather Saint"
	# Standing travels with the name, for the same reason and read the same way
	# round. A population whose every member's plate says ELO 1110 shows the
	# spawn table's seams exactly the way one repeated name does. The authored
	# pair stays the default, so a misfire is unchanged by this existing.
	var elo := int(encounter.get("elo", 1110 if str(encounter.kind) == "hostile" else 1510))
	var actor := CharacterBody3D.new()
	actor.name = subject_id
	actor.position = pathfinder.safe_position(at + Vector3.UP)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	actor.add_child(collision)
	add_child(actor)
	var identity := Label3D.new()
	identity.name = "Identity"
	identity.text = "%s\nELO %04d" % [display_name.to_upper(), elo]
	identity.position = Vector3(0, 3.1, 0)
	identity.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.add_child(identity)
	# Was a bare capsule with an anatomy component bolted on and no hit geometry
	# at all, which is why melee had to pick a zone by round-robin. The rig gives
	# them a real body to aim at.
	var rig := BaselineHuman.new()
	rig.name = "Body"
	actor.add_child(rig)
	rig.position = Vector3(0, -0.9, 0)
	# AE.3. Flesh colour, procedural variation, blood volume and named implants
	# are the four things `baseline_human.gd`'s own `build()` reads to make two
	# people out of one rig - and until now every spawn in this scene passed the
	# same values for the first three, so the region's population was one body
	# copied around with a different label over it. A caller may name them; the
	# defaults are exactly what this function has always used, so the misfires
	# and the captain's reinforcements are unchanged.
	var rig_config := {
		"flesh": Color(str(encounter.get("tint", "70201c"))) if str(encounter.kind) == "hostile" else Color("586c3a"),
		"variation": int(encounter.get("variation", subject_id.length())),
		"gore": viscera_fx,
		"blood": float(encounter.get("blood", 5200.0 if str(encounter.kind) == "boss" else 4300.0)),
	}
	# Named, not just an armour number. Before B2 an implant *was* its armour
	# value, so this passed an anonymous dictionary and every Ashline body
	# ended up carrying a part the catalogue could only call "unknown
	# hardware" — visible in the dossier and robbable as nothing in
	# particular. The armour override keeps the encounter balance it was
	# tuned with; the name gives it a zone, a condition and a real mesh.
	#
	# AE.3. Which hardware is now the caller's to say, because a yard full of
	# people who all have the same sternum plate is a yard full of one person.
	# A caller that names an implant gets it on the zone it names; every caller
	# that predates this - misfires, the captain's reinforcements - gets the
	# sternum this line has always built.
	var implant: Variant = encounter.get("implant", null)
	if implant is Dictionary:
		rig_config["cybernetics"] = {
			str(implant.get("zone", "torso")): {
				"name": str(implant.get("name", "salvaged hardware")),
				"armor": float(implant.get("armor", 0.12)),
			},
		}
	else:
		rig_config["cybernetics"] = {"torso": {"name": "ceramic sternum", "armor": 0.18}}
	if saved_actor.get("anatomy_state") is Dictionary:
		rig_config["restore"] = saved_actor.anatomy_state
	rig.gore = viscera_fx
	rig.build(subject_id, rig_config)
	HUNTER_APPEARANCE.style_world_rig(rig, subject_id, str(encounter.kind) == "hostile")
	var rival_changed := _fit_rival_adaptation(rig, saved_actor)
	if rival_changed:
		identity.text = "%s // RETURNED RIVAL" % display_name.to_upper()
	var anatomy: Node = rig.anatomy
	# AE.3. What is on the body when it goes down. A caller may say; everything
	# else keeps the Ashline pockets this has always spawned with.
	var loot: Array = []
	var requested_loot: Variant = encounter.get("loot", null)
	if requested_loot is Array:
		loot.assign(requested_loot)
	if loot.is_empty():
		loot = ["Ashline toll teeth", "rust scrip"] if str(encounter.kind) == "hostile" else ["weather-heart filament", "dead god relay"]
	encounter_actors.append({"subject_id": subject_id, "display_name": display_name, "node": actor, "rig": rig, "anatomy": anatomy, "state": "hunting", "disposition": "hostile", "speed": 3.7, "loot": loot, "loot_at_risk": false, "dead": false})
	encounter_actors.back()["encounter_id"] = str(encounter.get("instance_id", ""))
	if returning_rival:
		encounter_actors.back()["returning_rival"] = true
	if str(saved_actor.get("status", "")) in ["spared", "recruited"]:
		encounter_actors.back().state = str(saved_actor.status)
		encounter_actors.back().disposition = "ally" if str(saved_actor.status) == "recruited" else "neutral"
	WorldHistory.register_subject(subject_id, {"name": display_name, "kind": "person", "role": str(encounter.get("role", encounter.kind)), "elo": elo, "status": "encountered", "memory": summary_from(encounter), "wounds": [], "anatomy": anatomy.call("snapshot"), "relations": {"player": {"kind": "enemy", "strength": 35}}})
	if returning_rival:
		var return_count := int(saved_actor.get("rival_returns", 0)) + 1
		WorldHistory.amend_subject(subject_id, {
			"status": "hunting", "rival_returns": return_count,
			"anatomy_state": rig.snapshot(),
		})
		WorldHistory.record_event("rival_returned_to_hunt", {
			"subject_id": subject_id, "return_count": return_count,
			"adaptation": (saved_actor.get("rival_adaptation", {}) as Dictionary).duplicate(true),
			"location": HUNT_LOCATION,
		})
	# AE.3. Returned so the caller can finish dressing an actor it has a name
	# and a body for - a lantern, a proper label, a faction on the record. The
	# misfire director and `_spawn_ashline_reinforcements()` ignore this, as
	# they always ignored the absence of it.
	return encounter_actors.back()


## F10.4. Put the answer RivalRegistry derived onto the body that returns. The
## saved anatomy already restores scars and missing tissue; this adds the thing
## the rival did about it. All hardware goes through BaselineHuman, so anatomy,
## combat capability, INDEX and visible mesh read one installation.
func _fit_rival_adaptation(rig: BaselineHuman, subject: Dictionary) -> bool:
	if not bool(subject.get("is_rival", false)):
		return false
	var adaptation: Dictionary = subject.get("rival_adaptation", {})
	if adaptation.is_empty():
		return false
	var zone := str(adaptation.get("zone", "torso"))
	var item := str(adaptation.get("item", "remembered impact cage"))
	match str(adaptation.get("kind", "scar")):
		"prosthetic":
			rig.install_prosthetic(zone, {
				"name": item, "armor": 0.34, "restores": 0.82,
				"tint": "c15d2d",
			})
		"organ_support":
			rig.install_hardware(zone, {
				"name": item, "armor": 0.27, "tint": "8e6a54",
			})
		"armour":
			rig.install_hardware(zone, {
				"name": item, "armor": 0.22, "tint": "6c6258",
			})
		# A scar is already part of the restored body's wound geometry. Returning
		# true still marks the identity as changed rather than pretending no
		# adaptation exists because it did not require new hardware.
	return true


## The Hunt Grounds had no standing population at all. Every hostile in the
## region came out of `_on_reality_misfire`, and the misfire table rolls
## `hostile`+`boss` at 26 of 100 across 18 one-shot encounters — about four
## fights in a 470x370 m region, each of which never came back once it
## resolved. The AI underneath was never the problem: hunting, orbiting, the
## melee slot, fleeing at a bleed-out, footing and stagger were all built and
## all worked. There was simply nobody in the world to run them.
##
## So: a maintained roaming population, spawned through the exact same
## `_spawn_encounter_actor` every misfire uses, which is what gets them a real
## anatomy rig, real loot, a real WorldHistory subject and the same AI rather
## than a second, thinner "ambient enemy" that would drift out of step with it.
const ROAMER_TARGET := 14
## Never spawn inside the player's own view distance. A body that appears out
## of nothing forty metres ahead is worse than an empty region.
const ROAMER_MIN_SPAWN_RANGE := 55.0
const ROAMER_MAX_SPAWN_RANGE := 130.0
## Beyond this a roamer is genuinely on the other side of the region, so it is
## recycled rather than kept ticking — the population follows the player around
## the map instead of pooling wherever they happened to start.
const ROAMER_CULL_RANGE := 230.0
## One at a time, not a burst. The region refills at the rate a fight empties
## it, which reads as a place people keep walking into rather than a wave.
const ROAMER_SPAWN_INTERVAL := 7.0
var _roamer_clock := 0.0
var _roamer_serial := 0
## Advanced on every attempt, successful or not. Seeding the placement RNG off
## `_roamer_serial` alone deadlocked the population: the serial only moves when
## a body is actually placed, so the first attempt that found nowhere valid
## re-rolled the identical eight candidates on every subsequent interval and the
## region stayed permanently one short. Counted separately so a failed attempt
## still changes the dice.
var _roamer_attempt := 0


## How many living ROAMERS are still standing. Downed and dead bodies stay in
## the world (they are lootable, robbable and part of the record) but they are
## not opposition any more, so they do not hold a slot shut.
##
## Counted by encounter id rather than by disposition, which matters more than
## it looks: `_spawn_encounter_actor` hands every body it builds a default
## disposition of "hostile", so the yard's own five workers (AE.1, standing at
## their posts) and every misfire body read as hostile too. Counting those
## against a roaming target of fourteen would have quietly capped the roaming
## population at nine the moment the yard was manned — the region would have
## looked busier and actually hunted you less. The target governs roamers, so
## only roamers are counted toward it.
func _living_hostiles() -> int:
	var standing := 0
	for actor in encounter_actors:
		if bool(actor.get("dead", false)):
			continue
		if not str(actor.get("encounter_id", "")).begins_with("roamer_"):
			continue
		if str(actor.get("disposition", "hostile")) != "hostile":
			continue
		var anatomy: Node = actor.get("anatomy") as Node
		if anatomy == null or anatomy.dead or anatomy.downed:
			continue
		standing += 1
	return standing


func _maintain_roamers(delta: float) -> void:
	if pathfinder == null or generated_world == null or not is_instance_valid(generated_world):
		return
	_maintain_holding_work()
	_maintain_celloutz_contractors()
	_cull_distant_roamers()
	_roamer_clock += delta
	if _roamer_clock < ROAMER_SPAWN_INTERVAL:
		return
	_roamer_clock = 0.0
	if _living_hostiles() >= ROAMER_TARGET:
		return
	# A person the player made into a rival gets the open population slot before
	# another anonymous road body. This is the missing production bridge between
	# RivalRegistry's conclusion and a body actually coming back into play.
	if _spawn_returning_rival():
		return
	_spawn_roamer()


func _spawn_returning_rival() -> bool:
	var candidate_ids: Array[String] = []
	for subject_id: String in WorldHistory.all_subjects():
		var subject := WorldHistory.subject(subject_id)
		if subject_id == CAST.id_for(CAPTAIN_SLOT) or not subject_id.ends_with("_actor"):
			continue
		if str(subject.get("kind", "")) != "person" or str(subject.get("status", "")) != "escaped" or not bool(subject.get("is_rival", false)):
			continue
		if encounter_actors.any(func(actor: Dictionary): return str(actor.get("subject_id", "")) == subject_id):
			continue
		candidate_ids.append(subject_id)
	if candidate_ids.is_empty():
		return false
	candidate_ids.sort()
	var subject_id := candidate_ids[0]
	var subject := WorldHistory.subject(subject_id)
	var instance_id := subject_id.trim_suffix("_actor")
	var spawned := _spawn_encounter_actor({
		"instance_id": instance_id, "kind": "hostile", "returning_rival": true,
		"display_name": str(subject.get("name", "Returned Rival")),
		"role": str(subject.get("role", "RIVAL")), "elo": int(subject.get("elo", 1110)),
		"variation": abs(hash(subject_id)),
		"summary": "The same person returned with the last encounter still on their body.",
	}, _rival_return_position(subject_id))
	if not spawned.is_empty():
		HUNT_MEMORY.remember(subject_id, "returning_rival")
	return not spawned.is_empty()


func _rival_return_position(subject_id: String) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rival_return:%s:%d" % [subject_id, int(WorldHistory.subject(subject_id).get("rival_returns", 0))])
	var centres: Array = WORLD_GENERATOR.DISTRICT_CENTERS
	for attempt in centres.size():
		var centre: Vector3 = centres[(abs(hash(subject_id)) + attempt) % centres.size()]
		var angle := rng.randf() * TAU
		var candidate := centre + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(10.0, 34.0)
		var reach := player.distance_to(candidate)
		if reach >= ROAMER_MIN_SPAWN_RANGE and reach <= ROAMER_MAX_SPAWN_RANGE:
			return pathfinder.safe_position(candidate + Vector3.UP)
	# The deterministic district pass can fail while the player stands at the
	# edge of the generated region. The fallback is still outside view and still
	# projected through the shared pathfinder rather than dropped through terrain.
	var fallback_angle := rng.randf() * TAU
	return pathfinder.safe_position(player + Vector3(cos(fallback_angle), 0, sin(fallback_angle)) * ROAMER_MIN_SPAWN_RANGE + Vector3.UP)


## AA10.13. Accepted work leaves the dossier and enters the same physical world
## as every other encounter. Raid targets are ordinary persistent people;
## recovery targets are ordinary loot caches. Rebuilding the Hunt restores an
## unresolved objective from the job record instead of silently completing it.
func _maintain_holding_work() -> void:
	for job: Dictionary in ASHBLOOM_HOLDINGS.active_work():
		var job_id := str(job.id)
		var target_data: Dictionary = job.get("target", {}) if job.get("target", {}) is Dictionary else {}
		var target := Vector3(float(target_data.get("x", 0.0)), 0.0, float(target_data.get("z", 0.0)))
		match str(job.get("work_type", "")):
			"raid":
				_maintain_holding_raid(job_id, job, target)
			"collection":
				_maintain_holding_collection(job_id, job, target)


func _maintain_holding_raid(job_id: String, job: Dictionary, target: Vector3) -> void:
	var required := maxi(1, int(job.get("required", 2)))
	var subject_ids: Array = job.get("target_subjects", []).duplicate()
	if subject_ids.is_empty():
		for slot in required:
			subject_ids.append("holding_work_%s_%d_actor" % [str(job.get("holding_id", "unknown")), slot])
		WorldHistory.amend_subject(job_id, {"target_subjects": subject_ids.duplicate()})
	var resolved := 0
	for slot in required:
		var subject_id := str(subject_ids[slot])
		var status := str(WorldHistory.subject(subject_id).get("status", ""))
		if status in ["dead", "escaped", "spared", "recruited"]:
			resolved += 1
			continue
		var instance_id := subject_id.trim_suffix("_actor")
		if encounter_actors.any(func(actor: Dictionary): return str(actor.get("encounter_id", "")) == instance_id):
			continue
		var who := CAST.person(instance_id)
		var spawned := _spawn_encounter_actor({
			"instance_id": instance_id, "kind": "hostile", "display_name": str(who.name),
			"role": "UNRECORDED CLAIM CREW", "elo": 1050 + slot * 55,
			"variation": 610 + abs(hash(job_id)) % 200 + slot,
			"tint": "70513b", "loot": ["false claim writ", "holding survey stake"],
			"summary": "Named by a local holding's accepted raid order.",
		}, target + Vector3(-4.0 if slot == 0 else 4.0, 0.0, float(slot) * 2.0))
		if spawned.is_empty():
			continue
		spawned["holding_work_job"] = job_id
		WorldHistory.amend_subject(str(spawned.subject_id), {
			"holding_work_job": job_id, "contract_place": str(job.get("place_id", "")),
		})
	if int(job.get("progress", 0)) != resolved:
		WorldHistory.amend_subject(job_id, {"progress": resolved})
	if resolved >= required:
		ASHBLOOM_HOLDINGS.complete_work(job_id, {
			"method": "claim_crew_resolved", "subjects": subject_ids.duplicate(),
		})


func _maintain_holding_collection(job_id: String, job: Dictionary, target: Vector3) -> void:
	if loose_loot.any(func(cache: Node3D):
		return is_instance_valid(cache) and str(cache.get_meta("holding_work_job", "")) == job_id):
		return
	var item := "%s field cache" % str(job.get("holding_id", "local")).replace("_", " ")
	var cache := _spawn_loot_cache(target, [item])
	cache.set_meta("holding_work_job", job_id)


## AK1.8. A published area is work somebody can take. The responders are built
## through the ordinary encounter actor path, so they have the same anatomy,
## wounds, loot, perception and persistence as every other hunter. One live
## team owns the contract at a time; moving between ping cells cannot become an
## infinite enemy printer. A later ping can commission a replacement only once
## both members of the previous contract are dead or escaped.
func _maintain_celloutz_contractors() -> void:
	var reaction := WorldHistory.subject(FACILITY_TERRITORY.REACTION_SUBJECT)
	var area: Dictionary = reaction.get("target_area", {})
	if area.is_empty():
		return
	var ping_sequence := int(area.get("sequence", 0))
	var response_sequence := int(reaction.get("response_sequence", 0))
	if response_sequence > 0 and _celloutz_team_unresolved(response_sequence):
		_restore_celloutz_team(response_sequence, reaction.get("response_area", area))
		return
	if ping_sequence <= response_sequence:
		return
	WorldHistory.amend_subject(FACILITY_TERRITORY.REACTION_SUBJECT, {
		"response_sequence": ping_sequence,
		"response_area": area.duplicate(true),
	})
	WorldHistory.record_event("celloutz_repossession_team_dispatched", {
		"subject_id": FACILITY_TERRITORY.REACTION_SUBJECT,
		"target_id": "player",
		"sequence": ping_sequence,
		"area": area.duplicate(true),
	})
	_restore_celloutz_team(ping_sequence, area)


func _celloutz_team_unresolved(sequence: int) -> bool:
	for slot in 2:
		var id := "celloutz_contract_%d_%d_actor" % [sequence, slot]
		var status := str(WorldHistory.subject(id).get("status", ""))
		if status not in ["dead", "escaped", "spared", "recruited"]:
			return true
	return false


func _restore_celloutz_team(sequence: int, area_variant: Variant) -> void:
	var area: Dictionary = area_variant if area_variant is Dictionary else {}
	if area.is_empty():
		return
	var centre := Vector3(float(area.get("x", 0.0)), 0.0, float(area.get("z", 0.0)))
	var radius := float(area.get("radius", FACILITY_TERRITORY.TARGET_PING_RADIUS))
	var away := centre - player
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	var across := Vector3(-away.z, 0, away.x)
	for slot in 2:
		var instance_id := "celloutz_contract_%d_%d" % [sequence, slot]
		if encounter_actors.any(func(actor: Dictionary): return str(actor.get("encounter_id", "")) == instance_id):
			continue
		var subject_id := "%s_actor" % instance_id
		if str(WorldHistory.subject(subject_id).get("status", "")) in ["dead", "escaped", "spared", "recruited"]:
			continue
		var at := centre + away * radius * 0.88 + across * (-13.0 if slot == 0 else 13.0)
		var spawned := _spawn_encounter_actor({
			"instance_id": instance_id,
			"kind": "hostile",
			"display_name": "Ledger Bailiff %s" % ("A" if slot == 0 else "B"),
			"role": "CELLOUTZ REPOSSESSION CONTRACTOR",
			"elo": 1160 + slot * 45,
			"tint": "4f1718",
			"variation": 440 + sequence * 7 + slot,
			"implant": {"zone": "torso", "name": "pulse cage", "armor": 0.16},
			"loot": ["repossession writ", "sealed rust scrip"],
			"summary": "Contracted through the Black Mirror's published target area.",
		}, at)
		if spawned.is_empty():
			continue
		spawned["contract_sequence"] = sequence
		WorldHistory.amend_subject(str(spawned.subject_id), {
			"faction": "CellOutz",
			"faction_id": "celloutz",
			"contract": FACILITY_TERRITORY.REACTION_SUBJECT,
		})
		HUNT_MEMORY.remember(str(spawned.subject_id), "repossession_contract", "%s:%d" % [FACILITY_TERRITORY.REACTION_SUBJECT, sequence])


## Only roamers are recycled. A misfire's own body is part of an encounter the
## player was sent to and is left exactly where it was put.
func _cull_distant_roamers() -> void:
	for index in range(encounter_actors.size() - 1, -1, -1):
		var actor: Dictionary = encounter_actors[index]
		if not str(actor.get("encounter_id", "")).begins_with("roamer_"):
			continue
		if bool(actor.get("dead", false)):
			continue
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if player.distance_to(node.global_position) < ROAMER_CULL_RANGE:
			continue
		node.queue_free()
		encounter_actors.remove_at(index)


## Somewhere in the districts, far enough out to walk into rather than watch
## arrive. Ringed off a district centre rather than off the player, so the
## population sits where the world actually is instead of orbiting the camera.
## `anywhere` is the initial fill: at world build the player is at the gate and
## four of the five districts are two hundred metres off, so the follow-the-
## player ceiling that keeps later respawns nearby would seed exactly one
## district and leave the rest of the region empty. The floor still applies —
## nothing is ever placed inside the player's own view, seeding or not.
func _spawn_roamer(anywhere: bool = false) -> void:
	_roamer_attempt += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("roamer:%d:%d" % [WorldHistory.run_salt, _roamer_attempt])
	var centres: Array = WORLD_GENERATOR.DISTRICT_CENTERS
	var at := Vector3.ZERO
	var placed := false
	# A handful of tries rather than a loop that can never end: if every
	# district is currently too close to the player, this frame simply does not
	# spawn and the next interval tries again.
	for attempt in 8:
		var centre: Vector3 = centres[rng.randi() % centres.size()]
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(12.0, 46.0)
		var candidate := centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var reach := player.distance_to(candidate)
		if reach < ROAMER_MIN_SPAWN_RANGE:
			continue
		if not anywhere and reach > ROAMER_MAX_SPAWN_RANGE:
			continue
		at = candidate
		placed = true
		break
	if not placed:
		return
	_roamer_serial += 1
	# Their own name and their own standing, off the same generator the derby
	# captain comes from, so a roamer reads as somebody rather than as a copy.
	var who: Dictionary = CastNames.person("roamer_%d_%d" % [WorldHistory.run_salt, _roamer_serial])
	_spawn_encounter_actor({
		"instance_id": "roamer_%d" % _roamer_serial,
		"kind": "hostile",
		"display_name": str(who.get("name", "Ashline Tollkeeper")),
		"elo": 980 + (rng.randi() % 420),
		"summary": "%s works the %s roads and did not expect company." % [str(who.get("role", "collector")), str(who.get("faction", "Ashline"))],
	}, at)


func summary_from(encounter: Dictionary) -> String:
	return str(encounter.get("summary", "Encountered in the Ashbloom Expanse."))


func _spawn_misfire_marker(title_text: String, summary: String, at: Vector3, kind: String, instance_id: String = "") -> void:
	var marker := Node3D.new()
	marker.position = pathfinder.safe_position(at)
	marker.set_meta("kind", kind)
	marker.set_meta("instance_id", instance_id)
	social_markers.append(marker)
	add_child(marker)
	_add_mesh_to(marker, SphereMesh.new(), Vector3(0, 1.2, 0), Color("35b7a7") if kind == "friendly" else Color("b8d94a"), 0.8)
	var label := Label3D.new()
	label.text = "%s\n%s" % [title_text, summary]
	label.position = Vector3(0, 3.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	marker.add_child(label)


func _spawn_loot_cache(at: Vector3, items: Array) -> Node3D:
	var cache := Node3D.new()
	cache.position = at
	add_child(cache)
	loose_loot.append(cache)
	cache.set_meta("items", items.duplicate())
	# Was a default 1x1x1 BoxMesh tinted orange, floating at y 0.35 with nothing
	# under it — a placeholder that shipped, standing exactly where the player is
	# being rewarded. `LootCache` builds a dropped stash instead, and puts the
	# actual items in silhouette on top of it, so a cache can be read at distance
	# without reading the label.
	LootCache.build(cache, items, hash(str(at.snapped(Vector3.ONE)) + str(items)))
	var label := Label3D.new()
	label.text = "LOOT // %s" % ", ".join(PackedStringArray(items))
	# Sat at 1.4 over an object 0.35 tall — a metre of empty air between the
	# words and the thing they were about. Down onto the stash, and dressed:
	# bone on a dark outline in the region's own palette rather than white
	# engine-default text, which is the same fallback-font problem the menu had.
	label.position = Vector3(0, 0.62, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.0028
	label.modulate = Color("ead4ad")
	label.outline_modulate = Color(0.04, 0.03, 0.03, 0.9)
	label.outline_size = 10
	# Readable through the wreck it was dropped behind, which is most of what a
	# loot marker is for.
	label.no_depth_test = true
	label.render_priority = 2
	cache.add_child(label)
	return cache


func _spawn_friend() -> void:
	friend = Node3D.new()
	friend.position = Vector3(19, 1.0, 5)
	# Nix was a bare capsule while every procedurally spawned nobody in the
	# region got a full anatomy rig. The two named characters in the game were
	# the only two people in it without bodies.
	friend_rig = BaselineHuman.new()
	friend_rig.name = "Body"
	friend_rig.position = Vector3(0, -0.95, 0)
	friend.add_child(friend_rig)
	friend_rig.gore = viscera_fx
	var nix: Dictionary = WorldHistory.subject(FRIEND_ID)
	var nix_config := {"flesh": Color("6f7a52"), "variation": 5, "blood": 5000.0}
	if nix.get("anatomy_state") is Dictionary:
		nix_config["restore"] = nix.anatomy_state
	friend_rig.build(FRIEND_ID, nix_config)
	HUNTER_APPEARANCE.style_world_rig(friend_rig, FRIEND_ID, false)
	var label := Label3D.new()
	label.text = "NIX ARDEN\n[E] TALK"
	label.position = Vector3(0, 3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	friend.add_child(label)
	add_child(friend)


func _spawn_rival() -> void:
	enemy = Node3D.new()
	enemy.visible = false
	# Mara is the character the whole Hunt System exists to produce, and she was
	# a capsule with a box stuck to her shoulder. On a real rig her recorded
	# wounds and her replacement arm are *on her body*, which is the difference
	# between "bodies remember" being a pillar and being a line in a dossier.
	enemy_rig = BaselineHuman.new()
	enemy_rig.name = "Body"
	enemy_rig.position = Vector3(0, -1.15, 0)
	enemy.add_child(enemy_rig)
	enemy_rig.gore = viscera_fx
	var mara_record: Dictionary = WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT))
	var mara_config := {"flesh": Color("7a4a3a"), "variation": 2, "blood": 5400.0}
	if mara_record.get("anatomy_state") is Dictionary:
		mara_config["restore"] = mara_record.anatomy_state
	enemy_rig.build(CAST.id_for(CAPTAIN_SLOT), mara_config)
	HUNTER_APPEARANCE.style_world_rig(enemy_rig, CAST.id_for(CAPTAIN_SLOT), true)
	var label := Label3D.new()
	label.text = "%s // ASHLINE CAPTAIN" % _captain_name()
	label.position = Vector3(0, 3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	enemy.add_child(label)
	var mara := WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT))
	var adaptation: Dictionary = mara.get("rival_adaptation", {})
	if bool(mara.get("is_rival", false)) and not adaptation.is_empty():
		label.text = "%s // REBUILT ASHLINE CAPTAIN" % _captain_name()
		# The industrial arm is now an actual prosthetic in the anatomy record,
		# so it restores function, changes her combat ratio and shows on the rig
		# rather than being a cylinder parented next to her.
		_fit_rival_adaptation(enemy_rig, mara)
		var altered_vehicle := (load(SCRAP_SKIFF_PATH) as PackedScene).instantiate()
		altered_vehicle.name = "MarasRebuiltWrecker"
		altered_vehicle.position = Vector3(4.0, -0.45, 1.8)
		altered_vehicle.rotation.y = -0.7
		# M4.1. Was 0.78 — a third smaller than the same `scrap_skiff.glb` reads
		# in `rift_derby.gd` (1.05-1.176 there, on the same 1.8 m human rig this
		# scene also uses). Same asset, same person standing next to it, so it
		# has to agree on how big a car is, not shrink because it changed files.
		altered_vehicle.scale = Vector3(1.15, 1.15, 1.15)
		enemy.add_child(altered_vehicle)
	add_child(enemy)


func _spawn_ashline_reinforcements() -> void:
	for index in 2:
		var encounter := {"instance_id": "mara_reinforcement_%d" % index, "kind": "hostile", "summary": "An Ashline knife came to keep Mara's second body alive."}
		_spawn_encounter_actor(encounter, enemy.global_position + Vector3(-6.0 if index == 0 else 6.0, 0, 4.0 + index * 2.0))


## AE.1 - AE.5. The yard's population. Five workers standing where they work,
## each of whom is a person rather than a silhouette: a name generated per save,
## a subject in `WorldHistory` with a faction, a role and a grudge, a real
## `BaselineHuman` body with anatomy under it, a lantern so the dusk the clock
## opens into does not swallow them, and a death that is a saved status change
## rather than a node that stopped drawing.
##
## Everything here goes through the infrastructure that already exists. The body
## is the same rig `_spawn_rival()` gives the captain and `_spawn_friend()`
## gives Nix. The identity is `CastNames`, which is where the captain's name has
## come from since v10.1. The state is `WorldHistory`, and a kill lands in
## `encounter_actors` and reaches `_kill_encounter_actor()` by exactly the road
## every misfire actor already takes - melee through
## `_attack_nearest_encounter_actor()`, firearms through `_resolve_body_hit()`.
## Nothing here is a second copy of any of that.
func _spawn_yard_population() -> void:
	_register_population_faction()
	var spawned: Array[String] = []
	for index in POPULATION_POSTS.size():
		var subject_id := _spawn_yard_worker(index)
		if not subject_id.is_empty():
			spawned.append(subject_id)
	WorldHistory.record_event("bone_yard_population_manned", {
		"location": HUNT_LOCATION,
		"faction_id": POPULATION_FACTION_ID,
		"posts": spawned.size(),
		"subjects": spawned.duplicate(),
	})


## AE.4. The yard is not staffed by nobody. Every worker generated below carries
## this faction, so F3's succession has something real to work with when one of
## them is killed: `wire_net.gd` looks up the dead worker's `faction_id`, opens a
## vacancy on this subject and refills it from whoever else of the roster is
## still alive. Registered with `register_subject()`, which fills in missing
## authored fields without ever erasing a wound, grudge or vacant post an older
## save has already earned.
func _register_population_faction() -> void:
	if not WorldHistory.subject(POPULATION_FACTION_ID).is_empty():
		return
	WorldHistory.register_subject(POPULATION_FACTION_ID, {
		"name": POPULATION_FACTION_NAME, "kind": "faction", "role": "Yard labour union",
		"threat": "LOW", "territory": "Bone Yard gate, mid road and wreck line",
		"doctrine": "Somebody has to cut the wrecks. Those who do get first refusal on what comes out of them.",
		"relations": {"player": {"kind": "known", "strength": 4}, CAST.id_for(CAPTAIN_SLOT): {"kind": "employer", "strength": 38}},
	})


## AE.1 / AE.2 / AE.3. One worker, posted at one offset from one of the region's
## own lamps, built through `_spawn_encounter_actor()` rather than around it.
##
## The encounter dictionary is the same shape `_spawn_ashline_reinforcements()`
## already passes - instance_id, kind, summary - which is the point of reusing
## it: the worker is an encounter actor in every sense, so `_update_encounter_actors()`
## moves them, they orbit and press openings, they can be disarmed, grappled,
## downed, spared and recruited, the witness ledger counts them, the map shows
## them, and the existing combat path wounds them without knowing anything new.
## What the two extra keys do is identity, which `_spawn_encounter_actor()` has
## no concept of and would otherwise invent a name for: `display_name` and
## `role` come out of `CastNames` off this post's own slot.
func _spawn_yard_worker(index: int) -> String:
	var post: Dictionary = POPULATION_POSTS[index]
	var slot := "%s%02d" % [POPULATION_SLOT_PREFIX, index]
	var who: Dictionary = CAST.person(slot)
	var role := str(post.get("role", who.get("role", "Yard hand")))
	var request: Dictionary = {
		"instance_id": slot,
		"kind": "hostile",
		"display_name": str(who["name"]),
		"role": role,
		"summary": "Works the Bone Yard %s. Carries a lantern, a quota and a grudge about both." % str(post.get("post", "floor")),
		"faction": POPULATION_FACTION_NAME,
		"faction_id": POPULATION_FACTION_ID,
		"loot": post.get("loot", ["yard scrip"]),
		"tint": str(post.get("tint", "6f5f4b")),
		"variation": int(post.get("variation", index)),
		"implant": post.get("implant", {}),
	}
	var spawned := _spawn_encounter_actor(request, _population_post_position(post))
	if spawned.is_empty():
		return ""
	# The subject id comes back from the actor that was actually built, not from
	# the name this asked for - `_spawn_encounter_actor()` derives its own id
	# from the instance id, and a worker restored from a save has to be written
	# back as the same person they were, wounds and all.
	var subject_id := str(spawned.get("subject_id", who["id"]))
	var body := spawned.get("node") as Node3D
	_light_population_lantern(body)
	_label_population_worker(body, str(spawned.get("display_name", who["name"])), role)
	# AE.1 / AE.4. The identity is written here rather than left on whatever
	# `_spawn_encounter_actor()` filled in, because this is the part that makes
	# a worker a person in the world's record rather than a generic encounter:
	# their post, their job, the union they work for, what the lantern means,
	# and the name `cast_names.gd` generated for this save. A grudge is seeded
	# rather than invented later, so the dossier has something to say about
	# somebody the player has not touched yet. The faction `cast_names.gd`
	# generated for them is kept alongside as `faction_origin`, since who they
	# came from is theirs and who they work for is the yard's.
	WorldHistory.update_subject(subject_id, {
		"name": str(spawned.get("display_name", who["name"])),
		"role": role,
		"post": str(post.get("post", "")),
		"faction": POPULATION_FACTION_NAME,
		"faction_id": POPULATION_FACTION_ID,
		"faction_origin": str(who["faction"]),
		"grudge": int(post.get("grudge", 0)),
		"lantern": true,
		"memory": str(request["summary"]),
	}, "bone_yard_post_manned")
	return subject_id


## AE.2. Where a post stands. Read off the lamp it belongs to so the population
## follows the lights if those ever move, and snapped through the same
## `pathfinder.safe_position()` every other spawn in this scene uses, so a worker
## is never placed inside a wreck pile's own footprint.
func _population_post_position(post: Dictionary) -> Vector3:
	var lamp: Dictionary = GATE_LIGHTS[clampi(int(post.get("lamp", 0)), 0, GATE_LIGHTS.size() - 1)]
	var lamp_at: Vector3 = lamp["at"]
	var offset: Vector2 = post.get("offset", Vector2.ZERO)
	return pathfinder.safe_position(Vector3(lamp_at.x + offset.x, POPULATION_STAND_Y, lamp_at.z + offset.y))


## AE.5. The lantern. Built through `_place_night_light()` - the one place this
## scene makes a light - then reparented onto the body that carries it, so it
## travels with whoever is holding it instead of hanging over the spot they used
## to stand on. `_update_day_night()` drives it off the same hour as the gate
## lamps because it is in `night_lights` like every other one, and
## `_place_night_light()` has already given it its warp shell and its bulb.
func _light_population_lantern(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	var lantern := _place_night_light(
		body.global_position + POPULATION_LANTERN_AT,
		Color("e8c46a"),
		POPULATION_LANTERN_ENERGY,
		POPULATION_LANTERN_REACH,
		false,
		0.22,
	)
	# Reparenting keeps nothing of the old global transform by default, so the
	# lamp is placed at its offset in the body's own frame - which is what an
	# offset from a hand means anyway.
	remove_child(lantern)
	body.add_child(lantern)
	lantern.position = POPULATION_LANTERN_AT


## AE.3. Who this is, over their head, in the same "<NAME> // <WHAT THEY ARE>"
## register the captain's own label already uses.
##
## The whole generated name goes up rather than just the forename: five people
## drawn from thirty-two forenames will collide often enough to matter, and two
## of the yard's workers sharing a given name would undo the one thing this
## population is for. `cast_names.gd` guarantees the full name is the stable,
## save-specific one, so that is what is on the body.
func _label_population_worker(body: Node3D, display_name: String, role: String) -> void:
	if body == null or not is_instance_valid(body):
		return
	var label := body.get_node_or_null("Identity") as Label3D
	if label == null:
		return
	label.text = "%s // %s" % [display_name.to_upper(), role.to_upper()]


func _spawn_blood(at: Vector3, amount: int) -> void:
	_wear_it(at, amount)
	@warning_ignore("integer_division")
	for index in mini(8, amount / 4):
		var piece := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.08 + float(index) * 0.012
		mesh.height = mesh.radius * 2
		mesh.material = _material(Color("6d100d"), 0.0)
		piece.mesh = mesh
		piece.position = at + Vector3(randf_range(-0.7, 0.7), randf_range(-0.2, 0.8), randf_range(-0.7, 0.7))
		add_child(piece)
		var timer := get_tree().create_timer(3.0 + randf())
		timer.timeout.connect(piece.queue_free)


## AG4.2. Greg: *"in the first person it has that blood splatter effects and
## just generally in the game make that more integral or just do more instead of
## just being lame asf"*.
##
## Every blood event in this scene goes through `_spawn_blood`, so this is the
## one place that has to know: if it happened close enough and in front of you,
## you are wearing some of it. Distance decides how much, and the direction from
## the middle of the screen to wherever it happened decides which way the
## spatter throws — so opening somebody on your left puts it on your left.
func _wear_it(at: Vector3, amount: int) -> void:
	if blood_veil == null or not is_instance_valid(blood_veil):
		return
	if camera == null or not is_instance_valid(camera):
		return
	var distance := camera.global_position.distance_to(at)
	# Arm's reach is a faceful. Past four metres it is somebody else's problem.
	if distance > 4.0:
		return
	var closeness := clampf(1.0 - (distance - 0.8) / 3.2, 0.0, 1.0)
	var weight := clampf(float(amount) / 34.0, 0.15, 1.0)
	var force := closeness * closeness * weight
	if force <= 0.02:
		return
	var from := Vector2.ZERO
	if not camera.is_position_behind(at):
		var on_screen := camera.unproject_position(at)
		var centre := blood_veil.size * 0.5
		if on_screen.distance_to(centre) > 1.0:
			from = (on_screen - centre).normalized()
	blood_veil.call("splash", force, from)


func _add_mesh(mesh: PrimitiveMesh, position_value: Vector3, scale_value: Vector3, color: Color, emission: float) -> void:
	_add_mesh_to(self, mesh, position_value, color, emission, scale_value)


func _add_mesh_to(parent: Node3D, mesh: PrimitiveMesh, position_value: Vector3, color: Color, emission: float, scale_value := Vector3.ONE) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	mesh.material = _material(color, emission)
	parent.add_child(instance)


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.38
	material.roughness = 0.7
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material
