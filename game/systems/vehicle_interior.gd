class_name VehicleInterior
extends Node3D

## M2. Inside the car.
##
## Greg: *"in the car a driving the wheel with one hand which is wasd and then
## making it you hold a gun through shattered glass shooting out in first person
## driving then you can also switch third person driving as you progress in the
## derby"*.
##
## The derby has always been a chase camera looking at a box with wheels. That
## framing makes the car a *thing you steer*; this one makes it a *place you are
## sitting in*, which is the whole difference between a driving game and
## Carmageddon. Two details carry it:
##
##   - **One hand on the wheel, and that hand is the input.** The wheel turns
##     because you turned it, the arm follows the wheel, and the other hand is
##     busy holding a gun — so the car is being driven badly on purpose.
##   - **You shoot through your own windscreen.** The glass is real geometry in
##     front of the camera rather than a screen effect, so it occludes, it
##     catches light, and it accumulates damage where the car was actually hit.
##
## Built as its own node so the derby scene only has to parent it to a chassis.
## Nothing here reaches into `rift_derby.gd` or `arcade_vehicle.gd`.

const DASH := Color("0f0d0a")
const PILLAR := Color("15110d")
const WHEEL_RIM := Color("0c0a08")
const FLESH := Color("5d4b3c")
const SLEEVE := Color("1d1a14")
const GUN_METAL := Color("26262a")

const CLUSTER := preload("res://systems/dash_cluster.gd")

## Where the driver's eyes sit, relative to the chassis origin. Behind the wheel
## and to the left, because there is a passenger seat and you are not in it.
const EYE := Vector3(-0.34, 0.74, 0.16)

## The windscreen plane, in front of the eye. Close enough that the frame reads
## as a cabin rather than a windscreen at the end of a corridor.
const GLASS_AT := Vector3(0.0, 0.58, -1.06)
const GLASS_SIZE := Vector2(2.05, 1.12)

var wheel: Node3D
var left_arm: Node3D
var gun_arm: Node3D
var glass: MeshInstance3D
## AG3.1. The instruments, living in the binnacle rather than in a screen corner.
var cluster: SubViewport = null
var cluster_screen: MeshInstance3D = null

## 0 = intact, 1 = barely anything left to see through.
var glass_damage := 0.0
var _shatter: Array = []
var _rng := RandomNumberGenerator.new()


func build(seed_value: int = 0) -> void:
	_rng.seed = seed_value * 7919 + 11
	_dashboard()
	_pillars()
	_steering_wheel()
	_hands()
	_windscreen()
	_cabin_light()
	_on_cab_layer(self)


## The pit is a dark place and a cab is darker. Without this the dashboard, the
## wheel and both hands render as one black mass — which is exactly what the
## first capture of this showed. Small, warm, and short-range, so it lights the
## interior and throws nothing onto the road.
func _cabin_light() -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "CabinLight"
	lamp.position = Vector3(0.0, 0.86, -0.18)
	lamp.light_color = Color("ff9d4e")
	# Low. This exists so the dash and both hands are not one black mass; at 1.5
	# it lit the arena through the windscreen and turned the pit beige.
	lamp.light_energy = 0.42
	lamp.omni_range = 1.5
	lamp.omni_attenuation = 2.4
	lamp.shadow_enabled = false
	# Lights the cab and only the cab. Without this the interior lamp throws a
	# warm pool onto the road ahead through its own windscreen.
	lamp.light_cull_mask = 1 << (CAB_LAYER - 1)
	add_child(lamp)


## AG3.2. The cab and the car's exterior cannot both be drawn to the same
## camera: from the seat you are standing inside your own bodywork, and from the
## chase camera a floating dashboard trails the car. So they go on separate
## visual layers and each camera is told which one it is looking at. Doing it by
## layer rather than by hiding node names means the vehicle dressing — which is
## generated, and whose node names are not known here — is handled for free.
const CAB_LAYER := 3


func _on_cab_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1 << (CAB_LAYER - 1)
	for child in node.get_children():
		_on_cab_layer(child)


## Called every frame by whatever owns the car. `steer` is the same -1..1 the
## chassis is given, so the wheel in front of the player and the wheels on the
## road are driven by one number and can never disagree.
func drive(steer: float, throttle: float) -> void:
	if wheel != null and is_instance_valid(wheel):
		# Two and a bit turns lock to lock, which is a car rather than a go-kart.
		wheel.rotation.z = -clampf(steer, -1.0, 1.0) * 2.4
	if left_arm != null and is_instance_valid(left_arm):
		# The arm follows the rim it is holding, at less than the full angle,
		# because a shoulder does not rotate as far as a wheel does.
		left_arm.rotation.z = -clampf(steer, -1.0, 1.0) * 0.9
		left_arm.position.y = 0.44 + absf(steer) * 0.03
	if gun_arm != null and is_instance_valid(gun_arm):
		# The gun hand drifts with acceleration, since nobody braces a pistol
		# while flooring it.
		gun_arm.rotation.x = -0.1 + clampf(throttle, -1.0, 1.0) * 0.06


