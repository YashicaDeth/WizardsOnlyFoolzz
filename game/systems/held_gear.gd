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
		_: _build_sword(root)
	# Every part above is authored muzzle-forward along +Z because that is the
	# readable way to write a sweep, and a Godot node's forward is -Z. Turning
	# the assembled weapon once here means the geometry reads naturally in the
	# source and points where the camera looks in the world, and it carries the
	# anchors round with it so a grip cannot disagree with the shape.
	root.rotation.y = PI
	return root


## The Ashline Cleaver. Single-edged, heavy at the front, a blade that is a
## wedge in section rather than a plank — the spine carries the mass and the
## edge is where it runs out.
static func _build_sword(root: Node3D) -> void:
	var steel := Color("9aa0a4")
	var blade := MeshInstance3D.new()
	blade.name = "blade"
	blade.mesh = _blade(0.86, 0.078, 0.0135)
	blade.position = Vector3(0, 0, -0.10)
	blade.material_override = _metal(steel, 0.22, 11)
	root.add_child(blade)

	# A fuller: the groove down a blade that takes weight out of it without
	# taking stiffness out. Two of them, inset, reading as a dark line.
	for side in [-1.0, 1.0]:
		var fuller := MeshInstance3D.new()
		fuller.name = "fuller%d" % int(side)
		fuller.mesh = _sweep([
			{"at": 0.0, "width": 0.019, "depth": 0.002},
			{"at": 0.52, "width": 0.016, "depth": 0.002},
			{"at": 0.60, "width": 0.0, "depth": 0.001},
		], 0.0)
		fuller.position = Vector3(0, side * 0.0064, -0.06)
		fuller.material_override = _metal(steel.darkened(0.45), 0.35, 4)
		root.add_child(fuller)

	var guard := MeshInstance3D.new()
	guard.name = "guard"
	guard.mesh = _sweep([
		{"at": -0.115, "width": 0.016, "depth": 0.014},
		{"at": -0.060, "width": 0.022, "depth": 0.019},
		{"at": 0.0, "width": 0.040, "depth": 0.026},
		{"at": 0.060, "width": 0.022, "depth": 0.019},
		{"at": 0.115, "width": 0.016, "depth": 0.014},
	], 0.5)
	guard.rotation = Vector3(0, PI * 0.5, 0)
	guard.position = Vector3(0, 0, -0.10)
	guard.material_override = _metal(Color("8b6040"), 0.34, 21)
	root.add_child(guard)

	var handle := MeshInstance3D.new()
	handle.name = "grip"
	handle.mesh = BodyMesh.revolve([
		Vector3(0.0, 0.0165, 0.0125),
		Vector3(0.045, 0.0185, 0.0140),
		Vector3(0.110, 0.0170, 0.0130),
		Vector3(0.170, 0.0150, 0.0118),
	], 10)
	# M4.4. Same fix as the shotgun barrel: `revolve()` extends along local Y,
	# so only a rotation on X actually lays it down the blade's own axis.
	# Negative here because the grip runs *back* from the guard (towards -Z)
	# rather than forward like a barrel does.
	handle.rotation.x = -PI * 0.5
	handle.position = Vector3(0, 0, -0.10)
	handle.material_override = _leather(Color("35261e"), 5)
	root.add_child(handle)

	# Wrap, so the grip is not a smooth dowel. Rings of cord down its length.
	for index in 7:
		var cord := MeshInstance3D.new()
		cord.name = "wrap%d" % index
		cord.mesh = BodyMesh.revolve([
			Vector3(-0.005, 0.0195, 0.0150),
			Vector3(0.005, 0.0195, 0.0150),
		], 10)
		cord.rotation.x = -PI * 0.5
		cord.position = Vector3(0, 0, -0.122 - float(index) * 0.0205)
		cord.material_override = _leather(Color("241a14"), index)
		root.add_child(cord)

	var pommel := MeshInstance3D.new()
	pommel.name = "pommel"
	# A mass, not a cap: a pommel is a counterweight, and it is the head of the
	# hammer when the sword is held the other way up.
	pommel.mesh = BodyMesh.revolve([
		Vector3(0.0, 0.014, 0.014),
		Vector3(0.012, 0.030, 0.027),
		Vector3(0.030, 0.033, 0.029),
		Vector3(0.048, 0.022, 0.020),
		Vector3(0.056, 0.010, 0.010),
	], 10)
	pommel.rotation.x = -PI * 0.5
	pommel.position = Vector3(0, 0, -0.272)
	pommel.material_override = _metal(Color("8b6040"), 0.30, 33)
	root.add_child(pommel)

	_anchor(root, "grip", Vector3(0, 0, -0.158), Vector3.ZERO)
	_anchor(root, "grip_low", Vector3(0, 0, -0.226), Vector3.ZERO)
	# Halfway up the blade, which is where a hand goes when the cut has stopped
	# being the answer.
	_anchor(root, "blade_grip", Vector3(0, 0, 0.230), Vector3.ZERO)
	_anchor(root, "blade_high", Vector3(0, 0, 0.430), Vector3.ZERO)
	_anchor(root, "muzzle", Vector3(0, 0, 0.760), Vector3.ZERO)


