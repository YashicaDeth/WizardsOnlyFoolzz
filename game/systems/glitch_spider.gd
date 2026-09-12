class_name GlitchSpider
extends Node3D

## PiFrac-DEV Studio's "Glitch Spider particle system" reference — a burst of
## jagged, radiating cracks with a glitchy colour split, for the one moment
## in the hunt that never had any visual weight of its own:
## `reality_misfire_director.gd` is named "Reality Misfire" and had never
## once made reality visibly misfire. `trigger()` is the whole API: point one
## at a world position, let it fade, forget it.
##
## Also gives the psychedelic rig's own screen-space dials a brief, real
## pulse (cut_intensity/chromatic_offset) if handed one — the moment reads as
## reality glitching on the screen and in the world at once, rather than one
## effect standing in for the other.

const GLITCH_SHADER := preload("res://shaders/glitch_spider.gdshader")
const BURST_DURATION := 0.7
## The sharp attack, as a fraction of BURST_DURATION — fast in, slower fade,
## not a symmetric pulse. A crack appears; it does not breathe.
const ATTACK_FRACTION := 0.15

var _material: ShaderMaterial
var _elapsed := -1.0
var _rng := RandomNumberGenerator.new()
var _psychedelic: Control


func _init() -> void:
	_rng.randomize()
	var mesh_instance := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3.4, 3.4)
	mesh_instance.mesh = mesh
	_material = ShaderMaterial.new()
	_material.shader = GLITCH_SHADER
	mesh_instance.material_override = _material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	visible = false


func _ready() -> void:
	set_process(true)


## `look_from` orients the burst to face whoever should actually see it —
## there is no live camera reference on this class, so the caller hands one
## in rather than this node guessing. `psychedelic_rig`, if given, gets the
## screen-space pulse alongside the world-space one; optional, since not
## every caller necessarily has one to hand.
func trigger(world_position: Vector3, look_from: Vector3, psychedelic_rig: Control = null) -> void:
	global_position = world_position
	if look_from.distance_squared_to(world_position) > 0.0001:
		look_at(look_from, Vector3.UP)
	_material.set_shader_parameter("seed_value", _rng.randf() * 1000.0)
	_material.set_shader_parameter("legs", float(_rng.randi_range(5, 9)))
	_elapsed = 0.0
	visible = true
	_psychedelic = psychedelic_rig


func _process(delta: float) -> void:
	if _elapsed < 0.0:
		return
	_elapsed += delta
	var progress := clampf(_elapsed / BURST_DURATION, 0.0, 1.0)
	var intensity := 1.0
	if progress < ATTACK_FRACTION:
		intensity = progress / ATTACK_FRACTION
	else:
		intensity = 1.0 - inverse_lerp(ATTACK_FRACTION, 1.0, progress)
	_material.set_shader_parameter("intensity", intensity)
	_pulse_psychedelic(intensity)
	if progress >= 1.0:
		visible = false
		_elapsed = -1.0
		_pulse_psychedelic(0.0)


func _pulse_psychedelic(intensity: float) -> void:
	if _psychedelic == null or not is_instance_valid(_psychedelic) or not _psychedelic.has_method("set_dial"):
		return
	_psychedelic.set_dial("cut_intensity", intensity * 0.5)
	_psychedelic.set_dial("chromatic_offset", intensity * 0.02)
