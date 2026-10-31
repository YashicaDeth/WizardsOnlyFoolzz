extends Node3D

## Greg, 28 September: pools of light. Every ceiling lamp throws a pool
## straight down, the lamps flicker more with tension, some die for good (at
## different moments, never more than a third), the glass burst starts turning
## red strobes under which the tubes stay on, with one klaxon blast, and the
## four opening rooms are wired to it.

const ROOMS := ["res://vat_chamber.tscn", "res://service_arcade.tscn", "res://support_unit.tscn", "res://doctor_vehicle_bay.tscn"]

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _room(count: int) -> RoomLights:
	var room := Node3D.new()
	add_child(room)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_energy = 1.0
	room.add_child(world)
	var ceiling: Array = []
	for index in count:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 4.0, -3.0 * index)
		lamp.light_energy = 1.0
		room.add_child(lamp)
		ceiling.append(lamp)
	var lights := RoomLights.new().setup("vat", ceiling)
	room.add_child(lights)
	lights.rng.seed = 7
	lights.set_process(false)
	return lights


## The share of lamp-frames spent below full, over `steps` frames of 50 ms.
func _dimmed(lights: RoomLights, tension: float, steps: int) -> float:
	lights.tension = tension
	var dimmed := 0
	for step in steps:
		lights._process(0.05)
		for lamp in lights.lamps:
			if not lamp.dead and (lamp.pool as SpotLight3D).light_energy < float(lamp.energy) * 0.99:
				dimmed += 1
	return float(dimmed) / float(steps * lights.lamps.size())


func _ready() -> void:
	var lights := _room(6)
	var first: Dictionary = lights.lamps[0]
	var pool := first.pool as SpotLight3D
	check(lights.lamps.size() == 6, "every ceiling lamp is taken (%d)" % lights.lamps.size())
	check(pool.global_transform.basis.z.dot(Vector3.UP) > 0.99 and pool.spot_range > 4.0, "each lamp throws a pool straight down to the floor")
	check(is_equal_approx((first.light as OmniLight3D).light_energy, 1.0 * RoomLights.GLOW), "the lamp keeps only a dim glow of its own")
	check((first.light as OmniLight3D).light_color == RoomLights.LAB_LIGHT, "sick green-white lab light")
	var world := lights.get_parent().get_child(0) as WorldEnvironment
	check(is_equal_approx(world.environment.ambient_light_energy, 0.45), "the room's ambient is cut to leave it black (%.2f)" % world.environment.ambient_light_energy)

	var calm := _dimmed(lights, 0.0, 400)
	var panic := _dimmed(lights, 1.0, 400)
	check(calm < 0.02 and panic > 0.1 and panic > calm * 4.0, "the lamps flicker more as tension rises (calm %.3f, panic %.3f)" % [calm, panic])

	var still := _room(6)
	still.tension = 0.0
	for step in 6000:
		still._process(0.05)
	check(still.lamps.all(func(lamp: Dictionary) -> bool: return not lamp.dead), "at no tension no lamp dies")

	var dying := _room(6)
	dying.tension = 1.0
	var died_at: Array[int] = []
	for step in 6000:
		var dead_before := dying.lamps.filter(func(lamp: Dictionary) -> bool: return lamp.dead).size()
		dying._process(0.05)
		if dying.lamps.filter(func(lamp: Dictionary) -> bool: return lamp.dead).size() > dead_before:
			died_at.append(step)
	check(died_at.size() == 2, "some die for good, never more than a third (%d of 6)" % died_at.size())
	check(died_at.size() == 2 and died_at[0] != died_at[1], "each dies at its own moment (%s)" % str(died_at))
	var dead: Array = dying.lamps.filter(func(lamp: Dictionary) -> bool: return lamp.dead)
	check(dead.all(func(lamp: Dictionary) -> bool: return not (lamp.pool as SpotLight3D).visible and (lamp.light as OmniLight3D).light_energy == 0.0), "a dead lamp stays dark")

	var bursting := _room(6)
	bursting.tension = 0.95
	bursting.burst([Vector3(-7.0, 3.3, 0.0), Vector3(7.0, 3.3, -6.0)])
	var horn := bursting.get_node_or_null("Klaxon") as AudioStreamPlayer
	check(bursting.alarm and bursting.strobes.size() == 2, "the glass burst starts a strobe at each point")
	check(horn != null and horn.stream == preload("res://systems/ambient_audio.gd").stream("klaxon"), "and sounds the klaxon")
	var beams := bursting.strobes[0].find_children("*", "SpotLight3D", false, false)
	check(beams.size() == 2 and (beams[0] as SpotLight3D).light_color == RoomLights.STROBE_RED, "each strobe turns two red beams")
	bursting.burst([Vector3.ZERO])
	check(bursting.klaxons == 1 and bursting.strobes.size() == 2, "one klaxon blast, not one per blow")
	var turned_from := bursting.strobes[0].rotation.y
	bursting._process(0.05)
	check(absf(angle_difference(turned_from, bursting.strobes[0].rotation.y)) > 0.2, "the strobes keep turning, silent")
	var lowest := 1.0
	for step in 200:
		bursting._process(0.05)
		for lamp in bursting.lamps:
			if not lamp.dying and not lamp.dead:
				lowest = minf(lowest, (lamp.pool as SpotLight3D).light_energy / float(lamp.energy))
	check(lowest >= 0.34 and lowest < 1.0, "under the strobes the tubes stutter but stay on (lowest %.2f)" % lowest)

	for path: String in ROOMS:
		WorldHistory.clear_history()
		var room: Node = load(path).instantiate()
		add_child(room)
		await get_tree().process_frame
		await get_tree().process_frame
		var wired := room.get_node_or_null("RoomLights") as RoomLights
		check(wired != null and wired.lamps.size() >= 5, "%s lights its ceiling lamps as pools (%d)" % [path.get_file(), 0 if wired == null else wired.lamps.size()])
		if path.contains("vat_chamber") and wired != null:
			room.call("_breach")
			check(wired.alarm and wired.strobes.size() == 4 and wired.klaxons == 1, "the vat's glass burst sets off the strobes and the klaxon")
		room.queue_free()
		await get_tree().process_frame

	print("ROOM_LIGHTS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
