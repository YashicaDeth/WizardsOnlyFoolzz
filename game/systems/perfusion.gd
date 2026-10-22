class_name Perfusion
extends RefCounted

## The body's circulation and the oxygen in it: one small model, owned by
## `AnatomyComponent` and read by anything that has to say how alive a body is.
##
## Two numbers, deliberately not one:
##
## - **Perfusion** is flow — how much blood is reaching tissue right now. It is
##   computed from state the anatomy already keeps (blood volume, the open
##   vessels in `BaselineHuman.severed`, the spine organ, the heart) and never
##   stored, so it cannot drift from the body it describes.
## - **Oxygen** is the reserve that flow keeps topped up. It is the one thing
##   this model remembers, because oxygen is a quantity with a history: a body
##   whose heart stops does not lose its oxygen in a frame, it spends what is
##   left in the blood, and a body whose bleeding is stopped repays that debt
##   over seconds rather than instantly.
##
## The lungs are what keeps oxygen from being a second copy of perfusion with a
## different name: ruined lungs leave a body moving its blood normally with the
## reserve falling anyway. Neither number is a new death rule. Perfusion and
## oxygen feed the consciousness the anatomy already computes, so a body that
## runs out of either goes down through `go_down()` — the same door blood loss
## and a stopped heart already use — and nothing here decides that anyone dies.

## Above this fraction of its own blood, volume costs a body almost no flow:
## the baroreflex holds pressure while it still can.
const FULL_VOLUME := 0.72
## Below this there is nothing left to pump.
const ARREST_VOLUME := 0.20
## Flow at the volume where compensation runs out, before the fall.
const COMPENSATED_FLOW := 0.86
## A ruptured heart is not zero — it is a twitch, and the reserve drains from it.
const HEART_STOPPED := 0.06
## No vasomotor tone: pressure falls even with blood still in the body.
const SPINE_RUPTURED := 0.55
## How much of the flow the spinal column is still regulating.
const VERTEBRA_COST := 0.30
## Each open stump shunts blood away from everything still attached.
const OPEN_VESSEL := 0.12
const MAX_OPEN_VESSELS := 3
## Even ruined lungs exchange something. Without this, "no lungs" would read as
## a dead body, and a body can lose both lungs and still be in the room.
const LUNG_FLOOR := 0.25
## A resting body moves about five litres a minute; the current loss is read
## against that, because blood running onto the floor is blood not reaching
## tissue — and closing the wound is why flow comes back the moment it stops.
const CARDIAC_OUTPUT := 90.0
## Nobody stands while shunting more than this share of their output out of a
## hole; past it the volume term is already doing the work.
const MAX_LOSS_SHARE := 0.45
## How much of its oxygen-carrying capacity blood still has at a given volume.
## Delivery is flow times carriers, so it falls before flow does.
const CARRIED_FLOOR := 0.45

## Percent per second the reserve falls while delivery is short of the demand,
## and the slower rate it comes back at. Asymmetric on purpose: going without
## oxygen is quick and getting it back is a recovery.
const OXYGEN_SPEND := 5.5
const OXYGEN_REPLENISH := 7.0

## How much oxygen is left, 0 to 100. The only value this model stores.
var oxygen := 100.0


## Flow reaching tissue, 0 to 1, from the body's own fields. `open_vessels` is
## `BaselineHuman.severed.size()`, passed in rather than counted a second time.
static func flow(anatomy: Object, open_vessels := 0) -> float:
	if anatomy == null:
		return 0.0
	var capacity := maxf(1.0, float(anatomy.blood_capacity))
	var volume := clampf(float(anatomy.blood_remaining) / capacity, 0.0, 1.0)
	var pumped := 1.0
	if volume < FULL_VOLUME:
		pumped = COMPENSATED_FLOW * clampf((volume - ARREST_VOLUME) / (FULL_VOLUME - ARREST_VOLUME), 0.0, 1.0)
	var organs: Dictionary = anatomy.organs
	var heart: Dictionary = organs.get("heart", {})
	if bool(heart.get("ruptured", false)):
		pumped *= HEART_STOPPED
	var spine: Dictionary = organs.get("spine", {})
	if bool(spine.get("ruptured", false)):
		pumped *= SPINE_RUPTURED
	else:
		var damaged := (spine.get("vertebrae_damaged", []) as Array).size()
		pumped *= 1.0 - VERTEBRA_COST * clampf(float(damaged) / maxf(1.0, float(anatomy.SPINE_VERTEBRAE)), 0.0, 1.0)
	pumped *= 1.0 - OPEN_VESSEL * float(mini(maxi(open_vessels, 0), MAX_OPEN_VESSELS))
	var bleeding := maxf(0.0, float(anatomy.bleed_rate) + float(anatomy.internal_bleed_rate))
	pumped *= 1.0 - clampf(bleeding / CARDIAC_OUTPUT, 0.0, MAX_LOSS_SHARE)
	return clampf(pumped, 0.0, 1.0)


## Where the reserve is headed for this body right now: delivery is flow times
## what the lungs can put into it. The reserve chases this, it does not equal it.
static func oxygen_target(anatomy: Object, open_vessels := 0) -> float:
	if anatomy == null:
		return 0.0
	var capacity := maxf(1.0, float(anatomy.blood_capacity))
	var volume := clampf(float(anatomy.blood_remaining) / capacity, 0.0, 1.0)
	var carried: float = lerpf(CARRIED_FLOOR, 1.0, volume)
	var lungs: float = clampf(LUNG_FLOOR + (1.0 - LUNG_FLOOR) * float((anatomy.lung_state() as Dictionary).get("health", 1.0)), 0.0, 1.0)
	return clampf(100.0 * flow(anatomy, open_vessels) * carried * lungs, 0.0, 100.0)


## One tick of the reserve. Returns false when the reserve is full and delivery
## is too, which is the whole of a healthy body's answer. The per-frame gate
## that makes an untouched bystander free lives one level up, in
## `AnatomyComponent._process`: nothing here is called at all for a body with no
## wound and a full reserve.
func advance(anatomy: Object, open_vessels: int, delta: float) -> bool:
	if anatomy == null or delta <= 0.0:
		return false
	var target := oxygen_target(anatomy, open_vessels)
	# A whole body with a whole reserve has nowhere to go. Checked against the
	# delivery rather than only the organs, because a body with every organ
	# intact can still be short of oxygen while it runs out of blood.
	if oxygen >= 100.0 and target >= 100.0:
		return false
	oxygen = clampf(move_toward(oxygen, target, (OXYGEN_REPLENISH if target >= oxygen else OXYGEN_SPEND) * delta), 0.0, 100.0)
	return true


## Fresh blood carries a full reserve; this is called when a body is configured.
func reset() -> void:
	oxygen = 100.0


func percent() -> int:
	return roundi(clampf(oxygen, 0.0, 100.0))
