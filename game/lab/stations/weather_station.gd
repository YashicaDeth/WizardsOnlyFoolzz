extends Node3D

## Station 2: weather. The button steps through `states`. Rain, lightning and
## thunder are the game's own `StormWeather`, driven by its severity dial
## instead of chaos-magick; this station adds what the world does about it:
## open-air surfaces darken and shine as they wet, puddles fill the low spots,
## cloth and scrub take the wind, and acid rain etches a steel cabinet over
## thirty seconds and burns a dummy standing in the open but not the one under
## the roof. Cover is a real ray to the sky, the same one the rain stops on.

const BODIES := preload("res://lab/stations/bodies_station.gd")
const WIND := preload("res://lab/stations/wind_sway.gdshader")
const ETCH := preload("res://lab/stations/acid_etch.gdshader")
const TITLE := "WEATHER"
const VERB := "NEXT WEATHER"

## What each state is. `severity` feeds `StormWeather` (lightning starts above
## 0.15), `wet` is where open surfaces settle, `wind` drives cloth, scrub and
## the slant of the rain.
const STATES := {
	"clear": {"severity": 0.0, "wet": 0.0, "wind": 0.12, "sun": 1.0, "acid": false},
	"rain": {"severity": 0.15, "wet": 0.75, "wind": 0.35, "sun": 0.55, "acid": false},
	"storm": {"severity": 0.85, "wet": 1.0, "wind": 1.0, "sun": 0.25, "acid": false},
	"acid": {"severity": 0.45, "wet": 0.8, "wind": 0.5, "sun": 0.45, "acid": true},
}
## OPEN (Greg): which of these the real map uses at launch. The station steps
## through this list; trim it to try a launch set.
@export var states: PackedStringArray = ["clear", "rain", "storm", "acid"]
## OPEN (Greg): whether acid rain hurts the player at full strength. 1.0 is
## the dummy's rate; the lab keeps the dose the player would have taken.
@export var acid_player_scale := 0.5
## Damage a dummy in the open takes each second of acid rain, spread over
## the zones the rain lands on first.
const ACID_PER_SECOND := 2.5
const ACID_ZONES := ["head", "torso", "left_arm", "right_arm"]
## Seconds of exposure that take the cabinet from clean steel to eaten.
const ETCH_SECONDS := 30.0
## Wetting is quick, drying slow, per second.
const WET_RATE := 0.18
const DRY_RATE := 0.05
const RAIN_DROPS := 4000
const RAIN_HALF_WIDTH := 20.0

var lab: Node3D
var storm: StormWeather
var state := "clear"
var wetness := 0.0
var wind := 0.12
var etch := 0.0
var player_acid_taken := 0.0
var wet_materials: Array[StandardMaterial3D] = []
var open_dummy: BaselineHuman
var covered_dummy: BaselineHuman
var cabinet_material: ShaderMaterial
var _swaying: Array[ShaderMaterial] = []
var _puddles: Array[MeshInstance3D] = []
var _acid_clock := 0.0
var _acid_zone := 0
var _rain_material: StandardMaterial3D


