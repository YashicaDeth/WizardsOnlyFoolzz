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
var _tracers: Array = []

var station: Node3D
var carried_substances: Array[Dictionary] = []
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
	# Starts on the sidearm — the same weapon the range always opened on before
	# AF6, so nobody's muscle memory for "LMB shoots a pistol" breaks. Switching
	# away from it is the new part, not the default.
	arsenal.select_slot(HunterArsenal.SLOT_ORDER.find("sidearm"))
	_build_view_gear()
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
	key.shadow_enabled = true
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
	if xray:
		rig.reveal_organs(true)
		rig.see_through(true)
	bodies.append({"holder": holder, "rig": rig, "id": "demo_body_%d" % index})


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
		(chunk as RigidBody3D).apply_central_impulse(lift * (1.0 - distance / reach) * force * 0.16)


## The trigger, and nothing but the trigger for a firearm — one real round
## leaves the barrel carrying the mark that says whose it is and what it will
## do when it lands (AF6.1: the current `HunterArsenal` weapon's own real
## damage/impulse/type, not one number fixed for the whole room); the brass
## comes off it; the gun goes back into the frame and the sight climbs. No
## anatomy is touched here, because the round has not arrived anywhere yet —
## that is the entire point. The sword has no round to fire, so it swings
## through `_melee_swing()` instead.
func _fire() -> void:
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
	var directions: Array[Vector3] = arsenal.shot_directions(along, Vector3.UP)
	var calibre := "buck" if directions.size() > 1 else "pistol"
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


## AF6.1. A sword has no round to travel and no barrel to leave from, so a
## swing resolves on the frame it lands rather than deferred like a firearm's
## round — the same instant-vs-travelling split `AN2.5`'s grip already draws
## between a cut and a shot. Reuses `_trace_body()` (already built for the
## blast's own crosshair targeting) rather than growing a second raycast path,
## the only new part is holding the hit to the weapon's own `reach` instead of
## the blast's much longer `TRACE_RANGE`.
func _melee_swing() -> void:
	var attack: Dictionary = arsenal.begin_attack()
	if not bool(attack.get("accepted", false)):
		return
	_gear_recoil = 1.0
	var along := -camera.global_transform.basis.z
	var start := camera.global_position + along * 0.6
	var reach := float(attack.get("range", 3.0))
	var found := _trace_body(start, along)
	if found.is_empty() or camera.global_position.distance_to(found.get("position", start)) > reach:
		_note("MISS")
		return
	var rig: BaselineHuman = found["rig"]
	var zone: String = found["zone"]
	var damage_type := str(attack.get("damage_type", "cut"))
	var result: Dictionary = rig.hit(zone, float(attack.get("damage", 0.0)), float(attack.get("impulse", 0.0)), damage_type, "", along)
	if not bool(result.get("accepted", true)):
		_note("%s ALREADY GONE" % _spoken(zone))
		return
	var off := bool(result.get("severed", false))
	if off:
		severed_total += 1
	_kick(0.9, damage_type, off, HITSTOP_SHOT)
	_note("%s OFF" % _spoken(zone) if off else "HIT // %s" % _spoken(zone))


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
	if _seen.has(serial):
		_streak(_seen[serial], at)
		_seen.erase(serial)

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
	# AF6.1. Read off the round's own payload rather than one fixed number —
	# `_fire()` carries the weapon that actually fired it, so a shotgun pellet
	# and a pistol round no longer do identical damage.
	var damage := float(payload.get("damage", 46.0))
	var impulse := float(payload.get("impulse", 30.0))
	var damage_type := str(payload.get("damage_type", "ballistic"))
	var result: Dictionary = rig.hit(zone, damage * carried, impulse * carried, damage_type, "", direction)
	if not bool(result.get("accepted", true)):
		_note("%s ALREADY GONE" % _spoken(zone))
		return
	var off := bool(result.get("severed", false))
	if off:
		severed_total += 1
	_kick(0.7 * carried, damage_type, off, HITSTOP_SHOT)
	_note("%s OFF" % _spoken(zone) if off else "HIT // %s" % _spoken(zone))


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
	# On the camera, because in this room the camera *is* the player — there is
	# no body and so no arm pose for the weapon to be hung off and cancelled
	# against, which is the only part of the Hunt's viewmodel path that cannot
	# come across. `HeldGear` poses itself off `GRIPS[...].rest`, in view space.
	camera.add_child(view_gear)
	view_gear.take(arsenal.current_id)
	_gear_rest = view_gear.position

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


