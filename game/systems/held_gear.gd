class_name HeldGear
extends Node3D

## What is actually in your hands, in first person.
##
## Greg: *"the sword and gun models and hand first person still needs
## enhancing"*, and then the specific of it: *"holding fists halfsword and
## holding it like swords correctly and well modelled"*.
##
## What was there: `hunter_arsenal._build_weapon_model` built each weapon out of
## three `BoxMesh` primitives and parented them to the *upper arm box* of the
## anatomy rig. There were no hands in the game at all. A sword was a box on a
## box on a box, held by nothing, and every note in `ART-DIRECTION.md` about the
## world reading as made rather than assembled was being contradicted by the one
## object that is on screen every single frame.
##
## So: real geometry, and real hands holding it.
##
## **Geometry.** Swept cross-sections, not boxes. A blade has a spine, a taper
## and one edge, and it is swept from a five-point section so the edge is an
## actual edge — which is what makes it catch light along its length instead of
## reading as a painted plank. `BodyMesh.revolve` already existed for the
## anatomy and does the round parts; the swept sections here do the flat ones.
##
## **Hands.** A palm and five fingers with three joints each, curled by a pose
## table. That is the cheapest thing that can grip differently depending on what
## it is holding, and gripping differently is the entire request: a fist is not
## a sword grip is not a trigger finger.
##
## **Half-swording.** The off hand leaves the grip and takes hold of the blade
## itself, halfway up. It is a real technique — the way you fight an armoured
## man with a sword, because a cut will not go through plate and a thrust guided
## by two hands will find a gap — and it is in the request by name. Mechanically
## it is a different grip, a different reach and a different damage type, and
## `GRIPS` below is where that lives.

## Every way the hands can be arranged. The weapon exposes anchors; a grip says
## which hand goes on which anchor and how each one closes.
##
## `rest` is where the whole rig sits in the frame for that grip, because a
## fighting stance is not a property of the hands alone — fists come up in front
## of your face and a longsword does not, and posing only the fingers leaves the
## fists framed for a weapon that is not there.
##
## `reach` and `damage_type` are here rather than on the weapon because they are
## properties of *how it is being held*. Half-swording shortens your reach and
## turns a cut into a thrust, and that is the whole reason anybody ever did it.
## AN2.5. `control` is the number this comment already asked for and nothing
## ever read: how steady the arm carrying this grip is, as a multiplier on
## `LimbMomentum`'s own stiffness. Two hands brace each other, which is why a
## longsword held in one is wilder than the same sword held in two; half-
## swording is the most controlled grip in the table for the same reason a
## thrust needs to be — it is how the technique finds a gap in plate at all.
## Swinging by the blade is the opposite: an improvised hammer, held nowhere
## it was meant to be held.
const GRIPS := {
	"fists": {
		"right": {"anchor": "", "pose": "fist"},
		"left": {"anchor": "", "pose": "fist"},
		"rest": {"at": Vector3(0.030, -0.150, -0.300), "turn": Vector3(0.18, 0.0, 0.0)},
		"reach": 0.55, "damage_type": "blunt", "control": 1.0,
	},
	"one_hand": {
		"right": {"anchor": "grip", "pose": "wrap"},
		"left": {"anchor": "", "pose": "open"},
		"rest": {"at": Vector3(0.205, -0.255, -0.225), "turn": Vector3(0.52, 0.34, 0.30)},
		"reach": 1.0, "damage_type": "cut", "control": 0.82,
	},
	"two_hand": {
		"right": {"anchor": "grip", "pose": "wrap"},
		"left": {"anchor": "grip_low", "pose": "wrap"},
		"rest": {"at": Vector3(0.135, -0.300, -0.245), "turn": Vector3(0.56, 0.20, 0.24)},
		"reach": 1.0, "damage_type": "cut", "control": 1.15,
	},
	"half_sword": {
		"right": {"anchor": "grip", "pose": "wrap"},
		# The off hand on the blade itself. Flatter than a grip wrap, because
		# you are pinching a flat edge rather than closing round a handle, and
		# in period you would be wearing a glove to do it.
		"left": {"anchor": "blade_grip", "pose": "pinch"},
		"rest": {"at": Vector3(0.055, -0.215, -0.290), "turn": Vector3(0.16, 0.10, 0.08)},
		"reach": 0.62, "damage_type": "puncture", "control": 1.35,
	},
	"murder_stroke": {
		# Held by the blade, swung as a hammer. The pommel is the head. It is
		# the other half of the same fight and it is why the pommel is modelled
		# as a mass rather than as a cap.
		"right": {"anchor": "blade_grip", "pose": "wrap"},
		"left": {"anchor": "blade_high", "pose": "wrap"},
		"rest": {"at": Vector3(0.150, -0.195, -0.250), "turn": Vector3(1.05, 0.26, 0.42)},
		"reach": 0.72, "damage_type": "blunt", "control": 0.75,
	},
	"pistol": {
		"right": {"anchor": "grip", "pose": "trigger"},
		"left": {"anchor": "grip_support", "pose": "cup"},
		"rest": {"at": Vector3(0.090, -0.185, -0.245), "turn": Vector3(0.04, 0.20, 0.04)},
		"reach": 1.0, "damage_type": "ballistic", "control": 1.0,
	},
	"long_gun": {
		"right": {"anchor": "grip", "pose": "trigger"},
		"left": {"anchor": "forend", "pose": "wrap"},
		"rest": {"at": Vector3(0.105, -0.200, -0.215), "turn": Vector3(0.05, 0.26, 0.05)},
		"reach": 1.0, "damage_type": "ballistic", "control": 1.0,
	},
}

## How far each joint of each finger is curled, in radians, per pose. Three
## numbers per finger because a finger has three bones, and a hand that curls
## every joint by the same amount reads as a cartoon glove.
const POSES := {
	"open": {"fingers": [0.06, 0.10, 0.08], "thumb": [0.12, 0.10], "spread": 1.0},
	"fist": {"fingers": [1.52, 1.66, 1.42], "thumb": [0.85, 0.95], "spread": 0.15},
	"wrap": {"fingers": [1.18, 1.34, 0.92], "thumb": [0.62, 0.70], "spread": 0.25},
	# Flatter, and the fingers stay straighter: a blade is a plate, not a rod.
	"pinch": {"fingers": [0.92, 1.48, 0.55], "thumb": [0.95, 0.35], "spread": 0.35},
	# A cigarette sits between long, splayed fingers with the palm open toward
	# the player. Closing the other two into a fist made the object look gripped
	# like a tool; this is the loose fan visible in the player's reference pose.
	"smoke": {"fingers": [0.38, 0.52, 0.24], "thumb": [0.24, 0.14], "spread": 1.18,
		"index": [0.16, 0.24, 0.11], "middle": [0.22, 0.31, 0.14],
		"ring": [0.30, 0.42, 0.19], "little": [0.52, 0.68, 0.31]},
	# The Zippo needs a thumb at the wheel and an index curled around its far
	# shoulder, not the same four-finger cylinder grip used on a sword handle.
	"lighter": {"fingers": [1.06, 1.30, 0.82], "thumb": [0.28, 0.18], "spread": 0.32,
		"index": [0.66, 0.82, 0.42]},
	# Index out, everything else closed. The one pose a player will notice is
	# wrong, because it is the finger that does the thing.
	"trigger": {"fingers": [1.30, 1.46, 1.20], "thumb": [0.70, 0.55], "spread": 0.20,
		"index": [0.42, 0.30, 0.22]},
	"cup": {"fingers": [0.78, 0.62, 0.40], "thumb": [0.35, 0.30], "spread": 0.55},
}

const FINGERS := ["index", "middle", "ring", "little"]
## Base length per finger and where it sits across the knuckles. A hand whose
## fingers are all the same length is the other thing that reads as a glove.
const FINGER_SHAPE := {
	"index": {"length": 0.074, "across": -0.026, "forward": 0.004, "girth": 0.0105},
	"middle": {"length": 0.080, "across": -0.008, "forward": 0.006, "girth": 0.0110},
	"ring": {"length": 0.073, "across": 0.010, "forward": 0.003, "girth": 0.0100},
	"little": {"length": 0.059, "across": 0.026, "forward": -0.004, "girth": 0.0086},
}

var right_hand: Node3D
var left_hand: Node3D
var weapon: Node3D
var grip := "fists"

var _anchors: Dictionary = {}
var _flesh := Color("8a6a55")


