class_name CombatInputLayer
extends RefCounted

## Physical pad controls are stable; a discipline supplies only verb overrides.
## Keeping this table as data prevents the Hunt, sandbox and future discipline
## manager from each hard-coding a different meaning for the same shoulder.

const R1 := "pad_combat_r1"
const R2 := "pad_combat_r2"
const L1 := "pad_combat_l1"
const L2 := "pad_combat_l2"
const PHYSICAL_ACTIONS := [R1, R2, L1, L2]

const SOULS_BASE := {
	"melee": {
		R1: "light",
		R2: "heavy",
		L1: "block",
		L2: "parry",
	},
	"firearm": {
		# R1 remains the main-hand light verb. The current single-weapon Hunt
		# cannot perform it while a firearm occupies that hand, but it must not
		# become a second fire button. Bloodborne-style split hands can consume
		# this verb unchanged when that equipment work lands.
		R1: "light",
		R2: "fire",
		L1: "block",
		L2: "aim",
	},
}

## Lab-only discipline layers. Physical shoulders stay put; the selected
## discipline changes their verbs. Route scenes continue to use SOULS_BASE.
const DUELIST := {
	"melee": {
		R1: "duelist_attack",
		R2: "duelist_heavy",
		L1: "duelist_block",
		L2: "duelist_parry",
	},
}
const SHADE := {
	"melee": {
		R1: "shade_takedown",
		R2: "shade_throw",
		L1: "shade_darkness",
		L2: "shade_stalk",
	},
}

const GLYPHS := {R1: "R1", R2: "R2", L1: "L1", L2: "L2"}


static func souls_base() -> Dictionary:
	return SOULS_BASE.duplicate(true)


static func discipline(id: String) -> Dictionary:
	match id:
		"duelist": return with_overrides(DUELIST)
		"shade": return with_overrides(SHADE)
		_: return souls_base()


## A discipline layer is sparse: only meanings it changes are supplied.
## Example: {"melee": {R2: "discipline_special"}}. Context and physical
## controls omitted by it continue to use the Souls base.
static func with_overrides(overrides: Dictionary) -> Dictionary:
	var result := souls_base()
	for context_key in overrides:
		var context := str(context_key)
		if not result.has(context):
			result[context] = {}
		var values = overrides[context_key]
		if values is Dictionary:
			(result[context] as Dictionary).merge(values, true)
	return result


static func verb(layer: Dictionary, physical_action: String, context: String) -> String:
	var active_context := context if layer.has(context) else "melee"
	var mapping: Dictionary = layer.get(active_context, {})
	return str(mapping.get(physical_action, ""))


static func physical_for(layer: Dictionary, wanted_verb: String, context: String) -> String:
	var active_context := context if layer.has(context) else "melee"
	var mapping: Dictionary = layer.get(active_context, {})
	for physical_action in PHYSICAL_ACTIONS:
		if str(mapping.get(physical_action, "")) == wanted_verb:
			return physical_action
	return ""


static func glyph_for(layer: Dictionary, wanted_verb: String, context: String) -> String:
	return str(GLYPHS.get(physical_for(layer, wanted_verb, context), ""))
