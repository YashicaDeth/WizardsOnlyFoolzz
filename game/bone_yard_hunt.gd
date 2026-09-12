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
const VAULT_REACH := 0.85
const VAULT_FAR_SIDE := 0.55
const VAULT_HEAD_CLEARANCE := 1.55
const VAULT_DURATION := 0.34
## Worst case a wrecked body can move or swing at, as a share of healthy. The
## soulslike register wants injury to hurt; it does not want a player who has
## lost a leg to be unable to disengage from the thing that took it.
const PLAYER_INJURY_FLOOR := 0.55
## The person the hunt is about. Generated per save — see `cast_names.gd`.
const CAPTAIN_SLOT := "derby_captain"
const CAST := preload("res://systems/cast_names.gd")
const FRIEND_ID := "nix_arden"
const HUNT_LOCATION := "ashbloom_bone_yard"
const HANDHELD := preload("res://systems/handheld_device.gd")
const ANATOMY_COMPONENT := preload("res://systems/anatomy_component.gd")
const WORLD_GENERATOR := preload("res://systems/ashbloom_world_generator.gd")
const MISFIRE_DIRECTOR := preload("res://systems/reality_misfire_director.gd")
const SCRAP_SKIFF := preload("res://art/scrap_skiff.glb")
const HUNTER_MOTOR := preload("res://systems/hunter_motor.gd")
const BLOOD_VEIL := preload("res://systems/blood_veil.gd")
const PSYCHEDELIC_RIG := preload("res://systems/psychedelic_rig.gd")
const KEYS_CARD := preload("res://systems/keys_card.gd")
## AS1.1. Bright enough to actually read as a light source against
## `world_look.gd`'s low-ambient presets rather than a glow nobody would notice.
const HANDHELD_LAMP_ENERGY := 6.0
const BALLISTICS := preload("res://systems/ballistics.gd")
const LIMB_MOMENTUM := preload("res://systems/limb_momentum.gd")
const HUNTER_ARSENAL := preload("res://systems/hunter_arsenal.gd")
const HUNTER_BODY_MOTION := preload("res://systems/hunter_body_motion.gd")
const RIVAL_REGISTRY := preload("res://systems/rival_registry.gd")
const DEFEAT_ROUTER := preload("res://systems/defeat_router.gd")
const ASSET_NETWORK := preload("res://systems/asset_network.gd")
const COMBAT_RESPONSE := preload("res://systems/combat_response.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")
const LIVING_MAP := preload("res://systems/living_map.gd")
const WORLD_INDEX := preload("res://systems/world_index.gd")
const PIN_BOARD := preload("res://systems/pin_board.gd")
const IMPACT_FEEL := preload("res://systems/impact_feel.gd")
const ImplantCatalog := preload("res://systems/implant_catalog.gd")
const CARRION_SCAVENGER := preload("res://systems/carrion_scavenger.gd")
const RITUAL_LEDGER := preload("res://systems/ritual_ledger.gd")

var player := Vector3(0, 1.5, 19)
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
## AN1.2. The arm the weapon hangs off. Fed the same mouse delta the camera
## turns by, so the weapon is thrown by you turning rather than by a curve.
var arm: LimbMomentum = null
## Mouse movement this frame, in radians, accumulated in `_unhandled_input` and
## spent in `_physics_process`. It has to be a frame total rather than a
## per-event value: a 1000Hz mouse delivers several motion events per frame and
## handing the arm each one separately throws it several times as hard.
var _look_delta := Vector2.ZERO
## AN1.4/AN1.8. Whether `commitment()` reaches the damage number yet. The old
## swing stays authoritative until the new one is demonstrably better, which is
## a judgement to make with a controller in hand rather than in a commit.
var momentum_damage := false
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
var dodge_direction := Vector3.ZERO
## AD1.2. How long is left of the current vault, counting down from
## `VAULT_DURATION`; the body is not under normal movement control for as
## long as this is positive (see `_update_player()`'s own early branch).
var vaulting_time := 0.0
var vault_from := Vector3.ZERO
var vault_to := Vector3.ZERO
var handheld: Control
## FINAL_V.md §16. The one screen-space layer AS2's night warp, and later the
## drugs and shadow realms, all reach for instead of building their own effect.
var psychedelic: Control
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