# ------------------------------------------------------------------- the hands
## A hand. Palm, four fingers of three bones each, and a thumb that comes off
## the side of the palm rather than out of the end of it.
##
## `side` is -1 for left and 1 for right; the whole hand is mirrored on X, which
## is correct for a hand and is the reason the thumb ends up on the right side
## of one and the left side of the other without a second model.
static func build_hand(side: int, flesh := Color("8a6a55")) -> Node3D:
	var root := Node3D.new()
	root.name = "LeftHand" if side < 0 else "RightHand"
	var mirror := -1.0 if side < 0 else 1.0

	var palm := MeshInstance3D.new()
	palm.name = "palm"
	# Swept, not boxed: a palm is thicker at the knuckles than at the wrist and
	# thicker on the thumb side than on the little-finger side.
	palm.mesh = _sweep([
		{"at": 0.0, "width": 0.070, "depth": 0.030},
		{"at": 0.030, "width": 0.079, "depth": 0.034},
		{"at": 0.062, "width": 0.084, "depth": 0.032},
		{"at": 0.086, "width": 0.080, "depth": 0.026},
	], 0.30)
	palm.material_override = _skin(flesh, 3)
	root.add_child(palm)

	var wrist := MeshInstance3D.new()
	wrist.name = "wrist"
	wrist.mesh = BodyMesh.revolve([
		Vector3(-0.052, 0.030, 0.023),
		Vector3(-0.020, 0.032, 0.025),
		Vector3(0.004, 0.035, 0.027),
	], 10)
	wrist.rotation.z = PI * 0.5
	wrist.material_override = _skin(flesh.darkened(0.08), 7)
	root.add_child(wrist)

	for finger_name: String in FINGERS:
		var shape: Dictionary = FINGER_SHAPE[finger_name]
		var knuckle := Node3D.new()
		knuckle.name = finger_name
		knuckle.position = Vector3(float(shape.across) * mirror, float(shape.forward), 0.086)
		root.add_child(knuckle)
		_build_finger(knuckle, float(shape.length), float(shape.girth), flesh, finger_name.hash())

	var thumb := Node3D.new()
	thumb.name = "thumb"
	thumb.position = Vector3(-0.038 * mirror, 0.004, 0.030)
	thumb.rotation = Vector3(0.0, -0.62 * mirror, -0.85 * mirror)
	root.add_child(thumb)
	_build_finger(thumb, 0.062, 0.0125, flesh, 991, 2)
	return root


## The hunter's hands are issued costume, not bare skin. The ruling elite's
## joke is a black-wine glove forced through an oversized fool's cuff: readable
## in first person, humiliating in third, and large enough that the articulated
## fingers stop looking like detached doll hands beside a full-size weapon.
static func build_humiliation_hand(side: int) -> Node3D:
	var hand := build_hand(side, Color("3b2029"))
	hand.scale = Vector3.ONE * 1.16
	hand.set_meta("screen_entry_side", side)
	for child in hand.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = _glove(Color("28151e"), 70 + side)

	var cuff := Node3D.new()
	cuff.name = "HumiliationCuff"
	cuff.position.z = -0.030
	hand.add_child(cuff)
	# Six stuffed lobes make the silhouette deliberately theatrical instead of
	# reading as a tiny naked wrist. Bone and dried-blood alternate like a rank
	# the wearer never chose.
	for index in 6:
		var angle := TAU * float(index) / 6.0
		var puff := MeshInstance3D.new()
		puff.name = "CuffPuff%d" % index
		var puff_mesh := SphereMesh.new()
		puff_mesh.radius = 0.024
		puff_mesh.height = 0.040
		puff_mesh.radial_segments = 10
		puff_mesh.rings = 6
		puff.mesh = puff_mesh
		puff.position = Vector3(cos(angle) * 0.037, sin(angle) * 0.037, 0.0)
		puff.scale = Vector3(1.0, 1.0, 0.82)
		puff.material_override = _glove(Color("651d2a") if index % 2 == 0 else Color("c6ae7a"), 90 + index)
		cuff.add_child(puff)

	var shackle := MeshInstance3D.new()
	shackle.name = "CuffShackle"
	var shackle_mesh := TorusMesh.new()
	shackle_mesh.inner_radius = 0.031
	shackle_mesh.outer_radius = 0.044
	shackle_mesh.rings = 12
	shackle_mesh.ring_segments = 8
	shackle.mesh = shackle_mesh
	shackle.rotation.x = PI * 0.5
	shackle.position.z = -0.015
	shackle.material_override = _metal(Color("655d55"), 0.32, 113 + side)
	cuff.add_child(shackle)

	for side_step in [-1.0, 1.0]:
		var bell := MeshInstance3D.new()
		bell.name = "CuffBell"
		var bell_mesh := SphereMesh.new()
		bell_mesh.radius = 0.008
		bell_mesh.height = 0.014
		bell.mesh = bell_mesh
		bell.position = Vector3(side_step * 0.035, -0.030, -0.018)
		bell.material_override = _metal(Color("a7772d"), 0.24, 121 + int(side_step))
		cuff.add_child(bell)

	# The hand is never a floating viewmodel. A tapered costumed forearm carries
	# it back out through the bottom-left or bottom-right of the frame. Keeping it
	# under the hand means every smoking, lighter, weapon and inspection pose
	# inherits one continuous limb without each prop inventing an arm.
	var forearm := Node3D.new()
	forearm.name = "FirstPersonForearm"
	hand.add_child(forearm)
	var sleeve := MeshInstance3D.new()
	sleeve.name = "TaperedSleeve"
	var sleeve_mesh := CylinderMesh.new()
	sleeve_mesh.top_radius = 0.052
	sleeve_mesh.bottom_radius = 0.078
	sleeve_mesh.height = 0.36
	sleeve_mesh.radial_segments = 12
	sleeve.mesh = sleeve_mesh
	# Authored along +Y so the live view can stretch it exactly from a lower
	# screen edge to the wrist without guessing through the prop's rotations.
	sleeve.position = Vector3(0.0, 0.18, 0.0)
	sleeve.material_override = _glove(Color("40121e"), 140 + side)
	forearm.add_child(sleeve)
	# A broad entry puff hides the far cap at the screen edge and makes the arm
	# widen toward the unseen elbow instead of ending as a cut-off tube.
	for index in 4:
		var angle := TAU * float(index) / 4.0
		var entry_puff := MeshInstance3D.new()
		entry_puff.name = "EntryPuff%d" % index
		var entry_mesh := SphereMesh.new()
		entry_mesh.radius = 0.052
		entry_mesh.height = 0.086
		entry_mesh.radial_segments = 10
		entry_mesh.rings = 6
		entry_puff.mesh = entry_mesh
		entry_puff.position = Vector3(cos(angle) * 0.040, 0.018, sin(angle) * 0.040)
		entry_puff.material_override = _glove(Color("651d2a") if index % 2 == 0 else Color("c6ae7a"), 150 + index)
		forearm.add_child(entry_puff)
	return hand


static func _build_finger(parent: Node3D, length: float, girth: float, flesh: Color, seed_value: int, bones := 3) -> void:
	# Each bone hangs off the end of the one before it, so curling a knuckle
	# carries everything past it round with the joint — which is what a finger
	# does and what a chain of siblings cannot do.
	var shares := [0.44, 0.33, 0.23] if bones == 3 else [0.58, 0.42]
	var joint := parent
	var carried := 0.0
	for index in bones:
		var bone := Node3D.new()
		bone.name = "bone%d" % index
		bone.position = Vector3(0, 0, carried)
		joint.add_child(bone)
		var piece_length := length * float(shares[index])
		var taper := 1.0 - 0.16 * float(index)
		var visual := MeshInstance3D.new()
		visual.name = "pad%d" % index
		visual.mesh = BodyMesh.revolve([
			Vector3(0.0, girth * taper * 0.92, girth * taper * 0.86),
			Vector3(piece_length * 0.45, girth * taper, girth * taper * 0.94),
			Vector3(piece_length, girth * taper * 0.80, girth * taper * 0.74),
		], 8)
		# `revolve` sweeps along X; a finger points along Z.
		visual.rotation.y = -PI * 0.5
		visual.material_override = _skin(flesh.lightened(0.03 * float(index)), seed_value + index)
		bone.add_child(visual)
		joint = bone
		carried = piece_length


## Close a hand into one of `POSES`. Cheap enough to call every frame, which is
## what lets a grip change be animated rather than swapped.
static func set_pose(hand: Node3D, pose_name: String, blend := 1.0) -> void:
	if hand == null or not is_instance_valid(hand):
		return
	var pose: Dictionary = POSES.get(pose_name, POSES["open"])
	var curls: Array = pose["fingers"]
	var spread := float(pose.get("spread", 0.5))
	for index in FINGERS.size():
		var finger_name: String = FINGERS[index]
		var knuckle := hand.get_node_or_null(NodePath(finger_name)) as Node3D
		if knuckle == null:
			continue
		var own: Array = pose.get(finger_name, curls)
		# Fingers splay when the hand opens and close together when it grips.
		var fan := (float(index) - 1.5) * 0.09 * spread
		_curl(knuckle, own, blend, fan)
	var thumb := hand.get_node_or_null("thumb") as Node3D
	if thumb != null:
		_curl(thumb, pose.get("thumb", [0.4, 0.4]), blend, 0.0)


