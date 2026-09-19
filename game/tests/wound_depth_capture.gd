extends Node3D

## AN6.1 — a wound is an opening with depth, not a decal.
##
## The depth number was already being produced and already being stored:
## `Penetration.resolve()` has returned a `fraction` since it was written, and
## `baseline_human._record_wound()` has written it onto every wound dictionary.
## What nothing did was *draw* it. `_crater()` sank its centre by a constant
## multiple of the rim radius, so the fraction only ever reached the geometry
## through `radius` — a round that blew out the far side and one that barely
## broke the skin were the same hole at two widths. Wider, never deeper. A
## decal, which is exactly what AN6.1 says a wound is not.
##
## A passing assertion about an AABB does not settle whether that reads, so this
## photographs it twice:
##
## 1. **The ladder.** The same crater — same radius, same seed, so the outline is
##    literally identical — built at five penetration fractions and lit from a
##    raking angle. Radius is held constant here *on purpose*: it is the one
##    place the old behaviour is subtracted out, so anything visible between the
##    five is the new axis and nothing else.
## 2. **The gameplay result.** Two bodies shot in the same place with the same
##    damage, one with a round that stops just inside and one with a round that
##    crosses the torso. Here radius moves too, because that is what the player
##    actually sees.

const HUMAN := preload("res://systems/baseline_human.gd")

## Where the ladder's five craters sit, in penetration fraction. 0.0 is a round
## that had nothing left on arrival; 1.0 is one that went out the far side.
const LADDER := [0.0, 0.25, 0.5, 0.75, 1.0]
## Held constant across the ladder so depth is the only thing moving.
const LADDER_RADIUS := 0.075
const LADDER_SPACING := 0.22

## A round that stops just inside a torso, and one that crosses it. Torso depth
## front-to-back is 0.113 m and `Penetration.METRES_PER_POINT` is 0.45, so 0.05
## reaches 22 mm and stops, and 0.60 reaches 270 mm and leaves through the back.
const SHALLOW_ROUND := 0.05
const THROUGH_ROUND := 0.60


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	_light()

	var ladder_heights := await _capture_ladder()
	var body_heights := await _capture_bodies()

	# Printed beside the images so the photograph and the measurement are the
	# same run rather than two claims that have to be trusted to agree.
	print("ladder sink by fraction: ", ladder_heights)
	print("graze vs through sink: ", body_heights)
	print("WOUND_DEPTH_CAPTURE_RESULT saved")
	get_tree().quit(0)


func _light() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("14100e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b8a898")
	e.ambient_light_energy = 1.1
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	# Low and across the row, so an opening casts into itself and a dimple does
	# not. Lighting a crater from overhead is how you photograph a decal.
	key.rotation_degrees = Vector3(-22, 54, 0)
	key.light_energy = 1.6
	add_child(key)


## Panel 1. Five identical outlines, five different depths.
##
## Shot in profile against the background rather than laid into a surface. A
## crater's mouth is coplanar with the skin it sits in — on a body that is
## correct, because the limb it is parented to is curved and the wound rides
## it, but a flat demonstration slab would simply cover every mouth and
## photograph five lip rings. Edge-on, the sink is the silhouette, which is the
## thing being demonstrated. Panel 2 is the one that shows it in a surface.
func _capture_ladder() -> Array:
	var heights := []
	var start := -LADDER_SPACING * (float(LADDER.size()) - 1.0) * 0.5
	for index in LADDER.size():
		var fraction: float = LADDER[index]
		var wound := WoundMarks.make(Vector3.ZERO, Vector3.UP, 40.0, "ballistic", 0)
		# Same seed across the row: the wobble that makes each hole individual
		# would otherwise be mistaken for the difference being demonstrated.
		wound["seed"] = 4242
		wound["radius"] = LADDER_RADIUS
		wound["depth"] = fraction
		wound["at"] = Vector3(start + LADDER_SPACING * float(index), 0.0, 0.0)
		var node := WoundMarks.build(wound, Color("c9a893"))
		add_child(node)
		heights.append(snappedf(node.mesh.get_aabb().size.y, 0.0001))

	var cam := Camera3D.new()
	cam.fov = 30.0
	# Barely above the rim line, so each crater reads as how far it drops below
	# its own opening rather than as a circle seen from overhead.
	cam.position = Vector3(0.0, 0.085, 1.25)
	add_child(cam)
	cam.look_at(Vector3(0, -0.035, 0), Vector3.UP)
	for _s in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://captures/an6_1_wound_depth_ladder.png"))

	cam.queue_free()
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()
	await get_tree().process_frame
	return heights


## Panel 2. The same two rounds a player would actually fire.
func _capture_bodies() -> Array:
	var ground := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.4, 30)
	col.shape = box
	col.position = Vector3(0, -0.2, 0)
	ground.add_child(col)
	add_child(ground)

	var heights := []
	var shots := [SHALLOW_ROUND, THROUGH_ROUND]
	var bodies := []
	for index in shots.size():
		var body: BaselineHuman = HUMAN.new()
		add_child(body)
		body.build("depth_body_%d" % index, {})
		body.position = Vector3(-0.28 + 0.56 * float(index), 0, 0)
		bodies.append(body)
	await get_tree().process_frame
	await get_tree().process_frame

	for index in bodies.size():
		var body: BaselineHuman = bodies[index]
		var torso := body.parts.get("torso") as Node3D
		# Same place on each chest, same damage, same direction. The round is
		# the only difference between the two photographs.
		body.hit_at(torso.global_position + Vector3(0.0, 0.06, 0.17), 24.0, 1.2,
			"ballistic", Vector3(0, 0, -1), shots[index])
		var marks: Array = body.wound_marks.get("torso", []) as Array
		var entry: Dictionary = marks[0] if marks.size() > 0 else {}
		heights.append({
			"round": shots[index],
			"fraction": snappedf(float(entry.get("depth", -1.0)), 0.001),
			"through": bool(entry.get("through", false)),
			"wounds": marks.size(),
		})

	# Let the burst settle, or the photograph is of airborne tissue.
	for _s in 120:
		await get_tree().process_frame

	var cam := Camera3D.new()
	# Long lens from further back rather than a wide one up close: both chests
	# stay square to the camera and at the same angle, so the only difference
	# between the two halves of the frame is the round that made the hole.
	cam.fov = 16.0
	cam.position = Vector3(0.0, 1.21, 2.20)
	add_child(cam)
	cam.look_at(Vector3(0, 1.18, 0), Vector3.UP)
	for _s in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://captures/an6_1_wound_depth_rounds.png"))
	return heights
