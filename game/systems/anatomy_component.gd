class_name AnatomyComponent
extends Node

const ImplantCatalog := preload("res://systems/implant_catalog.gd")

signal wounded(result: Dictionary)
signal bleeding_changed(rate: float, blood_remaining: float)
signal critical_state_started()
signal organ_ruptured(organ_id: String, organ: Dictionary)
## Defeated but not dead. Every resolution the player can choose — execute,
## spare, recruit, mind-stamp — happens inside this window, so the window is the
## system. It is symmetric: the player goes down the same way anyone else does.
signal went_down()
signal died(cause: Dictionary)
## B8.2. The body ran out and the spirit did not go with it. Distinct from
## `died` on purpose: anything listening for a death — the witness ledger, the
## resolution window, the crowd — must not treat this as one, because nothing
## about the world changes except that this body has stopped working.
signal body_failed(report: Dictionary)
## The way back up. Emitted by `rise()`, so the flame and the HUD can react to
## the cost rather than being told to play an animation.
signal spirit_rose(report: Dictionary)

## Organs sit inside zones. A zone tracks whether a limb still works; an organ
## decides how you die. The distinction matters because two torso hits of equal
## damage should not be interchangeable — one through the gut leaves someone
## bleeding for a minute, one through the heart does not leave them anything.
const ORGANS := {
	"brain": {"zone": "head", "health": 18.0, "bleed": 1.2, "fatal": true},
	"heart": {"zone": "torso", "health": 26.0, "bleed": 3.4, "fatal": false},
	"left_lung": {"zone": "torso", "health": 34.0, "bleed": 1.2, "fatal": false},
	"right_lung": {"zone": "torso", "health": 34.0, "bleed": 1.2, "fatal": false},
	"liver": {"zone": "torso", "health": 40.0, "bleed": 1.8, "fatal": false},
	"gut": {"zone": "torso", "health": 52.0, "bleed": 0.9, "fatal": false},
	"spine": {"zone": "torso", "health": 30.0, "bleed": 0.4, "fatal": false},
}
const SPINE_VERTEBRAE := 33

## B3.1. Damage that melts rather than cuts. It is a family rather than a single
## type because the caustic pools in the Ashbloom do the same thing to a body
## that a hot zone does, over a different span.
const MELTING := ["radiation", "caustic"]
## B3.2. How much of a melting hit stays in the zone as dose, and how fast that
## dose spends itself. Slow on purpose: the injury this segment describes is one
## that is still happening after the fight it started in.
const DOSE_SHARE := 0.55
const DOSE_BURN_PER_SECOND := 0.9
const DOSE_DECAY_PER_SECOND := 0.035
## B7.1. How fast a storm doses an uncovered zone. Slow enough to be weather
## rather than an attack: a bad night out in it is survivable and costs you
## something, and staying out in it is not.
const EXPOSURE_DOSE_PER_SECOND := 0.42

const DEFAULT_ZONES := {
	"head": {"health": 45.0, "bleed": 0.75, "critical": true},
	"torso": {"health": 120.0, "bleed": 0.42, "critical": true},
	"left_arm": {"health": 65.0, "bleed": 0.55, "critical": false},
	"right_arm": {"health": 65.0, "bleed": 0.55, "critical": false},
	"left_leg": {"health": 75.0, "bleed": 0.62, "critical": false},
	"right_leg": {"health": 75.0, "bleed": 0.62, "critical": false},
}

## N5.1. A real slot per site rather than one slot per coarse damage zone.
## `installed_parts` used to be keyed by these same six zones directly, so a
## torso implant covered "torso" and nothing distinguished a spine cage from
## a chest plate from an organ-bay graft — Greg's own list ("spine, skull,
## chest, each arm, each leg, the organ bays") names four distinct sites
## where the zone model only ever had "head" and "torso". Each site still
## resolves to one of the six real damage zones below for armor/hit
## purposes — the wound model itself is not what this changes, and every
## existing caller that installs at a bare zone name ("head", "torso", a
## limb) keeps working exactly as before, since a zone is also a valid site
## of its own. What changes is that a caller can now also ask for "skull",
## "spine", "chest" or "organ_bays" specifically, and have it tracked,
## damaged and pulled as its own real slot rather than collapsing into
## whichever single implant happened to occupy "torso".
const INSTALL_SITES := {
	"head": "head", "skull": "head",
	"torso": "torso", "spine": "torso", "chest": "torso", "organ_bays": "torso",
	"left_arm": "left_arm", "right_arm": "right_arm",
	"left_leg": "left_leg", "right_leg": "right_leg",
}

