class_name HunterAppearance
extends Node

const HELD_GEAR := preload("res://systems/held_gear.gd")


## Greg: *"the gore in the gore sandbox is not up to date with the gore in the
## main game"*. It was not, and the reason was that the hunt styled its people
## and the sandbox did not: `bone_yard_hunt.gd` grew a private
## `_style_world_rig()` giving every combatant a face, wear, ink, piercings and
## a real cleaver on the hand, while `gore_demo.gd` called `BaselineHuman.build`
## and stopped, so the range was full of bare mannequins and anything learned
## there was learned against a body the game does not actually contain.
##
## One implementation, called from both, so they cannot drift apart again. The
## look is derived from the identity rather than randomised, so the same person
## is the same person in the hunt, in the sandbox and on a later run.
static func style_world_rig(rig: BaselineHuman, identity: String, armed: bool) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	var seed: int = abs(hash(identity))
	var look := HunterAppearance.new()
	look.name = "WorldAppearance"
	rig.add_child(look)
	look.configure(rig, {
		"name": identity,
		"wear": 0.32 + float(seed % 38) / 100.0,
		"ink": 0.20 + float((seed / 11) % 50) / 100.0,
		"piercings": 0.15 + float((seed / 31) % 35) / 100.0,
		"mutation": (0.22 + float((seed / 7) % 35) / 100.0) if armed else 0.08,
	})
	if not armed:
		return
	var arm := rig.parts.get("right_arm") as Node3D
	if arm == null:
		return
	var weapon := HELD_GEAR.build_weapon("sword")
	weapon.name = "HeldAshlineCleaver"
	# The grip sits at the wrist, with the edge projected forward of the body;
	# it is parented to the arm so a severed arm takes its weapon with it.
	weapon.position = Vector3(0.0, -0.34, -0.07)
	weapon.rotation = Vector3(-PI * 0.48, 0.12, 0.0)
	arm.add_child(weapon)

## Replaceable procedural hero detail mounted directly on BaselineHuman zones.
## These names are the contract for later authored meshes and blend shapes.

var rig: BaselineHuman
var details: Dictionary = {}
## B4.1. What this particular person chose to do to themselves, as filed by the
## character sheet. Empty means an unmarked body, which is a choice somebody
## made rather than a default the rig falls back to.
var marks: Dictionary = {}


func configure(body_rig: BaselineHuman, appearance: Dictionary = {}) -> void:
	rig = body_rig
	marks = appearance
	_build_face()
	_build_hands()
	_build_feet()
	_build_clothing()
	_build_prosthetic_readout()
	_build_body_mods()
	_build_head_mutations()
	_build_worn_layers()
	sync_from_anatomy()


## B4.2. What has grown on this head, and how much of it.
##
## On the head specifically, because that is what anybody looks at and what
## `faction_price_factor()` now reads: a mutation in this game is not a stat, it
## is a face people can see, and the same face that costs you at a Gate Lantern
## stall is a credential in the Soft Rot. Growths first, then the second pair of
## eyes, then the horn — so that a small mutation is a lump and a large one is
## unmistakably not human any more, rather than everything arriving at once.
func _build_head_mutations() -> void:
	var mutation := clampf(float(marks.get("mutation", 0.0)), 0.0, 1.0)
	if mutation <= 0.0:
		return
	var head := rig.parts.get("head") as Node3D
	if head == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mutation|%s|%.3f" % [str(marks.get("name", "")), mutation])
	var growths := 1 + int(mutation * 5.0)
	for growth in growths:
		var lump := _sphere(
			head,
			"Growth_%d" % growth,
			Vector3(
				rng.randf_range(-0.07, 0.07),
				rng.randf_range(-0.02, 0.09),
				rng.randf_range(-0.09, 0.05),
			),
			Vector3.ONE * (0.018 + rng.randf() * 0.03 * mutation),
			Color("6e7a3c").lerp(Color("8da442"), rng.randf()),
			"flesh",
		)
		lump.set_meta("mutation", "growth")
	if mutation > 0.45:
		var extra := _sphere(head, "Eye_Third", Vector3(rng.randf_range(-0.03, 0.03), 0.075, -0.1), Vector3(0.024, 0.02, 0.012), Color("d1d5ac"), "bone")
		extra.set_meta("mutation", "eye")
		var pupil := _sphere(head, "Pupil_Third", Vector3(rng.randf_range(-0.03, 0.03), 0.075, -0.112), Vector3(0.007, 0.009, 0.005), Color("12090a"), "dirt")
		pupil.set_meta("mutation", "eye")
	if mutation > 0.75:
		var horn := _box(head, "Horn", Vector3(0.04, 0.1, -0.02), Vector3(0.02, 0.09, 0.02), Color("b8a870"), "bone", Vector3(-18, 0, 12))
		horn.set_meta("mutation", "horn")