func build(owner_lab: Node3D) -> void:
	lab = owner_lab
	storm = StormWeather.new()
	storm.name = "Storm"
	add_child(storm)
	storm.position = -position
	storm.severity_override = 0.0
	var rain := storm.get_node("Rain") as GPUParticles3D
	# Across the whole hall (tidy-80 widened it), as thick as it always was.
	var hall: Variant = lab.get_script().get("HALF_X") if lab.get_script() != null else null
	var half_x: float = maxf(RAIN_HALF_WIDTH, float(hall) if hall != null else 0.0)
	rain.amount = roundi(RAIN_DROPS * half_x / RAIN_HALF_WIDTH)
	var falling := rain.process_material as ParticleProcessMaterial
	falling.emission_box_extents = Vector3(half_x, 1, RAIN_HALF_WIDTH)
	# The rain stops on the roof (the lab's particle colliders), which is the
	# whole point of a covered half.
	falling.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	rain.visibility_aabb = AABB(Vector3(-half_x - 4.0, -26, -24), Vector3(half_x * 2.0 + 8.0, 30, 48))
	_rain_material = (rain.draw_pass_1 as QuadMesh).material as StandardMaterial3D

	covered_dummy = BODIES.dummy(self, "lab_acid_covered", Vector3(-2.0, 0, -4.0), PI, 1)
	open_dummy = BODIES.dummy(self, "lab_acid_open", Vector3(2.0, 0, 4.0), PI, 2)
	_label("UNDER COVER", Vector3(-2.0, 2.3, -4.0))
	_label("IN THE OPEN", Vector3(2.0, 2.3, 4.0))

	var cabinet := StaticBody3D.new()
	cabinet.name = "SteelCabinet"
	cabinet.position = Vector3(5.0, 0.7, 4.5)
	add_child(cabinet)
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 1.4, 0.6)
	cabinet_material = ShaderMaterial.new()
	cabinet_material.shader = ETCH
	box.material = cabinet_material
	var look := MeshInstance3D.new()
	look.mesh = box
	cabinet.add_child(look)
	var hull := CollisionShape3D.new()
	hull.shape = BoxShape3D.new()
	(hull.shape as BoxShape3D).size = box.size
	cabinet.add_child(hull)

	# A tarp hung from a frame, and dead scrub beside the cabinet, inside the
	# bay's lines.
	_post(Vector3(-5.6, 0, 5.0), 2.6)
	_post(Vector3(-3.4, 0, 5.0), 2.6)
	_post_bar(Vector3(-4.5, 2.6, 5.0), 2.3)
	_sway(Vector3(-4.5, 0.9, 5.0), Vector2(2.0, 1.7), Color("5e2a1d"), true, false, 1.0)
	for index in 5:
		var at := Vector3(5.6 + float(index % 3) * 0.6, 0, 1.6 + float(index) * 0.55)
		for turn in 2:
			_sway(at, Vector2(0.9, 1.1 + 0.2 * float(index % 2)), Color("3c3a1e"), false, true, 0.7, PI * 0.5 * float(turn))
	# The yard's low spots, where standing water collects first.
	for spot in [Vector3(1.0, 0, 7.0), Vector3(-2.5, 0, 9.0), Vector3(4.0, 0, 10.5), Vector3(-6.0, 0, 8.0)]:
		_puddle(spot)
	apply(state)


func press() -> String:
	var at := states.find(state)
	apply(states[(at + 1) % states.size()])
	return "WEATHER: %s" % state.to_upper()


func apply(next: String) -> void:
	state = next if STATES.has(next) else "clear"
	var spec: Dictionary = STATES[state]
	storm.severity_override = float(spec.severity)
	_rain_material.albedo_color = Color(0.72, 0.9, 0.25, 0.5) if bool(spec.acid) else Color(0.72, 0.78, 0.82, 0.35)
	if lab != null and lab.get("sun") != null:
		(lab.sun as DirectionalLight3D).light_energy = float(spec.sun) * 1.4


func status() -> String:
	var line := "%s   WET %d%%   WIND %d%%" % [state.to_upper(), roundi(wetness * 100.0), roundi(wind * 100.0)]
	if bool(STATES[state].acid) or etch > 0.0:
		line += "   ETCH %d%%   OPEN HP %d / COVERED HP %d" % [roundi(etch * 100.0), roundi(_hp(open_dummy)), roundi(_hp(covered_dummy))]
	return line


## True when nothing stands between `at` and the sky.
func exposed(at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.UP * 40.0)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _process(delta: float) -> void:
	var spec: Dictionary = STATES[state]
	var target := float(spec.wet)
	wetness = move_toward(wetness, target, delta * (WET_RATE if target > wetness else DRY_RATE))
	wind = move_toward(wind, float(spec.wind), delta * 0.4)
	_wet_surfaces()
	var falling := (storm.get_node("Rain") as GPUParticles3D).process_material as ParticleProcessMaterial
	falling.direction = Vector3(wind * 0.35, -1.0, 0.0).normalized()
	if not bool(spec.acid):
		return
	if exposed(_cabinet_top()):
		etch = minf(1.0, etch + delta / ETCH_SECONDS)
		cabinet_material.set_shader_parameter("etch", etch)
	_acid_clock += delta
	if _acid_clock < 1.0:
		return
	_acid_clock -= 1.0
	var zone: String = ACID_ZONES[_acid_zone % ACID_ZONES.size()]
	_acid_zone += 1
	for rig: BaselineHuman in [open_dummy, covered_dummy]:
		if rig != null and is_instance_valid(rig) and not rig.anatomy.dead and exposed(rig.global_position + Vector3(0, 2.0, 0)):
			rig.hit(zone, ACID_PER_SECOND, 0.0, "blunt")
	if lab != null and lab.get("player") != null and exposed((lab.player as Node3D).global_position + Vector3(0, 1.0, 0)):
		player_acid_taken += ACID_PER_SECOND * acid_player_scale


