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
## 1. **Bullets went through everybody.** `Ballistics` traces its rounds with
##	  `collide_with_areas = false`, and every hitbox on a `BaselineHuman` is an
##	  `Area3D`. Rounds passed through a body and stopped on the wall behind it,
##	  and the old code then went looking for somebody within 1.4m of that wall.
##	  Damage is resolved by its own trace on the frame the trigger goes down now
##	  — which is exactly what the Hunt does (`_trace_actor` in
##	  `bone_yard_hunt.gd`) and for the same reason — while the visible round
##	  still flies for the tracer, the hole and the brass.
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


var station: Node3D
var carried_substances: Array[Dictionary] = []
var handheld: HandheldDevice


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
	for entry: Dictionary in bodies:
		var holder := entry["holder"] as Node3D
		if is_instance_valid(holder):
			holder.queue_free()
	bodies.clear()
	GoreChunks.clear()
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


func _fire() -> void:
	var along := -camera.global_transform.basis.z
	var muzzle := camera.global_position + along * 0.6
	# The round you can see, and the brass on the floor afterwards. Cosmetic
	# only: it is traced with `collide_with_areas = false` and will pass
	# straight through the body this shot is about to resolve against.
	ballistics.fire(muzzle, along, "rifle", 0.0, 1, "demo")
	spent += 1

	var found := _trace_body(muzzle, along)
	if found.is_empty():
		_note("MISS")
		return
	var rig := found["rig"] as BaselineHuman
	var zone := str(found["zone"])
	var result: Dictionary = rig.hit(zone, 46.0, 30.0, "ballistic", "", along)
	if not bool(result.get("accepted", true)):
		_note("%s ALREADY GONE" % _spoken(zone))
		return
	var off := bool(result.get("severed", false))
	if off:
		severed_total += 1
	_kick(0.7, "ballistic", off, HITSTOP_SHOT)
	_note("%s OFF" % _spoken(zone) if off else "HIT // %s" % _spoken(zone))


## Where the shot actually lands, on the zone that was actually aimed at.
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
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: _take_station_item()
			KEY_G:
				if handheld != null:
					handheld.toggle_device()
			KEY_1: _use_carried(0)
			KEY_2: _use_carried(1)
			KEY_3: _use_carried(2)
			KEY_4: _use_carried(3)
			KEY_R: _reset()
			KEY_X: _set_xray(not xray)
			KEY_ESCAPE: _step_out()
			KEY_F: _explode(camera.global_position + Vector3(0, 0.4, 0), 92.0)


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


func _use_carried(index: int) -> void:
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
		result = SMOKEABLES.hit(SANDBOX_SUBJECT, str(item.get("id", "")), 0.55, Time.get_ticks_msec() * 0.001)
	if bool(result.get("ok", false)):
		carried_substances.remove_at(index)
		_note("DOSE BEGUN // %s" % str(item.get("label", item.get("id", ""))))
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

	note_life = maxf(0.0, note_life - real_delta)
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
	CellOutzType.draw_text(hud, Vector2(26, 34), "GORE SANDBOX", 20.0, bone * Color(1, 1, 1, 0.85), 2.0)
	CellOutzType.draw_condensed(hud, Vector2(26, 54), "WIZARDS ONLY FOOLS  //  NOTHING HERE IS A MOCK-UP", 9.0, bone * Color(1, 1, 1, 0.4), 2.2)

	var keys := [
		["LMB", "SHOOT"], ["RMB", "BLAST THERE"], ["F", "BLAST HERE"],
		["SHIFT", "HOLD FOR SLOW"], ["X", "X-RAY"], ["E", "TAKE"], ["1-4", "USE"], ["G", "DEVICE"], ["R", "RESET"], ["WASD", "MOVE"],
	]
	var x := 26.0
	for pair: Array in keys:
		x += CellOutzType.draw_condensed(hud, Vector2(x, size.y - 26.0), str(pair[0]), 11.0, rust, 2.0) + 13.0
		x += CellOutzType.draw_condensed(hud, Vector2(x, size.y - 26.0), str(pair[1]), 10.0, bone * Color(1, 1, 1, 0.55), 1.6) + 22.0

	# What is actually on the floor. The interesting number in a gore sandbox.
	var standing := 0
	for entry: Dictionary in bodies:
		var rig := entry["rig"] as BaselineHuman
		if rig != null and is_instance_valid(rig) and not rig.anatomy.dead:
			standing += 1
	var right_edge := size.x - 26.0
	var lines := [
		"STANDING  %d / %d" % [standing, BODY_COUNT],
		"TAKEN OFF	%03d" % severed_total,
		"ON THE FLOOR  %03d" % GoreChunks.live_count(),
		"BRASS	%03d" % (ballistics.spent_brass() if ballistics != null else 0),
		"SPENT	%03d" % spent,
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
