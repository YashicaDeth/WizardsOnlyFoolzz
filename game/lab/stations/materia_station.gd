extends Node3D

## Station 6: materia (drug-70). The table of everything takeable that already
## exists (`SubstanceStation`, the same node the Hunt and the shed drop), a rack
## of class samples so each of the nine classes can be tried on its own, and
## the smoke, the body it curls round and the wall it slides along.
##
## Pad first, keyboard equal, all real InputMap actions:
## - at the plinth: D-pad left / right (`heal` / `inspect`) choose, USE takes;
## - a smokeable in hand: hold block (`guard`, L1 / RMB) to draw, let go and
##   the breath leaves on its own; R1 / LMB flicks the ash, or, just after an
##   exhale, blows a ring; Y / R puts it away;
## - D-pad up / K (`wizard_eyes`) opens the wizard eyes here: how far they
##   read, and how long before they strain, follow the class you are on, as
##   the X-ray's reach does;
## - the TRIP entry plays the 40-second sequence; USE again skips it.
##
## What each class does is `Materia` (systems/materia.gd); the picture is
## `PsychedelicRig`; the smoke is `SmokeVolume` and `SmokeEmber`; the lungs are
## `PulmonaryDiagnostic`. This file is the glue and owns no rule of its own.
##
## Dev dials (defaults in REMASTER_LOG.md): `osc_enabled` (off) lets a
## TouchDesigner patch drive the shader over OSC; `clock_rate` speeds the world
## clock while a dose is live, so a full arc fits in a short lab visit;
## `lost_time_enabled` (on) lets the deliriant take minutes away.

const BODIES := preload("res://lab/stations/bodies_station.gd")
const TRIP := preload("res://lab/stations/materia_trip.gd")
const SubstanceStationRef := preload("res://systems/substance_station.gd")
const SubstanceObjects := preload("res://systems/substance_objects.gd")
const TITLE := "MATERIA"
const VERB := "TAKE / SMOKE / TRIP"
const SUBJECT := "player"

## Where the smoker stands relative to the station, and the body downwind.
const SMOKER_AT := Vector3(0, 0, 1.9)
const DUMMY_AT := Vector3(1.6, 0, 1.4)
const WALL_AT := Vector3(-1.9, 1.2, 0.9)

@export var osc_enabled := false
@export var osc_port := OSCBridge.DEFAULT_PORT
@export var clock_rate := 6.0
@export var lost_time_enabled := true
## m/s of wind per unit of the weather station's wind (0.12 clear to 1 storm).
@export var wind_per_weather := 2.4
## -1 follows the weather; anything else pins the wind speed (m/s, along +X).
var wind_override := -1.0

var lab: Node3D
var table: SubstanceStation
var smoke: SmokeVolume
var ember: SmokeEmber
var rig: PsychedelicRig
var rig_layer: CanvasLayer
var trip: MateriaTrip
var bridge: OSCBridge
var radio: AudioReactive
var lungs: PulmonaryDiagnostic
## The wizard eyes (SignalSight), with one hidden mark on the smoke wall that
## only they show. Their reach follows `Materia.state().xray_reach`.
var sight: SignalSight
const HIDDEN_AT := Vector3(-1.78, 1.5, 0.6)
var dummy: BaselineHuman
var plane_marks: Dictionary = {}
var entries: Array[Dictionary] = []
var selected := 0
var last_state: Dictionary = {}
var _palette_shown := ""

# --- the smoke in hand ---
var device_id := ""
var model: Node3D
var spent := 0.0
var drawing := false
var draw_held := 0.0
var _dosed_this_item := false
var _pending_exhale: Dictionary = {}
var _exhale_wait := 0.0
var _trick_window := 0.0
var lung_fill := 0.0
var lung_stain := 0.0
var lung_cough := 0.0
var _lungs_show := 0.0
var _lift := 0.0
var _ladder_clock := 0.0
var _ladder_altitude := 0.0

# --- lost time ---
var lost_time_events := 0
var _lost_clock := 0.0
var _blackout := 0.0
var _sway_phase := 0.0