func _cabinet_top() -> Vector3:
	return get_node("SteelCabinet").global_position + Vector3(0, 0.75, 0)


func _wet_surfaces() -> void:
	for material in wet_materials:
		if not material.has_meta("dry_albedo"):
			material.set_meta("dry_albedo", material.albedo_color)
			material.set_meta("dry_roughness", material.roughness)
		var dry: Color = material.get_meta("dry_albedo")
		material.albedo_color = Color(dry.r * lerpf(1.0, 0.5, wetness), dry.g * lerpf(1.0, 0.5, wetness), dry.b * lerpf(1.0, 0.52, wetness), dry.a)
		material.roughness = lerpf(float(material.get_meta("dry_roughness")), 0.12, wetness)
	for sway in _swaying:
		sway.set_shader_parameter("wind", wind)
		sway.set_shader_parameter("wetness", wetness)
	cabinet_material.set_shader_parameter("wetness", wetness)
	var fill := clampf((wetness - 0.3) / 0.6, 0.0, 1.0)
	for puddle in _puddles:
		puddle.visible = fill > 0.01
		puddle.scale = Vector3(0.35 + fill * 0.65, 1.0, 0.35 + fill * 0.65)


func _hp(rig: BaselineHuman) -> float:
	if rig == null or not is_instance_valid(rig):
		return 0.0
	var total := 0.0
	for zone in ACID_ZONES:
		total += rig.zone_health(zone)
	return total


func _puddle(at: Vector3) -> void:
	# The dip itself reads dry too: a darker scuffed hollow.
	var hollow := MeshInstance3D.new()
	var dip := CylinderMesh.new()
	dip.top_radius = 1.25
	dip.bottom_radius = 1.25
	dip.height = 0.004
	var dust := StandardMaterial3D.new()
	dust.albedo_color = Color("2a2520")
	dust.roughness = 1.0
	dip.material = dust
	hollow.mesh = dip
	hollow.position = at + Vector3(0, 0.003, 0)
	add_child(hollow)
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.15
	disc.bottom_radius = 1.15
	disc.height = 0.004
	disc.radial_segments = 24
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(0.03, 0.035, 0.04, 0.85)
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.roughness = 0.02
	surface.metallic = 0.4
	surface.metallic_specular = 1.0
	disc.material = surface
	water.mesh = disc
	water.position = at + Vector3(0, 0.008, 0)
	water.rotation.y = randf() * TAU
	water.visible = false
	add_child(water)
	_puddles.append(water)


func _sway(at: Vector3, size: Vector2, tint: Color, pinned_top: bool, leafy: bool, stiffness: float, turn := 0.0) -> void:
	var sheet := QuadMesh.new()
	sheet.size = size
	sheet.subdivide_width = 8
	sheet.subdivide_depth = 10
	sheet.center_offset = Vector3(0, size.y * 0.5, 0)
	var material := ShaderMaterial.new()
	material.shader = WIND
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("height", size.y)
	material.set_shader_parameter("pinned_top", pinned_top)
	material.set_shader_parameter("stiffness", stiffness)
	material.set_shader_parameter("alpha_cut", 1.0 if leafy else 0.0)
	sheet.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = sheet
	instance.position = at
	instance.rotation.y = turn
	add_child(instance)
	_swaying.append(material)


func _post(at: Vector3, height: float) -> void:
	var post := MeshInstance3D.new()
	var bar := CylinderMesh.new()
	bar.top_radius = 0.05
	bar.bottom_radius = 0.05
	bar.height = height
	post.mesh = bar
	post.position = at + Vector3(0, height * 0.5, 0)
	add_child(post)


func _post_bar(at: Vector3, width: float) -> void:
	var post := MeshInstance3D.new()
	var bar := CylinderMesh.new()
	bar.top_radius = 0.04
	bar.bottom_radius = 0.04
	bar.height = width
	post.mesh = bar
	post.position = at
	post.rotation.z = PI * 0.5
	add_child(post)


func _label(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.006
	label.modulate = Color("c8a070")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	add_child(label)
