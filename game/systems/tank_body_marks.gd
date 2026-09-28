class_name TankBodyMarks
extends RefCounted

## Greg's checklist: body horror on your grown body, from your intake answers.
## Each answer family drives one kind of mark, and the same answers always
## grow the same body (seeded from them):
##   surgical marks  <- pre-owned organs and refusals: stitched seams, staples
##   growths         <- traits: cysts where the culture went wrong
##   skin and colour <- race and wear: translucent patches, bruise mottling
##   wrong parts     <- the mutation dial: a sixth finger, a vestigial nub
##
## ponytail: small meshes pinned to the rig's parts; no texture work.

const FLESH := Color("b08878")
const SEAM := Color("3b0a08")
const STAPLE := Color("9aa0a0")


static func dress(rig: Node3D, subject: Dictionary) -> Dictionary:
	var parts: Dictionary = rig.get("parts") if rig.get("parts") != null else {}
	var appearance: Dictionary = subject.get("appearance", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([subject.get("race", ""), subject.get("traits", []), subject.get("pre_owned_organs", []), appearance.get("mutation", 0.0), subject.get("examination_refusals", 0)])
	var made := {"seams": 0, "growths": 0, "patches": 0, "wrong": 0}
	var seams := 1 + (subject.get("pre_owned_organs", []) as Array).size() + mini(int(subject.get("examination_refusals", 0)), 3)
	for index in seams:
		var zone: String = ["torso", "torso", "left_arm", "right_arm", "left_leg"][index % 5]
		if parts.has(zone):
			_seam(parts[zone], rng)
			made.seams += 1
	for index in mini((subject.get("traits", []) as Array).size() + 1, 5):
		var zone: String = ["torso", "left_arm", "right_leg", "torso", "right_arm"][index % 5]
		if parts.has(zone):
			_growth(parts[zone], rng, 0.025 + rng.randf() * 0.03)
			made.growths += 1
	var wear := float(appearance.get("wear", 0.4))
	var translucent := str(subject.get("race", "decanted")) == "decanted"
	for index in 2 + int(wear * 4.0):
		var zone: String = ["torso", "left_leg", "right_arm", "torso", "left_arm", "right_leg"][index % 6]
		if parts.has(zone):
			_patch(parts[zone], rng, translucent)
			made.patches += 1
	if float(appearance.get("mutation", 0.0)) > 0.25 and parts.has("right_arm"):
		_wrong_part(parts["right_arm"], rng)
		made.wrong += 1
	if float(appearance.get("mutation", 0.0)) > 0.6 and parts.has("torso"):
		_growth(parts["torso"], rng, 0.07)
		made.wrong += 1
	return made


static func _material(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.6
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func _on(part: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.add_child(node)
	return node


static func _surface_point(part: Node3D, rng: RandomNumberGenerator) -> Vector3:
	# The front of the part, somewhere along it.
	return Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.25, 0.1), 0.1)


static func _seam(part: Node3D, rng: RandomNumberGenerator) -> void:
	var at := _surface_point(part, rng)
	var line := BoxMesh.new()
	line.size = Vector3(0.006, 0.16, 0.004)
	_on(part, line, at, _material(SEAM)).rotation.z = rng.randf_range(-0.6, 0.6)
	for stitch in 4:
		var across := BoxMesh.new()
		across.size = Vector3(0.03, 0.004, 0.005)
		_on(part, across, at + Vector3(0, -0.06 + stitch * 0.04, 0.002), _material(STAPLE if stitch % 2 == 0 else SEAM))


static func _growth(part: Node3D, rng: RandomNumberGenerator, radius: float) -> void:
	var cyst := SphereMesh.new()
	cyst.radius = radius
	cyst.height = radius * 1.6
	_on(part, cyst, _surface_point(part, rng), _material(FLESH.lerp(Color("9a5a52"), rng.randf())))


static func _patch(part: Node3D, rng: RandomNumberGenerator, translucent: bool) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.03 + rng.randf() * 0.03
	disc.bottom_radius = disc.top_radius
	disc.height = 0.003
	var node := _on(part, disc, _surface_point(part, rng), _material(Color("c9b8b0") if translucent else Color("3a2436"), 0.55 if translucent else 0.8))
	node.rotation.x = PI * 0.5


static func _wrong_part(part: Node3D, rng: RandomNumberGenerator) -> void:
	# A sixth finger where the hand ends.
	var finger := CylinderMesh.new()
	finger.top_radius = 0.008
	finger.bottom_radius = 0.011
	finger.height = 0.07
	var node := _on(part, finger, Vector3(0.04, -0.33 + rng.randf_range(-0.02, 0.02), 0.03), _material(FLESH))
	node.rotation.z = 0.5