## B7.1. What this body has on. Names from `Garments.CATALOGUE`; an empty list
## is somebody standing in the Ashbloom in their skin, which the weather and the
## radiation path both treat exactly as badly as that sounds.
var worn: Array = []
## B7.2. How much of each zone is behind something right now, 0 to 1, written by
## whatever knows about the world's geometry. Cover and armour resolve to one
## figure, so there is no armour stat for a wall to disagree with.
var cover: Dictionary = {}

## B3.1. What each zone is still carrying, in dose points. Not a status flag: it
## is spent down by `_process()` and it does damage the whole time it is there.
var dose: Dictionary = {}

var subject_id := ""
var blood_capacity := 5000.0
var blood_remaining := 5000.0
var bleed_rate := 0.0
## B6.8v2. This is deliberately separate from an open wound. The body loses
## blood either way, but only an X-ray/anatomy inspection may name this source.
var internal_bleed_rate := 0.0
var pain := 0.0
var consciousness := 100.0
var dead := false
var downed := false
## B8.1. The only thing that makes the player's body exceptional (B10.15).
##
## Not a second health pool, not a damage multiplier, not a separate player
## rig — this body takes every wound through exactly the same anatomy as the
## one lying in the road, and gets the same organs ruptured and the same limbs
## taken off. What is different is one thing: death does not take. AP2.1, "the
## spirit cannot be banished by violence."
var undying := false
## B8.2. What is left when a body fails but its spirit does not.
##
## `dead` is the end of a subject. `failed` is a body that has run out — every
## reason it should be `dead` has happened — attached to a spirit that will not
## go with it. Nothing recovers from this on its own; `rise()` is the only way
## out, and it costs.
var failed := false
## Every time this body has run out, and what did it. The record is the point:
## an undying body that forgets is a checkpoint, and one that remembers is a
## character (B10.2 — what carries over is scars, not statistics).
var failures: Array[Dictionary] = []
## B8.1's "visibly". How much of the body has been given up to keep standing,
## 0..1. Rises with every failure and never falls. Drives `UndyingFlame`, so
## surviving what would kill anybody else is legible as the spirit showing
## through more and the body mattering less — on the body, in the frame, rather
## than in a counter somewhere.
var spirit_burden := 0.0
## How much of the body each failure permanently gives up. Five failures reaches
## the floor, which is a run, not a fight — the cost has to be felt across an
## evening rather than inside one exchange.
const BURDEN_PER_FAILURE := 0.2
## Standing up returns blood only to the level it takes to be conscious. Not
## full, never full.
const RISE_BLOOD_FLOOR := 0.34
const RISE_CONSCIOUSNESS := 26.0
var critical := false
var zones: Dictionary = {}
var organs: Dictionary = {}
var installed_parts: Dictionary = {}
var wounds: Array[Dictionary] = []

## B2.7v2. Pain should announce itself through a guarded body before it turns
## into an invisible performance debuff. This is deliberately above routine
## combat pain: a person can be hurting, and visibly so, while still moving.
const FUNCTIONAL_PAIN := 55.0


func configure(id: String, capacity: float = 5000.0, cybernetics: Variant = {}) -> void:
	subject_id = id
	blood_capacity = maxf(100.0, capacity)
	blood_remaining = blood_capacity
	installed_parts = ImplantCatalog.by_zone(cybernetics)
	zones = DEFAULT_ZONES.duplicate(true)
	for zone_id in zones:
		zones[zone_id] = (zones[zone_id] as Dictionary).duplicate(true)
	organs = {}
	for organ_id in ORGANS:
		var organ: Dictionary = (ORGANS[organ_id] as Dictionary).duplicate(true)
		organ["ruptured"] = false
		if organ_id == "spine":
			organ["vertebrae_damaged"] = []
		organs[organ_id] = organ
	set_process(true)


