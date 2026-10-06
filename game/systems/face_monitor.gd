class_name FaceMonitor
extends Control

## imp-68. Greg, 5 Oct ~19:00: the round frowning face portrait "looks dumb".
## The face is now a third CRT, bolted rather than swinging, hung beside the
## heart and brain traces in the nerve rig's own copper, bone and phosphor:
##
##   "xray"     your own skull on a phosphor plate. The eyes in the orbits
##              narrow with pain and dim and drift as consciousness goes, the
##              jaw hangs open and gasps as stamina runs out and locks shut in
##              agony, the plate dims with blood loss, a head wound fractures
##              the vault, and the picture rolls when you are about to go.
##   "bodycam"  a live body-cam feed of your own rigged head, shot from a rig
##              held in front of the face. Pain flushes and shakes it, blood
##              loss starves it, fading rolls it. Without a head to point at
##              (a room with no player body) it shows the skull plate.
##
## Driven by `GothicFieldHud.set_state()`; it has no numbers of its own.

const CellOutzType := preload("res://systems/celloutz_type.gd")
## The dial (`GothicFieldHud.face_style`, Pause > DISPLAY / HUD > HUD FACE).
## "mask" is the old jester mask, drawn by the HUD itself.
const STYLES := ["xray", "bodycam", "mask"]
const DEFAULT_STYLE := "xray"
const BONE := Color("ead4ad")
const BLOOD := Color("a81716")
const COPPER := Color("dc5827")
const PHOSPHOR := Color("6fe0c8")
const ALARM := Color("ff5a4a")
const VIOLET := Color("7a55c9")
const HOUSING := Color("2a2626")
## Where it hangs: between the two swinging monitors, below them. The box is
## centred on `size.x + ANCHOR_X`.
const ANCHOR_X := -284.0
const BOX := Rect2(Vector2(-50, 150), Vector2(100, 108))
const SCREEN := Rect2(Vector2(-42, 157), Vector2(84, 84))
## The body-cam feed: pixels across, frames a second, metres in front of the
## face it sits, and the lens.
const FEED_PIXELS := 112
const FEED_RATE := 24.0
const FEED_REACH := 0.5
const FEED_FOV := 38.0
## The render layer the head sits on while the eye is inside it.
const HEAD_LAYER := 20

var style := "xray"
var health := 100.0
var blood := 1.0
var stamina := 100.0
var pain := 0.0
var consciousness := 100.0
var head_damage := 0.0
var magick_unlocked := false
var magick := 0.0
var elapsed := 0.0
var head: Node3D

var _feed: SubViewport
var _feed_camera: Camera3D
var _feed_view: TextureRect
var _glass: Control
var _plate: Control
var _feed_clock := 0.0
var _redraw_clock := 0.0
var _head_on_layer := false

const FEED_SHADER := """
shader_type canvas_item;
uniform vec3 ink = vec3(0.435, 0.878, 0.784);
uniform float gain = 1.0;
uniform float pain = 0.0;
uniform float blood = 1.0;
uniform float wake = 1.0;
uniform float roll = 0.0;
uniform float time = 0.0;
void fragment() {
	vec2 uv = vec2(UV.x, fract(UV.y + roll));
	vec3 src = texture(TEXTURE, uv).rgb;
	float l = clamp(dot(src, vec3(0.299, 0.587, 0.114)) * gain, 0.0, 1.0);
	l = pow(l, 0.75);
	vec3 c = ink * l * 1.25;
	float throb = 0.6 + 0.4 * sin(time * 9.0);
	c = mix(c, vec3(l * 1.25, l * 0.22, l * 0.18), clamp(pain * 0.6 * throb, 0.0, 1.0));
	c *= mix(0.4, 1.0, blood);
	c *= 0.84 + 0.16 * sin(UV.y * 260.0);
	float n = fract(sin(dot(UV * vec2(91.7, 37.3) + vec2(time * 3.1, time * 1.7), vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * (0.08 + 0.18 * (1.0 - wake));
	c *= mix(0.3, 1.0, smoothstep(0.72, 0.3, distance(UV, vec2(0.5))));
	COLOR = vec4(c, 1.0);
}
"""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate = Control.new()
	_plate.name = "SkullPlate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.clip_contents = true
	_plate.draw.connect(_draw_plate)
	add_child(_plate)


