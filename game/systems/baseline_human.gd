class_name BaselineHuman
extends Node3D

## One rig for every person in the world.
##
## Before this, each call site built its own body with its own zone vocabulary:
## the derby tagged a driver hitbox "legs", the hunt recorded Mara's wounds as
## "left arm", and AnatomyComponent only knows left_arm/left_leg/right_leg.
## Names it does not recognise silently resolve to "torso", so a severed leg was
## recorded as a chest wound and nothing downstream could tell the difference.
## Derby drivers skipped anatomy altogether and carried a loose driver_health
## integer instead.
##
## The rig owns the vocabulary, the hit geometry and the anatomy state together,
## so a body behaves the same wherever it is spawned. That is what "bodies
## remember" needs in order to apply to anyone rather than to hand-authored
## characters only. `head_anchor` exists so proximity voice has one consistent
## place to speak from.

const ImplantCatalog := preload("res://systems/implant_catalog.gd")

signal zone_disabled(zone_id: String)
signal limb_severed(zone_id: String, report: Dictionary)
signal went_down()
signal resolved(outcome: String)

const ZONES := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]
const LIMBS := ["left_arm", "right_arm", "left_leg", "right_leg"]
const SEVERING_DAMAGE := ["cut", "shear", "ballistic"]
const SEVER_THRESHOLD_RATIO := 0.85
const SEVER_HEALTH_RATIO := 0.25
## Multiplier on a zone's own bleed rate when it is taken off entirely, rather
## than merely destroyed. Tuned so an untreated stump is a clock measured in
## tens of seconds, not minutes.
const STUMP_BLEED := 26.0
## A human spine is authored as 33 vertebrae here. It is both the anatomical
## count and a deliberate recurring number in the game's body language.
const SPINE_VERTEBRAE := 33

## Every loose spelling that existed at a call site, mapped onto the canonical
## zone. Kept so old saves and old events stay readable rather than resolving to
## the torso forever.
const ZONE_ALIASES := {
	"legs": "left_leg", "leg": "left_leg", "arm": "left_arm",
	"left arm": "left_arm", "right arm": "right_arm",
	"left leg": "left_leg", "right leg": "right_leg",
	"chest": "torso", "body": "torso", "skull": "head",
}

const STANDING := {
	"head": {"at": Vector3(0, 1.62, 0), "size": Vector3(0.26, 0.28, 0.26)},
	"torso": {"at": Vector3(0, 1.12, 0), "size": Vector3(0.48, 0.66, 0.28)},
	# Arms hang *from* the shoulder, so their top has to end below the torso's
	# shoulder ring rather than level with it. At 1.10 the top of the arm sat at
	# 1.41 — above the torso's widest ring at 1.351 — and stuck up beside the
	# neck as a visibly separate object. Dropped, and tucked slightly inboard.
	"left_arm": {"at": Vector3(-0.228, 1.055, 0), "size": Vector3(0.17, 0.62, 0.19)},
	"right_arm": {"at": Vector3(0.228, 1.055, 0), "size": Vector3(0.17, 0.62, 0.19)},
	"left_leg": {"at": Vector3(-0.14, 0.42, 0), "size": Vector3(0.21, 0.84, 0.23)},
	"right_leg": {"at": Vector3(0.14, 0.42, 0), "size": Vector3(0.21, 0.84, 0.23)},
}

## Same zones, folded into a cab. A seated driver still has to be hittable in
## the right place, so this is a layout change rather than a different rig.
const SEATED := {
	"head": {"at": Vector3(0, 1.16, 0), "size": Vector3(0.26, 0.28, 0.26)},
	"torso": {"at": Vector3(0, 0.74, 0), "size": Vector3(0.48, 0.60, 0.28)},
	"left_arm": {"at": Vector3(-0.225, 0.74, -0.12), "size": Vector3(0.17, 0.52, 0.19)},
	"right_arm": {"at": Vector3(0.225, 0.74, -0.12), "size": Vector3(0.17, 0.52, 0.19)},
	"left_leg": {"at": Vector3(-0.14, 0.34, -0.30), "size": Vector3(0.21, 0.26, 0.62)},
	"right_leg": {"at": Vector3(0.14, 0.34, -0.30), "size": Vector3(0.21, 0.26, 0.62)},
}

const BONE := Color("cfc2a4")
const BLOOD := Color("6b0f0c")
const BLOOD_DARK := Color("3d0907")
const ORGAN := Color("7a1a16")
## Below this share of a zone's health the bone has gone through the skin and
## stays gone: a compound fracture is a state of the body, not an effect.
const FRACTURE_RATIO := 0.4
## Above this share of a zone's health the damage reads as bruising; below it
## the flesh has actually opened.
const BRUISE_RATIO := 0.55
const BRUISE_SKIN := Color("5c3550")
## B3.2. What dose takes flesh toward: sallow, greenish and wet, which is
## nothing like the purple a beating leaves. The two injuries have to be
## tellable apart across a room.
const MELTED_SKIN := Color("6e7a3c")
## Loose gore is capped across every body at once. Twelve drivers shedding
## unbounded blood in a pileup is a frame-rate bug, not atmosphere.
const MAX_LIVE_GORE := 140


static func live_gore_budget() -> int:
	match WorldLook.quality:
		WorldLook.Quality.ULTRA: return MAX_LIVE_GORE
		WorldLook.Quality.HIGH: return 92
		_: return 52
## Airborne blood is capped because twelve drivers shedding unbounded physics
## blobs in a pileup is a frame-rate bug. Blood that has *landed* is a flat
## splat with no simulation attached, so it can be far more numerous — and it
## has to be, because a drop that evaporates two seconds after it leaves the
## body means nothing ever accumulates and the fight leaves no trace. "Heaps of
## gore" is a property of the floor, not of the air.
const MAX_SPLATS := 420


static func splat_budget() -> int:
	match WorldLook.quality:
		WorldLook.Quality.ULTRA: return MAX_SPLATS
		WorldLook.Quality.HIGH: return 220
		_: return 96
## How far a landed drop spreads, as a multiple of the drop's own radius. A
## drop of blood makes a mark a few times its own size, not a puddle you could
## lie down in: at the old multiplier (6–12.5x, against a mesh already about
## two units across) every drop left a mark over three metres wide, so any
## fight buried its own floor. Measured in `gore_test`.
const SPLAT_SPREAD := 3.4

static var live_gore := 0
static var splats: Array[Node3D] = []
## Meshes belong to the loaded scene; evidence does not. Keep a compact record
## keyed by scene so revisiting a place redraws its blood without carrying old
## nodes across the scene boundary.
static var blood_records: Dictionary = {}
## Scales every effect count at once, driven by the GORE setting in the menu
## rather than by a hotkey over the pit. 0 is handled by the `gore` flag.
static var detail := 1.0

## Organs are positioned relative to the zone that contains them, so the seated
## and standing layouts both place them correctly without a second table.
const ORGAN_LAYOUT := {
	"brain": {"zone": "head", "at": Vector3(0, 0.01, 0), "size": 0.072, "tint": "9c8a86"},
	"heart": {"zone": "torso", "at": Vector3(-0.05, 0.10, 0.03), "size": 0.060, "tint": "6d100e"},
	"left_lung": {"zone": "torso", "at": Vector3(-0.12, 0.14, 0.0), "size": 0.076, "tint": "8a4d4a"},
	"right_lung": {"zone": "torso", "at": Vector3(0.12, 0.14, 0.0), "size": 0.076, "tint": "8a4d4a"},
	"liver": {"zone": "torso", "at": Vector3(0.08, -0.07, 0.02), "size": 0.070, "tint": "5a2015"},
	"gut": {"zone": "torso", "at": Vector3(0.0, -0.18, 0.03), "size": 0.088, "tint": "8d7a52"},
	"spine": {"zone": "torso", "at": Vector3(0.0, 0.0, -0.10), "size": 0.042, "tint": "cfc2a4"},
}

var anatomy: AnatomyComponent
var organ_parts: Dictionary = {}
var bones: Dictionary = {}
var head_anchor: Node3D
## Shoulder caps live on the torso, not the arms. The arm can be cut away and
## the shoulder still belongs to the chest — which avoids the detached-action-
## figure silhouette while keeping severing mechanically honest.
var shoulders: Dictionary = {}
var _xray := false
var subject_id := ""
var parts: Dictionary = {}
## Resting positions, captured lazily so `favour_injuries()` is idempotent.
var _rest_heights: Dictionary = {}
var severed: Array[String] = []
## Cutting force accumulates separately from health. A club can destroy an arm,
## but only a directional cutting/ballistic blow can take it off.
var sever_stress: Dictionary = {}
## Deepest `GoreChunks.Layer` any blow has reached, per zone. A body remembers
## how far it has been opened, not just how much health it has left.
var zone_depth: Dictionary = {}
## Where this body has actually been hit, per zone, in each limb's own local
## space. `hit_at()` has always received the exact impact point and always threw
## it away at the door; keeping it is the whole of B10.4's "a body carries its
## whole history visibly". See `wound_marks.gd`.
var wound_marks: Dictionary = {}
## Fractional drops owed. Bleeding runs well under one drop per frame, so the
## rate is accumulated and spent whole rather than rounded every frame — which
## would round to zero forever or to one every frame, and neither is a rate.
var _drip_owed := 0.0
## How long this body has been bleeding, in seconds, which is what lengthens and
## dries the streaks running down it.
var _bleed_seconds := 0.0
var gore := true
## D4.2. How big this body is, from the race on the sheet. Every body in the
## world used to be exactly the same size whatever the sheet said, because the
## factor existed and nothing read it.
var build_factor := 1.0

var _layout: Dictionary = {}
var _flesh := Color("6b5842")
var _seated := false
var _variation := 0
var _loose: Array[Dictionary] = []
## Most owners keep their own root (vehicles, scripted actors).  The range can
## opt into a short, floor-preserving travel on collapse so a defeated body
## reads as landing in the arena instead of snapping through its own feet.
var _knockdown_travel := 0.0
var _knockdown_tween: Tween
## O2.7 v4. Greg: *"gore and chunk physics still run at full speed through a
## hit, so a limb can leave a body that has not moved yet"*. Exactly right, and
## it is the most visible hole left in the hitstop work — the whole effect is
## that the blow met resistance, and it reads as a bug rather than as weight
## when the spray from that blow sails away on schedule while the body it came
## out of is standing still.
##
## The rig does not know the scene's `impact_feel` exists and should not. So it
## carries a scale that whoever owns it sets, defaulting to 1.0, which means a
## rig nobody is driving behaves exactly as it did before.
var motion_scale := 1.0


static func canonical_zone(zone_id: String) -> String:
	var lowered := zone_id.strip_edges().to_lower()
	if ZONES.has(lowered):
		return lowered
	return str(ZONE_ALIASES.get(lowered, "torso"))