func apply_hit(zone_id: String, damage: float, impulse: float, damage_type: String = "blunt", organ_id: String = "") -> Dictionary:
	if dead:
		return {"accepted": false, "reason": "dead"}
	var resolved_zone := zone_id if zones.has(zone_id) else "torso"
	var zone: Dictionary = zones[resolved_zone]
	# N5.1. A zone can now hold hardware at more than one site (a spine cage
	# and a chest plate both answer to "torso"), so a hit's armor is the sum
	# of every site installed there, each scaled by its own condition —
	# never a single implant standing in for the whole zone.
	var armor := 0.0
	for site_id in _sites_for_zone(resolved_zone):
		var part: Dictionary = installed_parts[site_id]
		armor += float(part.get("armor", 0.0)) * implant_condition(site_id)
	# B7.1 / B7.2. What is over this zone: what it is wearing, plus what it is
	# behind. Melting damage is stopped by shielding and ordinary damage by
	# plate, which is the difference between a lead wrap and a scrap plate and
	# the reason they are separate numbers on a garment rather than one
	# "protection" figure that would have to lie about one of them.
	var over := Garments.with_cover(
		Garments.shielding(worn, resolved_zone),
		float(cover.get(resolved_zone, 0.0)),
	)
	var melting_type := damage_type in MELTING
	var layered := float(over.shield) if melting_type else float(over.plate)
	var applied := maxf(1.0, damage * (1.0 - clampf(armor, 0.0, 0.85)) * (1.0 - layered))
	zone["health"] = maxf(0.0, float(zone.health) - applied)
	zones[resolved_zone] = zone
	var penetrating := damage_type in ["cut", "puncture", "ballistic", "shear"]
	# B3.2. A melting injury barely bleeds. It does not open a vessel, it ruins
	# one — which is most of why it is more dangerous than the wound it looks
	# like, and why a body can be lethally dosed with almost nothing running out
	# of it.
	var melting := damage_type in MELTING
	var bleed_share := 0.018
	if penetrating:
		bleed_share = 0.075
	elif melting:
		bleed_share = 0.005
	var wound_bleed := applied * float(zone.bleed) * bleed_share
	if float(zone.health) <= 0.0:
		wound_bleed *= 2.1
	bleed_rate += wound_bleed
	pain = clampf(pain + applied * 0.72 + impulse * 0.04, 0.0, 100.0)
	var wound := {
		"zone": resolved_zone,
		"damage": snappedf(applied, 0.1),
		"type": damage_type,
		"bleed_rate": snappedf(wound_bleed, 0.01),
		"disabled": float(zone.health) <= 0.0,
		"time_msec": Time.get_ticks_msec(),
		# AN2.3. How much of the raw blow this zone actually stopped, from armour
		# plate and shielding alone — the caller's own read of what the weapon
		# hit, not a duplicate of the armour math above.
		"absorbed": clampf(1.0 - applied / maxf(damage, 0.01), 0.0, 0.95),
	}
	# B6.7v2. A closed break and a compound break are not the same injury. The
	# former is a disabled structure under intact skin; only a penetrating blow
	# at fracture depth opens it to the world.
	# B3.2. Not for a melting injury. A dosed limb has not broken — there is
	# less of it than there was, and a fracture is a statement about structure
	# that survived. Reading "compound fracture" on a limb somebody irradiated
	# is the rig telling the player the wrong story about what happened.
	if not melting and resolved_zone in ["left_arm", "right_arm", "left_leg", "right_leg"] and float(zone.health) <= float(DEFAULT_ZONES[resolved_zone].health) * 0.40:
		var fracture := "compound" if penetrating else "closed"
		if str(zone.get("fracture", "")) != "compound":
			zone["fracture"] = fracture
			zones[resolved_zone] = zone
		wound["fracture"] = fracture
	if not _sites_for_zone(resolved_zone).is_empty():
		wound["implant_condition"] = damage_implants_at_zone(resolved_zone, applied * (0.30 if penetrating else 0.16))
	wounds.append(wound)
	if wounds.size() > 24:
		wounds.pop_front()
	if bool(zone.critical) and float(zone.health) <= 0.0:
		_enter_critical()
		# Losing the head or the chest drops you. It does not kill you on its
		# own, because what happens next is supposed to be someone's decision.
		go_down()
	# Only something that opens the body reaches what is inside it. A blunt hit
	# breaks the ribs; it does not perforate the liver.
	if penetrating and organs.has(organ_id):
		wound["organ"] = damage_organ(organ_id, applied * 0.7)
	# B3.1. Except this. Radiation does not need a way in — it goes through the
	# skin, through the zone, and through everything the zone is carrying, which
	# is the entire difference between being cut and being dosed. So it reaches
	# every organ in the zone at once rather than the one a blade happened to
	# find, and it leaves dose behind to go on doing it.
	if melting:
		wound["melted"] = true
		var shared: Array = []
		for organ_key in organs:
			if str((organs[organ_key] as Dictionary).get("zone", "")) == resolved_zone:
				damage_organ(organ_key, applied * 0.22)
				shared.append(organ_key)
		wound["organs_dosed"] = shared
		dose[resolved_zone] = float(dose.get(resolved_zone, 0.0)) + applied * DOSE_SHARE
		wound["dose"] = snappedf(float(dose[resolved_zone]), 0.1)
	var result := wound.duplicate(true)
	result["blood_remaining"] = blood_remaining
	result["pain"] = pain
	wounded.emit(result)
	return result


func fracture_kind(zone_id: String) -> String:
	return str((zones.get(zone_id, {}) as Dictionary).get("fracture", ""))


