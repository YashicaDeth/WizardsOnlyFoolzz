class_name RebirthSite
extends Node3D

## A place that can kill you (Greg, 24 September: every killer in minutes 0-30
## sends you to the vat, not just Hollis). The service arcade built this by
## hand for Hollis's door; this is the same thing any scene can add: your old
## bodies lie where they fell here, E next to one takes back what it holds,
## and `die()` files the death with `VatRebirth` and sends you to the vat of
## whoever claims you.

const VAT_REBIRTH := preload("res://systems/vat_rebirth.gd")
const SIGHT_AUDIO := preload("res://systems/sight_audio.gd")
const REACH := 2.2
const SIGIL_RECOVER_REACH := 1.05

signal recovered(remains_id: String, result: Dictionary, message: String)

var location := ""
var player: Node3D
var died := false
var rebirth_request: Dictionary = {}
var _bodies: Dictionary = {}
var _sigils: Dictionary = {}
var _pulse := 0.0


func setup(location_id: String, player_node: Node3D) -> void:
	location = location_id
	player = player_node
	name = "RebirthSite"
	for remains in VAT_REBIRTH.remains_at(location):
		var body := BaselineHuman.new()
		body.name = str(remains.id)
		add_child(body)
		body.build(str(remains.id), {"flesh": Color("6b5842"), "variation": int(remains.get("body_number", 1))})
		body.position = VAT_REBIRTH.remains_position(remains)
		body.anatomy.dead = true
		body.rotation.x = -PI * 0.46
		_bodies[str(remains.id)] = [body, null]
		if int(remains.get("blood_fragments", 0)) > 0 and not bool(remains.get("sigil_lost", false)):
			_build_sigil(str(remains.id), body.position + Vector3(0, 0.07, 0))


func _build_sigil(remains_id: String, at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "BloodSigil_%s" % remains_id
	root.position = at
	add_child(root)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("3b0908")
	material.emission_enabled = true
	material.emission = Color("54120c")
	material.emission_energy_multiplier = 0.55
	material.roughness = 0.26
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color("6d321b")
	copper.metallic = 0.72
	copper.roughness = 0.34
	copper.emission_enabled = true
	copper.emission = Color("6e2415")
	copper.emission_energy_multiplier = 0.35
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.32
	torus.outer_radius = 0.40
	torus.material = copper
	ring.mesh = torus
	ring.scale.y = 0.18
	root.add_child(ring)
	# Three wet lobes read as an organ at a glance; the copper ring makes it a
	# recovery mark rather than another loose gore chunk.
	for offset in [Vector3(-0.10, 0.035, 0), Vector3(0.10, 0.035, 0), Vector3(0, 0.055, 0.08)]:
		var lobe := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.22
		sphere.material = material
		lobe.mesh = sphere
		lobe.position = offset
		lobe.scale = Vector3(1.0, 0.64, 0.72)
		root.add_child(lobe)
	var light := OmniLight3D.new()
	light.light_color = Color("c34828")
	light.light_energy = 1.8
	light.omni_range = 2.8
	root.add_child(light)
	# The recovery mark calls from beyond the reach of its small glow. The
	# positional pulse accelerates as the player closes in, making it something
	# found by ear instead of another HUD waypoint.
	var heart := AudioStreamPlayer3D.new()
	heart.name = "Heartbeat"
	heart.stream = SIGHT_AUDIO.stream("heartbeat")
	heart.volume_db = -14.0
	heart.bus = "SFX"
	heart.max_distance = 18.0
	heart.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	heart.autoplay = true
	root.add_child(heart)
	_sigils[remains_id] = root


func _process(delta: float) -> void:
	_pulse += delta
	var touched := ""
	for remains_id: String in _sigils.keys():
		var sigil: Node3D = _sigils[remains_id]
		if not is_instance_valid(sigil):
			_sigils.erase(remains_id)
			continue
		var distance := player.global_position.distance_to(sigil.global_position) if player != null else 99.0
		var near := clampf(1.0 - distance / 12.0, 0.0, 1.0)
		var beat := pow(maxf(0.0, sin(_pulse * lerpf(2.5, 5.2, near))), 8.0)
		sigil.scale = Vector3.ONE * (1.0 + beat * 0.16)
		# Heartbeat is the last child, so the light precedes it.
		var light := sigil.get_child(sigil.get_child_count() - 2) as OmniLight3D
		light.light_energy = 1.2 + near * 1.8 + beat * 2.4
		var heart := sigil.get_node("Heartbeat") as AudioStreamPlayer3D
		heart.pitch_scale = lerpf(0.82, 1.42, near)
		heart.volume_db = lerpf(-16.0, -3.0, near)
		if player != null and distance <= SIGIL_RECOVER_REACH:
			touched = remains_id
	if not touched.is_empty():
		recover(touched)


## The old body within reach, if any.
func nearest() -> String:
	if player == null:
		return ""
	for remains_id: String in _bodies:
		var body: Node3D = _bodies[remains_id][0]
		var tag := _bodies[remains_id][1] as Label3D
		var gap := body.global_position - player.global_position
		gap.y = 0.0
		var stripped := bool(body.get_meta("stripped", false)) or (tag != null and tag.text == "STRIPPED")
		if gap.length() <= REACH and not stripped:
			return remains_id
	return ""


## E beside an old body: take back what it holds. Returns the prompt line, or
## "" when nothing was in reach.
func try_recover() -> String:
	var remains_id := nearest()
	if remains_id.is_empty():
		return ""
	var result := recover(remains_id)
	return str(result.get("message", ""))


## Recover one exact body. Walking through its sigil and the legacy interact
## prompt share this path, so neither can duplicate the persistent reward.
func recover(remains_id: String) -> Dictionary:
	var result := VAT_REBIRTH.recover(remains_id)
	if not bool(result.get("ok", false)):
		return result
	var body := _bodies[remains_id][0] as Node3D
	var tag := _bodies[remains_id][1] as Label3D
	body.set_meta("stripped", true)
	if tag != null:
		tag.text = "STRIPPED"
	if _sigils.has(remains_id):
		(_sigils[remains_id] as Node3D).queue_free()
		_sigils.erase(remains_id)
	var message := "RECOVERED // %d THINGS // %d BLOOD FRAGMENTS" % [int(result.get("items", 0)), int(result.get("blood_fragments", 0))]
	result["message"] = message
	recovered.emit(remains_id, result, message)
	return result


## You died here. Everything carried and worn stays on this body.
func die(cause: String, killed_by: String) -> Dictionary:
	if died:
		return rebirth_request
	died = true
	var at := player.global_position if player != null else Vector3.ZERO
	at.y = 0.0
	rebirth_request = VAT_REBIRTH.die(location, cause, killed_by, at)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Greg's playtest: a beat to know you died, of what, and what now.
	preload("res://systems/death_beat.gd").play(self, rebirth_request, cause)
	return rebirth_request
