class_name RivalTactics
extends RefCounted

## F4.2 / J3.1. Tactic adaptation, on LimboAI.
##
## The plugin has been sitting in the project unused at 119MB, and the honest
## question was whether to adopt it at all. The answer taken here: **do not port
## what already works.** The encounter AI is a state string with branches, it
## functions, and rewriting it into behaviour trees is risk for no player-visible
## gain. LimboAI earns its place on the thing that does *not* exist yet — the
## layer where a rival who has fought you before fights you differently.
##
## So this builds a tree per rival, from what the world actually recorded about
## them. `rival_registry.gd` already decides *that* somebody became a rival and
## what their body remembers; this decides *how they come at you next time*.
##
## Nothing here replaces the existing states. A tactic chooses which of them a
## rival prefers and when — it sits above the state machine rather than
## instead of it.

const RivalRegistryScript := preload("res://systems/rival_registry.gd")

## The tactics a rival can settle into. Each is a real answer to something the
## player actually did to them, which is the whole point — these are not
## personality flavours, they are scars with behaviour attached.
const TACTICS := {
	"press": {
		"label": "PRESSES",
		"why": "Nothing you did made them hesitate.",
		"keep_distance": 0.0,
		"patience": 0.2,
		"guard_bias": 0.1,
	},
	"circle": {
		"label": "CIRCLES",
		"why": "You put them down from the front, so they stopped going there.",
		"keep_distance": 3.4,
		"patience": 0.7,
		"guard_bias": 0.35,
	},
	"stand_off": {
		"label": "STANDS OFF",
		"why": "They lost an arm inside your reach and have not forgotten the distance.",
		"keep_distance": 7.5,
		"patience": 0.85,
		"guard_bias": 0.2,
	},
	"swarm": {
		"label": "BRINGS OTHERS",
		"why": "They have lost to you alone more than once.",
		"keep_distance": 4.2,
		"patience": 0.5,
		"guard_bias": 0.25,
	},
	"turtle": {
		"label": "COVERS UP",
		"why": "Their head has been opened before and they keep it behind their arms now.",
		"keep_distance": 1.6,
		"patience": 0.9,
		"guard_bias": 0.8,
	},
}


## What this rival has learned. Read out of `WorldHistory` at the moment it is
## asked for — no stored tactic to drift out of step with what happened, which
## is the same rule the Board runs on.
static func tactic_for(subject_id: String) -> Dictionary:
	var subject: Dictionary = WorldHistory.subject(subject_id)
	if subject.is_empty():
		return _named("press", 0)

	var losses := 0
	var lost_a_limb := false
	var head_opened := false
	var front_on := 0
	for event: Dictionary in WorldHistory.events:
		var details: Dictionary = event.get("details", {})
		if str(details.get("subject", details.get("subject_id", ""))) != subject_id:
			continue
		var kind := str(event.get("type", ""))
		if kind in ["npc_resolution", "rival_survived_hunt", "npc_spared", "npc_escaped_bleeding"]:
			losses += 1
		if kind == "limb_severed_in_combat":
			lost_a_limb = true
		if kind in ["melee_body_hit", "npc_anatomy_hit", "firearm_anatomy_hit"]:
			front_on += 1
			if str(details.get("zone", "")) == "head":
				head_opened = true

	# Ordered by how strongly the memory should override the others. A missing
	# limb is the loudest thing that can have happened to a body, so it wins.
	if lost_a_limb:
		return _named("stand_off", losses)
	if head_opened:
		return _named("turtle", losses)
	if losses >= 3:
		return _named("swarm", losses)
	if front_on >= 4:
		return _named("circle", losses)
	return _named("press", losses)


static func _named(id: String, losses: int) -> Dictionary:
	var tactic: Dictionary = (TACTICS[id] as Dictionary).duplicate()
	tactic["id"] = id
	tactic["losses"] = losses
	return tactic


## The LimboAI tree for a tactic, built in code rather than authored as a
## resource — a rival's tree depends on what happened to them, so it cannot be a
## file somebody saved in advance.
##
## Returns null when LimboAI is not present, and every caller is expected to
## cope: the plugin is 119MB of GDExtension and a build that cannot run without
## it is a build with a single point of failure for no reason.
static func build_tree(tactic: Dictionary) -> Resource:
	if not ClassDB.class_exists("BehaviorTree"):
		return null
	# Instantiate optional GDExtension classes by name. Referring to their
	# identifiers directly makes this script fail to parse on machines where
	# LimboAI is absent, defeating the graceful fallback above.
	var tree = ClassDB.instantiate("BehaviorTree")
	# Kept deliberately shallow. The value of the tree here is that it is *per
	# rival and swappable*, not that it is deep — a deep tree for an enemy that
	# fights for eleven seconds is decoration.
	var root = ClassDB.instantiate("BTSelector")
	tree.set_root_task(root)
	tree.set_meta("tactic", str(tactic.get("id", "press")))
	tree.set_meta("keep_distance", float(tactic.get("keep_distance", 0.0)))
	tree.set_meta("patience", float(tactic.get("patience", 0.2)))
	tree.set_meta("guard_bias", float(tactic.get("guard_bias", 0.1)))
	return tree


## What the encounter loop needs each frame, without knowing anything about
## behaviour trees. The tree is the authoring surface; this is the answer.
static func approach(tactic: Dictionary, distance: float) -> String:
	var wanted := float(tactic.get("keep_distance", 0.0))
	if wanted <= 0.1:
		return "close"
	if distance > wanted + 1.2:
		return "close"
	if distance < wanted - 1.2:
		return "withdraw"
	return "hold"
