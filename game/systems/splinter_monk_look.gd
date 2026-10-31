class_name SplinterMonkLook
extends RefCounted

## How the splinter monks look (DESIGN/OVERWORLD_EVENTS.md, decided by Greg):
## "eastern orthodox monks in the black and white garbs with the hoodies that
## have their sigils ... instead of just white and black make it blood stained
## and creased destroyed sigils". Old men.
##
## Built on an ordinary `BaselineHuman` so a monk is still a body the combat,
## anatomy and gore systems understand: the rig's garment shells are recoloured
## into the habit, and the pieces a riasa and a schema have that a work shirt
## does not are added from primitives - a long skirt, the pointed hood with its
## back mantle and lappets, the schema panel down the front, a beard.
##
## The sigils are CellOutzType seals (`seal_strokes`, the same geometry
## `draw_seal` uses) rasterised on the CPU into a mask, broken while they are
## drawn - strokes dropped, drifted, slashed through and burnt out - so the
## "destroyed" part is in the thread itself, not a filter on top. Creases and
## blood are the shader's (`shaders/monk_habit.gdshader`).
##
## Which seals they wear is a placeholder: their sigils' meaning is Greg's,
## and why the splinter left the guild is still open.

const HABIT_SHADER := preload("res://shaders/monk_habit.gdshader")

const SIGIL_SIZE := 512
const FLESH := Color("8d7b68")
const BEARD := Color("6e6a64")

static var _sigil_textures: Dictionary = {}
static var _crease_texture: Texture2D
static var _blood_texture: Texture2D


## A standing monk, built, dressed and ready to add to the tree (or already
## added: pass `parent`). `elder` makes the leader: taller hood, heavier schema.
static func build_monk(subject_id: String, seed_value: int, elder := false, parent: Node = null) -> BaselineHuman:
	var rig := BaselineHuman.new()
	rig.name = "MonkBody"
	if parent != null:
		parent.add_child(rig)
	rig.build(subject_id, {
		"flesh": FLESH.darkened(float(seed_value % 5) * 0.03),
		"variation": 3 + seed_value % 11,
		"blood": 4200.0 if not elder else 5000.0,
		"frame": 0.35,
		"build": 0.9,
	})
	dress(rig, seed_value, elder)
	return rig


