extends Node

## Things break outside the derby (DESIGN/GOAL_LOOP_2.md 0.2): every prop kind
## stands on the floor and breaks into its own pieces, all kinds share one
## capped pool, and the breach tool breaks them where the Service Arcade, the
## Lower Works and the drains put them, through each scene's own attack button.

const PROP := preload("res://systems/breakable_prop.gd")
const WORLD_BREAK := preload("res://systems/world_break.gd")
const WORLD_DEBRIS := preload("res://systems/world_debris.gd")
const RAM := FacilityGuardPost.RAM_DAMAGE

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
	WORLD_DEBRIS.clear_pool(PROP.FRAGMENT_POOL)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(40, 0.2, 40)
	ground.add_child(shape)
	ground.position.y = -0.1
	add_child(ground)

	# --- every kind: stands, breaks, sheds its own pieces --------------------
	var props: Array[BreakableProp] = []
	var x := -6.0
	for kind: String in PROP.KINDS:
		var prop := PROP.place(self, kind, "test_%s" % kind, Vector3(x, 0, 0))
		x += 2.0
		props.append(prop)
		var size: Vector3 = (PROP.KINDS[kind] as Dictionary).size
		check(is_equal_approx(prop.position.y, size.y * 0.5) and prop.get_node_or_null("SolidCollision") != null,
			"a %s stands on the floor with one collider" % kind)
	await get_tree().physics_frame
	var meshes := {}
	for prop in props:
		for blow in 3:
			if not prop.broken:
				WORLD_BREAK.hit(prop, RAM, "melee", prop.global_position, Vector3.FORWARD, "breach_tool", "melee")
		var pieces := int((PROP.KINDS[prop.kind] as Dictionary).pieces)
		check(prop.broken and prop.fragment_count() == pieces, "a %s breaks into its %d pieces (%d)" % [prop.kind, pieces, prop.fragment_count()])
		var found: Array = []
		for child in prop.get_children():
			if child is RigidBody3D:
				found.append((child.get_child(0) as MeshInstance3D).mesh.get_class())
		meshes[prop.kind] = found
	check("TorusMesh" in meshes.barrel, "a barrel sheds a hoop with its staves")
	check("SphereMesh" in meshes.jar and "PrismMesh" in meshes.jar, "a jar breaks into glass and lets out what was in it")
	check("PrismMesh" in meshes.monitor and "BoxMesh" in meshes.monitor, "a monitor breaks into screen glass and casing")
	check(not "PrismMesh" in meshes.crate, "a crate breaks into planks, not glass")

	# --- one shared cap -----------------------------------------------------
	var budget := PROP.fragment_budget()
	check(WORLD_DEBRIS.pool_count(PROP.FRAGMENT_POOL) == budget, "every kind shares one fragment pool, held at its cap (%d/%d)" % [WORLD_DEBRIS.pool_count(PROP.FRAGMENT_POOL), budget])
	check(props.back().fragment_count() == int((PROP.KINDS[props.back().kind] as Dictionary).pieces) and props[0].fragment_count() < int((PROP.KINDS[props[0].kind] as Dictionary).pieces),
		"a full pool gives up its oldest pieces, so the latest break still shows all of its own")

	# --- what it takes ------------------------------------------------------
	var crate := PROP.place(self, "crate", "round_crate", Vector3(-4, 0, 4))
	var locker := PROP.place(self, "locker", "blow_locker", Vector3(4, 0, 4))
	await get_tree().physics_frame
	WORLD_BREAK.hit(crate, 24.0, "round", crate.global_position, Vector3.FORWARD, "sidearm", "firearm")
	check(crate.broken, "one pistol round breaks a crate")
	WORLD_BREAK.hit(locker, RAM, "melee", locker.global_position, Vector3.FORWARD, "breach_tool", "melee")
	check(not locker.broken, "a locker takes more than one blow of the breach tool")
	WORLD_BREAK.hit(locker, RAM, "melee", locker.global_position, Vector3.FORWARD, "breach_tool", "melee")
	check(locker.broken, "and gives on the second")
	var filed: Dictionary = _last_strike()
	check(str(filed.get("id", "")) == "blow_locker" and str(filed.get("kind", "")) == "locker" and bool(filed.get("broke", false)),
		"the world files which locker broke, not only that a locker did (%s)" % [filed])
	for node in get_children():
		if node is BreakableProp or node == ground:
			node.queue_free()
	WORLD_DEBRIS.clear_pool(PROP.FRAGMENT_POOL)
	await get_tree().process_frame

	# --- where the player is ------------------------------------------------
	WorldHistory.clear_history()
	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	await get_tree().process_frame
	arcade.player.global_position = arcade.WEAPON_AT
	arcade._interact()
	check(arcade.weapon_taken and VatRebirth.carries("BREACH TOOL"), "the breach tool is picked up in the arcade")
	await _swing_in(arcade, "the Service Arcade")
	var city = load("res://buried_city.tscn").instantiate()
	add_child(city)
	await get_tree().process_frame
	await _swing_in(city, "the Lower Works")
	var drains = load("res://old_drains.tscn").instantiate()
	add_child(drains)
	await get_tree().process_frame
	await _swing_in(drains, "the drains")

	print("BREAKABLE_PROPS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Stands the scene's player a step from its first prop, looks at it, and
## presses the attack button the scene itself listens to.
func _swing_in(scene: Node3D, where: String) -> void:
	scene.set_physics_process(false)
	var placed: Array[BreakableProp] = []
	for child in scene.get_children():
		if child is BreakableProp:
			placed.append(child)
	check(placed.size() == scene.PROPS.size() and placed.size() >= 5, "%s has things to break (%d)" % [where, placed.size()])
	var target: BreakableProp = placed[0]
	var at := target.global_position
	var toward_middle := Vector3(-signf(at.x), 0, 0)
	scene.player.global_position = Vector3(at.x, 1.0, at.z) + toward_middle * 1.4
	await get_tree().physics_frame
	scene.camera.look_at(at)
	# The Lower Works and the drains only swing once the mouse is captured,
	# which a headless run never reports, so their attack is called past that
	# one gate. The arcade has no such gate and takes the click itself.
	if scene.has_method("_swing_breach_tool"):
		scene._swing_breach_tool()
	else:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		scene._unhandled_input(click)
	check(target.broken and target.fragment_count() > 0, "in %s, the breach tool breaks the %s in front of it" % [where, target.kind])
	check(str(_last_strike().get("id", "")) == str(target.name), "and the world files that it was %s" % target.name)
	scene.queue_free()
	await get_tree().process_frame


func _last_strike() -> Dictionary:
	for index in range(WorldHistory.events.size() - 1, -1, -1):
		var event: Dictionary = WorldHistory.events[index]
		if str(event.get("type", "")) == "world_object_struck":
			return event.get("details", {})
	return {}