## AG3.4. A round leaves through your own windscreen. `where` is in glass-local
## coordinates, roughly -1..1 across and -1..1 up, so a shot high and left puts
## its hole high and left. The hole is permanent: this is the only glass you get.
func punch_through(where: Vector2) -> void:
	glass_damage = clampf(glass_damage + 0.035, 0.0, 1.0)
	_shatter.append({
		"at": Vector2(clampf(where.x, -0.95, 0.95), clampf(where.y, -0.95, 0.95)),
		"size": 0.05,
		"seed": _rng.randi(),
		"hole": true,
	})
	_apply_glass()


## M2.5. The view gets worse as the car does. `hits` is a normalised measure of
## how battered the chassis is; `at_x` is roughly where on the screen the last
## impact came from, so damage accumulates where it was earned.
func take_hit(severity: float, at_x := 0.0) -> void:
	glass_damage = clampf(glass_damage + severity * 0.22, 0.0, 1.0)
	_shatter.append({
		"at": Vector2(clampf(at_x, -0.9, 0.9), _rng.randf_range(-0.5, 0.5)),
		"size": 0.08 + severity * 0.26,
		"seed": _rng.randi(),
	})
	_apply_glass()


func _apply_glass() -> void:
	if glass == null or not is_instance_valid(glass):
		return
	var material := glass.material_override as StandardMaterial3D
	if material == null:
		return
	# Cracked glass stops being transparent long before it stops being glass:
	# the milky scatter is what actually blocks the view, not the lines.
	material.albedo_color = Color(0.72, 0.76, 0.74, clampf(0.04 + glass_damage * 0.42, 0.0, 0.6))
	material.roughness = clampf(0.05 + glass_damage * 0.55, 0.0, 1.0)


func _dashboard() -> void:
	# A wide, low slab with a lip, so there is something between the player and
	# the road. Without it the camera reads as floating in front of the bonnet.
	# Pushed forward of the wheel: the driver, then the wheel, then the dash,
	# then the glass, in that order and never overlapping.
	_block(Vector3(0, 0.34, -0.76), Vector3(1.86, 0.30, 0.40), DASH)
	_block(Vector3(0, 0.50, -0.94), Vector3(1.86, 0.08, 0.12), DASH.lightened(0.08))
	# The binnacle in front of the driver. This used to be a deliberately empty
	# housing, on the reading that I0 forbade readouts — but I0 forbade *a list
	# of text in a box*, and an instrument cluster is neither. The playtester in
	# the seat could not find the hull at all, which settled the argument.
	_block(Vector3(-0.34, 0.545, -0.64), Vector3(0.58, 0.28, 0.24), DASH.darkened(0.3))
	_instruments()
	# The transmission tunnel, which is what makes a cabin feel narrow.
	_block(Vector3(0, 0.16, -0.2), Vector3(0.3, 0.26, 1.1), DASH.darkened(0.15))
	# A roof. Without one the A-pillars and the header rail read as three bars
	# hanging in the air above the bonnet rather than as a cabin around you.
	_block(Vector3(0, 1.24, -0.28), Vector3(1.96, 0.10, 1.75), PILLAR.darkened(0.25))


## AG3.1. The cluster is rendered to a viewport and hung inside the binnacle as
## a real surface, angled back the way a dash is. It is unshaded on purpose: a
## backlit instrument face makes its own light and should not go dark when the
## cab does, which is the entire reason you can read one at night.
func _instruments() -> void:
	cluster = CLUSTER.new()
	add_child(cluster)
	cluster_screen = MeshInstance3D.new()
	cluster_screen.name = "ClusterFace"
	var quad := QuadMesh.new()
	# A hair under the binnacle opening, so there is a bezel rather than a
	# screen that runs to the edges of its own housing.
	quad.size = Vector2(0.50, 0.225)
	cluster_screen.mesh = quad
	cluster_screen.position = Vector3(-0.34, 0.552, -0.505)
	# Raked back to meet the eye. The number is the binnacle's own rake, not a
	# value picked to look right from one screenshot.
	cluster_screen.rotation.x = -0.30
	var material := StandardMaterial3D.new()
	material.albedo_texture = cluster.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Slight emission so the face throws a little light back into the cab, the
	# way a lit cluster actually does on your hands at night.
	material.emission_enabled = true
	material.emission_texture = cluster.get_texture()
	material.emission_energy_multiplier = 0.55
	cluster_screen.material_override = material
	cluster_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cluster_screen)


## Hand the instruments what they show. Straight through, because the cluster
## owns its own smoothing and this node has no opinion about any of it.
func report(values: Dictionary) -> void:
	if cluster != null and is_instance_valid(cluster):
		cluster.report(values)