## Interpolate between two authored grips rather than fading a target grip from
## a mathematically straight hand. Inspection uses this when a support hand
## leaves its firing contact to pinch a slide, feel a receiver or trace an edge.
static func blend_pose(hand: Node3D, from_name: String, to_name: String, weight: float) -> void:
	if hand == null or not is_instance_valid(hand):
		return
	var from_pose: Dictionary = POSES.get(from_name, POSES["open"])
	var to_pose: Dictionary = POSES.get(to_name, POSES["open"])
	var amount := clampf(weight, 0.0, 1.0)
	var from_default: Array = from_pose["fingers"]
	var to_default: Array = to_pose["fingers"]
	var spread := lerpf(float(from_pose.get("spread", 0.5)), float(to_pose.get("spread", 0.5)), amount)
	for index in FINGERS.size():
		var finger_name: String = FINGERS[index]
		var knuckle := hand.get_node_or_null(NodePath(finger_name)) as Node3D
		if knuckle == null:
			continue
		var from_curl: Array = from_pose.get(finger_name, from_default)
		var to_curl: Array = to_pose.get(finger_name, to_default)
		var curls: Array = []
		for joint in mini(from_curl.size(), to_curl.size()):
			curls.append(lerpf(float(from_curl[joint]), float(to_curl[joint]), amount))
		var fan := (float(index) - 1.5) * 0.09 * spread
		_curl(knuckle, curls, 1.0, fan)
	var thumb := hand.get_node_or_null("thumb") as Node3D
	if thumb != null:
		var from_thumb: Array = from_pose.get("thumb", [0.4, 0.4])
		var to_thumb: Array = to_pose.get("thumb", [0.4, 0.4])
		var thumb_curls: Array = []
		for joint in mini(from_thumb.size(), to_thumb.size()):
			thumb_curls.append(lerpf(float(from_thumb[joint]), float(to_thumb[joint]), amount))
		_curl(thumb, thumb_curls, 1.0, 0.0)


static func _curl(joint: Node3D, angles: Array, blend: float, fan: float) -> void:
	var cursor := joint
	for index in angles.size():
		var bone := cursor.get_node_or_null("bone%d" % index) as Node3D
		if bone == null:
			return
		var target := -float(angles[index]) * blend
		bone.rotation = Vector3(target, fan if index == 0 else 0.0, 0.0)
		cursor = bone


# ----------------------------------------------------------------- the weapons
## A weapon, with anchors on it saying where a hand can go.
##
## Anchors are `Node3D`s rather than numbers so a grip can be expressed as "the
## off hand goes here" and the geometry stays the authority on where "here" is.
static func build_weapon(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_model" % weapon_id
	match weapon_id:
		"sword": _build_sword(root)
		"shotgun": _build_shotgun(root)
		"sidearm": _build_sidearm(root)
		"breach_nine": _build_breach_nine(root)
		"launcher": _build_launcher(root)
		"shiv": _build_shiv(root)
		"cleaver": _build_hotline_cleaver(root)
		"staff": _build_prodstaff(root)
		_: _build_sword(root)
	# Every part above is authored muzzle-forward along +Z because that is the
	# readable way to write a sweep, and a Godot node's forward is -Z. Turning
	# the assembled weapon once here means the geometry reads naturally in the
	# source and points where the camera looks in the world, and it carries the
	# anchors round with it so a grip cannot disagree with the shape.
	root.rotation.y = PI
	return root


## Sandbox breach launcher: a visibly different, heavy single tube rather than
## an invisible key that detonates the crosshair. It deliberately stays a
## range-only tool until explosive weapons belong in the production loadout.
static func _build_launcher(root: Node3D) -> void:
	var tube := MeshInstance3D.new()
	tube.name = "launch_tube"
	tube.mesh = BodyMesh.revolve([
		Vector3(0.0, 0.052, 0.052),
		Vector3(0.08, 0.060, 0.060),
		Vector3(0.62, 0.060, 0.060),
		Vector3(0.70, 0.068, 0.068),
	], 14)
	tube.rotation.x = PI * 0.5
	tube.position = Vector3(0, 0.015, 0.15)
	tube.material_override = _metal(Color("3f5145"), 0.42, 109)
	root.add_child(tube)

	var sight := MeshInstance3D.new()
	sight.name = "launcher_sight"
	var sight_mesh := BoxMesh.new()
	sight_mesh.size = Vector3(0.018, 0.055, 0.11)
	sight.mesh = sight_mesh
	sight.position = Vector3(0, 0.083, 0.33)
	sight.material_override = _metal(Color("a06b31"), 0.35, 111)
	root.add_child(sight)

	var grip := MeshInstance3D.new()
	grip.name = "launcher_grip"
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.065, 0.15, 0.075)
	grip.mesh = grip_mesh
	grip.position = Vector3(0, -0.075, -0.02)
	grip.rotation.x = 0.22
	grip.material_override = _wood(Color("392a20"), 113)
	root.add_child(grip)

	_anchor(root, "grip", Vector3(0, -0.075, -0.035), Vector3(0.22, 0, 0))
	_anchor(root, "forend", Vector3(0, -0.035, 0.34), Vector3.ZERO)
	_anchor(root, "muzzle", Vector3(0, 0.015, 0.85), Vector3.ZERO)


## The Ashline Cleaver. Single-edged, heavy at the front, a blade that is a
## wedge in section rather than a plank — the spine carries the mass and the
## edge is where it runs out.
## The shiv from the den (Greg, 28 September): a short scrap blade bound to a
## rag-wrapped handle. Built along +Z like the others.
##
## It is the generated model now (art/generated/items/shiv.glb, placed from
## measured axes by GeneratedModel), with the grip where the drawn one had it
## so nothing that reads the anchor moves. The drawn shiv below is the
## fallback for a checkout without the media.
const GENERATED_MODEL := preload("res://systems/generated_model.gd")


static func _build_shiv(root: Node3D) -> void:
	var model := GENERATED_MODEL.make("shiv")
	if model == null:
		_build_shiv_drawn(root)
		return
	model.position = Vector3(0, 0, -0.07)
	root.add_child(model)
	_anchor(root, "grip", Vector3(0, 0, -0.07), Vector3.ZERO)


static func _build_shiv_drawn(root: Node3D) -> void:
	var blade := MeshInstance3D.new()
	blade.name = "blade"
	blade.mesh = _blade(0.2, 0.034, 0.008)
	blade.position = Vector3(0, 0, 0.02)
	blade.material_override = _metal(Color("8c8f86"), 0.4, 23)
	root.add_child(blade)
	var handle := MeshInstance3D.new()
	handle.name = "handle"
	var wrap := BoxMesh.new()
	wrap.size = Vector3(0.03, 0.03, 0.12)
	var rag := StandardMaterial3D.new()
	rag.albedo_color = Color("5b4a36")
	rag.roughness = 0.95
	wrap.material = rag
	handle.mesh = wrap
	handle.position = Vector3(0, 0, -0.07)
	root.add_child(handle)
	_anchor(root, "grip", Vector3(0, 0, -0.07), Vector3.ZERO)


