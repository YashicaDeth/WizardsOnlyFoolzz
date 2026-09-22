extends Node3D

## The gore sandbox. Playable, not a capture harness.
##
## Greg: *"please quickly make a demo playable gore explosions demo"*, alongside
## a note about Sniper Elite executions and Mortal Kombat, and the good part of
## that note: *"i can make the slow mo psychedelic abstract and arty"*.
##
## Everything here already existed and none of it had anywhere to be looked at.
## `BaselineHuman` has zones, organs, bones, severing and an X-ray;
## `GoreChunks` tracks and rots what comes off; `impact_feel` holds the two
## bodies in an exchange without touching the world clock; `ballistics` puts a
## round through a body and leaves the casing on the floor. This is a room where
## all of that can be aimed at something, repeatedly, without playing the game
## to get to it.
##
## It is deliberately a sandbox rather than a level: spawn, wreck, slow it down,
## look inside, reset. That is what a gore system needs to be tuned against, and
## it is also the thing to point a camera at when somebody asks what the game is.
##
## Five things had to be true before any of that was playable, and none of them
## were. Each one failed silently, which is why the scene looked finished:
##
## 1. **Bullets went through everybody.** `Ballistics` traced its rounds with
##	  `collide_with_areas = false`, and every hitbox on a `BaselineHuman` is an
##	  `Area3D`, so a round passed through a body and stopped on the wall behind
##	  it. The workaround was an instant hitscan resolved on the frame the trigger
##	  went down, with the visible round fired alongside it and explicitly marked
##	  cosmetic. Greg, on that: *"the guns dont have bullets that come out hit the
##	  models and destroy there bodys bullet by bullet"* — which is exactly right,
##	  because the thing you could see was not the thing that did the damage.
##
##	  AF1.1 fixed the trace (`_step_rounds` asks for areas now), so the
##	  workaround has no reason to exist. One round leaves the barrel, travels,
##	  and the anatomy is opened in `_on_round_hit()` at the moment that round
##	  actually arrives — the same contract `bone_yard_hunt.gd` runs on. Nothing
##	  here resolves damage at the trigger; the trigger only spends a round,
##	  throws the brass and kicks the gun.
## 2. **The X-ray was a call to nothing.** It asked the rig for `set_xray()`,
##	  which does not exist, behind a `has_method` guard that swallowed it. It is
##	  `reveal_organs()` for the organs and bones, and `see_through()` so they
##	  win the depth test against the body standing in front of them.
## 3. **A blast only ever hit the torso.** Six zones were resolved through
##	  `hit_at()` at one shared point in space, and `hit_at()` maps a point to
##	  its nearest zone. Each zone is hit in its own right now.
## 4. **A blast could not take a limb off.** Severing comes from `cut`, `shear`
##	  or `ballistic` only (`BaselineHuman.SEVERING_DAMAGE`), and the blast was
##	  `blunt` — so the gore *explosion* demo was the one thing in this project
##	  that could not dismember anybody. Close in it shears; further out it stays
##	  blunt, which is the difference between being inside a blast and near one.
## 5. **Nothing read `ImpactFeel` back.** v2 deliberately stopped touching the
##	  global clock: it is a value you ask for, not an effect it applies. The
##	  scene called `strike()` and then never asked, so the camera never moved.
##
## The clock here is the scene own, on purpose — this is a sandbox whose whole
## point is bending time, so it holds `Engine.time_scale` itself and counts its
## hitstop in real seconds rather than leaving the feeler to fight it for it.

const BASELINE := preload("res://systems/baseline_human.gd")
const BALLISTICS := preload("res://systems/ballistics.gd")
const IMPACT_FEEL := preload("res://systems/impact_feel.gd")
const CellOutzType := preload("res://systems/celloutz_type.gd")
const SUBSTANCE_STATION := preload("res://systems/substance_station.gd")
const SUBSTANCES := preload("res://systems/substances.gd")
const SUBSTANCE_EXPERIENCE := preload("res://systems/substance_experience.gd")
const SMOKEABLES := preload("res://systems/smokeables.gd")
const PSYCHEDELIC_RIG := preload("res://systems/psychedelic_rig.gd")
const HELD_GEAR := preload("res://systems/held_gear.gd")
const BODY_MOTION := preload("res://systems/hunter_body_motion.gd")
# The range exists to show what the gore systems do, and had none of the ones
# built since. Greg: *"make the gore sandbox have all the main game changes"*.
const SKULL_BURST := preload("res://systems/skull_burst.gd")
const CAVITY := preload("res://systems/cavity.gd")
const KILL_SHOT := preload("res://systems/kill_shot.gd")
const KILL_CAM := preload("res://systems/kill_cam.gd")
const LIMB_MOMENTUM := preload("res://systems/limb_momentum.gd")
## The Hunt panel. Greg, on the range: it *"dosent have the lungs or the bottom
## right bottom left and top right person stuff minimap 3d model of the weapon
## or item your holding"*. All of that is one `Control` the Hunt has had all
## along and the sandbox drew its own smaller version of -- so the range has
## been showing a different game to the one it is a range for.
const FIELD_HUD := preload("res://systems/gothic_field_hud.gd")
## The satellite the minimap is a picture from. `gothic_field_hud._draw_minimap`
## returns on the first line when `minimap_texture` is null, so the panel came
## across with its bottom-left corner simply missing -- the one thing Greg
## pointed at. The image is the live region camera, not a radar the HUD draws.
const LIVING_MAP := preload("res://systems/living_map.gd")

const BODY_COUNT := 7
const ARENA := 26.0
## How far a blast reaches. Bodies past this are spectators.
const BLAST_REACH := 9.0
## Inside this fraction of the reach a blast shears rather than bruises, which
## is the line between losing an arm and being thrown across the room.
const SHEAR_BAND := 0.45
## Limbs first, head last.
##
## `AnatomyComponent` refuses every hit once the body is dead, and a penetrating
## hit to the head ruptures a fatal organ. `BaselineHuman.ZONES` begins at the
## head — so a blast big enough to kill resolved the kill on its first zone and
## was turned away from the five that were left. Turned away silently, too:
## `hit()` never checks whether the anatomy accepted, so every refused zone
## still sprayed and still shed chunks. The room filled with gore, the body kept
## every limb it had, and nothing anywhere said no. Order is the whole fix —
## what comes off comes off before what kills.
const BLAST_ORDER := ["left_arm", "right_arm", "left_leg", "right_leg", "torso", "head"]
## What the clock drops to on contact, and for how long in real seconds. Small
## on purpose: past about 150ms a hitstop reads as a frame drop, not as a hit.
const HITSTOP_SCALE := 0.08
const HITSTOP_SHOT := 0.055
const HITSTOP_BLAST := 0.13
## Held slow motion. The dial this scene exists to turn.
const SLOW_SCALE := 0.14
const TRACE_RANGE := 90.0
const SANDBOX_SUBJECT := "sandbox_player"
## AF6.1. A weapon is learned from a thing in the room, not only from a number
## key. This is deliberately the same short reach as the substance station:
## taking something means walking up to it, not selecting a distant display.
const WEAPON_PICKUP_REACH := 2.2

## AF6. What the sandbox is holding is `HunterArsenal`'s own real state now —
## the same `WEAPONS` table and ammo/reload/jam machinery the Hunt runs on —
## not one fixed pairing hand-picked for the sandbox. `configure()` is never
## called: that method exists to hang weapon models off a body rig's arm for
## third-person, and this room has no rig, only a camera (see `view_gear`
## below), so `HunterArsenal` is used here purely for its weapon logic.
## Rounds are only this scene's to resolve if they say so. `Ballistics` is a
## shared system and the Hunt fires through one too; a handler that resolved
## anything arriving anywhere would eventually resolve somebody else's shot.
const SHOT_SOURCE := "gore_demo"

## The streak. A 9mm crosses this room in about a frame and a half, and the
## mesh `Ballistics` gives each round is a 16cm box — correct, and never
## rendered anywhere a player is looking, which reads as "no bullet came out".
## This draws the ground the round actually covered between one physics frame
## and the next, so what you see is the round's real path rather than a
## decoration fired alongside it. Short-lived on purpose: past about a fifth of
## a second a tracer stops reading as speed and starts reading as a laser.
const TRACER_LIFE := 0.16
const TRACER_WIDTH := 0.028
const MAX_TRACERS := 48
## How long the flash at the barrel lasts, in real seconds. A muzzle flash is
## one or two frames of light; anything longer is a torch.
const FLASH_LIFE := 0.045
## How far the gun is driven back into the frame by its own recoil, and how
## fast it comes back.
const GEAR_RECOIL := 0.055
const GEAR_RETURN := 9.0

var camera: Camera3D
var bodies: Array = []
var ballistics: Node3D
var impact_feel: Node
var hud: Control
var kill_cam: KillCam
var field_hud: Control
var living_map: Control

## The arm the sword is on. The Hunt has had one since AN1 and the range never
## did, which is why a swing here landed square across a limb whatever it was
## doing while the Hunt cut at the angle it was swung at. Same arm now, so the
## range is where you can actually learn what a blade does.
var arm: LimbMomentum
## Mouse movement since the last physics frame, which is what moves the arm.
## Accumulated rather than read live, because input and physics do not tick
## together and a swing built from one frame of mouse is not a swing.
var _look_delta := Vector2.ZERO
var guarding := false
var guard_aim := Vector2.ZERO
var guard_held := 0.0
var swing_released_side := ""
var third_person := false
var last_read: Dictionary = {}
var pending_melee: Dictionary = {}
var melee_windup := -1.0

var yaw := 0.0
var pitch := -0.12
var eye := Vector3(0.0, 1.68, 9.0)
var walk := Vector3.ZERO

## Held, not toggled: slow motion is a posture. And it is the whole of the
## "slow mo psychedelic abstract and arty" hook — the dial this scene turns is
## the one the shader work will later read.
var slowed := 0.0
## Counted in real seconds, because a hitstop timed on the clock it is bending
## lasts a fixed number of frames instead of a fixed duration — and at 0.08 that
## is twelve times longer than it was asked for.
var hitstop := 0.0
var xray := false
var spent := 0
var severed_total := 0
var last_note := ""
var note_life := 0.0
## A range needs both non-retaliating anatomy targets and something that proves
## the same body remains readable while it closes distance. This is an explicit
## player-owned switch, not an invisible sandbox argument.
var enemies_enabled := false
var simulation_health := 100
var mode_button: Button
var jump_queued := false
var vertical_velocity := 0.0
var stance_height := 1.68
## The range shares the Hunt's basic combat footwork instead of teaching a
## different control language: directional Space evades, still Space jumps,
## and a shouldered firearm narrows the same real projectile cone.
var dodge_remaining := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector3.ZERO
var stamina := 100.0
var firearm_aiming := false
var firearm_aim_blend := 0.0
var launcher_equipped := false
var launcher_rounds := 4
var launcher_cooldown := 0.0
var controls_expanded := false
## C now rehearses the Hunt's contact-range clinch. The selected range body is
## still its real anatomy rig; holding it does not spawn a proxy or freeze the
## rest of the drill around it.
var grapple_index := -1
var grapple_distance := 1.15


## AF6. Real weapon state — current weapon, ammo, reload, jam — shared with
## the Hunt rather than reinvented for the range. `configure()` is skipped
## (see the comment above `SHOT_SOURCE`); only the logic is borrowed.
var arsenal: HunterArsenal
## The gun you are actually holding. `HeldGear` is the project's weapon
## presentation — swept geometry, real hands, a grip table — and it is a plain
## `Node3D` that poses itself, so the sandbox mounts one on the camera rather
## than growing a second viewmodel system of its own. What it cannot borrow from
## the Hunt is `hunter_arsenal._build_weapon_model()`, which exists to cancel the
## first-person *arm* pose; there is no player rig in this room to cancel.
var view_gear: HeldGear
var muzzle_point: Node3D
var _flash_light: OmniLight3D
var _flash_cone: MeshInstance3D
var _flash_life := 0.0
var _gear_rest := Vector3.ZERO
var _gear_recoil := 0.0
## One serial per trigger pull, so a round can be recognised as this scene's own
## when it eventually arrives, and so the streak drawn for it knows which round
## it belongs to.
var _shot_serial := 0
## Where each of this scene's rounds in flight was last seen, by serial.
var _seen: Dictionary = {}
## AF6.2. What the range is supposed to teach: not a number invented for the
## HUD, but exactly the numbers `_on_round_hit()` already computes to resolve
## the hit itself — real distance, real travel time, and the real fraction of
## muzzle energy a round still had carrying it (drag/drop's actual effect,
## not a separate cosmetic stat standing in for it).
var last_shot_readout: Dictionary = {}
var _tracers: Array = []

var station: Node3D
var carried_substances: Array[Dictionary] = []
## The range's physical arsenal. Each entry owns the production weapon model
## standing on the rack and whether that exact object is still there to take.
var weapon_rack: Node3D
var weapon_pickups: Array[Dictionary] = []
var handheld: HandheldDevice
var psychedelic: PsychedelicRig
## Smokeables are deliberately held rather than clicked.  The draw duration is
## the input to their shared sweet-spot/harshness curve, so a bong can actually
## be a long, high-risk pull instead of a renamed inventory button.
var smoke_draw_slot := -1
var smoke_draw_started := 0.0