func damage_organ(organ_id: String, amount: float) -> Dictionary:
	if not organs.has(organ_id):
		return {}
	var organ: Dictionary = organs[organ_id]
	if bool(organ.ruptured):
		return organ
	if organ_id == "spine":
		var damaged: Array = organ.get("vertebrae_damaged", []).duplicate()
		var newly_damaged := clampi(ceili(amount / 5.0), 1, SPINE_VERTEBRAE)
		for index in newly_damaged:
			var vertebra := (damaged.size() + index) % SPINE_VERTEBRAE + 1
			if not damaged.has(vertebra):
				damaged.append(vertebra)
		organ["vertebrae_damaged"] = damaged
	organ["health"] = maxf(0.0, float(organ.health) - amount)
	if float(organ.health) <= 0.0:
		organ["ruptured"] = true
		internal_bleed_rate += float(organ.bleed) * 14.0
		pain = clampf(pain + 26.0, 0.0, 100.0)
		organs[organ_id] = organ
		organ_ruptured.emit(organ_id, organ)
		_enter_critical()
		if bool(organ.get("fatal", false)):
			_die_or_fail({"type": "organ_destroyed", "organ": organ_id, "subject_id": subject_id})
	organs[organ_id] = organ
	return organ


func go_down() -> void:
	if downed or dead:
		return
	downed = true
	_enter_critical()
	went_down.emit()


## Someone chose to leave them alive. Bleeding is packed, not healed — sparing a
## person costs the winner nothing and leaves the world a witness.
func stabilise() -> void:
	if dead:
		return
	bleed_rate *= 0.12
	pain = maxf(0.0, pain - 34.0)
	consciousness = maxf(consciousness, 24.0)
	downed = false
	bleeding_changed.emit(bleed_rate, blood_remaining)


func finish(cause: String) -> void:
	if dead:
		return
	_die_or_fail({"type": cause, "subject_id": subject_id, "wounds": wounds.duplicate(true)})


## B8.1. The single door every death in this component goes through.
##
## There were three — a fatal organ, `finish()`, and bleeding out — and each set
## `dead = true` itself. That is fine until one body is not allowed to die, at
## which point three independent copies of "and now you are dead" is three
## chances to miss one, and the one you miss is the one that kills the player
## who cannot be killed. So they all call this, and the undying case is decided
## in exactly one place.
##
## Returns true if the subject actually died.
func _die_or_fail(report: Dictionary) -> bool:
	if not undying:
		dead = true
		downed = false
		died.emit(report)
		return true
	# AP2.1: "the spirit cannot be banished by violence." Note what is *not*
	# here — no healing, no reset, no mercy on the wound. Everything that was
	# done to this body is still done to it. It has simply stopped being able to
	# carry on, and something is still holding it.
	if failed:
		return false
	failed = true
	downed = true
	var record := report.duplicate(true)
	record["failure_index"] = failures.size() + 1
	failures.append(record)
	# B8.1's "visibly". Each failure gives up more of the body permanently, and
	# `UndyingFlame` reads condition — so the spirit shows through harder every
	# time, on the body, in the frame. This is the whole readout; there is no
	# counter anywhere.
	spirit_burden = clampf(spirit_burden + BURDEN_PER_FAILURE, 0.0, 1.0)
	body_failed.emit(record)
	return false


## B8.2. What is left, and what it costs to stand up in it.
##
## Deliberately not a revive. Blood comes back only to the floor it takes to be
## conscious, pain is not touched, every wound and every severed limb stays, and
## the burden that just went up never comes down. The body is worse than it was
## and will be worse again next time — which is the only thing stopping "cannot
## die" from meaning "nothing that happens matters".
func rise() -> Dictionary:
	if not failed:
		return {"risen": false, "reason": "the body has not failed"}
	failed = false
	downed = false
	blood_remaining = maxf(blood_remaining, blood_capacity * RISE_BLOOD_FLOOR)
	consciousness = maxf(consciousness, RISE_CONSCIOUSNESS)
	# Bleeding is slowed, not stopped. Standing up does not close anything.
	bleed_rate *= 0.35
	internal_bleed_rate *= 0.35
	var report := {
		"subject_id": subject_id,
		"failures": failures.size(),
		"spirit_burden": spirit_burden,
		"condition": combat_ratio(),
	}
	spirit_rose.emit(report)
	bleeding_changed.emit(bleed_rate, blood_remaining)
	return report


## What `UndyingFlame.set_condition()` should be handed for this body.
##
## The flame already burns harder as the anatomy worsens (A8). The burden folds
## into the same number rather than adding a second effect beside it, so a body
## that has run out three times reads as further gone than its current wounds
## alone would say — which is exactly what it is.
func flame_condition() -> float:
	return clampf(combat_ratio() * (1.0 - spirit_burden), 0.0, 1.0)