## A4.1. Every placed light, so `_update_day_night()` can put them out at dawn
## without holding a second list of where they are.
var night_lights: Array[OmniLight3D] = []
## AS2. Built once in `_build_world()`, driven every frame in
## `_update_day_night()` off `world_clock.gd` — it used to sit at one fixed
## angle and brightness no matter the hour, which is why W1.1 existing made no
## visible difference until this read off it.
var sun: DirectionalLight3D
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
const GRAPPLE_PRESSURE_INTERVAL := 0.4
var grapple_pressure_clock := 0.0
## Test hook: set true/false to force the press state `_update_grapple` reads,
## since it is the one clinch input read as a raw button rather than an
## action and there is no display server to raise a real one against in a
## headless run. Leave null for real input to decide it, as normal play does.
var grapple_pushing_override: Variant = null
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
var pending_attack: Dictionary = {}
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
	handheld_lamp.position = Vector3(0.16, -0.14, -0.15)
	handheld_lamp.rotation_degrees = Vector3(-6, 4, 0)
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
	psychedelic = PSYCHEDELIC_RIG.new()
	psychedelic.name = "Psychedelic"
	$HUD.add_child(psychedelic)
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
	_build_player_rig()
	arsenal = HUNTER_ARSENAL.new()
	arsenal.name = "HunterArsenal"
	player_body.add_child(arsenal)
	arsenal.configure(player_rig)
	body_motion = HUNTER_BODY_MOTION.new()
	body_motion.name = "HunterBodyMotion"
	player_body.add_child(body_motion)
	body_motion.configure(player_rig)
	body_motion.set_perspective(not third_person)
	WorldHistory.register_subject("inventory", {"items": []})
	_spawn_friend()
	_spawn_rival()
	_update_camera()
	WorldHistory.record_event("player_entered_hunt_ground", {"location": HUNT_LOCATION, "hunt_id": CAST.id_for(CAPTAIN_SLOT)})


## The player had no body at all — only a `health` integer, the same defect the
## derby drivers carried. `health` stays the coarse survivability meter the loop
## and HUD are balanced around; the rig records *where* the damage is, renders it
## on the player's own limbs in first person, and persists it. Unifying the two
## numbers means rebalancing the whole hunt loop and is tracked in ROADMAP.md.
func _build_player_rig() -> void:
	player_rig = BaselineHuman.new()
	player_rig.name = "HunterBody"
	player_body.add_child(player_rig)
	# The capsule is centred on the controller origin, so drop the rig by half
	# its height to stand the feet on the floor rather than mid-shin.
	player_rig.position = Vector3(0, -0.9, 0)
	var saved: Dictionary = WorldHistory.subject("player")
	# D4.2. The race you were decanted as is a silhouette, not just a stat block.
	# A Marrow-Cut stands bigger than an Unreset, and until now every body in the
	# world was the same size whatever the sheet said.
	var race: Dictionary = CharacterSheet.RACES.get(str(saved.get("race", "decanted")), {})
	# The intake collected a face, a wear level, a blood type and whatever you
	# were grown with, and the body read none of it — every player walked out of
	# the vat the same colour, the same blood, and wearing a hardcoded torque arm
	# regardless of what the sheet said. Greg's report: "nothing with the
	# character creation modelling gets made".
	var appearance: Dictionary = saved.get("appearance", {})
	var sheet_anatomy: Dictionary = saved.get("anatomy", {})
	var wear := clampf(float(appearance.get("wear", 0.4)), 0.0, 1.0)
	var config := {
		# Face drives the rig's procedural variation, so two players with
		# different faces are not the same generated head.
		"variation": 1 + int(clampf(float(appearance.get("face", 0.5)), 0.0, 1.0) * 24.0),
		"flesh": Color("7a6350").darkened(wear * 0.35),
		"blood": _blood_volume(str(sheet_anatomy.get("blood_type", "O-RUST"))),
		"gore": viscera_fx,
		"build": float(race.get("build", 1.0)),
		"cybernetics": _grown_cybernetics(sheet_anatomy),
	}
	if saved.get("anatomy_state") is Dictionary:
		config["restore"] = saved.anatomy_state
	player_rig.gore = viscera_fx
	player_rig.build("player", config)
	hunter_appearance = HUNTER_APPEARANCE.new()
	hunter_appearance.name = "HunterAppearance"
	player_rig.add_child(hunter_appearance)
	hunter_appearance.configure(player_rig)


## Blood type is a choice on the intake sheet, so it has to mean something.
## Volumes are small differences rather than build-defining ones: a NULL carrier
## bleeds out faster than an O-RUST and that is the whole of it.
func _blood_volume(blood_type: String) -> float:
	match blood_type:
		"NULL": return 4200.0
		"SAP": return 5800.0
		"AB-": return 4900.0
		"B-9": return 5100.0
		"A-ASH": return 5000.0
		_: return 5200.0


## What you were grown with, rather than a hardcoded arm. An empty sheet still
## gets the salvaged torque arm, because the opening hands you one either way
## and a body with no history at all is not this game.
func _grown_cybernetics(sheet_anatomy: Dictionary) -> Dictionary:
	var grown: Dictionary = {}
	var listed: Variant = sheet_anatomy.get("cybernetics", [])
	for entry in ImplantCatalog.list(listed):
		grown[str(entry.zone)] = {
			"name": str(entry.name),
			"armor": float(entry.get("armor", 0.1)),
			"restores": 0.7,
		}
	if grown.is_empty():
		grown["right_arm"] = {"name": "salvaged torque arm", "armor": 0.22, "restores": 0.72}
	return grown


## Damage to the player, routed through the body so it lands on a real zone,
## bleeds from a real organ, and is still there next time.
func _wound_player(from: Vector3, damage: float, damage_type := "cut") -> void:
	if player_rig == null:
		return
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
	prompt.text = "YOUR %s IS GONE — BLEEDING HARD, STILL STANDING" % zone.replace("_", " ").to_upper()


func _register_people() -> void:
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


