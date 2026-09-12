extends Node

const CarrionScavenger := preload("res://systems/carrion_scavenger.gd")

## B4. The claim is not "blood comes out" — it is that what comes out is a set
## of identified pieces that know which layer, which zone and which person they
## came from, because B5 (robbing cybernetics), camera rituals and the organ
## economy are all built on being able to ask a piece what it is.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func layers_of(chunks: Array) -> Array:
	var out: Array = []
	for chunk in chunks:
		var info := GoreChunks.identify(chunk)
		if not info.is_empty() and not out.has(int(info.layer)):
			out.append(int(info.layer))
	out.sort()
	return out


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	WorldHistory.clear_history()
	WorldHistory.register_subject("settings", {"gore": "FULL"})
	WorldHistory.register_subject("inventory", {"items": [], "rust_scrip": 0})
	BaselineHuman.apply_gore_setting()
	GoreChunks.clear()

	# --- depth is a function of the blow AND of the state of the zone ---------
	var shallow := GoreChunks.depth_for(18.0, "cut", 1.0)
	var deep := GoreChunks.depth_for(18.0, "cut", 0.15)
	check(shallow < deep, "the same cut goes deeper into an arm already opened (%d -> %d)" % [shallow, deep])
	check(shallow >= GoreChunks.Layer.SKIN, "even a light cut breaks skin")
	check(GoreChunks.depth_for(40.0, "blunt", 1.0) >= GoreChunks.Layer.BONE, "heavy blunt trauma reaches bone without opening the body first")
	check(GoreChunks.depth_for(6.0, "blunt", 1.0) <= GoreChunks.Layer.FAT, "a light knock does not")
	check(GoreChunks.depth_for(300.0, "ballistic", 0.0) == GoreChunks.Layer.CYBERNETIC, "depth is clamped at the deepest layer")

	# --- a real body sheds real pieces ---------------------------------------
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("chunk_probe", {"cybernetics": {"torso": {"name": "ceramic sternum"}}})
	await get_tree().physics_frame

	rig.hit("torso", 30.0, 10.0, "cut", "heart")
	await get_tree().physics_frame
	var thrown := GoreChunks.from_subject("chunk_probe")
	check(thrown.size() > 0, "a cut throws pieces (%d)" % thrown.size())
	var layers := layers_of(thrown)
	check(layers.has(GoreChunks.Layer.SKIN), "including the skin it went through")
	check(layers.has(GoreChunks.Layer.MUSCLE), "and the muscle under it")

	# --- every piece is identified -------------------------------------------
	var identified := 0
	var organ_named := 0
	for chunk in thrown:
		var info := GoreChunks.identify(chunk)
		if str(info.get("subject_id", "")) == "chunk_probe" and str(info.get("zone", "")) == "torso":
			identified += 1
		if int(info.get("layer", -1)) == GoreChunks.Layer.ORGAN and str(info.get("organ_id", "")) == "heart":
			organ_named += 1
	check(identified == thrown.size(), "every piece knows who it came off and from where (%d of %d)" % [identified, thrown.size()])
	if layers.has(GoreChunks.Layer.ORGAN):
		check(organ_named > 0, "an organ piece names the organ, not just the layer")

	# --- the two identified layers never invent themselves -------------------
	var bare := BaselineHuman.new()
	add_child(bare)
	bare.build("bare_probe", {})
	await get_tree().physics_frame
	bare.hit("left_arm", 300.0, 40.0, "ballistic")
	await get_tree().physics_frame
	var bare_layers := layers_of(GoreChunks.from_subject("bare_probe"))
	check(not bare_layers.has(GoreChunks.Layer.CYBERNETIC), "a body with no implant sheds no hardware, however deep the hit")
	check(not bare_layers.has(GoreChunks.Layer.ORGAN), "and no organ where the limb has none")
	check(bare_layers.has(GoreChunks.Layer.BONE), "but it does reach bone")
	var whole_limb: Node3D
	for piece in GoreChunks.from_subject("bare_probe"):
		if bool(GoreChunks.identify(piece).get("whole_limb", false)):
			whole_limb = piece
			break
	check(whole_limb != null, "a severed body zone enters the same identified chunk registry")
	var limb_info := GoreChunks.take(whole_limb)
	var carry := Carry.new()
	var carried_limb := carry.take_chunk(limb_info)
	check(str(carried_limb.get("kind", "")) == "limb" and str(carried_limb.get("from", "")) == "bare_probe", "the whole limb enters CARRY without losing its owner or zone")
	var condition_before := float(carried_limb.get("condition", 0.0))
	check(carry.damage_item(0, 0.2) < condition_before, "using a carried limb as a weapon degrades its condition")
	var quoted := carry.sale_value(carry.items[0])
	var sold := carry.sell(0)
	check(quoted > 0 and int(sold.get("price", 0)) == quoted, "a whole limb receives a real condition-and-freshness sale price")
	check(int(WorldHistory.subject("inventory").get("rust_scrip", 0)) == quoted, "selling the limb pays into the persistent rust-scrip wallet")

	# --- the body remembers how far it was opened ----------------------------
	check(rig.exposed_layer("torso") >= GoreChunks.Layer.MUSCLE, "the zone records its deepest breach (%d)" % rig.exposed_layer("torso"))
	var before_depth: int = rig.exposed_layer("torso")
	rig.hit("torso", 4.0, 2.0, "blunt")
	check(rig.exposed_layer("torso") >= before_depth, "and a lighter later blow never closes it back up")

	# --- B4.5: the layer itself shows on the body, not just in the chunks it shed
	# left_arm carries no implant on this rig, unlike torso, so the exposure
	# mark reflects flesh being opened rather than being suppressed by hardware.
	rig.hit("left_arm", 30.0, 10.0, "cut")
	var arm_part: Node3D = rig.parts.left_arm
	check(arm_part.get_node_or_null("LayerExposure") != null, "an opened zone carries a visible layer-exposure mark")
	rig.install_prosthetic("left_arm", {"name": "ashline scrap arm"})
	check(arm_part.get_node_or_null("LayerExposure") == null, "a prosthetic zone has no flesh layer to expose")

	# --- B4.7: chunks are generated geometry, not engine primitives ----------
	var mesh_rig := BaselineHuman.new()
	add_child(mesh_rig)
	mesh_rig.build("mesh_probe", {})
	await get_tree().physics_frame
	mesh_rig.hit("torso", 30.0, 10.0, "cut", "heart")
	await get_tree().physics_frame
	var authored := 0
	var checked := 0
	for chunk in GoreChunks.from_subject("mesh_probe"):
		for child in chunk.get_children():
			if child is MeshInstance3D:
				checked += 1
				if (child as MeshInstance3D).mesh is ArrayMesh:
					authored += 1
	check(checked > 0 and authored == checked, "every shed chunk carries authored geometry, not a primitive mesh (%d/%d)" % [authored, checked])

	# --- B4.6: a chunk marks the ground it lands or rolls on -----------------
	var splats_before: int = BaselineHuman.splats.size()
	BaselineHuman.mark_ground_for_chunk(mesh_rig.get_world_3d(), mesh_rig.get_tree().current_scene, mesh_rig.global_position + Vector3.UP * 0.4, Vector3.DOWN, 0.3)
	check(BaselineHuman.splats.size() == splats_before + 1, "a chunk landing leaves a mark on the ground it hit")

	# --- B4.8: each layer has its own real, distinct impact voice ------------
	var skin_voice := GoreChunks.impact_profile(GoreChunks.Layer.SKIN)
	var bone_voice := GoreChunks.impact_profile(GoreChunks.Layer.BONE)
	var hardware_voice := GoreChunks.impact_profile(GoreChunks.Layer.CYBERNETIC)
	check(float(bone_voice.freq) > float(skin_voice.freq), "bone reads higher and sharper than skin")
	check(float(hardware_voice.noise) < float(skin_voice.noise), "hardware rings cleaner than wet tissue")
	GoreChunks.play_impact(mesh_rig, mesh_rig.global_position, GoreChunks.Layer.BONE)

	# --- B4.9: rot is a real clock and a queryable gameplay signal -----------
	var rot_target: Node = GoreChunks.from_subject("mesh_probe")[0]
	check(GoreChunks.rot_ratio(rot_target) < 0.01, "a fresh chunk has not rotted")
	var fresh_info: Dictionary = GoreChunks.identify(rot_target)
	fresh_info["spawn_msec"] = Time.get_ticks_msec() - int(GoreChunks.ROT_SECONDS * 1000.0)
	rot_target.set_meta("chunk", fresh_info)
	check(GoreChunks.rot_ratio(rot_target) >= 1.0, "a chunk left long enough is fully rotted")
	var scent := GoreChunks.scent_sources()
	check(scent.any(func(source): return (source.position as Vector3).distance_to((rot_target as Node3D).global_position) < 0.01), "a rotten chunk becomes a queryable scent source")
	# --- B4.10: a creature answers the scent, but does not erase all evidence --
	var scavenger := CarrionScavenger.new()
	add_child(scavenger)
	scavenger.global_position = (rot_target as Node3D).global_position + Vector3(0.1, 0.0, 0.0)
	scavenger._process(1.0)
	check(not GoreChunks.live.has(rot_target), "a carrion scavenger follows rot and consumes the flesh")
	check(not CarrionScavenger.can_eat(GoreChunks.from_subject("bare_probe").filter(func(piece): return int(GoreChunks.identify(piece).get("layer", -1)) == GoreChunks.Layer.BONE)[0]), "scavengers leave bone behind for the world to read")

	# --- picking a piece up --------------------------------------------------
	var target: Node = GoreChunks.from_subject("chunk_probe")[0]
	var taken := GoreChunks.take(target)
	check(not taken.is_empty(), "a piece can be picked up")
	check(str(taken.get("subject_id", "")) == "chunk_probe", "and it carries its identity with it")
	check(GoreChunks.take(target).is_empty(), "the same piece cannot be taken twice")

	# --- the cap is a frame-rate contract ------------------------------------
	for round_index in 60:
		rig.hit("torso", 60.0, 10.0, "ballistic", "liver")
	await get_tree().physics_frame
	check(GoreChunks.live.size() <= GoreChunks.MAX_CHUNKS, "live chunks are capped (%d)" % GoreChunks.live.size())

	# --- the gore setting still governs everything ---------------------------
	GoreChunks.clear()
	WorldHistory.update_subject("settings", {"gore": "OFF"})
	BaselineHuman.apply_gore_setting()
	var quiet := BaselineHuman.new()
	add_child(quiet)
	quiet.build("quiet_probe", {})
	await get_tree().physics_frame
	quiet.hit("torso", 80.0, 20.0, "cut", "gut")
	await get_tree().physics_frame
	check(GoreChunks.from_subject("quiet_probe").is_empty(), "OFF sheds nothing at all")
	WorldHistory.update_subject("settings", {"gore": "FULL"})
	BaselineHuman.apply_gore_setting()

	print("CHUNK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