func build(id: String, config: Dictionary = {}) -> void:
	subject_id = id
	# Default to the world's gore setting rather than to true. Every rig used to
	# be born with gore on and every caller had to remember to turn it off - and
	# one of them did not, which is how the Hunt Grounds shipped ignoring the
	# setting entirely (recorded in ROADMAP.md). A caller that genuinely wants to
	# override it can still pass `gore` in the config.
	# Pass `gore` in the config to override the world setting. Assigning
	# `rig.gore` before calling build() does not work and never did — this line
	# overwrites it — which is how a showcase scene that explicitly asked for a
	# clean body ended up standing in three metres of blood.
	gore = bool(config.get("gore", apply_gore_setting()))
	_seated = bool(config.get("seated", false))
	_knockdown_travel = maxf(0.0, float(config.get("knockdown_travel", 0.0)))
	_flesh = config.get("flesh", Color("6b5842")) as Color
	_variation = int(config.get("variation", 0))
	build_factor = clampf(float(config.get("build", 1.0)), 0.7, 1.4)
	var layout := _scaled_layout(SEATED if _seated else STANDING)
	_layout = layout

	for zone_id in ZONES:
		var spec: Dictionary = layout[zone_id]
		var part := MeshInstance3D.new()
		part.name = zone_id
		part.mesh = _zone_mesh(zone_id, spec.size)
		part.material_override = _zone_material(zone_id, _flesh.lightened(0.06) if zone_id == "head" else _flesh)
		part.position = spec.at
		if _leg_points_forward(zone_id):
			part.rotation.x = PI * 0.5
		part.set_meta("rest_position", spec.at)
		# B3.2. What this limb is when nothing has happened to it, so a melting
		# injury has something to take volume away from.
		part.set_meta("rest_scale", part.scale)
		add_child(part)
		parts[zone_id] = part

		var hitbox := Area3D.new()
		hitbox.name = "%s_hitbox" % zone_id
		hitbox.position = spec.at
		hitbox.set_meta("body_zone", zone_id)
		add_child(hitbox)
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec.size
		shape_node.shape = box
		hitbox.add_child(shape_node)

	_build_shoulders()
	_build_organs()
	_build_bones(layout)

	head_anchor = Node3D.new()
	head_anchor.name = "HeadAnchor"
	head_anchor.position = (layout.head as Dictionary).at + Vector3(0, 0.12, 0)
	add_child(head_anchor)

	anatomy = AnatomyComponent.new()
	anatomy.name = "Anatomy"
	add_child(anatomy)
	anatomy.configure(id, float(config.get("blood", 5000.0)), config.get("cybernetics", {}))
	anatomy.organ_ruptured.connect(_on_organ_ruptured)
	anatomy.went_down.connect(_on_went_down)
	# Initial prosthetics must read on the mesh before the body is wounded.
	for zone_id in ZONES:
		_refresh_zone(zone_id)
	if config.get("restore") is Dictionary:
		var restored: Dictionary = config.restore
		anatomy.restore(restored)
		severed.clear()
		for zone_id in restored.get("severed", []):
			var canonical := canonical_zone(str(zone_id))
			if LIMBS.has(canonical) or canonical == "head":
				severed.append(canonical)
		sever_stress = (restored.get("sever_stress", {}) as Dictionary).duplicate(true)
		zone_depth = (restored.get("zone_depth", {}) as Dictionary).duplicate(true)
		# After `zone_depth`, never before it: `_refresh_wounds` shows a wound
		# at the shallower of its own layer and the depth the limb was actually
		# opened to, so restoring the marks first would draw every old graze
		# claiming to show bone.
		wound_marks = WoundMarks.from_records(restored.get("wound_marks", {}), ZONES)
		# A limb that is not there has no health to have. Ordinary saves already
		# wrote zero here because `_sever_zone` zeroes it, but a body restored
		# from scars alone has no saved zone numbers at all — and a missing arm
		# reporting full health would have `combat_ratio()` counting it toward a
		# swing it cannot throw.
		for zone_id in severed:
			var stump: Dictionary = anatomy.zones.get(zone_id, {})
			if not stump.is_empty():
				stump["health"] = 0.0
				anatomy.zones[zone_id] = stump
		if anatomy.downed:
			rotation.x = -PI * 0.46
		for zone_id in ZONES:
			_refresh_zone(zone_id)
			_refresh_wounds(zone_id)
		for organ_id in organ_parts:
			if not anatomy.organ_ok(organ_id):
				_hide_organ(str(organ_id))


## The old torso ended at a vertical wall and the arm began as another separate
## shape, leaving a visible daylight seam at both shoulders. Build a pair of
## organic caps over that join, plus short clavicle bridges, from the torso so
## all characters — player, NPC, seated driver — share one continuous body.
func _build_shoulders() -> void:
	var torso := parts.get("torso") as MeshInstance3D
	if torso == null:
		return
	for side in [-1.0, 1.0]:
		var joint := MeshInstance3D.new()
		joint.name = "Shoulder_L" if side < 0.0 else "Shoulder_R"
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 16
		mesh.rings = 8
		joint.mesh = mesh
		# Much smaller, and lower, than it was.
		#
		# It used to be 0.20 x 0.17 x 0.18 sitting at 0.255 — a ball the size of
		# the head perched on each corner, because it was covering a real gap:
		# the torso profile narrowed at the top and the arm tapered at the top,
		# so there was daylight between them and something had to fill it.
		# `BodyMesh.torso` now has a shoulder line as its widest ring and
		# `BodyMesh.arm` has a deltoid as its thickest, so the two meet on their
		# own. What is left here is a joint, not a patch.
		joint.position = Vector3(side * 0.228, 0.196, 0.0)
		joint.scale = Vector3(0.118, 0.108, 0.116) * build_factor
		joint.material_override = _zone_material("torso", _flesh, "flesh")
		torso.add_child(joint)
		shoulders["left_arm" if side < 0.0 else "right_arm"] = joint
		var clavicle := MeshInstance3D.new()
		clavicle.name = "Clavicle_L" if side < 0.0 else "Clavicle_R"
		# A collarbone under the skin, not a plate on top of it.
		#
		# At 0.23 x 0.055 x 0.09 sitting at 0.20 this was a rectangular slab
		# standing proud of each shoulder — fine when the torso was narrow there
		# and something had to bridge the gap, and a visible boxy flap now that
		# the torso has a real shoulder line of its own. Narrowed, thinned,
		# pulled inboard and forward so it reads as the ridge of a clavicle
		# under the surface.
		var bridge := BoxMesh.new()
		bridge.size = Vector3(0.155, 0.030, 0.052)
		clavicle.mesh = bridge
		clavicle.position = Vector3(side * 0.105, 0.222, -0.062)
		clavicle.rotation.z = side * -0.16
		clavicle.material_override = _zone_material("torso", _flesh.lightened(0.025), "flesh")
		torso.add_child(clavicle)


## Where a blow actually landed, rather than a round-robin through the zone
## list. This is the difference between hit geometry and a hit counter.
func zone_nearest(global_point: Vector3) -> String:
	var best := "torso"
	var best_distance := INF
	for zone_id in parts:
		var part := parts[zone_id] as Node3D
		if part == null or not is_instance_valid(part) or severed.has(zone_id):
			continue
		var distance: float = part.global_position.distance_to(global_point)
		if distance < best_distance:
			best_distance = distance
			best = str(zone_id)
	return best


## D4.2. Offsets scale along with sizes, which is what keeps the feet on the
## floor: the legs sit at half their own height above the origin, so scaling
## both grows the whole silhouette upward from the ground rather than sinking
## a big body into it.
func _scaled_layout(source: Dictionary) -> Dictionary:
	if is_equal_approx(build_factor, 1.0):
		return source.duplicate(true)
	var out := {}
	for zone_id in source:
		var spec: Dictionary = source[zone_id]
		out[zone_id] = {
			"at": (spec.at as Vector3) * build_factor,
			"size": (spec.size as Vector3) * build_factor,
		}
	return out


## Organs hang off the zone that contains them, so they ride the body and both
## the seated and standing layouts place them without a second table. They are
## hidden until something opens the body or the X-ray asks to see them.
func _build_organs() -> void:
	for organ_id in ORGAN_LAYOUT:
		var spec: Dictionary = ORGAN_LAYOUT[organ_id]
		var host := parts.get(spec.zone) as Node3D
		if host == null:
			continue
		var organ := MeshInstance3D.new()
		organ.name = "organ_%s" % organ_id
		var mesh := SphereMesh.new()
		# Organs are inside a body, so they are the size that body is.
		mesh.radius = float(spec.size) * build_factor
		mesh.height = mesh.radius * (2.6 if organ_id == "spine" else 2.0)
		mesh.material = WorldLook.surface(Color(str(spec.tint)), "bone" if organ_id == "spine" else "flesh", _variation + ORGAN_LAYOUT.keys().find(organ_id))
		organ.mesh = mesh
		organ.position = (spec.at as Vector3) * build_factor
		organ.visible = false
		host.add_child(organ)
		organ_parts[organ_id] = organ


## Which organ a blade actually reached. Without this, a torso hit is a torso
## hit and the difference between a gut wound and a heart shot is invented.
func organ_nearest(global_point: Vector3) -> String:
	var best := ""
	var best_distance := INF
	for organ_id in organ_parts:
		var organ := organ_parts[organ_id] as Node3D
		if organ == null or not is_instance_valid(organ) or not organ.is_inside_tree():
			continue
		if not anatomy.organ_ok(organ_id):
			continue
		var distance: float = organ.global_position.distance_to(global_point)
		if distance < best_distance:
			best_distance = distance
			best = str(organ_id)
	return best


func _organ_in_zone(zone_id: String) -> String:
	var candidates: Array[String] = []
	for organ_id in ORGAN_LAYOUT:
		if str((ORGAN_LAYOUT[organ_id] as Dictionary).zone) == zone_id and anatomy.organ_ok(organ_id):
			candidates.append(str(organ_id))
	return candidates[randi() % candidates.size()] if not candidates.is_empty() else ""


## A skeleton under the flesh. It is what the X-ray reads, what shows through a
## zone whose flesh has failed, and what is left sticking out of a stump.
func _build_bones(layout: Dictionary) -> void:
	for zone_id in ZONES:
		var host := parts.get(zone_id) as Node3D
		if host == null:
			continue
		var spec: Dictionary = layout[zone_id]
		var frame := Node3D.new()
		frame.name = "%s_bone" % zone_id
		frame.visible = false
		host.add_child(frame)
		bones[zone_id] = frame
		var length: float = (spec.size as Vector3).z if _leg_points_forward(zone_id) else (spec.size as Vector3).y
		match zone_id:
			"head":
				_bone_piece(frame, BodyMesh.skull((spec.size as Vector3).y), Vector3.ZERO)
			"torso":
				# The rig carries all 33 vertebrae, rather than a decorative handful.
				# They stay legible as a continuous column at normal camera distance.
				for index in SPINE_VERTEBRAE:
					var fraction := float(index) / float(SPINE_VERTEBRAE - 1)
					var vertebra := _bone_piece(frame, BodyMesh.vertebra(), Vector3(0, lerpf(length * 0.43, -length * 0.43, fraction), -0.072))
					vertebra.set_meta("vertebra", index + 1)
				for index in 5:
					var rib := _bone_piece(frame, BodyMesh.arc_tube(0.148, 0.098, 0.011, PI * 0.12, PI * 0.88), Vector3(0, length * 0.30 - index * 0.052, -0.012))
					rib.rotation.x = 0.14
			_:
				_bone_piece(frame, BodyMesh.long_bone(length * 0.92, 0.019), Vector3.ZERO)


