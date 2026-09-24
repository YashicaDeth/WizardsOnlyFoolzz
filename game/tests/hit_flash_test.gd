extends Node

## A landed blow flashes, harder blows throw more sparks, sparks carry on along
## the strike, and all of it is gone within a fraction of a second.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var light := HitFlash.new()
	add_child(light)
	light.burst(Vector3.ZERO, Vector3.FORWARD, 0.2)
	var heavy := HitFlash.new()
	add_child(heavy)
	heavy.burst(Vector3.ZERO, Vector3.FORWARD, 1.2)
	check(heavy.live_count() > light.live_count(), "a harder blow throws more sparks")
	var drift := 0.0
	for i in 4:
		heavy._process(1.0 / 60.0)
	for sp in heavy._sparks:
		drift += (sp.at as Vector3).dot(Vector3.FORWARD)
	check(drift > 0.0, "sparks carry on through the body along the strike")
	for i in 30:
		light._process(1.0 / 60.0)
		heavy._process(1.0 / 60.0)
	check(light.live_count() == 0 and heavy.live_count() == 0, "the flash is gone within a fraction of a second")
	print("HIT_FLASH_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
