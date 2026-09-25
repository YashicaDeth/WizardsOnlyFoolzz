class_name BloodTrees
extends RefCounted

## Greg, 24 September 2026: "each style or weapon earns its own experience,
## called blood, from killing with it or using it well. Weapons evolve through
## fighting experience, not shops." Stealth "is its own fighting style with its
## own blood and its own tree." Question box, same day: blood comes from ALL of
## kills, damage dealt, your own blood lost, and finishers (which pay the most).
##
## This file is only data and the rules that read it. `BloodLedger` owns the
## record; `HunterArsenal.set_blood_modifiers()` is where an unlock turns into a
## number the weapon actually uses.
##
## ASSISTANT PLACEHOLDERS, FLAGGED FOR GREG: every node name, cost and effect
## below, and every rate in `RATES`. The shape (four styles, a short chain per
## style, blood spent as fuel from the style's own pool) is the proposal; the
## names are stand-ins until Greg names them.

## How much blood each fact pays. Proposed numbers, open to Greg.
##  hit        1 blood per `hit_damage_per_blood` of damage dealt, 1..`hit_cap`
##  kill       flat, to the weapon that last hurt the body
##  takedown   a body put on the ground without killing it (grapple, ram)
##  finisher   an execution: pays the most, and replaces the kill it causes
##  bled       your own blood lost, credited to what you were fighting with
const RATES := {
	"hit_damage_per_blood": 4.0,
	"hit_cap": 15,
	"kill": 12,
	"takedown": 15,
	"finisher": 30,
	# Anatomy blood is millilitres (a body holds ~5000); scene-local damage
	# numbers (Hollis's shot, the sentinel, the drain thing) are points.
	"bled_ml_per_blood": 40.0,
	"bled_damage_per_blood": 3.0,
}

## Style id -> what the tree view calls it. `melee` is Greg's "sword/melee".
const STYLES := {
	"melee": {"label": "BLADE / BLUNT", "tone": Color("c81f16")},
	"firearm": {"label": "IRON", "tone": Color("d8a24a")},
	"martial": {"label": "MEAT", "tone": Color("b86a4a")},
	"stealth": {"label": "HUSH", "tone": Color("35b7a7")},
}
const STYLE_ORDER := ["melee", "firearm", "martial", "stealth"]

## Names for things that fight but are not in `HunterArsenal.WEAPONS`.
const EXTRA_WEAPONS := {
	"breach_tool": {"label": "BREACH TOOL", "style": "melee"},
	"severed_limb": {"label": "SEVERED LIMB", "style": "melee"},
	"hands": {"label": "BARE HANDS", "style": "martial"},
	"grapple": {"label": "CLINCH", "style": "martial"},
	"surge": {"label": "TORQUE ARM", "style": "martial"},
	"unseen": {"label": "UNSEEN", "style": "stealth"},
}

