extends Node

## A scripted trailer. Drives the Hunt Grounds through the game's mechanics in
## order and holds each beat long enough to read, so the whole thing can be
## recorded with Godot's movie writer:
##
##   Godot --path game --fixed-fps 30 --write-movie <out.avi> \
##         res://tests/trailer.tscn
##
## Nothing here is faked for the camera. Every beat calls the same functions the
## player's input calls, so if a mechanic is broken the trailer shows it broken.

const CARD := preload("res://systems/celloutz_type.gd")

var scene: Node
var overlay: Control
var caption := ""
var subcaption := ""
var card_blend := 0.0
var card_target := 0.0
var clock := 0.0


func _ready() -> void:
	scene = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(scene)
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_card)
	layer.add_child(overlay)
	_run()


func _process(delta: float) -> void:
	clock += delta
	card_blend = move_toward(card_blend, card_target, delta * 3.2)
	overlay.queue_redraw()


func _draw_card() -> void:
	var size := overlay.size
	if card_blend <= 0.01 or caption.is_empty():
		return
	var band := Rect2(0, size.y - 138.0, size.x, 96.0)
	overlay.draw_rect(band, Color(0.02, 0.03, 0.026, 0.72 * card_blend))
	overlay.draw_line(band.position, band.position + Vector2(size.x, 0), Color("b4da48") * Color(1, 1, 1, 0.55 * card_blend), 1.0)
	CARD.draw_stamped(overlay, Vector2(64, band.position.y + 22), caption, 30.0, Color("b4da48") * Color(1, 1, 1, card_blend), Color("c81f16") * Color(1, 1, 1, 0.3 * card_blend), 4.0)
	if not subcaption.is_empty():
		overlay.draw_string(ThemeDB.fallback_font, Vector2(66, band.position.y + 76), subcaption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 130, 15, Color("dce6ba") * Color(1, 1, 1, 0.75 * card_blend))


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _say(line: String, under: String, frames: int) -> void:
	caption = line
	subcaption = under
	card_target = 1.0
	await _hold(frames)
	card_target = 0.0
	await _hold(14)


func _walk(steps: int, step: Vector3) -> void:
	for _index in steps:
		scene.player_body.position += step
		scene.player = scene.player_body.position + Vector3.UP * 0.6
		await get_tree().physics_frame


func _spawn(tag: String, offset: Vector3) -> Dictionary:
	var at: Vector3 = scene.player + offset
	scene._spawn_encounter_actor({"instance_id": tag, "kind": "hostile"}, at)
	var actor: Dictionary = scene.encounter_actors.back()
	actor.node.position = at
	await get_tree().physics_frame
	return actor


func _run() -> void:
	await _hold(40)
	scene.yaw = 2.7
	await _say("WIZARDS ONLY FOOLS", "A CELLOUTZ WORLD  //  THE ASHBLOOM EXPANSE", 70)

	# --- the world, and a body in it -------------------------------------
	await _say("EVERY PERSON RUNS ONE RIG", "zones, organs, bones, blood — the player included", 40)
	await _walk(46, Vector3(-0.36, 0, -0.18))

	# --- lock on ----------------------------------------------------------
	var mark := await _spawn("trailer_mark", Vector3(sin(scene.yaw), 0, cos(scene.yaw)) * 5.0)
	scene._toggle_lock()
	await _say("LOCK ON", "Z or middle mouse — the locked target wins the strike", 60)

	# --- melee, and the wound lands where you aimed ------------------------
	for swing in 3:
		scene.pitch = 0.22
		scene._attack_nearest_encounter_actor({"damage": 26.0, "impulse": 14.0, "damage_type": "cut", "range": 9.0, "weapon": "cleaver"})
		await _hold(16)
	await _say("AIM DECIDES THE WOUND", "where you look is what you open", 50)

	# --- gore that stays --------------------------------------------------
	for blow in 6:
		mark.rig.hit("torso", 24.0, 12.0, "cut")
		await _hold(6)
	await _say("THE FLOOR REMEMBERS", "blood lands on what it hits and stays there", 55)

	# --- the clinch -------------------------------------------------------
	var held := await _spawn("trailer_clinch", Vector3(sin(scene.yaw), 0, cos(scene.yaw)) * 1.5)
	scene.stamina = 100.0
	scene._start_grapple()
	await _say("THE CLINCH", "a stamina contest you can lose", 40)
	for press in 90:
		scene.grapple_advantage += 0.02
		scene._update_grapple(0.05)
		if scene.grapple_target.is_empty():
			break
		await get_tree().physics_frame

	# --- the downed window ------------------------------------------------
	scene.player = (held.node as Node3D).global_position - Vector3(0, 0, 1.4)
	scene.player_body.position = scene.player - Vector3.UP * 0.6
	await get_tree().physics_frame
	scene._interact()
	await _say("DOWNED, NOT DEAD", "execute · spare · recruit — and the world records which", 80)

	# --- execution and the anatomical kill cam -----------------------------
	scene.resolution_ui._choose(0)
	await _say("THE KILL CAM READS THE REAL BODY", "the organs it ruptures are the ones you ruined", 90)
	await _hold(40)

	# --- the index: rain, rank, the body ----------------------------------
	scene._toggle_panel("index")
	await _say("THE WORLD INDEX", "everything printed is pointable", 70)
	scene._toggle_panel("index")

	# --- the map ----------------------------------------------------------
	scene._toggle_panel("map")
	await _say("THE MAP IS SURVEYED, NOT GIVEN", "walking is what charts it", 70)
	scene._toggle_panel("map")

	await _say("WIZARDS ONLY FOOLS", "wizardsonlyfoolz  //  celloutz.xyz", 80)
	await _hold(30)
	get_tree().quit()