func _bone_piece(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.position = at
	piece.material_override = _zone_material("torso", BONE, "bone")
	parent.add_child(piece)
	return piece


## Shows what is inside without cutting it open. The X-ray dossier drives this.
func reveal_organs(revealed: bool) -> void:
	_xray = revealed
	for organ_id in organ_parts:
		var organ := organ_parts[organ_id] as Node3D
		if organ != null and is_instance_valid(organ) and anatomy.organ_ok(organ_id):
			organ.visible = revealed
	for zone_id in bones:
		var bone := bones[zone_id] as Node3D
		if bone != null and is_instance_valid(bone):
			bone.visible = revealed or (not severed.has(zone_id) and zone_health(zone_id) < AnatomyComponent.DEFAULT_ZONES[zone_id].health * FRACTURE_RATIO)
	for zone_id in parts:
		var part := parts[zone_id] as MeshInstance3D
		if part != null and is_instance_valid(part) and not severed.has(zone_id):
			part.transparency = 0.62 if revealed else 0.0


## B3.4. Seeing into a body is not worth much if the shed in front of it still
## wins the depth test — that is a highlight, not an X-ray. While the world
## sweep has hold of this body its skeleton and organs draw over whatever is
## between it and the viewer, and go back to behaving normally afterwards.
func see_through(enabled: bool) -> void:
	for zone_id in bones:
		var frame := bones[zone_id] as Node3D
		if frame == null or not is_instance_valid(frame):
			continue
		for piece in frame.get_children():
			_set_depth_override(piece as MeshInstance3D, enabled)
	for organ_id in organ_parts:
		_set_depth_override(organ_parts[organ_id] as MeshInstance3D, enabled)


func _set_depth_override(piece: MeshInstance3D, enabled: bool) -> void:
	if piece == null or not is_instance_valid(piece):
		return
	var material := piece.material_override as StandardMaterial3D
	if material == null and piece.mesh is PrimitiveMesh:
		# Organs carry their material on the mesh rather than as an override.
		material = (piece.mesh as PrimitiveMesh).material as StandardMaterial3D
	if material == null:
		return
	material.no_depth_test = enabled
	material.render_priority = 4 if enabled else 0


func hit(zone_id: String, damage: float, impulse: float, damage_type := "blunt", organ_id := "", hit_direction := Vector3.ZERO) -> Dictionary:
	var zone := canonical_zone(zone_id)
	if severed.has(zone) and not anatomy.installed_parts.has(zone):
		return {"accepted": false, "reason": "severed", "zone": zone, "severed": false}
	var penetrates := damage_type in ["cut", "puncture", "ballistic", "shear"]
	if penetrates and organ_id.is_empty():
		organ_id = _organ_in_zone(zone)
	var result := anatomy.apply_hit(zone, damage, impulse, damage_type, organ_id)
	var direction := _resolved_hit_direction(zone, hit_direction)
	var did_sever := _accumulate_sever_stress(zone, float(result.get("damage", 0.0)), damage_type, direction)
	if did_sever:
		_sever_zone(zone, direction, result)
	else:
		_refresh_zone(zone)
	result["severed"] = did_sever
	result["sever_stress"] = snappedf(float(sever_stress.get(zone, 0.0)), 0.1)
	if gore and damage >= 5.0:
		# Something that cuts opens you up; something that hits you bruises and
		# breaks. The wet count follows from which one landed.
		var penetrating := damage_type in ["cut", "puncture", "ballistic", "shear"]
		_spray(_zone_origin(zone), (direction * 0.55 + Vector3.UP).normalized(), clampi(roundi(damage / (2.1 if penetrating else 4.4)), 3, 26))
		_shed_chunks(zone, damage, damage_type, organ_id, direction)
		# _shed_chunks just raised zone_depth (B4.3); refresh again so the layer
		# exposure mark (B4.5) reads the hit that just happened rather than the
		# one before it.
		if not did_sever:
			_refresh_zone(zone)
	if bool(result.get("disabled", false)):
		zone_disabled.emit(zone)
	return result


func _resolved_hit_direction(zone: String, hit_direction: Vector3) -> Vector3:
	if hit_direction.length_squared() > 0.001:
		return hit_direction.normalized()
	var outward := _zone_origin(zone) - global_position
	outward.y = 0.0
	return outward.normalized() if outward.length_squared() > 0.001 else Vector3.RIGHT


func _accumulate_sever_stress(zone: String, damage: float, damage_type: String, direction: Vector3) -> bool:
	if not LIMBS.has(zone) or anatomy.installed_parts.has(zone) or not SEVERING_DAMAGE.has(damage_type):
		return false
	var directionality := lerpf(0.35, 1.0, 1.0 - absf(direction.dot(Vector3.UP)))
	var damage_weight := 1.35 if damage_type == "shear" else (0.75 if damage_type == "ballistic" else 1.0)
	var stress := float(sever_stress.get(zone, 0.0)) + damage * damage_weight * directionality
	sever_stress[zone] = stress
	var ceiling := float(AnatomyComponent.DEFAULT_ZONES[zone].health)
	var remaining_ratio := zone_health(zone) / maxf(1.0, ceiling)
	return not severed.has(zone) and remaining_ratio <= SEVER_HEALTH_RATIO and stress >= ceiling * SEVER_THRESHOLD_RATIO


func _sever_zone(zone: String, direction: Vector3, result: Dictionary) -> void:
	if severed.has(zone):
		return
	var zone_state: Dictionary = anatomy.zones.get(zone, {})
	if not zone_state.is_empty():
		zone_state["health"] = 0.0
		anatomy.zones[zone] = zone_state
	severed.append(zone)
	result["disabled"] = true
	result["severed"] = true
	result["sever_direction"] = direction
	# B6.6. An open stump is the fastest way to bleed out in this game. The blow
	# that took the limb has already added its own wound bleed; this is the
	# vessel that is now simply open, and it is why losing an arm and walking it
	# off is not a survivable plan for anyone, the player included.
	anatomy.bleed_rate += float(AnatomyComponent.DEFAULT_ZONES[zone].bleed) * STUMP_BLEED
	if gore:
		_throw_limb(zone, direction)
		_add_stump(zone)
		_spray(_zone_origin(zone), (direction + Vector3.UP * 0.65).normalized(), 18)
	_refresh_zone(zone)
	limb_severed.emit(zone, result.duplicate(true))


## Throws the layers a blow actually went through, with the pieces carrying
## which person and which part of them they came off. Kept next to `_spray`
## rather than inside `GoreChunks` because only the rig knows the zone geometry,
## the installed hardware and how opened the zone already was.
func _shed_chunks(zone: String, damage: float, damage_type: String, organ_id: String, hit_direction := Vector3.ZERO) -> void:
	var maximum: float = float((AnatomyComponent.DEFAULT_ZONES.get(zone, {}) as Dictionary).get("health", 100.0))
	var ratio := clampf(zone_health(zone) / maxf(1.0, maximum), 0.0, 1.0)
	var depth := GoreChunks.depth_for(damage, damage_type, ratio)
	zone_depth[zone] = maxi(int(zone_depth.get(zone, 0)), depth)
	var installed: Dictionary = anatomy.installed_parts.get(zone, {})
	var origin := _zone_origin(zone)
	# Away from the body's own centre line, so pieces leave the wound rather
	# than falling straight through the torso they came out of.
	var outward := (origin - global_position)
	outward.y = 0.0
	if outward.length() < 0.05:
		outward = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	var force_direction := hit_direction.normalized() if hit_direction.length_squared() > 0.001 else outward.normalized()
	var heading := (force_direction * 0.7 + Vector3.UP * 0.8).normalized()
	GoreChunks.burst(self, origin, heading, {
		"depth": depth,
		"zone": zone,
		"subject_id": anatomy.subject_id,
		"organ_id": organ_id,
		"implant": str(installed.get("name", installed.get("id", ""))),
	}, detail)


## How far into a zone this body has been opened, as a `GoreChunks.Layer`.
func exposed_layer(zone_id: String) -> int:
	return int(zone_depth.get(canonical_zone(zone_id), 0))


## Opens a zone to a given layer without a blow landing — what digging into a
## body does (B5.2). Ratchets like `_shed_chunks` does, so an extraction can
## never un-open something the fight already opened further.
func mark_opened(zone_id: String, layer: int) -> int:
	var zone := canonical_zone(zone_id)
	zone_depth[zone] = maxi(int(zone_depth.get(zone, 0)), clampi(layer, 0, GoreChunks.Layer.CYBERNETIC))
	_refresh_zone(zone)
	return int(zone_depth[zone])


## `penetration` is the round's own figure from `Ballistics.CALIBRES` — the one
## that has been carried in every round's payload since ballistics was written
## and never read by anything. Left at -1 it is derived from the damage type, so
## every existing caller keeps working and a caller that knows what it fired
## gets a wound that reflects it.
func hit_at(global_point: Vector3, damage: float, impulse: float, damage_type := "blunt", hit_direction := Vector3.ZERO, penetration := -1.0) -> Dictionary:
	var zone := zone_nearest(global_point)
	# Kept before `hit()` resolves, because `hit()` may sever the limb and the
	# point has to be recorded against the limb that was actually struck.
	_record_wound(zone, global_point, hit_direction, damage, damage_type, penetration)
	var organ_id := ""
	if damage_type in ["cut", "puncture", "ballistic", "shear"]:
		organ_id = organ_nearest(global_point)
		# The nearest organ overall can sit in a different zone than the nearest
		# surface, so keep the two answers consistent with each other.
		if not organ_id.is_empty() and str((ORGAN_LAYOUT[organ_id] as Dictionary).zone) != zone:
			organ_id = _organ_in_zone(zone)
	return hit(zone, damage, impulse, damage_type, organ_id, hit_direction)


## O3.2. An injured body has to *look* injured.
##
## The mechanics of limb damage were already in: `mobility_ratio()` slows a
## broken leg and `combat_ratio()` weakens a broken arm, and both have driven
## movement and damage for a while. But nothing showed until a limb actually
## came off, so in every ordinary fight — which is nearly all of them — a man
## with a shattered forearm stood exactly like a man who had just walked in.
## The anatomy was doing real work the player could not see, which is the same
## as it not happening.
##
## This poses the rig off the anatomy: a hurt arm hangs and the shoulder drops,
## a hurt leg takes less weight and the body leans off it, and someone losing
## consciousness stops holding their head up. Called whenever damage lands, not
## per frame — it is a pose, not an animation.
func favour_injuries() -> void:
	if anatomy == null:
		return
	for zone_id: String in ["left_arm", "right_arm"]:
		var part := parts.get(zone_id) as Node3D
		if part == null or not is_instance_valid(part) or severed.has(zone_id):
			continue
		var hurt := 1.0 - _zone_fraction(zone_id)
		var side := -1.0 if zone_id == "left_arm" else 1.0
		# The arm hangs: it rotates out and down, and the whole limb drops.
		part.rotation.z = side * hurt * 0.55
		part.position.y = _rest_y(zone_id) - hurt * 0.11
	for zone_id: String in ["left_leg", "right_leg"]:
		var part := parts.get(zone_id) as Node3D
		if part == null or not is_instance_valid(part) or severed.has(zone_id):
			continue
		var hurt := 1.0 - _zone_fraction(zone_id)
		# A leg that cannot take weight trails, and the body sinks toward the
		# good side rather than standing square.
		part.rotation.x = hurt * 0.3
		part.position.y = _rest_y(zone_id) - hurt * 0.06
	var torso := parts.get("torso") as Node3D
	if torso != null and is_instance_valid(torso):
		# Leaning off whichever leg hurts more. This is the one that reads at
		# distance, because a silhouette that is not plumb is visibly wrong.
		var lean := (_zone_fraction("right_leg") - _zone_fraction("left_leg")) * 0.18
		torso.rotation.z = lean
	var head := parts.get("head") as Node3D
	if head != null and is_instance_valid(head):
		var fading := clampf(1.0 - anatomy.consciousness / 100.0, 0.0, 1.0)
		head.rotation.x = fading * 0.42
		head.rotation.z = fading * 0.2


func _zone_fraction(zone_id: String) -> float:
	var maximum: float = float((AnatomyComponent.DEFAULT_ZONES.get(zone_id, {}) as Dictionary).get("health", 100.0))
	return clampf(zone_health(zone_id) / maxf(maximum, 1.0), 0.0, 1.0)


## Where a part sits when nothing is wrong with it, remembered the first time it
## is asked so repeated posing cannot drift the body downward.
func _rest_y(zone_id: String) -> float:
	if not _rest_heights.has(zone_id):
		var part := parts.get(zone_id) as Node3D
		_rest_heights[zone_id] = part.position.y if part != null and is_instance_valid(part) else 0.0
	return float(_rest_heights[zone_id])


func is_downed() -> bool:
	return anatomy.downed and not anatomy.dead


## Tips over the feet rather than moving the rig, because the owner controls
## where the body sits — inside a cab, on a controller — and fighting them for
## the position would put the body through the floor.
func _on_went_down() -> void:
	if _knockdown_tween != null and _knockdown_tween.is_valid():
		_knockdown_tween.kill()
	# Preserve the established direct pose for every owner that did not opt into
	# sandbox travel.  Vehicles and the anatomy regression suite deliberately
	# inspect this state on the same frame the body goes down.
	if _knockdown_travel <= 0.0:
		rotation.x = -PI * 0.46
		went_down.emit()
		return
	# Pivot at the feet and travel in the fall direction.  This keeps a rig at
	# the y supplied by its owner (the floor is still y=0 in the sandbox) rather
	# than adding a fake vertical offset that makes corpses hover or tunnel.
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var landed := position + forward * _knockdown_travel
	_knockdown_tween = create_tween().set_parallel(true)
	_knockdown_tween.tween_property(self, "rotation:x", -PI * 0.46, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _knockdown_travel > 0.0:
		_knockdown_tween.tween_property(self, "position", landed, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	went_down.emit()


## B2.7v2. This uses the anatomy's shared posture answer, rather than making
## every caller invent a limp. It is a visible state of the rig and therefore
## applies equally to a rival, a derby driver, and the player body.
func _apply_pain_posture(delta: float) -> void:
	if anatomy == null or anatomy.downed or anatomy.dead:
		return
	var posture := anatomy.posture()
	var ease := clampf(delta * 8.0, 0.0, 1.0)
	rotation.x = lerpf(rotation.x, float(posture.hunch), ease)
	rotation.z = lerpf(rotation.z, float(posture.lean), ease)


## The resolutions the downed window exists for. Each is a different answer to
## the same question, and each leaves the world in a different state.
func execute(method := "executed") -> void:
	if anatomy.dead:
		return
	if method == "behead":
		behead()
		return
	if gore:
		_spray(_zone_origin("torso"), Vector3.UP, 16)
	anatomy.finish(method)
	resolved.emit(method)


func behead() -> void:
	if severed.has("head"):
		return
	var head := anatomy.zones.get("head", {}) as Dictionary
	if not head.is_empty():
		head["health"] = 0.0
		anatomy.zones["head"] = head
	severed.append("head")
	if gore:
		_shed_chunks("head", 90.0, "shear", "brain")
	if gore:
		_throw_limb("head")
		_spray(_zone_origin("head"), Vector3.UP, 24)
	var part := parts.get("head") as Node3D
	if part != null and is_instance_valid(part):
		part.visible = false
	anatomy.finish("beheaded")
	resolved.emit("behead")


## Sparing costs the winner nothing and leaves a living witness with a memory,
## which is the expensive part.
func spare() -> void:
	if anatomy.dead:
		return
	anatomy.stabilise()
	rotation.x = 0.0
	resolved.emit("spared")


func _hide_organ(organ_id: String) -> void:
	var organ := organ_parts.get(organ_id) as Node3D
	if organ != null and is_instance_valid(organ):
		organ.visible = false


## A ruptured organ leaves the body. This is the difference between a torso hit
## and a specific, legible wound the dossier can report afterwards.
func _on_organ_ruptured(organ_id: String, _organ: Dictionary) -> void:
	if not gore:
		_hide_organ(organ_id)
		return
	var spec: Dictionary = ORGAN_LAYOUT.get(organ_id, {})
	var organ := organ_parts.get(organ_id) as Node3D
	var origin := organ.global_position if organ != null and is_instance_valid(organ) and organ.is_inside_tree() else _zone_origin("torso")
	_hide_organ(organ_id)
	_spray(origin, Vector3.UP, 12)
	if spec.is_empty() or live_gore >= live_gore_budget():
		return
	var root := _gore_root()
	var loose_organ := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = float(spec.size) * 1.05
	mesh.height = mesh.radius * 2.2
	mesh.material = WorldLook.surface(Color(str(spec.tint)), "flesh", _variation + 21)
	loose_organ.mesh = mesh
	root.add_child(loose_organ)
	loose_organ.global_position = origin
	var spill := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 0.8), randf_range(-1.0, 1.0)).normalized()
	_loose.append({"node": loose_organ, "velocity": spill * (2.2 + randf() * 2.4), "life": 9.0})
	live_gore += 1


func install_prosthetic(zone_id: String, part_data: Dictionary) -> void:
	var zone := canonical_zone(zone_id)
	var installed := anatomy.install_part(zone, part_data)
	# A replacement limb restores function; it does not restore the person.
	var restored := float(installed.get("restores", 0.6))
	var zone_state: Dictionary = anatomy.zones.get(zone, {})
	if not zone_state.is_empty():
		var ceiling := float(AnatomyComponent.DEFAULT_ZONES[zone].health)
		zone_state["health"] = maxf(float(zone_state.health), ceiling * clampf(restored, 0.0, 1.0))
		anatomy.zones[zone] = zone_state
	severed.erase(zone)
	sever_stress.erase(zone)
	_refresh_zone(zone)


## Mount visible hardware without claiming it replaces a missing limb. Rival
## adaptations use this for an impact cage over a remembered wound or support
## around a ruptured organ; `install_prosthetic()` remains the stronger operation
## that restores function and removes a zone from the severed set.
func install_hardware(zone_id: String, part_data: Dictionary) -> void:
	var zone := canonical_zone(zone_id)
	anatomy.install_part(zone, part_data)
	_refresh_zone(zone)


func snapshot() -> Dictionary:
	var state := anatomy.snapshot()
	state["severed"] = severed.duplicate()
	state["sever_stress"] = sever_stress.duplicate(true)
	state["zone_depth"] = zone_depth.duplicate(true)
	# B10.2. Until this line a body's snapshot was eighteen keys of statistics
	# and not one mark: it saved the health the arm had left and lost the hole
	# in the arm. Everything B10.4 built — the real impact point, kept in the
	# limb's own space, drawn where it landed — existed only for as long as the
	# rig did, so every load rebuilt an unmarked body carrying a damage number.
	state["wound_marks"] = WoundMarks.to_records(wound_marks)
	return state


## Everything in a `snapshot()` that is a mark rather than a measurement. A
## whitelist rather than a list of things to strip, so a new statistic added to
## `AnatomyComponent.snapshot()` does not silently start surviving restarts
## because nobody remembered to add it to a denylist.
const SCAR_KEYS := ["wound_marks", "zone_depth", "severed", "cybernetics"]


## What a body carries across a quantum restart, as opposed to across a load.
##
## B10.2, both halves load-bearing. A scar is *located, visible and permanent*:
## the hole, where it is, how deep the limb was opened to, the arm that is not
## there any more, the hardware bolted into what is left. A statistic is a
## number describing the condition the body is in right now — health, blood,
## pain, consciousness, dose, whether it was on the floor, how close a limb was
## to coming off — and none of those are a mark on anything.
##
## Carrying the statistics is the easy accident, because they are most of what
## `snapshot()` is made of. It produces exactly the wrong body: one that arrives
## in a new universe still bleeding out from a wound that is not in this world,
## and with no hole where that wound was.
##
## A load is the other operation and is deliberately untouched by this: picking
## a save back up has to return the body exactly as it was put down, statistics
## included, or every slot in the game quietly heals whoever is in it.
static func scars_of(state: Dictionary) -> Dictionary:
	var scars := {}
	for key: String in SCAR_KEYS:
		if state.has(key):
			var value: Variant = state[key]
			scars[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return scars


## The rig this person's papers describe.
##
## B10.1: "the body is recognisably itself across a quantum restart". What makes
## a body recognisable is not its health — it is the authored shape. The race's
## build is a silhouette, the face seeds the generated head, the wear darkens
## the skin, the blood type is how much of it there is, and the hardware is what
## was grown around. All of that already lived on the subject record; the
## derivation from record to rig lived inside the hunt scene, so nothing else in
## the game could build the same body from the same papers, and no test could
## ask whether two bodies built either side of a restart were the same one.
##
## D, whose work this is, is the reason there is anything here to carry: the
## intake collected a face, a wear level, a blood type and whatever you were
## grown with, and the body read none of it — every player walked out of the vat
## the same colour, the same blood, and wearing a hardcoded torque arm whatever
## the sheet said. Greg's report was "nothing with the character creation
## modelling gets made". A body that is the same as every other body cannot be
## recognisably itself across anything.
static func config_from_subject(record: Dictionary) -> Dictionary:
	var race: Dictionary = CharacterSheet.RACES.get(str(record.get("race", "decanted")), {})
	var appearance: Dictionary = record.get("appearance", {}) if record.get("appearance") is Dictionary else {}
	var sheet_anatomy: Dictionary = record.get("anatomy", {}) if record.get("anatomy") is Dictionary else {}
	var wear := clampf(float(appearance.get("wear", 0.4)), 0.0, 1.0)
	var config := {
		# Face drives the rig's procedural variation, so two players with
		# different faces are not the same generated head.
		"variation": 1 + int(clampf(float(appearance.get("face", 0.5)), 0.0, 1.0) * 24.0),
		"flesh": Color("7a6350").darkened(wear * 0.35),
		"blood": blood_volume(str(sheet_anatomy.get("blood_type", "O-RUST"))),
		"build": float(race.get("build", 1.0)),
		"cybernetics": grown_cybernetics(sheet_anatomy),
	}
	if record.get("anatomy_state") is Dictionary:
		config["restore"] = record.anatomy_state
	return config


## Blood type is a choice on the intake sheet, so it has to mean something.
## Volumes are small differences rather than build-defining ones: a NULL carrier
## bleeds out faster than an O-RUST and that is the whole of it.
static func blood_volume(blood_type: String) -> float:
	match blood_type:
		"NULL": return 4200.0
		"SAP": return 5800.0
		"AB-": return 4900.0
		"B-9": return 5100.0
		"A-ASH": return 5000.0
		_: return 5200.0


## What you were grown with, rather than a hardcoded arm. An empty sheet still
## gets the salvaged torque arm, because the opening hands you one either way
## and a body with no history at all is not this game.
static func grown_cybernetics(sheet_anatomy: Dictionary) -> Dictionary:
	var grown: Dictionary = {}
	var listed: Variant = sheet_anatomy.get("cybernetics", [])
	for entry in ImplantCatalog.list(listed):
		grown[str(entry.zone)] = {
			"name": str(entry.name),
			"armor": float(entry.get("armor", 0.1)),
			"restores": 0.7,
		}
	if grown.is_empty():
		grown["right_arm"] = {"name": "salvaged torque arm", "armor": 0.22, "restores": 0.72}
	return grown


func zone_health(zone_id: String) -> float:
	var zone: Dictionary = anatomy.zones.get(canonical_zone(zone_id), {})
	return float(zone.get("health", 0.0))


## B6.1. What this limb can do, asked of the rig rather than of the anatomy
## component alone — because the component knows what is installed and in
## what condition, and only the rig knows whether the limb is still attached.
## That split is the item's own "through the anatomy rather than around it":
## a capability is the hardware's, but it is vetoed by the body.
##
## B6.2 falls straight out of it: a severed limb answers `false` to
## everything from the moment it comes off, with nothing needing to remember
## to go and switch a separate ability flag off.
func limb_can(zone_id: String, capability: String) -> bool:
	var zone := canonical_zone(zone_id)
	if severed.has(zone):
		return false
	return anatomy.limb_can(zone, capability)


## Every limb still attached to this body that can do the thing. Ordered
## arms before legs and left before right, the same stable order `_worst_limb`
## uses, so the same body reaches with the same arm twice rather than
## flickering between two equally-capable ones.
func capable_limbs(capability: String) -> Array[String]:
	var out: Array[String] = []
	for zone_id in ["left_arm", "right_arm", "left_leg", "right_leg"]:
		if limb_can(zone_id, capability):
			out.append(zone_id)
	return out


## Proportioned geometry rather than primitives. A capsule cannot express the
## difference between a chest and a forearm, and that difference is most of what
## makes a body read as a body.
func _zone_mesh(zone_id: String, size: Vector3) -> Mesh:
	var length := size.z if _leg_points_forward(zone_id) else size.y
	match zone_id:
		"head":
			return BodyMesh.head(size.y)
		"torso":
			return BodyMesh.torso(size.y)
		"left_arm", "right_arm":
			return BodyMesh.arm(length)
		_:
			return BodyMesh.leg(length)


## Seated legs run forward out of the hip rather than down from it, so the
## generated limb is swept along Z instead of Y.
func _leg_points_forward(zone_id: String) -> bool:
	return _seated and zone_id.ends_with("_leg")


func _zone_material(zone_id: String, tint: Color, kind := "flesh") -> StandardMaterial3D:
	var material := WorldLook.surface(tint, kind, _variation + ZONES.find(zone_id))
	# Generated surfaces are open where a limb has been taken off, and the
	# insides are supposed to be visible when they are.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Damage reads on the body itself: a zone darkens as it fails, and a limb that
## reaches zero comes off rather than staying attached at full brightness.
func _refresh_zone(zone_id: String) -> void:
	var part := parts.get(zone_id) as MeshInstance3D
	if part == null or not is_instance_valid(part):
		return
	var zone: Dictionary = anatomy.zones.get(zone_id, {})
	if zone.is_empty():
		return
	var ceiling := float(AnatomyComponent.DEFAULT_ZONES[zone_id].health)
	var ratio := clampf(float(zone.health) / maxf(ceiling, 1.0), 0.0, 1.0)
	var prosthetic := anatomy.installed_parts.has(zone_id)
	# Damage arrives as bruising long before it arrives as blood. Going straight
	# from clean flesh to dark red meant a body took a beating and showed
	# nothing until it was nearly ruined, which is most of why punches read as
	# having no effect.
	var tint := Color("8d9299")
	if not prosthetic:
		if ratio > BRUISE_RATIO:
			var bruising := (1.0 - ratio) / maxf(1.0 - BRUISE_RATIO, 0.01)
			tint = _flesh.lerp(BRUISE_SKIN, bruising * 0.85)
		else:
			var opened := 1.0 - ratio / maxf(BRUISE_RATIO, 0.01)
			tint = _flesh.lerp(BRUISE_SKIN, 0.85).lerp(Color("3d0907"), opened)
	_show_installed(zone_id, prosthetic)
	# B3.2. A melting injury does not read as a bruise going dark. Dose takes
	# the zone toward a wet, sallow green and takes the volume out of it — a
	# dosed limb slumps rather than swells — so that a body somebody irradiated
	# is distinguishable at a glance from a body somebody beat, which is the
	# difference this segment asks the rig to show.
	var dosed := anatomy.dose_ratio(zone_id) if anatomy.has_method("dose_ratio") else 0.0
	if dosed > 0.0 and not prosthetic:
		tint = tint.lerp(MELTED_SKIN, clampf(dosed * 1.35, 0.0, 0.9))
	part.material_override = _zone_material(zone_id, tint, "chrome" if prosthetic else "flesh")
	if dosed > 0.0 and not prosthetic:
		var melted_material := part.material_override as StandardMaterial3D
		# Wet where it is worst: what is left of the surface is running.
		melted_material.roughness = clampf(melted_material.roughness - dosed * 0.45, 0.05, 1.0)
		var rest: Vector3 = part.get_meta("rest_scale", Vector3.ONE)
		part.scale = rest.lerp(rest * 0.82, clampf(dosed, 0.0, 1.0))
	# Bone shows through where the flesh has failed, without waiting for the
	# limb to come off entirely.
	var bone := bones.get(zone_id) as Node3D
	if bone != null and is_instance_valid(bone) and not _xray:
		# A zone remembers the deepest layer it was ever cut to (B4.3), so bone
		# that has already been shown through does not hide again just because
		# a prosthetic or a lighter later hit raised the current health ratio.
		var ever_to_bone := int(zone_depth.get(zone_id, 0)) >= GoreChunks.Layer.BONE
		var compound := anatomy.fracture_kind(zone_id) == "compound"
		var exposed := (compound or ever_to_bone) and not prosthetic
		bone.visible = exposed
		# Bone inside opaque flesh is bone nobody can see. Ruined flesh goes
		# translucent so the skeleton under it actually reads.
		part.transparency = clampf((FRACTURE_RATIO - ratio) / FRACTURE_RATIO, 0.0, 1.0) * 0.55 if exposed else 0.0
	if gore and anatomy.fracture_kind(zone_id) == "compound" and ratio > 0.0 and not prosthetic:
		_add_fracture(zone_id)
	if severed.has(zone_id) and not prosthetic:
		if gore:
			_add_stump(zone_id)
		part.visible = false
		var hitbox := get_node_or_null("%s_hitbox" % zone_id) as Area3D
		if hitbox != null:
			hitbox.monitorable = false
	else:
		part.visible = true
		var restored := get_node_or_null("%s_hitbox" % zone_id) as Area3D
		if restored != null:
			restored.monitorable = true
		if prosthetic:
			var old_fracture := part.get_node_or_null("Fracture")
			if old_fracture != null:
				old_fracture.queue_free()
			var old_stump := get_node_or_null("%s_stump" % zone_id)
			if old_stump != null:
				old_stump.queue_free()
	if gore and zone_id == "torso" and ratio <= 0.0:
		_spill_guts()
	_update_layer_exposure(zone_id, prosthetic)
	if zone_id == "torso":
		_refresh_spine_vertebrae()


## The X-ray has 33 actual pieces to colour. A damaged vertebra changes from
## bone to hot fracture tone, so the diagnostic number and the body agree.
func _refresh_spine_vertebrae() -> void:
	var frame := bones.get("torso") as Node3D
	if frame == null or anatomy == null:
		return
	var spine: Dictionary = anatomy.organs.get("spine", {})
	var damaged: Array = spine.get("vertebrae_damaged", [])
	for piece in frame.get_children():
		if not piece.has_meta("vertebra"):
			continue
		var vertebra := int(piece.get_meta("vertebra"))
		var mesh := piece as MeshInstance3D
		if mesh != null:
			mesh.material_override = _zone_material("torso", Color("b94a32") if damaged.has(vertebra) else BONE, "bone")


func _zone_origin(zone_id: String) -> Vector3:
	var part := parts.get(zone_id) as Node3D
	if part != null and is_instance_valid(part) and part.is_inside_tree():
		return part.global_position
	return global_position if is_inside_tree() else Vector3.ZERO


## Gore lives in the world, not on the body, or a driver's blood would ride
## along inside the cab while the car keeps moving.
func _gore_root() -> Node:
	if not is_inside_tree():
		return self
	var scene := get_tree().current_scene
	return scene if scene != null else self


func _spray(origin: Vector3, bias: Vector3, count: int) -> void:
	var root := _gore_root()
	for index in maxi(1, roundi(count * detail)):
		if live_gore >= live_gore_budget():
			return
		var drop := MeshInstance3D.new()
		var blob := SphereMesh.new()
		blob.radius = 0.026 + randf() * 0.046
		blob.height = blob.radius * 2.0
		blob.material = WorldLook.surface(BLOOD if index % 2 == 0 else BLOOD_DARK, "flesh", index + _variation)
		drop.mesh = blob
		root.add_child(drop)
		drop.global_position = origin + Vector3(randf_range(-0.09, 0.09), randf_range(-0.09, 0.09), randf_range(-0.09, 0.09))
		var spread := (bias.normalized() + Vector3(randf_range(-0.75, 0.75), randf_range(0.05, 0.7), randf_range(-0.75, 0.75))).normalized()
		_loose.append({"node": drop, "velocity": spread * (1.9 + randf() * 3.6), "life": 1.3 + randf() * 1.0, "splat": true, "size": blob.radius})
		live_gore += 1


## Organs leave the body once the chest does. They are heavier and wetter than
## spray, so they fall short and stay put rather than misting.
func _spill_guts() -> void:
	if has_meta("gutted"):
		return
	set_meta("gutted", true)
	var root := _gore_root()
	var origin := _zone_origin("torso")
	for index in maxi(2, roundi(8 * detail)):
		if live_gore >= live_gore_budget():
			return
		var organ := MeshInstance3D.new()
		var blob := SphereMesh.new()
		blob.radius = 0.075 + randf() * 0.07
		blob.height = blob.radius * 2.0 * (1.2 + randf() * 0.9)
		blob.material = WorldLook.surface(ORGAN.lerp(BLOOD_DARK, randf()), "flesh", index + _variation + 9)
		organ.mesh = blob
		root.add_child(organ)
		organ.global_position = origin + Vector3(randf_range(-0.12, 0.12), randf_range(-0.1, 0.1), randf_range(-0.12, 0.12))
		var spill := Vector3(randf_range(-1.0, 1.0), randf_range(-0.1, 0.35), randf_range(-1.0, 1.0)).normalized()
		_loose.append({"node": organ, "velocity": spill * (0.8 + randf() * 1.7), "life": 6.0 + randf() * 3.0})
		live_gore += 1


## A compound fracture is permanent. It rides with the limb because it is part
## of the limb now.
func _add_fracture(zone_id: String) -> void:
	var part := parts.get(zone_id) as Node3D
	if part == null or not is_instance_valid(part) or part.has_node("Fracture"):
		return
	var shard := MeshInstance3D.new()
	shard.name = "Fracture"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.042, 0.15 + randf() * 0.11, 0.042)
	mesh.material = WorldLook.surface(BONE, "bone", _variation + 4)
	shard.mesh = mesh
	shard.position = Vector3(randf_range(-0.05, 0.05), randf_range(-0.13, 0.13), 0.07)
	shard.rotation = Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-1.0, 1.0))
	part.add_child(shard)