## The armour over a zone, as one number, summed the same way `apply_hit()` sums
## it. Public because `Penetration` needs the same figure to decide how much of
## a round's budget is spent before it reaches flesh, and two loops computing the
## same sum is one loop too many.
func zone_armor(zone_id: String) -> float:
	var armor := 0.0
	for site_id: String in _sites_for_zone(zone_id):
		var part: Dictionary = installed_parts.get(site_id, {})
		armor += float(part.get("armor", 0.0)) * implant_condition(site_id)
	return armor

func organ_ok(organ_id: String) -> bool:
	return not bool((organs.get(organ_id, {}) as Dictionary).get("ruptured", false))


## N5.2. What CellOutz puts in before you ever wake up. Not every zone —
## "fills them" is what a factory build actually feels like, not "every slot
## has something," and a limb or a leg staying open is what makes the ones
## that are not read as deliberate. Each one is a real reason CellOutz would
## want it there: the jaw nail hears what you say, the regulator can stop
## your heart, the dose counter answers exactly why the warning is in its
## voice rather than the game's.
const FACTORY_LOADOUT := {
	"head": "jaw telemetry nail",
	"torso": "quiet-heart regulator",
	"left_arm": "dose counter",
}


## N5.2/N5.6. Called once, at decanting — deliberately not from `configure()`
## itself, so an NPC built from the same rig never gets a player-only
## loadout it was never asked for. An empty zone left empty is not a bug: a
## limb with nothing installed is a real, mechanically lesser condition
## (N5.6) already, through `implant_condition()` simply having nothing to
## report — no separate penalty needed for a gap already visible as one.
##
## N5.8. A zone the character sheet already grew something into (D4's
## `_grown_cybernetics()`) is skipped rather than overwritten — CellOutz backs
## the slots you walked out of the vat with nothing in, not the ones you
## already had a body's worth of history in.
##
## `exclude` exists for one real reason today rather than as general API:
## `baseline_human.gd`'s severance stress only ever accumulates on a limb zone
## with nothing in `installed_parts` (B6.5/B6.6 — a limb already carrying any
## hardware is read as an existing replacement, not organic tissue). The
## catalog does not yet distinguish a wrist-mounted dose counter from a full
## prosthetic arm, so filling `left_arm` here would quietly make the
## player's own arm un-severable forever. The real caller excludes it until
## that distinction exists; this method's own test still exercises all three
## zones, since it never touches severance.
func install_factory_loadout(exclude: Array[String] = []) -> void:
	for zone_id in FACTORY_LOADOUT:
		if zone_id in exclude or installed_parts.has(zone_id):
			continue
		install_part(zone_id, {"id": str(FACTORY_LOADOUT[zone_id]), "locked": true})


## N5.1. Keyed by the site the caller actually asked for, not by whichever
## zone the catalog entry happens to carry — `ImplantCatalog`'s own entries
## still decide the *damage zone* an implant answers to (through `resolve()`'s
## `zone` field, read via `INSTALL_SITES` below), but "torso" and "spine" can
## now both be occupied at once without one silently overwriting the other,
## which was impossible while both collapsed onto the single key "torso".
func install_part(site_id: String, part_data: Dictionary) -> Dictionary:
	var zone_id := str(INSTALL_SITES.get(site_id, site_id))
	var part := ImplantCatalog.resolve(part_data, zone_id)
	installed_parts[site_id] = part
	return part.duplicate(true)


## B6.1. What a limb can *do* because of what is bolted into it — keyed off
## the hardware's own `profile`, the field `implant_catalog.gd` has carried
## for every entry since it was written and that B5.2 already draws the shape
## from. Keyed that way on purpose: a capability read off the same field the
## limb is drawn from cannot disagree with the thing granting it, the way a
## second ability table sitting beside the body would.
##
## "Through the anatomy rather than around it" is the whole of the item. A
## limb grapples because of what is installed in that limb, its condition is
## the hardware's real condition, and when the limb stops being there it
## stops being able to (B6.2) — none of which is true of an ability flag that
## never hears about an arm coming off.
const LIMB_CAPABILITIES := {
	"industrial_limb": ["grapple"],
	"scrap_limb": ["grapple"],
	"limb_drive": ["grapple"],
	"launcher_limb": ["launch"],
	# AD3.2. "Cybernetics change what movement is possible, not just the
	# numbers" — so these grant moves, never multipliers. `heel anchors` is
	# the catalogue's own right-leg entry and reads exactly like the thing
	# that would drive a body off the ground: with it a leg can kick off
	# nothing mid-air, and clear obstacles a bare body reads as a wall.
	"joint_anchor": ["kick_off", "vault_high"],
}

