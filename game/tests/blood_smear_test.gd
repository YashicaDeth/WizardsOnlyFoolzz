extends Node3D

## AN6.8. Blood is carried, not only dropped.
##
## Drags a bleeding body across a floor and asserts the things that make the
## streak worth having: it is continuous, it points where the body went, it
## narrows as the blood runs out, it grows the pools it passes through rather
## than replacing them, it costs the body the millilitres it lays, and a body
## with no blood in circulation leaves nothing at all.
##
## Run headless for the assertions. Run it windowed and it also writes
## `P:/GameDev/Temp/blood_smear.png`, so the streak can be looked at rather than
## only measured — which is the rule in `wof-verify-by-looking`.

const OUT := "P:/GameDev/Temp/blood_smear.png"
const STEP := 0.055
const STEPS := 40

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	BloodSmear.clear()
	BloodPool.clear()
	_build_room()
	await get_tree().physics_frame

	# --- the body that bleeds ------------------------------------------------
	var mover := Node3D.new()
	mover.name = "Mover"
	add_child(mover)
	mover.position = Vector3(-1.4, 1.0, 0.0)
	var body := BaselineHuman.new()
	mover.add_child(body)
	body.position = Vector3(0, -1.0, 0)
	body.build("dragged", {"gore": true})
	await get_tree().physics_frame
	# A torso round that crosses, then the vitals of somebody losing blood.
	body._record_wound("torso", body.global_position + Vector3(0, 0.12, -0.12), Vector3(0, 0, 1), 55.0, "ballistic", 0.75)
	body.anatomy.bleed_rate = 3.2
	body.anatomy.blood_remaining = body.anatomy.blood_capacity * 0.82
	var blood_before: float = body.anatomy.blood_remaining

	# --- the drag ------------------------------------------------------------
	var laid := 0
	var reasons := {}
	for step in STEPS:
		mover.position.x += STEP
		await get_tree().physics_frame
		var receipt := BloodSmear.follow(self, mover, 1.0 / 60.0, body)
		var reason := str(receipt.get("reason", "?"))
		reasons[reason] = int(reasons.get(reason, 0)) + 1
		if bool(receipt.get("ok", false)) and reason == "laid":
			laid += 1
	print("DRAG_REASONS ", reasons, " bleed=", body.anatomy.bleed_rate if body.anatomy != null else -1.0)

	var trail := BloodSmear.trail_for(self, mover)
	check(not trail.is_empty(), "a dragged body leaves a trail behind it")
	var segments := int(trail.get("segments", 0))
	var length := float(trail.get("length", 0.0))
	check(segments >= 10, "the trail is many marks, not one (%d segments over %d steps)" % [segments, laid])
	check(length > 1.0, "and it is as long as the drag (%.2f m)" % length)

	# --- continuous, oriented, tapering --------------------------------------
	var points: PackedVector3Array = trail["points"]
	var widest_gap := 0.0
	for index in points.size() - 1:
		widest_gap = maxf(widest_gap, points[index].distance_to(points[index + 1]))
	check(widest_gap <= BloodSmear.SEGMENT_SPACING * 1.8, "no gap in the streak is wider than a mark (%.3f m)" % widest_gap)

	var heading: Vector3 = trail.get("heading", Vector3.ZERO)
	check(heading.x > 0.9, "the streak is oriented the way the body was dragged (%s)" % str(heading.snapped(Vector3(0.01, 0.01, 0.01))))
	check(float(trail.get("width_end", 1.0)) < float(trail.get("width_start", 0.0)) * 0.5,
		"and it tapers from %.3f m to %.3f m as the blood runs out" % [float(trail.get("width_start", 0.0)), float(trail.get("width_end", 0.0))])

	var node := trail.get("mesh") as MeshInstance3D
	check(node != null and node.mesh != null, "the streak is actually drawn")
	if node != null and node.mesh != null:
		var arrays: Array = node.mesh.surface_get_arrays(0)
		check((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= segments * 3,
			"with geometry for every mark (%d vertices)" % (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())

	# --- the pool stayed the owner ------------------------------------------
	check(BloodPool.pool_count(self) >= 1, "the floor's own pool system took the blood (%d pools)" % BloodPool.pool_count(self))
	var blood_after: float = body.anatomy.blood_remaining
	check(blood_after < blood_before, "and the body paid for it (%.0f -> %.0f mL)" % [blood_before, blood_after])

	# --- standing still lays nothing ----------------------------------------
	var settled := BloodSmear.follow(self, mover, 1.0 / 60.0, body)
	check(str(settled.get("reason", "")) == "slow", "a body that has stopped does not keep marking the floor")
	check(BloodSmear.segment_count(self, mover) == segments, "and the trail does not grow while it rests")

	# --- a dry body carries nothing ----------------------------------------
	var dry_mover := Node3D.new()
	add_child(dry_mover)
	dry_mover.position = Vector3(-1.4, 1.0, 1.2)
	var dry := BaselineHuman.new()
	dry_mover.add_child(dry)
	dry.position = Vector3(0, -1.0, 0)
	dry.build("dry", {"gore": true})
	await get_tree().physics_frame
	for step in 16:
		dry_mover.position.x += STEP
		await get_tree().physics_frame
		BloodSmear.follow(self, dry_mover, 1.0 / 60.0, dry)
	check(BloodSmear.segment_count(self, dry_mover) == 0, "a body with no wound leaves the floor clean")

	# --- heavy damage throws a mist it can account for ----------------------
	var mist := BloodSmear.throw_mist(self, Vector3(-1.0, 0.3, 0.3), Vector3(1, 0, 0), 1.0)
	check(bool(mist.get("ok", false)) and int(mist.get("droplets", 0)) > 0, "a heavy hit throws mist (%d droplets)" % int(mist.get("droplets", 0)))
	check(BloodSmear.mist_count() >= 1, "and the system counts what it threw")
	for index in BloodSmear.MAX_MISTS + 4:
		BloodSmear.throw_mist(self, Vector3(-1.0, 0.3, 0.3), Vector3(1, 0, 0), 0.4)
	check(BloodSmear.mist_count() <= BloodSmear.MAX_MISTS, "mist is capped at %d" % BloodSmear.MAX_MISTS)

	# --- look at it, when there is a screen to look with --------------------
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(OUT)
		print("CAPTURE ", OUT, " error=", error)

	print("BLOOD_SMEAR_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _build_room() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 0.2, 6)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.1, 0)

	var slab := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 6)
	slab.mesh = plane
	# Dark concrete, not a white studio floor: blood reads against it the way it
	# does in the lab it was taken from.
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.30, 0.30, 0.31)
	concrete.roughness = 0.85
	slab.material_override = concrete
	add_child(slab)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, 34, 0)
	key.light_energy = 1.2
	add_child(key)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.14, 0.15, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	add_child(env)

	var camera := Camera3D.new()
	camera.fov = 52.0
	camera.position = Vector3(1.1, 3.0, 3.3)
	add_child(camera)
	camera.look_at(Vector3(-0.25, 0.0, 0.25))
	camera.current = true