## B4.5: the zone shows the deepest layer it has ever been cut to, on the body
## itself rather than only in the chunks it shed. Skin, fat, muscle in order -
## bone is handled separately above because a fracture already owns that read.
## Blood leaving the wounds it is actually coming out of.
##
## Driven by `anatomy.bleed_rate` — the same number that decides whether this
## body bleeds to death — so what is on screen is the thing that is killing
## them rather than an effect playing alongside it. See `blood_flow.gd` for why
## this is drops and streaks rather than a fluid solve.
func _bleed(delta: float) -> void:
	if not gore or anatomy == null or anatomy.dead and _loose.is_empty() and _bleed_seconds > 12.0:
		return
	# Internal bleeding is blood going *into* the body, so only a fraction of it
	# shows outside — but it is forty-seven points against an external one or
	# two, so a ruptured organ still reads as a gusher rather than a graze.
	var rate := anatomy.bleed_rate + anatomy.internal_bleed_rate * 0.12
	if rate < BloodFlow.MIN_BLEED:
		return
	var sites := _bleeding_sites()
	if sites.is_empty():
		return
	_bleed_seconds += delta
	_drip_owed += BloodFlow.drops_for(rate, delta)
	while _drip_owed >= 1.0:
		_drip_owed -= 1.0
		_drip_one(sites[randi() % sites.size()])
	_refresh_streaks(sites)