## Dead hardware does nothing. A limb drive at zero condition is a weight on
## the end of your arm, not a grapple.
const CAPABILITY_MINIMUM_CONDITION := 0.15


## What the hardware at one site offers right now. Empty for an empty site,
## for hardware with no capability profile, and for hardware too far gone to
## answer — the last of which is why this reads condition rather than only
## presence.
func limb_capabilities(site_id: String) -> Array[String]:
	var out: Array[String] = []
	var part: Dictionary = installed_parts.get(site_id, {})
	if part.is_empty():
		return out
	if implant_condition_ratio(part) < CAPABILITY_MINIMUM_CONDITION:
		return out
	for capability in LIMB_CAPABILITIES.get(str(part.get("profile", "")), []):
		out.append(str(capability))
	return out


func limb_can(site_id: String, capability: String) -> bool:
	return limb_capabilities(site_id).has(capability)


## Every site that can do this right now. For a caller choosing which arm to
## reach with rather than asking about one it already picked.
func capable_sites(capability: String) -> Array[String]:
	var out: Array[String] = []
	for site_id in installed_parts:
		if limb_can(str(site_id), capability):
			out.append(str(site_id))
	return out


## N5.1. Every occupied site that answers to a given damage zone — "torso"
## alone once meant one implant; it can now mean a spine cage, a chest plate
## and an organ-bay graft all at once, each tracked and damaged separately.
func _sites_for_zone(zone_id: String) -> Array[String]:
	var out: Array[String] = []
	for site_id in installed_parts:
		if str(INSTALL_SITES.get(site_id, site_id)) == zone_id:
			out.append(site_id)
	return out


## The combined readout for a zone with more than one site occupied — the
## average of what is actually installed there, rather than only ever seeing
## whichever single implant used to own the whole zone.
func implant_condition_at_zone(zone_id: String) -> float:
	var sites := _sites_for_zone(zone_id)
	if sites.is_empty():
		return 0.0
	var total := 0.0
	for site_id in sites:
		total += implant_condition(site_id)
	return total / float(sites.size())


func damage_implants_at_zone(zone_id: String, amount: float) -> float:
	for site_id in _sites_for_zone(zone_id):
		damage_implant(site_id, amount)
	return implant_condition_at_zone(zone_id)


## N5.4. In CellOutz's own voice, not the game's — the warning belongs to the
## faction that put the hardware in, not to a UI writing a generic refusal.
const LOCKED_WARNING := "you don't want to go rogue yet, do you"


## N5.2/N5.3. Locked means discouraged, never disabled: a first call against a
## locked slot only warns, and the caller has to ask again with `confirmed`
## actually true to make it happen — never a silent block. N5.7: what comes
## back is shaped for `Carry.take_chunk()` directly, with a lien attached
## (N5.7 again — a factory part was never yours), so a caller only has to pass
## the result straight through rather than re-deriving the shape.
func pull_part(zone_id: String, confirmed := false) -> Dictionary:
	var part: Dictionary = installed_parts.get(zone_id, {})
	if part.is_empty():
		return {"ok": false, "reason": "EMPTY"}
	if bool(part.get("locked", false)) and not confirmed:
		return {"ok": false, "reason": "LOCKED", "warning": LOCKED_WARNING}
	installed_parts.erase(zone_id)
	WorldHistory.record_event("implant_pulled", {
		"subject_id": subject_id, "zone": zone_id, "implant": str(part.get("id", "")),
		"was_locked": bool(part.get("locked", false)),
	})
	return {
		"ok": true,
		"info": {
			"subject_id": subject_id,
			"zone": zone_id,
			"implant": str(part.get("name", part.get("id", "hardware"))),
			"condition": implant_condition_ratio(part),
			# CellOutz put it there; CellOutz's claim on it does not end just
			# because it is now in your hand instead of your body.
			"lien": "celloutz",
		},
	}


func implant_condition_ratio(part: Dictionary) -> float:
	if part.is_empty():
		return 0.0
	return clampf(float(part.get("condition", 0.0)) / maxf(1.0, float(part.get("max_condition", 100.0))), 0.0, 1.0)


func implant_condition(zone_id: String) -> float:
	return implant_condition_ratio(installed_parts.get(zone_id, {}))


func damage_implant(zone_id: String, amount: float) -> float:
	var part: Dictionary = installed_parts.get(zone_id, {})
	if part.is_empty():
		return 0.0
	part["condition"] = maxf(0.0, float(part.get("condition", 0.0)) - maxf(0.0, amount))
	installed_parts[zone_id] = part
	return implant_condition(zone_id)


