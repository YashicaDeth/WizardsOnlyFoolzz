extends Node

## A9.2 and A9.5. The claims are physical: what is between you and a transmitter
## changes what you hear, walking out of a pit brings a station in, and a weak
## signal is heard *wrongly* rather than quietly.

const RADIO_AUDIO := preload("res://systems/radio_audio.gd")

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

	var radio := WireRadio.new(88.6)
	var pit_control: Dictionary = WireRadio.STATIONS[0]
	var far_station: Dictionary = WireRadio.STATIONS[1]

	# --- the dial still works -------------------------------------------------
	radio.stand_at(Vector2(-155.0, 0.0))
	var on_tune := radio.strength(pit_control)
	radio.khz = 92.0
	var off_tune := radio.strength(pit_control)
	check(on_tune > off_tune, "tuning off a station loses it (%.2f -> %.2f)" % [on_tune, off_tune])
	radio.khz = 88.6

	# --- A9.2: the rim is between you and everything outside it --------------
	# Dead centre of the Bone Yard bowl, receiving a transmitter *outside* it.
	radio.khz = 97.2
	radio.stand_at(Vector2(-155.0, 0.0))
	var in_pit := radio.strength(far_station)
	var pit_shadow := radio.shadow(far_station.at as Vector2)
	check(str(pit_shadow.get("cause", "")) == "THE BONE YARD", "the quarry is named as the obstruction (got '%s')" % str(pit_shadow.get("cause", "")))
	check(float(pit_shadow.get("loss", 1.0)) < 0.5, "and it is a hard shadow (%.2f)" % float(pit_shadow.get("loss", 1.0)))

	# Same dial, same station, standing up on the rim.
	radio.stand_at(Vector2(-155.0 + 94.0, 0.0))
	var on_rim := radio.strength(far_station)
	check(on_rim > in_pit, "climbing out of the pit brings it in (%.3f -> %.3f)" % [in_pit, on_rim])

	# A transmitter inside the same bowl is not shadowed by its own rim.
	radio.khz = 88.6
	radio.stand_at(Vector2(-150.0, 8.0))
	var same_bowl := radio.shadow(pit_control.at as Vector2)
	check(str(same_bowl.get("cause", "")) == "", "standing in the pit with the pit's own transmitter is clear")
	check(radio.strength(pit_control) > 0.5, "and it comes in strongly (%.2f)" % radio.strength(pit_control))

	# --- A9.2: buildings scatter rather than cut -----------------------------
	var open := WireRadio.new(88.6)
	open.stand_at(Vector2(-40.0, 0.0))
	var clear_signal := open.strength(pit_control)
	var built := WireRadio.new(88.6)
	built.stand_at(Vector2(-40.0, 0.0))
	# A wall of footprints across the path back to the Bone Yard.
	var wall: Array = []
	for step in 8:
		wall.append(Rect2(Vector2(-100.0 + float(step) * 7.0, -12.0), Vector2(6.0, 24.0)))
	built.set_occluders(wall)
	var through_town := built.strength(pit_control)
	check(through_town < clear_signal, "a built-up path costs signal (%.3f -> %.3f)" % [clear_signal, through_town])
	check(through_town > 0.0, "but scatters rather than cutting it dead (%.3f)" % through_town)
	check(built.shadow(pit_control.at as Vector2).get("blocked", 0.0) > 1.0, "and the obstruction is measured in metres")
	var beside := WireRadio.new(88.6)
	beside.stand_at(Vector2(-40.0, 90.0))
	beside.set_occluders(wall)
	check(is_equal_approx(beside.shadow(pit_control.at as Vector2).get("blocked", 0.0), 0.0), "a path that misses the buildings is not blocked")

	# --- the band listing reports why ----------------------------------------
	radio.stand_at(Vector2(-155.0, 0.0))
	var named := false
	for entry in radio.band():
		if str(entry.get("shadowed_by", "")) != "":
			named = true
	check(named, "the dial can say what is in the way, not only that something is")

	# --- A9.5: the audio degrades with the signal ----------------------------
	var audio: Node = RADIO_AUDIO.new()
	add_child(audio)
	await get_tree().process_frame
	audio.tune_to("wire", 1.0)
	audio._process(0.016)
	var strong_band: float = audio._band.cutoff_hz
	var strong_drive: float = audio._drive.drive
	var strong_wet: float = audio._room.wet
	var strong_station: float = audio.station.volume_db
	audio.tune_to("wire", 0.08)
	audio._process(0.016)
	check(audio._band.cutoff_hz < strong_band, "a weak signal narrows the band (%.0fHz -> %.0fHz)" % [strong_band, audio._band.cutoff_hz])
	check(audio._drive.drive > strong_drive, "and drives harder (%.2f -> %.2f)" % [strong_drive, audio._drive.drive])
	check(audio._room.wet > strong_wet, "and arrives from further away (%.2f -> %.2f)" % [strong_wet, audio._room.wet])
	check(audio.station.volume_db < strong_station, "and the station itself drops under the carrier")
	check(audio.carrier.volume_db > -60.0, "the carrier is always there, even at full signal")
	check(AudioServer.get_bus_index(audio.BUS) != -1, "the radio owns a real bus with real effects on it")

	# The bed changes with the station kind rather than everything sounding alike.
	audio.tune_to("numbers", 0.9)
	var numbers_stream: AudioStream = audio.station.stream
	audio.tune_to("music", 0.9)
	check(audio.station.stream != numbers_stream, "a numbers station does not sound like the music one")

	# --- the set can actually be turned off ---------------------------------
	# It could not. Both players started in _ready on looping streams and there
	# was no stop path in the class, and "off" was expressed as strength 0.0 —
	# which is a dead band, the loudest carrier hiss it makes. So it blared in
	# every scene that owned a handheld, including after leaving the car.
	audio.tune_to("wire", 0.9)
	audio._process(0.016)
	check(audio.station.playing and audio.carrier.playing, "a tuned set is playing")
	audio.silence()
	var fading: float = audio.carrier.volume_db
	audio._process(0.05)
	check(audio.carrier.volume_db < fading, "letting go of it fades rather than cuts")
	check(audio.station.playing, "and is still audible mid-fade")
	for _frame in 20:
		audio._process(0.05)
	check(not audio.station.playing and not audio.carrier.playing, "and then the set is genuinely stopped, not just quiet")
	audio.tune_to("wire", 0.9)
	audio._process(0.016)
	check(audio.station.playing, "picking it back up starts it again")

	print("RADIO_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
