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
	return "TAKEN BACK OFF YOUR OLD BODY // %d THINGS" % int(result.get("items", 0))


## You died here. Everything carried and worn stays on this body.
func die(cause: String, killed_by: String) -> Dictionary:
	if died:
		return rebirth_request
	died = true
	var at := player.global_position if player != null else Vector3.ZERO
	at.y = 0.0
	rebirth_request = VAT_REBIRTH.die(location, cause, killed_by, at)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.get_environment("ATG_TEST_MODE") != "1":
		Interstitial.travel(str(rebirth_request.scene), "you died // %s grows you back" % str(rebirth_request.vat.label).to_lower())
	return rebirth_request
