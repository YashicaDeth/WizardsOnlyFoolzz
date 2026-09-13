class_name BodyMirror
extends SubViewport

## B9.1/B9.2, B10.10, AH1.5. The mirror renders this rig live, with everything
## done to it — including the things you cannot see on yourself in first person.
##
## `black_mirror.gd` is the handheld's glass and is a different object: a dark
## surface you look *into*, drawn in 2D, whose reflection is deliberately vague.
## This is the mirror on the wall of the room, and it has the opposite job. It
## has to be exact.
##
## The technique is A10's, pointed sideways instead of down. `SatelliteView`
## renders the player's own world from a second camera rather than keeping a
## copy of the region in step; this renders the player's own body from a second
## camera rather than keeping a copy of the rig in step. That single decision is
## what makes "with everything done to it" true for nothing: a severed arm is
## missing in the mirror because it is missing on the rig, an implant shows
## because it is installed, a garment shows because it is worn. There is no
## second body to update and therefore no second body to forget to update.
##
## **What you cannot see on yourself.** In first person the player's own head is
## behind the camera and their back is behind them, so the anatomy is carrying
## damage nobody can look at. The mirror is the only surface in the game where
## the player's own face is visible to the player, which is why B9.2 is a
## separate segment from B9.1 rather than a detail of it.

## A mirror does not need the resolution a map does — it is a surface on a wall
## at arm's length, not a region seen from two hundred metres.
const DEFAULT_RESOLUTION := Vector2i(512, 640)

var camera: Camera3D
## The plane, in world space. `normal` points out of the glass, into the room.
var plane_origin := Vector3.ZERO
var plane_normal := Vector3.FORWARD


static func make(world: World3D, resolution := DEFAULT_RESOLUTION) -> BodyMirror:
	var view := BodyMirror.new()
	view.size = resolution
	view.transparent_bg = false
	# Nothing renders until somebody asks. A mirror in a room the player is not
	# standing in is a second render of a body, every frame, for nobody — the
	# same rule A10.8 made for the satellite.
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.world_3d = world
	view.own_world_3d = false
	view._assemble()
	return view


func _assemble() -> void:
	camera = Camera3D.new()
	camera.name = "MirrorCamera"
	# Narrow. A mirror is a window the size of the glass, not a fisheye, and a
	# wide FOV here makes the body it shows read as further away than the room
	# says it is.
	camera.fov = 48.0
	camera.near = 0.05
	camera.far = 60.0
	# Never `current`: this camera belongs to its own viewport and must not
	# steal the one the player is looking through.
	add_child(camera)


## Where the glass is. Called once when the room is built.
func place(origin: Vector3, normal: Vector3) -> void:
	plane_origin = origin
	plane_normal = normal.normalized() if normal.length_squared() > 0.0 else Vector3.FORWARD


## The reflection of a point across a plane. Split out and static because this
## is the only part of a mirror that can be wrong in a way a screenshot will not
## show you — a body at the wrong depth still looks like a body.
static func reflect_point(origin: Vector3, normal: Vector3, point: Vector3) -> Vector3:
	var unit := normal.normalized()
	return point - unit * (2.0 * unit.dot(point - origin))


## The reflection of a direction. No origin term: directions do not have one,
## and using the point form on a look vector is the classic way to end up with a
## mirror that is subtly wrong everywhere except dead centre.
static func reflect_direction(normal: Vector3, direction: Vector3) -> Vector3:
	var unit := normal.normalized()
	return direction - unit * (2.0 * unit.dot(direction))


## Put the camera where the viewer's reflection stands. Everything the mirror
## shows follows from this one placement.
func reflect(viewer: Transform3D) -> void:
	if camera == null:
		return
	var eye := reflect_point(plane_origin, plane_normal, viewer.origin)
	# The viewer looks down -Z in Godot, so the reflected gaze is the reflection
	# of that, and the reflected up vector keeps the horizon level.
	var gaze := reflect_direction(plane_normal, -viewer.basis.z)
	var up := reflect_direction(plane_normal, viewer.basis.y)
	camera.global_position = eye
	# Degenerate only if somebody is looking exactly along their own up vector,
	# which is not a thing a standing body does — but a mirror that throws on
	# one frame is worse than one that holds its last angle.
	if absf(gaze.normalized().dot(up.normalized())) > 0.999:
		return
	camera.look_at(eye + gaze, up)
	# Clip at the glass. The reflection camera stands behind the mirror, so
	# everything between it and the plane is the wall the mirror is set into —
	# and rendering the back of that wall is a black mirror. Culling the wall
	# instead works, and then the camera sees the void where the wall was; a
	# near plane at the glass removes it without removing the room.
	camera.near = maxf(0.05, distance_from(viewer.origin))


## How far the viewer is from the glass, which is what a room uses to decide
## whether the mirror is worth rendering at all.
func distance_from(point: Vector3) -> float:
	return absf(plane_normal.normalized().dot(point - plane_origin))


func request_frame() -> void:
	render_target_update_mode = SubViewport.UPDATE_ONCE


func live() -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func sleep() -> void:
	render_target_update_mode = SubViewport.UPDATE_DISABLED
