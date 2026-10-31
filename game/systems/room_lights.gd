class_name RoomLights
extends Node3D

## Greg, 28 September (question boxes, late): the vat room, the Service Arcade,
## the Support Unit and the vehicle bay are pools of light. Mostly black, a
## harsh pool under each lamp, and you move between them, in sick green-white
## lab light. The lamps flicker more as tension rises and some die for good.
## When the glass bursts, red strobes turn over the green tubes, which stay on
## but stutter; one klaxon blast, then silent strobing. Red only on danger.
##
## A room hands over its ceiling lamps: each keeps a dim glow of its own and
## throws its light straight down into the pool. The room sets `tension`
## (0..1), as it does for AmbientBed.

const AMBIENT_AUDIO := preload("res://systems/ambient_audio.gd")
## Per room: the pool's radius on the floor (m), how much of the preset's
## ambient light is kept, and a fog of its own where the preset's washed the
## black out (the arcade's ossuary purple).
const PROFILES := {
	"vat": {"pool": 1.25, "ambient": 0.45},
	"arcade": {"pool": 1.6, "ambient": 0.3, "fog": "0b100a"},
	"support": {"pool": 2.4, "ambient": 0.35},
	"bay": {"pool": 1.9, "ambient": 0.35},
}
const LAB_LIGHT := Color("b8d6a6")
const STROBE_RED := Color("ff1c10")
## What the lamp keeps for itself once its light goes into the pool.
const GLOW := 0.2
## The pool's brightness per metre the lamp hangs above the floor.
const POOL_ENERGY := 10.0
## Flickers a second per lamp, calm to panicked.
const FLICKER_RATE := Vector2(0.02, 0.8)
## A lamp's chance a second of dying for good at full tension. At most a third
## of a room's lamps go, so there are always pools to move between.
const DEATH_RATE := 0.02
const STROBE_TURN := TAU * 0.8

var profile := "vat"
var tension := 0.25
var lamps: Array[Dictionary] = []
var strobes: Array[Node3D] = []
var alarm := false
var klaxons := 0
var rng := RandomNumberGenerator.new()
var _ceiling: Array = []


func setup(room: String, ceiling: Array) -> RoomLights:
	profile = room if PROFILES.has(room) else "vat"
	_ceiling = ceiling
	name = "RoomLights"
	return self


func _ready() -> void:
	rng.randomize()
	var room: Dictionary = PROFILES[profile]
	for light: OmniLight3D in _ceiling:
		var height := maxf(1.0, light.position.y)
		var pool := SpotLight3D.new()
		pool.name = "Pool"
		pool.rotation_degrees = Vector3(-90, 0, 0)
		pool.light_color = LAB_LIGHT
		pool.spot_range = height * 1.35
		pool.spot_angle = rad_to_deg(atan(float(room.pool) / height))
		# A hard rim: the pool ends, it does not fade into the black.
		pool.spot_angle_attenuation = 4.0
		light.add_child(pool)
		light.light_color = LAB_LIGHT
		var lamp := {"light": light, "pool": pool, "glow": light.light_energy * GLOW, "energy": POOL_ENERGY * height,
			"flicker": 0.0, "hold": 0.0, "on": true, "dying": false, "dead": false}
		lamps.append(lamp)
		_set_level(lamp, 1.0)
	for child in get_parent().get_children():
		var world := child as WorldEnvironment
		if world == null or world.environment == null:
			continue
		world.environment.ambient_light_energy *= float(room.ambient)
		if room.has("fog"):
			var fog := Color(str(room.fog))
			world.environment.fog_light_color = fog
			world.environment.volumetric_fog_albedo = fog
			world.environment.volumetric_fog_emission = fog.darkened(0.7)


func _process(delta: float) -> void:
	tension = clampf(tension, 0.0, 1.0)
	var rate := lerpf(FLICKER_RATE.x, FLICKER_RATE.y, tension * tension)
	if alarm:
		rate = maxf(rate, 2.0)
	var going := lamps.filter(func(lamp: Dictionary) -> bool: return lamp.dying or lamp.dead).size()
	for lamp in lamps:
		if lamp.dead:
			continue
		if not lamp.dying and (going + 1) * 3 <= lamps.size() and rng.randf() < DEATH_RATE * tension * tension * delta:
			# One last stutter, then dark for good.
			lamp.dying = true
			lamp.flicker = 0.9
			going += 1
		elif lamp.flicker <= 0.0 and rng.randf() < rate * delta:
			lamp.flicker = rng.randf_range(0.1, 0.3 + tension * 0.6)
		if lamp.flicker <= 0.0:
			if lamp.dying:
				lamp.dead = true
				_set_level(lamp, 0.0)
			else:
				_set_level(lamp, 1.0)
			continue
		lamp.flicker -= delta
		lamp.hold -= delta
		if lamp.hold <= 0.0:
			lamp.on = not lamp.on
			lamp.hold = rng.randf_range(0.03, 0.12)
		# Under the strobes the tubes stay on, only stuttering.
		_set_level(lamp, 1.0 if lamp.on else (0.35 if alarm else 0.06))
	for beacon in strobes:
		beacon.rotate_y(STROBE_TURN * delta)


func _set_level(lamp: Dictionary, level: float) -> void:
	(lamp.light as OmniLight3D).light_energy = float(lamp.glow) * level
	var pool := lamp.pool as SpotLight3D
	pool.light_energy = float(lamp.energy) * level
	pool.visible = not lamp.dead


## The glass bursts: red strobes turn at each point, one klaxon blast.
func burst(points: Array) -> void:
	if alarm:
		return
	alarm = true
	for at: Vector3 in points:
		var beacon := Node3D.new()
		beacon.name = "Strobe"
		beacon.position = at
		beacon.rotation.y = rng.randf() * TAU
		add_child(beacon)
		# Two beams back to back, tipped down so the sweep lands on the floor.
		for side in [0.0, PI]:
			var beam := SpotLight3D.new()
			beam.light_color = STROBE_RED
			beam.light_energy = 40.0
			beam.spot_range = 10.0
			beam.spot_angle = 22.0
			beam.rotation = Vector3(-0.85, side, 0.0)
			beacon.add_child(beam)
		var housing := MeshInstance3D.new()
		var dome := CylinderMesh.new()
		dome.top_radius = 0.1
		dome.bottom_radius = 0.13
		dome.height = 0.18
		dome.material = WorldLook.emissive(STROBE_RED, 3.0)
		housing.mesh = dome
		housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beacon.add_child(housing)
		strobes.append(beacon)
	var horn := AudioStreamPlayer.new()
	horn.name = "Klaxon"
	horn.stream = AMBIENT_AUDIO.stream("klaxon")
	horn.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(horn)
	horn.play()
	horn.finished.connect(horn.queue_free)
	klaxons += 1