## B4.1. Piercings and tattoos, on the same rig as everything else.
##
## They are mounted on the zone meshes rather than painted into the flesh
## material, for the reason B6 already established about limbs: a mark on an arm
## has to leave with the arm. A tattoo in the material would survive the limb
## coming off and turn up on a stump, and a piercing in a texture could not be
## torn out.
##
## Seeded from the sheet, so the same character is marked the same way every run
## and two players are not marked alike. Nobody is marked by accident: a sheet
## that asked for nothing gets a body with nothing on it.
func _build_body_mods() -> void:
	var ink := clampf(float(marks.get("ink", 0.0)), 0.0, 1.0)
	var metal := clampf(float(marks.get("piercings", 0.0)), 0.0, 1.0)
	if ink <= 0.0 and metal <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%.3f|%.3f" % [str(marks.get("name", "")), ink, metal])

	# Piercings first, because they sit on the face and the ears where a tattoo
	# would not go, and because a face is what anybody looks at.
	var head := rig.parts.get("head") as Node3D
	if head != null and metal > 0.0:
		var studs := 1 + int(metal * 6.0)
		for stud in studs:
			var side := -1.0 if stud % 2 == 0 else 1.0
			var height := 0.04 - float(stud) * 0.028
			var ring := _sphere(
				head,
				"Piercing_%d" % stud,
				Vector3(side * (0.055 + rng.randf() * 0.02), height, -0.09 - rng.randf() * 0.02),
				Vector3.ONE * (0.012 + rng.randf() * 0.008),
				Color("cdbfa4"),
				"chrome",
			)
			ring.set_meta("body_mod", "piercing")

	if ink <= 0.0:
		return
	# Ink goes on the big surfaces, in Greg's own collage where there is any —
	# A10.1's argument about intent applies exactly here, since a tattoo is the
	# one place in a game where somebody else's art is supposed to be on a body.
	var sheet: Texture2D = ArtSet.pick("body", int(ink * 997.0))
	for zone_id in ["torso", "left_arm", "right_arm", "left_leg", "right_leg"]:
		var zone := rig.parts.get(zone_id) as Node3D
		if zone == null:
			continue
		if rng.randf() > ink:
			continue
		var patch := MeshInstance3D.new()
		patch.name = "Tattoo_%s" % zone_id
		var quad := QuadMesh.new()
		quad.size = Vector2(0.11 + rng.randf() * 0.06, 0.15 + rng.randf() * 0.08)
		var skin_ink := StandardMaterial3D.new()
		if sheet != null:
			skin_ink.albedo_texture = sheet
		# Under the skin rather than on it: ink sits in flesh, so it takes the
		# flesh's own light response and never reads as a sticker.
		skin_ink.albedo_color = Color(0.20, 0.15, 0.17, 0.86)
		skin_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		skin_ink.roughness = 0.86
		skin_ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		quad.material = skin_ink
		patch.mesh = quad
		patch.position = Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.06, 0.06), -0.075)
		patch.rotation.z = rng.randf_range(-0.4, 0.4)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patch.set_meta("body_mod", "tattoo")
		zone.add_child(patch)