static func _build_shotgun(root: Node3D) -> void:
	var gunmetal := Color("53585a")
	var receiver := MeshInstance3D.new()
	receiver.name = "receiver"
	receiver.mesh = _sweep([
		{"at": 0.0, "width": 0.052, "depth": 0.062},
		{"at": 0.055, "width": 0.055, "depth": 0.070},
		{"at": 0.200, "width": 0.055, "depth": 0.070},
		{"at": 0.245, "width": 0.048, "depth": 0.058},
	], 0.35)
	receiver.position = Vector3(0, 0, -0.02)
	receiver.material_override = _metal(gunmetal, 0.30, 13)
	root.add_child(receiver)

	var barrel := MeshInstance3D.new()
	barrel.name = "barrel"
	barrel.mesh = BodyMesh.revolve([
		Vector3(0.0, 0.0125, 0.0125),
		Vector3(0.40, 0.0112, 0.0112),
		Vector3(0.52, 0.0118, 0.0118),
	], 12)
	# M4.4. `BodyMesh.revolve()` extends along its own local Y, not Z like
	# `_sweep()` — a rotation around Y cannot retarget a shape that is already
	# aligned with Y, which is why this read as a barrel pointed at the sky
	# rather than downrange. Tipping it over on X is what actually lays a
	# Y-extending tube along +Z, matching every `_sweep()` part's own
	# muzzle-forward convention.
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0, 0.016, 0.225)
	barrel.material_override = _metal(gunmetal.darkened(0.2), 0.24, 17)
	root.add_child(barrel)

	var magazine := MeshInstance3D.new()
	magazine.name = "tube"
	magazine.mesh = BodyMesh.revolve([
		Vector3(0.0, 0.0115, 0.0115),
		Vector3(0.40, 0.0115, 0.0115),
	], 10)
	magazine.rotation.x = PI * 0.5
	magazine.position = Vector3(0, -0.014, 0.225)
	magazine.material_override = _metal(gunmetal.darkened(0.3), 0.30, 19)
	root.add_child(magazine)

	var forend := MeshInstance3D.new()
	forend.name = "forend"
	forend.mesh = _sweep([
		{"at": 0.0, "width": 0.036, "depth": 0.040},
		{"at": 0.030, "width": 0.042, "depth": 0.047},
		{"at": 0.150, "width": 0.042, "depth": 0.047},
		{"at": 0.182, "width": 0.035, "depth": 0.039},
	], 0.45)
	forend.position = Vector3(0, -0.006, 0.250)
	forend.material_override = _wood(Color("4a3325"), 23)
	root.add_child(forend)

	# Ribs on the pump, because the one part of a shotgun a player looks at in
	# first person is the part their off hand is on.
	for index in 6:
		var rib := MeshInstance3D.new()
		rib.name = "rib%d" % index
		rib.mesh = BodyMesh.revolve([
			Vector3(-0.004, 0.0235, 0.0255),
			Vector3(0.004, 0.0235, 0.0255),
		], 10)
		rib.rotation.x = PI * 0.5
		rib.position = Vector3(0, -0.006, 0.272 + float(index) * 0.0225)
		rib.material_override = _wood(Color("35241a"), index + 40)
		root.add_child(rib)

	var grip_mesh := MeshInstance3D.new()
	grip_mesh.name = "grip"
	grip_mesh.mesh = _sweep([
		{"at": 0.0, "width": 0.038, "depth": 0.046},
		{"at": 0.060, "width": 0.036, "depth": 0.050},
		{"at": 0.125, "width": 0.034, "depth": 0.044},
	], 0.5)
	grip_mesh.rotation = Vector3(PI * 0.5 + 0.42, 0, 0)
	grip_mesh.position = Vector3(0, -0.052, -0.030)
	grip_mesh.material_override = _wood(Color("3d2a1e"), 29)
	root.add_child(grip_mesh)

	var stock := MeshInstance3D.new()
	stock.name = "stock"
	stock.mesh = _sweep([
		{"at": 0.0, "width": 0.044, "depth": 0.058},
		{"at": 0.110, "width": 0.048, "depth": 0.076},
		{"at": 0.215, "width": 0.046, "depth": 0.092},
	], 0.4)
	stock.rotation = Vector3(0.10, PI, 0)
	stock.position = Vector3(0, -0.030, -0.110)
	stock.material_override = _wood(Color("4a3325"), 31)
	root.add_child(stock)

	var guard := MeshInstance3D.new()
	guard.name = "trigger_guard"
	guard.mesh = BodyMesh.arc_tube(0.052, 0.030, 0.006, PI, TAU, 10)
	guard.position = Vector3(0, -0.036, -0.012)
	guard.material_override = _metal(gunmetal, 0.34, 37)
	root.add_child(guard)

	# AF1.4. The BONE YARD 12G is built box-fed rather than tube-fed — a
	# quick-load cassette ahead of the guard, not the fixed `tube` above, which
	# is why it is the only part of this weapon named "magazine": that is the
	# name `HunterArsenal` looks for to ride the reload timer.
	var cassette := MeshInstance3D.new()
	cassette.name = "magazine"
	cassette.mesh = _sweep([
		{"at": 0.0, "width": 0.034, "depth": 0.020},
		{"at": 0.070, "width": 0.034, "depth": 0.020},
		{"at": 0.080, "width": 0.026, "depth": 0.016},
	], 0.25)
	cassette.rotation = Vector3(PI * 0.5 + 0.10, 0, 0)
	cassette.position = Vector3(0, -0.058, 0.028)
	cassette.material_override = _metal(gunmetal.darkened(0.1), 0.32, 61)
	root.add_child(cassette)

	_anchor(root, "grip", Vector3(0, -0.070, -0.044), Vector3(0.42, 0, 0))
	_anchor(root, "forend", Vector3(0, -0.020, 0.300), Vector3(0.10, 0, 0))
	_anchor(root, "muzzle", Vector3(0, 0.016, 0.745), Vector3.ZERO)


