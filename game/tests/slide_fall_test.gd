extends Node3D

## Greg, 26 September: sprint + Ctrl slides for about a second; falls hurt
## only past 2.5 m and never more than 15 blood.

const JUMP_CLIMB := preload("res://systems/jump_climb.gd")

var failures := 0
var body: CharacterBody3D
var hurt_total := 0.0


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _physics_process(delta: float) -> void:
	if body == null:
		return
	if not JUMP_CLIMB.slide_step(body, delta):
		body.velocity.x = move_toward(body.velocity.x, 0.0, 30.0 * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, 30.0 * delta)
	JUMP_CLIMB.fall(body, delta)
	body.move_and_slide()
	hurt_total += JUMP_CLIMB.landing_damage(body)


func settle(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _ready() -> void:
	WorldHistory.clear_history()
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)
	body = CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	collider.shape = capsule
	body.add_child(collider)
	body.position = Vector3(0, 0.9, 0)
	add_child(body)
	await settle(20)

	check(not JUMP_CLIMB.try_slide(body, 0.0, false), "no slide without sprinting")
	body.velocity = Vector3(0, 0, -5.4)
	check(JUMP_CLIMB.try_slide(body, 0.0, true), "sprint + Ctrl slides")
	var start := body.global_position
	var frames := 0
	while JUMP_CLIMB.sliding(body) and frames < 200:
		await get_tree().physics_frame
		frames += 1
	var seconds := float(frames) / float(Engine.physics_ticks_per_second)
	var travelled := start.distance_to(body.global_position)
	check(seconds > 0.8 and seconds < 1.2, "it lasts about a second (%.2fs)" % seconds)
	check(travelled > 3.5, "and carries you forward (%.1f m)" % travelled)

	hurt_total = 0.0
	body.global_position = Vector3(0, 0.9 + 2.0, 10)
	await settle(60)
	check(hurt_total == 0.0, "a 2 m drop does not hurt")
	body.global_position = Vector3(0, 0.9 + 4.0, 10)
	await settle(80)
	check(hurt_total > 0.0 and hurt_total <= JUMP_CLIMB.FALL_MAX, "a 4 m drop stings (%.1f blood)" % hurt_total)
	hurt_total = 0.0
	body.global_position = Vector3(0, 0.9 + 30.0, 10)
	await settle(200)
	check(is_equal_approx(hurt_total, JUMP_CLIMB.FALL_MAX), "a huge drop is capped at %d blood (%.1f)" % [JUMP_CLIMB.FALL_MAX, hurt_total])
	check(WorldHistory.event_count("player_fall_hurt") == 2 and WorldHistory.event_count("player_slid") == 1, "slides and falls are on record")
	print("SLIDE_FALL_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