## Dress an existing rig as a splinter monk. Safe on any BaselineHuman,
## including one the Hunt spawned for a fight.
static func dress(rig: BaselineHuman, seed_value: int, elder := false) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	# Everything but the head: the face stays open under the hood.
	var wardrobe := ClothingShell.fresh_wardrobe()
	wardrobe["head"] = 0.0
	rig.dress(wardrobe)
	var black := habit_material(seed_value, 0.0)
	var white := habit_material(seed_value + 7, 1.0)
	var hood_mat := habit_material(seed_value + 3, 0.0)
	hood_mat.set_shader_parameter("sigil_scale", 3.0)
	black.set_shader_parameter("sigil_scale", 1.8)
	white.set_shader_parameter("sigil_scale", 2.2)
	for zone_id in rig.parts:
		var part := rig.parts[zone_id] as Node3D
		if part == null:
			continue
		var garment := part.get_node_or_null("Garment") as MeshInstance3D
		if garment != null:
			garment.material_override = black
	var torso := rig.parts.get("torso") as Node3D
	var head := rig.parts.get("head") as Node3D
	if torso == null or head == null:
		return
	var torso_y: float = torso.position.y

	# The riasa: a long skirt from the waist to the ankles.
	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 0.26
	skirt_mesh.bottom_radius = 0.37
	skirt_mesh.height = 0.98
	skirt_mesh.radial_segments = 22
	skirt_mesh.rings = 6
	skirt_mesh.cap_top = false
	skirt_mesh.cap_bottom = false
	var skirt_mat := habit_material(seed_value + 1, 0.0)
	skirt_mat.set_shader_parameter("hem_height", -0.05)
	skirt_mat.set_shader_parameter("hem_blood", 0.55)
	skirt_mat.set_shader_parameter("fray", 0.5)
	_piece(torso, "Riasa", skirt_mesh, skirt_mat, Vector3(0, 0.49 - torso_y, 0))

	# The hood: the koukoulion, a rounded cowl drawn up to a blunt point that
	# sits on the brow and leaves the face open, the mantle down the back and
	# a lappet over each shoulder, all covered in the broken seals.
	var cap := SphereMesh.new()
	cap.radius = 0.16
	cap.height = 0.32
	cap.is_hemisphere = true
	cap.radial_segments = 20
	cap.rings = 8
	var cowl := _piece(head, "Koukoulion", cap, hood_mat, Vector3(0, 0.035, 0.025))
	cowl.scale = Vector3(1.0, 2.3 if elder else 1.9, 1.05)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.162
	brim.bottom_radius = 0.172
	brim.height = 0.07
	brim.radial_segments = 20
	brim.cap_top = false
	brim.cap_bottom = false
	_piece(head, "HoodBrim", brim, hood_mat, Vector3(0, 0.035, 0.025))
	var mantle := BoxMesh.new()
	mantle.size = Vector3(0.36, 0.62, 0.025)
	var mantle_node := _piece(head, "HoodMantle", mantle, hood_mat, Vector3(0, -0.26, 0.17))
	mantle_node.rotation.x = -0.1
	for side in [-1.0, 1.0]:
		var lappet := BoxMesh.new()
		lappet.size = Vector3(0.1, 0.42, 0.02)
		var node := _piece(head, "Lappet", lappet, hood_mat, Vector3(0.175 * side, -0.2, 0.0))
		node.rotation.z = 0.1 * side

	# The schema: a white panel over the chest and a white stole down the
	# front of the skirt, seals in dark thread, ruined like the rest.
	var schema := BoxMesh.new()
	schema.size = Vector3(0.32, 0.5, 0.02)
	_piece(torso, "Schema", schema, white, Vector3(0, -0.05, -0.16))
	var stole := BoxMesh.new()
	stole.size = Vector3(0.24 if elder else 0.2, 0.82, 0.015)
	var stole_node := _piece(torso, "SchemaStole", stole, white, Vector3(0, 0.46 - torso_y, -0.33))
	stole_node.rotation.x = 0.112
	# The shoulder caps are bare flesh on the rig; cover them.
	for cap_node in rig.shoulders.values():
		if cap_node is MeshInstance3D:
			(cap_node as MeshInstance3D).material_override = black
	for side_name in ["Clavicle_L", "Clavicle_R"]:
		var clavicle := torso.get_node_or_null(side_name) as MeshInstance3D
		if clavicle != null:
			clavicle.material_override = black

	# Old men: a long grey beard over the collar.
	var beard := CylinderMesh.new()
	beard.top_radius = 0.062
	beard.bottom_radius = 0.008
	beard.cap_top = false
	beard.height = 0.38 if elder else 0.3
	beard.radial_segments = 10
	var beard_mat := StandardMaterial3D.new()
	beard_mat.albedo_color = BEARD.darkened(float(seed_value % 4) * 0.08)
	# Streaked like hair: the crease noise stretched down its length.
	beard_mat.albedo_texture = crease_texture()
	beard_mat.uv1_scale = Vector3(3.0, 0.6, 1.0)
	beard_mat.roughness = 1.0
	beard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beard_node := _piece(head, "Beard", beard, beard_mat, Vector3(0, -0.11 - beard.height * 0.42, -0.085))
	beard_node.rotation.x = 0.2


