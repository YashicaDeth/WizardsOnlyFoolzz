class_name ThreatCompass
extends Control

## Where the next blow is coming from. Every enemy winding up a strike reports
## itself each frame; this draws a red arc at the screen edge in that
## direction — behind you at the bottom, to your left on the left — that
## thickens and heats as their blow comes due. Fighting in every direction is
## only fair if you can read every direction. Reports expire on their own a
## moment after an enemy stops reporting, so nothing lingers.

const HOLD := 0.12
const BLOOD := Color("c8151c")
const HOT := Color("ffb04a")

var _threats: Dictionary = {}
var camera: Camera3D
var elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## `progress` 0..1 is how far into the wind-up; 1 is the blow landing.
func report(key: String, world_position: Vector3, progress: float) -> void:
	_threats[key] = {"at": world_position, "progress": clampf(progress, 0.0, 1.0), "ttl": HOLD}


func active_count() -> int:
	return _threats.size()


## Screen-edge angle for a world point, 0 = straight ahead (top), PI = behind
## (bottom), positive = to the right. Flat: height never decides direction.
static func bearing(camera_basis: Basis, from: Vector3, to: Vector3) -> float:
	var forward := -camera_basis.z
	forward.y = 0.0
	var right := camera_basis.x
	right.y = 0.0
	var toward := to - from
	toward.y = 0.0
	if toward.length_squared() < 0.0001 or forward.length_squared() < 0.0001:
		return 0.0
	return atan2(toward.normalized().dot(right.normalized()), toward.normalized().dot(forward.normalized()))


func _process(delta: float) -> void:
	elapsed += delta
	for key in _threats.keys():
		_threats[key].ttl = float(_threats[key].ttl) - delta
		if float(_threats[key].ttl) <= 0.0:
			_threats.erase(key)
	queue_redraw()


func _draw() -> void:
	var cam := camera if camera != null and is_instance_valid(camera) else get_viewport().get_camera_3d()
	if cam == null or _threats.is_empty():
		return
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	for threat in _threats.values():
		var angle := bearing(cam.global_transform.basis, cam.global_position, threat.at)
		var p := float(threat.progress)
		# Screen angle: 0 at the top, clockwise to the right.
		var screen_angle := angle - PI * 0.5
		var span := lerpf(0.18, 0.42, p)
		var colour := BLOOD.lerp(HOT, p * p)
		colour.a = 0.55 + 0.45 * p
		var width := lerpf(5.0, 15.0, p)
		# Squash the ring to the frame so side threats sit at the side edges.
		var points := PackedVector2Array()
		for i in 13:
			var a := screen_angle - span * 0.5 + span * float(i) / 12.0
			points.append(centre + Vector2(cos(a) * size.x * 0.46, sin(a) * size.y * 0.44))
		# A dark underlay so the arc reads over any world, however busy.
		draw_polyline(points, Color(0, 0, 0, 0.55), width + 5.0)
		draw_polyline(points, colour, width)
		if p > 0.85:
			# Due: a pulse outward so the last instant is unmissable.
			var pulse := 1.0 + 0.04 * sin(elapsed * 40.0)
			var outer := PackedVector2Array()
			for pt in points:
				outer.append(centre + (pt - centre) * pulse * 1.03)
			draw_polyline(outer, Color(HOT, 0.5), 2.0)