func _ready() -> void:
	# The sandbox player has the same persisted body ledger a main-game dose
	# charges.  There is no free, sandbox-only consumption path.
	WorldHistory.register_subject(SANDBOX_SUBJECT, {"name": "SANDBOX WITNESS", "kind": "person", "anatomy_state": {}})
	_build_room()
	_build_camera()
	impact_feel = IMPACT_FEEL.new()
	add_child(impact_feel)
	ballistics = BALLISTICS.new()
	add_child(ballistics)
	# The whole of the fix. A round decides what it did when it gets there.
	ballistics.round_hit.connect(_on_round_hit)
	ballistics.round_expired.connect(_on_round_expired)
	arsenal = HunterArsenal.new()
	add_child(arsenal)
	# The arm exists before the first swing does, same as AN1.2 in the Hunt.
	arm = LIMB_MOMENTUM.new()
	arm.carry(1.4, 0.55)
	# Starts on the sidearm — the same weapon the range always opened on before
	# AF6, so nobody's muscle memory for "LMB shoots a pistol" breaks. Switching
	# away from it is the new part, not the default.
	arsenal.select_slot(HunterArsenal.SLOT_ORDER.find("sidearm"))
	_build_view_gear()
	_build_weapon_rack()
	# AU3.5. The same station the shed and the Hunt Grounds drop - the sandbox
	# does not get its own layout, because a sandbox-only list is a list that
	# falls behind the game within a week.
	station = SUBSTANCE_STATION.new()
	station.name = "SubstanceStation"
	station.position = Vector3(0.0, 0.0, 4.2)
	add_child(station)
	station.build()
	station.taken.connect(_on_station_taken)
	for index in BODY_COUNT:
		_spawn_body(index)
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_note("SEVEN BODIES. GO ON THEN.")


# ---------------------------------------------------------------- the room
func _build_room() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("bone_yard")
	add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, 34, 0)
	key.light_energy = 0.85
	# Seven articulated anatomy rigs already account for roughly a thousand
	# visible mesh surfaces. Re-rendering all of them into the sandbox shadow map
	# is the dominant baseline cost, so the safe preset keeps the authored key
	# light and drops only its duplicate shadow pass.
	key.shadow_enabled = WorldLook.quality != WorldLook.Quality.PERFORMANCE
	add_child(key)

	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA * 2.0, 1.0, ARENA * 2.0)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	add_child(floor_body)

	var plate := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ARENA * 2.0, 0.2, ARENA * 2.0)
	plate.mesh = mesh
	plate.position.y = -0.1
	plate.material_override = WorldLook.surface(Color("2a2620"), "rust", 11)
	add_child(plate)

	# Four walls, so brass and chunks stay in the room rather than sliding off
	# into a void nobody can see them in.
	for side in 4:
		var wall := StaticBody3D.new()
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(ARENA * 2.0, 6.0, 0.6)
		wall_shape.shape = wall_box
		wall.add_child(wall_shape)
		wall.rotation.y = PI * 0.5 * float(side)
		wall.position = Vector3(0, 3.0, 0) + Vector3(0, 0, -ARENA).rotated(Vector3.UP, PI * 0.5 * float(side))
		add_child(wall)
		var face := MeshInstance3D.new()
		var face_mesh := BoxMesh.new()
		face_mesh.size = wall_box.size
		face.mesh = face_mesh
		face.material_override = WorldLook.surface(Color("1c1a16"), "rust", side + 3)
		wall.add_child(face)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.current = true
	add_child(camera)
	camera.global_position = eye


## AF6.1. The shed rack is part of the range, not a weapon menu given a mesh.
## It uses `HeldGear.build_weapon()` so the object on the wall and the object
## that enters the player's hands cannot drift into two different silhouettes.
func _build_weapon_rack() -> void:
	weapon_rack = Node3D.new()
	weapon_rack.name = "WeaponShed"
	weapon_rack.position = Vector3(-4.6, 0.0, 7.2)
	add_child(weapon_rack)

	# A shallow roof and battered backing make this read as a range shed from
	# across the room. The open front keeps every weapon visible and reachable.
	_rack_box("Backing", Vector3(0.0, 1.25, -0.10), Vector3(3.4, 2.5, 0.16), Color("3b3025"))
	_rack_box("Roof", Vector3(0.0, 2.55, 0.12), Vector3(3.8, 0.16, 1.05), Color("493a2b"))
	_rack_box("LeftPost", Vector3(-1.72, 1.25, 0.08), Vector3(0.16, 2.5, 0.42), Color("57412c"))
	_rack_box("RightPost", Vector3(1.72, 1.25, 0.08), Vector3(0.16, 2.5, 0.42), Color("57412c"))
	_rack_box("Rail", Vector3(0.0, 1.02, 0.04), Vector3(3.25, 0.10, 0.20), Color("766044"))
	var lamp := OmniLight3D.new()
	lamp.name = "RackLamp"
	lamp.position = Vector3(0.0, 2.28, 0.92)
	lamp.light_color = Color("e8ad68")
	lamp.light_energy = 2.2
	lamp.omni_range = 4.2
	lamp.shadow_enabled = false
	weapon_rack.add_child(lamp)

	weapon_pickups.clear()
	var placements := {
		# Authored muzzle-forward along Z; quarter-turning the mounts shows the
		# actual profiles instead of pointing three foreshortened barrels at the eye.
		"sword": {"at": Vector3(-0.42, 1.75, 0.12), "turn": Vector3(0.0, PI * 0.5, -0.04)},
		"shotgun": {"at": Vector3(-0.42, 0.86, 0.12), "turn": Vector3(0.0, PI * 0.5, 0.03)},
		"sidearm": {"at": Vector3(1.12, 1.34, 0.12), "turn": Vector3(0.0, PI * 0.5, 0.0)},
	}
	for weapon_id: String in HunterArsenal.SLOT_ORDER:
		var placement: Dictionary = placements.get(weapon_id, {})
		var model := HELD_GEAR.build_weapon(weapon_id)
		model.name = "%s_pickup" % weapon_id
		model.position = placement.get("at", Vector3.ZERO)
		model.rotation = placement.get("turn", Vector3.ZERO)
		model.scale = Vector3.ONE * 1.2
		weapon_rack.add_child(model)
		weapon_pickups.append({"weapon": weapon_id, "model": model, "available": true})

	# The rifle is deliberately not in `SLOT_ORDER` -- `arsenal_test` asserts
	# the hunter carries three -- so the range had no weapon that could earn
	# the X-ray finisher, and the finisher is most of what there is to see.
	# It is found here, which is how it is found in the world too.
	var rifle := HELD_GEAR.build_weapon("sniper")
	rifle.name = "sniper_pickup"
	rifle.position = Vector3(1.12, 0.46, 0.12)
	rifle.rotation = Vector3(0.0, PI * 0.5, 0.0)
	rifle.scale = Vector3.ONE * 1.2
	weapon_rack.add_child(rifle)
	weapon_pickups.append({"weapon": "sniper", "model": rifle, "available": true})


func _rack_box(label: String, at: Vector3, dimensions: Vector3, tint: Color) -> void:
	var piece := MeshInstance3D.new()
	piece.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = WorldLook.surface(tint, "wood", label.hash())
	piece.mesh = mesh
	piece.position = at
	weapon_rack.add_child(piece)


# ---------------------------------------------------------------- the bodies
func _spawn_body(index: int) -> void:
	var angle := TAU * float(index) / float(BODY_COUNT)
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = Vector3(cos(angle) * 6.5, 0.9, sin(angle) * 6.5 - 2.0)
	holder.rotation.y = -angle + PI * 0.5
	var rig: BaselineHuman = BASELINE.new()
	rig.name = "Body%d" % index
	holder.add_child(rig)
	rig.position = Vector3(0, -0.9, 0)
	# Gore goes in the config, not on the node. `build()` overwrites the
	# property from the world setting, which is written down inside `build()`
	# itself as the way a showcase scene once ended up standing in three metres
	# of blood. Here it is wanted on whatever the setting says.
	rig.build("demo_body_%d" % index, {
		"flesh": Color("70201c") if index % 2 == 0 else Color("586c3a"),
		"variation": index * 13 + 5,
		# Same world setting and same BaselineHuman implementation as the Hunt
		# and derby. The sandbox used to force gore on, making it look like a
		# separate, older system whenever the main-game setting was reduced.
		"gore": BaselineHuman.apply_gore_setting(),
		"blood": 4300.0,
		# The same body still owns its collapse, but the sandbox asks it to use a
		# grounded fall pose.  A body cannot be allowed to tunnel beneath the
		# range floor just because it has gone down.
		"knockdown_travel": 0.42,
		"cybernetics": {"torso": {"name": "ceramic sternum", "armor": 0.18}},
	})
	# Greg: *"the gore in the gore sandbox is not up to date with the gore in the
	# main game"*. The bodies here were bare rigs while the hunt gave every
	# person a face, wear, ink, piercings and a real cleaver on the hand, so the
	# range was a room of mannequins and anything you learned about a weapon here
	# was learned against a body the game does not contain. Same call the hunt
	# makes, so the two cannot drift apart again. Odd bodies come armed, which is
	# also what makes the range a place a fight could start rather than a rack.
	HunterAppearance.style_world_rig(rig, "demo_body_%d" % index, index % 2 == 1)
	# Clothing landed after the range did, so every dummy here was still bare
	# and a round hitting one skipped the cloth layer entirely -- the sandbox
	# was quietly teaching the wrong damage numbers. Every third body wears the
	# humiliation rig, so the motley is something you can stand in front of and
	# shoot rather than only a palette in a test.
	rig.dress(ClothingShell.humiliation_wardrobe() if index % 3 == 0 else ClothingShell.fresh_wardrobe())
	var motion: HunterBodyMotion = BODY_MOTION.new()
	motion.name = "BodyMotion"
	holder.add_child(motion)
	motion.configure(rig)
	motion.set_perspective(false)
	if xray:
		rig.reveal_organs(true)
		rig.see_through(true)
	bodies.append({
		"holder": holder,
		"rig": rig,
		"motion": motion,
		"id": "demo_body_%d" % index,
		"attack_ready": 0.35 + float(index) * 0.12,
		"guard": BladeRead.SIDES[index % BladeRead.SIDES.size()],
		"guard_age": 1.0,
		"guard_hold": 1.4 + float(index % 4) * 0.4,
	})


func _reset() -> void:
	smoke_draw_slot = -1
	for entry: Dictionary in bodies:
		var holder := entry["holder"] as Node3D
		if is_instance_valid(holder):
			holder.queue_free()
	bodies.clear()
	GoreChunks.clear()
	for index in range(_tracers.size() - 1, -1, -1):
		_retire_tracer(index)
	_seen.clear()
	if ballistics != null:
		ballistics.clear()
	_restore_weapon_rack()
	BaselineHuman.clear_gore()
	await get_tree().process_frame
	for index in BODY_COUNT:
		_spawn_body(index)
	spent = 0
	severed_total = 0
	_note("SEVEN MORE. THEY KEEP MAKING THEM.")


# ---------------------------------------------------------------- the verbs
func _explode(at: Vector3, force: float) -> void:
	_blast_light(at, force)
	var reached := 0
	var took := 0
	for entry: Dictionary in bodies:
		var rig := entry["rig"] as BaselineHuman
		if rig == null or not is_instance_valid(rig):
			continue
		var distance := rig.global_position.distance_to(at)
		if distance > BLAST_REACH:
			continue
		reached += 1
		var away := rig.global_position - at
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.001 else Vector3.RIGHT
		var falloff := 1.0 - clampf(distance / BLAST_REACH, 0.0, 1.0)
		# Inside the blast it shears, further out it only breaks. That line is
		# the entire difference between an explosion and a shove, and it is
		# literally `BaselineHuman.SEVERING_DAMAGE`: `blunt` never takes a limb
		# off, however hard it lands.
		var kind := "shear" if distance < BLAST_REACH * SHEAR_BAND else "blunt"
		# Everything in range takes it through the anatomy rather than through a
		# radius-and-damage number, so what comes off is what was actually
		# there — and each zone is hit as itself, because one point in space
		# resolves to one zone and that zone was always the torso.
		for zone: String in BLAST_ORDER:
			# There is nothing left to take off a corpse: the anatomy refuses a
			# dead body, and carrying on only sheds chunks nobody paid for.
			if rig.anatomy.dead:
				break
			var bite: float = force * falloff * randf_range(0.55, 1.3)
			if bite < 6.0:
				continue
			var report: Dictionary = rig.hit(zone, bite, bite * 1.6, kind, "", away)
			if bool(report.get("severed", false)):
				took += 1
	severed_total += took
	_kick(clampf(force / 92.0, 0.0, 1.0), "blunt", took > 0, HITSTOP_BLAST)
	if took > 0:
		_note("BLAST // %d REACHED // %d OFF" % [reached, took])
	else:
		_note("BLAST // %d REACHED" % reached)