## Every wound currently open enough to run, as {part, at, normal}. A severed
## limb is not in here — its stump bleeds, and the stump is its own zone.
func _bleeding_sites() -> Array:
	var sites: Array = []
	for zone: String in wound_marks.keys():
		if severed.has(zone):
			continue
		var part := parts.get(zone) as Node3D
		if part == null or not is_instance_valid(part) or not part.is_inside_tree():
			continue
		var marks: Array = wound_marks[zone]
		if marks.is_empty():
			continue
		# The worst wound on a limb is the one that runs. A body with fourteen
		# grazes on one arm should not out-bleed one with a hole in it.
		var worst: Dictionary = marks[0]
		for wound: Dictionary in marks:
			if float(wound.get("damage", 0.0)) > float(worst.get("damage", 0.0)):
				worst = wound
		sites.append({"zone": zone, "part": part, "wound": worst})
	return sites


func _drip_one(site: Dictionary) -> void:
	if live_gore >= live_gore_budget():
		return
	var part := site["part"] as Node3D
	var wound: Dictionary = site["wound"]
	var root := _gore_root()
	if root == null or not is_inside_tree():
		return
	var drop := MeshInstance3D.new()
	var blob := SphereMesh.new()
	# Smaller than a spray drop. This is running out, not being thrown out.
	blob.radius = 0.014 + randf() * 0.016
	blob.height = blob.radius * 2.0
	blob.material = WorldLook.surface(BLOOD if randf() > 0.5 else BLOOD_DARK, "flesh", _variation)
	drop.mesh = blob
	root.add_child(drop)
	var normal: Vector3 = wound.get("normal", Vector3.UP)
	drop.global_position = part.to_global(wound.get("at", Vector3.ZERO) as Vector3 + normal * 0.02)
	var velocity: Vector3 = part.global_transform.basis * BloodFlow.drip_velocity(normal)
	# Longer life than a spray drop, because it starts slow and has further to
	# fall before it lands and marks.
	_loose.append({"node": drop, "velocity": velocity, "life": 2.6 + randf() * 1.2, "splat": true, "size": blob.radius})
	live_gore += 1