## AX1.3. The seven intake axes, on the skull.
##
## Greg, playing the 21 September build: *"Brow, jaw, none of this actually
## changes."* Every feature below used to be a hardcoded constant, and the only
## thing an axis reached was `WorldLook.surface()`'s noise seed by way of
## `_variation` -- so cycling JAW from NARROW to BROAD changed the pattern in
## the skin and left the jaw exactly where it was. Seven controls that the form
## described in words and the body ignored.
##
## Each axis now owns geometry a player can point at. The ranges are small on
## purpose: this is a head somebody grew badly in a tank, not a character
## creator with a caricature slider.
func _build_face() -> void:
	var head := rig.parts.head as Node3D
	var axes: Dictionary = marks.get("axes", {}) if marks.get("axes") is Dictionary else {}
	var brow := _axis(axes, "brow")
	var jaw := _axis(axes, "jaw")
	var cheek := _axis(axes, "cheek")
	var eyes := _axis(axes, "eyes")
	var nose := _axis(axes, "nose")
	var mouth := _axis(axes, "mouth")
	# GROWN WRONG starts at 0 rather than centred: the facility does not intend
	# the damage, it just does not prevent it. So this one is a one-sided push.
	var wrong := clampf(float(axes.get("grown_wrong", 0.0)), 0.0, 1.0)

	# EYES: deep-set through prominent is how far the eye sits out of the skull,
	# and the brow above it decides how much of that is in shadow.
	var eye_out := lerpf(-0.008, 0.012, eyes)
	var eye_high := lerpf(-0.006, 0.006, eyes)
	# GROWN WRONG puts the two halves of the face out of step with each other.
	var skew := wrong * 0.016
	_sphere(head, "Eye_L", Vector3(-0.048, 0.035 + eye_high, -0.103 - eye_out), Vector3(0.031, 0.022, 0.014), Color("d1d5ac"), "bone")
	_sphere(head, "Eye_R", Vector3(0.047, 0.026 + eye_high - skew, -0.106 - eye_out), Vector3(0.022, 0.030, 0.012), Color("83c6bd"), "chrome")
	_sphere(head, "Pupil_L", Vector3(-0.050, 0.034 + eye_high, -0.116 - eye_out), Vector3(0.008, 0.010, 0.006), Color("12090a"), "dirt")
	_sphere(head, "Pupil_R", Vector3(0.050, 0.026 + eye_high - skew, -0.118 - eye_out), Vector3(0.006, 0.012, 0.005), Color("8d1b16"), "flesh")

	# BROW: fine through heavy. A ridge that grows forward and down over the
	# eyes, which is the single most legible thing on a low-poly head.
	var brow_depth := lerpf(0.012, 0.034, brow)
	var brow_drop := lerpf(0.004, -0.004, brow)
	_box(
		head, "Brow_Ridge",
		Vector3(0.0, 0.072 + brow_drop, -0.104 - brow_depth * 0.5),
		Vector3(0.175, lerpf(0.014, 0.030, brow), brow_depth),
		Color("6d5643"), "flesh",
		Vector3(deg_to_rad(lerpf(-4.0, 8.0, brow)), 0.0, deg_to_rad(wrong * 5.0)),
	)

	# CHEEK: hollow through fed. Two plates that widen and rise.
	for side in [-1.0, 1.0]:
		_box(
			head, "Cheek_%s" % ("L" if side < 0.0 else "R"),
			Vector3(side * lerpf(0.058, 0.074, cheek), -0.006 + lerpf(-0.010, 0.008, cheek), -0.080),
			Vector3(lerpf(0.030, 0.052, cheek), lerpf(0.038, 0.062, cheek), 0.048),
			Color("6b5340"), "flesh",
			Vector3(0.0, 0.0, deg_to_rad(side * lerpf(10.0, -4.0, cheek))),
		)

	# NOSE: straight through broken. Broken is not a bigger nose, it is a nose
	# that stops agreeing with the middle of the face, so the bridge and the tip
	# go different ways.
	var bridge_lean := lerpf(0.0, 9.0, nose) + wrong * 6.0
	_box(
		head, "Nose_Bridge",
		Vector3(lerpf(0.0, 0.009, nose), 0.012, -0.118),
		Vector3(0.030, 0.070, 0.036), Color("70573f"), "flesh",
		Vector3(0.0, 0.0, deg_to_rad(bridge_lean)),
	)
	_box(
		head, "Nose_Tip",
		Vector3(lerpf(0.0, -0.011, nose), -0.026, -0.129),
		Vector3(0.036, 0.028, 0.034), Color("7a5f45"), "flesh",
		Vector3(0.0, 0.0, deg_to_rad(-bridge_lean * 0.7)),
	)

	# MOUTH: thin through full, and JAW decides how wide the whole lower face is
	# for it to sit across.
	var jaw_wide := lerpf(0.86, 1.18, jaw)
	var lip := lerpf(0.009, 0.026, mouth)
	_box(head, "Mouth_Upper", Vector3(0, -0.052, -0.112), Vector3(0.105 * jaw_wide, lip, 0.014), Color("451311"), "flesh")
	_box(head, "Mouth_Lower", Vector3(0.010, -0.078 - lip * 0.3, -0.110), Vector3(0.088 * jaw_wide, lip * 0.92, 0.014), Color("65201b"), "flesh")
	for tooth in 5:
		var tooth_height: float = 0.012 if tooth == 3 else (0.021 if tooth not in [1, 4] else 0.017)
		_box(head, "Tooth_%d" % tooth, Vector3((-0.038 + tooth * 0.019) * jaw_wide, -0.063 + (0.008 if tooth in [1, 4] else 0.0), -0.121), Vector3(0.013, tooth_height, 0.009), Color("a99b72"), "bone")

	# JAW: narrow through broad, as an actual jaw under the mouth.
	_box(
		head, "Jaw_Line",
		Vector3(0.0, -0.098, -0.066),
		Vector3(0.132 * jaw_wide, lerpf(0.040, 0.058, jaw), lerpf(0.090, 0.118, jaw)),
		Color("67503d"), "flesh",
		Vector3(0.0, deg_to_rad(wrong * 4.0), deg_to_rad(wrong * 3.0)),
	)