static func _build_sidearm(root: Node3D) -> void:
	var gunmetal := Color("6a6f6c")
	var slide := MeshInstance3D.new()
	slide.name = "slide"
	slide.mesh = _sweep([
		{"at": 0.0, "width": 0.030, "depth": 0.034},
		{"at": 0.020, "width": 0.032, "depth": 0.038},
		{"at": 0.175, "width": 0.032, "depth": 0.036},
		{"at": 0.198, "width": 0.028, "depth": 0.030},
	], 0.40)
	slide.position = Vector3(0, 0.014, -0.020)
	slide.material_override = _metal(gunmetal, 0.26, 41)
	root.add_child(slide)

	# The sidearm used to have the right mass but no landmarks: at first-person
	# distance it read as a short metal rectangle.  These are the three details
	# a player can identify without inspecting a high-poly asset — the open port,
	# rear notch and front blade — all kept as real geometry so they catch the
	# same world light as the rest of the held weapon.
	var port := MeshInstance3D.new()
	port.name = "ejection_port"
	var port_mesh := BoxMesh.new()
	port_mesh.size = Vector3(0.004, 0.016, 0.056)
	port.mesh = port_mesh
	port.position = Vector3(0.033, 0.019, 0.096)
	port.material_override = _metal(Color("171a19"), 0.48, 45)
	root.add_child(port)
	for side in [-1.0, 1.0]:
		var rear_sight := MeshInstance3D.new()
		rear_sight.name = "rear_sight_l" if side < 0.0 else "rear_sight_r"
		var rear_mesh := BoxMesh.new()
		rear_mesh.size = Vector3(0.010, 0.020, 0.012)
		rear_sight.mesh = rear_mesh
		rear_sight.position = Vector3(side * 0.016, 0.048, 0.010)
		rear_sight.material_override = _metal(gunmetal.darkened(0.34), 0.38, 46 + int(side))
		root.add_child(rear_sight)
	var front_sight := MeshInstance3D.new()
	front_sight.name = "front_sight"
	var front_mesh := BoxMesh.new()
	front_mesh.size = Vector3(0.012, 0.021, 0.008)
	front_sight.mesh = front_mesh
	front_sight.position = Vector3(0, 0.048, 0.178)
	front_sight.material_override = _metal(gunmetal.lightened(0.08), 0.32, 49)
	root.add_child(front_sight)

	# Serrations at the back of the slide, the detail that says "gun" faster
	# than the silhouette does.
	for index in 5:
		var cut := MeshInstance3D.new()
		cut.name = "serration%d" % index
		cut.mesh = _sweep([
			{"at": 0.0, "width": 0.0035, "depth": 0.030},
			{"at": 0.006, "width": 0.0035, "depth": 0.030},
		], 0.1)
		cut.position = Vector3(0, 0.014, -0.012 + float(index) * 0.0085)
		cut.material_override = _metal(gunmetal.darkened(0.4), 0.4, index + 50)
		root.add_child(cut)

	var frame := MeshInstance3D.new()
	frame.name = "frame"
	frame.mesh = _sweep([
		{"at": 0.0, "width": 0.026, "depth": 0.022},
		{"at": 0.130, "width": 0.026, "depth": 0.024},
	], 0.3)
	frame.position = Vector3(0, -0.010, -0.012)
	frame.material_override = _metal(gunmetal.darkened(0.25), 0.30, 43)
	root.add_child(frame)

	var butt := MeshInstance3D.new()
	butt.name = "grip"
	butt.mesh = _sweep([
		{"at": 0.0, "width": 0.030, "depth": 0.036},
		{"at": 0.050, "width": 0.031, "depth": 0.040},
		{"at": 0.108, "width": 0.030, "depth": 0.036},
	], 0.45)
	# The rake of a pistol grip is most of what makes it read as a pistol.
	butt.rotation = Vector3(PI * 0.5 + 0.38, 0, 0)
	butt.position = Vector3(0, -0.052, -0.036)
	butt.material_override = _leather(Color("2b2422"), 47)
	root.add_child(butt)

	var guard := MeshInstance3D.new()
	guard.name = "trigger_guard"
	guard.mesh = BodyMesh.arc_tube(0.044, 0.026, 0.005, PI, TAU, 10)
	guard.position = Vector3(0, -0.030, -0.004)
	guard.material_override = _metal(gunmetal, 0.32, 53)
	root.add_child(guard)

	# AF1.4. Named "magazine" on purpose — `HunterArsenal` finds this node by
	# that name and rides it through the reload timer, dropping it clear of the
	# well and bringing a fresh one back up. It sits proud of the butt's heel
	# so the well it leaves actually reads as empty mid-swap, not just shorter.
	var magazine := MeshInstance3D.new()
	magazine.name = "magazine"
	magazine.mesh = _sweep([
		{"at": 0.0, "width": 0.024, "depth": 0.014},
		{"at": 0.062, "width": 0.024, "depth": 0.014},
		{"at": 0.070, "width": 0.019, "depth": 0.011},
	], 0.25)
	magazine.rotation = Vector3(PI * 0.5 + 0.38, 0, 0)
	magazine.position = Vector3(0, -0.096, -0.050)
	magazine.material_override = _metal(gunmetal.darkened(0.15), 0.30, 59)
	root.add_child(magazine)

	_anchor(root, "grip", Vector3(0, -0.062, -0.048), Vector3(0.38, 0, 0))
	_anchor(root, "grip_support", Vector3(0.030, -0.058, -0.030), Vector3(0.38, 0, -0.5))
	_anchor(root, "muzzle", Vector3(0, 0.014, 0.190), Vector3.ZERO)


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


func _ready() -> void:
	if right_hand == null:
		right_hand = build_hand(1, _flesh)
		add_child(right_hand)
	if left_hand == null:
		left_hand = build_hand(-1, _flesh)
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
		"shotgun": return "long_gun"
		"sidearm": return "pistol"
	return "one_hand"


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


static func _leather(tint: Color, seed_value: int) -> StandardMaterial3D:
	var material := WorldLook.surface(tint, "dirt", seed_value)
	material.roughness = 0.82
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.16
	return material