func _unhandled_input(event: InputEvent) -> void:
	if resolution_ui.visible or kill_cam.active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.pressed:
			_attack()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		_toggle_lock()
	if event is InputEventMouseButton and event.pressed and not lock_target.is_empty():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_lock(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_lock(-1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_attack(true)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _equip_weapon(0)
			KEY_2: _equip_weapon(1)
			KEY_3: _equip_weapon(2)
			KEY_4: _equip_carried_limb()
			KEY_5: _put_the_weapons_down()
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
			# L. The wall. It has existed since this morning and nothing opened it.
			KEY_P: _toggle_panel("board")
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
		apply_look(Vector2(event.relative.x * 0.0026, event.relative.y * 0.0024))


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
	_update_handheld_lamp(delta)
	# W1.1. The world keeps time, and exactly one place advances it — a clock
	# that two scenes both wind runs at double speed the moment anybody
	# builds a third.
	WorldClock.advance(delta)
	_update_day_night()
	dodge_remaining = maxf(0.0, dodge_remaining - delta)
	# O2.7 v3. scale_for() only ever reached the encounter loop's actor_delta —
	# the player is the other half of every exchange they are in and kept
	# ticking at full speed through their own hitstop, which is backwards: the
	# whole point of a local freeze is that both bodies in contact feel it.
	var player_delta: float = delta * impact_feel.scale_for("player")
	_advance_arm(player_delta)
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
	_update_carrion(delta)
	_update_extraction(delta, Input.is_key_pressed(KEY_H))
	# Q, not B. B is a stretch away from WASD with the left hand, and this is a
	# *hold* — you are meant to be moving while you do it. Greg: "make the b
	# slider change to like e or idk r or q"; E is interact and R is reload, so
	# Q is the one of the three that is actually free.
	_update_xray(delta, Input.is_key_pressed(KEY_Q))
	# Reports walk home in real time; F1.3's window only exists if it ticks.
	witness_ledger.tick(delta)
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
		var progress := 1.0 - vaulting_time / VAULT_DURATION
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		player_body.position = vault_from.lerp(vault_to, eased)
		if vaulting_time <= 0.0:
			player_body.position = vault_to
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
	jump_queued = false
	HUNTER_MOTOR.move_body(player_body, direction, speed, delta, dodge_direction if dodge_remaining > 0.0 else Vector3.ZERO, 16.0, JUMP_IMPULSE if jumping else 0.0)
	if jumping:
		WorldHistory.record_event("player_jumped", {"location": HUNT_LOCATION})
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
}


func _carry_current_weapon() -> void:
	if arm == null:
		return
	var id := "bare"
	if bare_handed:
		id = "bare"
	elif carried_limb_index >= 0:
		id = "severed_limb"
	elif arsenal != null:
		id = str(arsenal.current_id)
	var spec: Dictionary = ARM_WEIGHTS.get(id, ARM_WEIGHTS["sword"])
	if is_equal_approx(arm.mass, float(spec["mass"])):
		return
	arm.carry(float(spec["mass"]), float(spec["reach"]))


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


func _attack(heavy := false) -> void:
	if resolution_ui.visible or kill_cam.active or player_rig.is_downed() or player_rig.anatomy.dead:
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
	var swing := _player_swing_scale()
	# O5.1. The body's own motion is part of the blow.
	var momentum := swing_momentum(player_body.velocity)
	# AN1.4. What the arm was actually doing, measured. Recorded either way so
	# the two systems can be compared against the same swings; it only reaches
	# the damage number when `momentum_damage` says so (AN1.8).
	last_commitment = arm.commitment() if arm != null else 0.0
	report["commitment"] = last_commitment
	if momentum_damage and arm != null:
		# The weapon sets the ceiling and the player earns how much of it they
		# get. Floored well above zero: a game where a mistimed swing does
		# nothing at all is a game that feels broken rather than demanding.
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
	if _attack_nearest_encounter_actor(report):
		if arm != null:
			arm.strike(0.65, Vector3(sin(yaw), 0.0, cos(yaw)))
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
		var wound := enemy_rig.hit_at(aim, float(damage), float(damage) * 0.8, "cut", look)
		body_zone = str(wound.get("zone", "torso"))
		WorldHistory.update_subject(CAST.id_for(CAPTAIN_SLOT), {"anatomy_state": enemy_rig.snapshot()}, "anatomy_changed")
	if enemy_rig != null and is_instance_valid(enemy_rig):
		enemy_health = roundi(float(enemy_health_max) * _rig_health_ratio(enemy_rig))
	else:
		enemy_health = maxi(0, enemy_health - damage)
	_spawn_blood(enemy.global_position + Vector3(0, 1.2, 0), damage)
	WorldHistory.record_event("melee_body_hit", {"target": CAST.id_for(CAPTAIN_SLOT), "body_zone": body_zone, "damage": damage, "location": HUNT_LOCATION})
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


func _attack_nearest_encounter_actor(attack: Dictionary = {}) -> bool:
	if attack.is_empty():
		attack = {"damage": 24.0, "impulse": 18.0, "damage_type": "cut", "range": 4.1, "weapon": "sword"}
	var nearest_index := -1
	var nearest_distance := 99999.0
	for index in encounter_actors.size():
		var actor: Dictionary = encounter_actors[index]
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(actor.get("dead", false)):
			continue
		if actor.anatomy.downed or str(actor.get("disposition", "hostile")) != "hostile":
			continue
		var distance := player.distance_to(node.global_position)
		# A locked target wins regardless of who has wandered closer, which is
		# the entire reason to have a lock.
		if not lock_target.is_empty() and str(actor.subject_id) == lock_target:
			nearest_distance = distance
			nearest_index = index
			break
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	var reach := float(attack.get("range", 4.1))
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
	var organ_hit := str((result.get("organ", {}) as Dictionary).get("zone", ""))
	if not organ_hit.is_empty() and bool((result.get("organ", {}) as Dictionary).get("ruptured", false)):
		prompt.text = "%s IS OPENED UP" % str(actor.display_name).to_upper()
	WorldHistory.update_subject(str(actor.subject_id), {"anatomy_state": anatomy.call("snapshot")}, "anatomy_changed")
	_spawn_blood(target.global_position + Vector3(0, 1.1, 0), roundi(float(attack.damage)))
	WorldHistory.record_event("npc_anatomy_hit", {"subject_id": actor.subject_id, "weapon": attack.weapon, "zone": zone, "result": result, "location": HUNT_LOCATION})
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
	return true


## AF1.2. Where a round that missed everybody ended up. The world keeps the
## hole (the projectile draws that itself) and the record keeps the fact,
## which is what AB2 will read when destruction is tracked properly.
func _on_round_hit(hit: Dictionary) -> void:
	var struck: Variant = hit.get("collider")
	if struck != null and struck is Node and (struck as Node).is_in_group("actor_body"):
		return
	WorldHistory.record_event("round_struck_world", {
		"calibre": str(hit.get("calibre", "")),
		"energy": snappedf(float(hit.get("energy", 0.0)), 0.01),
		"shooter": str(hit.get("shooter", "")),
		"location": HUNT_LOCATION,
	})


func _resolve_firearm(attack: Dictionary) -> void:
	var forward := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	var origin := camera.global_position + forward * 0.48
	var impacts: Dictionary = {}
	var directions: Array[Vector3] = arsenal.shot_directions(forward, Vector3.UP)
	# AF1. The visible round. Damage to a body still resolves below on the
	# frame it is fired — moving that onto the projectile means deferring
	# every anatomy hit by a few frames and is a change worth making on its
	# own rather than folded into this one (AF1.1 stays open). What this
	# buys now is everything the raycast could never do: a round you can
	# see travel, a hole where it went wide, and brass on the floor.
	if ballistics != null and is_instance_valid(ballistics):
		var calibre := "buck" if directions.size() > 1 else "pistol"
		for direction in directions:
			ballistics.fire(origin, direction, calibre, 0.0, 1, "player")
	for direction in directions:
		var hit := _trace_actor(origin, direction, float(attack.range))
		if hit.is_empty():
			continue
		var actor: Dictionary = hit.actor
		var rig := actor.rig as BaselineHuman
		var result := rig.hit_at(hit.position, float(attack.damage), float(attack.impulse), str(attack.damage_type), direction)
		var id := str(actor.subject_id)
		if not impacts.has(id):
			impacts[id] = {"actor": actor, "zones": [], "damage": 0.0, "ruptures": [], "severed": []}
		var summary: Dictionary = impacts[id]
		summary.zones.append(str(result.get("zone", "torso")))
		summary.damage = float(summary.damage) + float(result.get("damage", 0.0))
		var organ := result.get("organ", {}) as Dictionary
		if bool(organ.get("ruptured", false)):
			summary.ruptures.append(str(organ.get("zone", "internal")))
		if bool(result.get("severed", false)):
			summary.severed.append(str(result.get("zone", "limb")))
		impacts[id] = summary
		(actor.node as CharacterBody3D).velocity += direction * minf(6.0, float(attack.impulse) * 0.075)
		# O2.2. Time, camera and sound on the same frame. Severity is measured
		# against the zone's own health so a cleaver through a head reads
		# heavier than the same cleaver through a thigh.
		var zone_id := str(result.get("zone", "torso"))
		var zone_max: float = float((AnatomyComponent.DEFAULT_ZONES.get(zone_id, {}) as Dictionary).get("health", 100.0))
		impact_feel.strike(
			float(attack.get("damage", 0.0)) / maxf(zone_max, 1.0),
			str(attack.get("damage_type", "cut")),
			bool(result.get("severed", false)),
			# O2.5 v2. Only the two of you are in this. Everyone else in the
			# region keeps fighting at full speed.
			["player", str(actor.subject_id)]
		)
		if actor.rig != null and is_instance_valid(actor.rig):
			actor.rig.favour_injuries()
	for id in impacts:
		var summary: Dictionary = impacts[id]
		var actor: Dictionary = summary.actor
		WorldHistory.update_subject(id, {"anatomy_state": actor.rig.snapshot()}, "anatomy_changed")
		WorldHistory.record_event("firearm_anatomy_hit", {
			"subject_id": id, "weapon": attack.weapon, "zones": summary.zones,
			"damage": snappedf(float(summary.damage), 0.1), "ruptures": summary.ruptures, "severed": summary.severed,
			"location": HUNT_LOCATION,
		})
		if actor.anatomy.dead:
			_kill_encounter_actor(encounter_actors.find(actor), str(attack.weapon))
		elif actor.anatomy.downed:
			actor.state = "downed"
		elif not (summary.severed as Array).is_empty():
			_apply_maiming_state(actor, summary.severed, forward)
		elif actor.anatomy.critical or actor.anatomy.pain >= 68.0:
			actor.state = "fleeing"
			actor.loot_at_risk = true
		else:
			_apply_combat_response(actor, attack, {"pain": actor.anatomy.pain})
	if impacts.is_empty():
		impact_feel.whiff()
		# O2.3 / O5.7. A miss was already free of damage; it is no longer free of
		# balance. Swinging at air is how you end up on your heels.
		lose_footing(FOOTING_WHIFF, "SWUNG AT NOTHING")
		prompt.text = "%s / MISS" % str(arsenal.current().label)
	else:
		prompt.text = "%s / %d BODY%s HIT" % [str(arsenal.current().label), impacts.size(), "IES" if impacts.size() != 1 else ""]
	WorldHistory.record_event("weapon_fired", {"weapon": attack.weapon, "hits": impacts.keys(), "location": HUNT_LOCATION})


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


func _player_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [player_body.get_rid()]
	for zone_id in BaselineHuman.ZONES:
		var hitbox := player_rig.get_node_or_null("%s_hitbox" % zone_id) as CollisionObject3D
		if hitbox != null:
			exclusions.append(hitbox.get_rid())
	return exclusions


## O5.8. Put everything down. Not a weapon slot — the absence of one.
func _put_the_weapons_down() -> void:
	_clear_carried_limb_model()
	bare_handed = true
	pending_attack = {}
	strike_windup = -1.0
	prompt.text = "HANDS"


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
	bare_handed = false
	_clear_carried_limb_model()
	if arsenal.select_slot(slot):
		pending_attack = {}
		strike_windup = -1.0
		# The ammo well and the model in the player's hand already show the new
		# weapon. A persistent READY subtitle duplicated both of them.
		prompt.text = ""


func _reload_weapon() -> void:
	if carried_limb_index >= 0:
		prompt.text = "THAT IS AN ARM, NOT A GUN"
		return
	if arsenal.reload():
		body_motion.trigger_reload(float(arsenal.current().reload))
		# Reloading is visible as a cartridge travelling through the well.
		prompt.text = ""


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
func _update_handheld_lamp(delta: float) -> void:
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
	var waver := 1.0 + sin(pulse * 11.0) * 0.03 * (1.0 + (1.0 - charge) * 2.5)
	# Below a fifth of a charge it starts guttering rather than merely dimming.
	if charge < 0.2:
		var gutter := 1.0 if fmod(pulse * (5.0 + (0.2 - charge) * 40.0), 1.0) > 0.5 else 0.0
		waver *= 0.7 + 0.3 * gutter
	handheld_lamp.light_energy = 9.0 * charge * waver
	# A4.2. The air the beam bends answers the same battery the beam does, so a
	# guttering torch bends it in the same stutter rather than holding a steady
	# shimmer over a dying light.
	if handheld_warp != null and is_instance_valid(handheld_warp):
		handheld_warp.set_amount(clampf(handheld_lamp.light_energy / 9.0, 0.0, 1.0))


## AD1.2. Empty means "not vaultable", never a crash — every one of these
## rays is allowed to simply miss, because most things in front of the
## player most of the time are not a low wall.
func _vault_target(direction: Vector3) -> Dictionary:
	if not panel_mode.is_empty() or resolution_ui.visible or not grapple_target.is_empty():
		return {}
	if direction.is_zero_approx() or crouching or vaulting_time > 0.0:
		return {}
	if not player_body.is_on_floor():
		return {}
	var space := get_world_3d().direct_space_state
	var exclusions := _player_collision_exclusions()
	var feet: Vector3 = player_body.position + Vector3.UP * -0.9
	var low_query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.4, feet + Vector3.UP * 0.4 + direction * VAULT_REACH)
	low_query.exclude = exclusions
	var low_hit := space.intersect_ray(low_query)
	if low_hit.is_empty():
		return {}
	var high_query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * VAULT_MAX_TOP, feet + Vector3.UP * VAULT_MAX_TOP + direction * VAULT_REACH)
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
		Vector3(probe_x, feet.y + VAULT_MAX_TOP + 0.2, probe_z),
		Vector3(probe_x, feet.y + VAULT_MIN_TOP - 0.1, probe_z))
	top_query.exclude = exclusions
	var top_hit := space.intersect_ray(top_query)
	if top_hit.is_empty():
		return {}
	var top_pos: Vector3 = top_hit.position
	var obstacle_height: float = top_pos.y - feet.y
	if obstacle_height < VAULT_MIN_TOP or obstacle_height > VAULT_MAX_TOP:
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
	vaulting_time = VAULT_DURATION
	vault_from = player_body.position
	vault_to = landing
	player_body.velocity = Vector3.ZERO
	WorldHistory.record_event("player_vaulted", {"location": HUNT_LOCATION})


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
	if not player_body.is_on_floor():
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
			WorldHistory.record_event("melee_body_hit", {"target": CAST.id_for(CAPTAIN_SLOT), "body_zone": str(wound.get("zone", "torso")), "damage": 30, "location": HUNT_LOCATION})
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
				var bond := int(WorldHistory.subject(FRIEND_ID).get("bond", 0))
				WorldHistory.update_subject(FRIEND_ID, {"bond": bond + 5}, "misfire_bond")
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
			var items: Array = WorldHistory.subject("inventory").get("items", []).duplicate()
			items.append_array(cache.get_meta("items", []))
			WorldHistory.update_subject("inventory", {"items": items}, "loot_collected")
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
	WorldHistory.record_event("canonical_hunt_encounter_started", {"hunter": "player", "target": CAST.id_for(CAPTAIN_SLOT), "location": HUNT_LOCATION, "encounter_number": mara_encounter_number})
	if mara_encounter_number == 2:
		_spawn_ashline_reinforcements()
		prompt.text = "SECOND HUNT // %s: INDUSTRIAL ARM, REBUILT WRECKER, TWO ASHLINE KNIVES." % _captain_name()
	else:
		prompt.text = "HUNT ARC: %s has found you. Do not kill the story; make them remember." % _captain_name()