## An axis as a 0..1 number, defaulting to the middle so a rig built without a
## sheet -- an overworld stranger, a test fixture -- still gets a plain face
## rather than an accidental extreme.
func _axis(axes: Dictionary, key: String) -> float:
	return clampf(float(axes.get(key, 0.5)), 0.0, 1.0)


func _build_hands() -> void:
	for side in [-1, 1]:
		var zone_id: String = "left_arm" if side < 0 else "right_arm"
		var arm := rig.parts[zone_id] as Node3D
		_box(arm, "%s_Hand" % zone_id, Vector3(0, -0.335, -0.008), Vector3(0.095, 0.095, 0.055), Color("795e49"), "flesh")
		for finger in 5:
			var length: float = 0.060 - absf(float(finger - 2)) * 0.006
			_box(arm, "%s_Finger_%d" % [zone_id, finger], Vector3((finger - 2) * 0.018, -0.402 - length * 0.5, -0.015), Vector3(0.012, length, 0.018), Color("765944"), "flesh")


func _build_feet() -> void:
	for side in [-1, 1]:
		var zone_id: String = "left_leg" if side < 0 else "right_leg"
		var leg := rig.parts[zone_id] as Node3D
		_box(leg, "%s_Boot" % zone_id, Vector3(side * 0.006, -0.455, -0.075), Vector3(0.12, 0.09, 0.23), Color("25231f"), "cloth")
		_box(leg, "%s_Toecap" % zone_id, Vector3(side * 0.006, -0.455, -0.17), Vector3(0.125, 0.07, 0.07), Color("655b4e"), "metal")


## AS3.4. The coat's own colour now comes from whatever layer `clothing.gd`
## says this subject is wearing rather than one constant every body in the
## game shared — real on the body in the ordinary camera right now, whatever
## a not-yet-built literal mirror elsewhere in the project would also show.
##
## `clothing.gd` (AS3, one worn layer, faction/weather strategy) and
## `garments.gd` (B7, a stackable list, combat shielding `apply_hit()` reads)
## are two different systems answering two different questions, not one
## renamed — `_build_clothing()` below draws the first, `_build_worn_layers()`
## draws the second, and a body can carry both at once.

## B7.1. The coat this rig has always had, plus whatever else the body is
## actually wearing. The built-in pieces stay: they are this character's own
## clothes, and a garment list is what they put on over them.
func _build_worn_layers() -> void:
	var worn: Array = marks.get("worn", [])
	if worn.is_empty():
		return
	for zone_id in Garments.covered_zones(worn):
		var zone := rig.parts.get(zone_id) as Node3D
		if zone == null:
			continue
		var over: Dictionary = Garments.shielding(worn, zone_id)
		var layer := _box(
			zone,
			"Worn_%s" % zone_id,
			Vector3(0, 0, -0.02),
			Vector3(0.3, 0.42, 0.06) if zone_id == "torso" else Vector3(0.14, 0.3, 0.05),
			# Heavier shielding reads heavier: a lead wrap is not a coat and
			# should not look like one across a yard.
			Color("2a2722").lerp(Color("6b6a5e"), float(over.shield)),
			"rust" if float(over.plate) > 0.25 else "paint",
		)
		layer.set_meta("worn_layer", zone_id)


