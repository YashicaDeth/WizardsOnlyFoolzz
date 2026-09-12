class_name CastNames
extends RefCounted

## Names, generated per save.
##
## Greg: *"no more mara voss wipe it"*. Fair — she has been the Bone Yard captain
## in every screenshot and every run since the derby was built, and the reason is
## that she is hardcoded in two places as a string.
##
## The wipe is not a find-and-replace, because a second hardcoded name is the
## same problem with different letters. **F v10.1 already says it: a rival is
## made by what happened, never spawned as a rival.** A world where the captain
## has the same name in everybody's save is a world with an authored antagonist,
## which is the thing this project keeps saying it does not want.
##
## So names are generated from `WorldHistory.run_salt` — the same number A5.6
## uses to make each run's grime its own. That gives the property that matters:
## **stable inside a save, different between saves.** The captain you are
## hunting is yours. Somebody else's captain has another name, and when the
## universe restarts (T1.1) so does the cast.
##
## The register is taken from the people already written into this world — Cass
## Lumen, Juno Veil, Gray Hollis, Wren Ashby, Nix Arden, Rook Sable, Iris Coil.
## Short blunt forenames; surnames that are materials, weather, instruments or
## parts of a building. Nothing fantasy, nothing apostrophised.

const FORENAMES := [
	"Cass", "Juno", "Wren", "Nix", "Rook", "Iris", "Gray", "Vale", "Bex",
	"Tallis", "Orla", "Pike", "Sloane", "Reve", "Mera", "Corin", "Ash",
	"Lior", "Sable", "Quill", "Enna", "Torr", "Kester", "Brann", "Dove",
	"Halloway", "Ives", "Nell", "Roan", "Sparrow", "Verity", "Whit",
]

## Materials, weather, instruments, and parts of a building. A surname in this
## world sounds like something you could be hit with.
const SURNAMES := [
	"Lumen", "Veil", "Hollis", "Ashby", "Arden", "Sable", "Coil", "Marrow",
	"Gantry", "Culvert", "Lathe", "Brine", "Winch", "Cinder", "Rime",
	"Lockwood", "Tarn", "Grieve", "Mallory", "Stanchion", "Gale", "Quarry",
	"Fen", "Hollow", "Kiln", "Lintel", "Murrain", "Pallor", "Rafter",
	"Sallow", "Trestle", "Vellum", "Wick", "Yarrow", "Corbel", "Drift",
]

## What a person is for, in this world. Used when something needs a role and
## nobody has authored one.
const ROLES := [
	"Bone Yard Captain", "Pit Marshal", "Scrap Surgeon", "Line Foreman",
	"Ration Clerk", "Signal Keeper", "Wreck Boss", "Grave Contractor",
	"Tithe Collector", "Spare Parts Broker", "Yard Warden", "Rig Mechanic",
]

const FACTIONS := [
	{"id": "ashline_wreckers", "name": "Ashline Wreckers"},
	{"id": "mercy_county_haul", "name": "Mercy County Haul"},
	{"id": "the_slag_line", "name": "The Slag Line"},
	{"id": "bonewright_union", "name": "Bonewright Union"},
]


## A name for a given slot. `slot` is a stable string — "derby_captain", say —
## so the same slot always resolves to the same person inside one save and to a
## different one in the next. Nothing here is random at the point of call, which
## is what keeps it from changing between two reads on the same frame.
static func person(slot: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(slot)
	var forename: String = FORENAMES[rng.randi() % FORENAMES.size()]
	var surname: String = SURNAMES[rng.randi() % SURNAMES.size()]
	var faction: Dictionary = FACTIONS[rng.randi() % FACTIONS.size()]
	return {
		"id": "%s_%s" % [forename.to_lower(), surname.to_lower()],
		"name": "%s %s" % [forename, surname],
		"role": ROLES[rng.randi() % ROLES.size()],
		"faction": str(faction["name"]),
		"faction_id": str(faction["id"]),
	}


## The same person, already registered, or registered now. Anything that needs
## the derby captain calls this rather than holding a constant, which is the
## whole point — there is no longer a name in the source to go stale.
static func ensure(slot: String, extra: Dictionary = {}) -> Dictionary:
	var who := person(slot)
	var record: Dictionary = {
		"name": str(who["name"]),
		"kind": "person",
		"role": str(who["role"]),
		"faction": str(who["faction"]),
		"faction_id": str(who["faction_id"]),
	}
	for key in extra:
		record[key] = extra[key]
	WorldHistory.register_subject(str(who["id"]), record)
	return who


## The id alone, for the many places that only need to address the subject.
static func id_for(slot: String) -> String:
	return str(person(slot)["id"])


## Mixed rather than concatenated, so two adjacent slot names do not produce two
## adjacent people — "derby_captain" and "derby_captain_2" should not be
## siblings by accident.
static func _seed_for(slot: String) -> int:
	var mixed := int(WorldHistory.run_salt) ^ hash(slot)
	mixed = (mixed ^ (mixed >> 13)) * 0x5bd1e995
	return absi(mixed ^ (mixed >> 15))
