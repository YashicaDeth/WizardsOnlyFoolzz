class_name Ballistics
extends Node3D

## AF1. A round is a thing that travels.
##
## Greg, twice: *"the combat system apart of the gun system ect and weapons so
## bullet weapon and firing ect are all realistic bullets and reload with the
## things"*, and then *"bullets shells fall on the floor aggressively as the
## bullet destroys the map"*.
##
## Firing in this game has always been `intersect_ray` on the frame the trigger
## went down. That is not wrong — it is what most shooters do and it is cheap —
## but it means a round has no existence: it cannot be in flight, it cannot miss
## and land somewhere, it cannot arrive after you have stopped looking at where
## it was going, and nothing it passes through is any different for having been
## passed through. Every one of the things Greg is asking for is a consequence of
## the round being an event rather than an object.
##
## So here it is an object. It has a mass, a muzzle velocity and a calibre; it
## drops; it slows; it is traced between where it was and where it is so it
## cannot tunnel through a wall at three hundred metres a second; and when it
## arrives it marks whatever it arrived at.
##
## Casings are the same argument at a smaller scale. A firefight should be
## legible afterwards from the floor, and that costs a stepped particle with a
## bounce, not a physics body per round.

signal round_hit(hit: Dictionary)

## Calibres, and what each one is for. These are the whole balance conversation
## for firearms the same way mass and reach are for melee (AN1.5).
const CALIBRES := {
	"pistol": {
		"label": "9 SHORT", "muzzle": 340.0, "grain": 0.008, "drag": 0.02,
		"penetration": 0.25, "casing": Vector3(0.009, 0.019, 0.009),
	},
	"buck": {
		# Nine pellets, each individually tracked, which is why a shotgun at
		# range stops being a shotgun without anybody writing a falloff curve.
		"label": "12 BORE", "muzzle": 395.0, "grain": 0.0032, "drag": 0.085,
		"penetration": 0.12, "casing": Vector3(0.019, 0.070, 0.019),
	},
	"rifle": {
		"label": "LONG", "muzzle": 780.0, "grain": 0.010, "drag": 0.008,
		"penetration": 0.75, "casing": Vector3(0.012, 0.051, 0.012),
	},
	"slug": {
		"label": "SLUG", "muzzle": 430.0, "grain": 0.028, "drag": 0.035,
		"penetration": 0.55, "casing": Vector3(0.019, 0.070, 0.019),
	},
}

## Past this a round is somebody else's problem. Rounds are cheap but not free
## and nothing in this world is worth simulating at four hundred metres.
const MAX_RANGE := 260.0
const MAX_ROUNDS := 96
## Casings stay for the scene. Capped so a long firefight fills the floor and
## then stays full, rather than costing more the longer it runs — the same rule
## `GoreChunks` uses, for the same reason.
const MAX_CASINGS := 180
const GRAVITY := 9.81

## Rounds in flight. Plain dictionaries stepped by hand: a RigidBody per bullet
## would hand the physics server ninety bodies a second during a shotgun volley
## for no behaviour the integrator below does not already give.
var rounds: Array = []
var casings: Array = []
var marks: Array = []

var _rng := RandomNumberGenerator.new()
var _mesh_round: BoxMesh
var _material_round: StandardMaterial3D


func _ready() -> void:
	name = "Ballistics"
	_rng.randomize()
	# One mesh and one material for every tracer in flight. Ninety of each was
	# the first version and it cost more than the simulation did.
	_mesh_round = BoxMesh.new()
	_mesh_round.size = Vector3(0.02, 0.02, 0.16)
	_material_round = StandardMaterial3D.new()
	_material_round.albedo_color = Color("d8b06a")
	_material_round.emission_enabled = true
	_material_round.emission = Color("ffca7a")
	_material_round.emission_energy_multiplier = 1.6
	_material_round.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


