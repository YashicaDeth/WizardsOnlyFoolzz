extends Node

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

	# --- the body remembers how far it was opened ----------------------------
	check(rig.exposed_layer("torso") >= GoreChunks.Layer.MUSCLE, "the zone records its deepest breach (%d)" % rig.exposed_layer("torso"))
	var before_depth: int = rig.exposed_layer("torso")
	rig.hit("torso", 4.0, 2.0, "blunt")
	check(rig.exposed_layer("torso") >= before_depth, "and a lighter later blow never closes it back up")

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
