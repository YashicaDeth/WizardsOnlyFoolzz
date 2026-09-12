extends Node

## G5 verification. The mixer is the part that was actually broken, and a broken
## mixer is invisible in a screenshot — it has to be asserted.

const GoreChunks := preload("res://systems/gore_chunks.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("G5.1 - the mixer actually reaches everything")
	# The chains systems build for themselves, created the way they create them.
	for chain_name in ["DerbyQuarry", "FieldRadio", "Gore", "Bodies"]:
		AudioBus.chain(chain_name)
	AudioBus.ensure()

	var graph: Dictionary = AudioBus.graph()
	_check(graph.has("SFX") and str(graph["SFX"]) == "Master", "SFX reaches Master")
	_check(graph.has("Ambience") and str(graph["Ambience"]) == "Master", "Ambience reaches Master")
	_check(graph.has("Music") and str(graph["Music"]) == "Master", "Music reaches Master")
	for chain_name in ["DerbyQuarry", "FieldRadio", "Gore", "Bodies"]:
		_check(str(graph.get(chain_name, "")) == "SFX", "%s feeds SFX, not Master" % chain_name)
	_check(AudioBus.fully_routed(), "nothing reaches Master around the player's mixer")

	# The repair case: a system points its own chain at Master, as they all did.
	AudioServer.set_bus_send(AudioServer.get_bus_index("DerbyQuarry"), "Master")
	_check(not AudioBus.fully_routed(), "a chain sent straight to Master is detected")
	AudioBus.ensure()
	_check(AudioBus.fully_routed(), "and repaired by ensure()")

	# Turning SFX down has to actually attenuate the derby.
	var sfx := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx, linear_to_db(0.0001))
	AudioServer.set_bus_mute(sfx, true)
	_check(AudioServer.is_bus_mute(sfx), "SFX can be muted")
	_check(str(AudioServer.get_bus_send(AudioServer.get_bus_index("DerbyQuarry"))) == "SFX", "and the derby is downstream of it")
	AudioServer.set_bus_mute(sfx, false)

	# A player asking for a bus that does not exist must not land on Master.
	var orphan := AudioStreamPlayer.new()
	add_child(orphan)
	AudioBus.route(orphan, "NoSuchChain")
	_check(orphan.bus == "SFX", "a player asking for a missing chain falls back to SFX, not Master")
	AudioBus.route(orphan, "Ambience")
	_check(orphan.bus == "Ambience", "and an explicit visible bus is honoured")

	print("")
	print("G5.4 - every layer is a different event")
	var shapes: Dictionary = {}
	for layer in [GoreChunks.Layer.SKIN, GoreChunks.Layer.MUSCLE, GoreChunks.Layer.BONE, GoreChunks.Layer.ORGAN, GoreChunks.Layer.CYBERNETIC]:
		var profile: Dictionary = GoreChunks.impact_profile(layer)
		# Sampled with a fixed noise value so the comparison is about the
		# synthesis and not about the random seed.
		var early := absf(GoreChunks.impact_sample(profile, 0.001, 0.5))
		var late := absf(GoreChunks.impact_sample(profile, 0.09, 0.5))
		shapes[layer] = {"character": str(profile.get("character", "")), "early": early, "late": late}

	_check(str(shapes[GoreChunks.Layer.BONE]["character"]) == "crack", "bone cracks")
	_check(str(shapes[GoreChunks.Layer.ORGAN]["character"]) == "burst", "an organ bursts")
	_check(str(shapes[GoreChunks.Layer.CYBERNETIC]["character"]) == "fault", "a cybernetic faults")
	# Bone rings on after the hit; an organ does not.
	var bone_tail: float = float(shapes[GoreChunks.Layer.BONE]["late"]) / maxf(float(shapes[GoreChunks.Layer.BONE]["early"]), 0.0001)
	var organ_tail: float = float(shapes[GoreChunks.Layer.ORGAN]["late"]) / maxf(float(shapes[GoreChunks.Layer.ORGAN]["early"]), 0.0001)
	_check(bone_tail > organ_tail, "bone rings on after the hit and an organ does not (%.3f vs %.3f)" % [bone_tail, organ_tail])

	# An organ's pitch falls as it empties; nothing else does that.
	var organ_profile: Dictionary = GoreChunks.impact_profile(GoreChunks.Layer.ORGAN)
	var zero_crossings := 0
	var previous := 0.0
	for step in 900:
		var value := GoreChunks.impact_sample(organ_profile, float(step) / 22050.0, 0.0)
		if (value < 0.0) != (previous < 0.0):
			zero_crossings += 1
		previous = value
	var late_crossings := 0
	previous = 0.0
	for step in range(1800, 2700):
		var value := GoreChunks.impact_sample(organ_profile, float(step) / 22050.0, 0.0)
		if (value < 0.0) != (previous < 0.0):
			late_crossings += 1
		previous = value
	_check(late_crossings < zero_crossings, "the organ's pitch falls as it empties (%d -> %d crossings over equal windows)" % [zero_crossings, late_crossings])

	# No two layers sound the same.
	var distinct: Dictionary = {}
	for layer in shapes:
		distinct["%s:%.4f" % [shapes[layer]["character"], shapes[layer]["early"]]] = true
	_check(distinct.size() == shapes.size(), "no two layers produce the same impact (%d of %d distinct)" % [distinct.size(), shapes.size()])

	# Nothing clips.
	var loudest := 0.0
	for layer in shapes:
		var profile: Dictionary = GoreChunks.impact_profile(layer)
		for step in 900:
			loudest = maxf(loudest, absf(GoreChunks.impact_sample(profile, float(step) / 22050.0, 1.0)))
	_check(loudest <= 1.0, "no layer clips (peak %.3f)" % loudest)

	print("")
	if failures.is_empty():
		print("G5 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