func build(owner_lab: Node3D) -> void:
	lab = owner_lab
	table = SubstanceStationRef.new()
	table.name = "Table"
	add_child(table)
	table.position = Vector3(0, 0, -0.4)
	table.build(true)
	_build_samples()
	dummy = BODIES.dummy(self, "materia_dummy", DUMMY_AT, -PI * 0.5, 3)
	_build_wall()
	_build_plane_marks()

	smoke = SmokeVolume.new()
	smoke.name = "Smoke"
	lab.add_child.call_deferred(smoke)
	ember = SmokeEmber.new()
	ember.name = "Ember"
	add_child(ember)

	rig_layer = CanvasLayer.new()
	rig_layer.name = "MateriaScreen"
	# Over the 3D, under the lab HUD, so the readout stays readable on a trip.
	rig_layer.layer = 0
	add_child(rig_layer)
	rig = PsychedelicRig.new()
	rig.name = "Psychedelic"
	rig_layer.add_child(rig)
	trip = TRIP.new()
	trip.name = "Trip"
	add_child(trip)
	trip.setup(rig, rig_layer)
	trip.finished.connect(func(skipped: bool) -> void:
		if lab != null and lab.has_method("_note"):
			lab._note("TRIP %s" % ("SKIPPED" if skipped else "OVER")))

	bridge = OSCBridge.new()
	add_child(bridge)
	bridge.drive(rig)
	bridge.message.connect(_on_osc)
	set_osc(osc_enabled)

	radio = AudioReactive.new()
	add_child(radio)
	radio.listen("Master")

	var lung_layer := CanvasLayer.new()
	lung_layer.layer = 3
	add_child(lung_layer)
	lungs = PulmonaryDiagnostic.new()
	lungs.name = "Lungs"
	lung_layer.add_child(lungs)

	if lab.get("camera") != null:
		sight = SignalSight.new()
		sight.name = "WizardEyes"
		sight.handle_keys = false
		add_child(sight)
		sight.setup(lab.camera)
		sight.enabled = true
		sight.hidden = [{"id": "materia_wall_mark", "at": to_global(HIDDEN_AT),
			"size": Vector2(0.6, 0.6), "across": global_basis.z}]
		sight.hidden_seen.connect(func(_id: String) -> void:
			if lab.has_method("_note"):
				lab._note("WIZARD EYES // HIDDEN MARK ON THE WALL"))

	for raw in SubstanceStationRef.MANIFEST:
		var entry: Dictionary = raw
		entries.append({"kind": str(entry.kind), "id": str(entry.id), "label": _item_label(entry)})
	for class_id in Materia.CLASS_ORDER:
		entries.append({"kind": "sample", "id": str(class_id), "label": "SAMPLE // %s" % str(class_id).replace("_", " ").to_upper()})
	entries.append({"kind": "trip", "id": "trip", "label": "TRIP SEQUENCE (40 S, SKIPPABLE)"})
	entries.append({"kind": "osc", "id": "osc", "label": "TOUCHDESIGNER OSC LINK (DEV)"})


func _item_label(entry: Dictionary) -> String:
	var id := str(entry.id)
	if str(entry.kind) == "smokeable":
		return "%s  [%s]" % [str((Smokeables.CATALOG.get(id, {}) as Dictionary).get("label", id)).to_upper(), Materia.class_of(id).replace("_", " ").to_upper()]
	return "%s %s  [%s]" % [str((Substances.CATALOG.get(id, {}) as Dictionary).get("label", id)).to_upper(), str(entry.get("form", "")).to_upper(), Materia.class_of(id).replace("_", " ").to_upper()]


## A shelf of class samples beside the table. Labelled by class only: no
## names are invented for things the world has not named.
func _build_samples() -> void:
	var shelf := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.04, 0.3)
	shelf.mesh = box
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("3a2c22")
	wood.roughness = 0.9
	shelf.material_override = wood
	shelf.position = Vector3(0, 1.32, -0.95)
	add_child(shelf)
	for index in Materia.CLASS_ORDER.size():
		var class_id := str(Materia.CLASS_ORDER[index])
		var x := -1.05 + float(index) * 0.26
		var sample := SubstanceObjects.build("blister", "")
		sample.position = Vector3(x, 1.36, -0.95)
		add_child(sample)
		var tag := Label3D.new()
		tag.text = class_id.replace("_", " ").to_upper()
		tag.font_size = 18
		tag.pixel_size = 0.0012
		tag.modulate = Color("d8cbb0")
		tag.position = Vector3(x, 1.27, -0.79)
		add_child(tag)


func _build_wall() -> void:
	var wall := StaticBody3D.new()
	wall.name = "SmokeWall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.4, 3.0)
	shape.shape = box
	wall.add_child(shape)
	var look := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	look.mesh = mesh
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("4b4a46")
	concrete.roughness = 0.95
	look.material_override = concrete
	wall.add_child(look)
	wall.position = WALL_AT
	add_child(wall)