## A ruptured heart does not let you keep standing while you bleed out on a
## normal clock, and a severed spine is not a limp.
func _organ_consciousness_drain() -> float:
	var drain := 0.0
	if not organ_ok("heart"):
		drain += 34.0
	if not organ_ok("left_lung"):
		drain += 9.0
	if not organ_ok("right_lung"):
		drain += 9.0
	return drain


func treat_wound(zone_id: String, quality: float) -> void:
	var treatment := clampf(quality, 0.0, 1.0)
	bleed_rate *= 1.0 - treatment * 0.82
	pain = maxf(0.0, pain - treatment * 28.0)
	for wound in wounds:
		if str(wound.get("zone", "")) == zone_id:
			wound["treated"] = true
	bleeding_changed.emit(bleed_rate, blood_remaining)


func has_internal_bleeding() -> bool:
	return internal_bleed_rate > 0.01


func xray_findings() -> Array[String]:
	var findings: Array[String] = []
	for organ_id in organs:
		if bool((organs[organ_id] as Dictionary).get("ruptured", false)):
			findings.append("INTERNAL BLEED: " + str(organ_id).replace("_", " ").to_upper())
	var spine: Dictionary = organs.get("spine", {})
	var damaged: Array = spine.get("vertebrae_damaged", [])
	if not damaged.is_empty():
		findings.append("SPINE: %d / %d VERTEBRAE DAMAGED" % [damaged.size(), SPINE_VERTEBRAE])
	return findings


func posture() -> Dictionary:
	var visual_pain := clampf(pain / FUNCTIONAL_PAIN, 0.0, 1.0)
	var left_leg: Dictionary = zones.get("left_leg", DEFAULT_ZONES.left_leg)
	var right_leg: Dictionary = zones.get("right_leg", DEFAULT_ZONES.right_leg)
	var left_ratio := float(left_leg.health) / float(DEFAULT_ZONES.left_leg.health)
	var right_ratio := float(right_leg.health) / float(DEFAULT_ZONES.right_leg.health)
	return {
		"state": "upright" if visual_pain < 0.12 else ("guarded" if visual_pain < 0.72 else "faltering"),
		"hunch": -visual_pain * 0.085,
		"lean": clampf((right_ratio - left_ratio) * 0.16, -0.16, 0.16),
	}


func mobility_ratio() -> float:
	var left: Dictionary = zones.get("left_leg", DEFAULT_ZONES.left_leg)
	var right: Dictionary = zones.get("right_leg", DEFAULT_ZONES.right_leg)
	var limb_ratio := (float(left.health) / 75.0 + float(right.health) / 75.0) * 0.5
	# A severed spine is not a limp. It floors mobility below anything two bad
	# legs can produce, and no amount of pain management brings it back.
	if not organ_ok("spine"):
		return 0.05
	var spine: Dictionary = organs.get("spine", {})
	var damaged_count := (spine.get("vertebrae_damaged", []) as Array).size()
	var spine_ratio := 1.0 - float(damaged_count) / float(SPINE_VERTEBRAE)
	var functional_pain := maxf(0.0, pain - FUNCTIONAL_PAIN)
	return clampf(limb_ratio * lerpf(0.38, 1.0, spine_ratio) * (1.0 - functional_pain * 0.008), 0.18, 1.0)


func combat_ratio() -> float:
	var left: Dictionary = zones.get("left_arm", DEFAULT_ZONES.left_arm)
	var right: Dictionary = zones.get("right_arm", DEFAULT_ZONES.right_arm)
	return clampf((float(left.health) + float(right.health)) / 130.0, 0.15, 1.0)


func snapshot() -> Dictionary:
	return {
		# B3.1. Dose travels with the body. A survivor who walked out of a hot
		# zone is still being damaged by it in the next scene, which is the
		# whole point of it being a path through the anatomy rather than an
		# effect attached to a place.
		"dose": dose.duplicate(true),
		"worn": worn.duplicate(),
		"blood": roundi(blood_remaining),
		"blood_capacity": roundi(blood_capacity),
		"bleed_rate": snappedf(bleed_rate, 0.01),
		"internal_bleed_rate": snappedf(internal_bleed_rate, 0.01),
		"pain": roundi(pain),
		"consciousness": roundi(consciousness),
		"critical": critical,
		"dead": dead,
		"downed": downed,
		"zones": zones.duplicate(true),
		"organs": organs.duplicate(true),
		"wounds": wounds.duplicate(true),
		"cybernetics": installed_parts.duplicate(true),
	}