## The blast you can see. A flash and an expanding shell for the eye, and an
## impulse on everything already loose — which is what makes a second blast into
## a room you have already wrecked look different from the first one.
func _blast_light(at: Vector3, force: float) -> void:
	var reach: float = clampf(force / 92.0, 0.35, 1.0) * BLAST_REACH

	var flash := OmniLight3D.new()
	flash.position = at
	flash.light_color = Color("ffb457")
	flash.light_energy = 0.0
	flash.omni_range = reach * 2.2
	add_child(flash)

	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 18
	sphere.rings = 9
	shell.mesh = sphere
	shell.position = at
	shell.scale = Vector3.ONE * 0.25
	var skin := StandardMaterial3D.new()
	skin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skin.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	skin.albedo_color = Color(1.0, 0.48, 0.16, 0.75)
	shell.material_override = skin
	add_child(shell)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "light_energy", 7.5, 0.035)
	tween.tween_property(flash, "light_energy", 0.0, 0.40).set_delay(0.05)
	tween.tween_property(shell, "scale", Vector3.ONE * reach, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(skin, "albedo_color", Color(1.0, 0.30, 0.08, 0.0), 0.32)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free()
		if is_instance_valid(shell):
			shell.queue_free())

	for chunk in GoreChunks.live:
		if not is_instance_valid(chunk) or not chunk is RigidBody3D:
			continue
		var away: Vector3 = chunk.global_position - at
		var distance := away.length()
		if distance > reach or distance < 0.001:
			continue
		var lift := (away.normalized() * 0.75 + Vector3.UP * 0.65).normalized()
		var body := chunk as RigidBody3D
		# GoreChunks freezes settled evidence to remove its ongoing physics cost.
		# A new blast is an explicit reason to wake it again.
		if body.freeze:
			body.freeze = false
		body.apply_central_impulse(lift * (1.0 - distance / reach) * force * 0.16)


## The trigger, and nothing but the trigger for a firearm — one real round
## leaves the barrel carrying the mark that says whose it is and what it will
## do when it lands (AF6.1: the current `HunterArsenal` weapon's own real
## damage/impulse/type, not one number fixed for the whole room); the brass
## comes off it; the gun goes back into the frame and the sight climbs. No
## anatomy is touched here, because the round has not arrived anywhere yet —
## that is the entire point. The sword has no round to fire, so it swings
## through `_melee_swing()` instead.
func _fire() -> void:
	if launcher_equipped:
		_fire_launcher()
		return
	if str(arsenal.current().get("kind", "")) == "melee":
		_melee_swing()
		return
	var attack: Dictionary = arsenal.begin_attack()
	if not bool(attack.get("accepted", false)):
		match str(attack.get("reason", "")):
			"empty": _note("DRY // [T] RELOAD")
			"jammed": _note("JAMMED // [T] CLEAR")
			_: _note("BUSY")
		return
	var along := -camera.global_transform.basis.z
	var start := camera.global_position + along * 0.6
	# `shot_directions()` returns one direction for a single-pellet weapon and
	# several for a shotgun — mirrors `bone_yard_hunt.gd`'s own
	# `_resolve_firearm()` exactly, calibre included, so the range and the Hunt
	# can never quietly disagree about what "buck" means.
	var directions: Array[Vector3] = arsenal.shot_directions(along, Vector3.UP, 0.38 if firearm_aiming else 1.0)
	# Damage and spread are not the whole gun. The sniper must launch Ballistics'
	# rifle profile (velocity, drag, mass and penetration), not a pistol round
	# wearing rifle damage because both happen to fire one projectile.
	var calibre := str(attack.get("calibre", "buck" if directions.size() > 1 else "pistol"))
	spent += 1
	for direction in directions:
		_shot_serial += 1
		ballistics.fire(start, direction, calibre, 0.0, 1, "demo", {
			"source": SHOT_SOURCE,
			"shot": _shot_serial,
			"weapon": str(attack.get("weapon", arsenal.current_id)),
			"damage": float(attack.get("damage", 0.0)),
			"impulse": float(attack.get("impulse", 0.0)),
			"damage_type": str(attack.get("damage_type", "ballistic")),
		})
		# The streak is drawn from where the gun actually is, not from the
		# round's own start point 0.6m off the lens — the round is aimed down
		# the camera axis so the crosshair stays honest, and the first segment
		# of its trail is what makes it read as having come out of the barrel.
		_seen[_shot_serial] = _muzzle_world(start)
	_muzzle_flash()
	_gear_recoil = 1.0
	# Muzzle side only: climb and a little roll, which is the gun moving, not a
	# hit landing. `_kick()` is contact and does not belong on a trigger pull.
	impact_feel.kick += Vector2(randf_range(-0.3, 0.3), 1.0) * IMPACT_FEEL.KICK_GRAZE * 2.0
	impact_feel.roll += randf_range(-1.0, 1.0) * 0.004
	if bool(attack.get("caused_jam", false)):
		_note("JAMMED")


func _fire_launcher() -> void:
	if launcher_cooldown > 0.0:
		_note("LAUNCHER CYCLING")
		return
	if launcher_rounds <= 0:
		_note("LAUNCHER EMPTY // SELECT ANOTHER WEAPON")
		return
	launcher_rounds -= 1
	launcher_cooldown = 1.15
	var along := -camera.global_transform.basis.z
	var start := _muzzle_world(camera.global_position + along * 0.7)
	_shot_serial += 1
	ballistics.fire(start, along, "rocket", 0.0, 1, "demo", {
		"source": SHOT_SOURCE,
		"shot": _shot_serial,
		"weapon": "breach_launcher",
		"damage": 0.0,
		"impulse": 0.0,
		"damage_type": "blast",
		"explosive": true,
	})
	_seen[_shot_serial] = start
	_muzzle_flash()
	_gear_recoil = 1.0
	_note("WARHEAD AWAY // %d REMAIN" % launcher_rounds)


## AF6.1. A sword has no round to travel and no barrel to leave from, so a
## swing resolves on the frame it lands rather than deferred like a firearm's
## round — the same instant-vs-travelling split `AN2.5`'s grip already draws
## between a cut and a shot. Reuses `_trace_body()` (already built for the
## blast's own crosshair targeting) rather than growing a second raycast path,
## the only new part is holding the hit to the weapon's own `reach` instead of
## the blast's much longer `TRACE_RANGE`.
## The Hunt panel reads one dictionary, so this is the whole of the wiring.
##
## Fed with the range own numbers rather than plausible ones: the health is the
## simulation health the dummies can actually take off you, the weapon is the
## live arsenal entry, and the lungs are whatever the substance station has
## done to you. A panel showing invented values would be worse than no panel,
## because it would look exactly like a working one.
func _feed_field_hud() -> void:
	if field_hud == null or not is_instance_valid(field_hud):
		return
	var current: Dictionary = arsenal.current() if arsenal != null else {}
	# `update_minimap` refuses while the full map is open, which it never is
	# here, and returns null until the satellite has a frame -- the panel
	# handles null by drawing nothing, so the corner fills in when it is ready
	# rather than needing to be waited for.
	var local_map: Texture2D = null
	if living_map != null and is_instance_valid(living_map):
		living_map.call("observe", eye, yaw)
		local_map = living_map.call("update_minimap", get_process_delta_time()) as Texture2D
	field_hud.call("set_state", {
		"minimap_texture": local_map,
		"minimap_heading": yaw,
		"health": float(simulation_health),
		"stamina": stamina,
		"blood": clampf(float(simulation_health) / 100.0, 0.0, 1.0),
		"weapon": current,
		"bare": current.is_empty(),
		"location": "THE GORE RANGE",
		"world_stamp": "SANDBOX // %d ON THE FLOOR" % GoreChunks.live_count(),
		"smoking": smoke_draw_slot >= 0,
		"can_dodge": dodge_cooldown <= 0.0 and stamina >= 25.0,
		"near_something": _near_pickup_source(),
		"interact_verb": "take",
	})


## Which way the player guard is held right now, from the mouse.
func _player_guard() -> String:
	if not guarding:
		return ""
	var side := BladeRead.guard_side(guard_aim)
	# Neutral until the mouse says otherwise, rather than snapping to whatever
	# the first pixel of drift happened to be.
	return side if not side.is_empty() else BladeRead.HIGH


## The dummies hold a guard and change it, which is the only way the read is
## worth anything: a target with no guard means every swing lands and there is
## nothing to learn. Posed through `CombatStance` so what they are holding is
## visible on the body rather than only true in a variable.
func _update_dummy_guards(real_delta: float) -> void:
	for entry: Dictionary in bodies:
		var rig := entry.get("rig") as BaselineHuman
		if rig == null or not is_instance_valid(rig) or rig.anatomy.dead:
			continue
		var age := float(entry.get("guard_age", 0.0)) + real_delta
		var side := str(entry.get("guard", ""))
		if side.is_empty() or age > float(entry.get("guard_hold", 2.0)):
			side = BladeRead.SIDES[randi() % BladeRead.SIDES.size()]
			age = 0.0
			entry["guard_hold"] = randf_range(1.4, 3.2)
		entry["guard"] = side
		entry["guard_age"] = age
		var motion := entry.get("motion") as HunterBodyMotion
		if motion != null and is_instance_valid(motion):
			motion.set_guard(BladeRead.guard_height(side))
			motion.set_lean(BladeRead.guard_lean(side))


func _melee_swing() -> void:
	if not pending_melee.is_empty():
		_note("RECOVER THE BLADE")
		return
	var attack: Dictionary = arsenal.begin_attack()
	if not bool(attack.get("accepted", false)):
		return
	_gear_recoil = 1.0
	swing_released_side = BladeRead.swing_side(arm.velocity)
	attack["released_side"] = swing_released_side
	pending_melee = attack
	melee_windup = maxf(0.01, float(attack.get("windup", 0.12)))


## Contact resolves after the weapon's real wind-up. Mouse motion received in
## that interval continues to drive LimbMomentum, so first-person contact can
## differ from release (a drag); lock-style third person keeps the release read.
func _resolve_melee_swing() -> void:
	var attack := pending_melee
	pending_melee = {}
	melee_windup = -1.0
	if attack.is_empty():
		return
	var along := -camera.global_transform.basis.z
	var start := camera.global_position + along * 0.6
	var reach := float(attack.get("range", 3.0))
	var found := _trace_body(start, along)
	var released_side := str(attack.get("released_side", ""))
	if found.is_empty() or camera.global_position.distance_to(found.get("position", start)) > reach:
		# A miss carries through and has to be caught, which is why whiffing a
		# committed swing is a real cost rather than a free probe.
		arm.whiff()
		_note("MISS // %s" % released_side.to_upper() if not released_side.is_empty() else "MISS")
		return
	var rig: BaselineHuman = found["rig"]
	var zone: String = found["zone"]
	var damage_type := str(attack.get("damage_type", "cut"))
	var landed: Vector3 = found.get("position", start)

	# Which way this swing is going, off the arm rather than off the camera.
	# In first person that is read here, at contact, so the mouse is still
	# steering and a drag lands where it was dragged to. In third person the
	# direction was locked when it was released and the player is wearing it.
	var contact_side := BladeRead.swing_side(arm.velocity)
	var side := BladeRead.committed_side(released_side, contact_side, not third_person)
	var defender := _entry_for(rig)
	var read: Dictionary = BladeRead.resolve(
		str(defender.get("guard", "")), float(defender.get("guard_age", 99.0)), side, arm.head_speed())
	last_read = {"swing": side, "guard": str(defender.get("guard", "")), "outcome": str(read.get("outcome", "none"))}
	var through := float(read.get("through", 1.0))
	if str(read.outcome) == "parry":
		# Turned. The arm takes the whole of its own commitment back.
		arm.strike(1.0, -along)
		_kick(1.0, "cut", false, HITSTOP_SHOT)
		var defender_motion := defender.get("motion") as HunterBodyMotion
		if defender_motion != null and is_instance_valid(defender_motion):
			defender_motion.trigger_parry()
		_note("PARRIED // %s MET %s" % [str(read.guard).to_upper(), side.to_upper()])
		return
	if str(read.outcome) == "block":
		_note("BLOCKED // %s" % side.to_upper())

	# The cut lands on the plane the edge actually swept, which is what makes
	# an overhead and a level slash take an arm off along different lines.
	var commitment := arm.commitment()
	var earned_damage := float(attack.get("damage", 0.0)) * lerpf(0.35, 1.35, commitment)
	var result: Dictionary = rig.hit_at(
		landed, earned_damage * through, float(attack.get("impulse", 0.0)) * through,
		damage_type, along, -1.0, arm.cut_plane(camera.global_transform.basis, landed))
	if not bool(result.get("accepted", true)):
		_note("%s ALREADY GONE" % _spoken(zone))
		return
	_trigger_body_hit_reaction(rig, along, zone, float(result.get("damage", attack.get("damage", 0.0))))
	var off := bool(result.get("severed", false))
	if off:
		severed_total += 1
	_kick(0.9, damage_type, off, HITSTOP_SHOT)
	arm.strike(_melee_bite(off), -along)
	var defender_hit := defender.get("motion") as HunterBodyMotion
	if defender_hit != null and is_instance_valid(defender_hit):
		defender_hit.trigger_stagger(rig.to_local(camera.global_position), 1.0 if off else 0.6)
	_note("%s OFF // %s" % [_spoken(zone), side.to_upper()] if off else "HIT // %s // %s" % [_spoken(zone), side.to_upper()])
	_try_finisher(rig, str(arsenal.current_id), zone, along, float(result.get("damage", 0.0)), damage_type)


