extends Node

## B v10 / AF v10 are mostly audit items — claims about the whole project rather
## than features to add. The only honest way to tick one is to make it fail if it
## stops being true, so this proves each claim against the live rig instead of
## somebody reading the code and agreeing with it.

const HUMAN := preload("res://systems/baseline_human.gd")
const PEN := preload("res://systems/penetration.gd")
const BALLISTICS := preload("res://systems/ballistics.gd")

var failures: Array[String] = []

func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)

func _rig(id: String) -> BaselineHuman:
	var r: BaselineHuman = HUMAN.new()
	add_child(r)
	r.build(id, {"gore": true})
	return r

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var rig := _rig("audit")
	await get_tree().process_frame

	# --- B10.3 / AF10.7: a round finds a zone, never a hitbox --------------
	var torso := rig.parts.get("torso") as Node3D
	var head := rig.parts.get("head") as Node3D
	check(rig.zone_nearest(torso.global_position) == "torso", "a point on the chest resolves to the torso")
	check(rig.zone_nearest(head.global_position) == "head", "a point on the head resolves to the head")
	var arm := rig.parts.get("left_arm") as Node3D
	check(rig.zone_nearest(arm.global_position) == "left_arm", "and a point on the left arm resolves to the left arm, not to whichever collider was nearest")
	# Every wound that lands is filed under a zone name.
	rig.hit_at(torso.global_position + Vector3(0, 0.1, 0.14), 20.0, 4.0, "ballistic", Vector3(0, 0, -1))
	for zone_key: String in rig.wound_marks.keys():
		check(HUMAN.ZONES.has(zone_key), "every wound is filed under a real zone (%s)" % zone_key)

	# --- B10.8: every damage type resolves through the same anatomy -------
	# Not "each type has an effect" — that they all go through one path, so a new
	# type cannot quietly bypass organs, bleeding or severing.
	for kind: String in ["ballistic", "cut", "shear", "blunt", "puncture", "radiation", "caustic"]:
		var body := _rig("kind_%s" % kind)
		await get_tree().process_frame
		var before: float = body.zone_health("torso")
		var result: Dictionary = body.hit("torso", 24.0, 4.0, kind)
		# Every successful hit comes back through `apply_hit`, which stamps the
		# body's own state onto the result before emitting `wounded`. Those two
		# keys are the shared contract — a damage type that bypassed the anatomy
		# could not produce them.
		check(result.has("blood_remaining") and result.has("pain"), "%s comes back through apply_hit's own contract" % kind)
		check(body.zone_health("torso") <= before, "%s costs the zone health through the anatomy" % kind)

	# --- B10.15: the player's body is the same rig, exceptional only by
	# being undying ---------------------------------------------------------
	var npc := _rig("ordinary")
	var player := _rig("exceptional")
	await get_tree().process_frame
	player.anatomy.undying = true
	check(npc.anatomy.get_script() == player.anatomy.get_script(), "the player's anatomy is the same class as everyone's")
	check(npc.get_script() == player.get_script(), "and the player's rig is the same class as everyone's")
	npc.anatomy.finish("shot")
	player.anatomy.finish("shot")
	check(npc.anatomy.dead, "the ordinary body dies")
	check(not player.anatomy.dead and player.anatomy.failed, "the player's does not — and that is the whole of the difference")

	# --- B10.4: a body carries its whole history visibly and permanently ---
	var carrier := _rig("carrier")
	await get_tree().process_frame
	var chest := carrier.parts.get("torso") as Node3D
	var placed: Array[Vector3] = []
	for shot in 4:
		var at := chest.global_position + Vector3(-0.05 + 0.033 * float(shot), 0.10 - 0.04 * float(shot), 0.14)
		placed.append(at)
		carrier.hit_at(at, 12.0, 2.0, "ballistic", Vector3(0, 0, -1))
	var zone := carrier.zone_nearest(placed[0])
	var marks: Array = carrier.wound_marks.get(zone, [])
	check(marks.size() >= 4, "four hits leave four wounds (%d)" % marks.size())
	var holder := (carrier.parts.get(zone) as Node3D).get_node_or_null("Wounds")
	check(holder != null and holder.get_child_count() >= 4, "and all four are on the body as geometry")
	# Permanent: nothing clears them over time.
	for _f in 90:
		await get_tree().process_frame
	check((carrier.wound_marks.get(zone, []) as Array).size() >= 4, "and they are still there ninety frames later — permanent, not a decal that ages out")

	# --- AF10.6: calibre decides what happens to a body -------------------
	var light: Dictionary = PEN.resolve("torso", 0.3, false, float((BALLISTICS.CALIBRES["buck"] as Dictionary)["penetration"]), 0.0, 0.66)
	var heavy: Dictionary = PEN.resolve("torso", 0.3, false, float((BALLISTICS.CALIBRES["rifle"] as Dictionary)["penetration"]), 0.0, 0.66)
	check(float(heavy["fraction"]) > float(light["fraction"]), "a heavier calibre reaches further into the same chest")
	check(bool(heavy["through"]) and not bool(light["through"]), "and only one of them comes out the other side")


	# --- B10.7: what is installed in a limb is visible in that limb --------
	var fitted := _rig("fitted")
	await get_tree().process_frame
	var before_children := (fitted.parts.get("left_arm") as Node3D).get_child_count()
	fitted.anatomy.install_part("left_arm", {"id": "ashline industrial arm"})
	fitted.call("_refresh_zone", "left_arm")
	await get_tree().process_frame
	var after_children := (fitted.parts.get("left_arm") as Node3D).get_child_count()
	check(fitted.anatomy.installed_parts.has("left_arm"), "sanity: the limb has hardware in it")
	check(after_children > before_children, "installing hardware in a limb puts something in that limb you can see (%d -> %d)" % [before_children, after_children])

	# --- B10.5: blood, viscera and bone answer light differently -----------
	# Three materials, not one red. Checked as a real difference in how each
	# responds to light rather than as three hex codes that happen to differ.
	var lit := _rig("materials")
	await get_tree().process_frame
	var bone_mat := WorldLook.surface(HUMAN.BONE, "bone", 1) as StandardMaterial3D
	var organ_mat := WorldLook.surface(HUMAN.ORGAN, "flesh", 1) as StandardMaterial3D
	check(bone_mat != null and organ_mat != null, "sanity: bone and viscera both resolve a material")
	check(not is_equal_approx(bone_mat.roughness, organ_mat.roughness), "bone and viscera catch light differently (%.2f vs %.2f)" % [bone_mat.roughness, organ_mat.roughness])
	var splat_mesh: Mesh = lit.call("_splat_mesh", 0.1)
	var splat_mat := splat_mesh.surface_get_material(0) as StandardMaterial3D
	check(splat_mat != null, "sanity: blood resolves a material")
	check(splat_mat.shading_mode != bone_mat.shading_mode, "and blood answers light differently again — it is shaded unshaded on purpose, so it reads as a mark rather than as a third wet object")


	# --- B10.6: any body opens up in the same detail as any other ----------
	# The claim is that there is no "detailed body" and "cheap body" — one rig,
	# so an NPC nobody will ever inspect has the same organs as the one the
	# player is about to dig through.
	var a := _rig("body_a")
	var b := _rig("body_b")
	await get_tree().process_frame
	check(a.anatomy.organs.keys().size() == b.anatomy.organs.keys().size(), "two different bodies carry the same organ count")
	check(a.anatomy.zones.keys() == b.anatomy.zones.keys(), "and the same zones")
	check(a.parts.keys() == b.parts.keys(), "and the same parts to open")
	# Depth is a ratchet on any of them, not a property of special bodies.
	b.call("mark_opened", "torso", GoreChunks.Layer.ORGAN)
	check(b.exposed_layer("torso") >= GoreChunks.Layer.ORGAN, "any body can be opened to the organ layer, not just an authored one")
	check(a.exposed_layer("torso") < GoreChunks.Layer.ORGAN, "and doing it to one does not do it to the other")

	# --- B10.11: gore rots on a real clock, and is eaten ------------------
	check(GoreChunks.ROT_SECONDS > 0.0, "gore has a real rot clock (%.0f s)" % GoreChunks.ROT_SECONDS)
	# `has_method` cannot be called on a class name, only an instance, so the
	# method list comes off the script resource — which also covers statics.
	check(_declares("res://systems/gore_chunks.gd", "rot_ratio"), "and how rotten a piece is can be asked at any time")
	check(ResourceLoader.exists("res://systems/carrion_scavenger.gd"), "and something exists that eats it")
	check(_declares("res://systems/carrion_scavenger.gd", "can_eat"), "which decides for itself what counts as food")

	# --- B10.13: a corpse is a place other systems can read from ----------
	# Not "the mesh stays there" — that a *later* system, with no reference to
	# the rig, can ask what happened to that body and get an answer.
	var fallen := _rig("the_deceased")
	await get_tree().process_frame
	var chest2 := fallen.parts.get("torso") as Node3D
	fallen.hit_at(chest2.global_position + Vector3(0, 0.08, 0.14), 30.0, 6.0, "ballistic", Vector3(0, 0, -1))
	fallen.severed.append("left_arm")
	WorldHistory.update_subject("the_deceased", {"anatomy_state": fallen.snapshot()}, "anatomy_changed")
	# Everything about the rig is now gone, the way it would be a day later.
	fallen.queue_free()
	await get_tree().process_frame
	var record: Dictionary = WorldHistory.subject("the_deceased")
	var state: Dictionary = record.get("anatomy_state", {})
	check(not state.is_empty(), "a body that is no longer in the scene still has a record")
	check((state.get("severed", []) as Array).has("left_arm"), "the record remembers which limb came off")
	check(state.has("zones") or state.has("organs"), "and the state of what is left, readable by anything — this is what makes a corpse a place rather than a prop")

	print("BODY_V10_AUDIT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Whether a script declares a method, static or otherwise. `has_method()` needs
## an instance and these are static utility classes with no instances to make.
func _declares(path: String, method_name: String) -> bool:
	var script: Script = load(path)
	if script == null:
		return false
	for entry: Dictionary in script.get_script_method_list():
		if str(entry.get("name", "")) == method_name:
			return true
	return false