## The wet runs down the skin. One per bleeding limb, lengthening with time and
## drying as it goes, reusing the node rather than rebuilding it every frame.
func _refresh_streaks(sites: Array) -> void:
	var length := minf(BloodFlow.STREAK_GROWTH * _bleed_seconds, BloodFlow.STREAK_MAX)
	if length < 0.02:
		return
	var age := clampf(_bleed_seconds / 45.0, 0.0, 1.0)
	for site: Dictionary in sites:
		var part := site["part"] as Node3D
		var wound: Dictionary = site["wound"]
		var streak := part.get_node_or_null("BloodStreak") as MeshInstance3D
		if streak == null or not is_instance_valid(streak):
			streak = BloodFlow.build_streak(BloodFlow.STREAK_WIDTH, length, age)
			streak.name = "BloodStreak"
			part.add_child(streak)
		else:
			streak.mesh = BloodFlow.streak_mesh(BloodFlow.STREAK_WIDTH, length)
			streak.material_override = BloodFlow.streak_material(age)
		streak.transform = BloodFlow.streak_transform(
			part, wound.get("at", Vector3.ZERO) as Vector3, wound.get("normal", Vector3.UP) as Vector3, length)


## Keep where a round landed, and show it there.
##
## The single `LayerExposure` flap this replaces sat at a hardcoded local offset
## and only ever showed the deepest layer a limb had been opened to, so six hits
## in six places produced one mark in one place. A body that has been shot six
## times should look like a body that has been shot six times.
## Rough penetration for a hit whose caller did not say what it fired. These are
## the same order as `Ballistics.CALIBRES`: a blade barely crosses tissue, a
## rifle round crosses a body.
const TYPE_PENETRATION := {
	"ballistic": 0.35,
	"shear": 0.50,
	"puncture": 0.30,
	"cut": 0.18,
	"blunt": 0.05,
	"radiation": 0.0,
	"caustic": 0.0,
}


func _record_wound(zone_id: String, global_point: Vector3, travel: Vector3, damage: float, damage_type: String, penetration := -1.0) -> void:
	if damage < WoundMarks.MIN_DAMAGE:
		return
	var zone := canonical_zone(zone_id)
	if severed.has(zone):
		return
	var part := parts.get(zone) as Node3D
	if part == null or not is_instance_valid(part) or not part.is_inside_tree():
		return
	var surface: Dictionary = WoundMarks.surface_of(part, global_point, travel)

	# --- how far in did it get -------------------------------------------
	# Greg's whole ask, in one call: a hand is thin so a round goes through it,
	# an upper arm is not so the same round stops inside. Nothing here knows
	# what a hand is — it asks how much body is at that height and spends the
	# round's budget against it.
	var points: float = penetration if penetration >= 0.0 else float(TYPE_PENETRATION.get(damage_type, 0.2))
	var spec: Dictionary = _layout.get(zone, {})
	var limb_length: float = float((spec.get("size", Vector3(0.2, 0.6, 0.2)) as Vector3).y)
	var local_point: Vector3 = surface["at"]
	var local_travel: Vector3 = (part.global_transform.basis.inverse() * travel) if travel.length_squared() > 0.0001 else Vector3(0, 0, -1)
	var shot: Dictionary = Penetration.resolve(
		zone,
		Penetration.height_fraction(local_point, limb_length),
		Penetration.across_wide_axis(local_travel),
		points,
		anatomy.zone_armor(zone),
		limb_length)
	if int(shot["result"]) == Penetration.Result.STOPPED_BY_ARMOUR:
		# What you are wearing stopped it. No hole in you.
		return
	# The layer is read *after* the hit resolves everywhere else; here it is read
	# before, so a fresh hole shows the depth the body was already opened to and
	# deepens on the next frame's refresh rather than predicting itself.
	var layer := int(zone_depth.get(zone, 0))
	var wound: Dictionary = WoundMarks.make(surface["at"], surface["normal"], damage, damage_type, layer)
	wound["depth"] = shot["fraction"]
	wound["through"] = shot["through"]
	# A hole that nearly went through looks nearly like one that did.
	wound["radius"] = float(wound["radius"]) * lerpf(0.62, 1.0, float(shot["fraction"]))
	wound_marks[zone] = WoundMarks.record(wound_marks.get(zone, []) as Array, wound)

	# --- and out the other side ------------------------------------------
	if bool(shot["through"]):
		var exit_at: Vector3 = local_point - (surface["normal"] as Vector3) * float(shot["thickness"])
		var exit_wound: Dictionary = WoundMarks.make(exit_at, -(surface["normal"] as Vector3), damage, damage_type, layer)
		exit_wound["radius"] = float(exit_wound["radius"]) * WoundMarks.EXIT_SPREAD
		exit_wound["depth"] = 1.0
		exit_wound["through"] = true
		exit_wound["exit"] = true
		wound_marks[zone] = WoundMarks.record(wound_marks.get(zone, []) as Array, exit_wound)

	_refresh_wounds(zone)