## How hard the blade is stopped. Taking a limb off is barely stopped at all;
## meeting one that stays on is what jars the arm.
func _melee_bite(severed: bool) -> float:
	return 0.25 if severed else 0.75


## The bodies entry for a rig, so a swing can ask what its target was holding.
func _entry_for(rig: BaselineHuman) -> Dictionary:
	for entry: Dictionary in bodies:
		if entry.get("rig") == rig:
			return entry
	return {}


## Where a round of this scene's ended up, on the frame it actually got there.
##
## Everything `_fire()` used to do the instant the trigger went down happens
## here instead, however many frames later that turns out to be — and once per
## round, which is what makes emptying a magazine into one body take it apart in
## stages rather than in one lump.
func _on_round_hit(hit: Dictionary) -> void:
	var payload: Dictionary = hit.get("payload", {})
	if str(payload.get("source", "")) != SHOT_SOURCE:
		return
	var serial := int(payload.get("shot", 0))
	var at: Vector3 = hit.get("position", Vector3.ZERO)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var direction: Vector3 = hit.get("direction", Vector3.FORWARD)
	# The last stretch of the flight, from wherever it was last seen to where it
	# stopped. Without this a round that crossed the room inside one physics
	# frame would leave no trail at all.
	var muzzle_position := at
	if _seen.has(serial):
		muzzle_position = _seen[serial]
		_streak(_seen[serial], at)
		_seen.erase(serial)
	# Flight time and drop arrive on the round's own report below. They are
	# simulated ballistic facts, so slow motion and headless tests cannot turn
	# them into different answers by changing how fast the host clock advances.
	if bool(payload.get("explosive", false)):
		_unmark_last()
		_impact_burst(at, normal, Color("9c6230"))
		_explode(at, 72.0)
		_note("BREACH WARHEAD // IMPACT")
		return

	var struck := hit.get("collider") as Node
	var rig: BaselineHuman = null
	if struck != null and is_instance_valid(struck):
		rig = _rig_above(struck)
	if rig == null:
		# Loose gore is a `RigidBody3D` on the same layer as the walls, so a
		# round can genuinely stop in what is already on the floor. It arrived;
		# it just did not arrive at anybody.
		if struck != null and is_instance_valid(struck) and not GoreChunks.identify(struck).is_empty():
			_impact_burst(at, normal, Color("6b2a26"))
			_note("INTO THE MESS")
			return
		_impact_burst(at, normal, Color("9c8f78"))
		_note("INTO THE FLOOR" if normal.dot(Vector3.UP) > 0.6 else "INTO THE WALL")
		return

	# A round meeting a person opens them; it does not scar them. `Ballistics`
	# stamps its generic wall-hole from inside `_land()` before this handler is
	# ever called and has no idea what it landed on, which is where the flat
	# black rectangles across a shot-up body were coming from. Taking the last
	# mark back off is the only thing this scene can do about that without
	# reaching into `ballistics.gd`, which another lane owns — the real fix
	# belongs in `_land()`.
	_unmark_last()

	var zone := str(struck.get_meta("body_zone")) if struck.has_meta("body_zone") else rig.zone_nearest(at)
	# What it still had when it got here, against what it had leaving the
	# barrel. Near one at this range; well under one for anything that has had
	# to cross the room, which is the difference a travelling round buys.
	var muzzle_energy := _muzzle_energy(str(hit.get("calibre", "pistol")))
	var carried := clampf(float(hit.get("energy", 0.0)) / maxf(muzzle_energy, 0.001), 0.12, 1.4)
	# AF6.2. "Bullets are readable here" — not a stat invented for the HUD,
	# the exact real distance/travel-time/energy numbers this function just
	# used to resolve the hit itself, shown rather than only acted on. What
	# a round dragged off between the barrel and the body is `1.0 - carried`;
	# real drag against a real distance is why it is not 1.0 every time.
	last_shot_readout = {
		"calibre": str(hit.get("calibre", "pistol")),
		"distance": float(hit.get("travelled", muzzle_position.distance_to(at))),
		"travel_ms": roundi(float(hit.get("flight_time", 0.0)) * 1000.0),
		"drop_cm": float(hit.get("drop", 0.0)) * 100.0,
		"energy_pct": carried,
		"zone": zone,
	}
	# AF6.1. Read off the round's own payload rather than one fixed number —
	# `_fire()` carries the weapon that actually fired it, so a shotgun pellet
	# and a pistol round no longer do identical damage.
	var damage := float(payload.get("damage", 46.0))
	var impulse := float(payload.get("impulse", 30.0))
	var damage_type := str(payload.get("damage_type", "ballistic"))
	# Keep the exact impact point and the calibre's penetration budget. Calling
	# `hit(zone)` here used to throw both away, so the range could never teach
	# whether this live round lodged or opened an exit wound.
	var result: Dictionary = rig.hit_at(
		at, damage * carried, impulse * carried, damage_type, direction,
		float(hit.get("penetration", -1.0)))
	var penetration_report: Dictionary = result.get("penetration", {})
	match int(penetration_report.get("result", Penetration.Result.GRAZE)):
		Penetration.Result.STOPPED_BY_ARMOUR:
			last_shot_readout["penetration"] = "ARMOUR STOP"
		Penetration.Result.THROUGH:
			last_shot_readout["penetration"] = "THROUGH"
		Penetration.Result.BLIND:
			last_shot_readout["penetration"] = "LODGED %d%%" % roundi(float(penetration_report.get("fraction", 0.0)) * 100.0)
		_:
			last_shot_readout["penetration"] = "GRAZE"
	if not bool(result.get("accepted", true)):
		_note("%s ALREADY GONE" % _spoken(zone))
		return
	_trigger_body_hit_reaction(rig, direction, zone, float(result.get("damage", damage * carried)))
	var off := bool(result.get("severed", false))
	if off:
		severed_total += 1
	_kick(0.7 * carried, damage_type, off, HITSTOP_SHOT)
	_note("%s OFF" % _spoken(zone) if off else "HIT // %s" % _spoken(zone))
	_try_finisher(rig, str(payload.get("weapon", arsenal.current_id)), zone, direction,
		float(result.get("damage", damage * carried)), damage_type)


## What a lethal round earns, resolved after the rig has answered for the hit.
##
## Both of these were wired into the Hunt and neither reached the range, which
## is the wrong way round: the range is where you find out what a weapon does.
func _try_finisher(rig: BaselineHuman, weapon: String, zone: String, direction: Vector3, damage: float, damage_type: String) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	var snapshot: Dictionary = rig.snapshot()
	if not bool(snapshot.get("dead", false)):
		return
	# The head comes apart before the camera runs, so the plate plays over a
	# body already in the state you will walk up to when it ends.
	if SKULL_BURST.earned(zone, damage, damage_type, snapshot):
		var burst: Dictionary = SKULL_BURST.open(rig, direction)
		if not burst.is_empty():
			_note("CRANIUM OFF // %s" % weapon.to_upper())
	if kill_cam == null or kill_cam.active:
		return
	var finish: Dictionary = KILL_SHOT.earned(weapon, zone, snapshot)
	if finish.is_empty():
		return
	kill_cam.trigger(str(rig.name).to_upper(), str(finish.get("zone", zone)), direction,
		str(finish.get("label", weapon.to_upper())), snapshot)


## Range bodies already share anatomy with the Hunt; they now share the hit
## animation handoff too. Direction remains world-space until BodyMotion turns
## it into the victim's local lean, so a left hit and right hit cannot collapse
## into the same generic flinch.
func _trigger_body_hit_reaction(rig: BaselineHuman, direction: Vector3, zone: String, damage: float) -> bool:
	if rig == null or not is_instance_valid(rig):
		return false
	for entry: Dictionary in bodies:
		if entry.get("rig") != rig:
			continue
		var motion := entry.get("motion") as HunterBodyMotion
		if motion == null or not is_instance_valid(motion):
			return false
		var zone_max: float = float((AnatomyComponent.DEFAULT_ZONES.get(zone, {}) as Dictionary).get("health", 100.0))
		motion.trigger_hit(direction, damage / maxf(zone_max, 1.0))
		rig.favour_injuries()
		return true
	return false


## A round that ran out of world without arriving anywhere. Still an outcome,
## and the only one `_on_round_hit()` never sees.
func _on_round_expired(payload: Dictionary) -> void:
	if str(payload.get("source", "")) != SHOT_SOURCE:
		return
	_seen.erase(int(payload.get("shot", 0)))
	_note("MISS")


## What a round of this calibre carries as it leaves the barrel, read out of the
## calibre table rather than written down a second time — `Ballistics._land()`
## reports `0.5 * grain * v²`, so this is the same number at t=0.
func _muzzle_energy(calibre: String) -> float:
	var spec: Dictionary = BALLISTICS.CALIBRES.get(calibre, {})
	if spec.is_empty():
		return 1.0
	var muzzle := float(spec["muzzle"])
	return 0.5 * float(spec["grain"]) * muzzle * muzzle


## The hole `Ballistics` punched from inside `_land()` on the frame it landed.
## `marks` is appended to immediately before `round_hit` is emitted, so the last
## entry is unambiguously this round's.
func _unmark_last() -> void:
	if ballistics == null or not is_instance_valid(ballistics) or ballistics.marks.is_empty():
		return
	var hole: Node3D = ballistics.marks.pop_back()
	if hole != null and is_instance_valid(hole):
		hole.queue_free()


# ------------------------------------------------------- what you can see of it
## Greg, playing it: *"the bullets on the floor are good but the fact that when
## you shoot into the ground there no animations or whatever no gun model or
## anything goin on / and no bullet shot only bullet casings"*. The round was
## real before this and the brass was real before this; everything else about a
## shot was invisible. Three things had to arrive: something in your hands,
## something leaving it, and something happening where it lands.
func _build_view_gear() -> void:
	view_gear = HELD_GEAR.new()
	view_gear.name = "ViewGear"
	# The same hands the world puts on the same weapons. Set before the node
	# enters the tree, because that is when they are built.
	view_gear.gloved = true
	# On the camera, because in this room the camera *is* the player — there is
	# no body and so no arm pose for the weapon to be hung off and cancelled
	# against, which is the only part of the Hunt's viewmodel path that cannot
	# come across. `HeldGear` poses itself off `GRIPS[...].rest`, in view space.
	camera.add_child(view_gear)
	view_gear.take(arsenal.current_id)
	_gear_rest = view_gear.position
	# `HeldGear` already gives the range the production hands and costumed
	# forearms.  Unlike the Hunt, this scene has no body-motion pass to stretch
	# those sleeves from the frame edge to the live wrists, so do that here.
	_update_view_forearms()

	muzzle_point = Node3D.new()
	muzzle_point.name = "Muzzle"
	camera.add_child(muzzle_point)
	_refresh_muzzle_anchor()

	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color("ffcf8a")
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 5.5
	muzzle_point.add_child(_flash_light)

	_flash_cone = MeshInstance3D.new()
	var cone := SphereMesh.new()
	cone.radius = 0.055
	cone.height = 0.11
	cone.radial_segments = 8
	cone.rings = 4
	_flash_cone.mesh = cone
	_flash_cone.scale = Vector3(1.0, 1.0, 2.6)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = Color(1.0, 0.82, 0.42, 0.9)
	_flash_cone.material_override = glow
	_flash_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_cone.visible = false
	muzzle_point.add_child(_flash_cone)


## The weapon's own muzzle anchor, expressed in the camera's space, so the
## flash sits on the end of the barrel that is actually modelled rather than
## at a number somebody guessed. Factored out of `_build_view_gear()` so
## switching weapons (AF6.1) can re-anchor to the new model's barrel — a sword
## has no `anchor_muzzle` at all, so the guessed fallback position is what a
## melee swing's flash/kick effects sit at instead.
func _refresh_muzzle_anchor() -> void:
	muzzle_point.position = Vector3(0.09, -0.17, -0.44)
	if view_gear.weapon != null and is_instance_valid(view_gear.weapon):
		var anchor := view_gear.weapon.get_node_or_null("anchor_muzzle") as Node3D
		if anchor != null:
			muzzle_point.position = view_gear.transform * (view_gear.weapon.transform * anchor.position)