## The ladder on the back wall, from PlaneLadder's own names. Each one shows
## only while what you have taken carries you above its "see" floor; Da'ath
## has its own mark that only the deliriant lights, and badly.
func _build_plane_marks() -> void:
	var order := PlaneLadder.reachable_planes()
	for index in order.size():
		var plane_id := str(order[index])
		var mark := Label3D.new()
		mark.text = str((PlaneLadder.PLANES[plane_id] as Dictionary).name).to_upper()
		mark.font_size = 34
		mark.pixel_size = 0.0022
		mark.modulate = Color(0.85, 0.78, 0.6, 0.0)
		mark.outline_modulate = Color(0, 0, 0, 0)
		mark.position = Vector3(1.1, 0.55 + float(index) * 0.26, -1.3)
		mark.visible = false
		add_child(mark)
		plane_marks[plane_id] = mark
	var daath := Label3D.new()
	daath.text = "DA'ATH"
	daath.font_size = 34
	daath.pixel_size = 0.0022
	daath.modulate = Color(0.25, 0.05, 0.05, 0.0)
	daath.position = Vector3(1.6, 1.6, -1.3)
	daath.visible = false
	add_child(daath)
	plane_marks[PlaneLadder.DAATH] = daath


# --- the button ---------------------------------------------------------------

func press() -> String:
	if trip.playing:
		trip.skip()
		return "SKIPPING"
	var entry: Dictionary = entries[selected]
	match str(entry.kind):
		"smokeable":
			return take_smokeable(str(entry.id))
		"substance":
			var class_id := Materia.class_of(str(entry.id))
			var taken := Materia.dose(SUBJECT, class_id, WorldClock.minutes(), str(entry.id))
			return "%s // %s AT %d%%" % [str(entry.label).get_slice("  [", 0), class_id.replace("_", " ").to_upper(), roundi(float(taken.get("strength", 0.0)) * 100.0)]
		"sample":
			var taken := Materia.dose(SUBJECT, str(entry.id), WorldClock.minutes())
			return "%s AT %d%%" % [str(entry.label), roundi(float(taken.get("strength", 0.0)) * 100.0)]
		"trip":
			trip.play()
			return "TRIP // [%s] SKIPS" % InputProfile.glyph("interact")
		"osc":
			set_osc(not osc_enabled)
			return "OSC %s" % ("LISTENING ON %d" % osc_port if bridge.listening else "OFF")
	return ""


func select(step: int) -> String:
	selected = posmod(selected + step, entries.size())
	return str(entries[selected].label)


func status() -> String:
	var line := "> %s" % str(entries[selected].label) if not entries.is_empty() else ""
	if not last_state.is_empty() and float(last_state.get("level", 0.0)) > 0.0:
		line += "   %s %s %d%%" % [str(last_state["class"]).replace("_", " ").to_upper(), str(last_state["phase"]).to_upper(), roundi(float(last_state["level"]) * 100.0)]
	if not device_id.is_empty():
		line += "   %s ASH %dMM" % [device_id.to_upper(), roundi(ember.ash_length * 1000.0)]
	if bridge != null and bridge.listening:
		line += "   OSC ON"
	return line


func near_plinth() -> bool:
	if lab == null or lab.get("player") == null:
		return false
	var plinth := to_global(Vector3(0, 0, 0.9))
	return Vector2(lab.player.global_position.x - plinth.x, lab.player.global_position.z - plinth.z).length() < 2.6


## The station's own inputs. Returns true when it used the event, so the lab's
## weapons do not also swing on it.
func handle_input(event: InputEvent) -> bool:
	if not device_id.is_empty():
		if event.is_action_pressed("guard"):
			begin_draw()
			return true
		if event.is_action_released("guard"):
			end_draw()
			return true
		if event.is_action_pressed("attack"):
			flick_or_ring()
			return true
		if event.is_action_pressed("reload"):
			put_away()
			return true
	if sight != null and event.is_action_pressed("wizard_eyes"):
		sight.toggle_wizard()
		return true
	if near_plinth():
		if event.is_action_pressed("heal"):
			lab._note(select(-1))
			return true
		if event.is_action_pressed("inspect"):
			lab._note(select(1))
			return true
	if trip.playing and event.is_action_pressed("ui_cancel"):
		trip.skip()
		return true
	return false


# --- smoking ------------------------------------------------------------------