## AF6.1. Every `HunterArsenal` weapon reachable in the sandbox, not just the
## one it opened on. Declined while mid-reload/jam-clear — `select_slot()`
## itself already refuses then — so a weapon swap can never strand a reload.
func _switch_weapon(slot: int) -> void:
	if slot < 0 or slot >= HunterArsenal.SLOT_ORDER.size():
		return
	if HunterArsenal.SLOT_ORDER[slot] == arsenal.current_id:
		return
	if not arsenal.select_slot(slot):
		_note("CAN'T SWITCH // BUSY")
		return
	view_gear.take(arsenal.current_id)
	_gear_rest = view_gear.position
	_refresh_muzzle_anchor()
	_note("EQUIPPED // %s" % str(arsenal.current().label))


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
		view_gear.position = _gear_rest + Vector3(0.0, 0.006, GEAR_RECOIL) * _gear_recoil

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
	var result := rig.hit(zone, 58.0, 72.0, "cut", "", along)
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * 0.0026
		pitch = clampf(pitch - motion.relative.y * 0.0024, -1.2, 0.9)
	if event is InputEventMouseButton and event.pressed:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			# Clicking back into a released mouse should not also fire a round
			# into whatever happened to be under the cursor.
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
			_fire()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			# A blast where you are looking, not where you are standing — and
			# put against whatever the crosshair is actually on, so it goes off
			# at the body rather than in the air somewhere near it.
			var along := -camera.global_transform.basis.z
			var found := _trace_body(camera.global_position + along * 0.6, along)
			var at: Vector3 = found.get("position", camera.global_position + along * 6.0)
			_explode(at, 58.0)
		elif click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
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
			KEY_E: _take_station_item()
			KEY_G:
				if handheld != null:
					handheld.toggle_device()
			KEY_Q: _cut()
			KEY_R: _reset()
			KEY_X: _set_xray(not xray)
			KEY_ESCAPE: _step_out()
			KEY_F: _explode(camera.global_position + Vector3(0, 0.4, 0), 92.0)
			KEY_6: _switch_weapon(HunterArsenal.SLOT_ORDER.find("sword"))
			KEY_7: _switch_weapon(HunterArsenal.SLOT_ORDER.find("shotgun"))
			KEY_8: _switch_weapon(HunterArsenal.SLOT_ORDER.find("sidearm"))
			KEY_T:
				if not arsenal.reload():
					_note("CAN'T RELOAD")


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
	if station == null:
		return
	var taken: Dictionary = station.take_nearest(eye)
	if taken.is_empty():
		_note("NO SUBSTANCE WITHIN REACH")
		return
	# The signal appends the actual data; this only narrates the physical action.
	_note("TAKEN // %s" % str(taken.get("label", "UNMARKED")))


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

	var forward := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(forward.z, 0, -forward.x)
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move -= forward
	if Input.is_key_pressed(KEY_S): move += forward
	if Input.is_key_pressed(KEY_A): move -= right
	if Input.is_key_pressed(KEY_D): move += right
	walk = walk.lerp(move.normalized() * 7.0, clampf(real_delta * 14.0, 0.0, 1.0))
	eye += walk * real_delta
	eye.x = clampf(eye.x, -ARENA + 2.0, ARENA - 2.0)
	eye.z = clampf(eye.z, -ARENA + 2.0, ARENA - 2.0)
	eye.y = 1.68

	# The third of the three things that are supposed to arrive together on
	# contact. The feeler has been carrying this the whole time and nothing in
	# this scene was asking it for anything.
	var shove: Vector2 = impact_feel.camera_offset()
	camera.global_position = eye
	camera.global_transform.basis = Basis(Vector3.UP, yaw + shove.x) * Basis(Vector3.RIGHT, pitch + shove.y) * Basis(Vector3.FORWARD, impact_feel.roll)

	# Everything a shot owes the eye, timed in real seconds like the hitstop is:
	# a tracer measured on the bent clock would hang in the air for a second and
	# a half the moment slow motion is held, which is a laser, not a bullet.
	_advance_shot_feel(real_delta)
	# Real seconds, same as the hitstop and the tracers above — reload and jam
	# recovery are muscle-memory timing a player is meant to be testing here,
	# not something holding slow motion should let them cheat.
	arsenal.tick(real_delta)

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
	hud.draw.connect(_paint_hud)
	layer.add_child(hud)
	# Same damaged CellOutz hardware as the Hunt, not a sandbox text panel.
	handheld = HandheldDevice.new()
	handheld.name = "SandboxHandheld"
	layer.add_child(handheld)
	psychedelic = PSYCHEDELIC_RIG.new()
	psychedelic.name = "SandboxPsychedelic"
	layer.add_child(psychedelic)