## The weapon model is not a floating prop: the same gloves and sleeves used
## in the Hunt have to reach the bottom of the first-person frame here too.
## `top_level` makes each sleeve camera-composed after HeldGear moves a hand
## for recoil or a new grip; recalculating it in `_advance_shot_feel()` keeps
## that continuity rather than freezing the wrist in the old pose.
func _update_view_forearms() -> void:
	if camera == null or not is_instance_valid(camera) or view_gear == null or not is_instance_valid(view_gear):
		return
	for hand in [view_gear.right_hand, view_gear.left_hand]:
		if hand == null or not is_instance_valid(hand):
			continue
		var forearm := hand.get_node_or_null("FirstPersonForearm") as Node3D
		var sleeve := forearm.get_node_or_null("TaperedSleeve") as MeshInstance3D if forearm != null else null
		if forearm == null or sleeve == null:
			continue
		forearm.visible = true
		forearm.top_level = true
		var side := int(hand.get_meta("screen_entry_side", 1))
		var start: Vector3 = camera.to_global(Vector3(0.43 * float(side), -0.49, -0.30))
		var end: Vector3 = hand.to_global(Vector3(0.0, 0.0, -0.035))
		var along: Vector3 = end - start
		var length := maxf(along.length(), 0.08)
		forearm.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, along.normalized())), start)
		var sleeve_mesh := sleeve.mesh as CylinderMesh
		if sleeve_mesh != null:
			sleeve_mesh.height = length
		sleeve.position.y = length * 0.5


## AF6.1. Every `HunterArsenal` weapon reachable in the sandbox, not just the
## one it opened on. Declined while mid-reload/jam-clear — `select_slot()`
## itself already refuses then — so a weapon swap can never strand a reload.
func _switch_weapon(slot: int) -> void:
	if slot < 0 or slot >= HunterArsenal.SLOT_ORDER.size():
		return
	if not launcher_equipped and HunterArsenal.SLOT_ORDER[slot] == arsenal.current_id:
		return
	if not arsenal.select_slot(slot):
		_note("CAN'T SWITCH // BUSY")
		return
	launcher_equipped = false
	firearm_aiming = false
	view_gear.take(arsenal.current_id)
	_gear_rest = view_gear.position
	_refresh_muzzle_anchor()
	_note("EQUIPPED // %s" % str(arsenal.current().label))


func _equip_launcher() -> void:
	if grapple_index >= 0:
		_note("LET GO BEFORE CHANGING WEAPONS")
		return
	launcher_equipped = true
	firearm_aiming = false
	view_gear.take("launcher")
	_gear_rest = view_gear.position
	_refresh_muzzle_anchor()
	_note("BREACH LAUNCHER // LMB FIRES A VISIBLE WARHEAD")


func _muzzle_world(fallback: Vector3) -> Vector3:
	if muzzle_point != null and is_instance_valid(muzzle_point):
		return muzzle_point.global_position
	return fallback


func _muzzle_flash() -> void:
	_flash_life = FLASH_LIFE
	if _flash_cone != null and is_instance_valid(_flash_cone):
		_flash_cone.visible = true
		_flash_cone.rotation.z = randf() * TAU


## One segment of a round's real path, for the eye. Built from where the round
## was to where it now is, which is why it stretches with speed: the faster the
## round, the longer the streak, and a pistol round covers about five metres
## between physics frames. Hold SHIFT and the same round crawls — the streak
## shortens, the bullet separates from its own trail, and the thing this sandbox
## exists to show is a bullet you can watch cross a room.
func _streak(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.03:
		return
	while _tracers.size() >= MAX_TRACERS:
		_retire_tracer(0)
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TRACER_WIDTH, TRACER_WIDTH, length)
	node.mesh = mesh
	var skin := StandardMaterial3D.new()
	skin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skin.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	skin.albedo_color = Color(1.0, 0.84, 0.44, 0.95)
	node.material_override = skin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = (from + to) * 0.5
	var along := (to - from).normalized()
	# `look_at` cannot use UP as its up vector when that is where it is pointing,
	# and a shot straight up or straight down is exactly what a sandbox gets.
	node.look_at(to, Vector3.FORWARD if absf(along.dot(Vector3.UP)) > 0.98 else Vector3.UP)
	_tracers.append({"node": node, "skin": skin, "life": TRACER_LIFE})


func _retire_tracer(index: int) -> void:
	if index < 0 or index >= _tracers.size():
		return
	var node := (_tracers[index] as Dictionary)["node"] as Node3D
	if node != null and is_instance_valid(node):
		node.queue_free()
	_tracers.remove_at(index)


## Something happens where it lands. Not a decal — `Ballistics` already owns the
## hole — but the moment of arrival: a spark off the surface and a puff of
## whatever the surface is made of, thrown back along the normal.
func _impact_burst(at: Vector3, normal: Vector3, dust: Color) -> void:
	var out := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var spark := OmniLight3D.new()
	spark.position = at + out * 0.05
	spark.light_color = Color("ffd08a")
	spark.light_energy = 2.6
	spark.omni_range = 1.6
	add_child(spark)

	var puff := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 10
	ball.rings = 5
	puff.mesh = ball
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var smoke := StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.cull_mode = BaseMaterial3D.CULL_DISABLED
	smoke.albedo_color = Color(dust.r, dust.g, dust.b, 0.5)
	puff.material_override = smoke
	add_child(puff)
	puff.global_position = at + out * 0.06
	puff.scale = Vector3.ONE * 0.06

	# Grit thrown back out of the surface, as short streaks in a cone around the
	# normal — the same primitive as a tracer, because that is what a spall is.
	for _piece in 5:
		var scatter := (out + Vector3(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))).normalized()
		_streak(at + out * 0.02, at + scatter * randf_range(0.14, 0.42))

	var tween := create_tween().set_parallel(true)
	tween.tween_property(spark, "light_energy", 0.0, 0.09)
	tween.tween_property(puff, "scale", Vector3.ONE * randf_range(0.30, 0.46), 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(smoke, "albedo_color", Color(dust.r, dust.g, dust.b, 0.0), 0.30)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(spark):
			spark.queue_free()
		if is_instance_valid(puff):
			puff.queue_free())


## Every frame of presentation a shot owes: the streaks fading, the flash going
## out, the gun coming back down out of its own recoil, and the trail of any
## round still in the air.
func _advance_shot_feel(real_delta: float) -> void:
	for index in range(_tracers.size() - 1, -1, -1):
		var streak: Dictionary = _tracers[index]
		streak["life"] = float(streak["life"]) - real_delta
		var node := streak["node"] as Node3D
		if float(streak["life"]) <= 0.0 or node == null or not is_instance_valid(node):
			_retire_tracer(index)
			continue
		var fade := clampf(float(streak["life"]) / TRACER_LIFE, 0.0, 1.0)
		var skin := streak["skin"] as StandardMaterial3D
		if skin != null:
			skin.albedo_color.a = fade * 0.95
		node.scale = Vector3(fade, fade, 1.0)

	if _flash_life > 0.0:
		_flash_life = maxf(0.0, _flash_life - real_delta)
		var strength := clampf(_flash_life / FLASH_LIFE, 0.0, 1.0)
		if _flash_light != null and is_instance_valid(_flash_light):
			_flash_light.light_energy = strength * 5.5
		if _flash_cone != null and is_instance_valid(_flash_cone):
			_flash_cone.visible = _flash_life > 0.0
			(_flash_cone.material_override as StandardMaterial3D).albedo_color.a = strength * 0.9

	if view_gear != null and is_instance_valid(view_gear):
		_gear_recoil = maxf(0.0, _gear_recoil - real_delta * GEAR_RETURN)
		var recoil := Vector3(0.0, 0.006, GEAR_RECOIL) * _gear_recoil
		if arm != null and arsenal != null and str(arsenal.current().get("kind", "")) == "melee":
			# The visible sword follows the same spring-driven hand that decides
			# speed, direction and cut plane; it is not a disconnected recoil prop.
			view_gear.position = _gear_rest + (arm.at - arm.anchor) + recoil
			view_gear.rotation = Vector3(arm.tilt.x, arm.tilt.y, 0.0)
		else:
			view_gear.position = _gear_rest + recoil
			view_gear.rotation = Vector3.ZERO
		_update_view_forearms()

	if ballistics == null or not is_instance_valid(ballistics):
		return
	# The trail of everything still in the air, one segment per frame per round.
	var live: Dictionary = {}
	for round_data: Dictionary in ballistics.rounds:
		var payload: Dictionary = round_data.get("payload", {})
		if str(payload.get("source", "")) != SHOT_SOURCE:
			continue
		var serial := int(payload.get("shot", 0))
		var at: Vector3 = round_data["at"]
		var was: Vector3 = _seen.get(serial, round_data["was"])
		_streak(was, at)
		live[serial] = at
	# A round fired this frame has not been stepped yet and so is not in
	# `rounds`; its muzzle position has to survive to be the start of its first
	# segment. Everything else that has gone has genuinely gone.
	if _seen.has(_shot_serial) and not live.has(_shot_serial):
		live[_shot_serial] = _seen[_shot_serial]
	_seen = live


## A close cutting pass is not a cosmetic alternate-fire.  It enters the same
## BaselineHuman anatomy path as melee in the Hunt: it opens layers, can rupture
## an organ, can sever a limb, and sends those real chunks/blood into the room.
func _cut() -> void:
	var along := -camera.global_transform.basis.z
	var found := _trace_body(camera.global_position + along * 0.45, along)
	if found.is_empty():
		_note("CUT // NO BODY")
		return
	var rig := found["rig"] as BaselineHuman
	var zone := str(found["zone"])
	var landed: Vector3 = found.get("position", rig.global_position)
	var plane: Variant = null
	if arm != null and arm.head_speed() > LimbMomentum.IDLE_SPEED:
		plane = arm.cut_plane(camera.global_transform.basis, landed)
	var result := rig.hit_at(landed, 58.0, 72.0, "cut", along, -1.0, plane)
	if not bool(result.get("accepted", true)):
		_note("%s ALREADY GONE" % _spoken(zone))
		return
	var off := bool(result.get("severed", false))
	if off:
		severed_total += 1
	_kick(0.58, "cut", off, HITSTOP_SHOT)
	_note("CUT // %s%s" % [_spoken(zone), " OFF" if off else " OPEN"])