## Remade 4 October (Greg: *"fix the god awful gun and sword models"*). Low,
## readable and faceted, the way a PS2 prop reads at arm's length: every part
## a player can name from the first-person view — blade, fuller, langet,
## recurved guard, wrapped grip with ferrules, a faceted pommel — and nothing
## smaller. Anchors are where they were, so the grips table still fits.
static func _build_sword(root: Node3D) -> void:
	var steel := Color("9aa0a4")
	var copper := Color("8b6040")
	# The cleaver's blade starts just ahead of the guard and widens towards a
	# clipped point: the spine carries the mass, the front is where it bites.
	_part(root, "blade", _cleaver_blade(0.84), Vector3(0, 0, -0.095), _metal(steel, 0.22, 11))
	# A fuller each face, near the spine, as a dark inset strip that dies out
	# two thirds of the way up. Flat faces are ±Y, the edge is +X.
	for side in [-1.0, 1.0]:
		_part(root, "fuller%d" % int(side), _sweep([
			{"at": 0.0, "width": 0.011, "depth": 0.0012},
			{"at": 0.44, "width": 0.010, "depth": 0.0012},
			{"at": 0.50, "width": 0.0, "depth": 0.0006},
		], 0.0, 8), Vector3(-0.014, side * 0.0063, -0.035), _metal(steel.darkened(0.55), 0.40, 4))

	# The guard: a block, a copper langet tongue down the blade, and two
	# quillons recurved towards the edge with a knob on each end.
	_part(root, "guard", _box(Vector3(0.078, 0.026, 0.020)), Vector3(0, 0, -0.100), _metal(copper, 0.34, 21))
	_part(root, "langet", _box(Vector3(0.024, 0.0165, 0.026)), Vector3(0, 0, -0.080), _metal(copper, 0.30, 22))
	for side in [-1.0, 1.0]:
		var quillon := _part(root, "quillon%d" % int(side), _sweep([
			{"at": 0.0, "width": 0.017, "depth": 0.015},
			{"at": 0.070, "width": 0.010, "depth": 0.011},
		], 0.3, 8), Vector3(side * 0.035, 0, -0.100), _metal(copper, 0.34, 23))
		quillon.rotation.y = side * (PI * 0.5 - 0.25)
		var knob := MeshInstance3D.new()
		knob.name = "knob"
		var ball := SphereMesh.new()
		ball.radius = 0.0095
		ball.height = 0.019
		ball.radial_segments = 8
		ball.rings = 4
		knob.mesh = ball
		knob.position = Vector3(0, 0, 0.072)
		knob.material_override = quillon.material_override
		quillon.add_child(knob)

	var handle := _part(root, "grip", BodyMesh.revolve([
		Vector3(0.0, 0.0165, 0.0125),
		Vector3(0.045, 0.0185, 0.0140),
		Vector3(0.110, 0.0170, 0.0130),
		Vector3(0.170, 0.0150, 0.0118),
	], 10), Vector3(0, 0, -0.10), _leather(Color("35261e"), 5))
	# `revolve()` extends along local Y; tipping it on X lays it down the
	# blade's axis, negative because the grip runs back from the guard.
	handle.rotation.x = -PI * 0.5
	# Cord wrap, then a metal ferrule each end so the grip reads as fitted.
	for index in 7:
		var cord := _part(root, "wrap%d" % index, BodyMesh.revolve([
			Vector3(-0.005, 0.0195, 0.0150),
			Vector3(0.005, 0.0195, 0.0150),
		], 10), Vector3(0, 0, -0.130 - float(index) * 0.0195), _leather(Color("241a14"), index))
		cord.rotation.x = -PI * 0.5
	for index in 2:
		var ferrule := _part(root, "ferrule%d" % index, BodyMesh.revolve([
			Vector3(-0.005, 0.0200, 0.0158),
			Vector3(0.005, 0.0200, 0.0158),
		], 8), Vector3(0, 0, [-0.115, -0.264][index]), _metal(copper, 0.30, 31 + index))
		ferrule.rotation.x = -PI * 0.5

	# A mass, not a cap: a pommel is a counterweight, and it is the head of the
	# hammer when the sword is held the other way up. Six facets, on purpose.
	var pommel := _part(root, "pommel", BodyMesh.revolve([
		Vector3(0.0, 0.014, 0.014),
		Vector3(0.012, 0.030, 0.027),
		Vector3(0.030, 0.033, 0.029),
		Vector3(0.048, 0.022, 0.020),
		Vector3(0.056, 0.010, 0.010),
	], 6), Vector3(0, 0, -0.272), _metal(copper, 0.30, 33))
	pommel.rotation.x = -PI * 0.5

	_anchor(root, "grip", Vector3(0, 0, -0.158), Vector3.ZERO)
	_anchor(root, "grip_low", Vector3(0, 0, -0.226), Vector3.ZERO)
	# Halfway up the blade, which is where a hand goes when the cut has stopped
	# being the answer.
	_anchor(root, "blade_grip", Vector3(0, 0, 0.230), Vector3.ZERO)
	_anchor(root, "blade_high", Vector3(0, 0, 0.430), Vector3.ZERO)
	_anchor(root, "muzzle", Vector3(0, 0, 0.740), Vector3.ZERO)


## v0.1 Brawler (job 3). Greg, 5 Oct: "200 years in the future, why would they
## just have an axe" -- a meat-processing cleaver with a heating element down
## the edge, working name HOTLINE CLEAVER. Same axis convention as the sword
## (along +Z, flat faces +-Y, edge +X). The edge strip is its own mesh with
## its own material, named `heat_edge`, so `MeleeDriver` can brighten it as the
## blade takes heat from hits.
static func _build_hotline_cleaver(root: Node3D) -> void:
	var steel := Color("6f7376")
	var housing := _metal(Color("1d1f1e"), 0.55, 61)
	# A wide, square-nosed slab: most of the mass is in the blade, as on a
	# butcher's cleaver, so a light swing still lands heavy.
	_part(root, "blade", _box(Vector3(0.112, 0.006, 0.290)), Vector3(0.026, 0, 0.175), _metal(steel, 0.38, 62))
	# The element housing along the spine, with a cable run back to the grip.
	_part(root, "element_housing", _box(Vector3(0.020, 0.013, 0.270)), Vector3(-0.036, 0, 0.170), housing)
	for index in 6:
		_part(root, "element_rib%d" % index, _box(Vector3(0.022, 0.015, 0.006)),
			Vector3(-0.036, 0, 0.060 + float(index) * 0.044), _metal(Color("3a2b20"), 0.5, 63 + index))
	# The heated edge: a thin strip proud of the blade, lit from inside.
	var edge := _part(root, "heat_edge", _box(Vector3(0.010, 0.0068, 0.284)), Vector3(0.086, 0, 0.175), heat_edge_material())
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The hang hole a cleaver has near its nose, punched through as a dark plug.
	var hole := _part(root, "hang_hole", BodyMesh.revolve([Vector3(-0.004, 0.009, 0.009), Vector3(0.004, 0.009, 0.009)], 10),
		Vector3(0.0, 0, 0.292), _bore())
	# Bolster and an industrial grip: hazard-yellow over black rubber, a
	# battery block for a pommel and a short cable between them.
	_part(root, "bolster", _box(Vector3(0.060, 0.022, 0.026)), Vector3(-0.004, 0, 0.018), _metal(Color("4a4b48"), 0.42, 70))
	var grip := _part(root, "grip", BodyMesh.revolve([
		Vector3(0.0, 0.0175, 0.0135),
		Vector3(0.060, 0.0190, 0.0145),
		Vector3(0.130, 0.0180, 0.0140),
	], 10), Vector3(0, 0, 0.004), _leather(Color("1a1816"), 71))
	grip.rotation.x = -PI * 0.5
	for index in 3:
		var band := _part(root, "band%d" % index, BodyMesh.revolve([
			Vector3(-0.006, 0.0197, 0.0152), Vector3(0.006, 0.0197, 0.0152),
		], 10), Vector3(0, 0, -0.020 - float(index) * 0.042), _leather(Color("b88a1c"), 72 + index))
		band.rotation.x = -PI * 0.5
	_part(root, "battery", _box(Vector3(0.042, 0.034, 0.050)), Vector3(0, 0, -0.152), housing)
	_part(root, "battery_lamp", _box(Vector3(0.010, 0.036, 0.010)), Vector3(0.012, 0, -0.140), _glow(Color("d24a1e")))
	_part(root, "cable", _box(Vector3(0.007, 0.007, 0.170)), Vector3(-0.026, 0.004, -0.050), housing)

	_anchor(root, "grip", Vector3(0, 0, -0.060), Vector3.ZERO)
	_anchor(root, "grip_low", Vector3(0, 0, -0.110), Vector3.ZERO)
	_anchor(root, "muzzle", Vector3(0.030, 0, 0.320), Vector3.ZERO)