func take_smokeable(id: String) -> String:
	put_away()
	device_id = id
	model = Smokeables.build(id, 0.0)
	model.set_meta("device_id", id)
	spent = 0.0
	_dosed_this_item = false
	lab.camera.add_child(model)
	_pose_model(0.0)
	ember.attach(model, id, smoke, lab)
	return "%s IN HAND // HOLD [%s] TO DRAW" % [id.to_upper(), InputProfile.glyph("guard")]


func put_away() -> void:
	ember.detach()
	if model != null and is_instance_valid(model):
		model.queue_free()
	model = null
	device_id = ""
	drawing = false


func begin_draw() -> void:
	if device_id.is_empty() or not _pending_exhale.is_empty():
		return
	drawing = true
	draw_held = 0.0


func end_draw() -> Dictionary:
	if not drawing:
		return {}
	drawing = false
	var quality := Smokeables.draw_quality(device_id, draw_held)
	if not bool(quality.get("ok", false)):
		return quality
	# The class dose is the session: lighting an item doses once, its later
	# draws carry the breath and the lungs. A second item of the same class in
	# one day is where tolerance shows.
	if not _dosed_this_item:
		_dosed_this_item = true
		Materia.dose(SUBJECT, Materia.class_of(device_id), WorldClock.minutes(), device_id, true)
	var harsh := float(quality.harsh)
	lung_fill = clampf(float(quality.strength) / maxf(float((Smokeables.CATALOG[device_id] as Dictionary).yield_scale), 0.01), 0.0, 1.3)
	lung_stain = clampf(lung_stain + (0.012 + harsh * 0.05) * Materia.cost_scale, 0.0, 1.0)
	lung_cough = clampf(harsh, 0.0, 1.0)
	_pending_exhale = {"breath": 1.0 + harsh * 0.6, "volume": clampf(draw_held / float((Smokeables.CATALOG[device_id] as Dictionary).draw_ideal), 0.3, 1.6)}
	# One short hold at the lips, then the breath leaves on its own.
	_exhale_wait = 0.55
	_lungs_show = 2.5
	spent = minf(1.0, spent + Smokeables.spend_per_hit(device_id))
	Smokeables.set_spent(model, spent)
	return quality


func exhale_now() -> int:
	if _pending_exhale.is_empty():
		return 0
	var made := smoke.exhale(device_id if not device_id.is_empty() else "cigarette", mouth(), forward(),
		float(_pending_exhale.breath), float(_pending_exhale.volume))
	_pending_exhale = {}
	_trick_window = 1.2
	if spent >= 1.0:
		put_away()
		lab._note("STUBBED OUT")
	return made


func flick_or_ring() -> void:
	if _trick_window > 0.0:
		smoke.ring(device_id, mouth(), forward())
		_trick_window = 0.0
		lab._note("RING")
		return
	if ember.flick(lab.camera.global_basis.x * 0.4 + Vector3.DOWN):
		lab._note("ASH FLICKED")


func mouth() -> Vector3:
	return lab.camera.global_position + forward() * 0.12 + Vector3.DOWN * 0.05


func forward() -> Vector3:
	return (-lab.camera.global_basis.z + Vector3.UP * 0.05).normalized()


func _pose_model(to_mouth: float) -> void:
	if model == null:
		return
	var rest := Vector3(0.13, -0.11, -0.3) if device_id != "bong" else Vector3(0.0, -0.42, -0.42)
	var lips := Vector3(0.02, -0.055, -0.12) if device_id != "bong" else Vector3(0.0, -0.36, -0.2)
	model.position = rest.lerp(lips, smoothstep(0.0, 1.0, to_mouth))
	model.rotation = Vector3(0.05, 0.35 * (1.0 - to_mouth) + 0.05, 0.0) if device_id != "bong" else Vector3.ZERO


