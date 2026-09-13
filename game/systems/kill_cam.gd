class_name KillCam
extends Control

const CellOutzType := preload("res://systems/celloutz_type.gd")

## Slow-motion anatomical kill camera. On a lethal impact the world drops into
## slow motion and the victim's body is drawn as an X-ray plate with the damage
## propagating through it: the shockwave crosses the ribs, bones fracture along
## real lines, organs rupture in sequence.
##
## The X-ray killcam is a genre convention rather than anyone's property, but
## the implementation, anatomy, palette and presentation here are original and
## driven by this project's own AnatomyComponent zones.

signal finished()

const DURATION := 2.6
const SLOW_SCALE := 0.16

const PLATE_BG := Color("050c0e")
const BONE := Color("dbe7cd")
const BONE_BREAK := Color("fff4d2")
const ARTERIAL := Color("c81f16")
const BRUISE := Color("6a2d6e")
const BILE := Color("b8a12a")
const ACID := Color("9bf01a")

var active := false
var clock := 0.0
var impact_zone := "torso"
var subject_name := "UNKNOWN"
var impact_from := Vector2.LEFT
var fragments: Array[Dictionary] = []
var ruptures: Array[Dictionary] = []
var caption := ""
var anatomy_state: Dictionary = {}
const ORGAN_POINTS := {"brain": Vector2(0, -86), "heart": Vector2(-5, -25), "left_lung": Vector2(-18, -35), "right_lung": Vector2(18, -35), "liver": Vector2(13, 5), "gut": Vector2(0, 27), "spine": Vector2(0, -5)}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchors alone leave the rect at zero size until a layout pass; offsets make
	# it fill immediately, which matters because this draws from its own size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(true)


## `direction` is the impact heading in world space; only its horizontal sign is
## used, so the plate reads as struck from the side the player actually hit.
func trigger(display_name: String, zone: String, direction: Vector3, label: String = "", snapshot: Dictionary = {}) -> void:
	if active:
		return
	active = true
	visible = true
	clock = 0.0
	subject_name = display_name.to_upper()
	impact_zone = zone
	caption = label
	anatomy_state = snapshot.duplicate(true)
	impact_from = Vector2(signf(direction.x) if absf(direction.x) > 0.01 else -1.0, 0.0)
	_seed_damage()
	if not anatomy_state.is_empty():
		_seed_anatomy()
	Engine.time_scale = SLOW_SCALE

func _seed_anatomy() -> void:
	ruptures.clear()
	if impact_zone != "torso":
		fragments.clear()
	for organ_id in ORGAN_POINTS:
		var organ: Dictionary = anatomy_state.get("organs", {}).get(organ_id, {})
		if organ.is_empty():
			continue
		ruptures.append({"id": organ_id, "at": ORGAN_POINTS[organ_id], "radius": 5.0 if organ_id == "spine" else 11.0, "color": BONE if organ_id == "spine" else BRUISE if "lung" in organ_id else BILE if organ_id in ["gut", "liver"] else ARTERIAL, "delay": 0.35 + ruptures.size() * 0.07, "ruptured": bool(organ.get("ruptured", false))})

func cancel() -> void:
	if not active:
		return
	active = false
	visible = false
	Engine.time_scale = 1.0
	finished.emit()

func _exit_tree() -> void:
	cancel()


