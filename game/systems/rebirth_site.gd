class_name RebirthSite
extends Node3D

## A place that can kill you (Greg, 24 September: every killer in minutes 0-30
## sends you to the vat, not just Hollis). The service arcade built this by
## hand for Hollis's door; this is the same thing any scene can add: your old
## bodies lie where they fell here, E next to one takes back what it holds,
## and `die()` files the death with `VatRebirth` and sends you to the vat of
## whoever claims you.

const VAT_REBIRTH := preload("res://systems/vat_rebirth.gd")
const REACH := 2.2

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
		var tag := Label3D.new()
		tag.text = "YOUR OLD BODY"
		tag.font_size = 30
		tag.outline_size = 8
		tag.modulate = Color("d9c3a4")
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = body.position + Vector3(0, 0.9, 0)
		add_child(tag)
		_bodies[str(remains.id)] = [body, tag]
		if int(remains.get("blood_fragments", 0)) > 0 and not bool(remains.get("sigil_lost", false)):
			_build_sigil(str(remains.id), body.position + Vector3(0, 0.35, 0))


func _build_sigil(remains_id: String, at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "BloodSigil_%s" % remains_id
	root.position = at
	add_child(root)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("5f110c")
	material.emission_enabled = true
	material.emission = Color("b53a22")
	material.emission_energy_multiplier = 2.2
	material.roughness = 0.38
	# Three wet lobes read as an organ at a glance; the copper ring makes it a
	# recovery mark rather than another loose gore chunk.
	for offset in [Vector3(-0.18, 0, 0), Vector3(0.18, 0, 0), Vector3(0, 0.12, 0.08)]:
		var lobe := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.24
		sphere.height = 0.42
		sphere.material = material
		lobe.mesh = sphere
		lobe.position = offset
		lobe.scale = Vector3(1.0, 0.78, 0.72)
		root.add_child(lobe)
	var light := OmniLight3D.new()
	light.light_color = Color("c34828")
	light.light_energy = 1.8
	light.omni_range = 2.8
	root.add_child(light)
	_sigils[remains_id] = root


func _process(delta: float) -> void:
	_pulse += delta
	for remains_id: String in _sigils.keys():
		var sigil: Node3D = _sigils[remains_id]
		if not is_instance_valid(sigil):
			_sigils.erase(remains_id)
			continue
		var distance := player.global_position.distance_to(sigil.global_position) if player != null else 99.0
		var near := clampf(1.0 - distance / 12.0, 0.0, 1.0)
		var beat := pow(maxf(0.0, sin(_pulse * lerpf(2.5, 5.2, near))), 8.0)
		sigil.scale = Vector3.ONE * (1.0 + beat * 0.16)
		var light := sigil.get_child(sigil.get_child_count() - 1) as OmniLight3D
		light.light_energy = 1.2 + near * 1.8 + beat * 2.4


## The old body within reach, if any.
func nearest() -> String:
	if player == null:
		return ""
	for remains_id: String in _bodies:
		var body: Node3D = _bodies[remains_id][0]
		var gap := body.global_position - player.global_position
		gap.y = 0.0
		if gap.length() <= REACH and str((_bodies[remains_id][1] as Label3D).text) != "STRIPPED":
			return remains_id
	return ""


## E beside an old body: take back what it holds. Returns the prompt line, or
## "" when nothing was in reach.
func try_recover() -> String:
	var remains_id := nearest()
	if remains_id.is_empty():
		return ""
	var result := VAT_REBIRTH.recover(remains_id)
	if not bool(result.get("ok", false)):
		return ""
	(_bodies[remains_id][1] as Label3D).text = "STRIPPED"
	if _sigils.has(remains_id):
		(_sigils[remains_id] as Node3D).queue_free()
		_sigils.erase(remains_id)
	return "RECOVERED // %d THINGS // %d BLOOD FRAGMENTS" % [int(result.get("items", 0)), int(result.get("blood_fragments", 0))]


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