# --- every frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	if lab == null or lab.get("camera") == null:
		return
	var now := WorldClock.minutes()
	var live: bool = not str(last_state.get("class", "")).is_empty()
	if live and clock_rate > 0.0:
		WorldClock.advance(delta * clock_rate)
		now = WorldClock.minutes()
	# The ladder's own altitude walks the event log; twice a second is plenty.
	_ladder_clock -= delta
	if _ladder_clock <= 0.0:
		_ladder_clock = 0.5
		_ladder_altitude = PlaneLadder.altitude(SUBJECT)
	last_state = Materia.state(SUBJECT, now, _ladder_altitude)

	# The wind, from the weather station's own dial unless pinned.
	var speed := wind_override if wind_override >= 0.0 else (float(lab.weather.wind) * wind_per_weather if lab.get("weather") != null else 0.0)
	smoke.wind = Vector3(speed, 0.0, 0.0)
	ember.wind_speed = speed
	_refresh_obstacles()

	# The hand.
	if drawing:
		draw_held += delta
	# Up to the lips over half a second and back down again, eased: bringing a
	# cigarette to your mouth should not be the jolt that knocks the ash off.
	var lift_target := 1.0 if drawing or _exhale_wait > 0.0 else 0.0
	_lift = move_toward(_lift, lift_target, delta * 2.2)
	_pose_model(_lift)
	ember.tick(delta, Smokeables.draw_heat(device_id, draw_held) if drawing else 0.0)
	if not _pending_exhale.is_empty():
		_exhale_wait -= delta
		if _exhale_wait <= 0.0:
			exhale_now()
	_trick_window = maxf(0.0, _trick_window - delta)
	# Lungs: fill with the draw, empty with the breath, show while it matters.
	if drawing:
		lung_fill = clampf(Smokeables.draw_heat(device_id, draw_held) * 0.8, 0.0, 1.3)
		_lungs_show = 1.0
	elif _pending_exhale.is_empty():
		lung_fill = move_toward(lung_fill, 0.0, delta * 0.9)
	lung_cough = move_toward(lung_cough, 0.0, delta * 0.4)
	_lungs_show = maxf(0.0, _lungs_show - delta)
	var xray_on: bool = lab.get("bodies") != null and bool(lab.bodies.xray)
	lungs.set_state({
		"lung_health": clampf(1.0 - lung_stain * 0.6, 0.0, 1.0), "lung_stain": lung_stain,
		"lung_fill": lung_fill, "lung_cough": lung_cough, "lung_inhaling": drawing,
		"pulmonary_expanded": _lungs_show > 0.0 or (xray_on and (lung_fill > 0.02 or lung_stain > 0.05)),
	})

	_drive_screen(delta)
	_reveal_planes()
	_lost_time(delta)


func _refresh_obstacles() -> void:
	var capsules: Array[Dictionary] = []
	if dummy != null and is_instance_valid(dummy) and not dummy.anatomy.dead:
		var feet := dummy.global_position
		capsules.append({"a": feet + Vector3.UP * 0.3, "b": feet + Vector3.UP * 1.45, "r": 0.24})
	smoke.set_obstacles(capsules)
	if lab.get("player") != null:
		smoke.set_ray_exclusions([lab.player.get_rid()])


func _drive_screen(delta: float) -> void:
	if trip.playing or (bridge != null and bridge.listening):
		return
	var dials: Dictionary = last_state.get("dials", PsychedelicRig.NEUTRAL)
	for dial_name: String in dials:
		rig.set_dial(dial_name, float(dials[dial_name]))
	var palette := str(last_state.get("palette", ""))
	if not palette.is_empty() and palette != _palette_shown:
		_palette_shown = palette
		rig.set_texture("lut_texture", Materia.palette_texture(palette))
	# The beat: the lab's own sound through the master bus; a heartbeat when it
	# is silent, so a pulse dial is never dead.
	var beat := maxf(radio.beat, radio.band("bass"))
	if beat < 0.02 and float(dials.get("pulse_strength", 0.0)) > 0.0:
		var t := fmod(Time.get_ticks_msec() * 0.001 * 1.2, 1.0)
		beat = exp(-t * 9.0) + exp(-maxf(t - 0.18, 0.0) * 12.0) * 0.6 * (1.0 if t >= 0.18 else 0.0)
	rig.set_dial("beat_level", clampf(beat, 0.0, 1.0))
	if _blackout > 0.0:
		_blackout -= delta
		rig.set_dial("darkness", 1.0)
		rig.set_dial("tunnel", 1.0)


## Perception shows the hidden ladder; altitude decides how far up it goes.
## The X-ray reach follows the class too.
func _reveal_planes() -> void:
	var feel: Dictionary = last_state.get("feel", {})
	var perception := float(feel.get("perception", 0.0))
	var seen := Materia.planes_seen(float(last_state.get("altitude", 0.0)))
	for plane_id: String in plane_marks:
		var mark := plane_marks[plane_id] as Label3D
		var lit := 0.0
		if plane_id == PlaneLadder.DAATH:
			lit = 0.6 if str(last_state.get("plane", "")) == PlaneLadder.DAATH else 0.0
		elif plane_id != "malkuth" and plane_id in seen:
			lit = clampf(perception * 1.4, 0.0, 1.0)
		mark.visible = lit > 0.01
		mark.modulate.a = lit
	var reach := float(last_state.get("xray_reach", 1.0))
	if lab.get("bodies") != null:
		lab.bodies.reach_scale = reach
	if sight != null:
		sight.reach_scale = reach