func _pillars() -> void:
	# A-pillars at the edges of the windscreen. These do most of the work: they
	# are what the eye reads as "I am inside something".
	for side in [-1.0, 1.0]:
		var pillar := _block(
			Vector3(side * (GLASS_SIZE.x * 0.5 + 0.08), GLASS_AT.y + 0.02, GLASS_AT.z + 0.05),
			Vector3(0.16, GLASS_SIZE.y + 0.24, 0.18),
			PILLAR
		)
		pillar.rotation.z = -side * 0.13
	# The roof lip above the glass, and the scuttle below it.
	_block(Vector3(0, GLASS_AT.y + GLASS_SIZE.y * 0.5 + 0.07, GLASS_AT.z + 0.06), Vector3(1.9, 0.14, 0.2), PILLAR)
	_block(Vector3(0, GLASS_AT.y - GLASS_SIZE.y * 0.5 - 0.04, GLASS_AT.z + 0.04), Vector3(1.9, 0.1, 0.22), PILLAR.darkened(0.2))


func _steering_wheel() -> void:
	wheel = Node3D.new()
	wheel.name = "Wheel"
	wheel.position = Vector3(-0.34, 0.395, -0.32)
	# Raked back the way a column actually sits, rather than standing vertical.
	wheel.rotation.x = -0.38
	add_child(wheel)
	# The rim, as a ring of short segments — a torus mesh would read as too
	# clean for a car that has been in a derby.
	var segments := 18
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		var seg := _block(Vector3(cos(angle) * 0.165, sin(angle) * 0.165, 0.0), Vector3(0.05, 0.05, 0.045), WHEEL_RIM, wheel)
		seg.rotation.z = angle
	# Two spokes and a boss. Two, not three: it is a wheel somebody welded.
	for spoke in [-0.45, PI + 0.45]:
		var arm := _block(Vector3(cos(spoke) * 0.09, sin(spoke) * 0.09, 0.0), Vector3(0.18, 0.032, 0.032), WHEEL_RIM.lightened(0.06), wheel)
		arm.rotation.z = spoke
	_block(Vector3(0, 0, 0.01), Vector3(0.08, 0.08, 0.06), WHEEL_RIM.lightened(0.12), wheel)


func _hands() -> void:
	# M2.2. The left hand, on the rim. Parented outside the wheel node so it
	# leans with the steering rather than spinning all the way round with it —
	# a hand that rotates 2.4 radians is a hand that has come off.
	left_arm = Node3D.new()
	left_arm.name = "WheelArm"
	left_arm.position = Vector3(-0.34, 0.405, -0.28)
	add_child(left_arm)
	_block(Vector3(-0.16, -0.02, 0.06), Vector3(0.11, 0.11, 0.34), SLEEVE, left_arm)
	_block(Vector3(-0.19, 0.0, -0.06), Vector3(0.1, 0.09, 0.13), FLESH, left_arm)
	for knuckle in 3:
		_block(Vector3(-0.2, 0.03, -0.11 + float(knuckle) * 0.035), Vector3(0.09, 0.035, 0.03), FLESH.darkened(0.1), left_arm)

	# M2.3. The right hand, holding a pistol up near the glass. The barrel points
	# out and slightly across, because you are shooting past your own A-pillar.
	gun_arm = Node3D.new()
	gun_arm.name = "GunArm"
	gun_arm.position = Vector3(0.36, 0.58, -0.34)
	gun_arm.rotation = Vector3(-0.1, 0.16, 0.0)
	add_child(gun_arm)
	_block(Vector3(0.06, -0.06, 0.16), Vector3(0.12, 0.12, 0.36), SLEEVE, gun_arm)
	_block(Vector3(0.0, -0.02, -0.02), Vector3(0.1, 0.1, 0.14), FLESH, gun_arm)
	# The gun: a grip, a slide and a short barrel.
	_block(Vector3(0.0, -0.06, -0.06), Vector3(0.05, 0.13, 0.06), GUN_METAL.darkened(0.25), gun_arm)
	_block(Vector3(0.0, 0.02, -0.16), Vector3(0.06, 0.07, 0.24), GUN_METAL, gun_arm)
	_block(Vector3(0.0, 0.05, -0.28), Vector3(0.035, 0.035, 0.08), GUN_METAL.lightened(0.1), gun_arm)


func _windscreen() -> void:
	# M2.4. Real geometry, not a screen effect. It sits in front of the camera,
	# it is lit by the world, and it is what the damage accumulates on.
	glass = MeshInstance3D.new()
	glass.name = "Windscreen"
	var plane := BoxMesh.new()
	plane.size = Vector3(GLASS_SIZE.x, GLASS_SIZE.y, 0.02)
	glass.mesh = plane
	glass.position = GLASS_AT
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.72, 0.76, 0.74, 0.04)
	material.metallic = 0.1
	material.roughness = 0.05
	# Off, or the glass darkens everything behind it into a windscreen-shaped
	# shadow on the road.
	material.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.material_override = material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)


func _block(at: Vector3, size: Vector3, tint: Color, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.96
	material.disable_ambient_light = true
	node.material_override = material
	if parent == null:
		add_child(node)
	else:
		parent.add_child(node)
	return node
