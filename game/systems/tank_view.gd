class_name TankView
extends CanvasLayer

## Greg, 28 September (question boxes): inside the tank you should see and
## feel it. The room through the medium and the glass (a wobble, murk at the
## edges), bubbles rising (more when you panic), your breathing through the
## regulator, your heartbeat speeding up with panic, and the whole room
## muffled as if underwater, his voice included. It all goes when the tank
## drains.
##
## Over the world and under every HUD. The chamber sets `in_tank` and
## `panic` from its phase each frame; this does the rest.

const SHADER := preload("res://shaders/tank_view.gdshader")
const SIGHT_AUDIO := preload("res://systems/sight_audio.gd")
const FADE := 1.5
const MUFFLE_HZ := 650.0

var in_tank := true
var panic := 0.0
var amount := 0.0
var clock := 0.0
var screen: ColorRect
var bubbles: Control
var heart: AudioStreamPlayer
var breath: AudioStreamPlayer
var _material: ShaderMaterial
var _muffle: AudioEffectLowPassFilter
var _muffle_bus := -1


func _ready() -> void:
	name = "TankView"
	layer = -30
	screen = ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	screen.material = _material
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubbles = Control.new()
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubbles)
	bubbles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubbles.draw.connect(_draw_bubbles)
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	heart = AudioStreamPlayer.new()
	heart.stream = SIGHT_AUDIO.stream("heartbeat")
	heart.bus = bus
	heart.volume_db = -6.0
	add_child(heart)
	breath = AudioStreamPlayer.new()
	breath.stream = SIGHT_AUDIO.stream("tank_breath")
	breath.bus = bus
	breath.volume_db = -10.0
	add_child(breath)
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = MUFFLE_HZ


func _process(delta: float) -> void:
	clock += delta
	amount = move_toward(amount, 1.0 if in_tank else 0.0, delta / FADE)
	visible = amount > 0.001
	_material.set_shader_parameter("amount", amount)
	_material.set_shader_parameter("panic", panic)
	bubbles.queue_redraw()
	_set_muffled(amount > 0.5)
	if amount > 0.05:
		if not heart.playing:
			heart.play()
		if not breath.playing:
			breath.play()
		# One beat a second calm, near two at full panic.
		heart.pitch_scale = lerpf(1.0, 1.9, panic)
		heart.volume_db = lerpf(-30.0, lerpf(-8.0, -2.0, panic), amount)
		breath.volume_db = lerpf(-30.0, -10.0, amount)
	else:
		heart.stop()
		breath.stop()


func _exit_tree() -> void:
	_set_muffled(false)


## The room's own sound, low-passed while you are under. His voice goes
## through the same bus, so it comes through the glass muffled too.
func _set_muffled(on: bool) -> void:
	var master := AudioServer.get_bus_index("Master")
	if on and _muffle_bus < 0:
		AudioServer.add_bus_effect(master, _muffle)
		_muffle_bus = master
	elif not on and _muffle_bus >= 0:
		for index in AudioServer.get_bus_effect_count(_muffle_bus):
			if AudioServer.get_bus_effect(_muffle_bus, index) == _muffle:
				AudioServer.remove_bus_effect(_muffle_bus, index)
				break
		_muffle_bus = -1


func muffled() -> bool:
	return _muffle_bus >= 0


## Bubbles rising from the regulator and your skin, more when you panic.
func _draw_bubbles() -> void:
	if amount <= 0.01:
		return
	var view := bubbles.size
	var count := int(lerpf(14.0, 46.0, panic))
	for bubble in count:
		var salt := float(bubble) * 12.9898
		var x := _fract(sin(salt) * 43758.5) * view.x
		var speed := 0.07 + 0.08 * _fract(sin(salt * 1.7) * 9631.3)
		var rise := _fract(_fract(sin(salt * 2.3) * 3141.6) + clock * speed * (1.0 + panic))
		var y := view.y * (1.05 - rise * 1.1)
		var wobble := sin(clock * 3.0 + salt) * 6.0
		var radius := 2.0 + 7.0 * _fract(sin(salt * 3.1) * 777.7)
		bubbles.draw_arc(Vector2(x + wobble, y), radius, 0.0, TAU, 14, Color(0.85, 0.95, 0.85, 0.35 * amount), 1.3)
		bubbles.draw_circle(Vector2(x + wobble - radius * 0.3, y - radius * 0.3), radius * 0.2, Color(1, 1, 1, 0.3 * amount))


static func _fract(x: float) -> float:
	return x - floor(x)
