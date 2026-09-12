extends Node

## G5 verification. The mixer is the part that was actually broken, and a broken
## mixer is invisible in a screenshot — it has to be asserted.

const GoreChunks := preload("res://systems/gore_chunks.gd")
const DerbyAudio := preload("res://systems/procedural_derby_audio.gd")

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
	print("G5.2 - engine layered by load, not one pitched sine")
	var engine := DerbyAudio.new()
	add_child(engine)
	engine.warm_up = 1.0 # skip the fade-up so volumes read the target immediately
	engine.update_engine(0.0, 0.0)
	var idle_low: float = engine.engine_low.volume_db
	var idle_high: float = engine.engine_high.volume_db
	var idle_strain: float = engine.engine_strain.volume_db
	var idle_pitch_low: float = engine.engine_low.pitch_scale
	engine.update_engine(24.0, 1.0)
	var floor_low: float = engine.engine_low.volume_db
	var floor_high: float = engine.engine_high.volume_db
	var floor_strain: float = engine.engine_strain.volume_db
	var floor_pitch_low: float = engine.engine_low.pitch_scale
	_check(floor_low > idle_low, "the low layer rises under load (%.1f -> %.1f dB)" % [idle_low, floor_low])
	_check(floor_high > idle_high, "the high layer rises under load (%.1f -> %.1f dB)" % [idle_high, floor_high])
	_check(floor_pitch_low > idle_pitch_low, "pitch itself also rises with load, on top of the layering")
	_check(idle_strain <= DerbyAudio.ENGINE_SILENT + 0.5, "the strain layer stays silent at idle (%.1f dB)" % idle_strain)
	_check(floor_strain > idle_strain + 15.0, "and arrives as a distinct band at full load (%.1f -> %.1f dB)" % [idle_strain, floor_strain])
	engine.update_engine(10.0, 0.3)
	var cruise_strain: float = engine.engine_strain.volume_db
	_check(cruise_strain < floor_strain - 10.0, "cruising load does not already sound like redline (%.1f dB)" % cruise_strain)
	engine.queue_free()

	print("")
	print("G5.3 - impact layers by severity and material")
	var impacts := DerbyAudio.new()
	add_child(impacts)
	impacts.play_impact(0.15, Vector3.ZERO, "glass")
	var light_stream: AudioStream = null
	var light_voices := 0
	for voice in impacts.impact_voices:
		if voice.playing:
			light_voices += 1
			light_stream = voice.stream
	_check(light_voices == 1, "a light hit uses a single voice (%d playing)" % light_voices)
	_check(light_stream == impacts.impact_streams["glass"], "and it carries the material's own sound, not a generic one")
	for voice in impacts.impact_voices:
		voice.stop()
	impacts.play_impact(0.95, Vector3.ZERO, "glass")
	var heavy_voices := 0
	var heavy_has_body := false
	for voice in impacts.impact_voices:
		if voice.playing:
			heavy_voices += 1
			if voice.stream == impacts.impact_streams["body"]:
				heavy_has_body = true
	_check(heavy_voices == 2, "a severe hit of the same material stacks a second layer (%d playing)" % heavy_voices)
	_check(heavy_has_body, "and the added layer is the shared low-end body, not a second copy of the material voice")
	impacts.queue_free()

	print("")
	if failures.is_empty():
		print("G5 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
