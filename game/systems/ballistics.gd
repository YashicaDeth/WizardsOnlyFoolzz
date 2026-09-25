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
## AF1.1. The other half of a round having a real existence: something has to
## know when one *stopped* existing without ever arriving anywhere — out of
## range, or below the world — so a caller waiting to find out whether a shot
## connected is not left waiting forever. `payload` is echoed back exactly as
## given to `fire()`; empty for anything that did not ask to be told.
signal round_expired(payload: Dictionary)
## AD3.3. The third way a round's flight can end, distinct from the other
## two: not arriving somewhere (`round_hit`) and not running out of world
## (`round_expired`), but being reached into and taken out of the air before
## either happens.
signal round_intercepted(report: Dictionary)

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
	# AD3.1. A rocket is the one round in this table you are meant to be able
	# to answer. It leaves the tube at roughly a tenth of a pistol round's
	# speed, which is what makes AD3.3's `intercept_near()` and your own feet
	# real options against it rather than theoretical ones — you can see it
	# coming. Heavy and low-drag so the slowness is mass rather than a round
	# that stops in mid-air, and no casing, because a launcher does not throw
	# brass.
	"rocket": {
		"label": "WARHEAD", "muzzle": 38.0, "grain": 0.900, "drag": 0.004,
		"penetration": 0.85, "casing": Vector3.ZERO,
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

## Persistent brass and impact scars are useful evidence, but their meshes are
## still real scene objects. Keep the authored high-quality ceiling while
## giving the default PERFORMANCE route a smaller nearby-world budget.
static func casing_budget() -> int:
	match WorldLook.quality:
		WorldLook.Quality.ULTRA: return MAX_CASINGS
		WorldLook.Quality.HIGH: return 120
		_: return 32


static func round_budget() -> int:
	match WorldLook.quality:
		WorldLook.Quality.ULTRA: return MAX_ROUNDS
		WorldLook.Quality.HIGH: return 64
		_: return 32

static func wound_budget() -> int:
	match WorldLook.quality:
		WorldLook.Quality.ULTRA: return MAX_CASINGS
		WorldLook.Quality.HIGH: return 120
		_: return 64

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
## AF1.1. `payload` is the round's own memory of what it was fired to do —
## damage, impulse, damage type, whoever's trigger this was for — carried on
## the round rather than resolved here, so whatever it eventually hits (or
## fails to) is what decides when that damage actually happens, not the frame
## the trigger went down. Ballistics does not know what a payload means and
## never reads it; it only ever hands it back, on `round_hit` or
## `round_expired`, to whoever is listening.
func fire(from: Vector3, along: Vector3, calibre := "pistol", spread := 0.0, count := 1, shooter := "", payload := {}) -> void:
	var spec: Dictionary = CALIBRES.get(calibre, CALIBRES["pistol"])
	for index in count:
		if rounds.size() >= round_budget():
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
			"origin": from,
			"at": from,
			"was": from,
			"initial_direction": direction,
			"velocity": direction * float(spec["muzzle"]),
			"calibre": calibre,
			"spec": spec,
			"travelled": 0.0,
			"flight_time": 0.0,
			"shooter": shooter,
			"payload": payload,
		})
	_eject(from, along, calibre)