## Rebuild a zone's wound meshes. Cheap because a zone is capped at
## `WoundMarks.MAX_PER_ZONE`, and rebuilding beats tracking which of fourteen
## small nodes corresponds to which of fourteen dictionaries.
func _refresh_wounds(zone_id: String) -> void:
	var zone := canonical_zone(zone_id)
	var part := parts.get(zone) as Node3D
	if part == null or not is_instance_valid(part):
		return
	var holder := part.get_node_or_null("Wounds") as Node3D
	if holder != null and is_instance_valid(holder):
		part.remove_child(holder)
		holder.queue_free()
	var marks: Array = wound_marks.get(zone, [])
	if marks.is_empty() or not gore:
		return
	holder = Node3D.new()
	holder.name = "Wounds"
	part.add_child(holder)
	var depth := int(zone_depth.get(zone, 0))
	for wound: Dictionary in marks:
		# A wound never shows a layer deeper than the limb has actually been
		# opened to, so a graze recorded before a blast does not retroactively
		# claim to show bone.
		var shown: int = mini(int(wound.get("layer", 0)), depth)
		var tint := Color(str(GoreChunks.LAYER_TINTS[clampi(shown, 0, GoreChunks.LAYER_TINTS.size() - 1)]))
		holder.add_child(WoundMarks.build(wound, tint))


## Reads `zone_depth`, the same ratchet `_shed_chunks` writes, so this survives
## healing and reattachment exactly the way the remembered depth does.
func _update_layer_exposure(zone_id: String, prosthetic: bool) -> void:
	var part := parts.get(zone_id) as Node3D
	if part == null or not is_instance_valid(part):
		return
	var mark := part.get_node_or_null("LayerExposure") as MeshInstance3D
	var depth := int(zone_depth.get(zone_id, 0))
	if prosthetic or severed.has(zone_id) or depth < GoreChunks.Layer.FAT:
		if mark != null and is_instance_valid(mark):
			# queue_free is deferred; remove_child makes it gone from the tree
			# (and from get_node lookups) immediately rather than next idle frame.
			part.remove_child(mark)
			mark.queue_free()
		return
	if mark == null or not is_instance_valid(mark):
		mark = MeshInstance3D.new()
		mark.name = "LayerExposure"
		var flap := BoxMesh.new()
		flap.size = Vector3(0.10, 0.010, 0.13)
		mark.mesh = flap
		mark.position = Vector3(0.0, 0.02, 0.075)
		part.add_child(mark)
	var shown_depth := mini(depth, GoreChunks.Layer.MUSCLE)
	var tint := Color(str(GoreChunks.LAYER_TINTS[shown_depth]))
	mark.material_override = _zone_material(zone_id, tint, "flesh")


## A limb that comes off is the same geometry that was attached a moment ago,
## handed to the solver with the bone still in it. Hiding the mesh and calling it
## dismemberment is the version that reads as a bug.
func _throw_limb(zone_id: String, hit_direction := Vector3.ZERO) -> void:
	var part := parts.get(zone_id) as MeshInstance3D
	if part == null or not is_instance_valid(part) or not part.is_inside_tree():
		return
	if live_gore >= live_gore_budget():
		return
	var limb := RigidBody3D.new()
	limb.name = "%s_severed" % zone_id
	limb.mass = 5.0
	_gore_root().add_child(limb)
	limb.global_transform = part.global_transform
	var visual := MeshInstance3D.new()
	visual.mesh = part.mesh
	visual.material_override = part.material_override
	limb.add_child(visual)
	# B4.1. Whatever somebody had done to this limb goes with it. A tattoo and a
	# piercing are on the arm, not on the person: the arm lands across the yard
	# still carrying them, and the stump it left behind does not. This is the
	# reason body mods are mounted on the zone meshes rather than painted into
	# the flesh material — ink in a material would survive on a stump, which is
	# the wrong story about what just happened.
	for child in part.get_children():
		if child is MeshInstance3D and (child as Node).has_meta("body_mod"):
			var carried := (child as MeshInstance3D).duplicate() as MeshInstance3D
			visual.add_child(carried)
			carried.transform = (child as MeshInstance3D).transform
			child.queue_free()
	var bone := bones.get(zone_id) as Node3D
	if bone != null and is_instance_valid(bone) and bone.get_child_count() > 0:
		var stub := (bone.get_child(0) as MeshInstance3D).duplicate() as MeshInstance3D
		stub.visible = true
		limb.add_child(stub)
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	var bounds := part.get_aabb()
	shape.radius = maxf(0.05, minf(bounds.size.x, bounds.size.z) * 0.5)
	shape.height = maxf(shape.radius * 2.0 + 0.01, bounds.size.y)
	shape_node.shape = shape
	limb.add_child(shape_node)
	GoreChunks.register_whole_limb(limb, zone_id, anatomy.subject_id)
	var launch := hit_direction.normalized() if hit_direction.length_squared() > 0.001 else Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	limb.apply_central_impulse((launch * 2.25 + Vector3.UP * 2.1) * limb.mass)
	limb.apply_torque_impulse(Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)))
	live_gore += 1
	get_tree().create_timer(90.0).timeout.connect(func():
		live_gore = maxi(0, live_gore - 1)
		GoreChunks.live.erase(limb)
		if is_instance_valid(limb):
			limb.queue_free())


func _add_stump(zone_id: String) -> void:
	if has_node("%s_stump" % zone_id):
		return
	var layout: Dictionary = _layout if not _layout.is_empty() else (SEATED if _seated else STANDING)
	var spec: Dictionary = layout[zone_id]
	var stump := MeshInstance3D.new()
	stump.name = "%s_stump" % zone_id
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.058
	mesh.height = 0.19
	mesh.material = WorldLook.surface(BONE, "bone", _variation + 6)
	stump.mesh = mesh
	# Sit the exposed bone between the torso and where the limb used to be, so
	# it reads as a joint rather than a floating spike.
	stump.position = (spec.at as Vector3).lerp((layout.torso as Dictionary).at as Vector3, 0.45)
	add_child(stump)


func _process(delta: float) -> void:
	# Everything this rig animates runs on the exchange's clock, not the world's.
	var own_delta := delta * motion_scale
	_apply_pain_posture(own_delta)
	_bleed(own_delta)
	if _loose.is_empty():
		return
	delta = own_delta
	for index in range(_loose.size() - 1, -1, -1):
		var piece: Dictionary = _loose[index]
		var node := piece.node as Node3D
		if node == null or not is_instance_valid(node):
			_loose.remove_at(index)
			live_gore = maxi(0, live_gore - 1)
			continue
		piece.velocity.y -= 11.0 * delta
		node.global_position += piece.velocity * delta
		piece.life -= delta
		if piece.life <= 0.0:
			if bool(piece.get("splat", false)):
				_land_splat(node.global_position, float(piece.get("size", 0.05)), piece.velocity)
			node.queue_free()
			_loose.remove_at(index)
			live_gore = maxi(0, live_gore - 1)


## A landed drop becomes a flat mark on the ground that stays for the rest of
## the scene. Oldest marks are recycled rather than accumulating without bound,
## so the floor fills up and then stays full instead of costing more over time.
func _land_splat(at: Vector3, size: float, velocity := Vector3.DOWN) -> void:
	if not gore or detail <= 0.01:
		return
	var root := _gore_root()
	if root == null or not is_inside_tree():
		return

	# Find what the drop actually hit. Stamping every mark onto the y=0 plane
	# put blood under the floor in the derby, under ramps, and inside interiors
	# — which is most of why the gore "hardly works" outside a flat test field.
	# Blood now lands on the surface it reaches and lies along that surface, so
	# it climbs walls and drapes over wreckage.
	var space := get_world_3d().direct_space_state
	var heading := velocity.normalized() if velocity.length_squared() > 0.01 else Vector3.DOWN
	var normal := Vector3.UP
	var landed := Vector3(at.x, 0.02, at.z)
	var query := PhysicsRayQueryParameters3D.create(at - heading * 0.35, at + heading * 1.6)
	query.collide_with_areas = false
	var ground_hit := space.intersect_ray(query)
	if ground_hit.is_empty():
		# Nothing along the flight path: drop it straight down onto whatever is
		# underneath, which is the common case for a drop that ran out of arc.
		var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 4.0)
		down.collide_with_areas = false
		ground_hit = space.intersect_ray(down)
	if not ground_hit.is_empty():
		landed = ground_hit.position
		normal = (ground_hit.normal as Vector3).normalized()
	var splat := MeshInstance3D.new()
	splat.mesh = _splat_mesh(1.0)
	var spread := size * SPLAT_SPREAD * (0.7 + randf() * 0.6)
	# Flat to the ground and jittered, so a pool reads as spatter rather than as
	# a row of identical stamps.
	root.add_child(splat)
	# Lie along the surface, whatever its angle. A fixed -90 degree pitch only
	# ever reads correctly on flat ground.
	var up := normal
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var spin := randf() * TAU
	var forward := up.cross(side).normalized()
	# The size has to be baked into the basis. Setting `splat.scale` and then
	# assigning `global_transform` discards it — an orthonormal basis overwrites
	# the scale — so every mark rendered at 1:1 whatever the caller asked for,
	# which is roughly three metres of blood per landed drop.
	splat.global_transform = Transform3D(
		Basis(side, forward, up).rotated(up, spin).scaled(Vector3.ONE * spread),
		landed + normal * (0.012 + randf() * 0.01)
	)
	splats.append(splat)
	_remember_blood(root, splat)
	while splats.size() > splat_budget():
		var oldest: Node3D = splats.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


## Both scenes read the GORE setting through here, so the Hunt Grounds and the
## derby cannot disagree. They did: only the derby ever applied it, so OFF did
## nothing once the player walked out of the pit, and REDUCED leaked across as a
## static that the hunt never reset.
static func apply_gore_setting() -> bool:
	var mode := str(WorldHistory.subject("settings").get("gore", "FULL"))
	detail = 0.4 if mode == "REDUCED" else 1.0
	return mode != "OFF"


static func clear_gore() -> void:
	for splat in splats:
		if is_instance_valid(splat):
			splat.queue_free()
	splats.clear()
	blood_records.clear()
	live_gore = 0