## v0.1 Brawler (job 3): a guard's shock staff, working name PRODSTAFF. Reach
## over a sword's, two hands, a forked head that carries the charge. The head
## glow is its own mesh, `shock_tip`, for `MeleeDriver` to flare on a charged
## blow. Most of the length is ahead of the hands; little sits behind them,
## because in first person what is behind the hand is behind the eye.
static func _build_prodstaff(root: Node3D) -> void:
	var shaft_metal := _metal(Color("3c403e"), 0.48, 80)
	var wrap := _leather(Color("1c1a18"), 81)
	var shaft := _part(root, "shaft", BodyMesh.revolve([
		Vector3(-0.52, 0.0150, 0.0150),
		Vector3(1.10, 0.0140, 0.0140),
	], 10), Vector3.ZERO, shaft_metal)
	shaft.rotation.x = PI * 0.5
	# Two rubber grip sleeves where the hands go, and a hazard band between.
	for entry in [[-0.10, 0.20], [-0.46, 0.14]]:
		var sleeve := _part(root, "sleeve", BodyMesh.revolve([
			Vector3(0.0, 0.0185, 0.0185), Vector3(float(entry[1]), 0.0185, 0.0185),
		], 10), Vector3(0, 0, float(entry[0]) - float(entry[1]) * 0.5), wrap)
		sleeve.rotation.x = PI * 0.5
	var band := _part(root, "hazard_band", BodyMesh.revolve([
		Vector3(0.0, 0.0175, 0.0175), Vector3(0.05, 0.0175, 0.0175),
	], 10), Vector3(0, 0, 0.08), _leather(Color("b88a1c"), 82))
	band.rotation.x = PI * 0.5
	# The power collar under the head and its status lamp.
	_part(root, "collar", _box(Vector3(0.050, 0.050, 0.110)), Vector3(0, 0, 0.96), _metal(Color("1d1f1e"), 0.55, 83))
	_part(root, "collar_lamp", _box(Vector3(0.008, 0.052, 0.012)), Vector3(0.022, 0, 0.94), _glow(Color("7fd6e8")))
	# The fork: two prongs either side, a tip between them that lights.
	for side in [-1.0, 1.0]:
		_part(root, "prong", _box(Vector3(0.012, 0.012, 0.150)), Vector3(side * 0.030, 0, 1.085), shaft_metal)
	var tip := MeshInstance3D.new()
	tip.name = "shock_tip"
	var ball := SphereMesh.new()
	ball.radius = 0.016
	ball.height = 0.032
	ball.radial_segments = 10
	ball.rings = 5
	tip.mesh = ball
	tip.position = Vector3(0, 0, 1.13)
	tip.material_override = shock_tip_material()
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tip)
	_part(root, "butt_cap", _box(Vector3(0.036, 0.036, 0.040)), Vector3(0, 0, -0.53), _metal(Color("1d1f1e"), 0.55, 84))

	_anchor(root, "grip", Vector3(0, 0, -0.10), Vector3.ZERO)
	_anchor(root, "grip_low", Vector3(0, 0, -0.46), Vector3.ZERO)
	_anchor(root, "muzzle", Vector3(0, 0, 1.15), Vector3.ZERO)


## Shared so a fresh model and a driver-brightened one start from one look.
static func heat_edge_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("5a2010")
	material.roughness = 0.4
	material.metallic = 0.6
	material.emission_enabled = true
	material.emission = Color("ff5a1a")
	material.emission_energy_multiplier = 0.6
	return material


static func shock_tip_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9fe8ff")
	material.emission_enabled = true
	material.emission = Color("7fd6e8")
	material.emission_energy_multiplier = 1.2
	return material


## The BONE YARD 12G. Pump, box-fed, with a vent rib and a brass bead you can
## actually put on a target: the rear notch sits on the receiver and the bead
## top sits level with it, so `sight_rear` -> `sight_front` is a real line.
static func _build_shotgun(root: Node3D) -> void:
	var gunmetal := Color("53585a")
	var receiver_metal := _metal(gunmetal, 0.30, 13)
	_part(root, "receiver", _sweep([
		{"at": -0.020, "width": 0.048, "depth": 0.064},
		{"at": 0.215, "width": 0.048, "depth": 0.064},
		{"at": 0.228, "width": 0.044, "depth": 0.056},
	], 0.14, 8), Vector3.ZERO, receiver_metal)
	_part(root, "loading_port", _box(Vector3(0.002, 0.022, 0.064)), Vector3(0.0245, 0.004, 0.118), _metal(Color("121413"), 0.5, 14))
	# A copper eye on the left of the receiver: the facility's mark, struck
	# into the steel. The only ornament, and it is on the side you never aim.
	var mark := _part(root, "receiver_mark", BodyMesh.revolve([
		Vector3(0.0, 0.0115, 0.0115), Vector3(0.002, 0.0115, 0.0115), Vector3(0.002, 0.004, 0.004),
	], 8), Vector3(-0.024, 0.0, 0.088), _metal(Color("8b6040"), 0.3, 15))
	mark.rotation.z = PI * 0.5

	# `revolve()` extends along local Y; tipping it on X lays it along +Z.
	var barrel := _part(root, "barrel", BodyMesh.revolve([
		Vector3(0.0, 0.0125, 0.0125),
		Vector3(0.500, 0.0115, 0.0115),
		Vector3(0.500, 0.0135, 0.0135),
		Vector3(0.515, 0.0135, 0.0135),
	], 12), Vector3(0, 0.014, 0.225), _metal(gunmetal.darkened(0.2), 0.24, 17))
	barrel.rotation.x = PI * 0.5
	var bore := _part(root, "bore", BodyMesh.revolve([Vector3(0, 0, 0), Vector3(0, 0.0095, 0.0095)], 12),
		Vector3(0, 0.014, 0.7405), _bore())
	bore.rotation.x = PI * 0.5
	_part(root, "vent_rib", _box(Vector3(0.008, 0.003, 0.490)), Vector3(0, 0.0280, 0.478), _metal(gunmetal.darkened(0.35), 0.4, 18))

	var tube := _part(root, "tube", BodyMesh.revolve([
		Vector3(0.0, 0.0110, 0.0110),
		Vector3(0.400, 0.0110, 0.0110),
		Vector3(0.400, 0.0122, 0.0122),
		Vector3(0.414, 0.0122, 0.0122),
	], 10), Vector3(0, -0.016, 0.225), _metal(gunmetal.darkened(0.3), 0.30, 19))
	tube.rotation.x = PI * 0.5
	_part(root, "barrel_band", _box(Vector3(0.030, 0.052, 0.010)), Vector3(0, -0.001, 0.612), receiver_metal)

	_part(root, "forend", _sweep([
		{"at": 0.0, "width": 0.036, "depth": 0.040},
		{"at": 0.025, "width": 0.040, "depth": 0.044},
		{"at": 0.155, "width": 0.040, "depth": 0.044},
		{"at": 0.180, "width": 0.035, "depth": 0.039},
	], 0.8, 12), Vector3(0, -0.012, 0.250), _wood(Color("4a3325"), 23))
	# Ribs on the pump, because the one part of a shotgun a player looks at in
	# first person is the part their off hand is on.
	for index in 6:
		var rib := _part(root, "rib%d" % index, BodyMesh.revolve([
			Vector3(-0.003, 0.0225, 0.0245),
			Vector3(0.003, 0.0225, 0.0245),
		], 12), Vector3(0, -0.012, 0.282 + float(index) * 0.0225), _wood(Color("2c1d14"), index + 40))
		rib.rotation.x = PI * 0.5

	var grip := _part(root, "grip", _sweep([
		{"at": -0.025, "width": 0.036, "depth": 0.044},
		{"at": 0.060, "width": 0.037, "depth": 0.050},
		{"at": 0.125, "width": 0.034, "depth": 0.045},
	], 0.5), Vector3(0, -0.052, -0.030), _wood(Color("3d2a1e"), 29))
	grip.rotation.x = PI * 0.5 + 0.42

	# The stock runs straight back off the receiver and drops to a butt with
	# a dark recoil pad, instead of starting a hand's width behind the gun.
	var stock := _part(root, "stock", _sweep([
		{"at": 0.0, "width": 0.040, "depth": 0.050},
		{"at": 0.100, "width": 0.042, "depth": 0.066},
		{"at": 0.250, "width": 0.044, "depth": 0.104},
	], 0.4), Vector3(0, -0.006, -0.016), _wood(Color("4a3325"), 31))
	stock.rotation = Vector3(0.12, PI, 0)
	_part(stock, "butt_pad", _box(Vector3(0.045, 0.106, 0.012)), Vector3(0, 0, 0.256), _leather(Color("1c1715"), 32))

	_trigger_guard(root, Vector3(0, -0.032, -0.012), 0.026, 0.027, gunmetal, 37)

	# AF1.4. The BONE YARD 12G is box-fed rather than tube-fed: a quick-load
	# cassette ahead of the guard, which is why it is the only part named
	# "magazine" — the name `HunterArsenal` looks for to ride the reload timer.
	var cassette := _part(root, "magazine", _sweep([
		{"at": -0.030, "width": 0.026, "depth": 0.040},
		{"at": 0.042, "width": 0.026, "depth": 0.040},
		{"at": 0.050, "width": 0.030, "depth": 0.046},
		{"at": 0.058, "width": 0.030, "depth": 0.046},
	], 0.2, 8), Vector3(0, -0.058, 0.036), _metal(gunmetal.darkened(0.1), 0.32, 61))
	cassette.rotation.x = PI * 0.5 + 0.10

	# Sights. Rear notch on the receiver, bead on a post at the muzzle; the
	# bead's top and the notch's centre are both at y = 0.041.
	_notch_sight(root, Vector3(0, 0.032, 0.010), 0.006, 0.014, gunmetal.darkened(0.4))
	_part(root, "bead_post", _box(Vector3(0.003, 0.006, 0.004)), Vector3(0, 0.0325, 0.722), _metal(gunmetal, 0.3, 63))
	var bead := MeshInstance3D.new()
	bead.name = "front_bead"
	var ball := SphereMesh.new()
	ball.radius = 0.0035
	ball.height = 0.007
	ball.radial_segments = 8
	ball.rings = 4
	bead.mesh = ball
	bead.position = Vector3(0, 0.0375, 0.722)
	bead.material_override = _glow(Color("c9a45a"))
	root.add_child(bead)
	_sights(root, Vector3(0, 0.041, 0.010), Vector3(0, 0.041, 0.722), Vector3(0, 0.014, 0.742))

	_anchor(root, "grip", Vector3(0, -0.070, -0.044), Vector3(0.42, 0, 0))
	_anchor(root, "forend", Vector3(0, -0.020, 0.300), Vector3(0.10, 0, 0))
	_anchor(root, "muzzle", Vector3(0, 0.014, 0.742), Vector3.ZERO)