## Fire. `from` and `along` are world space, `calibre` keys `CALIBRES`, `spread`
## is in radians and `count` is how many projectiles leave the barrel — which is
## the only difference between a pistol and a shotgun in this system.
func fire(from: Vector3, along: Vector3, calibre := "pistol", spread := 0.0, count := 1, shooter := "") -> void:
	var spec: Dictionary = CALIBRES.get(calibre, CALIBRES["pistol"])
	for index in count:
		if rounds.size() >= MAX_ROUNDS:
			_retire_round(0)
		var direction := along.normalized()
		if spread > 0.0:
			# Cone, not a square: a square spread puts corners on the pattern
			# and a shotgun pattern with corners is visible immediately.
			var angle := _rng.randf() * TAU
			var off := sqrt(_rng.randf()) * spread
			var basis := Basis().looking_at(direction, Vector3.UP)
			direction = (basis * Vector3(sin(off) * cos(angle), sin(off) * sin(angle), -cos(off))).normalized()
		var tracer := MeshInstance3D.new()
		tracer.mesh = _mesh_round
		tracer.material_override = _material_round
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tracer)
		tracer.global_position = from
		rounds.append({
			"node": tracer,
			"at": from,
			"was": from,
			"velocity": direction * float(spec["muzzle"]),
			"calibre": calibre,
			"spec": spec,
			"travelled": 0.0,
			"shooter": shooter,
		})
	_eject(from, along, calibre)


## AF1.3. The casing. Out of the port, sideways and back, tumbling — which is
## where a real one goes and is why brass ends up behind and to the right of
## whoever was shooting rather than in front of them.
func _eject(from: Vector3, along: Vector3, calibre: String) -> void:
	var spec: Dictionary = CALIBRES.get(calibre, CALIBRES["pistol"])
	if casings.size() >= MAX_CASINGS:
		_retire_casing(0)
	var forward := along.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length() < 0.1:
		right = Vector3.RIGHT
	var shell := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	var size: Vector3 = spec["casing"]
	mesh.top_radius = size.x
	mesh.bottom_radius = size.x
	mesh.height = size.y
	mesh.radial_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b08a3c")
	material.metallic = 0.7
	material.roughness = 0.35
	mesh.material = material
	shell.mesh = mesh
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	shell.global_position = from + right * 0.08 + Vector3.UP * 0.02
	casings.append({
		"node": shell,
		"velocity": right * _rng.randf_range(1.9, 3.4) + Vector3.UP * _rng.randf_range(1.6, 2.8) - forward * _rng.randf_range(0.2, 0.9),
		"spin": Vector3(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-14.0, 14.0), _rng.randf_range(-22.0, 22.0)),
		"rest": 0.0,
		"life": 0.0,
	})


func _physics_process(delta: float) -> void:
	_step_rounds(delta)
	_step_casings(delta)


## The integrator. Traced between where the round was and where it now is, so a
## round cannot be on one side of a wall this frame and the other side next.
func _step_rounds(delta: float) -> void:
	if rounds.is_empty():
		return
	var space := get_world_3d().direct_space_state
	for index in range(rounds.size() - 1, -1, -1):
		var round_data: Dictionary = rounds[index]
		var spec: Dictionary = round_data["spec"]
		round_data["was"] = round_data["at"]
		var velocity: Vector3 = round_data["velocity"]
		# Drag proportional to speed squared, which is what actually makes a
		# light fast pellet lose its authority so much faster than a heavy one.
		var speed := velocity.length()
		velocity -= velocity.normalized() * speed * speed * float(spec["drag"]) * 0.0001 * delta * 60.0
		velocity.y -= GRAVITY * delta
		var at: Vector3 = round_data["at"] + velocity * delta
		round_data["velocity"] = velocity
		round_data["at"] = at
		round_data["travelled"] = float(round_data["travelled"]) + (at - round_data["was"]).length()

		var query := PhysicsRayQueryParameters3D.create(round_data["was"], at)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			_land(round_data, hit)
			_retire_round(index)
			continue
		if float(round_data["travelled"]) > MAX_RANGE or at.y < -30.0:
			_retire_round(index)
			continue
		var node := round_data["node"] as Node3D
		if node != null and is_instance_valid(node):
			node.global_position = at
			if velocity.length() > 0.1:
				node.look_at(at + velocity, Vector3.UP)