func _seed_damage() -> void:
	fragments.clear()
	ruptures.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Ribs fracture in order away from the impact side, so the break reads as a
	# wave crossing the body rather than everything failing at once.
	for rib in 6:
		var side := -1.0 if rib % 2 == 0 else 1.0
		@warning_ignore("integer_division")
		var height := -46.0 + float(rib / 2) * 17.0
		fragments.append({
			"origin": Vector2(side * 17.0, height),
			"drift": Vector2(side * rng.randf_range(6.0, 17.0), rng.randf_range(-7.0, 7.0)),
			"spin": rng.randf_range(-2.4, 2.4),
			"delay": 0.12 + float(rib) * 0.055 + (0.0 if side == impact_from.x else 0.12),
			"length": rng.randf_range(13.0, 22.0),
		})
	for shard in 5:
		fragments.append({
			"origin": Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-58.0, -34.0)),
			"drift": Vector2(rng.randf_range(-13.0, 13.0), rng.randf_range(-12.0, 4.0)),
			"spin": rng.randf_range(-3.4, 3.4),
			"delay": 0.3 + rng.randf() * 0.3,
			"length": rng.randf_range(6.0, 12.0),
		})
	ruptures = [
		{"at": Vector2(-3, -26), "radius": 13.0, "color": ARTERIAL, "delay": 0.34},
		{"at": Vector2(-15, -30), "radius": 11.0, "color": BRUISE, "delay": 0.48},
		{"at": Vector2(14, -28), "radius": 11.0, "color": BRUISE, "delay": 0.54},
		{"at": Vector2(2, 12), "radius": 14.0, "color": BILE, "delay": 0.66},
	]


func _process(delta: float) -> void:
	if not active:
		return
	# Unscaled time, or the sequence would also be slowed by its own effect.
	clock += delta / maxf(Engine.time_scale, 0.001)
	if clock >= DURATION:
		cancel()
		return
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var t := clampf(clock / DURATION, 0.0, 1.0)
	# Hold, then wipe away.
	var fade := clampf(t / 0.12, 0.0, 1.0) * clampf((1.0 - t) / 0.18, 0.0, 1.0)
	if fade <= 0.01:
		return

	var plate := Rect2(size * Vector2(0.5, 0.5) - Vector2(210, 250), Vector2(420, 500))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72 * fade))
	draw_rect(plate, PLATE_BG * Color(1, 1, 1, 0.96 * fade))
	draw_rect(plate, ACID * Color(1, 1, 1, 0.35 * fade), false, 2)

	var center := plate.get_center() + Vector2(0, 10)
	draw_set_transform(center, 0.0, Vector2(1.7, 1.7))
	_draw_plate_body(fade)
	_draw_fractures(fade)
	_draw_ruptures(fade)
	_draw_shockwave(fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# A1.3. Headers and the stamp in the display face; the caption stays in a
	# real font because a stencil alphabet is for stamps, not sentences.
	CellOutzType.draw_stamped(self, plate.position + Vector2(18, 16), subject_name.to_upper(), 19.0, BONE * Color(1, 1, 1, fade), ARTERIAL * Color(1, 1, 1, 0.3 * fade), 1.4)
	CellOutzType.draw_text(self, plate.position + Vector2(18, 44), "LETHAL // %s" % impact_zone.to_upper().replace("_", " "), 10.0, ARTERIAL * Color(1, 1, 1, fade), 1.0)
	if not caption.is_empty():
		# The name above this is stamped in CellOutzType and the zone under it is
		# set in it; the caption between them was the one line on the plate still
		# in the engine's fallback face.
		CellOutzType.draw_condensed(self, Vector2(plate.position.x + 18, plate.end.y - 30), caption,
			9.0, ACID * Color(1, 1, 1, 0.85 * fade), 1.0)
	for scan in range(0, int(plate.size.y), 3):
		draw_line(Vector2(plate.position.x, plate.position.y + scan), Vector2(plate.end.x, plate.position.y + scan), Color(0, 0, 0, 0.14 * fade), 1)


func _draw_plate_body(fade: float) -> void:
	var ghost := ACID * Color(1, 1, 1, 0.1 * fade)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -62), Vector2(20, -62), Vector2(30, -48), Vector2(27, 2),
		Vector2(20, 44), Vector2(-20, 44), Vector2(-27, 2), Vector2(-30, -48),
	]), ghost)
	for offset in [-1.0, 1.0]:
		draw_line(Vector2(offset * 25, -48), Vector2(offset * 47, 36), ghost, 13)
		draw_line(Vector2(offset * 13, 42), Vector2(offset * 20, 104), ghost, 16)
	draw_circle(Vector2(0, -86), 23, ghost)
	# Spine and pelvis stay intact so the fractures have something to read against.
	draw_line(Vector2(0, -58), Vector2(0, 46), BONE * Color(1, 1, 1, 0.85 * fade), 4)
	draw_arc(Vector2(0, -86), 22, PI, TAU, 22, BONE * Color(1, 1, 1, 0.7 * fade), 2)
	draw_line(Vector2(-16, 44), Vector2(16, 44), BONE * Color(1, 1, 1, 0.6 * fade), 5)


