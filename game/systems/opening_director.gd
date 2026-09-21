class_name OpeningDirector
extends RefCounted

## Tracks the opening run as world state rather than as scene-local flags, so
## the sequence survives a save/load and every other system can read where the
## player is in it. Stages advance forward only.
##
##   woke        -> conscious on the slab in the Cut Room
##   entered_arcade -> escaped the Growing Floor into the service artery
##   entered_lower_works -> entered the buried transit district beneath intake
##   entered_pit -> took the heat elevator to the derby under duress
##   won_derby   -> earned the way out
##   took_wire   -> picked up the handheld
##   left_facility -> out into the Ashbloom Expanse

const SUBJECT := "opening_run"
const STAGES := ["none", "woke", "broke_free", "entered_arcade", "entered_lower_works", "entered_pit", "won_derby", "took_wire", "left_facility"]


static func stage() -> String:
	return str(WorldHistory.subject(SUBJECT).get("stage", "none"))


static func stage_index() -> int:
	var found := STAGES.find(stage())
	return found if found >= 0 else 0


static func reached(target: String) -> bool:
	var target_index := STAGES.find(target)
	return target_index >= 0 and stage_index() >= target_index


## The front door asks the route where this world resumes. Keeping the stage
## mapping here prevents PLAY and DEMO from growing separate scene ladders.
static func resume_destination() -> Dictionary:
	if reached("won_derby"):
		return {"scene": "res://bone_yard_hunt.tscn", "caption": "walking out into the ashbloom expanse"}
	if reached("entered_pit"):
		return {"scene": "res://underground_colosseum.tscn", "caption": "the underground colosseum // heat one"}
	if reached("entered_lower_works"):
		return {"scene": "res://buried_city.tscn", "caption": "the lower works // restore lift power"}
	if reached("entered_arcade"):
		return {"scene": "res://service_arcade.tscn", "caption": "the service arcade // find a way below"}
	return {"scene": "res://vat_chamber.tscn", "caption": "the growing floor // decanting"}


static func advance(target: String) -> void:
	var target_index := STAGES.find(target)
	if target_index < 0 or target_index <= stage_index():
		return
	# update_subject owns first registration and its event atomically; include
	# the opening schema in that first mutation instead of saving it beforehand.
	WorldHistory.update_subject(SUBJECT, {"kind": "run", "debt": 1, "stage": target}, "opening_stage_%s" % target)


## The player owns the handheld only after physically picking it up.
static func has_wire() -> bool:
	return reached("took_wire")
