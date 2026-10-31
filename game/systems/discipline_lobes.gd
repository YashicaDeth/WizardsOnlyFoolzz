class_name DisciplineLobes
extends RefCounted

## imp-66. What the pair you slot on the brain screen does, now (Greg, 5 Oct
## ~19:00: "the discipline pair has no effect"). Each discipline runs in one
## lobe of the chip's brain, and that lobe glows on every brain the HUD draws:
## the brain screen itself, the body-cam vitals on the facility route and the
## nerve rig in the Hunt. The first slot is the one in your hand: it decides
## the weapon you start the Hunt holding, and so the stance you stand in
## (blade guard or pistol stance); the second slot's weapon is carried too.
##
## DIALS (defaults mine, DESIGN/REMASTER_LOG.md; Greg has not set these):
## `PAIR_EFFECT` false = the pair is recorded and nothing changes, as before.
## `LOBES` picks each discipline's lobe, colour and weapon. Whether a
## mismatched pair should mean more stays Greg's (waking-vat-01).

const PAIR_EFFECT := true
const LOBES := {
	# Motor cortex: heavy directional swings.
	"brawler": {"lobe": "frontal", "colour": Color("dc5827"), "weapon": "cleaver"},
	# Visual cortex: aim down sights, slow time.
	"marksman": {"lobe": "occipital", "colour": Color("e6d4ac"), "weapon": "sidearm"},
	# The lab's two (lab-52), for when Greg puts them on the chip.
	"duelist": {"lobe": "parietal", "colour": Color("4f9c93"), "weapon": "cleaver"},
	"shade": {"lobe": "temporal", "colour": Color("8a9a74"), "weapon": "shiv"},
}
## Where each lobe sits on a side-view brain facing left (front = -x), in
## units of the brain's half-height, and its half-size.
const PLACES := {
	"frontal": {"at": Vector2(-0.62, -0.18), "size": Vector2(0.62, 0.62)},
	"parietal": {"at": Vector2(0.30, -0.48), "size": Vector2(0.58, 0.44)},
	"occipital": {"at": Vector2(0.92, 0.06), "size": Vector2(0.40, 0.52)},
	"temporal": {"at": Vector2(-0.10, 0.46), "size": Vector2(0.66, 0.34)},
}
const BONE := Color("e6d4ac")
const FLESH := Color("b98287")


## The pair the record holds, slot order kept; empty with the dial off.
static func slotted() -> Array:
	if not PAIR_EFFECT:
		return []
	var stored: Array = WorldHistory.subject("player").get("disciplines", [])
	return stored.filter(func(id) -> bool: return LOBES.has(str(id)))


static func lobe(id: String) -> String:
	return str((LOBES.get(id, {}) as Dictionary).get("lobe", ""))


static func colour(id: String) -> Color:
	return (LOBES.get(id, {}) as Dictionary).get("colour", BONE)


## The weapon in hand at the start: the first slot's, or `fallback` (the
## intake's fighting style) when nothing is slotted or the dial is off.
static func starting_weapon(fallback: String, pair: Array = []) -> String:
	if pair.is_empty():
		pair = slotted()
	if pair.is_empty():
		return fallback
	return str((LOBES[str(pair[0])] as Dictionary).weapon)


## Arms the Hunt: every slotted discipline's weapon carried, the first in hand.
static func arm(arsenal: HunterArsenal, fallback: String) -> String:
	var pair := slotted()
	for id in pair:
		var weapon := str((LOBES[str(id)] as Dictionary).weapon)
		if not arsenal.carried().has(weapon):
			arsenal.acquire_melee(weapon)
	var held := starting_weapon(fallback, pair)
	if not arsenal.select_weapon(held):
		arsenal.select_weapon(fallback)
	return str(arsenal.current_id)


## The slotted lobes, glowing, over a brain already drawn at `centre` whose
## half-height is `half` px. `faint` is a lobe shown as a preview (the card in
## focus on the brain screen).
static func draw_lobes(canvas: CanvasItem, centre: Vector2, half: float, ids: Array, clock: float, faint := "", alpha := 1.0) -> void:
	var lit := ids.duplicate()
	if faint != "" and not lit.has(faint):
		lit.append(faint)
	for index in lit.size():
		var id := str(lit[index])
		var place: Dictionary = PLACES.get(lobe(id), {})
		if place.is_empty():
			continue
		var preview := not ids.has(id)
		var pulse := 0.75 + 0.25 * sin(clock * (3.2 if index == 0 else 2.4) + float(index) * 1.7)
		var strength := alpha * (0.28 if preview else pulse)
		var at: Vector2 = centre + (place.at as Vector2) * half
		var size: Vector2 = (place.size as Vector2) * half
		var tone := colour(id)
		# A soft bloom, then the lobe itself, then its rim.
		for ring in 3:
			var grow := 1.0 + float(2 - ring) * 0.16
			canvas.draw_colored_polygon(_ellipse(at, size * grow, 24), Color(tone, strength * (0.12 + 0.16 * ring)))
		canvas.draw_polyline(_ellipse(at, size, 24, true), Color(tone.lightened(0.25), strength * 0.9), maxf(1.0, half * 0.05))
		# The first slot is the one in your hand: a bright core.
		if index == 0 and not preview:
			canvas.draw_circle(at, half * 0.11, Color(tone.lightened(0.45), strength))


## A whole small brain for screens that have none of their own (brain screen,
## body-cam vitals): cortex, cerebellum, stem, fissure, then the lobes.
static func draw_brain(canvas: CanvasItem, centre: Vector2, half: float, ids: Array, clock: float, faint := "", alpha := 1.0) -> void:
	var tint := Color(FLESH.darkened(0.35), alpha * 0.9)
	canvas.draw_circle(centre + Vector2(0.52, 0.80) * half, half * 0.40, tint.darkened(0.25))
	canvas.draw_line(centre + Vector2(0.20, 0.80) * half, centre + Vector2(0.24, 1.30) * half, tint.darkened(0.3), half * 0.2)
	var outline := PackedVector2Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		var r := 1.0 + 0.05 * sin(a * 5.0) + 0.035 * sin(a * 9.0 + 1.0)
		outline.append(centre + Vector2(cos(a) * r * 1.37, sin(a) * r) * half)
	canvas.draw_colored_polygon(outline, tint)
	draw_lobes(canvas, centre, half, ids, clock, faint, alpha)
	for fold in 9:
		var seed_a := float(fold) * 2.39996
		var at := centre + Vector2(cos(seed_a) * 0.9 * fmod(float(fold) * 0.37, 1.0) * 1.3, sin(seed_a) * 0.62 * fmod(float(fold) * 0.61, 1.0)) * half
		canvas.draw_arc(at, half * (0.2 + fold % 3 * 0.06), seed_a, seed_a + PI * 1.2, 8, Color(0.08, 0.02, 0.02, alpha * 0.5), maxf(1.0, half * 0.04))
	canvas.draw_polyline(outline, Color(BONE, alpha * 0.6), maxf(1.0, half * 0.04))


static func _ellipse(at: Vector2, size: Vector2, steps: int, closed := false) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + (1 if closed else 0):
		var a := TAU * float(i) / float(steps)
		points.append(at + Vector2(cos(a) * size.x, sin(a) * size.y))
	return points