## Greg, 24 September: blood opens the trees both ways. A node marked
## `auto` opens by itself, free, once its style has EARNED its cost in total;
## every other node is bought by spending blood from the style's pool.
##
## Each node: label, style, cost (blood spent from the style's pool), the
## nodes it needs first, a one-line effect, and either `scales` (applied to the
## named weapons through the arsenal's existing customization scale path) or
## `flag` (read by the system that owns the move; a flag nothing reads yet
## says NOT WIRED YET in its effect, and the tree marks it).
## `weapons` may name arsenal ids or a whole kind ("firearm", "melee").
const NODES := {
	# BLADE / BLUNT
	"first_cut": {
		"style": "melee", "label": "FIRST CUT", "cost": 20, "requires": [], "auto": true,
		"effect": "CLEAVER BITES DEEPER  +10% DAMAGE",
		"weapons": ["sword"], "scales": {"damage_scale": 1.10},
	},
	"light_hand": {
		"style": "melee", "label": "LIGHT HAND", "cost": 40, "requires": ["first_cut"],
		"effect": "CLEAVER RECOVERS FASTER  -10% COOLDOWN",
		"weapons": ["sword"], "scales": {"cooldown_scale": 0.90},
	},
	"clean_killer": {
		"style": "melee", "label": "CLEAN KILLER", "cost": 70, "requires": ["first_cut"],
		"effect": "KILLS SPARE THE LOOT  (NOT WIRED YET)",
		"flag": "melee_clean_kill",
	},
	"bone_reader": {
		"style": "melee", "label": "BONE READER", "cost": 110, "requires": ["light_hand"],
		"effect": "CLEAVER +10% DAMAGE AGAIN",
		"weapons": ["sword"], "scales": {"damage_scale": 1.10},
	},
	# Greg, 24 September: the moves. Each is read by the Hunt's fight code.
	"feint": {
		"style": "melee", "label": "FEINT", "cost": 60, "requires": ["first_cut"],
		"effect": "GUARD MID WIND-UP CANCELS THE SWING  THEY BITE AND OPEN UP",
		"flag": "melee_feint",
	},
	"combo": {
		"style": "melee", "label": "COMBO", "cost": 90, "requires": ["feint"],
		"effect": "THIRD QUICK HIT IN A ROW ON ONE BODY ALWAYS LANDS",
		"flag": "melee_combo",
	},
	# IRON
	"steady_hand": {
		"style": "firearm", "label": "STEADY HAND", "cost": 20, "requires": [], "auto": true,
		"effect": "EVERY GUN  -15% SPREAD",
		"weapons": ["firearm"], "scales": {"spread_scale": 0.85},
	},
	"quick_mag": {
		"style": "firearm", "label": "QUICK MAG", "cost": 40, "requires": ["steady_hand"],
		"effect": "EVERY GUN  -15% RELOAD TIME",
		"weapons": ["firearm"], "scales": {"reload_scale": 0.85},
	},
	"heavy_grain": {
		"style": "firearm", "label": "HEAVY GRAIN", "cost": 80, "requires": ["steady_hand"],
		"effect": "EVERY GUN  +8% DAMAGE",
		"weapons": ["firearm"], "scales": {"damage_scale": 1.08},
	},
	"dead_eye": {
		"style": "firearm", "label": "DEAD EYE", "cost": 120, "requires": ["quick_mag", "heavy_grain"],
		"effect": "CLEAN HEAD SHOTS  (NOT WIRED YET)",
		"flag": "firearm_dead_eye",
	},
	"hip_counter": {
		"style": "firearm", "label": "HIP COUNTER", "cost": 60, "requires": ["steady_hand"],
		"effect": "PARRY WITH A GUN IN HAND  FIRES POINT BLANK INTO THEM",
		"flag": "firearm_hip_counter",
	},
	# MEAT
	"knuckle": {
		"style": "martial", "label": "KNUCKLE", "cost": 20, "requires": [], "auto": true,
		"effect": "HARDER BARE HANDS  (NOT WIRED YET)",
		"flag": "martial_knuckle",
	},
	"clinch": {
		"style": "martial", "label": "CLINCH", "cost": 40, "requires": ["knuckle"],
		"effect": "LONGER HOLDS  (NOT WIRED YET)",
		"flag": "martial_clinch",
	},
	"breaker": {
		"style": "martial", "label": "BREAKER", "cost": 80, "requires": ["clinch"],
		"effect": "TAKEDOWNS BREAK LIMBS  (NOT WIRED YET)",
		"flag": "martial_breaker",
	},
	"riposte": {
		"style": "martial", "label": "RIPOSTE", "cost": 60, "requires": ["knuckle"],
		"effect": "AFTER YOU PARRY  YOUR NEXT BLOW CANNOT BE STOPPED",
		"flag": "martial_riposte",
	},
	# HUSH
	"soft_foot": {
		"style": "stealth", "label": "SOFT FOOT", "cost": 20, "requires": [], "auto": true,
		"effect": "QUIETER STEPS  (NOT WIRED YET)",
		"flag": "stealth_soft_foot",
	},
	"quiet_kill": {
		"style": "stealth", "label": "QUIET KILL", "cost": 40, "requires": ["soft_foot"],
		"effect": "UNSEEN FINISHERS LEAVE NO WITNESS  (NOT WIRED YET)",
		"flag": "stealth_quiet_kill",
	},
	"ghost": {
		"style": "stealth", "label": "GHOST", "cost": 80, "requires": ["quiet_kill"],
		"effect": "LONGER BEFORE THEY NOTICE  (NOT WIRED YET)",
		"flag": "stealth_ghost",
	},
	"backstab": {
		"style": "stealth", "label": "BACKSTAB", "cost": 60, "requires": ["soft_foot"],
		"effect": "FROM BEHIND ON SOMEONE WHO HASN'T SEEN YOU  A TAKEDOWN",
		"flag": "stealth_backstab",
	},
}


static func weapon_style(weapon_id: String) -> String:
	if EXTRA_WEAPONS.has(weapon_id):
		return str((EXTRA_WEAPONS[weapon_id] as Dictionary).style)
	if HunterArsenal.WEAPONS.has(weapon_id):
		return "firearm" if str((HunterArsenal.WEAPONS[weapon_id] as Dictionary).kind) == "firearm" else "melee"
	return "melee"


static func weapon_label(weapon_id: String) -> String:
	if EXTRA_WEAPONS.has(weapon_id):
		return str((EXTRA_WEAPONS[weapon_id] as Dictionary).label)
	if HunterArsenal.WEAPONS.has(weapon_id):
		return str((HunterArsenal.WEAPONS[weapon_id] as Dictionary).label)
	return weapon_id.to_upper().replace("_", " ")


static func style_nodes(style_id: String) -> Array[String]:
	var out: Array[String] = []
	for node_id in NODES:
		if str((NODES[node_id] as Dictionary).style) == style_id:
			out.append(str(node_id))
	return out


## Depth in its chain (0 = a root), for laying the tree out.
static func node_depth(node_id: String) -> int:
	var requires: Array = (NODES.get(node_id, {}) as Dictionary).get("requires", [])
	var deepest := -1
	for parent in requires:
		deepest = maxi(deepest, node_depth(str(parent)))
	return deepest + 1


static func hit_blood(damage: float) -> int:
	if damage <= 0.0:
		return 0
	return clampi(ceili(damage / float(RATES.hit_damage_per_blood)), 1, int(RATES.hit_cap))


## The composed scale dictionary every unlocked node gives one arsenal weapon.
## Multipliers compose, the same rule `weapon_definition()` uses for parts.
static func weapon_scales(unlocked: Array, weapon_id: String) -> Dictionary:
	var out: Dictionary = {}
	if not HunterArsenal.WEAPONS.has(weapon_id):
		return out
	var kind := str((HunterArsenal.WEAPONS[weapon_id] as Dictionary).kind)
	for node_id in unlocked:
		var node := NODES.get(str(node_id), {}) as Dictionary
		if not node.has("scales"):
			continue
		var targets: Array = node.get("weapons", [])
		if not (weapon_id in targets or kind in targets):
			continue
		for scale_name in (node.scales as Dictionary):
			out[scale_name] = float(out.get(scale_name, 1.0)) * float(node.scales[scale_name])
	return out