static func _piece(parent: Node3D, piece_name: String, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = piece_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


## One piece of habit cloth. `white_field` 0 is black cloth with white seals,
## 1 is white cloth with dark seals.
static func habit_material(seed_value: int, white_field: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = HABIT_SHADER
	material.set_shader_parameter("sigil_mask", sigil_texture(seed_value % 3))
	material.set_shader_parameter("crease_noise", crease_texture())
	material.set_shader_parameter("blood_noise", blood_texture())
	material.set_shader_parameter("white_field", white_field)
	material.set_shader_parameter("seed_offset", float(seed_value % 17) * 0.137)
	material.set_shader_parameter("blood_amount", 0.45 + float(seed_value % 5) * 0.08)
	return material


## The seal mask for one of a few variants: four large seals and a band of
## small ones per tile, drawn from `CellOutzType.seal_strokes` and destroyed
## while being drawn. White = thread.
static func sigil_texture(variant: int) -> Texture2D:
	if _sigil_textures.has(variant):
		return _sigil_textures[variant]
	var image := Image.create(SIGIL_SIZE, SIGIL_SIZE, false, Image.FORMAT_L8)
	image.fill(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91017 + variant * 7919
	var cell := SIGIL_SIZE / 2
	for gy in 2:
		for gx in 2:
			var centre := Vector2((gx + 0.5) * cell, (gy + 0.5) * cell - 18.0)
			_draw_broken_seal(image, centre, cell * 0.36, 400 + variant * 17 + gy * 2 + gx, 6 + (gx + gy) % 3, 0.45, rng)
	# A band of small seals under each row, like the embroidered lettering
	# round a schema's border.
	for gy in 2:
		for index in 6:
			var at := Vector2((index + 0.5) * SIGIL_SIZE / 6.0, (gy + 1) * cell - 20.0)
			_draw_broken_seal(image, at, 15.0, 900 + variant * 31 + gy * 6 + index, 4, 0.55, rng)
	# Destroyed: slashed through and burnt out.
	for slash in 5:
		var from := Vector2(rng.randf_range(0, SIGIL_SIZE), rng.randf_range(0, SIGIL_SIZE))
		var to := from + Vector2.from_angle(rng.randf_range(-0.9, 0.9) + (PI * 0.5 if slash % 2 == 0 else 0.0)) * rng.randf_range(90.0, 220.0)
		_line(image, from, to, 7, Color.BLACK)
	for burn in 7:
		var at := Vector2(rng.randf_range(0, SIGIL_SIZE), rng.randf_range(0, SIGIL_SIZE))
		var radius := rng.randf_range(10.0, 34.0)
		_disc(image, at, radius, Color.BLACK)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_sigil_textures[variant] = texture
	return texture


static func _draw_broken_seal(image: Image, centre: Vector2, radius: float, seed_value: int, complexity: int, damage: float, rng: RandomNumberGenerator) -> void:
	var thickness := maxi(2, int(radius * 0.06))
	var wander := radius * 0.05 * damage
	for stroke: PackedVector2Array in CellOutzType.seal_strokes(seed_value, complexity):
		for step in range(stroke.size() - 1):
			var from := centre + stroke[step] * radius
			var to := centre + stroke[step + 1] * radius
			for piece in 3:
				if rng.randf() < damage * 0.5:
					continue
				var a := from.lerp(to, float(piece) / 3.0)
				var b := from.lerp(to, float(piece + 1) / 3.0)
				var drift := Vector2(rng.randf_range(-wander, wander), rng.randf_range(-wander, wander))
				var shade := Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.35))
				_line(image, a + drift, b + drift, thickness, shade)


static func _line(image: Image, from: Vector2, to: Vector2, thickness: int, color: Color) -> void:
	var length := from.distance_to(to)
	var steps := maxi(1, int(ceil(length / maxf(1.0, thickness * 0.5))))
	var half := thickness / 2
	for step in steps + 1:
		var p := from.lerp(to, float(step) / float(steps))
		var rect := Rect2i(int(p.x) - half, int(p.y) - half, thickness, thickness)
		rect = rect.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
		if rect.size.x > 0 and rect.size.y > 0:
			image.fill_rect(rect, color)


static func _disc(image: Image, centre: Vector2, radius: float, color: Color) -> void:
	var r := int(radius)
	for dy in range(-r, r + 1):
		var half := int(sqrt(maxf(0.0, radius * radius - dy * dy)))
		var rect := Rect2i(int(centre.x) - half, int(centre.y) + dy, half * 2 + 1, 1)
		rect = rect.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
		if rect.size.x > 0 and rect.size.y > 0:
			image.fill_rect(rect, color)


static func crease_texture() -> Texture2D:
	if _crease_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 3301
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		noise.fractal_octaves = 4
		noise.domain_warp_enabled = true
		noise.domain_warp_amplitude = 22.0
		var image := noise.get_seamless_image(256, 256)
		image.generate_mipmaps()
		_crease_texture = ImageTexture.create_from_image(image)
	return _crease_texture


static func blood_texture() -> Texture2D:
	if _blood_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 6607
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.018
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 5
		var image := noise.get_seamless_image(256, 256)
		image.generate_mipmaps()
		_blood_texture = ImageTexture.create_from_image(image)
	return _blood_texture
