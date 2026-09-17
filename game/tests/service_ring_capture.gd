extends Node

## Visual proof for the Service Ring slice. This does not stage a decorative
## relay gallery: it loads the real underground derby, sits in its real cab,
## fires the real travelling rounds and fails the capture if those rounds do
## not disable the three real chamber relays.

const FACILITY := preload("res://systems/facility_territory.gd")
const FPS := 30

var derby: Node
var caption: Label


func _frames(count: int, physics := false) -> void:
	for _frame in count:
		if physics:
			await get_tree().physics_frame
		else:
			await get_tree().process_frame


func _caption(text: String) -> void:
	caption.text = text


func _park_on(relay: Node3D) -> void:
	var toward_arena := Vector3(relay.global_position.x, 0.0, relay.global_position.z).normalized()
	derby.boat.freeze = true
	derby.boat.global_position = relay.global_position - toward_arena * 12.0 + Vector3.UP * 0.75
	derby.boat.look_at(Vector3(relay.global_position.x, derby.boat.global_position.y, relay.global_position.z), Vector3.UP)
	derby.boat.linear_velocity = Vector3.ZERO
	derby.aim_yaw = 0.0
	derby.aim_pitch = 0.0
	derby._update_cab_camera(1.0)


func _shoot_relay(relay: Node3D) -> bool:
	for hit in 3:
		derby.fire_cooldown = 0.0
		derby._fire_from_cab()
		await _frames(12, true)
		_caption("PHYSICAL CAB ROUND %d/3  //  RELAY %02d" % [hit + 1, relay.relay_index + 1])
		await _frames(9)
	return relay.disabled


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	FACILITY.apply_event("opening_entered_pit")
	derby = load("res://underground_colosseum.tscn").instantiate()
	add_child(derby)
	await _frames(3, true)

	# The eight-car heat has just ended; the player keeps control because the
	# territorial hardware remains. Remove only the defeated AI bodies so the
	# capture can judge the authored objective rather than another collision.
	for target: Node in derby.targets.duplicate():
		if is_instance_valid(target):
			target.queue_free()
	derby.targets.clear()
	derby.disabled_count = 8
	derby.round_state = "active"
	derby.countdown = 0.0
	derby.in_cab = true
	derby.boat.enabled = false

	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	caption = Label.new()
	caption.position = Vector2(32, 22)
	caption.size = Vector2(1216, 52)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color("f1d7a8"))
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)

	_caption("EIGHT WRECKERS DOWN  //  THE SERVICE RING IS STILL WATCHING")
	_park_on(derby.service_relays[0])
	await _frames(FPS * 2)

	for index in derby.service_relays.size():
		var relay: Node3D = derby.service_relays[index]
		_park_on(relay)
		_caption("CHAMBER %02d/03  //  SWEEPING RELAY ACQUIRED" % [index + 1])
		await _frames(FPS)
		if not await _shoot_relay(relay):
			push_error("CAPTURE_FAILED relay %d survived three real rounds" % index)
			get_tree().quit(1)
			return
		_caption("RELAY %02d DARK  //  SERVICE RING %d/3" % [index + 1, index + 1])
		await _frames(FPS)

	_caption("SERVICE RING CUT LOOSE  //  CELLOUTZ RESPONSE ESCALATED")
	await _frames(FPS * 2)
	var liberated := str(FACILITY.sector("service_ring").state) == FACILITY.LIBERATED
	print("SERVICE_RING_CAPTURE_RESULT liberated=", liberated, " rounds=", WorldHistory.event_count("derby_shot_landed"))
	get_tree().quit(0 if liberated else 1)