## What the crosshair is on, right now. Firing no longer goes through here —
## a round finds its own body by arriving at it — but the cut and the blast are
## both instant by nature and still need to know what is in front of you.
##
## Iterated rather than a single ray because loose gore is a `RigidBody3D` on
## the same layer as the walls: a floor covered in what you have already done
## should not become armour for whoever is still standing behind it.
func _trace_body(from: Vector3, along: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var skip: Array[RID] = []
	for _step in 6:
		var query := PhysicsRayQueryParameters3D.create(from, from + along.normalized() * TRACE_RANGE)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider := hit.get("collider") as Node
		if collider != null and not GoreChunks.identify(collider).is_empty():
			skip.append(hit.get("rid"))
			continue
		var rig := _rig_above(collider)
		if rig == null:
			return {}
		var at: Vector3 = hit.get("position", from)
		var zone := str(collider.get_meta("body_zone")) if collider.has_meta("body_zone") else rig.zone_nearest(at)
		return {"rig": rig, "zone": zone, "position": at}
	return {}


func _rig_above(node: Node) -> BaselineHuman:
	var cursor := node
	while cursor != null:
		if cursor is BaselineHuman:
			return cursor as BaselineHuman
		cursor = cursor.get_parent()
	return null


## Contact, felt. `ImpactFeel` v2 is a value you read rather than an effect it
## applies: it carries the camera kick and says what a delta should be scaled
## by, and it deliberately stopped touching the global clock. This scene does
## hold the clock, so it takes the camera from the feeler and keeps the freeze
## on its own real-time counter instead of fighting over `Engine.time_scale`.
func _kick(severity: float, kind: String, severed: bool, freeze: float) -> void:
	impact_feel.strike(severity, kind, severed, [])
	# While slow motion is held it is already the slowest thing in the room, and
	# a hitstop underneath it would only read as a hitch.
	if slowed < 0.05:
		hitstop = maxf(hitstop, freeze * (1.6 if severed else 1.0))


## How many of this scene's own rounds are in the air right now.
func _rounds_in_flight() -> int:
	if ballistics == null or not is_instance_valid(ballistics):
		return 0
	var count := 0
	for round_data: Dictionary in ballistics.rounds:
		var payload: Dictionary = round_data.get("payload", {})
		if str(payload.get("source", "")) == SHOT_SOURCE:
			count += 1
	return count


func _spoken(zone: String) -> String:
	return zone.to_upper().replace("_", " ")


func _note(text: String) -> void:
	last_note = text
	note_life = 2.6


# ---------------------------------------------------------------- the loop
func _unhandled_input(event: InputEvent) -> void:
	# The raised handheld owns the player's attention.  Letting the range keep
	# interpreting its keys made G look open while mouse, weapon, and movement
	# commands continued underneath it.
	if handheld != null and handheld.is_open:
		if event is InputEventKey and not event.echo:
			var device_key := event as InputEventKey
			if device_key.pressed and device_key.keycode in [KEY_G, KEY_ESCAPE]:
				handheld.close_device()
				get_viewport().set_input_as_handled()
				return
			if handheld.handle_input(event):
				get_viewport().set_input_as_handled()
				return
		# A device page is never a transparent overlay.  Unclaimed keys are
		# intentionally swallowed instead of firing, dodging, or changing gear.
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var turn := Vector2(motion.relative.x * 0.0026, motion.relative.y * 0.0024)
		yaw -= turn.x
		pitch = clampf(pitch - turn.y, -1.2, 0.9)
		# The same movement that turns the head swings the blade. This is the
		# whole of the Mordhau input model and it costs one line, because
		# `LimbMomentum.advance()` has always taken a look delta.
		_look_delta += turn
		if guarding:
			guard_aim += motion.relative
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			# Clicking back into a released mouse should not also fire a round
			# into whatever happened to be under the cursor.
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
			if grapple_index >= 0:
				_grapple_pressure()
			else:
				_fire()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			if launcher_equipped or str(arsenal.current().get("kind", "")) == "firearm":
				firearm_aiming = click.pressed
			else:
				# Held, and the mouse picks the side while it is held. Right
				# was the melee swing before; swinging belongs on left with
				# everything else that attacks, and a blade needs the other
				# button for the half of a sword fight that is not attacking.
				guarding = click.pressed
				guard_aim = Vector2.ZERO
				guard_held = 0.0
				if not click.pressed:
					_note("GUARD DOWN")
		elif click.pressed and (click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			# AF6.1. Cycling rather than reserving three more number keys, since
			# 1-4 already belong to the carry/substance slots and doubling a key
			# up between two different systems is exactly the kind of thing that
			# reads as a bug the first time somebody reaches for a smoke mid-fight.
			var current_slot := HunterArsenal.SLOT_ORDER.find(arsenal.current_id)
			var step := 1 if click.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			var total := HunterArsenal.SLOT_ORDER.size()
			_switch_weapon(posmod(current_slot + step, total))
	if event is InputEventKey and not event.echo:
		var key := event as InputEventKey
		var slot := _carry_slot_for_key(key.keycode)
		if not key.pressed:
			if slot == smoke_draw_slot:
				var held := maxf(0.08, Time.get_ticks_msec() * 0.001 - smoke_draw_started)
				smoke_draw_slot = -1
				_use_carried(slot, held)
			return
		if slot >= 0:
			_begin_or_use_carried(slot)
			return
		match key.keycode:
			KEY_F1:
				controls_expanded = not controls_expanded
				_note("FULL CONTROL REFERENCE" if controls_expanded else "ESSENTIAL CONTROLS ONLY")
			KEY_C: _toggle_grapple()
			KEY_H: _set_enemies_enabled(not enemies_enabled)
			KEY_SPACE:
				var move := _sandbox_move_input()
				if move.length_squared() > 0.01:
					_begin_dodge(move)
				else:
					jump_queued = true
			KEY_E: _take_station_item()
			KEY_F: _open_nearest_body()
			KEY_V:
				third_person = not third_person
				# The registers differ in when the swing direction is read, so
				# say which one is running rather than leaving it to be felt.
				_note("THIRD PERSON // COMMITTED SWINGS" if third_person else "FIRST PERSON // DRAG YOUR SWINGS")
			KEY_G:
				if handheld != null:
					handheld.toggle_device()
					get_viewport().set_input_as_handled()
					return
			KEY_Q: _cut()
			KEY_R: _reset()
			KEY_X: _set_xray(not xray)
			KEY_ESCAPE: _step_out()
			KEY_6: _switch_weapon(HunterArsenal.SLOT_ORDER.find("sword"))
			KEY_7: _switch_weapon(HunterArsenal.SLOT_ORDER.find("shotgun"))
			KEY_8: _switch_weapon(HunterArsenal.SLOT_ORDER.find("sidearm"))
			KEY_9: _equip_launcher()
			KEY_T:
				if launcher_equipped:
					_note("LAUNCHER AUTO-CYCLES // %d WARHEADS REMAIN" % launcher_rounds)
				elif not arsenal.reload():
					_note("CAN'T RELOAD")


func _sandbox_move_input() -> Vector3:
	var forward := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(forward.z, 0, -forward.x)
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move -= forward
	if Input.is_key_pressed(KEY_S): move += forward
	if Input.is_key_pressed(KEY_A): move -= right
	if Input.is_key_pressed(KEY_D): move += right
	return move.normalized()


func _begin_dodge(requested_direction := Vector3.ZERO) -> bool:
	if grapple_index >= 0 or dodge_remaining > 0.0 or dodge_cooldown > 0.0 or stamina < 25.0 or vertical_velocity != 0.0:
		return false
	var requested: Vector3 = requested_direction
	requested.y = 0.0
	if requested.length_squared() <= 0.01:
		return false
	dodge_direction = requested.normalized()
	dodge_remaining = 0.28
	dodge_cooldown = 0.75
	stamina -= 25.0
	firearm_aiming = false
	_note("DODGE // COMMIT, RECOVER, MOVE AGAIN")
	return true


func _toggle_grapple() -> bool:
	if grapple_index >= 0:
		_release_grapple("YOU LET GO")
		return false
	var along := -camera.global_transform.basis.z
	var found := _trace_body(camera.global_position, along)
	if found.is_empty() or camera.global_position.distance_to(found.get("position", camera.global_position)) > 2.65:
		_note("NO BODY IN GRAPPLING REACH")
		return false
	var target_rig := found.get("rig") as BaselineHuman
	for index in bodies.size():
		if (bodies[index] as Dictionary).get("rig") == target_rig:
			return _begin_grapple(index)
	return false


func _begin_grapple(index: int) -> bool:
	if index < 0 or index >= bodies.size() or grapple_index >= 0:
		return false
	var entry: Dictionary = bodies[index]
	var rig := entry.get("rig") as BaselineHuman
	var holder := entry.get("holder") as Node3D
	if rig == null or holder == null or not is_instance_valid(rig) or not is_instance_valid(holder) or rig.anatomy.dead or rig.anatomy.downed:
		return false
	if camera.global_position.distance_to(holder.global_position + Vector3.UP * 0.7) > 2.9:
		return false
	grapple_index = index
	grapple_distance = clampf(camera.global_position.distance_to(holder.global_position), 0.95, 1.45)
	firearm_aiming = false
	var motion := entry.get("motion") as HunterBodyMotion
	if motion != null:
		motion.set_grapple_pose(1.0, false)
	_note("CLINCH // WASD DRAGS, LMB PRESSES, C RELEASES")
	return true


func _release_grapple(message := "") -> void:
	if grapple_index >= 0 and grapple_index < bodies.size():
		var motion := (bodies[grapple_index] as Dictionary).get("motion") as HunterBodyMotion
		if motion != null and is_instance_valid(motion):
			motion.set_grapple_pose(0.0, false)
	grapple_index = -1
	if not message.is_empty():
		_note(message)


func _grapple_pressure() -> bool:
	if grapple_index < 0 or grapple_index >= bodies.size():
		return false
	var entry: Dictionary = bodies[grapple_index]
	var rig := entry.get("rig") as BaselineHuman
	if rig == null or not is_instance_valid(rig) or rig.anatomy.dead:
		_release_grapple()
		return false
	var result: Dictionary = rig.hit("torso", 3.0, 2.0, "blunt")
	_kick(0.18, "blunt", false, HITSTOP_SHOT)
	_note("CLINCH PRESSURE // C RELEASES")
	if rig.anatomy.dead or rig.anatomy.downed:
		_release_grapple("THE BODY DROPS OUT OF YOUR HOLD")
	return bool(result.get("accepted", true))


func _carry_slot_for_key(keycode: Key) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
	return -1


func _begin_or_use_carried(index: int) -> void:
	if index < 0 or index >= carried_substances.size():
		_note("CARRY SLOT EMPTY")
		return
	var item := carried_substances[index]
	if str(item.get("kind", "")) != "smokeable":
		_use_carried(index)
		return
	smoke_draw_slot = index
	smoke_draw_started = Time.get_ticks_msec() * 0.001
	_note("DRAWING // %s" % str(item.get("label", "SMOKEABLE")))


func _take_station_item() -> void:
	if _take_nearest_weapon():
		return
	if station == null:
		return
	var taken: Dictionary = station.take_nearest(eye)
	if taken.is_empty():
		_note("NO SUBSTANCE WITHIN REACH")
		return
	# The signal appends the actual data; this only narrates the physical action.
	_note("TAKEN // %s" % str(taken.get("label", "UNMARKED")))


## A carry prompt is contextual information, not a permanent watermark.  It
## appears only when an item can actually be taken or when the player has
## something in a carried slot to use.
func _near_pickup_source() -> bool:
	if station != null and is_instance_valid(station) and eye.distance_to(station.global_position) <= WEAPON_PICKUP_REACH:
		return true
	for pickup: Dictionary in weapon_pickups:
		if not bool(pickup.get("available", false)):
			continue
		var model := pickup.get("model") as Node3D
		if model != null and is_instance_valid(model) and eye.distance_to(model.global_position) <= WEAPON_PICKUP_REACH:
			return true
	return false


## AF6.1. E takes the nearest authored gun or blade only when the player has
## physically walked into reach. The rack model disappears in the same action
## that equips the live arsenal entry, so this cannot read as a display prop
## beside a hotkey swap.
## `Cavity`, on a body you are standing over.
##
## The Hunt only reaches this through a timed extraction, so the geometry half
## of opening somebody -- the wall coming away, the organs behind it becoming
## visible -- was effectively unreachable anywhere you could stand and look at
## it. Here it is a key.
func _open_nearest_body() -> void:
	var nearest: BaselineHuman = null
	var nearest_distance := 2.8
	for entry: Dictionary in bodies:
		var candidate := entry.get("rig") as BaselineHuman
		if candidate == null or not is_instance_valid(candidate):
			continue
		var distance := eye.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest == null:
		_note("NOTHING IN REACH TO OPEN")
		return
	# Chest first, then the head, so a second press on the same body does
	# something rather than refusing.
	var zone := "torso" if not CAVITY.is_open(nearest, "torso") else "head"
	if CAVITY.is_open(nearest, zone):
		_note("ALREADY OPEN // BOTH")
		return
	# From the body toward the hands, so the wall that comes away is the one
	# between you and the inside -- and flattened, because these bodies are
	# standing. Leaving the vertical in means reaching down into a chest from
	# above the shoulder, and the plane then takes a cap off the top of the
	# torso too small to clear `MIN_OPENING_AREA`, so the dig silently did
	# nothing. `bone_yard_hunt` zeroes the same component for the same reason.
	var facing := eye - nearest.global_position
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		facing = Vector3.FORWARD
	var cut: Dictionary = CAVITY.open_zone(nearest, zone, facing)
	if cut.is_empty():
		_note("NOTHING WORTH OPENING THERE")
		return
	# The slab is a real piece rather than geometry that stopped existing.
	CAVITY.shed_wall(nearest, cut, facing, GoreChunks.Layer.MUSCLE)
	var organs: Array = cut.get("organs", [])
	_note("OPENED // %s%s" % [_spoken(zone), "" if organs.is_empty() else " // " + ", ".join(organs).to_upper()])


func _take_nearest_weapon() -> bool:
	var nearest: Dictionary = {}
	var nearest_distance := WEAPON_PICKUP_REACH
	for pickup: Dictionary in weapon_pickups:
		if not bool(pickup.get("available", false)):
			continue
		var model := pickup.get("model") as Node3D
		if model == null or not is_instance_valid(model):
			continue
		var distance := eye.distance_to(model.global_position)
		if distance <= nearest_distance:
			nearest = pickup
			nearest_distance = distance
	if nearest.is_empty():
		return false
	var weapon_id := str(nearest.get("weapon", ""))
	var slot := HunterArsenal.SLOT_ORDER.find(weapon_id)
	if weapon_id == "sniper":
		# Not a slot. It is acquired rather than selected, which is the same
		# call the world makes when the rifle is found.
		if not arsenal.acquire_sniper():
			return false
	elif slot < 0:
		return false
	# Use the same refusal the hotkeys use: a half-finished reload or jam clear
	# cannot strand its timer merely because the replacement came off a wall.
	elif weapon_id != arsenal.current_id and not arsenal.select_slot(slot):
		_note("CAN'T TAKE // HANDS BUSY")
		return true
	launcher_equipped = false
	firearm_aiming = false
	view_gear.take(weapon_id)
	_gear_rest = view_gear.position
	_refresh_muzzle_anchor()
	nearest["available"] = false
	(nearest.get("model") as Node3D).visible = false
	_note("TAKEN FROM RACK // %s" % str(arsenal.current().get("label", weapon_id)).to_upper())
	return true


func _restore_weapon_rack() -> void:
	for pickup: Dictionary in weapon_pickups:
		pickup["available"] = true
		var model := pickup.get("model") as Node3D
		if model != null and is_instance_valid(model):
			model.visible = true


func _on_station_taken(entry: Dictionary) -> void:
	carried_substances.append(entry.duplicate(true))


func _use_carried(index: int, held := 1.0) -> void:
	if index < 0 or index >= carried_substances.size():
		_note("CARRY SLOT EMPTY")
		return
	var item: Dictionary = carried_substances[index]
	var result: Dictionary = {}
	if str(item.get("kind", "")) == "substance":
		result = SUBSTANCES.take(SANDBOX_SUBJECT, str(item.get("id", "")), 1.0)
		if bool(result.get("ok", false)):
			SUBSTANCE_EXPERIENCE.begin(SANDBOX_SUBJECT, str(item.get("id", "")), Time.get_ticks_msec() * 0.001, 1.0)
	else:
		result = SMOKEABLES.hit(SANDBOX_SUBJECT, str(item.get("id", "")), held, Time.get_ticks_msec() * 0.001)
	if bool(result.get("ok", false)):
		carried_substances.remove_at(index)
		var grade := str(result.get("grade", ""))
		_note("DOSE %s // %s" % [grade.to_upper() if not grade.is_empty() else "BEGUN", str(item.get("label", item.get("id", "")))])
	else:
		_note("DOSE REFUSED // %s" % str(result.get("reason", "BODY LEDGER")))



## Escape twice to leave. The first press gives the mouse back, which is what
## somebody wants nine times out of ten; the second actually goes. A sandbox
## handed to a stranger with no way out of it but Alt+F4 is not a demo.
func _step_out() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_note("ESCAPE AGAIN TO LEAVE")
		return
	Engine.time_scale = 1.0
	if Engine.has_singleton("Interstitial") or get_node_or_null("/root/Interstitial") != null:
		Interstitial.travel("res://country_town_menu.tscn", "back out of it")
	else:
		get_tree().change_scene_to_file("res://country_town_menu.tscn")

## Two calls, not one. `reveal_organs()` shows the organs and the skeleton and
## makes the flesh translucent; `see_through()` puts them in front of whatever
## is between the body and the camera, without which an X-ray is a highlight.
func _set_xray(enabled: bool) -> void:
	xray = enabled
	for entry: Dictionary in bodies:
		var rig := entry["rig"] as BaselineHuman
		if rig == null or not is_instance_valid(rig):
			continue
		rig.reveal_organs(xray)
		rig.see_through(xray)
	_note("X-RAY %s" % ("ON" if xray else "OFF"))


func _physics_process(delta: float) -> void:
	# Real seconds, whatever the clock is doing to everything else. `delta` is
	# `real * time_scale` by definition, so this inverts it exactly — and it is
	# the only honest way to time anything in a scene that bends time on purpose.
	var real_delta := delta / maxf(Engine.time_scale, 0.0001)

	# Held, not toggled. The world slows; your own aim and your own feet do not,
	# which is what makes a slow-motion execution feel like something you are
	# doing rather than something being shown to you.
	var want := 1.0 if Input.is_key_pressed(KEY_SHIFT) else 0.0
	slowed = move_toward(slowed, want, real_delta * 5.0)
	hitstop = maxf(0.0, hitstop - real_delta)
	Engine.time_scale = lerpf(1.0, SLOW_SCALE, slowed) * (HITSTOP_SCALE if hitstop > 0.0 else 1.0)

	var move := _sandbox_move_input()
	var move_speed := 7.0 * (0.68 if firearm_aiming else 1.0)
	walk = walk.lerp(move * move_speed, clampf(real_delta * 14.0, 0.0, 1.0))
	# The arm and guard run in real seconds: sandbox slow motion bends the world,
	# not the player's input. The delta is already radians, matching the Hunt.
	if arm != null:
		var forward := Vector3(sin(yaw), 0.0, cos(yaw))
		var right := Vector3(forward.z, 0.0, -forward.x)
		arm.advance(real_delta, _look_delta, Vector3(walk.dot(right), walk.y, -walk.dot(forward)))
		_look_delta = Vector2.ZERO
	if guarding:
		guard_held += real_delta
	_update_dummy_guards(real_delta)
	_feed_field_hud()
	if melee_windup >= 0.0:
		melee_windup -= real_delta
		if melee_windup < 0.0:
			_resolve_melee_swing()
	if dodge_remaining > 0.0:
		eye += dodge_direction * 16.0 * real_delta
	else:
		eye += walk * real_delta
	dodge_remaining = maxf(0.0, dodge_remaining - real_delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - real_delta)
	if dodge_remaining <= 0.0:
		stamina = minf(100.0, stamina + 18.0 * real_delta)
	eye.x = clampf(eye.x, -ARENA + 2.0, ARENA - 2.0)
	eye.z = clampf(eye.z, -ARENA + 2.0, ARENA - 2.0)
	var crouching := Input.is_key_pressed(KEY_CTRL)
	var target_stance := 1.08 if crouching else 1.68
	stance_height = move_toward(stance_height, target_stance, real_delta * 3.8)
	if jump_queued and vertical_velocity == 0.0 and not crouching:
		vertical_velocity = 5.8
	jump_queued = false
	if vertical_velocity != 0.0:
		vertical_velocity -= 16.0 * real_delta
		eye.y += vertical_velocity * real_delta
		if eye.y <= stance_height:
			eye.y = stance_height
			vertical_velocity = 0.0
	else:
		eye.y = stance_height
	_update_training_bodies(real_delta)

	# The third of the three things that are supposed to arrive together on
	# contact. The feeler has been carrying this the whole time and nothing in
	# this scene was asking it for anything.
	var shove: Vector2 = impact_feel.camera_offset()
	camera.global_position = eye
	camera.global_transform.basis = Basis(Vector3.UP, yaw + shove.x) * Basis(Vector3.RIGHT, pitch + shove.y) * Basis(Vector3.FORWARD, impact_feel.roll)
	var aiming_now := firearm_aiming and str(arsenal.current().get("kind", "")) == "firearm"
	if launcher_equipped:
		aiming_now = firearm_aiming
	if not aiming_now:
		firearm_aiming = false
	firearm_aim_blend = move_toward(firearm_aim_blend, 1.0 if aiming_now else 0.0, real_delta * 7.0)
	camera.fov = lerpf(78.0, 56.0, firearm_aim_blend)

	# Everything a shot owes the eye, timed in real seconds like the hitstop is:
	# a tracer measured on the bent clock would hang in the air for a second and
	# a half the moment slow motion is held, which is a laser, not a bullet.
	_advance_shot_feel(real_delta)
	# Real seconds, same as the hitstop and the tracers above — reload and jam
	# recovery are muscle-memory timing a player is meant to be testing here,
	# not something holding slow motion should let them cheat.
	arsenal.tick(real_delta)
	launcher_cooldown = maxf(0.0, launcher_cooldown - real_delta)

	note_life = maxf(0.0, note_life - real_delta)
	# A dose is only a gameplay feature when the player can actually see its
	# state.  This drives the same fullscreen rig and timed profile the Hunt
	# uses; the sandbox does not invent a separate "drug screen" effect.
	if psychedelic != null and is_instance_valid(psychedelic):
		var now := Time.get_ticks_msec() * 0.001
		SUBSTANCE_EXPERIENCE.drive(psychedelic, SANDBOX_SUBJECT, now)
		SUBSTANCE_EXPERIENCE.settle(SANDBOX_SUBJECT, now)
	if hud != null and is_instance_valid(hud):
		hud.queue_redraw()


func _exit_tree() -> void:
	# Leaving this scene with the world still slowed would follow you out of it.
	Engine.time_scale = 1.0


# ------------------------------------------------------------------- the HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Under the sandbox readouts, because it is the room the numbers sit in.
	field_hud = Control.new()
	field_hud.set_script(FIELD_HUD)
	field_hud.name = "FieldInterface"
	field_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(field_hud)
	# Never shown as a full screen here: the range is one room and there is
	# nowhere to travel to. It is carried purely for the satellite feeding the
	# corner of the panel.
	living_map = LIVING_MAP.new()
	living_map.name = "LivingMap"
	living_map.visible = false
	layer.add_child(living_map)
	living_map.call("attach_world", get_world_3d())
	hud.draw.connect(_paint_hud)
	layer.add_child(hud)
	# Above the readouts, because when it fires it is the only thing to look at.
	kill_cam = KILL_CAM.new()
	kill_cam.name = "KillCam"
	kill_cam.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	kill_cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(kill_cam)
	# Same damaged CellOutz hardware as the Hunt, not a sandbox text panel.
	handheld = HandheldDevice.new()
	handheld.name = "SandboxHandheld"
	layer.add_child(handheld)
	# The sandbox is a real 3D region, so its handheld gets the same live
	# satellite feed as the main world instead of falling back to the facility
	# chart with no world source attached.
	handheld.bind(self, null, Callable())
	psychedelic = PSYCHEDELIC_RIG.new()
	psychedelic.name = "SandboxPsychedelic"
	layer.add_child(psychedelic)
	mode_button = Button.new()
	mode_button.name = "TrainingMode"
	mode_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mode_button.offset_left = -164.0
	mode_button.offset_top = 24.0
	mode_button.offset_right = 164.0
	mode_button.offset_bottom = 62.0
	mode_button.focus_mode = Control.FOCUS_NONE
	mode_button.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.02, 0.016, 0.9)
	normal.border_color = Color("862016")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	mode_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.12, 0.035, 0.02, 0.96)
	mode_button.add_theme_stylebox_override("hover", hover)
	mode_button.pressed.connect(func() -> void: _set_enemies_enabled(not enemies_enabled))
	layer.add_child(mode_button)
	_update_mode_button()