func set_state(values: Dictionary) -> void:
	health = clampf(float(values.get("health", health)), 0.0, 100.0)
	blood = clampf(float(values.get("blood", blood)), 0.0, 1.0)
	stamina = clampf(float(values.get("stamina", stamina)), 0.0, 100.0)
	pain = clampf(float(values.get("pain", pain)), 0.0, 100.0)
	consciousness = clampf(float(values.get("consciousness", consciousness)), 0.0, 100.0)
	magick_unlocked = bool(values.get("magick_unlocked", magick_unlocked))
	magick = clampf(float(values.get("magick", magick)), 0.0, 1.0)
	var regions: Dictionary = values.get("wound_regions", {})
	head_damage = clampf(float(regions.get("head", head_damage)), 0.0, 1.0)


func set_style(next: String) -> void:
	style = next
	_sync_feed()


## The player's own head: the zone node the rig keeps on the skeleton, so the
## feed follows every hit lean, stumble and ragdoll the body does.
func attach_head(body: Node) -> void:
	head = null
	if body != null and is_instance_valid(body) and "parts" in body:
		head = (body.get("parts") as Dictionary).get("head") as Node3D
	_sync_feed()


## The eye sits inside the skull, so the Hunt hides the head from it; hiding
## the node would hide it from this feed too. While `hidden`, every piece of
## the head (zone part, dressing, rigged skin) goes on HEAD_LAYER, which the
## eye's camera does not draw and the feed does; otherwise back on layer 1.
func film_head(eye: Camera3D, body: Node, hidden: bool) -> void:
	if not hidden and not _head_on_layer:
		return
	_head_on_layer = hidden
	eye.set_cull_mask_value(HEAD_LAYER, not hidden)
	var pieces: Array = []
	var part := (body.get("parts") as Dictionary).get("head") as Node3D if body != null and "parts" in body else null
	if part != null:
		pieces.append(part)
		pieces.append_array(part.find_children("*", "VisualInstance3D", true, false))
	var rigged: Node = body.get("rigged") if body != null and "rigged" in body else null
	if rigged != null and is_instance_valid(rigged):
		pieces.append_array((rigged.get("zone_meshes") as Dictionary).get("head", []))
	# ponytail: rescans the head every frame it is hidden (dressing is rebuilt
	# underneath it); cache on child count if it ever shows in a profile.
	var mask := 1 << (HEAD_LAYER - 1) if hidden else 1
	for piece in pieces:
		if piece is VisualInstance3D and is_instance_valid(piece):
			(piece as VisualInstance3D).layers = mask


## Whether the live feed is what is on the screen right now.
func feeding() -> bool:
	return style == "bodycam" and head != null and is_instance_valid(head) and head.is_inside_tree()


func _sync_feed() -> void:
	var want := feeding()
	if want and _feed == null:
		_build_feed()
	if _feed != null:
		_feed_view.visible = want
		_feed.render_target_update_mode = SubViewport.UPDATE_ONCE if want else SubViewport.UPDATE_DISABLED


func _build_feed() -> void:
	_feed = SubViewport.new()
	_feed.name = "HeadFeed"
	_feed.size = Vector2i(FEED_PIXELS, FEED_PIXELS)
	_feed.positional_shadow_atlas_size = 0
	_feed.msaa_3d = Viewport.MSAA_DISABLED
	_feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_feed)
	_feed_camera = Camera3D.new()
	_feed_camera.fov = FEED_FOV
	_feed_camera.near = 0.05
	_feed_camera.far = 4.0
	_feed.add_child(_feed_camera)
	_feed_camera.current = true
	# A ring light on the rig: the face is usually turned from the sun. It
	# lights only HEAD_LAYER, so it touches nothing the eye can see.
	var ring := OmniLight3D.new()
	ring.name = "RingLight"
	ring.omni_range = 1.2
	ring.light_energy = 1.4
	ring.light_color = Color("f2e2c8")
	ring.light_cull_mask = 1 << (HEAD_LAYER - 1)
	_feed_camera.add_child(ring)
	_feed_view = TextureRect.new()
	_feed_view.name = "FeedView"
	_feed_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_view.texture = _feed.get_texture()
	_feed_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_feed_view.stretch_mode = TextureRect.STRETCH_SCALE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FEED_SHADER
	material.shader = shader
	_feed_view.material = material
	add_child(_feed_view)
	# Glass and cracks go over the picture, so they are their own layer.
	_glass = Control.new()
	_glass.name = "Glass"
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glass.draw.connect(_draw_glass)
	add_child(_glass)