func _paint_hud() -> void:
	var bone := Color("ead4ad")
	var acid := Color("9bf01a")
	var rust := Color("b0552a")
	var size := hud.size

	# A damaged field instrument, not a clean debug overlay. The corners and
	# centre sigil use the same copper/blood language as the front door and the
	# handheld so this room reads as part of the game before anything is shot.
	var frame := Color("862016")
	hud.draw_line(Vector2(18, 18), Vector2(250, 18), frame * Color(1, 1, 1, 0.82), 2.0)
	hud.draw_line(Vector2(18, 18), Vector2(18, 104), frame * Color(1, 1, 1, 0.82), 2.0)
	hud.draw_line(Vector2(size.x - 18, 18), Vector2(size.x - 250, 18), frame * Color(1, 1, 1, 0.82), 2.0)
	hud.draw_line(Vector2(size.x - 18, 18), Vector2(size.x - 18, 104), frame * Color(1, 1, 1, 0.82), 2.0)
	hud.draw_line(Vector2(18, size.y - 18), Vector2(250, size.y - 18), frame * Color(1, 1, 1, 0.55), 2.0)
	hud.draw_line(Vector2(size.x - 18, size.y - 18), Vector2(size.x - 250, size.y - 18), frame * Color(1, 1, 1, 0.55), 2.0)
	# `CellOutzType.draw_text` takes the top-left and `cap_height` is the cap, so
	# a 20-cap title at y=34 ends at y=54 and the strapline started at exactly
	# y=54 — no gap at all, and the title's own 2.6px stroke then ran straight
	# through the line below it. Set on a real leading instead.
	CellOutzType.draw_text(hud, Vector2(26, 32), "GORE SANDBOX", 20.0, bone * Color(1, 1, 1, 0.85), 2.0)
	CellOutzType.draw_condensed(hud, Vector2(26, 62), "WIZARDS ONLY FOOLS  //  NOTHING HERE IS A MOCK-UP", 9.0, bone * Color(1, 1, 1, 0.4), 2.2)

	var keys := [
		["LMB", "FIRE/SWING"], ["RMB", "BLAST THERE"], ["F", "BLAST HERE"],
		["6-8", "WEAPON"], ["WHEEL", "CYCLE"], ["T", "RELOAD"],
		["SHIFT", "HOLD FOR SLOW"], ["X", "X-RAY"], ["Q", "CUT"], ["E", "TAKE"], ["1-4", "USE/HOLD SMOKE"], ["G", "DEVICE"], ["R", "RESET"], ["WASD", "MOVE"],
	]
	var x := 26.0
	for pair: Array in keys:
		x += CellOutzType.draw_condensed(hud, Vector2(x, size.y - 26.0), str(pair[0]), 11.0, rust, 2.0) + 13.0
		x += CellOutzType.draw_condensed(hud, Vector2(x, size.y - 26.0), str(pair[1]), 10.0, bone * Color(1, 1, 1, 0.55), 1.6) + 22.0

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
	var weapon_line := "WEAPON  %s" % str(arsenal.current().get("label", "?"))
	if str(arsenal_state.get("kind", "")) == "firearm":
		if bool(arsenal_state.get("jammed", false)):
			weapon_line += "  //  JAMMED"
		elif bool(arsenal_state.get("reloading", false)):
			weapon_line += "  //  RELOADING"
		else:
			weapon_line += "  //  %d / %d" % [int(arsenal_state.get("loaded", 0)), int(arsenal_state.get("reserve", 0))]
	var lines := [
		weapon_line,
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
	var y := 40.0
	for line: String in lines:
		var width := CellOutzType.width_condensed(line, 11.0, 2.0)
		CellOutzType.draw_condensed(hud, Vector2(right_edge - width, y), line, 11.0, acid * Color(1, 1, 1, 0.8), 2.0)
		y += 18.0
	var carry_line := "CARRY  "
	for index in carried_substances.size():
		carry_line += "%d:%s  " % [index + 1, str((carried_substances[index] as Dictionary).get("id", "?")).to_upper()]
	if carried_substances.is_empty():
		carry_line += "EMPTY // [E] AT THE STATION"
	var carry_width := CellOutzType.width_condensed(carry_line, 10.0, 1.8)
	CellOutzType.draw_condensed(hud, Vector2(right_edge - carry_width, y + 10.0), carry_line, 10.0, bone * Color(1, 1, 1, 0.62), 1.8)

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

	if note_life > 0.0 and last_note != "":
		var note_width := CellOutzType.width(last_note, 17.0, 3.0)
		CellOutzType.draw_text(hud, Vector2(size.x * 0.5 - note_width * 0.5, size.y - 84.0),
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