func _set_enemies_enabled(enabled: bool) -> void:
	enemies_enabled = enabled
	if enabled:
		simulation_health = 100
		_note("ENEMY DRILL // BODIES WILL CLOSE AND STRIKE")
	else:
		_note("DUMMY DRILL // BODIES HOLD POSITION")
	_update_mode_button()


func _update_mode_button() -> void:
	if mode_button == null or not is_instance_valid(mode_button):
		return
	mode_button.text = "[H] TRAINING MODE  //  %s" % ("ENEMIES" if enemies_enabled else "DUMMIES")
	mode_button.add_theme_color_override("font_color", Color("e05032") if enemies_enabled else Color("d7c69e"))


## The enemy drill deliberately stays inside the sandbox's existing anatomy
## bodies: no duplicate health rig and no decorative AI proxy. Standing bodies
## advance, face the camera and land timed training strikes; downed, dead or
## dismembered bodies stop. DUMMY mode halts this entire path immediately.
func _update_training_bodies(real_delta: float) -> void:
	if grapple_index >= bodies.size():
		_release_grapple()
	for index in bodies.size():
		var entry: Dictionary = bodies[index]
		var holder := entry.get("holder") as Node3D
		var rig := entry.get("rig") as BaselineHuman
		var motion := entry.get("motion") as HunterBodyMotion
		if holder == null or rig == null or not is_instance_valid(holder) or not is_instance_valid(rig):
			continue
		if rig.anatomy.dead or rig.anatomy.downed:
			if index == grapple_index:
				_release_grapple("THE BODY DROPS OUT OF YOUR HOLD")
			continue
		if index == grapple_index:
			var forward := -camera.global_transform.basis.z
			forward.y = 0.0
			if forward.length_squared() <= 0.001:
				forward = Vector3.FORWARD
			var anchor := eye + forward.normalized() * grapple_distance
			anchor.y = 0.9
			holder.global_position = holder.global_position.lerp(anchor, clampf(real_delta * 22.0, 0.0, 1.0))
			holder.rotation.y = yaw
			if motion != null:
				motion.set_combat_pose(0.0, "")
				motion.set_grapple_pose(1.0, false)
				motion.update(real_delta, walk, true, walk.length() > 3.0, false, false)
			continue
		if not enemies_enabled:
			if motion != null:
				motion.set_combat_pose(0.0, "")
				motion.update(real_delta, Vector3.ZERO, true, false, false, false)
			continue
		var toward := eye - holder.global_position
		toward.y = 0.0
		var distance := toward.length()
		var visual_velocity := Vector3.ZERO
		if distance > 1.45:
			var travel_speed := 3.8 if distance > 4.5 else 2.15
			var step := toward.normalized() * minf(distance - 1.35, real_delta * travel_speed)
			holder.global_position += step
			holder.look_at(Vector3(eye.x, holder.global_position.y, eye.z), Vector3.UP)
			visual_velocity = step / maxf(real_delta, 0.0001)
		entry["attack_ready"] = float(entry.get("attack_ready", 0.0)) - real_delta
		var windup := clampf(1.0 - float(entry["attack_ready"]) / 1.05, 0.0, 1.0) if distance <= 1.65 else 0.0
		if motion != null:
			motion.set_combat_pose(windup, "melee")
			motion.update(real_delta, visual_velocity, true, visual_velocity.length() > 3.0, false, false)
		if distance <= 1.65 and float(entry["attack_ready"]) <= 0.0:
			entry["attack_ready"] = 1.05
			if motion != null:
				motion.set_combat_pose(0.0, "")
				motion.trigger_attack(0.62, "melee")
			simulation_health = maxi(0, simulation_health - 8)
			_kick(0.24, "blunt", false, HITSTOP_SHOT)
			_note("TRAINING HIT // SIM HEALTH %03d" % simulation_health)
			if simulation_health <= 0:
				simulation_health = 100
				eye = Vector3(0.0, stance_height, 9.0)
				_note("SIMULATION BODY RESET // TARGETS RETAIN DAMAGE")