func _process(delta: float) -> void:
	elapsed += delta
	if feeding():
		_place_feed()
		_feed_clock += delta
		if _feed_clock >= 1.0 / FEED_RATE:
			_feed_clock = 0.0
			_feed.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif _feed != null and _feed_view.visible:
		_sync_feed()
	var screen := _screen_rect()
	_plate.position = screen.position
	_plate.size = screen.size
	_plate.visible = not feeding()
	_redraw_clock += delta
	if _redraw_clock >= 1.0 / 20.0:
		_redraw_clock = 0.0
		queue_redraw()
		_plate.queue_redraw()
		if _glass != null:
			_glass.queue_redraw()


func _origin() -> Vector2:
	return Vector2(size.x + ANCHOR_X, 0.0)


func _screen_rect() -> Rect2:
	return Rect2(_origin() + SCREEN.position, SCREEN.size)


## The rig is held at arm's length in front of the face and looks back at it.
## Pain shakes it; an empty body breathes it up and down.
func _place_feed() -> void:
	var at := head.global_position + Vector3.UP * 0.02
	var face := -head.global_basis.z
	face.y = 0.0
	face = face.normalized() if face.length_squared() > 0.0001 else Vector3.FORWARD
	var shake := Vector3(sin(elapsed * 41.0), cos(elapsed * 37.0), 0.0) * (pain / 100.0) * 0.012
	var spent := 1.0 - stamina / 100.0
	var breath := Vector3.UP * sin(elapsed * lerpf(1.1, 4.4, spent)) * spent * 0.02
	_feed_camera.global_position = at + face * FEED_REACH + Vector3.UP * 0.04 + shake + breath
	_feed_camera.look_at(at, Vector3.UP)
	var screen := _screen_rect()
	_feed_view.position = screen.position
	_feed_view.size = screen.size
	var material := _feed_view.material as ShaderMaterial
	material.set_shader_parameter("ink", _ink())
	material.set_shader_parameter("pain", pain / 100.0)
	material.set_shader_parameter("blood", blood)
	material.set_shader_parameter("wake", consciousness / 100.0)
	material.set_shader_parameter("roll", _roll())
	material.set_shader_parameter("time", elapsed)


func _ink() -> Color:
	if health < 35.0:
		return ALARM
	if magick_unlocked and magick > 0.52:
		return PHOSPHOR.lerp(VIOLET.lightened(0.3), 0.55)
	return PHOSPHOR


## Vertical hold failing: the picture slips a frame at a time as you fade.
func _roll() -> float:
	if consciousness >= 45.0:
		return 0.0
	var loss := 1.0 - consciousness / 45.0
	return fposmod(elapsed * loss * 0.9, 1.0) if sin(elapsed * 1.7) > 0.2 - loss else 0.0


func _draw() -> void:
	var origin := _origin()
	# Two short cables to the top edge: it is bolted, not swinging.
	for side in [-1.0, 1.0]:
		var top := origin + Vector2(side * 34.0, 0.0)
		var low := origin + Vector2(side * 34.0, BOX.position.y)
		draw_line(top, low, Color(0.08, 0.06, 0.06, 0.95), 2.0)
		draw_line(top + Vector2(2, 0), low + Vector2(2, 0), COPPER * Color(1, 1, 1, 0.3), 1.0)
	var box := Rect2(origin + BOX.position, BOX.size)
	draw_rect(box, HOUSING)
	draw_rect(box, BONE * Color(1, 1, 1, 0.35), false, 1.2)
	for bolt in [box.position + Vector2(4, 4), Vector2(box.end.x - 4, box.position.y + 4)]:
		draw_circle(bolt, 1.4, COPPER)
	var screen := _screen_rect()
	draw_rect(screen, Color(0.01, 0.05, 0.045))
	var tag := "CAM" if feeding() else "SKL"
	CellOutzType.draw_condensed(self, Vector2(screen.position.x, box.end.y - 9.0), tag, 6.0, BONE * Color(1, 1, 1, 0.6), 0.4)
	if feeding():
		# A recording dot: the feed is live.
		if fposmod(elapsed, 1.2) < 0.7:
			draw_circle(Vector2(screen.end.x - 4.0, box.end.y - 6.0), 1.8, BLOOD.lightened(0.2))


func _draw_glass() -> void:
	if feeding():
		_draw_glass_marks(_glass, _screen_rect())