## AF1.3. The casing. Out of the port, sideways and back, tumbling — which is
## where a real one goes and is why brass ends up behind and to the right of
## whoever was shooting rather than in front of them.
func _eject(from: Vector3, along: Vector3, calibre: String) -> void:
	var spec: Dictionary = CALIBRES.get(calibre, CALIBRES["pistol"])
	# AD3.1. A launcher does not throw brass. Sized at zero in the table
	# rather than special-cased by name here, so anything else that is fired
	# without a case gets the same answer for free.
	if (spec["casing"] as Vector3).is_zero_approx():
		return
	if casings.size() >= casing_budget():
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
		round_data["flight_time"] = float(round_data.get("flight_time", 0.0)) + delta

		var query := PhysicsRayQueryParameters3D.create(round_data["was"], at)
		# AF1.1. A body's own zones are `Area3D` hitboxes (`baseline_human.gd`),
		# not physics bodies — this traced only bodies before, which is exactly
		# why nothing fired at a person could ever actually reach one through
		# here. `_trace_actor()`'s own instant raycast has collided with areas
		# from the start; this one has to now, or a round can travel forever
		# and land on nobody.
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			_land(round_data, hit, delta)
			_retire_round(index)
			continue
		if float(round_data["travelled"]) > MAX_RANGE or at.y < -30.0:
			# AF1.1. Ran out of world before it ran out of flight — still a real
			# outcome for whoever fired it, and the only one of the three ways a
			# round can stop existing that `_land()` never sees.
			var expired_payload: Dictionary = round_data.get("payload", {})
			if not expired_payload.is_empty():
				round_expired.emit(expired_payload)
			_retire_round(index)
			continue
		var node := round_data["node"] as Node3D
		if node != null and is_instance_valid(node):
			node.global_position = at
			if velocity.length() > 0.1:
				# A round fired straight up (or down) has `velocity` colinear
				# with `Vector3.UP` — the same case `_surface_basis()` already
				# guards below, just met here instead of a surface normal.
				# Unguarded, `look_at()` warns every physics step for the rest
				# of that round's flight instead of just picking a roll.
				var direction := velocity.normalized()
				var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
				node.look_at(at + velocity, up)


## AF1.2. It arrives, and the thing it arrived at is different for it.
func _land(round_data: Dictionary, hit: Dictionary, step_delta: float) -> void:
	var spec: Dictionary = round_data["spec"]
	var at: Vector3 = hit.get("position", round_data["at"])
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var velocity: Vector3 = round_data["velocity"]
	var origin: Vector3 = round_data.get("origin", round_data["was"])
	var initial_direction: Vector3 = round_data.get("initial_direction", velocity.normalized())
	# The integrator advances to the end of a frame before tracing that whole
	# segment. A collision may be near its start, so trim both distance and time
	# to the actual intercept instead of reporting the unused tail of the step.
	var stepped: float = (round_data["at"] as Vector3).distance_to(round_data["was"])
	var reached: float = at.distance_to(round_data["was"])
	var step_fraction := clampf(reached / maxf(stepped, 0.0001), 0.0, 1.0)
	var travelled_to_hit := float(round_data.get("travelled", 0.0)) - stepped + reached
	var flight_to_hit := float(round_data.get("flight_time", 0.0)) - step_delta + step_delta * step_fraction
	# Distance below the ray that left the muzzle. This is the drop a sight has
	# to compensate for, rather than simply the world's Y coordinate changing.
	var ray_distance := maxf(0.0, (at - origin).dot(initial_direction))
	var expected_on_ray := origin + initial_direction * ray_distance
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
		"travelled": maxf(0.0, travelled_to_hit),
		"flight_time": maxf(0.0, flight_to_hit),
		"drop": maxf(0.0, expected_on_ray.y - at.y),
		"speed": velocity.length(),
		"penetration": float(spec["penetration"]),
		"shooter": round_data["shooter"],
		"payload": round_data.get("payload", {}),
	}
	_mark(at, normal, energy, hit.get("collider"), velocity.normalized())
	round_hit.emit(report)


## AN2.3. The same scar a round leaves, for whatever else in this game hits a
## wall hard enough to mark it — a melee swing meeting stone rather than an
## actor, currently. Public because that caller is not a round in flight and
## has no `_land()` of its own to route through.
func mark_impact(at: Vector3, normal: Vector3, energy: float) -> void:
	_mark(at, normal, energy)