## AF1.2. It arrives, and the thing it arrived at is different for it.
func _land(round_data: Dictionary, hit: Dictionary) -> void:
	var spec: Dictionary = round_data["spec"]
	var at: Vector3 = hit.get("position", round_data["at"])
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var velocity: Vector3 = round_data["velocity"]
	# Energy, not speed: the number that decides what this does to whatever it
	# just met. Half m v squared, in whatever units this world runs on.
	var energy := 0.5 * float(spec["grain"]) * velocity.length_squared()
	var report := {
		"collider": hit.get("collider"),
		"position": at,
		"normal": normal,
		"direction": velocity.normalized(),
		"calibre": round_data["calibre"],
		"energy": energy,
		"penetration": float(spec["penetration"]),
		"shooter": round_data["shooter"],
	}
	_mark(at, normal, energy)
	round_hit.emit(report)


## The hole. Small, dark, slightly irregular, and permanent for the scene —
## which is the whole of "the bullet destroys the map" that can be afforded
## before AB's destruction pass lands properly.
func _mark(at: Vector3, normal: Vector3, energy: float) -> void:
	if marks.size() >= MAX_CASINGS:
		var oldest: Node3D = marks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var hole := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	var scale := clampf(0.045 + energy * 0.02, 0.03, 0.22)
	mesh.size = Vector2(scale, scale)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.035, 0.03, 0.92)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	hole.mesh = mesh
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hole)
	# Lifted off the surface, or it fights the wall it is drawn on.
	hole.global_position = at + normal * 0.006
	if absf(normal.dot(Vector3.UP)) < 0.98:
		hole.look_at(at + normal, Vector3.UP)
	else:
		hole.look_at(at + normal, Vector3.FORWARD)
	marks.append(hole)


## AF1.3. Brass on the floor. Stepped rather than given to the physics server,
## with a bounce that loses most of its energy — brass does not roll far, it
## clatters twice and stops, and getting that wrong is what makes shells look
## like plastic.
func _step_casings(delta: float) -> void:
	for index in range(casings.size() - 1, -1, -1):
		var shell: Dictionary = casings[index]
		var node := shell["node"] as Node3D
		if node == null or not is_instance_valid(node):
			casings.remove_at(index)
			continue
		shell["life"] = float(shell["life"]) + delta
		if float(shell["rest"]) > 0.0:
			continue
		var velocity: Vector3 = shell["velocity"]
		velocity.y -= GRAVITY * delta
		var at: Vector3 = node.global_position + velocity * delta
		# One plane rather than a raycast per shell per frame. The floor of this
		# world is flat where a fight happens, and ninety raycasts a second for
		# brass is not a trade worth making.
		if at.y <= 0.02:
			at.y = 0.02
			if absf(velocity.y) < 0.55:
				# Settled. Lie it down: brass comes to rest on its side, and a
				# casing standing on end is the single most obvious tell that
				# nobody simulated it.
				shell["rest"] = 1.0
				node.rotation = Vector3(PI * 0.5, _rng.randf() * TAU, 0.0)
			else:
				velocity.y = absf(velocity.y) * 0.34
				velocity.x *= 0.6
				velocity.z *= 0.6
				shell["spin"] = (shell["spin"] as Vector3) * 0.5
		shell["velocity"] = velocity
		node.global_position = at
		if float(shell["rest"]) <= 0.0:
			node.rotation += (shell["spin"] as Vector3) * delta


func _retire_round(index: int) -> void:
	if index < 0 or index >= rounds.size():
		return
	var node := rounds[index]["node"] as Node3D
	if node != null and is_instance_valid(node):
		node.queue_free()
	rounds.remove_at(index)


func _retire_casing(index: int) -> void:
	if index < 0 or index >= casings.size():
		return
	var node := casings[index]["node"] as Node3D
	if node != null and is_instance_valid(node):
		node.queue_free()
	casings.remove_at(index)


## How much brass is on the floor. For the Board, the Choir, or anything that
## wants to know what happened in a room it did not watch.
func spent_brass() -> int:
	var settled := 0
	for shell: Dictionary in casings:
		if float(shell.get("rest", 0.0)) > 0.0:
			settled += 1
	return settled


## Clear the scene's brass and holes. Called on a scene change, because these
## live under this node and would otherwise go with it silently.
func clear() -> void:
	for index in range(rounds.size() - 1, -1, -1):
		_retire_round(index)
	for index in range(casings.size() - 1, -1, -1):
		_retire_casing(index)
	for hole in marks:
		if is_instance_valid(hole):
			hole.queue_free()
	marks.clear()
