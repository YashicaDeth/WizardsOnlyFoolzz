class_name Perception
extends RefCounted

## AE1.1. "Unseen is a real state with real inputs — light, noise, cover,
## distance." Two other checklist items were already blocked waiting on
## this before any code here existed: AS1.5 (the handheld's own light giving
## you away) and AU1.10/AE1.4 (the law reading what a lacing was witnessed
## by). Neither invents its own answer to "can something see me right now" —
## this is that answer, so the day either one wires to it, it is the same
## number a third caller would also read.
##
## A pure function of its four named inputs rather than a live query with a
## scene and a raycast baked into it, so the formula itself is fully testable
## without either. `bone_yard_hunt.gd`'s `_update_perception()` is what
## supplies real values for the four inputs from the actual world; this file
## never reaches into a scene tree to get its own answers.

## Below this, a target counts as genuinely unseen — the one number that
## turns a continuous exposure score into the boolean AE1.1 actually names.
const UNSEEN_THRESHOLD := 0.35
## A bright object is easier to notice than the body behind it. Keeping the
## threshold shared makes "I saw the light" and "I saw the holder" comparable
## without pretending they are the same sighting.
const EMITTED_LIGHT_THRESHOLD := 0.2


## 0 (unseen) to 1 (in plain sight).
##
## `light`/`noise` are 0..1 — how lit and how loud the subject is right now.
## `cover` is 0..1 — how blocked the sightline is. `distance`/`max_range` give
## the base falloff a plain "how far away" check would already produce.
##
## No single term is allowed to fully override another: full cover dims a
## lit, loud subject rather than erasing them outright, because a spotlit
## target standing in a doorway is not actually invisible, and standing
## motionless in the dark at melee range is still not unseen.
static func visibility(light: float, noise: float, cover: float, distance: float, max_range: float) -> float:
	if max_range <= 0.0:
		return 1.0
	var range_term := 1.0 - clampf(distance / max_range, 0.0, 1.0)
	var exposure := clampf(range_term * 0.55 + clampf(light, 0.0, 1.0) * 0.3 + clampf(noise, 0.0, 1.0) * 0.15, 0.0, 1.0)
	return clampf(exposure * (1.0 - clampf(cover, 0.0, 1.0) * 0.75), 0.0, 1.0)


static func is_unseen(light: float, noise: float, cover: float, distance: float, max_range: float) -> bool:
	return visibility(light, noise, cover, distance, max_range) < UNSEEN_THRESHOLD


## C7.1 / AS1.5. Visibility of the source itself, not the person carrying it.
## A source can be noticed out to twice its useful illumination radius: the
## beam has stopped lighting a surface well before its bright origin becomes
## impossible to pick out. Cover still matters, and an exhausted lamp has no
## signal at all.
static func emitted_light_signal(distance: float, light_radius: float, cover: float) -> float:
	if light_radius <= 0.0:
		return 0.0
	var range_term := 1.0 - clampf(distance / (light_radius * 2.0), 0.0, 1.0)
	return clampf(range_term * (1.0 - clampf(cover, 0.0, 1.0) * 0.75), 0.0, 1.0)


static func sees_emitted_light(distance: float, light_radius: float, cover: float) -> bool:
	return emitted_light_signal(distance, light_radius, cover) >= EMITTED_LIGHT_THRESHOLD