## The skull plate is its own clipped layer, so a rolling picture slides off
## the glass instead of over the housing.
func _draw_plate() -> void:
	var local := Rect2(Vector2.ZERO, _plate.size)
	_draw_skull(_plate, local)
	_draw_glass_marks(_plate, local)


## Scanlines, the head-wound tear, and cracks across the glass.
func _draw_glass_marks(canvas: CanvasItem, screen: Rect2) -> void:
	for line in range(0, int(screen.size.y), 3):
		canvas.draw_line(screen.position + Vector2(0, line), screen.position + Vector2(screen.size.x, line), Color(0, 0, 0, 0.16), 1.0)
	if head_damage > 0.08:
		var tear := screen.position.y + fposmod(elapsed * 34.0, screen.size.y)
		canvas.draw_rect(Rect2(screen.position.x, tear, screen.size.x, 2.0 + head_damage * 5.0), Color(0.8, 0.9, 0.9, 0.3 * head_damage))
		var hit := screen.position + Vector2(screen.size.x * 0.78, screen.size.y * 0.16)
		for arm in 4:
			var angle := 1.9 + float(arm) * 0.72
			var reach := (14.0 + float(arm % 2) * 9.0) * (0.4 + head_damage)
			var elbow := hit + Vector2.from_angle(angle) * reach * 0.5 + Vector2(2, -1) * float(arm % 2)
			canvas.draw_polyline(PackedVector2Array([hit, elbow, hit + Vector2.from_angle(angle + 0.2) * reach]), Color(0.9, 0.95, 0.95, 0.35 + head_damage * 0.3), 1.0)


# --- the skull plate ------------------------------------------------------------

func _draw_skull(p: CanvasItem, screen: Rect2) -> void:
	var roll := _roll() * screen.size.y
	var c := screen.get_center() + Vector2(0, -6 + roll)
	if roll > 0.0:
		# The picture wraps: draw it again one screen up so the slip is visible.
		_draw_skull_at(p, c - Vector2(0, screen.size.y), screen)
	_draw_skull_at(p, c, screen)