func _update_rival(delta: float) -> void:
	if enemy == null or enemy_retreating or story_step < 2:
		return
	var to_player := player - enemy.global_position
	to_player.y = 0
	var distance := to_player.length()
	if distance > 3.2:
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
		elif str(actor.get("disposition", "hostile")) == "hostile" and distance < 24.0 and distance > 3.0:
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
					health = maxi(1, health - roundi(float(guarded.get("damage", incoming))))
					_wound_player(node.global_position, maxf(5.0, 15.0 * _actor_combat_ratio(actor)), "cut")


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


func _actor_attack_cycle(actor: Dictionary) -> float:
	# O5.10 v2. Off-balance on top of whatever their arms already cost them —
	# a fighter who is barely standing winds up slower than their combat_ratio
	# alone would say, the same way a player who is stumbling swings softer.
	return lerpf(2.4, 1.4, _actor_combat_ratio(actor)) * lerpf(1.6, 1.0, _actor_footing(actor))


func _actor_attack_damage(actor: Dictionary) -> int:
	return maxi(2, roundi(9.0 * _actor_combat_ratio(actor) * lerpf(0.55, 1.0, _actor_footing(actor))))


func _apply_combat_response(actor: Dictionary, attack: Dictionary, hit: Dictionary) -> void:
	var response := COMBAT_RESPONSE.from_hit(attack, actor.anatomy, hit)
	# O5.10 v2. Every landed hit costs footing on its own scale — this used to
	# leave no mark at all below the stagger threshold, so a fighter chipped
	# by three medium blows fought exactly as well as one who had taken none,
	# right up until the fourth one crossed the line.
	_actor_lose_footing(actor, clampf(float(response.severity) / COMBAT_RESPONSE.STAGGER_THRESHOLD * 0.3, 0.05, 0.5))
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
	WorldHistory.update_subject(str(actor.subject_id), {"status": "dead", "memory": "The Hunter caught them before escape.", "anatomy_state": anatomy.call("snapshot")}, "npc_killed")
	var succession := WireNet.new(WireNet.SIGNAL_SURFACE)
	var vacancy := succession.open_vacancy(str(actor.subject_id))
	if not vacancy.is_empty():
		# The vacancy is written first and remains a separate historical fact;
		# succession resolves on the following idle turn from the existing roster.
		call_deferred("_fill_faction_vacancy", str(WorldHistory.subject(str(actor.subject_id)).get("faction_id", "")), str(vacancy.rank))
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