func _paint_hud() -> void:
	var bone := Color("ead4ad")
	var acid := Color("9bf01a")
	var rust := Color("b0552a")
	var size := hud.size

	# A damaged field instrument, not a clean debug overlay. The corners and
	# centre sigil use the same copper/blood language as the front door and the
	# handheld so this room reads as part of the game before anything is shot.
	# The corner frame is `gothic_field_hud._draw_screen_frame()` now. Drawing a
	# second one over it puts two sets of copper corners a few pixels apart,
	# which is the same mistake the Hunt already fixed once when it had two
	# control strips (I3).
	# `CellOutzType.draw_text` takes the top-left and `cap_height` is the cap, so
	# a 20-cap title at y=34 ends at y=54 and the strapline started at exactly
	# y=54 — no gap at all, and the title's own 2.6px stroke then ran straight
	# through the line below it. Set on a real leading instead.
	# Everything this scene draws that the Hunt does not is reference material,
	# and it now lives behind F1 rather than on top of the game.
	#
	# Greg, looking at the range beside the world: *"remove this green text top
	# right and the controls at the bottom"*, *"make it all match and the
	# same"*. The green telemetry sat directly over the vitals vessels
	# `gothic_field_hud` draws, and the key strip sat directly over the one it
	# draws too -- the exact double strip the Hunt removed for itself in I3,
	# rebuilt here by adding the Hunt panel underneath the sandbox one.
	#
	# The rule now is simply: if the Hunt does not show it, it is behind F1.
	if controls_expanded:
		# Something to read it against. The reference is text over a live 3D
		# scene, and at a glance the two were indistinguishable.
		hud.draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.015, 0.02, 0.86))
		CellOutzType.draw_text(hud, Vector2(26, 32), "GORE SANDBOX", 20.0, bone * Color(1, 1, 1, 0.85), 2.0)
		CellOutzType.draw_condensed(hud, Vector2(26, 62), "WIZARDS ONLY FOOLS  //  NOTHING HERE IS A MOCK-UP", 9.0, bone * Color(1, 1, 1, 0.4), 2.2)

	var compact := size.x < 900.0 or size.y < 560.0
	var keys := [["F1", "CONTROLS"], ["G", "DEVICE"], ["H", "DUMMIES"]] if compact else [
		["WASD", "MOVE/DRAG"], ["LMB", "FIRE/PRESS"], ["RMB", "AIM/HEAVY"],
		["SPACE", "JUMP/MOVE+DODGE"], ["C", "GRAPPLE/LET GO"], ["H", "DUMMY/ENEMY"],
		["6-9", "WEAPONS"], ["F1", "MORE CONTROLS"],
	]
	if controls_expanded:
		keys = [
			["WASD", "MOVE/DRAG"], ["LMB", "FIRE/PRESS"], ["RMB", "AIM/HEAVY"],
			["SPACE", "JUMP/MOVE+DODGE"], ["C", "GRAPPLE/LET GO"], ["H", "DUMMY/ENEMY"],
			["6-8", "MELEE/FIREARMS"], ["9", "BREACH LAUNCHER"], ["WHEEL", "CYCLE"], ["T", "RELOAD"],
			["SHIFT", "HOLD FOR SLOW"], ["X", "X-RAY"], ["Q", "CUT"], ["E", "TAKE"], ["F", "OPEN BODY"],
			["RMB", "GUARD (MOUSE PICKS SIDE)"], ["V", "1ST/3RD PERSON"],
			["1-4", "USE/HOLD SMOKE"], ["G", "DEVICE"], ["R", "RESET"], ["CTRL", "CROUCH"], ["F1", "LESS CONTROLS"],
		]
	# Emptied rather than branched around, so the layout below stays one code
	# path and cannot drift from the expanded one.
	if not controls_expanded:
		keys = []
	var row_size := 3 if compact and not controls_expanded else (7 if controls_expanded else 4)
	var row_count := ceili(float(keys.size()) / float(row_size))
	for index in keys.size():
		var pair: Array = keys[index]
		var row := index / row_size
		var in_row := index % row_size
		var column_width := (size.x - 52.0) / float(row_size)
		var x := 26.0 + float(in_row) * column_width
		var y_keys := size.y - 20.0 - float(row_count - row) * 21.0
		var used := CellOutzType.draw_condensed(hud, Vector2(x, y_keys), str(pair[0]), 10.0, rust, 1.8)
		CellOutzType.draw_condensed(hud, Vector2(x + used + 7.0, y_keys), str(pair[1]), 8.5, bone * Color(1, 1, 1, 0.55), 1.4)

	# What is actually on the floor. The interesting number in a gore sandbox.
	# Greg: *"CAN YOU FIX THE KNOCKDOWN ISSUE"*. This was it. The count tested
	# `dead` and nothing else, so a body that had gone down - unconscious, tipped
	# flat on its back by `BaselineHuman._on_went_down()`, lying in its own
	# blood - still counted as STANDING. The knockdown machinery works and has
	# the whole time; nothing in the sandbox ever said so, and a knockdown with
	# no acknowledgement anywhere on screen is indistinguishable from one that
	# did not happen.
	var standing := 0
	var downed := 0
	for entry: Dictionary in bodies:
		var rig := entry["rig"] as BaselineHuman
		if rig == null or not is_instance_valid(rig) or rig.anatomy.dead:
			continue
		if rig.anatomy.downed:
			downed += 1
		else:
			standing += 1
	var right_edge := size.x - 26.0
	# AF6.1. The weapon actually equipped, read live off `arsenal` rather than
	# a fixed label — a jam or an empty magazine is exactly the kind of thing
	# a range needs to say out loud rather than leave the player to guess at.
	var arsenal_state: Dictionary = arsenal.state()
	var weapon_line := "WEAPON  BREACH LAUNCHER // %d WARHEADS" % launcher_rounds if launcher_equipped else "WEAPON  %s" % str(arsenal.current().get("label", "?"))
	if not launcher_equipped and str(arsenal_state.get("kind", "")) == "firearm":
		if bool(arsenal_state.get("jammed", false)):
			weapon_line += "  //  JAMMED"
		elif bool(arsenal_state.get("reloading", false)):
			weapon_line += "  //  RELOADING"
		else:
			weapon_line += "  //  %d / %d" % [int(arsenal_state.get("loaded", 0)), int(arsenal_state.get("reserve", 0))]
	var lines := [
		weapon_line,
		"STANCE  %s // STAMINA %03d" % ["AIM" if firearm_aiming else ("DODGE" if dodge_remaining > 0.0 else "READY"), roundi(stamina)],
		"TRAINING  %s // SIM HEALTH %03d" % ["ENEMIES" if enemies_enabled else "DUMMIES", simulation_health],
		"STANDING  %d / %d" % [standing, BODY_COUNT],
		"DOWNED	%03d" % downed,
		"TAKEN OFF	%03d" % severed_total,
		"ON THE FLOOR  %03d" % GoreChunks.live_count(),
		"BRASS	%03d" % (ballistics.spent_brass() if ballistics != null else 0),
		"SPENT	%03d" % spent,
		# The number that says a round is a thing and not an event. It is 1 for
		# the frame or two a pistol round needs to cross this room, and it sits
		# there for seconds on end while slow motion is held.
		"IN FLIGHT  %03d" % _rounds_in_flight(),
	]
	# At small window sizes the old readout tried to preserve every internal
	# counter, drew itself outside the screen, and hid the actual game.  The
	# compact panel says only what a player can act on; F1 remains the route to
	# the fuller reference rather than a permanent debug flood.
	if compact:
		var compact_weapon := "%s // %d" % [str(arsenal.current().get("label", "WEAPON")).to_upper(), int(arsenal_state.get("loaded", 0))] if not launcher_equipped else "BREACH // %d" % launcher_rounds
		lines = [
			compact_weapon,
			"%s // STAMINA %03d" % ["AIM" if firearm_aiming else "READY", roundi(stamina)],
			"%s // %d UP" % ["ENEMIES" if enemies_enabled else "DUMMIES", standing],
		]
	# AF6.2. The last shot, read back rather than only felt: real distance,
	# real travel time, and how much muzzle energy actually survived the
	# trip — drag's real effect against a real number, not a cosmetic stat.
	if not last_shot_readout.is_empty():
		lines.append("LAST SHOT  %s @ %.1fm" % [
			str(last_shot_readout.get("calibre", "?")).to_upper(),
			float(last_shot_readout.get("distance", 0.0)),
		])
		lines.append("  %dms TRAVEL // %.1f%% ENERGY // %s" % [
			int(last_shot_readout.get("travel_ms", 0)),
			float(last_shot_readout.get("energy_pct", 1.0)) * 100.0,
			_spoken(str(last_shot_readout.get("zone", ""))),
		])
		lines.append("  %.1fcm DROP // %s" % [
			float(last_shot_readout.get("drop_cm", 0.0)),
			str(last_shot_readout.get("penetration", "NO BODY READ")),
		])
	# The green block. It is the single worst offender: it drew straight over
	# the blood and stamina vessels in the top right corner of the Hunt panel,
	# so the two readouts were legible only in the gaps between each other.
	if not controls_expanded:
		lines = []
	var y := 40.0
	var telemetry_cap := 8.5 if compact else 11.0
	var telemetry_spacing := 14.0 if compact else 18.0
	for line: String in lines:
		var width := CellOutzType.width_condensed(line, telemetry_cap, 2.0)
		CellOutzType.draw_condensed(hud, Vector2(right_edge - width, y), line, telemetry_cap, acid * Color(1, 1, 1, 0.8), 2.0)
		y += telemetry_spacing
	var carry_line := "CARRY  "
	for index in carried_substances.size():
		carry_line += "%d:%s  " % [index + 1, str((carried_substances[index] as Dictionary).get("id", "?")).to_upper()]
	if carried_substances.is_empty() and _near_pickup_source():
		carry_line += "EMPTY // [E] TAKE"
	if controls_expanded and (not carried_substances.is_empty() or _near_pickup_source()):
		var carry_cap := 8.5 if compact else 10.0
		var carry_width := CellOutzType.width_condensed(carry_line, carry_cap, 1.8)
		CellOutzType.draw_condensed(hud, Vector2(right_edge - carry_width, y + 10.0), carry_line, carry_cap, bone * Color(1, 1, 1, 0.62), 1.8)

	if xray:
		var tag := "X-RAY"
		var tag_width := CellOutzType.width_condensed(tag, 11.0, 3.0)
		CellOutzType.draw_condensed(hud, Vector2(right_edge - tag_width, y + 8.0), tag, 11.0, bone * Color(1, 1, 1, 0.7), 3.0)

	if slowed > 0.02:
		hud.draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.03, 0.02, slowed * 0.18))
		var label := "SLOW"
		var label_width := CellOutzType.width(label, 26.0, 6.0)
		CellOutzType.draw_text(hud, Vector2(size.x * 0.5 - label_width * 0.5, size.y * 0.5 - 120.0),
			label, 26.0, acid * Color(1, 1, 1, slowed * 0.5), 6.0)

	# One line, bottom right, so a scene with its chrome hidden still tells you
	# the chrome exists. It is the only permanent sandbox-only mark left.
	var hint := "F1  REFERENCE"
	var hint_width := CellOutzType.width_condensed(hint, 8.5, 1.6)
	CellOutzType.draw_condensed(hud, Vector2(size.x - 26.0 - hint_width, size.y - 30.0), hint, 8.5,
		bone * Color(1, 1, 1, 0.22), 1.6)

	if note_life > 0.0 and last_note != "":
		var note_width := CellOutzType.width(last_note, 17.0, 3.0)
		CellOutzType.draw_text(hud, Vector2(size.x * 0.5 - note_width * 0.5, size.y - 112.0),
			last_note, 17.0, rust * Color(1, 1, 1, clampf(note_life, 0.0, 1.0)), 3.0)

	# An Algiz-like sight: a cross at the centre rather than an OS pointer,
	# with branches that pulse during slow time. It stays precise enough to aim.
	var centre := size * 0.5
	var sight := rust.lerp(acid, slowed * 0.55) * Color(1, 1, 1, 0.88)
	hud.draw_circle(centre, 2.0, sight)
	hud.draw_line(centre + Vector2(0, 15), centre + Vector2(0, -15), sight, 1.5)
	hud.draw_line(centre + Vector2(0, -9), centre + Vector2(-8, -1), sight, 1.5)
	hud.draw_line(centre + Vector2(0, -9), centre + Vector2(8, -1), sight, 1.5)
	hud.draw_arc(centre, 17.0, 0.22, PI - 0.22, 16, sight * Color(1, 1, 1, 0.55), 1.0)