## The BREACH NINE, from the generated model (art/generated/items/
## breach_nine.glb: Tripo, from a house-style image, 29 September). It keeps
## the contract every weapon here keeps: muzzle along +Z (the assembly turns
## it once at the end) and the anchors the hands and the arsenal read. The
## model's own muzzle is -Z with the grip at +Z, and it is one unit long, so
## it is turned a half revolution and scaled to a pistol. Measured on the
## model in its unit box: grip centre (0, -0.234, 0.365), muzzle
## (0, 0.232, -0.48). It has no separate magazine node, so the reload's
## magazine drop simply has nothing to move; the reload timer, ammo and the
## jam logic are unaffected. Falls back to the drawn pistol if the file is
## not there (an LFS checkout without media still plays).
const BREACH_NINE_MODEL := "res://art/generated/items/breach_nine.glb"
const BREACH_NINE_SCALE := 0.23


static func _build_breach_nine(root: Node3D) -> void:
	var scene: PackedScene = load(BREACH_NINE_MODEL) as PackedScene if ResourceLoader.exists(BREACH_NINE_MODEL) else null
	if scene == null:
		_build_sidearm(root)
		return
	var model := scene.instantiate() as Node3D
	model.name = "generated_breach_nine"
	GENERATED_MODEL.tame_metal(model)
	model.scale = Vector3.ONE * BREACH_NINE_SCALE
	model.rotation.y = PI
	root.add_child(model)
	# In the assembly's convention, after the half turn and the scale.
	_anchor(root, "grip", Vector3(0.001, -0.054, -0.084), Vector3(0.30, 0, 0))
	_anchor(root, "grip_support", Vector3(0.031, -0.054, -0.064), Vector3(0.30, 0, -0.5))
	_anchor(root, "muzzle", Vector3(0.0, 0.053, 0.111), Vector3.ZERO)
	# Measured off the model's own vertices in this frame: the rear sight
	# block tops out at 0.081 around z -0.078, the front post at 0.0816
	# around z 0.098, both centred on x = 0.
	_sights(root, Vector3(0.0, 0.0812, -0.078), Vector3(0.0, 0.0816, 0.098), Vector3(0.0, 0.053, 0.111))


## The MERCY NINE, remade 4 October. A service pistol a player can name from
## the back: slide with serrations and an ejection port, a barrel crown with a
## bore you can see, hammer, beavertail, a vertical trigger guard and trigger,
## bone grip panels, and real sights — a two-post rear notch and a front post
## whose top is level with the posts, bone dots on both, so the ADS line
## `sight_rear` -> `sight_front` is the picture you see.
static func _build_sidearm(root: Node3D) -> void:
	var gunmetal := Color("5d625f")
	var dark := _metal(Color("151716"), 0.5, 40)
	_part(root, "slide", _sweep([
		{"at": -0.030, "width": 0.028, "depth": 0.032},
		{"at": 0.150, "width": 0.028, "depth": 0.032},
		{"at": 0.166, "width": 0.025, "depth": 0.027},
	], 0.18, 8), Vector3(0, 0.017, 0), _metal(gunmetal, 0.26, 41))
	var crown := _part(root, "barrel_crown", BodyMesh.revolve([
		Vector3(0.0, 0.0072, 0.0072), Vector3(0.008, 0.0072, 0.0072),
	], 10), Vector3(0, 0.017, 0.164), _metal(gunmetal.darkened(0.3), 0.3, 42))
	crown.rotation.x = PI * 0.5
	var bore := _part(root, "bore", BodyMesh.revolve([Vector3(0, 0, 0), Vector3(0, 0.0048, 0.0048)], 10),
		Vector3(0, 0.017, 0.1722), _bore())
	bore.rotation.x = PI * 0.5
	_part(root, "ejection_port", _box(Vector3(0.002, 0.010, 0.034)), Vector3(0.0141, 0.025, 0.060), dark)
	# Serrations at the back of the slide, the detail that says "gun" faster
	# than the silhouette does.
	for side in [-1.0, 1.0]:
		for index in 5:
			_part(root, "serration%d_%d" % [int(side), index], _box(Vector3(0.0015, 0.024, 0.0028)),
				Vector3(side * 0.0141, 0.017, -0.024 + float(index) * 0.007), dark)
	var hammer := _part(root, "hammer", _box(Vector3(0.009, 0.014, 0.006)), Vector3(0, 0.024, -0.034), dark)
	hammer.rotation.x = -0.45

	_part(root, "frame", _box(Vector3(0.024, 0.018, 0.172)), Vector3(0, -0.009, 0.064), _metal(gunmetal.darkened(0.25), 0.30, 43))
	var beavertail := _part(root, "beavertail", _box(Vector3(0.026, 0.006, 0.022)), Vector3(0, -0.006, -0.036), _metal(gunmetal.darkened(0.25), 0.30, 44))
	beavertail.rotation.x = 0.3
	var pin := _part(root, "frame_mark", BodyMesh.revolve([
		Vector3(0.0, 0.0045, 0.0045), Vector3(0.002, 0.0045, 0.0045), Vector3(0.002, 0.0, 0.0),
	], 8), Vector3(-0.012, -0.008, 0.096), _metal(Color("8b6040"), 0.3, 45))
	pin.rotation.z = PI * 0.5

	# The rake of a pistol grip is most of what makes it read as a pistol. It
	# starts inside the frame so there is no gap between grip and slide.
	var grip := _part(root, "grip", _sweep([
		{"at": -0.040, "width": 0.027, "depth": 0.042},
		{"at": 0.0, "width": 0.029, "depth": 0.045},
		{"at": 0.060, "width": 0.030, "depth": 0.046},
		{"at": 0.105, "width": 0.029, "depth": 0.043},
	], 0.45), Vector3(0, -0.052, -0.036), _leather(Color("2b2422"), 47))
	grip.rotation.x = PI * 0.5 + 0.38
	var panels := _part(root, "grip_panels", _sweep([
		{"at": 0.004, "width": 0.0322, "depth": 0.032},
		{"at": 0.088, "width": 0.0322, "depth": 0.032},
	], 0.6), Vector3(0, -0.052, -0.036), _wood(Color("8a7a5c"), 48))
	panels.rotation.x = PI * 0.5 + 0.38

	_trigger_guard(root, Vector3(0, -0.018, 0.012), 0.024, 0.026, gunmetal, 53)

	# AF1.4. Named "magazine" on purpose — `HunterArsenal` finds this node by
	# that name and rides it through the reload timer. It sits proud of the
	# butt's heel so the well it leaves actually reads as empty mid-swap.
	var magazine := _part(root, "magazine", _sweep([
		{"at": 0.0, "width": 0.024, "depth": 0.014},
		{"at": 0.062, "width": 0.024, "depth": 0.014},
		{"at": 0.066, "width": 0.028, "depth": 0.020},
		{"at": 0.072, "width": 0.028, "depth": 0.020},
	], 0.25), Vector3(0, -0.096, -0.050), _metal(gunmetal.darkened(0.15), 0.30, 59))
	magazine.rotation.x = PI * 0.5 + 0.38

	# Rear posts and front post both top out at y = 0.043; the notch between
	# the posts bottoms at 0.037.
	_notch_sight(root, Vector3(0, 0.033, -0.020), 0.004, 0.010, gunmetal.darkened(0.4))
	_part(root, "front_sight", _box(Vector3(0.0045, 0.010, 0.010)), Vector3(0, 0.038, 0.156), _metal(gunmetal.darkened(0.4), 0.32, 49))
	_part(root, "front_dot", _box(Vector3(0.0028, 0.0028, 0.001)), Vector3(0, 0.040, 0.1505), _glow(Color("d8cfb4")))
	_sights(root, Vector3(0, 0.043, -0.020), Vector3(0, 0.043, 0.156), Vector3(0, 0.017, 0.173))

	_anchor(root, "grip", Vector3(0, -0.062, -0.048), Vector3(0.38, 0, 0))
	_anchor(root, "grip_support", Vector3(0.030, -0.058, -0.030), Vector3(0.38, 0, -0.5))
	_anchor(root, "muzzle", Vector3(0, 0.017, 0.173), Vector3.ZERO)