func _fill_faction_vacancy(faction_id: String, rank: String) -> void:
	if faction_id.is_empty():
		return
	var succession := WireNet.new(WireNet.SIGNAL_SURFACE)
	succession.promote_successor(faction_id, rank)

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
	if outcome == "execute":
		var finish := _execution_target(actor)
		actor.rig.hit(str(finish[0]), 100.0, 30.0, "puncture", str(finish[1]))
		actor.rig.execute()
		var snapshot: Dictionary = actor.rig.snapshot()
		WorldHistory.record_event("npc_resolution", {"subject_id": id, "outcome": outcome, "actor": "player", "zone": finish[0], "organ": finish[1], "anatomy_state": snapshot})
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
		WorldHistory.record_event("npc_resolution", {"subject_id": id, "outcome": outcome, "actor": "player", "witnesses": [id]})
		if outcome == "spare":
			RIVAL_REGISTRY.consider(id)
		misfire_director.resolve(str(actor.get("encounter_id", "")), actor.state)
		var label := actor.node.get_node_or_null("Identity") as Label3D
		if label != null:
			label.text = "%s / %s" % [str(actor.display_name).to_upper(), str(actor.state).to_upper()]
	prompt.text = "DISPOSITION RECORDED / " + outcome.to_upper()
	attack_cooldown = 0.72


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
	WorldHistory.record_event("proximity_voice_addressed", {"speaker": "player", "listener": subject_id, "duration": result.duration, "location": HUNT_LOCATION, "raw_audio_saved": false})
	WorldHistory.update_subject(subject_id, {"last_voice_contact": WorldHistory.event_count(), "memory": "The Hunter spoke to me while I was downed."}, "voice_contact_remembered")
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


