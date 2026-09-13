class_name CabReticle
extends Control

## Greg: *"you still cant shoot"*.
##
## You can. `_fire_from_cab()` has always fired a real round along the camera's
## own forward, and `_update_cab_camera()` turns the camera by `aim_yaw` and
## `aim_pitch`, so the shot goes exactly where the middle of the screen is
## pointing. Nothing has ever said so. With no mark on the glass and no
## acknowledgement when the trigger goes down, firing reads as a key that does
## nothing.
##
## Deliberately not a crosshair with a dot in the middle: I0 says a readout
## should be an object rather than an overlay, and the closest honest thing to
## an object here is a gunsight — four ticks standing off an empty centre, so it
## frames what you are pointing at instead of covering it.
##
## It also carries the two things the cluster cannot say fast enough to matter
## in a fight: the sight kicks open when the gun goes off, and it goes hollow
## and red when the gun is empty.

const LIVE := Color("c9d6a8")
const SPENT := Color("b8402f")

## How far the four ticks stand off the centre at rest, and how far the kick
## pushes them out on top of that.
const REST_GAP := 9.0
const KICK_GAP := 7.0
const TICK := 7.0

var active := false
var empty := false
## 0 at rest, 1 the instant the gun goes off. The owner hands this over rather
## than the reticle timing its own recoil, because the cooldown that decides it
## already lives on the derby.
var kick := 0.0
var _shown_kick := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Told, not polled: the derby owns the gun and already knows all three of these.
func report(is_active: bool, is_empty: bool, recoil: float) -> void:
	active = is_active
	empty = is_empty
	kick = clampf(recoil, 0.0, 1.0)


func _process(delta: float) -> void:
	# Smoothed so the sight settles back rather than snapping, which is most of
	# what makes a shot feel like it had weight.
	_shown_kick = move_toward(_shown_kick, kick, delta * (9.0 if kick > _shown_kick else 3.4))
	visible = active
	if active:
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var centre := size * 0.5
	var tone := SPENT if empty else LIVE
	var gap := REST_GAP + KICK_GAP * _shown_kick
	var weight := 1.6
	# Four ticks: up, down, left, right. The centre stays empty on purpose — the
	# thing you are shooting at is more useful to see than the mark saying so.
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(
			centre + direction * gap,
			centre + direction * (gap + TICK),
			tone * Color(1, 1, 1, 0.85), weight
		)
	# A single pip below the sight when the gun is empty, because "nothing
	# happened" and "no rounds left" are otherwise the same experience.
	if empty:
		draw_circle(centre + Vector2(0, gap + TICK + 6.0), 1.8, SPENT * Color(1, 1, 1, 0.9))
