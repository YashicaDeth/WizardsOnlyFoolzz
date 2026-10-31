extends Node

## player-81: the player's look on the rigged base. The player (PlayerLook.mark)
## is built leaner than an unmarked body on the same skeleton, wears the chosen
## garment painted on the flesh and follows a change of look; everyone else
## wears none. Fingers relax on the player only, the hardware readout bands do
## not float, the first-person hands lose the jester cuff and the grain, and a
## cut and a death still work on the new build.

var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _ready() -> void:
	WorldHistory.clear_history()
	PlayerLook.set_current(PlayerLook.DEFAULT)
	var player := _body("look_subject", true)
	var other := _body("base_subject", false)
	for _frame in 20:
		await get_tree().process_frame
	check(player.rigged != null and other.rigged != null, "both bodies are rigged")
	if player.rigged == null or other.rigged == null:
		_finish()
		return
	check(player.rigged.human == "male" and other.rigged.human == "male", "both wear the human skin")
	# Leaner: the arm and the torso are thinner across than the base's.
	var arm_lean: AABB = player.rigged.zone_extents["right_arm"]
	var arm_base: AABB = other.rigged.zone_extents["right_arm"]
	check(arm_lean.size.z < arm_base.size.z * 0.93, "the player's arm is slimmer (%.3f vs %.3f)" % [arm_lean.size.z, arm_base.size.z])
	var torso_lean: AABB = player.rigged.zone_extents["torso"]
	var torso_base: AABB = other.rigged.zone_extents["torso"]
	check(torso_lean.size.z < torso_base.size.z * 0.97, "the player's chest is shallower")
	check(absf(torso_lean.size.y - torso_base.size.y) < 0.02, "the player is as tall as the base")
	# Garment and relief per instance.
	check(_mode(player, "torso") == PlayerLook.LOOKS["patient"].mode, "the player wears the patient smock by default")
	check(_mode(other, "torso") == 0.0, "nobody else wears a garment")
	check(is_equal_approx(float(_param(player, "torso", "muscle")), PlayerLook.MUSCLE), "the player's muscle relief is turned down")
	check(is_equal_approx(float(_param(other, "torso", "muscle")), 1.0), "everyone else keeps theirs")
	PlayerLook.set_current("bodysuit")
	for _frame in 10:
		await get_tree().process_frame
	check(_mode(player, "torso") == PlayerLook.LOOKS["bodysuit"].mode, "a change of look reaches the body")
	check(_mode(player, "left_leg") == PlayerLook.LOOKS["bodysuit"].mode, "every zone takes it")
	PlayerLook.set_current(PlayerLook.DEFAULT)
	check(PlayerLook.cycle() == "bodysuit" and PlayerLook.cycle(-1) == PlayerLook.DEFAULT, "the look cycles")
	# Hands.
	check(player.rigged.hand_relax != null and not player.rigged.hand_relax.bones.is_empty(), "the player's fingers relax")
	check(other.rigged.hand_relax == null, "nobody else's are touched")
	# Hardware readout.
	var arm := player.parts["right_arm"] as Node3D
	var floating := 0
	for child in arm.get_children():
		if str(child.name).contains("_ServoBand_") and (child as Node3D).visible:
			floating += 1
	check(floating == 0, "no servo band floats off a skinned arm")
	# First person.
	var arms := FirstPersonArms.new()
	add_child(arms)
	arms.take("")
	check(arms.held.find_child("HumiliationCuff", true, false) == null, "first-person hands wear the look, not the jester cuff")
	var sleeve := arms.held.find_child("TaperedSleeve", true, false) as MeshInstance3D
	var sleeve_material := sleeve.material_override as BaseMaterial3D if sleeve != null else null
	check(sleeve_material != null and not sleeve_material.uv1_triplanar, "the sleeve carries no world grain")
	arms.queue_free()
	var gloved := FirstPersonArms.new()
	gloved.gloved = true
	add_child(gloved)
	gloved.take("")
	check(gloved.held.find_child("HumiliationCuff", true, false) != null, "gloved arms keep the jester set")
	gloved.queue_free()
	# The cut and the death on the new build.
	var guard := 0
	while not player.severed.has("right_arm") and guard < 20:
		player.hit("right_arm", 60.0, 6.0, "cut", "", Vector3.RIGHT)
		guard += 1
	for _frame in 5:
		await get_tree().process_frame
	check(player.severed.has("right_arm"), "the player's arm still comes off")
	var shown := false
	for instance: MeshInstance3D in player.rigged.zone_meshes["right_arm"]:
		shown = shown or instance.visible
	check(not shown, "the cut arm's skin is gone from the body")
	player.hit("head", 400.0, 6.0, "puncture", "brain", Vector3.LEFT, 1.0, null, null, "heavy")
	for _frame in 120:
		await get_tree().physics_frame
	check(player.anatomy.dead, "the player's body died")
	check(player.rigged.ragdolled, "the player falls as a ragdoll")
	check(player.rigged.max_joint_gap() < 0.08, "every joint holds (worst gap %.3f m)" % player.rigged.max_joint_gap())
	_finish()


func _body(subject: String, marked: bool) -> BaselineHuman:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	add_child(floor_body)
	var rig := BaselineHuman.new()
	rig.position = Vector3(3.0 if marked else -3.0, 0, 0)
	add_child(rig)
	if marked:
		PlayerLook.mark(rig)
	rig.build(subject, {"gore": true, "ragdoll": true, "rigged": true})
	return rig


func _param(rig: BaselineHuman, zone: String, key: String) -> Variant:
	for instance: MeshInstance3D in rig.rigged.zone_meshes[zone]:
		if not instance.has_meta("own_material"):
			return instance.get_instance_shader_parameter(key)
	return null


func _mode(rig: BaselineHuman, zone: String) -> float:
	var value: Variant = _param(rig, zone, "garment_mode")
	return float(value) if value != null else -1.0


func _finish() -> void:
	print("PLAYER_LOOK_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