## Live contacts for the map, expressed as plain data so the map never reaches
## into the hunt loop for them.
func _map_contacts() -> Array:
	var contacts: Array = []
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
	strike_windup = -1.0
	WorldHistory.record_event("grapple_started", {"subject_id": grapple_target, "zone": grapple_zone, "location": HUNT_LOCATION})


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
	if not message.is_empty():
		prompt.text = message


## Advantage runs from -1 to 1. The player pushes by holding the strike button;
## the opponent pushes back with whatever their arms and their pain leave them.
func _update_grapple(delta: float) -> void:
	var actor := _actor_by_id(grapple_target)
	if actor.is_empty() or bool(actor.get("dead", false)) or actor.anatomy.downed:
		_break_grapple()
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
		var flat_right := Vector3(flat_forward.z, 0, -flat_forward.x)
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
	prompt.text = "CLINCH / %s%s   %+d   [LMB] PRESS  [WASD] WALK THEM  [V] TALK  [X] LEAN  [H] TAKE  [SPACE] BREAK" % [
		str(actor.display_name).to_upper(), grip_note, roundi(grapple_advantage * 100.0),
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
func _take_photograph() -> Dictionary:
	if not panel_mode.is_empty() or resolution_ui.visible:
		return {}
	var photo := FieldCamera.capture(camera, _all_rigs(), HUNT_LOCATION)
	FieldCamera.store(photo)
	WorldHistory.record_event("photograph_taken", {
		"photo": str(photo.id),
		"in_frame": (photo.contents as Array).size(),
		"location": HUNT_LOCATION,
	})
	# E3.3. A rite is satisfied by doing the thing and recording it. The photo is
	# submitted as it is taken; there is no separate acceptance screen or button
	# that could make the evidence into a menu chore.
	var ritual_result := RITUAL_LEDGER.submit_photo(photo)
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
	if not changes.is_empty():
		WorldHistory.update_subject(id, changes, "clinch_%s" % verb)
	WorldHistory.record_event("clinch_%s" % verb, {
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
		WorldHistory.update_subject(id, {"status": "surrendered", "anatomy_state": actor.rig.snapshot()}, "clinch_surrender")
		_break_grapple("%s GIVES UP — [E] DECIDE" % str(actor.display_name).to_upper())


## Winning drops them into the downed window rather than killing them. The
## takedown itself is blunt trauma to the head and torso, so the body carries a
## record of how it was beaten and the resolution form shows it.
func _finish_grapple(actor: Dictionary) -> void:
	var rig := actor.rig as BaselineHuman
	rig.hit("head", 26.0, 18.0, "blunt")
	rig.hit("torso", 30.0, 20.0, "blunt")
	if not actor.anatomy.downed and not actor.anatomy.dead:
		actor.anatomy.go_down()
	WorldHistory.record_event("grapple_takedown", {"subject_id": str(actor.subject_id), "location": HUNT_LOCATION})
	WorldHistory.update_subject(str(actor.subject_id), {"anatomy_state": rig.snapshot()}, "anatomy_changed")
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
			["R", "RELOAD"],
			["HOLD Q", "X-RAY, THEN THE WHEEL"],
		]},
		{"group": "HANDS ON", "rows": [
			["E", "INTERACT"],
			["C", "GRAPPLE"],
			["V", "PERSUADE"],
			["X", "THREATEN"],
			["H", "EXTRACTION"],
			["N", "PHOTOGRAPH"],
		]},
		{"group": "WHAT YOU CARRY", "rows": [
			["G", "THE DEVICE"],
			["TAB", "WORLD INDEX"],
			["M", "LIVING MAP"],
			["T", "CHARACTER TREE"],
			["P", "THE BOARD"],
			["J", "ALLUSIONS / SIGIL"],
			["HOLD L", "LEAN INTO THE SCREEN"],
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
	var lens: Array = [blood_veil, psychedelic]
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
	if field_interface.has_method("set_state"):
		field_interface.set_state({
			"health": health,
			"stamina": stamina,
			"rival_status": WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT)).get("status", "dormant"),
			"rival_name": _captain_name(),
			"menu_open": world_index.visible or character_archive.visible or allusions_artwork.visible or living_map.visible,
			"menu_mode": panel_mode,
			"weapon": arsenal.state() if arsenal != null else {},
			"lock_screen": lock_screen,
		})


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
			var focus: Vector3 = subject.node.global_position + Vector3.UP * 0.65
			var away := player - focus
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3.BACK
			away = away.normalized()
			var shoulder := Vector3(-away.z, 0, away.x) * 1.05
			var desired := player + away * 3.1 + shoulder * 0.85 + Vector3.UP * 1.55
			var ray := PhysicsRayQueryParameters3D.create(focus, desired)
			var excluded: Array[RID] = [player_body.get_rid()]
			if subject.node is CollisionObject3D:
				excluded.append((subject.node as CollisionObject3D).get_rid())
			ray.exclude = excluded
			var obstruction := get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstruction.is_empty():
				desired = obstruction.position + (focus - obstruction.position).normalized() * 0.35
			camera.global_position = desired
			camera.look_at(focus, Vector3.UP)
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
	_add_mesh(BoxMesh.new(), Vector3(0, -0.6, 0), Vector3(470, 1, 370), Color("17150f"), 0.0)
	var floor_body := StaticBody3D.new()
	var floor_collider := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(470, 1, 370)
	floor_collider.shape = floor_shape
	floor_body.position.y = -0.6
	floor_body.add_child(floor_collider)
	add_child(floor_body)
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
		env.ambient_light_energy = lerpf(0.16, 0.72, daylight)
		env.tonemap_exposure = lerpf(0.85, 1.18, daylight)
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
				(light.get_meta("glass") as StandardMaterial3D).emission_energy_multiplier = BULB_GLOW * (1.0 - daylight)


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


func _on_reality_misfire(encounter: Dictionary, at: Vector3) -> void:
	WorldHistory.record_event("reality_misfire_triggered", {"encounter": encounter.duplicate(true), "location": HUNT_LOCATION})
	var title_text := str(encounter.get("title", "REALITY MISFIRE"))
	var summary := str(encounter.get("summary", "Something impossible notices you."))
	prompt.text = "REALITY MISFIRE // %s\n%s" % [title_text, summary]
	var kind := str(encounter.get("kind", "mystery"))
	if kind in ["hostile", "boss"]:
		_spawn_encounter_actor(encounter, at)
	else:
		_spawn_misfire_marker(title_text, summary, at, kind, str(encounter.instance_id))


func _spawn_encounter_actor(encounter: Dictionary, at: Vector3) -> void:
	var subject_id := "%s_actor" % str(encounter.get("instance_id", "misfire"))
	var saved_actor := WorldHistory.subject(subject_id)
	if str(saved_actor.get("status", "")) in ["dead", "escaped"]:
		return
	var display_name := "Ashline Tollkeeper" if str(encounter.kind) == "hostile" else "Dead Weather Saint"
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
	identity.text = "%s\nELO %04d" % [display_name.to_upper(), 1110 if str(encounter.kind) == "hostile" else 1510]
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
	var rig_config := {
		"flesh": Color("70201c") if str(encounter.kind) == "hostile" else Color("586c3a"),
		"variation": subject_id.length(),
		"gore": viscera_fx,
		"blood": 5200.0 if str(encounter.kind) == "boss" else 4300.0,
		# Named, not just an armour number. Before B2 an implant *was* its armour
		# value, so this passed an anonymous dictionary and every Ashline body
		# ended up carrying a part the catalogue could only call "unknown
		# hardware" — visible in the dossier and robbable as nothing in
		# particular. The armour override keeps the encounter balance it was
		# tuned with; the name gives it a zone, a condition and a real mesh.
		"cybernetics": {"torso": {"name": "ceramic sternum", "armor": 0.18}},
	}
	if saved_actor.get("anatomy_state") is Dictionary:
		rig_config["restore"] = saved_actor.anatomy_state
	rig.gore = viscera_fx
	rig.build(subject_id, rig_config)
	var anatomy: Node = rig.anatomy
	var loot := ["Ashline toll teeth", "rust scrip"] if str(encounter.kind) == "hostile" else ["weather-heart filament", "dead god relay"]
	encounter_actors.append({"subject_id": subject_id, "display_name": display_name, "node": actor, "rig": rig, "anatomy": anatomy, "state": "hunting", "disposition": "hostile", "speed": 3.7, "loot": loot, "loot_at_risk": false, "dead": false})
	encounter_actors.back()["encounter_id"] = str(encounter.get("instance_id", ""))
	if str(saved_actor.get("status", "")) in ["spared", "recruited"]:
		encounter_actors.back().state = str(saved_actor.status)
		encounter_actors.back().disposition = "ally" if str(saved_actor.status) == "recruited" else "neutral"
	WorldHistory.register_subject(subject_id, {"name": display_name, "kind": "person", "role": str(encounter.kind), "elo": 1110 if str(encounter.kind) == "hostile" else 1510, "status": "encountered", "memory": summary_from(encounter), "wounds": [], "anatomy": anatomy.call("snapshot"), "relations": {"player": {"kind": "enemy", "strength": 35}}})


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


func _spawn_loot_cache(at: Vector3, items: Array) -> void:
	var cache := Node3D.new()
	cache.position = at
	add_child(cache)
	loose_loot.append(cache)
	cache.set_meta("items", items.duplicate())
	_add_mesh_to(cache, BoxMesh.new(), Vector3(0, 0.35, 0), Color("c08134"), 0.35)
	var label := Label3D.new()
	label.text = "LOOT // %s" % ", ".join(PackedStringArray(items))
	label.position = Vector3(0, 1.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cache.add_child(label)


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
		if str(adaptation.get("kind", "")) == "prosthetic":
			enemy_rig.install_prosthetic(str(adaptation.get("zone", "left_arm")), {"name": str(adaptation.get("item", "Ashline industrial limb")), "armor": 0.34, "restores": 0.82, "tint": Color("c15d2d")})
		var altered_vehicle := SCRAP_SKIFF.instantiate()
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


func _spawn_blood(at: Vector3, amount: int) -> void:
	_wear_it(at, amount)
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
