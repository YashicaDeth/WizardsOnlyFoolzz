class_name VitalitySignal
extends RefCounted

## I4. How badly the interface is doing, derived entirely from how badly the
## player is doing.
##
## The panels in this game are diegetic objects — a CellOutz handheld, a
## salvaged registry terminal — held by a person who may be bleeding. I4.3 says
## the degradation must be *of the panel*, never a post-process filter over the
## whole frame, because a filter is the game telling you that you are hurt and a
## failing screen is you noticing.
##
## Nothing new is stored. `anatomy_component.gd` has tracked blood, pain and
## consciousness since it was written, and `signal_field.gd` already decides
## Wire grade from where you stand. This reads those and returns one number.

## Below this the interface is clean. A player at a scratch should not be
## reading a broken screen.
const FLOOR := 0.12


## 0.0 when the reader is fine, 1.0 when they can barely hold the thing.
## `strain` is the Wire's own contribution — a weak signal degrades the panel
## even for a healthy player, which is why it is a separate argument rather
## than folded into the body.
static func severity(strain := 0.0) -> float:
	var player: Dictionary = WorldHistory.subject("player")
	var anatomy: Dictionary = player.get("anatomy_state", {})
	if anatomy.is_empty():
		return clampf(strain, 0.0, 1.0)

	var capacity := maxf(1.0, float(anatomy.get("blood_capacity", 5000.0)))
	var bled := 1.0 - clampf(float(anatomy.get("blood", capacity)) / capacity, 0.0, 1.0)
	var pain := clampf(float(anatomy.get("pain", 0.0)) / 100.0, 0.0, 1.0)
	var dimming := 1.0 - clampf(float(anatomy.get("consciousness", 100.0)) / 100.0, 0.0, 1.0)

	# Consciousness dominates: a clear-headed player who has lost blood can
	# still read, and someone about to go under cannot, whatever their chart
	# says. Pain is the twitch; blood is the slow fade.
	var body := clampf(dimming * 0.55 + bled * 0.3 + pain * 0.25, 0.0, 1.0)
	var total := clampf(maxf(body, strain * 0.8), 0.0, 1.0)
	return 0.0 if total < FLOOR else clampf((total - FLOOR) / (1.0 - FLOOR), 0.0, 1.0)


## How far a glyph should wander at this severity. Small: type that swims is
## unreadable, and unreadable is a different feeling from failing.
static func jitter(level: float, seed_value: int, clock: float) -> Vector2:
	if level <= 0.0:
		return Vector2.ZERO
	var phase := clock * (2.4 + level * 5.0) + float(seed_value) * 0.7
	return Vector2(sin(phase) * level * 1.6, cos(phase * 1.37) * level * 1.1)


## The ink fades before the panel breaks up, which is the order a failing
## display actually goes in.
static func ink(level: float) -> float:
	return clampf(1.0 - level * 0.45, 0.35, 1.0)
