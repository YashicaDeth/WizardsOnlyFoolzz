extends Node

## A dodge kicks up ash that drifts against the direction of travel and is
## gone within its life; bursts reuse the pool rather than growing it.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var dust := DustPuff.new()
	add_child(dust)
	check(dust.live_count() == 0, "nothing hangs in the air before a dodge")
	dust.burst(Vector3.ZERO, Vector3(1, 0, 0))
	check(dust.live_count() == DustPuff.PER_BURST, "a dodge kicks up one burst")
	var start := {}
	for child in dust.get_children():
		if (child as Node3D).visible:
			start[child] = (child as Node3D).global_position.x
	for i in 10:
		dust._process(1.0 / 60.0)
	var every_back := true
	for child in start:
		every_back = every_back and (child as Node3D).global_position.x < float(start[child])
	check(every_back, "every billow drifts back, against the direction of the dodge")
	for i in 10:
		dust.burst(Vector3.ZERO, Vector3.FORWARD)
	check(dust.get_child_count() == DustPuff.POOL, "repeated dodges reuse the pool")
	for i in 60:
		dust._process(1.0 / 60.0)
	check(dust.live_count() == 0, "it all settles within its life")
	print("DUST_PUFF_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
