extends Node3D

## A parry reads and rings: nothing when idle; a star, a ring, a fan of sparks
## thrown along the attacking blade, a light and a clang when driven; the pool
## stays bounded and is gone after its life. In the Hunt, a timed parry lands
## the spark where the first-person camera can see it (it used to sit a metre
## over your head).

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var eye := Camera3D.new()
	add_child(eye)
	eye.current = true
	var spark := ParrySpark.new()
	add_child(spark)
	spark._process(0.016)
	check(spark.live_count() == 0 and spark.light_energy() == 0.0, "nothing when no one has parried")

	var clang := ParrySpark.clang()
	var peak := 0
	for index in range(0, clang.data.size(), 64):
		peak = maxi(peak, absi(clang.data.decode_s16(index)))
	check(peak > 8000 and clang.loop_mode == AudioStreamWAV.LOOP_DISABLED, "the steel rings, once (peak %d)" % peak)

	var at := Vector3(0, 1.4, -2)
	spark.burst(at, Vector3.RIGHT)
	check(spark.live_count() >= ParrySpark.SPARKS and spark.light_energy() > 0.0, "a parry throws sparks and lights the bind (%d)" % spark.live_count())
	check(spark.get_node("Clang").playing, "and you hear it")
	for step in 4:
		spark._process(1.0 / 60.0)
	var drift := 0.0
	for sp in spark._sparks:
		drift += ((sp.at as Vector3) - at).dot(Vector3.RIGHT)
	check(drift / float(spark._sparks.size()) > 0.05, "the sparks go the way the blade was sliding (%.3f m)" % (drift / float(spark._sparks.size())))
	for i in 20:
		spark.burst(at, Vector3.UP)
	check(spark._sparks.size() <= ParrySpark.MAX_SPARKS, "twenty parries in a frame stay a bounded pool (%d)" % spark._sparks.size())
	for step in 70:
		spark._process(1.0 / 60.0)
	check(spark.live_count() == 0 and spark.light_energy() == 0.0, "gone after its life")
	spark.queue_free()
	eye.queue_free()

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for frame in 4:
		await get_tree().physics_frame
	var fx: ParrySpark = hunt.parry_spark
	check(fx != null, "the Hunt carries one parry spark")
	hunt.third_person = false
	hunt.guarding = true
	hunt.guard_side = BladeRead.LEFT
	hunt.guard_raised = 0.05
	var parry: Dictionary = hunt.guard_absorb(20.0, Vector3.INF, BladeRead.LEFT)
	check(bool(parry.parried) and fx.bursts == 1 and hunt.parry_spark_count == 1, "a timed parry in the Hunt bursts it")
	var contact: Vector3 = fx._flashes[0].at
	var camera: Camera3D = hunt.get_viewport().get_camera_3d()
	print("PROBE eye ", camera.global_position, " player ", hunt.player, " contact ", contact)
	check(camera.is_position_in_frustum(contact) and contact.distance_to(camera.global_position) < 1.2, "and the bind is in front of your eyes, on screen")
	hunt.guard_raised = BladeRead.PARRY_WINDOW + 0.1
	hunt.guard_absorb(20.0, Vector3.INF, BladeRead.LEFT)
	check(fx.bursts == 1, "a late guard is only a block: no spark")

	print("PARRY_SPARK_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