# ---------------------------------------------------------- weapon part helpers
static func _part(parent: Node3D, part_name: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part


static func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


## A rear notch sight standing on `top_of` (where it meets the gun): a base
## strip `base` high and two posts up to `post`, a bone dot on each post.
static func _notch_sight(root: Node3D, top_of: Vector3, base: float, post: float, tint: Color) -> void:
	var metal := _metal(tint, 0.34, 46)
	_part(root, "rear_sight", _box(Vector3(0.026, base, 0.009)), top_of + Vector3(0, base * 0.5, 0), metal)
	for side in [-1.0, 1.0]:
		var name_side := "l" if side < 0.0 else "r"
		_part(root, "rear_sight_" + name_side, _box(Vector3(0.009, post - base + 0.0005, 0.009)),
			top_of + Vector3(side * 0.0085, (base + post) * 0.5, 0), metal)
		_part(root, "rear_dot_" + name_side, _box(Vector3(0.0028, 0.0028, 0.001)),
			top_of + Vector3(side * 0.0085, (base + post) * 0.5, -0.0048), _glow(Color("d8cfb4")))


## A trigger guard hanging below the frame as a vertical loop, and the
## trigger inside it. `under` is the middle of the loop's top.
static func _trigger_guard(root: Node3D, under: Vector3, drop: float, half_length: float, tint: Color, seed_value: int) -> void:
	# `arc_tube` draws in its own XZ plane; turned a quarter on Z its X
	# becomes height, and the half from PI/2 to 3PI/2 is the half below.
	var guard := _part(root, "trigger_guard", BodyMesh.arc_tube(drop, half_length, 0.0035, PI * 0.5, PI * 1.5, 10),
		under, _metal(tint, 0.32, seed_value))
	guard.rotation.z = PI * 0.5
	var trigger := _part(root, "trigger", _box(Vector3(0.005, drop * 0.66, 0.004)),
		under + Vector3(0, -drop * 0.33, -half_length * 0.15), _metal(tint.darkened(0.3), 0.32, seed_value + 1))
	trigger.rotation.x = 0.3


## The three points an aim-down-sights camera lines up on: the rear notch,
## the top of the front sight, and the bore's exit. Marker3D and named, so
## ADS finds them on any gun with `find_child`.
static func _sights(root: Node3D, rear: Vector3, front: Vector3, muzzle: Vector3) -> void:
	for entry in [["sight_rear", rear], ["sight_front", front], ["muzzle", muzzle]]:
		var marker := Marker3D.new()
		marker.name = entry[0]
		marker.position = entry[1]
		root.add_child(marker)


static func _bore() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("050505")
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Sight dots and the bead: faintly lit so they hold in the dark, which is
## the one thing a sight has to do.
static func _glow(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.5
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.9
	return material


## The cleaver's blade, along +Z, flat faces ±Y, edge +X. The spine stays
## put while the edge widens towards the front; near the end the spine drops
## in a straight clip to the point. Flat-shaded so each bevel catches light
## as one plane.
static func _cleaver_blade(length: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	# [along, spine x, edge x, thickness]
	var stations := [
		[0.00, -0.030, 0.030, 0.0130],
		[0.08, -0.030, 0.031, 0.0130],
		[0.55, -0.030, 0.040, 0.0115],
		[0.84, -0.030, 0.046, 0.0095],
		[0.92, -0.012, 0.046, 0.0070],
		[1.00, 0.040, 0.044, 0.0015],
	]
	var rings: Array = []
	for station: Array in stations:
		var along: float = length * float(station[0])
		var spine: float = station[1]
		var edge: float = station[2]
		var half: float = float(station[3]) * 0.5
		var shoulder := lerpf(spine, edge, 0.6)
		rings.append([
			Vector3(spine, -half, along),
			Vector3(spine, half, along),
			Vector3(shoulder, half * 0.86, along),
			Vector3(edge, 0.0, along),
			Vector3(shoulder, -half * 0.86, along),
		])
	for index in rings.size() - 1:
		var here: Array = rings[index]
		var there: Array = rings[index + 1]
		for step in 5:
			var next := (step + 1) % 5
			_quad(surface, here[step], here[next], there[next], there[step])
	_fan(surface, rings[0], Vector3(0, 0, 0), true)
	_fan(surface, rings[rings.size() - 1], Vector3(0.042, 0, length), false)
	surface.generate_normals()
	return surface.commit()


static func _anchor(root: Node3D, anchor_name: String, at: Vector3, turn: Vector3) -> void:
	var node := Node3D.new()
	node.name = "anchor_%s" % anchor_name
	node.position = at
	node.rotation = turn
	root.add_child(node)


## The anchor convention belongs to held gear, not only to weapons. Small
## carried objects use this public seam so hands, smokeables and anything added
## later agree that `anchor_grip` is the place a palm closes around the object.
static func add_anchor(root: Node3D, anchor_name: String, at: Vector3, turn := Vector3.ZERO) -> Node3D:
	_anchor(root, anchor_name, at, turn)
	return root.get_node("anchor_%s" % anchor_name) as Node3D


# ----------------------------------------------------------------- the assembly
func _init() -> void:
	name = "HeldGear"


## Whether these are the rig gloves or bare hands. Set it before the node
## enters the tree, because `_ready()` is where the hands get built.
##
## `hunter_arsenal._build_weapon_model()` mounts `build_humiliation_hand()` on
## every weapon the Hunt carries -- dark leather, scaled up -- because the
## player wakes in the humiliation rig and never takes it off. A `HeldGear`
## instance built its own out of bare `_flesh` instead, so the gore range put
## pink hands on the same weapon the world puts gloved ones on. Greg, with the
## two side by side: *"the hand models arent the same as the ashbloom world"*.
var gloved := false


func _ready() -> void:
	if right_hand == null:
		right_hand = build_humiliation_hand(1) if gloved else build_hand(1, _flesh)
		add_child(right_hand)
	if left_hand == null:
		left_hand = build_humiliation_hand(-1) if gloved else build_hand(-1, _flesh)
		add_child(left_hand)
	take("", "fists")


func set_flesh(colour: Color) -> void:
	_flesh = colour


## Put something in your hands, held a particular way. An empty `weapon_id` is
## empty hands, which is a real state and not an absence — it is the one you are
## in when you have just thrown your sword at somebody.
func take(weapon_id: String, grip_name := "") -> void:
	if weapon != null and is_instance_valid(weapon):
		weapon.queue_free()
		weapon = null
	_anchors.clear()
	if weapon_id != "":
		weapon = build_weapon(weapon_id)
		add_child(weapon)
		for child in weapon.get_children():
			var node_name := str(child.name)
			if node_name.begins_with("anchor_"):
				_anchors[node_name.trim_prefix("anchor_")] = child
	if grip_name == "":
		grip_name = _default_grip(weapon_id)
	hold(grip_name)


func _default_grip(weapon_id: String) -> String:
	match weapon_id:
		"": return "fists"
		"sword": return "two_hand"
		"staff": return "two_hand"
		"shotgun": return "long_gun"
		"sidearm": return "pistol"
		"launcher": return "long_gun"
	return "one_hand"


## Re-pose the hands on a production weapon mount without rebuilding it. The
## Hunt uses lightweight weapon nodes rather than a full HeldGear instance, but
## the anchors and grip table are the same authored grammar. Keeping this here
## prevents half-swording from changing only combat numbers while the visible
## off hand remains wrapped around the pommel.
static func pose_mounted_hand(hand: Node3D, weapon: Node3D, hand_spec: Dictionary, side: int) -> void:
	if hand == null or weapon == null or not is_instance_valid(hand) or not is_instance_valid(weapon):
		return
	set_pose(hand, str(hand_spec.get("pose", "open")))
	var anchor_name := str(hand_spec.get("anchor", ""))
	var anchor := weapon.get_node_or_null("anchor_%s" % anchor_name) as Node3D
	if anchor == null:
		hand.position = Vector3(0.085 * float(side), -0.075, -0.02)
		hand.rotation = Vector3(-0.30, 0.20 * float(side), 0.18 * float(side))
	else:
		var placed := weapon.transform * anchor.transform
		hand.position = placed.origin + Vector3(0.019 * float(side), -0.013, 0.0)
		hand.rotation = placed.basis.get_euler() + Vector3(-PI * 0.5, 0.0, (PI * 0.5) * float(side))
	hand.set_meta("grip_rest_position", hand.position)
	hand.set_meta("grip_rest_rotation", hand.rotation)


## Change how the same thing is held. This is the verb behind half-swording:
## nothing is drawn or sheathed, the hands move.
func hold(grip_name: String) -> bool:
	if not GRIPS.has(grip_name):
		return false
	grip = grip_name
	var spec: Dictionary = GRIPS[grip_name]
	var rest: Dictionary = spec.get("rest", {})
	if not rest.is_empty():
		position = rest["at"]
		rotation = rest["turn"]
	_place(right_hand, spec["right"], 1)
	_place(left_hand, spec["left"], -1)
	return true


## What the current grip does to a blow. `HunterArsenal` owns the weapon's own
## numbers; this is the multiplier and the type that come from how it is held.
func grip_effect() -> Dictionary:
	var spec: Dictionary = GRIPS.get(grip, GRIPS["fists"])
	return {"reach": float(spec.get("reach", 1.0)), "damage_type": str(spec.get("damage_type", "blunt"))}


func _place(hand: Node3D, spec: Dictionary, side: int) -> void:
	if hand == null or not is_instance_valid(hand):
		return
	set_pose(hand, str(spec.get("pose", "open")))
	var anchor_name := str(spec.get("anchor", ""))
	var anchor := _anchors.get(anchor_name) as Node3D
	if anchor == null:
		# Nothing to hold, so the hand goes where a hand goes: out in front,
		# off to its own side, angled in. A hand left at the origin is the
		# classic sign of a rig that has not been posed at all.
		hand.position = Vector3(0.085 * float(side), -0.075, -0.02)
		hand.rotation = Vector3(-0.30, 0.20 * float(side), 0.18 * float(side))
		return
	# Through the weapon's own transform, not straight off the anchor: the
	# weapon is turned to face down -Z, so an anchor position read raw is in a
	# space nobody else is in and the hand lands on the wrong end of the blade.
	var placed: Transform3D = weapon.transform * anchor.transform
	# The palm closes round the anchor, so the hand sits slightly off it rather
	# than inside it, and it rolls so the fingers close across the object.
	hand.position = placed.origin + Vector3(0.019 * float(side), -0.013, 0.0)
	hand.rotation = placed.basis.get_euler() + Vector3(-PI * 0.5, 0.0, (PI * 0.5) * float(side))


# ------------------------------------------------------------------- the meshes
## Sweep a cross-section along Z, scaling it at each station.
##
## `rounding` blends the rectangular section toward an ellipse: 0 is a hard box,
## 1 is a tube, and everything interesting is in between. This one function is
## every flat part of every weapon here, which is the point — a grip, a receiver
## and a stock are the same operation with different numbers, and that is much
## closer to how the objects were actually made than three boxes are.
static func _sweep(stations: Array, rounding := 0.3, sides := 12) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for station: Dictionary in stations:
		var ring: Array = []
		var half_width := float(station["width"]) * 0.5
		var half_depth := float(station["depth"]) * 0.5
		for index in sides:
			var angle := TAU * float(index) / float(sides)
			var round_x := cos(angle)
			var round_y := sin(angle)
			# The square version of the same angle: push the unit circle out to
			# the unit square, then blend back by `rounding`.
			var longest := maxf(absf(round_x), absf(round_y))
			var box_x := round_x / maxf(longest, 0.0001)
			var box_y := round_y / maxf(longest, 0.0001)
			ring.append(Vector3(
				lerpf(box_x, round_x, rounding) * half_width,
				lerpf(box_y, round_y, rounding) * half_depth,
				float(station["at"])))
		rings.append(ring)

	for index in rings.size() - 1:
		var here: Array = rings[index]
		var there: Array = rings[index + 1]
		for step in sides:
			var next := (step + 1) % sides
			_quad(surface, here[step], here[next], there[next], there[step])
	_fan(surface, rings[0], Vector3(0, 0, float((stations[0] as Dictionary)["at"])), true)
	_fan(surface, rings[rings.size() - 1],
		Vector3(0, 0, float((stations[stations.size() - 1] as Dictionary)["at"])), false)
	surface.generate_normals()
	return surface.commit()


## A blade. One edge, a spine with the mass in it, and a point.
##
## The section is five points rather than four: spine top, spine bottom, two
## bevel shoulders and the edge itself. That is what a wedge-section blade is,
## and it is the difference between something that catches a highlight along its
## length and a grey rectangle.
static func _blade(length: float, width: float, thickness: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Along the blade: how wide, how thick, how far. The last station is the
	# point, where both collapse.
	var stations := [
		{"at": 0.0, "width": 1.0, "thick": 1.0},
		{"at": 0.10, "width": 1.02, "thick": 1.0},
		{"at": 0.62, "width": 0.96, "thick": 0.86},
		{"at": 0.86, "width": 0.88, "thick": 0.64},
		{"at": 0.97, "width": 0.52, "thick": 0.34},
		{"at": 1.0, "width": 0.06, "thick": 0.08},
	]
	var rings: Array = []
	for station: Dictionary in stations:
		var half_width := width * 0.5 * float(station["width"])
		var half_thick := thickness * 0.5 * float(station["thick"])
		var along := length * float(station["at"])
		rings.append([
			Vector3(-half_width, -half_thick, along),		   # spine, one face
			Vector3(-half_width, half_thick, along),		   # spine, other face
			Vector3(half_width * 0.35, half_thick * 0.86, along),  # bevel shoulder
			Vector3(half_width, 0.0, along),				   # the edge
			Vector3(half_width * 0.35, -half_thick * 0.86, along), # bevel shoulder
		])
	for index in rings.size() - 1:
		var here: Array = rings[index]
		var there: Array = rings[index + 1]
		for step in 5:
			var next := (step + 1) % 5
			_quad(surface, here[step], here[next], there[next], there[step])
	_fan(surface, rings[0], Vector3(0, 0, 0), true)
	surface.generate_normals()
	return surface.commit()


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a, b, c]:
		surface.add_vertex(point)
	for point in [a, c, d]:
		surface.add_vertex(point)


static func _fan(surface: SurfaceTool, ring: Array, middle: Vector3, flip: bool) -> void:
	for index in ring.size():
		var next := (index + 1) % ring.size()
		if flip:
			surface.add_vertex(middle)
			surface.add_vertex(ring[next])
			surface.add_vertex(ring[index])
		else:
			surface.add_vertex(middle)
			surface.add_vertex(ring[index])
			surface.add_vertex(ring[next])


static func _skin(flesh: Color, seed_value: int) -> StandardMaterial3D:
	var material := WorldLook.surface(flesh, "flesh", seed_value)
	# `WorldLook`'s flesh carries a strong rim, which is right for a body read
	# across a lit room and wrong for a hand forty centimetres from the lens: at
	# this range the rim wraps the whole silhouette and the hand reads as wax.
	# Everything else about the surface is kept, so a hand still belongs to the
	# same world as the body it is attached to.
	material.rim_enabled = false
	material.roughness = 0.72
	# The Ashbloom exterior crushes everything at hip height toward black, which
	# is the same reason the held weapon carries a self-lit edge. Hands in frame
	# have to survive the same light.
	material.emission_enabled = true
	material.emission = flesh
	material.emission_energy_multiplier = 0.13
	return material


static func _metal(tint: Color, roughness: float, seed_value: int) -> StandardMaterial3D:
	var material := WorldLook.surface(tint, "chrome", seed_value)
	material.metallic = 0.86
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.20
	return material


static func _wood(tint: Color, seed_value: int) -> StandardMaterial3D:
	var material := WorldLook.surface(tint, "dirt", seed_value)
	material.roughness = 0.68
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.18
	return material


## player-81: the jester glove and sleeve. The world's grain is sized for a
## wall seen across a room; forty centimetres from the lens its texels were
## thumb-sized squares drifting purple, green and orange. Same surface, grain
## fifteen times finer.
static func _glove(tint: Color, seed_value: int) -> StandardMaterial3D:
	var material := _leather(tint, seed_value)
	material.uv1_scale *= 15.0
	return material


static func _leather(tint: Color, seed_value: int) -> StandardMaterial3D:
	var material := WorldLook.surface(tint, "dirt", seed_value)
	material.roughness = 0.82
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.16
	return material
