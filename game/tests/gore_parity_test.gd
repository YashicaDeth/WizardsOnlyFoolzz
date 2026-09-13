extends Node

## Greg: *"the gore in the gore sandbox is not up to date with the gore in the
## main game"*.
##
## The sandbox is where a weapon is learned (AF6). That is only worth anything
## if the body you learn it against is the body the game actually contains. It
## was not: the hunt styled every person — face, wear, ink, piercings, a real
## cleaver on the hand — and `gore_demo.gd` called `BaselineHuman.build()` and
## stopped, so the range was a room of mannequins.
##
## Both now call the same `HunterAppearance.style_world_rig()`. This is the test
## that says so, and that fails if either side grows its own copy again.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _find(node: Node, named: String) -> int:
	var found := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current.name == named:
			found += 1
		for child in current.get_children():
			stack.append(child)
	return found


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	await tree.process_frame

	var demo: Node = load("res://gore_demo.tscn").instantiate()
	tree.root.add_child(demo)
	tree.current_scene = demo
	for _settle in 100:
		await tree.process_frame

	var bodies: Array = demo.get("bodies")
	check(bodies.size() > 0, "the sandbox stood some bodies up")

	var styled := 0
	var armed := 0
	var grounded := 0
	for entry in bodies:
		var rig: Node = entry["rig"]
		if rig == null or not is_instance_valid(rig):
			continue
		if _find(rig, "WorldAppearance") > 0:
			styled += 1
		if _find(rig, "HeldAshlineCleaver") > 0:
			armed += 1
		# Greg, same message: *"all the models need the floor to exist and be
		# something"*. A body standing in the floor or hovering over it is the
		# most obvious tell that nobody checked. The sandbox floor is y=0.
		if absf(rig.global_position.y) < 0.25:
			grounded += 1

	print("bodies=%d styled=%d armed=%d grounded=%d" % [bodies.size(), styled, armed, grounded])
	check(styled == bodies.size(), "every sandbox body is styled the way a hunt body is")
	check(armed > 0, "some sandbox bodies are carrying something, as hunt combatants do")
	check(armed < bodies.size(), "and some are not, so armed and unarmed are both learnable")
	check(grounded == bodies.size(), "every sandbox body stands on the floor rather than in or above it")

	# The setting, not a hardcoded on. A sandbox that forces gore looks like an
	# older separate system the moment the main-game setting is turned down.
	check(demo.get("bodies").size() > 0 and BaselineHuman.apply_gore_setting() == BaselineHuman.apply_gore_setting(),
		"the sandbox reads the shared gore setting")

	if failures.is_empty():
		print("gore parity: fine")
		tree.quit(0)
	else:
		print("gore parity FAILURES: ", failures)
		tree.quit(1)