## The deliriant takes time. At its peak, every so often the screen goes and
## comes back with the world clock further on and you facing somewhere else.
func _lost_time(delta: float) -> void:
	if not lost_time_enabled or str(last_state.get("class", "")) != "deliriant" or str(last_state.get("phase", "")) != "peak":
		_lost_clock = 0.0
		return
	_lost_clock += delta
	if _lost_clock < 14.0:
		return
	_lost_clock = -randf_range(0.0, 10.0)
	take_lost_time()


func take_lost_time() -> float:
	var minutes := float(Materia.CLASSES.deliriant.lost_minutes) * randf_range(0.3, 1.0)
	WorldClock.advance(minutes / WorldClock.MINUTES_PER_SECOND)
	lost_time_events += 1
	_blackout = 0.9
	if lab.get("yaw") != null:
		lab.yaw += randf_range(-PI, PI)
	WorldHistory.record_event("materia_lost_time", {"subject_id": SUBJECT, "minutes": snappedf(minutes, 0.1)})
	return minutes


## Called by the lab after its camera is placed each physics frame: sway, a
## shakier or steadier aim, stamina, pain. Behind `Materia.feel_scale`.
func apply_body(delta: float) -> void:
	var feel: Dictionary = last_state.get("feel", {})
	if feel.is_empty():
		return
	_sway_phase += delta
	var sway := float(feel.get("sway", 0.0))
	var aim := float(feel.get("aim", 0.0))
	var shake := sway * 0.05 + maxf(0.0, -aim) * (0.03 if bool(lab.get("aiming")) else 0.008)
	if bool(lab.get("aiming")) and aim > 0.0:
		shake *= 1.0 - clampf(aim, 0.0, 0.8)
	var cam: Camera3D = lab.camera
	cam.rotation.z += sin(_sway_phase * 0.7) * shake
	cam.rotation.x += sin(_sway_phase * 1.3 + 1.0) * shake * 0.5
	cam.rotation.y += sin(_sway_phase * 0.9 + 2.0) * shake * 0.6
	if lab.get("melee") != null:
		var melee: MeleeDriver = lab.melee
		melee.stamina = clampf(melee.stamina + MeleeDriver.STAMINA_REGEN * float(feel.get("stamina", 0.0)) * 0.5 * delta, 0.0, MeleeDriver.MAX_STAMINA)
	if lab.get("player_body") != null and lab.player_body != null:
		var anatomy = lab.player_body.anatomy
		anatomy.pain = maxf(0.0, float(anatomy.pain) - float(feel.get("pain", 0.0)) * 12.0 * delta)


# --- TouchDesigner --------------------------------------------------------------

## Development only, off by default. While it listens, TouchDesigner has the
## wheel: the class curve stops writing the dials so a slider is not fought.
func set_osc(on: bool) -> void:
	osc_enabled = on
	if on:
		if not bridge.listen(osc_port):
			osc_enabled = false
	else:
		bridge.stop()
		rig.reset_dials()


## Beyond plain dials (which `bridge.drive(rig)` already routes by address):
## `/materia/preset <class> [level]` shows a class preset, and
## `/materia/lut <path>` loads a LUT baked out of TouchDesigner.
func _on_osc(address: String, args: Array) -> void:
	if address == "/materia/preset" and not args.is_empty():
		var class_id := str(args[0])
		var level := float(args[1]) if args.size() > 1 and (args[1] is float or args[1] is int) else 1.0
		var dials := Materia.peak_dials(class_id, level)
		for dial_name: String in dials:
			rig.set_dial(dial_name, float(dials[dial_name]))
		var palette := str((Materia.CLASSES.get(class_id, {}) as Dictionary).get("palette", ""))
		if not palette.is_empty():
			rig.set_texture("lut_texture", Materia.palette_texture(palette))
	elif address == "/materia/lut" and not args.is_empty():
		var path := str(args[0])
		var image := Image.new()
		var loaded := image.load(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
		if loaded == OK:
			rig.set_texture("lut_texture", ImageTexture.create_from_image(image))