func restore(state: Dictionary) -> void:
	dose = (state.get("dose", {}) as Dictionary).duplicate(true)
	worn = (state.get("worn", []) as Array).duplicate()
	blood_capacity = maxf(100.0, float(state.get("blood_capacity", blood_capacity)))
	blood_remaining = clampf(float(state.get("blood", blood_capacity)), 0.0, blood_capacity)
	bleed_rate = maxf(0.0, float(state.get("bleed_rate", 0.0)))
	internal_bleed_rate = maxf(0.0, float(state.get("internal_bleed_rate", 0.0)))
	pain = clampf(float(state.get("pain", 0.0)), 0.0, 100.0)
	consciousness = clampf(float(state.get("consciousness", 100.0)), 0.0, 100.0)
	critical = bool(state.get("critical", false))
	dead = bool(state.get("dead", false))
	downed = bool(state.get("downed", false))
	var saved_zones: Dictionary = state.get("zones", {})
	for zone_id in zones:
		if saved_zones.get(zone_id) is Dictionary:
			zones[zone_id].merge(saved_zones[zone_id], true)
	# Saves written before organs existed simply have none; the defaults built
	# in configure() stand, which is the same migration rule as subjects.
	var saved_organs: Dictionary = state.get("organs", {})
	for organ_id in organs:
		if saved_organs.get(organ_id) is Dictionary:
			organs[organ_id].merge(saved_organs[organ_id], true)
	if state.has("cybernetics"):
		installed_parts = ImplantCatalog.by_zone(state.cybernetics)
	wounds.clear()
	for wound in state.get("wounds", []):
		if wound is Dictionary:
			wounds.append(wound.duplicate(true))


func _process(delta: float) -> void:
	if dead:
		return
	_burn_dose(delta)
	var total_bleed := bleed_rate + internal_bleed_rate
	if total_bleed <= 0.001:
		return
	blood_remaining = maxf(0.0, blood_remaining - total_bleed * delta)
	consciousness = clampf((blood_remaining / blood_capacity) * 120.0 - pain * 0.22 - _organ_consciousness_drain(), 0.0, 100.0)
	bleed_rate = maxf(0.0, bleed_rate - delta * 0.012)
	internal_bleed_rate = maxf(0.0, internal_bleed_rate - delta * 0.006)
	bleeding_changed.emit(bleed_rate, blood_remaining)
	if blood_remaining <= blood_capacity * 0.32:
		_enter_critical()
	if consciousness <= 0.0:
		go_down()
	# Running out of blood is the one thing nobody gets to decide about.
	if blood_remaining <= 0.0:
		_die_or_fail({"type": "bleed_out", "subject_id": subject_id, "wounds": wounds.duplicate(true)})


## B3.2. Dose spends itself into the body it is sitting in. This is the half a
## cut does not have: a blade does its damage at the moment it lands and is
## finished, and this goes on ruining the zone and everything inside it long
## after whoever delivered it has walked away.
func _burn_dose(delta: float) -> void:
	if dose.is_empty():
		return
	var spent: Array = []
	for zone_id in dose:
		var remaining := float(dose[zone_id])
		if remaining <= 0.01:
			spent.append(zone_id)
			continue
		var burn := minf(remaining, DOSE_BURN_PER_SECOND * delta)
		var zone: Dictionary = zones.get(zone_id, {})
		if not zone.is_empty():
			zone["health"] = maxf(0.0, float(zone.health) - burn)
			zones[zone_id] = zone
		for organ_key in organs:
			if str((organs[organ_key] as Dictionary).get("zone", "")) == str(zone_id):
				damage_organ(organ_key, burn * 0.3)
		dose[zone_id] = maxf(0.0, remaining - burn - DOSE_DECAY_PER_SECOND * delta)
	for zone_id in spent:
		dose.erase(zone_id)


## B7.1. Standing in it. A contaminated storm doses a body through the air
## rather than by hitting it, so this is not a wound and makes none: it is the
## same dose B3 introduced, arriving slowly, on the zones nothing is covering.
## A sealed garment is the difference between walking through weather and
## breathing it.
func expose(severity: float, delta: float) -> void:
	var bad := clampf(severity, 0.0, 1.0)
	if bad <= 0.05 or dead:
		return
	for zone_id in zones:
		var sealed := float(Garments.shielding(worn, str(zone_id)).seal)
		var taken := bad * (1.0 - sealed) * EXPOSURE_DOSE_PER_SECOND * delta
		if taken <= 0.0:
			continue
		dose[zone_id] = float(dose.get(zone_id, 0.0)) + taken


## B3.2. How melted a zone reads, 0 to 1, for anything that draws it.
func dose_ratio(zone_id: String) -> float:
	return clampf(float(dose.get(zone_id, 0.0)) / 24.0, 0.0, 1.0)


func _enter_critical() -> void:
	if critical:
		return
	critical = true
	critical_state_started.emit()