func _draw_fractures(fade: float) -> void:
	for fragment in fragments:
		var delay := float(fragment.delay)
		var progress := clampf((clock - delay) / 0.85, 0.0, 1.0)
		var origin: Vector2 = fragment.origin
		var length := float(fragment.length)
		if progress <= 0.0:
			# Intact: draw the bone where it still belongs.
			draw_line(origin - Vector2(length * 0.5, 0), origin + Vector2(length * 0.5, 0), BONE * Color(1, 1, 1, 0.8 * fade), 2)
			continue
		var eased := ease(progress, 0.4)
		var displaced: Vector2 = origin + (fragment.drift as Vector2) * eased
		var angle := float(fragment.spin) * eased
		var flash := clampf(1.0 - progress * 2.6, 0.0, 1.0)
		var tint := BONE.lerp(BONE_BREAK, flash) * Color(1, 1, 1, (0.85 - progress * 0.25) * fade)
		var arm := Vector2.from_angle(angle) * length * 0.5
		draw_line(displaced - arm, displaced + arm, tint, 2)
		if flash > 0.05:
			draw_circle(displaced, 3.0 + flash * 5.0, BONE_BREAK * Color(1, 1, 1, flash * 0.5 * fade))


func _draw_ruptures(fade: float) -> void:
	for rupture in ruptures:
		var progress := clampf((clock - float(rupture.delay)) / 0.9, 0.0, 1.0)
		if not bool(rupture.get("ruptured", true)):
			progress = 0.0
		var at: Vector2 = rupture.at
		var base := float(rupture.radius)
		var tint: Color = rupture.color
		if rupture.has("id"):
			var label_at := Vector2(53, -100 + ORGAN_POINTS.keys().find(rupture.id) * 24)
			draw_line(at, label_at - Vector2(3, 4), tint * Color(1, 1, 1, 0.4 * fade), 0.5)
			CellOutzType.draw_text(self, label_at - Vector2(0, 6), str(rupture.id).replace("_", " ").to_upper(), 7.0, BONE * Color(1, 1, 1, fade), 0.6)
		if progress <= 0.0:
			draw_circle(at, base, tint * Color(1, 1, 1, 0.55 * fade))
			continue
		var swell := base * (1.0 + progress * 0.5)
		draw_circle(at, swell, tint * Color(1, 1, 1, (0.6 - progress * 0.25) * fade))
		# Spray out of the rupture, weighted along the impact heading.
		for spur in 7:
			var angle := TAU * spur / 7.0 + progress * 1.4
			var reach := swell + progress * (16.0 + spur * 3.0)
			var tip := at + Vector2.from_angle(angle) * reach + impact_from * progress * 9.0
			draw_line(at + Vector2.from_angle(angle) * swell, tip, ARTERIAL * Color(1, 1, 1, (0.5 - progress * 0.3) * fade), 2)


func _draw_shockwave(fade: float) -> void:
	var progress := clampf(clock / 0.55, 0.0, 1.0)
	if progress >= 1.0:
		return
	var front := -impact_from.x * (-60.0 + progress * 120.0)
	draw_line(Vector2(front, -110), Vector2(front, 110), ACID * Color(1, 1, 1, (1.0 - progress) * 0.55 * fade), 3)
	draw_line(Vector2(front - impact_from.x * 9.0, -110), Vector2(front - impact_from.x * 9.0, 110), BONE_BREAK * Color(1, 1, 1, (1.0 - progress) * 0.25 * fade), 1)
