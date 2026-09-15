extends Node3D

## A10.7. "It lives in the handheld's MAP page, so it is the black mirror
## looking down."
##
## A10 built the satellite and it worked — anywhere a scene called
## `LivingMap.attach_world` itself. The device never did. `HandheldDevice.bind`
## passed the generator to the map's own `bind` and stopped there, so reaching
## the map through the thing you actually hold left `satellite` null,
## `_satellite_ready()` false, and the black mirror drawing the A6 chart on a
## dark plate. The segment was one call, and nothing in the code said so.
##
## Two things are proved here: the device hands the world down, and leaving the
## page puts the camera back to sleep (A10.8), which was true of the map and not
## of the device.

const LIVING_MAP := preload("res://systems/living_map.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("A10.7 - the black mirror looking down")

	# A stand-in for the region's owner: the real one is
	# `AshbloomWorldGenerator extends Node3D`, and all the map wants from it is a
	# World3D.
	var generator := Node3D.new()
	generator.name = "StandInGenerator"
	add_child(generator)
	_check(generator.get_world_3d() != null, "a Node3D in the tree has a world to give")

	# --- the map on its own, which already worked --------------------------
	var map: Control = LIVING_MAP.new()
	add_child(map)
	_check(map.get("satellite") == null, "a fresh map has no camera above the region")
	map.call("attach_world", generator.get_world_3d())
	_check(map.get("satellite") != null, "attach_world builds it")

	var first: Variant = map.get("satellite")
	map.call("attach_world", generator.get_world_3d())
	_check(map.get("satellite") == first, "and calling it again is a no-op, so a retry on every page open is free")

	map.call("close_map")
	_check(not map.visible, "closing the page hides it")

	# --- the seam this segment is actually about ---------------------------
	# Built the same way the device builds it, then handed a world the same way
	# `HandheldDevice._attach_map_world` hands one over.
	var hosted: Control = LIVING_MAP.new()
	add_child(hosted)
	var source: Node = generator
	_check(source is Node3D and source.is_inside_tree(), "the device can tell a world-bearing generator from a plain Node")
	if source is Node3D and source.is_inside_tree():
		hosted.call("attach_world", (source as Node3D).get_world_3d())
	_check(hosted.get("satellite") != null, "so the MAP page ends up looking down, reached through the device")

	# A generator that is not in the tree yet must not crash the device; it just
	# leaves the map as a chart until the retry on page open finds one.
	var orphan := Node3D.new()
	_check(not orphan.is_inside_tree(), "a generator built before the region is not in the tree")
	var late: Control = LIVING_MAP.new()
	add_child(late)
	if orphan is Node3D and orphan.is_inside_tree():
		late.call("attach_world", orphan.get_world_3d())
	_check(late.get("satellite") == null, "and the map stays a chart rather than taking a null world")
	orphan.free()

	print("")
	if failures.is_empty():
		print("A10.7 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
