class_name RoomMirrorView
extends SubViewport

## Compatibility is intentional: the freestanding BodyMirror follows a body,
## while the room's wall mirror reflects the viewer across a fixed plane. They
## share a technique (one live World3D), not a camera contract.

const DEFAULT_RESOLUTION := Vector2i(512, 640)

var camera: Camera3D
var plane_origin := Vector3.ZERO
var plane_normal := Vector3.FORWARD


static func make(world: World3D, resolution := DEFAULT_RESOLUTION) -> RoomMirrorView:
	var view := RoomMirrorView.new()
	view.size = resolution
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.world_3d = world
	view.own_world_3d = false
	view._assemble()
	return view


func _assemble() -> void:
	camera = Camera3D.new()
	camera.name = "MirrorCamera"
	camera.fov = 48.0
	camera.near = 0.05
	camera.far = 60.0
	add_child(camera)


func place(origin: Vector3, normal: Vector3) -> void:
	plane_origin = origin
	plane_normal = normal.normalized() if normal.length_squared() > 0.0 else Vector3.FORWARD


static func reflect_point(origin: Vector3, normal: Vector3, point: Vector3) -> Vector3:
	var unit := normal.normalized()
	return point - unit * (2.0 * unit.dot(point - origin))


static func reflect_direction(normal: Vector3, direction: Vector3) -> Vector3:
	var unit := normal.normalized()
	return direction - unit * (2.0 * unit.dot(direction))


func reflect(viewer: Transform3D) -> void:
	if camera == null:
		return
	var eye := reflect_point(plane_origin, plane_normal, viewer.origin)
	var gaze := reflect_direction(plane_normal, -viewer.basis.z)
	var up := reflect_direction(plane_normal, viewer.basis.y)
	camera.global_position = eye
	if absf(gaze.normalized().dot(up.normalized())) <= 0.999:
		camera.look_at(eye + gaze, up)
	camera.near = maxf(0.05, distance_from(viewer.origin))


func distance_from(point: Vector3) -> float:
	return absf(plane_normal.normalized().dot(point - plane_origin))


func live() -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func sleep() -> void:
	render_target_update_mode = SubViewport.UPDATE_DISABLED
