extends Node

## drug-70: the materia classes, their curve and tolerance, the deliriant
## guard, the smoke physics, and the station in the mechanics lab, driven
## through real InputMap actions where the lab takes them.

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
	_curve()
	_tolerance()
	_deliriant()
	_presets()
	_bakes()
	await _smoke()
	await _station()
	print("MATERIA_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _curve() -> void:
	for class_id: String in Materia.CLASS_ORDER:
		var spec: Dictionary = Materia.CLASSES[class_id]
		var onset := float(spec.onset)
		var peak := float(spec.peak)
		var down := float(spec.comedown)
		var rising := float(Materia.curve(class_id, onset * 0.5).level)
		var top := float(Materia.curve(class_id, onset + peak * 0.5).level)
		var falling := float(Materia.curve(class_id, onset + peak + down * 0.5).level)
		var after := Materia.curve(class_id, onset + peak + down + 1.0)
		var ok := rising > 0.05 and rising < 0.95 and is_equal_approx(top, 1.0) and falling > 0.05 and falling < 0.95 and str(after.phase) == "sober" and float(after.level) == 0.0
		# Continuous at both seams: no dial jumps when a phase changes.
		var seam1 := absf(float(Materia.curve(class_id, onset - 0.01).level) - float(Materia.curve(class_id, onset + 0.01).level))
		var seam2 := absf(float(Materia.curve(class_id, onset + peak - 0.01).level) - float(Materia.curve(class_id, onset + peak + 0.01).level))
		check(ok and seam1 < 0.02 and seam2 < 0.02, "%s rises through onset, holds at peak, falls through comedown, smoothly" % class_id)
	check(str(Materia.curve("psychedelic", 1.0).phase) == "onset" and str(Materia.curve("psychedelic", 20.0).phase) == "peak" and str(Materia.curve("psychedelic", 60.0).phase) == "comedown", "the phases are named onset, peak, comedown")


func _tolerance() -> void:
	WorldHistory.clear_history()
	var day_start := 3.0 * WorldClock.MINUTES_PER_DAY + 600.0
	var first := Materia.dose("tolerance_subject", "cannabinoid", day_start)
	var second := Materia.dose("tolerance_subject", "cannabinoid", day_start + 90.0)
	var other := Materia.dose("tolerance_subject", "stimulant", day_start + 95.0)
	var next_day := Materia.dose("tolerance_subject", "cannabinoid", day_start + WorldClock.MINUTES_PER_DAY)
	check(is_equal_approx(float(first.strength), 1.0), "the first dose of a class in a day is full strength")
	check(float(second.strength) < float(first.strength) and float(second.strength) <= 0.6, "the second dose of the same class that day is weaker (%.2f)" % float(second.strength))
	check(is_equal_approx(float(other.strength), 1.0), "tolerance is per class: a different class that day is not weakened")
	check(is_equal_approx(float(next_day.strength), 1.0), "a new world day starts tolerance over")
	# The weaker dose is weaker on screen and in the body too.
	var strong := Materia.state("tolerance_subject", day_start + 30.0)
	WorldHistory.clear_history()
	Materia.dose("t2", "cannabinoid", day_start)
	Materia.dose("t2", "cannabinoid", day_start + 1.0)
	var doses: Array = WorldHistory.subject("t2").get(Materia.DOSES_KEY, [])
	check(doses.size() == 2 and float((doses[1] as Dictionary).strength) < 1.0, "the dose record keeps the weakened strength")
	check(float(strong.level) > 0.9, "a full-strength dose at its peak reads at the top of the curve")
	var cost_events := 0
	for event in WorldHistory.events:
		if str(event.get("type", "")) == "materia_dose":
			cost_events += 1
	check(cost_events == 2, "every dose is recorded once with its cost")
	check(float((WorldHistory.subject("t2").get("anatomy_state", {}) as Dictionary).get("consciousness", 100.0)) < 100.0, "a dose costs the body")


func _deliriant() -> void:
	var spec := Materia.preset("deliriant")
	check(str(spec.palette) != Materia.FUN_PALETTE, "the deliriant never uses the bright fun palette")
	check(Materia.palette_peak_luminance(str(spec.palette)) < 0.35, "the deliriant's palette stays dark (brightest stop %.2f)" % Materia.palette_peak_luminance(str(spec.palette)))
	check(Materia.palette_peak_luminance(Materia.FUN_PALETTE) > 0.6, "and the fun palette really is the bright one")
	for level in [0.3, 0.7, 1.0, 1.4]:
		var dials := Materia.peak_dials("deliriant", level)
		var decorative_rest := true
		for dial_name: String in Materia.DECORATIVE_DIALS:
			if not is_equal_approx(float(dials[dial_name]), float(PsychedelicRig.NEUTRAL[dial_name])):
				decorative_rest = false
		check(decorative_rest and float(dials.saturation_shift) <= 0.0, "deliriant at %.1f moves no decorative dial and never brightens colour" % level)
	var peak := Materia.peak_dials("deliriant", 1.0)
	check(float(peak.darkness) > 0.5 and float(peak.edge_figures) > 0.5, "the deliriant brings darkness and figures at the edge of vision")
	check(float(spec.altitude) == 0.0 and str(spec.plane) == PlaneLadder.DAATH, "the deliriant goes to Da'ath and carries you nowhere on the ladder")
	check(float(spec.get("lost_minutes", 0.0)) > 0.0, "the deliriant takes time")
	# And in the live state, with a dose running, the rig would get none of it.
	WorldHistory.clear_history()
	Materia.dose("d", "deliriant", 0.0)
	var live := Materia.state("d", 40.0)
	check(str(live.palette) != Materia.FUN_PALETTE and float((live.dials as Dictionary).kaleidoscope_segments) == 0.0, "a live deliriant state sends no fun palette and no mirrors")


func _presets() -> void:
	var known := true
	var rest_ok := true
	for class_id: String in Materia.CLASS_ORDER:
		for dial_name: String in (Materia.CLASSES[class_id] as Dictionary).dials:
			if not PsychedelicRig.NEUTRAL.has(dial_name):
				known = false
				print("  unknown dial ", class_id, " ", dial_name)
		var zero := Materia.peak_dials(class_id, 0.0)
		for dial_name: String in zero:
			if dial_name in ["cut_rate", "displacement_scroll"]:
				continue
			if not is_equal_approx(float(zero[dial_name]), float(PsychedelicRig.NEUTRAL[dial_name])):
				rest_ok = false
	check(known, "every class dial is a dial the shader has")
	check(rest_ok, "every class at level 0 is the neutral screen")
	check(Materia.CLASS_ORDER.size() == 9, "nine classes: stimulant to new-world")
	var psy_seen := Materia.planes_seen(float(Materia.CLASSES.psychedelic.altitude))
	var stim_seen := Materia.planes_seen(float(Materia.CLASSES.stimulant.altitude))
	check(psy_seen.size() > stim_seen.size() and not psy_seen.has(PlaneLadder.DAATH), "a psychedelic lets you see higher up the ladder than a stimulant")
	check(float(Materia.CLASSES.psychedelic.xray_reach) > 1.0 and float(Materia.CLASSES.deliriant.xray_reach) < 1.0, "the X-ray reads further on a psychedelic and shorter on a deliriant")
	for class_id: String in Materia.CLASS_ORDER:
		var feel: Dictionary = (Materia.CLASSES[class_id] as Dictionary).feel
		var any := false
		for key in Materia.FEEL_KEYS:
			if absf(float(feel.get(key, 0.0))) > 0.0:
				any = true
		var cost: Dictionary = (Materia.CLASSES[class_id] as Dictionary).cost
		check(any and float(cost.get("body", 0.0)) > 0.0, "%s changes something you feel and has a cost" % class_id)
	# The shader's new dials are neutral by default: a fresh rig draws nothing.
	var rig := PsychedelicRig.new()
	add_child(rig)
	rig._process(0.0)
	check(not rig._display.visible, "a fresh psychedelic rig with every dial at default is not drawn")
	rig.set_dial("edge_figures", 0.5)
	rig._process(0.0)
	check(rig._display.visible, "moving a new dial engages it")
	rig.queue_free()


func _smoke() -> void:
	var calm := SmokeVolume.new()
	var windy := SmokeVolume.new()
	var wrapped := SmokeVolume.new()
	for volume: SmokeVolume in [calm, windy, wrapped]:
		volume.wall_rays = 0
		volume.turbulence = 0.0
		add_child(volume)
	windy.wind = Vector3(2.0, 0, 0)
	calm.exhale("cigarette", Vector3(0, 1.6, 0), Vector3.FORWARD)
	windy.exhale("cigarette", Vector3(0, 1.6, 0), Vector3.FORWARD)
	# The breath takes 0.8 s to leave; measure from when it has.
	for _i in 50:
		calm.step(1.0 / 60.0)
		windy.step(1.0 / 60.0)
	var density_start := calm.total_density()
	var radius_start := calm.mean_radius()
	for _i in 120:
		calm.step(1.0 / 60.0)
		windy.step(1.0 / 60.0)
	check(windy.centroid().x - calm.centroid().x > 1.0, "the world wind bends the plume downwind (%.2f m)" % (windy.centroid().x - calm.centroid().x))
	check(calm.centroid().z < -0.5, "the breath carries the plume forward with momentum (%.2f m)" % -calm.centroid().z)
	check(calm.centroid().y > 1.6, "warm smoke rises")
	check(calm.total_density() < density_start * 0.75 and calm.mean_radius() > radius_start * 1.5, "it thins and spreads as it lingers")
	# A body in the path: the smoke goes round it, never through it.
	wrapped.wind = Vector3(1.5, 0, 0)
	wrapped.set_obstacles([{"a": Vector3(1.0, 0.6, 0), "b": Vector3(1.0, 1.9, 0), "r": 0.25}] as Array[Dictionary])
	wrapped.exhale("joint", Vector3(0, 1.4, 0), Vector3.RIGHT, 1.2)
	var deepest := 0.0
	for _i in 180:
		wrapped.step(1.0 / 60.0)
		deepest = maxf(deepest, wrapped.deepest_inside())
	var past := 0
	for p in wrapped.positions():
		if p.x > 1.3:
			past += 1
	check(deepest < 0.06, "no smoke sits inside a body (deepest %.3f m)" % deepest)
	check(past > 0, "the smoke curls round the body and closes behind it (%d parcels past it)" % past)
	# Rings keep their speed: a ring travels further than a free exhale.
	var ring := SmokeVolume.new()
	ring.wall_rays = 0
	ring.turbulence = 0.0
	add_child(ring)
	var made := ring.ring("cigarette", Vector3(0, 1.6, 0), Vector3.FORWARD)
	for _i in 90:
		ring.step(1.0 / 60.0)
	check(made > 10 and ring.centroid().z < -0.6, "a smoke ring is a loop of parcels that travels (%.2f m)" % -ring.centroid().z)
	# Each device reads differently.
	var vape_spec: Dictionary = SmokeVolume.DEVICES.vape
	var cig_spec: Dictionary = SmokeVolume.DEVICES.cigarette
	var bong_spec: Dictionary = SmokeVolume.DEVICES.bong
	check(int(vape_spec.count) > int(cig_spec.count) and float(vape_spec.life) < float(cig_spec.life) and float(bong_spec.life) > float(cig_spec.life), "cigarette, vape and bong smoke are different volumes")
	for volume in [calm, windy, wrapped, ring]:
		volume.queue_free()
	await get_tree().process_frame


func _station() -> void:
	WorldHistory.clear_history()
	BloodPool.clear()
	var lab: Node3D = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	var station = lab.materia
	check(station != null and lab.stations.any(func(s: Dictionary) -> bool: return s.node == station), "the materia station stands in the lab")
	check(not station.osc_enabled and not station.bridge.listening, "the TouchDesigner OSC link is off by default")
	# Mapping, with it off: nothing a patch sends reaches the screen unless asked.
	check(station.trip.playing == false and not station.rig._display.visible, "nothing is on screen before anything is taken")

	lab.go_to(lab.stations.find_custom(func(s: Dictionary) -> bool: return s.node == lab.materia))
	await _frames(3)
	check(station.near_plinth(), "the station menu takes you to the materia plinth")
	# Choose the psychedelic sample with the D-pad and take it with USE.
	var target := -1
	for index in station.entries.size():
		if str(station.entries[index].kind) == "sample" and str(station.entries[index].id) == "psychedelic":
			target = index
	while station.selected != target:
		await _press("inspect")
	await _press("interact")
	var doses: Array = WorldHistory.subject("player").get(Materia.DOSES_KEY, [])
	check(doses.size() == 1 and str((doses[0] as Dictionary)["class"]) == "psychedelic", "D-pad and USE take the chosen sample")
	# Run the clock to the peak.
	WorldClock.advance((float(Materia.CLASSES.psychedelic.onset) + 5.0) / WorldClock.MINUTES_PER_SECOND)
	await _frames(4)
	check(str(station.last_state.phase) == "peak" and station.rig._display.visible and station.rig.dial("kaleidoscope_segments") >= 2.0, "at its peak the psychedelic preset is on screen")
	check(station.lab.bodies.reach_scale > 1.2, "and the X-ray reads further")
	check(station.sight != null and station.sight.reach_scale > 1.2, "and the wizard eyes read further too")
	await _press("wizard_eyes")
	check(station.sight.mode == "wizard", "D-pad up opens the wizard eyes at the station")
	await _press("wizard_eyes")
	var lit := 0
	for plane_id in station.plane_marks:
		if station.plane_marks[plane_id].visible:
			lit += 1
	check(lit >= 3, "perception shows planes up the ladder (%d lit)" % lit)
	var stamina_before: float = lab.melee.stamina

	# A cigarette: take it, draw with block held, let the breath go.
	target = -1
	for index in station.entries.size():
		if str(station.entries[index].id) == "cigarette":
			target = index
	station.selected = target
	await _press("interact")
	check(station.device_id == "cigarette" and station.model != null, "USE on a smokeable puts it in hand")
	var before: int = station.smoke.count()
	var down := InputEventAction.new()
	down.action = "guard"
	down.pressed = true
	Input.parse_input_event(down)
	await _seconds(1.4)
	check(station.drawing and station.ember.heat > 0.5, "holding block draws, and the ember brightens (heat %.2f)" % station.ember.heat)
	check(station.lungs.fill > 0.3, "the lungs fill with the draw")
	var up := InputEventAction.new()
	up.action = "guard"
	up.pressed = false
	Input.parse_input_event(up)
	await _seconds(0.9)
	check(station.smoke.count() > before + 10, "letting go breathes out a plume (%d parcels)" % (station.smoke.count() - before))
	check(station.lung_stain > 0.0, "the smoke marks the lungs the X-ray shows")
	# Just after the breath, R1 shapes a ring; once that moment has passed, R1
	# flicks the ash.
	var ring_before: int = station.smoke.count()
	await _press("attack")
	check(station.smoke.count() >= ring_before + 15, "R1 right after an exhale blows a ring")
	await _seconds(1.3)
	station.ember.ash_length = 0.012
	var drops: int = station.ember.drops
	await _press("attack")
	check(station.ember.drops == drops + 1 and station.ember.last_drop_reason == "flicked" and station.ember.ash_length < 0.001, "R1 later flicks the ash off")
	# The ash builds and a hard move knocks it off.
	station.ember.ash_length = 0.02
	await _frames(2)
	drops = station.ember.drops
	# A snap of the view and back, over a few frames: the hand whips round.
	for step_index in 8:
		lab.yaw += 0.35 if step_index < 4 else -0.35
		await get_tree().process_frame
	check(station.ember.drops > drops, "long ash falls when you move hard (%s)" % station.ember.last_drop_reason)
	await _press("reload")
	check(station.device_id.is_empty(), "Y puts it away")

	# The trip plays and USE skips it.
	target = -1
	for index in station.entries.size():
		if str(station.entries[index].kind) == "trip":
			target = index
	station.selected = target
	await _press("interact")
	check(station.trip.playing, "the trip sequence starts at the station")
	await _seconds(0.5)
	await _press("interact")
	await _seconds(0.9)
	check(not station.trip.playing, "USE skips the trip")
	check(MateriaTrip.dials_at(26.0).kaleidoscope_segments >= 2.0 and MateriaTrip.plate_at(26.0) > 0.4 and MateriaTrip.dials_at(40.0).lut_strength == 0.0, "the trip track folds over Greg's plate and ends at rest")

	# OSC: when switched on it maps an address to the dial of the same name.
	station.bridge._deliver({"address": "/psy/feedback_strength", "args": [0.4]})
	check(is_equal_approx(station.rig.dial("feedback_strength"), 0.4), "an OSC dial message maps onto the shader uniform of the same name")
	station._on_osc("/materia/preset", ["deliriant", 1.0])
	check(station.rig.dial("darkness") > 0.5, "/materia/preset shows a class preset")

	# The deliriant takes time.
	var clock_before := WorldClock.minutes()
	var lost: float = station.take_lost_time()
	check(lost > 0.0 and WorldClock.minutes() - clock_before >= lost - 0.01, "lost time moves the world clock on (%.1f minutes)" % lost)
	check(lab.melee.stamina >= 0.0 and stamina_before >= 0.0, "stamina stays in range under a dose")
	lab.queue_free()
	await _frames(2)


## TouchDesigner bakes dropped into the bake folder are picked up, and the
## deliriant guard reads a baked LUT too. Written to user://, removed after.
func _bakes() -> void:
	var real_dir := MateriaBakes.bake_dir
	var dir := "user://materia_bake_test"
	DirAccess.make_dir_recursive_absolute(dir)
	MateriaBakes.bake_dir = dir
	var bright := Image.create(16, 1, false, Image.FORMAT_RGB8)
	bright.fill(Color(1.0, 0.95, 0.4))
	bright.save_png(dir.path_join("lut_ash.png"))
	check(Materia.palette_texture("ash").get_width() == 16, "a baked LUT replaces the generated palette")
	check(Materia.palette_peak_luminance("ash") > 0.35, "a bright baked LUT on the deliriant's palette is caught by the guard")
	var atlas := Image.create(64, 32, false, Image.FORMAT_RGB8)
	atlas.save_png(dir.path_join("trip_flipbook.png"))
	var sidecar := FileAccess.open(dir.path_join("trip_flipbook.json"), FileAccess.WRITE)
	sidecar.store_string(JSON.stringify({"columns": 4, "rows": 2, "frames": 7, "fps": 10, "loop": true}))
	sidecar.close()
	var layer := CanvasLayer.new()
	add_child(layer)
	var rig := PsychedelicRig.new()
	layer.add_child(rig)
	var trip := MateriaTrip.new()
	add_child(trip)
	trip.setup(rig, layer)
	check(trip.plate.texture is AtlasTexture and int(trip.flipbook.frames) == 7, "a baked flipbook becomes the trip's ground")
	check(trip.flipbook_frame(0.25) == 2 and trip.flipbook_frame(0.75) == 0, "the flipbook steps at its own fps and loops")
	check(MateriaBakes.flipbook_region(trip.flipbook, 5) == Rect2(16, 16, 16, 16), "frame 5 is the second row, second cell")
	trip.queue_free()
	layer.queue_free()
	for file_name in ["lut_ash.png", "trip_flipbook.png", "trip_flipbook.json"]:
		DirAccess.remove_absolute(dir.path_join(file_name))
	MateriaBakes.bake_dir = real_dir
	check(Materia.palette_peak_luminance("ash") < 0.35, "with the bake gone the deliriant's palette is dark again")


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	await _frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