func _draw_skull_at(p: CanvasItem, c: Vector2, screen: Rect2) -> void:
	var ink := _ink()
	var lit := lerpf(0.35, 1.0, blood) * lerpf(0.55, 1.0, consciousness / 100.0)
	var hurt := pain / 100.0
	var throb := 0.6 + 0.4 * sin(elapsed * 9.0)
	var bone := ink * Color(1, 1, 1, 0.85 * lit)
	var faint := ink * Color(1, 1, 1, 0.22 * lit)
	# The vault, outer and inner table.
	var vault := _oval(c + Vector2(0, -9), Vector2(27, 26), 28, -PI * 0.98, PI * 0.02)
	var cranium := _oval(c + Vector2(0, -6), Vector2(27, 29), 32, 0.0, TAU)
	p.draw_colored_polygon(cranium, ink * Color(1, 1, 1, 0.10 * lit))
	# Pain is heat in the bone: a red flush that throbs.
	if hurt > 0.05:
		p.draw_colored_polygon(cranium, ALARM * Color(1, 1, 1, hurt * 0.38 * throb))
	p.draw_polyline(vault, bone, 1.6)
	p.draw_polyline(_oval(c + Vector2(0, -9), Vector2(23, 22), 24, -PI * 0.96, -PI * 0.04), faint, 1.0)
	# Temples down to the cheekbones.
	for side in [-1.0, 1.0]:
		p.draw_polyline(PackedVector2Array([c + Vector2(side * 27, -8), c + Vector2(side * 26, 4), c + Vector2(side * 21, 12), c + Vector2(side * 16, 17)]), bone, 1.4)
		p.draw_line(c + Vector2(side * 24, 8), c + Vector2(side * 13, 9), faint, 1.0)
	# The orbits, and in each a point of light: the eyes.
	var eye_h := lerpf(2.6, 0.5, clampf(hurt * 1.15, 0.0, 1.0))
	var drift := 0.0
	if consciousness < 40.0:
		drift = (1.0 - consciousness / 40.0) * 2.5
		eye_h *= 0.5 + 0.5 * absf(sin(elapsed * 2.3))
	for side in [-1.0, 1.0]:
		var orbit := c + Vector2(side * 10.5, 1.0)
		var socket := _oval(orbit, Vector2(7.5, 6.5), 14, 0.0, TAU)
		p.draw_colored_polygon(socket, Color(0.005, 0.02, 0.018))
		p.draw_polyline(socket, bone, 1.2)
		var eye_at := orbit + Vector2(side * drift * 0.6, drift)
		var eye_ink := (ALARM if hurt > 0.6 else ink.lightened(0.35)) * Color(1, 1, 1, lit)
		p.draw_rect(Rect2(eye_at - Vector2(2.6, eye_h * 0.5), Vector2(5.2, eye_h)), eye_ink)
		p.draw_circle(eye_at, 3.6, eye_ink * Color(1, 1, 1, 0.18))
	# Nasal aperture.
	var nose := PackedVector2Array([c + Vector2(0, 7), c + Vector2(4, 15), c + Vector2(2, 17), c + Vector2(0, 16), c + Vector2(-2, 17), c + Vector2(-4, 15)])
	p.draw_colored_polygon(nose, Color(0.005, 0.02, 0.018))
	p.draw_polyline(nose + PackedVector2Array([nose[0]]), bone, 1.0)
	# Upper teeth, fixed in the skull.
	var upper_y := c.y + 20.0
	p.draw_line(Vector2(c.x - 14, upper_y - 1), Vector2(c.x + 14, upper_y - 1), bone, 1.2)
	for tooth in 8:
		var x := c.x - 12.25 + float(tooth) * 3.5
		p.draw_rect(Rect2(x - 1.3, upper_y, 2.6, 3.4), bone)
	# The jaw: hangs and gasps as the body empties, locks in agony.
	var spent := 1.0 - stamina / 100.0
	var gasp := 0.0
	if spent > 0.2:
		var rate := lerpf(1.1, 4.4, spent)
		gasp = spent * (0.45 + 0.55 * (0.5 + 0.5 * sin(elapsed * rate))) * 7.0
	if hurt > 0.6:
		gasp = maxf(0.0, gasp * (1.0 - (hurt - 0.6) * 2.5)) + sin(elapsed * 47.0) * 0.5
	if consciousness < 30.0:
		gasp = maxf(gasp, 5.0)
	var jaw := c + Vector2(0, 24.0 + gasp)
	for tooth in 8:
		var x := c.x - 12.25 + float(tooth) * 3.5
		p.draw_rect(Rect2(Vector2(x - 1.3, jaw.y), Vector2(2.6, 3.0)), bone)
	var mandible := PackedVector2Array([
		Vector2(c.x - 19, c.y + 12), Vector2(c.x - 18, jaw.y + 6), Vector2(c.x - 10, jaw.y + 12),
		Vector2(c.x, jaw.y + 14), Vector2(c.x + 10, jaw.y + 12), Vector2(c.x + 18, jaw.y + 6), Vector2(c.x + 19, c.y + 12),
	])
	p.draw_polyline(mandible, bone, 1.5)
	p.draw_line(Vector2(c.x - 14, jaw.y + 4), Vector2(c.x + 14, jaw.y + 4), faint, 1.0)
	# The top of the column leaves the plate and carries on into the rig.
	p.draw_line(Vector2(c.x + 3, jaw.y + 15), Vector2(c.x + 3, screen.end.y), faint, 3.0)
	if head_damage > 0.05:
		_draw_fracture(p, c, head_damage, lit)


## A fixed fracture pattern across the vault, longer the worse the head is.
func _draw_fracture(p: CanvasItem, c: Vector2, amount: float, lit: float) -> void:
	var dark := Color(0.0, 0.0, 0.0, 0.85)
	var line := ALARM * Color(1, 1, 1, (0.5 + amount * 0.5) * lit)
	var start := c + Vector2(17, -29)
	var path := PackedVector2Array([start, start + Vector2(-6, 7), start + Vector2(-9, 15), start + Vector2(-17, 19), start + Vector2(-20, 27)])
	var reach := clampi(int(ceil(amount * float(path.size() - 1))) + 1, 2, path.size())
	var cut := path.slice(0, reach)
	p.draw_polyline(cut, dark, 2.6)
	p.draw_polyline(cut, line, 1.0)
	if amount > 0.45:
		p.draw_polyline(PackedVector2Array([path[1], path[1] + Vector2(6, 4), path[1] + Vector2(8, 10)]), line, 1.0)
	if amount > 0.7:
		p.draw_polyline(PackedVector2Array([path[2], path[2] + Vector2(-9, -3), path[2] + Vector2(-15, -2)]), line, 1.0)


static func _oval(centre: Vector2, radius: Vector2, steps: int, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / float(steps))
		points.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points
