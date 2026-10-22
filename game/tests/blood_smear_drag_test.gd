extends Node

## AN6.8. The drag itself, in the game rather than in the blood system's own
## harness.
##
## `blood_smear_test` moves a bare node by hand and calls `BloodSmear.follow`
## itself, which proves the streak is drawn but not that anything in play
## produces one. This test never calls the smear system. It puts somebody in a
## clinch, holds W through `_update_grapple()` — the same call WASD makes — and
## then reads the floor: continuous marks, oriented along the path the body was
## taken, paid for out of that body, and nothing at all behind a captive who is
## not bleeding.

const HUNT := preload("res://bone_yard_hunt.tscn")
const TICK := 0.05

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	BloodSmear.clear()
	var hunt := HUNT.instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	for existing: Dictionary in hunt.encounter_actors:
		if is_instance_valid(existing.get("node")):
			existing.node.queue_free()
	hunt.encounter_actors.clear()
	hunt.player = Vector3(0, 1.5, 19)
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.yaw = PI

	# The body that bleeds is the one under the reticle; the dry one waits off
	# the axis so the same public acquire path can reach it afterwards.
	hunt._spawn_encounter_actor({"instance_id": "smear_dry", "kind": "hostile"}, hunt.player + Vector3(1.7, -0.6, -1.2))
	var dry: Dictionary = hunt.encounter_actors.back()
	hunt._spawn_encounter_actor({"instance_id": "smear_bleeder", "kind": "hostile"}, hunt.player + Vector3(0.0, -0.6, -2.0))
	var bleeder: Dictionary = hunt.encounter_actors.back()
	var rig: BaselineHuman = bleeder.rig
	check(rig != null and is_instance_valid(rig), "the held body has an anatomy to bleed from")

	rig._record_wound("left_arm", rig.global_position + Vector3(-0.22, 0.35, -0.02), Vector3(0, 0, 1), 55.0, "ballistic", 0.75)
	rig.anatomy.bleed_rate = 3.0
	rig.anatomy.blood_remaining = rig.anatomy.blood_capacity * 0.85
	var blood_before: float = rig.anatomy.blood_remaining

	hunt._start_grapple()
	check(hunt.grapple_target == str(bleeder.subject_id), "C takes hold of the body that will be dragged")
	var start: Vector3 = bleeder.node.global_position

	# The only thing that moves the captive is the player walking while holding
	# them. The override stands in for a held W key, which cannot be raised
	# headless; nothing else in this loop touches the body.
	hunt.grapple_pushing_override = false
	hunt.grapple_drag_override = Vector2(0, -1)
	for tick in 60:
		hunt.grapple_advantage = 0.0
		hunt._update_grapple(TICK)
	hunt.grapple_drag_override = null
	hunt.grapple_pushing_override = null

	var moved: Vector3 = bleeder.node.global_position - start
	moved.y = 0.0
	check(moved.length() > 0.8, "the player walked the body across the floor (%.2f m)" % moved.length())

	var trail := BloodSmear.trail_for(hunt, bleeder.node)
	check(not trail.is_empty(), "a body dragged by the player's own walk leaves a trail")
	var segments := int(trail.get("segments", 0))
	var length := float(trail.get("length", 0.0))
	check(segments >= 8, "with many marks rather than one (%d segments)" % segments)
	check(length > moved.length() * 0.6, "and the marks cover the path it was taken along (%.2f m of %.2f m)" % [length, moved.length()])

	# Continuous: no hole in the streak wider than one mark, so it reads as a
	# drag rather than a dotted line.
	var points: PackedVector3Array = trail.get("points", PackedVector3Array())
	var widest_gap := 0.0
	for index in points.size() - 1:
		widest_gap = maxf(widest_gap, points[index].distance_to(points[index + 1]))
	check(widest_gap <= BloodSmear.SEGMENT_SPACING * 1.8,
		"no gap in the streak is wider than a mark (%.3f m)" % widest_gap)

	# Oriented the way the body actually went, not merely "a trail exists".
	var heading: Vector3 = trail.get("heading", Vector3.ZERO)
	var along := moved.normalized() if moved.length_squared() > 0.0001 else Vector3.ZERO
	check(heading.dot(along) > 0.9, "and it points the way the body was taken (%s)" % str(heading.snapped(Vector3(0.01, 0.01, 0.01))))

	var node := trail.get("mesh") as MeshInstance3D
	check(node != null and node.mesh != null and node.mesh.get_surface_count() > 0, "the streak is actually drawn in the hunt")

	check(BloodPool.pool_count(hunt) >= 1, "the floor's own pool system took the blood")
	var blood_after: float = rig.anatomy.blood_remaining
	check(blood_after < blood_before, "and the dragged body paid for it (%.0f -> %.0f mL)" % [blood_before, blood_after])

	# --- a captive with nothing to lose leaves nothing -----------------------
	# The guard has to hold through this new path too, or every clinch would
	# paint the floor.
	hunt._break_grapple("TEST RELEASE")
	hunt.player_body.global_position = dry.node.global_position - Vector3(0, 0, 1.5)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.player = hunt.player_body.global_position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.stamina = 100.0
	hunt._start_grapple()
	check(hunt.grapple_target == str(dry.subject_id), "the dry body can be taken in the same hold")
	hunt.grapple_drag_override = Vector2(0, -1)
	for tick in 30:
		hunt.grapple_advantage = 0.0
		hunt._update_grapple(TICK)
	hunt.grapple_drag_override = null
	check(BloodSmear.segment_count(hunt, dry.node) == 0, "a body with no wound dragged the same way leaves the floor clean")

	print("BLOOD_SMEAR_DRAG_TEST_RESULT failures=", failures.size())
	hunt.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)
