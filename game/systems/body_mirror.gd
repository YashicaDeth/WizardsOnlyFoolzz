class_name BodyMirror
extends Node3D

## B9.1 / B9.2 / B10.10 / AH1.5. The mirror in the room shows your body, current.
##
## Nine passes went into this rig — anatomy, severing, implants, wounds, blood —
## and the player has never once been able to look at it. First person shows you
## a pair of hands. Everything the game spends its detail on happens to a body
## you cannot see, which is close to the worst possible arrangement: all of the
## cost and none of the payoff.
##
## The whole design decision here is **not to build a second body**.
##
## A portrait rig that mirrors the real one is the obvious build and it is wrong,
## because "with everything done to it" then means keeping two bodies in step
## through severing, hardware, wounds, bleeding and the hour — and the day they
## disagree is the day the mirror starts lying, which is worse than not having
## one. So this renders *the actual rig* through a second camera into a
## `SubViewport` that shares the world. There is nothing to keep in step. If the
## body has a hole in it, the hole is in the mirror, because it is the same hole.
##
## B9.2 — "including the things you cannot see on yourself in first person" —
## then costs nothing extra and is the real reason it is worth having: your own
## face, your own back, the wound between your shoulder blades, what the thing
## you just fought did to you from behind.

## Resolution of the reflection. Deliberately modest: a mirror in a filthy room
## is not a 4K monitor, and this is a second render of the whole scene.
const SURFACE := Vector2i(540, 900)

## How far in front of the subject the reflected camera stands. A real mirror at
## distance d shows you as if you were 2d away, which is why a mirror always
## reads as further off than the wall it is on.
const STANDOFF := 1.15

enum Facing {
	FRONT,  ## What a mirror on the wall shows: your own face.
	BACK,   ## Turned. B9.2's real payload — you do not otherwise own this view.
}

var subject: Node3D = null
var facing: int = Facing.FRONT
## Slowly orbits instead of sitting still, so a body can be read all the way
## round without the player having to walk in a circle.
var orbit := false
var orbit_speed := 0.45

var viewport: SubViewport
var camera: Camera3D
var surface: MeshInstance3D
var _clock := 0.0


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "MirrorView"
	viewport.size = SURFACE
	# The point of the whole thing: share the world rather than owning one, so
	# what is reflected is the real body in the real room and not a copy that has
	# to be maintained.
	viewport.own_world_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.transparent_bg = false
	add_child(viewport)

	camera = Camera3D.new()
	camera.name = "MirrorEye"
	camera.fov = 48.0
	camera.current = true
	viewport.add_child(camera)

	surface = MeshInstance3D.new()
	surface.name = "Glass"
	var pane := QuadMesh.new()
	pane.size = Vector2(1.05, 1.75)
	surface.mesh = pane
	var material := StandardMaterial3D.new()
	material.albedo_texture = viewport.get_texture()
	# A mirror emits what it shows rather than being lit — otherwise the room's
	# own darkness lands on the reflection twice, once in the reflected scene and
	# again on the glass.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.88, 0.86, 0.82)
	# A `QuadMesh` faces +Z, and a mirror hung the wrong way round is simply
	# invisible rather than obviously backwards — which cost a capture. Glass is
	# silvered on one side in life and visible from both here, because a mirror
	# you cannot find is worse than one you can see the back of.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = material
	add_child(surface)


## Point it at a body. Anything with a transform will do; it does not have to be
## a `BaselineHuman`, which is what lets the same object serve the vat, the shed
## and a wall mirror without three implementations.
func watch(body: Node3D) -> void:
	subject = body


func set_facing(value: int) -> void:
	facing = value


func _process(delta: float) -> void:
	_clock += delta
	if subject == null or not is_instance_valid(subject) or camera == null:
		return
	# Aim at the chest rather than the origin: a rig's origin is at its feet, and
	# a mirror framed on somebody's boots is a comedy.
	var centre: Vector3 = subject.global_position + Vector3(0, 1.05, 0)
	var angle := 0.0 if facing == Facing.FRONT else PI
	if orbit:
		angle += _clock * orbit_speed
	# In the subject's own frame, so turning the body turns the reflection — a
	# mirror fixed to world axes stops being a mirror the moment anybody moves.
	var direction: Vector3 = subject.global_transform.basis * Vector3(sin(angle), 0.0, cos(angle))
	camera.global_position = centre + direction * STANDOFF + Vector3(0, 0.12, 0)
	camera.look_at(centre, Vector3.UP)


## Where the reflected camera is standing, for anything that needs to know — a
## test, or a scene that does not want the mirror's own eye inside a wall.
func eye_position() -> Vector3:
	return camera.global_position if camera != null else global_position


func stop() -> void:
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func resume() -> void:
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
