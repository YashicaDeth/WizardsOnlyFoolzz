extends Node

## K1.2 / K1.3 / K4.1 / K4.2 — CellOutz and wizardsonlyfoolz made real, and the
## three Sins the axis table named but nobody built.
##
## `FACTION_TREE_AXIS` in `world_history.gd` has held `celloutz` and
## `wizardsonlyfoolz` since the M/N/O capture, but neither was ever registered
## as a real `WorldHistory` subject outside a test file — they were two names
## in a table, which is the exact gap K1.2/K1.3 name. Pride, Lust and Sloth had
## no faction at all: `DESIGN/COSMOLOGY.md` calls the other four Sins "already
## half in the code" and these three the gap to fill.
##
## Autoloaded (after `WorldHistory`, so its save load runs first) rather than
## seeded from `bone_yard_hunt.gd`, which Agent A owns — this only calls
## `WorldHistory`'s public API and never touches another agent's file. Every
## write here is a brand-new subject; nothing existing is amended, so there is
## nothing to migrate and nothing to lose.
##
## wizardsonlyfoolz deliberately holds no relation to `gate_lanterns` —
## whether the Lanterns are part of the order or a rival is still an open
## question in `DESIGN/COSMOLOGY.md`, and picking an answer here would quietly
## resolve a decision that belongs to Greg.
##
## K2, the Four Horsemen: named by Greg 2026-09-12 (traditional names, not an
## Ashbloom coinage) and seeded in `systems/the_four_horsemen.gd`, not here —
## a rotating leadership on its own succession machinery is a distinct enough
## concern from "these seven factions exist" to earn its own file.

func _ready() -> void:
	_seed()
	AscentEntities.seed_entities()
	TheFourHorsemen.seed_horsemen()


func _seed() -> void:
	_seed_sin(
		"vanity_row", "Vanity Row", "Augment vanity cult", "MODERATE",
		"Chrome strip market stalls threaded through the Bone Yard overpass",
		"A beauty pageant broadcast for augments, judged by people who can no longer feel their own faces.",
		"An unmodified face is an unfinished one. Perfection is purchased, in installments, forever.",
		"cass_lumen", "Cass Lumen", "Vanity Row headliner",
		"Has replaced every visible surface at least twice.",
		["mirror-chrome cheekbones", "subdermal ring lights"], "O+",
	)
	_seed_sin(
		"honeyvein", "The Honeyvein", "Intimacy and obligation brokers", "UNKNOWN",
		"Backrooms behind the Black Mile tollbooths, never the same door twice",
		"A private feed of favours owed, traded for a night, a name, or a look the other way.",
		"Want is a debt instrument. We just collect early.",
		"juno_veil", "Juno Veil", "Honeyvein handler",
		"Knows exactly what everyone in the Bone Yard owes, and to whom.",
		["subvocal recorder", "pupil dilation cuffs"], "AB+",
	)
	_seed_sin(
		"long_static", "The Long Static", "Apathy cult holding dead signal", "LOW",
		"Every forum nobody has closed and every mast nobody has climbed to fix",
		"Threads that have not moved in years, kept open because closing them would take effort.",
		"The flash already happened. Whatever you're bracing for already won.",
		"gray_hollis", "Gray Hollis", "Long Static caretaker",
		"Has not left the relay shack in four years and insists nothing has changed.",
		["dead man's switch pacemaker"], "unresolved",
	)

	WorldHistory.register_subject("celloutz", {
		"name": "CellOutz", "kind": "faction", "role": "The company that grew you", "threat": "UNKNOWN",
		"territory": "Everywhere. It is the brand under every panel you have touched since the vat.",
		"channel": "Every product notice, every liability waiver, every screen on the handheld you're holding.",
		"doctrine": "Ownership, downward. You signed the day you were grown.",
		"relations": {
			"ashline_wreckers": {"kind": "command", "strength": 90},
			"black_mile": {"kind": "command", "strength": 90},
			"soft_rot": {"kind": "command", "strength": 90},
			"choir_of_marrow": {"kind": "command", "strength": 90},
			"vanity_row": {"kind": "command", "strength": 90},
			"honeyvein": {"kind": "command", "strength": 90},
			"long_static": {"kind": "command", "strength": 90},
		},
	})
	WorldHistory.register_subject("wizardsonlyfoolz", {
		"name": "wizardsonlyfoolz", "kind": "faction", "role": "Ascending mage collective", "threat": "UNKNOWN",
		"territory": "Wherever a mast points up instead of down. Mostly rumour.",
		"channel": "A guild feed that will not verify you, no matter what you send it.",
		"doctrine": "Frequency is rank, and rank is bought in ways nobody will name to your face.",
		"relations": {},
	})
	# K1.3. "Ranks... paid grades" does not need the order's still-blocked
	# Law/Book/founder (E2) — WireNet.pyramid() already prices rank generically
	# once a faction has a real member. One real member, deliberately at the
	# bottom: nobody has been promoted, they have simply paid to be counted,
	# which is the doctrine already stated above made concrete rather than a
	# hierarchy this file would be inventing.
	WorldHistory.register_subject("wren_ashby", {
		"name": "Wren Ashby", "kind": "person", "role": "Paid into the first grade, still unverified",
		"faction": "wizardsonlyfoolz", "faction_id": "wizardsonlyfoolz", "elo": 950,
		"grudge": 0, "status": "waiting", "memory": "Sent the fee three times before anything answered.",
		"wounds": [], "anatomy": {"blood_type": "O-", "cybernetics": []}, "relations": {},
	})


## One Sin-faction plus the one captain who currently holds it, in the same
## shape `bone_yard_hunt.gd` already uses for the other four so `WireNet`'s
## pyramid, the Board and faction pricing treat all seven identically.
func _seed_sin(
	faction_id: String, faction_name: String, role: String, threat: String,
	territory: String, channel: String, doctrine: String,
	captain_id: String, captain_name: String, captain_role: String,
	memory: String, cybernetics: Array, blood_type: String,
) -> void:
	WorldHistory.register_subject(faction_id, {
		"name": faction_name, "kind": "faction", "role": role, "threat": threat,
		"territory": territory, "channel": channel, "doctrine": doctrine,
		"relations": {captain_id: {"kind": "command", "strength": 50}},
	})
	WorldHistory.register_subject(captain_id, {
		"name": captain_name, "kind": "person", "role": captain_role,
		"faction": faction_name, "faction_id": faction_id, "elo": 1000,
		"grudge": 0, "status": "active", "memory": memory, "wounds": [],
		"anatomy": {"blood_type": blood_type, "cybernetics": cybernetics},
		"relations": {faction_id: {"kind": "command", "strength": 50}},
	})