## Spatter, not tiles. A quad puts four hard corners and a straight edge on the
## ground and reads as red confetti from any angle. This is a ragged fan with
## jittered radii and a couple of thrown outliers, which is what a drop landing
## at speed actually leaves. Meshes are pooled by variation so a floor of four
## hundred marks costs a handful of resources, not four hundred.
## Nine distinct splat shapes was enough when a splat was a blob; with
## satellites each shape is much more recognisable, so a floor of nine repeats
## visibly. Twelve, and they are built once and shared.
const SPLAT_SHAPES := 12
static var _splat_pool: Array[ArrayMesh] = []

## B4.6: a chunk from `GoreChunks` marks the ground the same way a blood drop
## does, at the point it lands or while it is still rolling fast. A free
## function rather than a method so `GoreChunks`, which is not a body, can call
## it without needing an instance.
static func mark_ground_for_chunk(world: World3D, root: Node, at: Vector3, velocity: Vector3, size: float) -> void:
	if root == null or not root.is_inside_tree() or world == null or splats.size() > splat_budget() * 2:
		return
	var space := world.direct_space_state
	var heading := velocity.normalized() if velocity.length_squared() > 0.01 else Vector3.DOWN
	var normal := Vector3.UP
	var landed := Vector3(at.x, 0.02, at.z)
	var query := PhysicsRayQueryParameters3D.create(at - heading * 0.35, at + heading * 1.6)
	query.collide_with_areas = false
	var ground_hit := space.intersect_ray(query)
	if ground_hit.is_empty():
		var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 4.0)
		down.collide_with_areas = false
		ground_hit = space.intersect_ray(down)
	if not ground_hit.is_empty():
		landed = ground_hit.position
		normal = (ground_hit.normal as Vector3).normalized()
	var splat := MeshInstance3D.new()
	splat.mesh = _splat_mesh(1.0)
	var up := normal
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var forward := up.cross(side).normalized()
	# Scale baked in, for the same reason as `_land_splat`.
	splat.global_transform = Transform3D(
		Basis(side, forward, up).rotated(up, randf() * TAU).scaled(Vector3.ONE * size),
		landed + normal * 0.014
	)
	root.add_child(splat)
	splats.append(splat)
	_remember_blood(root, splat)
	while splats.size() > splat_budget():
		var oldest: Node3D = splats.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


static func _blood_scene_key(root: Node) -> String:
	var path := str(root.scene_file_path)
	return path if not path.is_empty() else str(root.name)


static func _remember_blood(root: Node, splat: MeshInstance3D) -> void:
	var key := _blood_scene_key(root)
	var records: Array = blood_records.get(key, [])
	records.append({"transform": splat.global_transform})
	while records.size() > splat_budget():
		records.pop_front()
	blood_records[key] = records


static func restore_blood(root: Node) -> int:
	if root == null or not root.is_inside_tree():
		return 0
	var restored := 0
	for record in blood_records.get(_blood_scene_key(root), []):
		var splat := MeshInstance3D.new()
		splat.mesh = _splat_mesh(1.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = BLOOD_DARK
		material.roughness = 0.92
		splat.material_override = material
		splat.global_transform = record.transform
		root.add_child(splat)
		splats.append(splat)
		restored += 1
	return restored


static func _splat_mesh(radius: float) -> ArrayMesh:
	if _splat_pool.size() >= SPLAT_SHAPES:
		return _splat_pool[randi() % _splat_pool.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = _splat_pool.size() * 7919 + 13
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	# Greg: "make the blood realistic and fun but abstract arty".
	#
	# The arty half is a *decision about lighting*, not about shape. Blood shaded
	# per-pixel like every other surface is a wet brown object lying on the
	# ground, and no amount of silhouette work rescues it — it is competing with
	# the floor on the floor's terms. Drawn flat, it stops being an object and
	# becomes a mark: printed colour on the world, which is the same language the
	# stencil typeface and the sigils already speak. Hence unshaded, with the
	# tonal variation carried in vertex colour instead of in light.
	#
	# The realistic half is the satellites. A drop that lands does not make one
	# blob — it throws a ring of smaller ones out along the direction it was
	# travelling, and that scatter is the single most recognisable thing about
	# real spatter. It is also, conveniently, the most graphic.
	var steps := 17
	var radii: Array[float] = []
	var widest := 0.0
	for step in steps:
		var jitter := rng.randf_range(0.40, 1.0)
		# Every few points throw a long finger, so the outline has runs coming
		# off it rather than being a fuzzy circle.
		if step % 5 == 0:
			jitter *= rng.randf_range(1.4, 2.3)
		widest = maxf(widest, jitter)
		radii.append(jitter)
	# Normalised so `radius` means what it says. It used to be accepted and
	# ignored, leaving the mesh whatever size the jitter happened to make it
	# — up to 2.1 units — which the caller then scaled up again.
	for index in radii.size():
		radii[index] = radii[index] / maxf(0.001, widest) * radius

	# Pooled blood is darkest where it is deepest, which is the middle.
	#
	# Tuned for *unshaded*, which is a different job: with lighting off the
	# vertex colour is the final pixel, so values picked to look right after a
	# key light multiplies them come out washed. The first pass reused BLOOD and
	# BLOOD_DARK straight and the floor went salmon pink. These are deliberately
	# deeper and much more saturated than the lit palette — arterial, not meat.
	var core := Color(0.135, 0.009, 0.011)
	var edge := Color(0.355, 0.026, 0.024)
	for step in steps:
		var a := TAU * float(step) / float(steps)
		var b := TAU * float(step + 1) / float(steps)
		var ra: float = radii[step]
		var rb: float = radii[(step + 1) % steps]
		points.append(Vector3.ZERO)
		points.append(Vector3(cos(a) * ra, sin(a) * ra, 0.0))
		points.append(Vector3(cos(b) * rb, sin(b) * rb, 0.0))
		colors.append(core)
		colors.append(edge)
		colors.append(edge)
		# Without normals the surface has no defined lighting and renders black
		# under the Ashbloom fog, which is how a floor of blood became invisible.
		for _corner in 3:
			normals.append(Vector3.BACK)

	# Satellites: small discs flung off the main mass, thrown further where the
	# main outline already has a finger, so the scatter reads as having come off
	# *this* splat rather than being sprinkled around it.
	for satellite in rng.randi_range(4, 9):
		var finger := (satellite * 5) % steps
		var angle := TAU * float(finger) / float(steps) + rng.randf_range(-0.35, 0.35)
		var distance: float = radii[finger] * rng.randf_range(1.25, 2.4)
		var centre := Vector3(cos(angle) * distance, sin(angle) * distance, 0.0)
		var drop_radius: float = radius * rng.randf_range(0.055, 0.16)
		var facets := 6
		for facet in facets:
			var fa := TAU * float(facet) / float(facets)
			var fb := TAU * float(facet + 1) / float(facets)
			points.append(centre)
			points.append(centre + Vector3(cos(fa) * drop_radius, sin(fa) * drop_radius, 0.0))
			points.append(centre + Vector3(cos(fb) * drop_radius, sin(fb) * drop_radius, 0.0))
			colors.append(edge)
			colors.append(core)
			colors.append(core)
			for _corner in 3:
				normals.append(Vector3.BACK)

	# The main blob was normalised above so `radius` meant what it says. The
	# satellites are appended after that, at up to 2.4x a finger's length plus
	# their own width, so the finished mark reached about 2.5x the radius it was
	# handed and `radius` quietly stopped meaning anything -- which is how a
	# landed drop ended up 1.46m across, a puddle you could lie in.
	#
	# Normalise once more, over everything, so the invariant holds for the mesh
	# that is actually returned rather than for an intermediate state of it.
	var extent := 0.0
	for point in points:
		extent = maxf(extent, Vector2(point.x, point.y).length())
	if extent > radius and extent > 0.0001:
		var shrink := radius / extent
		for index in points.size():
			points[index] = Vector3(points[index].x * shrink, points[index].y * shrink, points[index].z)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# The colours above are written as sRGB the way every other colour in this
	# project is, so say so rather than letting them be read as linear.
	material.vertex_color_is_srgb = true
	material.albedo_color = Color(1, 1, 1, 0.96)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# The whole point. See the note above: shaded, this is a brown object on the
	# ground; unshaded, it is a mark on the world.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	_splat_pool.append(mesh)
	return mesh

## B5.2. What is installed in a limb, visible in that limb.
##
## The catalogue has carried a `profile` and a `tint` for every implant since it
## was written and nothing ever drew either: a prosthetic arm was the same arm
## with a chrome material on it, so twenty distinct pieces of hardware were
## indistinguishable from each other and from a clean limb somebody had polished.
## Each one is a shape now, mounted in the zone it was installed in, so a body
## you are looking at tells you what is in it — which is also what makes B5.1's
## ball something you can see somebody carrying.
##
## Rebuilt rather than updated, because an implant that is pulled has to leave,
## and one piece of geometry per zone is cheap enough to make that the simple
## path.
func _show_installed(zone_id: String, prosthetic: bool) -> void:
	var part := parts.get(zone_id) as MeshInstance3D
	if part == null or not is_instance_valid(part):
		return
	var existing := part.get_node_or_null("InstalledHardware")
	if existing != null:
		existing.queue_free()
	if not prosthetic:
		return
	var installed: Dictionary = anatomy.installed_parts.get(zone_id, {})
	if installed.is_empty():
		return
	var hardware := MeshInstance3D.new()
	hardware.name = "InstalledHardware"
	hardware.mesh = _implant_mesh(str(installed.get("profile", "")))
	hardware.material_override = _zone_material(zone_id, Color(str(installed.get("tint", "9a8f7c"))), "chrome")
	# Proud of the surface rather than buried in it: an implant nobody can see
	# is the state this segment is fixing.
	hardware.position = Vector3(0, 0, -0.055)
	hardware.set_meta("installed", str(installed.get("name", "")))
	hardware.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.add_child(hardware)


## The shape of a piece of hardware, by the profile the catalogue already gives
## it. Deliberately blunt forms — this reads at arm's length on a body in
## motion, not in a cutaway.
func _implant_mesh(profile: String) -> Mesh:
	match profile:
		"orb":
			var orb := SphereMesh.new()
			orb.radius = 0.055
			orb.height = 0.11
			return orb
		"optic", "optic_spool":
			var lens := CylinderMesh.new()
			lens.top_radius = 0.028
			lens.bottom_radius = 0.034
			lens.height = 0.03
			return lens
		"meter", "joint_dial", "digit_tool":
			var dial := BoxMesh.new()
			dial.size = Vector3(0.07, 0.05, 0.02)
			return dial
		"bone_rail", "spine_cage", "chest_plate", "pulse_cage":
			var plate := BoxMesh.new()
			plate.size = Vector3(0.19, 0.12, 0.03)
			return plate
		"industrial_limb", "scrap_limb", "limb_drive":
			var drive := BoxMesh.new()
			drive.size = Vector3(0.1, 0.17, 0.05)
			return drive
		_:
			var block := BoxMesh.new()
			block.size = Vector3(0.08, 0.07, 0.03)
			return block
