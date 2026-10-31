class_name BrainChipFlash
extends Node3D

## The chip in an alerted character's skull, flashing on their model (Greg,
## 24 September: "an animated brainchip flash on their character model"). It
## sits on the back of the head, over where the brain is on the rig's own
## organ layout, and rides the head anchor so it moves with the body.
##
## Idle it is a dark board, barely there. `flash()` lights it: the traces run
## from the die outward in a pulse, a halo ring beats round the skull, and it
## draws through the head so it reads from the front. After the first burst it
## keeps a slow alert blink until `calm()`.

const BURST_SECONDS := 2.2
const INK := Color(1.0, 0.18, 0.12)
const HOT := Color(1.0, 0.93, 0.85)
const TRACE_COUNT := 6

var active := false
var burst := 0.0
var clock := 0.0
var board: MeshInstance3D
var die: MeshInstance3D
var halo: MeshInstance3D
var traces: Array[MeshInstance3D] = []
var glow: OmniLight3D
var _board_material: StandardMaterial3D
var _die_material: StandardMaterial3D
var _halo_material: StandardMaterial3D
var _trace_materials: Array[StandardMaterial3D] = []


## Mount it on a BaselineHuman's head anchor. Returns the chip.
static func install(rig: Node3D) -> BrainChipFlash:
	var chip := BrainChipFlash.new()
	chip.name = "BrainChip"
	var anchor: Node3D = rig.get("head_anchor") as Node3D
	if anchor == null:
		anchor = rig
	anchor.add_child(chip)
	# The anchor sits 0.12 above the head's centre; the chip goes on the back
	# of the skull (+z is behind a rig facing -z), slightly up.
	chip.position = Vector3(0, -0.06, 0.1)
	chip._build()
	return chip


func _build() -> void:
	_board_material = _material(Color(0.05, 0.06, 0.05), Color.BLACK, 0.0)
	board = _box(Vector3(0.1, 0.075, 0.012), Vector3.ZERO, _board_material)
	_die_material = _material(Color(0.08, 0.08, 0.08), INK, 0.0)
	die = _box(Vector3(0.034, 0.034, 0.016), Vector3(0, 0, 0.006), _die_material)
	for index in TRACE_COUNT:
		var material := _material(Color(0.1, 0.07, 0.04), INK, 0.0)
		var angle := TAU * float(index) / float(TRACE_COUNT)
		var trace := _box(Vector3(0.042, 0.004, 0.004), Vector3(cos(angle), sin(angle), 0.0) * 0.032 + Vector3(0, 0, 0.007), material)
		trace.rotation.z = angle
		traces.append(trace)
		_trace_materials.append(material)
	halo = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.15
	ring.outer_radius = 0.162
	ring.rings = 32
	ring.ring_segments = 6
	_halo_material = _material(INK, INK, 0.0)
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_material.albedo_color = Color(INK, 0.0)
	ring.material = _halo_material
	halo.mesh = ring
	halo.position = Vector3(0, 0.02, -0.1)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	glow = OmniLight3D.new()
	glow.light_color = INK
	glow.light_energy = 0.0
	glow.omni_range = 0.9
	glow.position = Vector3(0, 0, 0.08)
	glow.shadow_enabled = false
	glow.visible = false
	add_child(glow)


func _material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.roughness = 0.4
	material.metallic = 0.6
	return material


func _box(size: Vector3, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = at
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance


## The alarm reached this head.
func flash() -> void:
	active = true
	burst = BURST_SECONDS
	# Seen through the skull while it burns: the point is that you notice.
	for material in [_board_material, _die_material, _halo_material] + _trace_materials:
		(material as StandardMaterial3D).no_depth_test = true
		(material as StandardMaterial3D).render_priority = 6


func calm() -> void:
	active = false
	burst = 0.0
	for material in [_board_material, _die_material, _halo_material] + _trace_materials:
		(material as StandardMaterial3D).no_depth_test = false
		(material as StandardMaterial3D).render_priority = 0
	_apply(0.0, 0.0)


## 0..1 how lit the chip is right now, for tests and captures.
func intensity() -> float:
	return glow.light_energy / 3.0 if glow != null else 0.0


func _process(delta: float) -> void:
	if not active:
		return
	clock += delta
	burst = maxf(0.0, burst - delta)
	var strength: float
	if burst > 0.0:
		# A stutter at 11 Hz under a beat at 3 Hz: a chip being written to.
		strength = clampf(0.55 + 0.45 * sin(clock * TAU * 3.0), 0.0, 1.0) * (0.7 + 0.3 * float(int(clock * 22.0) % 2))
	else:
		strength = 0.35 + 0.35 * maxf(0.0, sin(clock * TAU * 0.8))
	# The pulse runs out along the traces, one after another.
	var travel := fmod(clock * 2.6, 1.0)
	_apply(strength, travel)


func _apply(strength: float, travel: float) -> void:
	_die_material.emission = INK.lerp(HOT, strength * 0.6)
	_die_material.emission_energy_multiplier = strength * 6.0
	_board_material.emission = INK
	_board_material.emission_energy_multiplier = strength * 0.6
	for index in _trace_materials.size():
		var lit := 1.0 - clampf(absf(travel - float(index) / float(TRACE_COUNT)) * 4.0, 0.0, 1.0)
		_trace_materials[index].emission_energy_multiplier = strength * (1.5 + lit * 5.0)
	var ring_scale := 1.0 + fmod(clock * 1.6, 1.0) * 0.6
	halo.scale = Vector3.ONE * ring_scale
	_halo_material.albedo_color = Color(INK, strength * 0.8 * (1.6 - ring_scale))
	_halo_material.emission_energy_multiplier = strength * 3.0
	glow.light_energy = strength * 3.0
	glow.visible = strength > 0.01