## AD3.3. "A projectile is a physical thing that can be met, not a damage
## event." Everything above resolves a round *arriving*; this is the other
## end of being met — something reaching into its flight path and taking it
## out of the air before it gets anywhere.
##
## Position-and-radius rather than an index, because the caller that wants
## this is a swing: it knows where and when it landed, not which of up to
## `MAX_ROUNDS` entries that corresponds to. Returns how many it actually
## took out, so a caller can tell the difference between cutting a round out
## of the air and swinging at nothing — which is the whole feedback the move
## needs to be worth making.
##
## Deliberately does not emit `round_hit` or `round_expired`: an intercepted
## round never arrived anywhere and did not run out of world, and a caller
## waiting on either of those to decide whether a shot connected would be
## told the wrong thing by a third outcome dressed up as one of the first
## two.
func intercept_near(position: Vector3, radius: float, by: String = "") -> int:
	if radius <= 0.0:
		return 0
	var destroyed := 0
	for index in range(rounds.size() - 1, -1, -1):
		var round_data: Dictionary = rounds[index]
		var at: Vector3 = round_data["at"]
		if position.distance_to(at) > radius:
			continue
		round_intercepted.emit({
			"position": at,
			"calibre": round_data["calibre"],
			"shooter": round_data["shooter"],
			"payload": round_data.get("payload", {}),
			"by": by,
			# What it still had left when it was taken out — a round cut down
			# on the way out of the barrel was a different save from one met
			# at the end of its travel, and only this knows the difference.
			"energy": 0.5 * float((round_data["spec"] as Dictionary)["grain"]) * (round_data["velocity"] as Vector3).length_squared(),
		})
		_retire_round(index)
		destroyed += 1
	return destroyed


## What is actually in the air right now, as positions. For anything that
## needs to decide whether meeting a round is even available to it this
## frame — an AI weighing a parry, a prompt telling the player a round is
## coming — without reaching into `rounds` and depending on its shape.
func rounds_in_flight() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for round_data: Dictionary in rounds:
		out.append(round_data["at"])
	return out


## The wound. Small, dark, slightly irregular, and permanent for the scene —
## which is the whole of "the bullet destroys the map" that can be afforded
## before AB's destruction pass lands properly.  This deliberately is not a
## QuadMesh: a dark, untextured quad is a black square wherever a player shoots
## the floor, which reads as a broken decal rather than a struck surface.
##
## 0.2b: a round into the ground (`GroundHole.is_ground`) leaves a hole instead,
## sized by the energy it arrived with, in the same capped pool as the scars.
func _mark(at: Vector3, normal: Vector3, energy: float, collider: Object = null, direction := Vector3.DOWN) -> void:
	if marks.size() >= wound_budget():
		var oldest: Node3D = marks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var surface_normal := normal.normalized()
	if surface_normal.length_squared() < 0.001:
		surface_normal = Vector3.UP
	if GroundHole.is_ground(collider, surface_normal):
		marks.append(GroundHole.carve(self, at, surface_normal, GroundHole.radius_for_round(energy), direction))
		return
	var radius := clampf(0.030 + energy * 0.012, 0.028, 0.135)

	# A tiny two-layer cylinder scar gives the hit a real, circular outline at
	# grazing angles: burnt displaced material around a recessed black centre.
	# It is cheap enough to leave behind with the brass, but no longer exposes a
	# full square when the camera looks down at the floor.
	var wound := Node3D.new()
	wound.name = "BulletWound"
	add_child(wound)
	# Global transforms only have a valid world after the wound joins this
	# Ballistics node.  Setting them first silently collapsed every scar to the
	# origin in a headless world and could make unrelated impacts stack together.
	wound.global_position = at + surface_normal * 0.004
	wound.global_basis = _surface_basis(surface_normal)

	var rim := _wound_disc(radius, 0.006, Color("38140d"), "ImpactRim")
	wound.add_child(rim)
	var core := _wound_disc(radius * 0.61, 0.008, Color("080605"), "ImpactCore")
	core.position.y = 0.003
	wound.add_child(core)
	marks.append(wound)


## Builds a very shallow, many-sided disc.  The local Y axis is aligned to the
## impact normal by `_surface_basis`, so one model reads correctly on a floor,
## wall, ramp, or ceiling instead of needing a separate decal path for each.
func _wound_disc(radius: float, depth: float, tint: Color, label: String) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.88
	mesh.height = depth
	mesh.radial_segments = 12
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.0
	material.roughness = 0.96
	mesh.material = material
	disc.mesh = mesh
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc


## Godot cylinder meshes point their local Y axis out of the surface.  `look_at`
## would aim -Z instead, which is why the prior quad needed special cases and
## still presented its square face incorrectly on the floor.
func _surface_basis(surface_normal: Vector3) -> Basis:
	var guide := Vector3.FORWARD
	if absf(surface_normal.dot(guide)) > 0.94:
		guide = Vector3.RIGHT
	var right := guide.cross(surface_normal).normalized()
	var forward := surface_normal.cross(right).normalized()
	return Basis(right, surface_normal, forward)


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