func _build_clothing() -> void:
	var torso := rig.parts.torso as Node3D
	var tint := Color(str(Clothing.stats(rig.anatomy.subject_id).get("tint", "29271f")))
	_box(torso, "Coat_Front", Vector3(0, -0.06, -0.105), Vector3(0.34, 0.50, 0.045), tint, "cloth")
	_box(torso, "Collar_L", Vector3(-0.09, 0.24, -0.12), Vector3(0.12, 0.16, 0.035), tint.darkened(0.18), "cloth", Vector3(0, 0, -0.28))
	_box(torso, "Collar_R", Vector3(0.085, 0.21, -0.12), Vector3(0.11, 0.20, 0.035), tint.darkened(0.32), "cloth", Vector3(0, 0, 0.28))
	_box(torso, "Torque_Strap", Vector3(0.08, 0.02, -0.136), Vector3(0.055, 0.56, 0.025), Color("8a4426"), "metal", Vector3(0, 0, -0.28))


## AS3.4. For a layer worn mid-scene rather than at the moment the body was
## first built — re-tints the same pieces `_build_clothing()` already made
## rather than rebuilding the coat from scratch.
func sync_from_clothing() -> void:
	var tint := Color(str(Clothing.stats(rig.anatomy.subject_id).get("tint", "29271f")))
	var pairs := {
		"Coat_Front": tint,
		"Collar_L": tint.darkened(0.18),
		"Collar_R": tint.darkened(0.32),
	}
	for piece_name: String in pairs:
		var piece := details.get(piece_name) as MeshInstance3D
		if piece == null or piece.mesh == null:
			continue
		piece.mesh.material = WorldLook.surface(pairs[piece_name], "cloth", piece_name.hash())


func _build_prosthetic_readout() -> void:
	for zone_id in rig.anatomy.installed_parts:
		var limb := rig.parts.get(zone_id) as Node3D
		if limb == null:
			continue
		for band in 3:
			_box(limb, "%s_ServoBand_%d" % [zone_id, band], Vector3(0, -0.16 + band * 0.16, 0), Vector3(0.19, 0.035, 0.205), Color("b07646") if band == 1 else Color("727b78"), "metal")


func set_mouth(open_amount: float, injury_bias := 0.0) -> void:
	var lower := details.get("Mouth_Lower") as Node3D
	if lower != null:
		lower.position.y = -0.078 - clampf(open_amount, 0.0, 1.0) * 0.035
		lower.rotation.z = injury_bias * 0.16


func sync_from_anatomy() -> void:
	for index in rig.anatomy.wounds.size():
		var wound: Dictionary = rig.anatomy.wounds[index]
		var mark_name: String = "Wound_%d" % index
		if details.has(mark_name):
			continue
		var host := rig.parts.get(str(wound.get("zone", "torso"))) as Node3D
		if host == null:
			continue
		var y: float = -0.18 + fmod(float(index) * 0.137, 0.36)
		_box(host, mark_name, Vector3(0.02 if index % 2 == 0 else -0.025, y, -0.105), Vector3(0.09, 0.014, 0.018), Color("70110e"), "flesh", Vector3(0, 0, -0.32 + index * 0.11))


func _box(parent: Node3D, piece_name: String, at: Vector3, dimensions: Vector3, tint: Color, kind: String, turn := Vector3.ZERO) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = WorldLook.surface(tint, kind, piece_name.hash())
	piece.mesh = mesh
	piece.position = at
	piece.rotation = turn
	parent.add_child(piece)
	details[piece_name] = piece
	return piece


func _sphere(parent: Node3D, piece_name: String, at: Vector3, dimensions: Vector3, tint: Color, kind: String) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.material = WorldLook.surface(tint, kind, piece_name.hash())
	piece.mesh = mesh
	piece.position = at
	piece.scale = dimensions * 2.0
	parent.add_child(piece)
	details[piece_name] = piece
	return piece
