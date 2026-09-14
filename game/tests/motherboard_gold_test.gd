extends Node

## E2.5 gap. Greg's own comparison named two metals, not one — the board had
## only COPPER. Pads (a trace's own contact points) and the chip's legs are
## the actual contact surfaces on a real board and are plated in gold for
## exactly that reason; the trace runs between them stay copper. This checks
## the built geometry rather than reading the constants back at itself: real
## mesh instances, real material colours, walked out of the board the same
## way anything else would have to find them.

const MOTHERBOARD := preload("res://systems/motherboard.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _count_color(root: Node, color: Color) -> int:
	var total := 0
	for child in root.get_children():
		if child is MeshInstance3D:
			var material := (child as MeshInstance3D).material_override as StandardMaterial3D
			if material != null and material.albedo_color.is_equal_approx(color):
				total += 1
		total += _count_color(child, color)
	return total


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# Built directly rather than added to a live tree — `_ready()` only does
	# procedural mesh construction, nothing that needs a running SceneTree.
	var board := MOTHERBOARD.new()
	board._ready()

	var gold_count := _count_color(board, MOTHERBOARD.GOLD)
	var copper_count := _count_color(board, MOTHERBOARD.COPPER)
	check(gold_count > 0, "the board actually contains gold-coloured geometry (%d instances)" % gold_count)
	check(copper_count > 0, "and copper is still there too — this is a second metal, not a replacement (%d instances)" % copper_count)
	# 6 pins a side, 2 sides: the chip's legs alone account for 12 of these.
	check(gold_count >= 12, "at least the chip's own 12 legs are gold (%d)" % gold_count)
	# The old build coloured every pad the same as its trace; a leftover pad
	# still reading copper would mean the contact point was missed, not just
	# the leg.
	var zero_gold_pads := gold_count - 12
	check(zero_gold_pads > 0, "trace pads beyond the chip's legs are gold too, not just the legs (%d)" % zero_gold_pads)

	board.free()

	if failures.is_empty():
		print("motherboard gold: a second metal, on the actual contact points")
		get_tree().quit(0)
	else:
		print("motherboard gold FAILURES: ", failures)
		get_tree().quit(1)
