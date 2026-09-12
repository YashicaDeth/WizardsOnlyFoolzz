class_name GoeticSeals
extends RefCounted

## E2.2/E2.3. "The 72 seals of the Ars Goetia, from the Lesser Key of
## Solomon... this is 17th-century material and Mathers' 1904 edition is long
## out of copyright, so the seals themselves are free to use." —
## DESIGN/RITUAL_AND_KARMA.md. Per non-negotiable 1, only the *seals
## themselves* (the drawn glyphs) must be original code rather than pasted
## scans — the roster of names, ranks and traditional numbers is the actual
## public-domain original, verified against a primary reference rather than
## transcribed from memory, since a wrong name here would be citing the wrong
## source material for something the design explicitly permits using.
##
## Data only. No stroke geometry, no drawing — `celloutz_type.gd` (Agent A's
## file) owns the stroke vocabulary E2.1 asks for; `GOETIA` below is what it
## would eventually draw, in the order Mathers' edition lists it.
const GOETIA := [
	{"number": 1, "name": "Bael", "rank": "King"},
	{"number": 2, "name": "Agares", "rank": "Duke"},
	{"number": 3, "name": "Vassago", "rank": "Prince"},
	{"number": 4, "name": "Samigina", "rank": "Marquis"},
	{"number": 5, "name": "Marbas", "rank": "President"},
	{"number": 6, "name": "Valefor", "rank": "Duke"},
	{"number": 7, "name": "Amon", "rank": "Marquis"},
	{"number": 8, "name": "Barbatos", "rank": "Duke"},
	{"number": 9, "name": "Paimon", "rank": "King"},
	{"number": 10, "name": "Buer", "rank": "President"},
	{"number": 11, "name": "Gusion", "rank": "Duke"},
	{"number": 12, "name": "Sitri", "rank": "Prince"},
	{"number": 13, "name": "Beleth", "rank": "King"},
	{"number": 14, "name": "Leraje", "rank": "Marquis"},
	{"number": 15, "name": "Eligos", "rank": "Duke"},
	{"number": 16, "name": "Zepar", "rank": "Duke"},
	{"number": 17, "name": "Botis", "rank": "Count/President"},
	{"number": 18, "name": "Bathin", "rank": "Duke"},
	{"number": 19, "name": "Sallos", "rank": "Duke"},
	{"number": 20, "name": "Purson", "rank": "King"},
	{"number": 21, "name": "Morax", "rank": "Count/President"},
	{"number": 22, "name": "Ipos", "rank": "Count/Prince"},
	{"number": 23, "name": "Aim", "rank": "Duke"},
	{"number": 24, "name": "Naberius", "rank": "Marquis"},
	{"number": 25, "name": "Glasya-Labolas", "rank": "Count/President"},
	{"number": 26, "name": "Bune", "rank": "Duke"},
	{"number": 27, "name": "Ronove", "rank": "Marquis/Count"},
	{"number": 28, "name": "Berith", "rank": "Duke"},
	{"number": 29, "name": "Astaroth", "rank": "Duke"},
	{"number": 30, "name": "Forneus", "rank": "Marquis"},
	{"number": 31, "name": "Foras", "rank": "President"},
	{"number": 32, "name": "Asmodeus", "rank": "King"},
	{"number": 33, "name": "Gaap", "rank": "Prince/President"},
	{"number": 34, "name": "Furfur", "rank": "Count"},
	{"number": 35, "name": "Marchosias", "rank": "Marquis"},
	{"number": 36, "name": "Stolas", "rank": "Prince"},
	{"number": 37, "name": "Phenex", "rank": "Marquis"},
	{"number": 38, "name": "Halphas", "rank": "Count"},
	{"number": 39, "name": "Malphas", "rank": "President"},
	{"number": 40, "name": "Raum", "rank": "Count"},
	{"number": 41, "name": "Focalor", "rank": "Duke"},
	{"number": 42, "name": "Vepar", "rank": "Duke"},
	{"number": 43, "name": "Sabnock", "rank": "Marquis"},
	{"number": 44, "name": "Shax", "rank": "Marquis"},
	{"number": 45, "name": "Vine", "rank": "King/Count"},
	{"number": 46, "name": "Bifrons", "rank": "Count"},
	{"number": 47, "name": "Vual", "rank": "Duke"},
	{"number": 48, "name": "Haagenti", "rank": "President"},
	{"number": 49, "name": "Crocell", "rank": "Duke"},
	{"number": 50, "name": "Furcas", "rank": "Knight"},
	{"number": 51, "name": "Balam", "rank": "King"},
	{"number": 52, "name": "Alloces", "rank": "Duke"},
	{"number": 53, "name": "Caim", "rank": "President"},
	{"number": 54, "name": "Murmur", "rank": "Duke/Count"},
	{"number": 55, "name": "Orobas", "rank": "Prince"},
	{"number": 56, "name": "Gremory", "rank": "Duke"},
	{"number": 57, "name": "Ose", "rank": "President"},
	{"number": 58, "name": "Amy", "rank": "President"},
	{"number": 59, "name": "Orias", "rank": "Marquis"},
	{"number": 60, "name": "Vapula", "rank": "Duke"},
	{"number": 61, "name": "Zagan", "rank": "King/President"},
	{"number": 62, "name": "Valac", "rank": "President"},
	{"number": 63, "name": "Andras", "rank": "Marquis"},
	{"number": 64, "name": "Flauros", "rank": "Duke"},
	{"number": 65, "name": "Andrealphus", "rank": "Marquis"},
	{"number": 66, "name": "Kimaris", "rank": "Marquis"},
	{"number": 67, "name": "Amdusias", "rank": "Duke"},
	{"number": 68, "name": "Belial", "rank": "King"},
	{"number": 69, "name": "Decarabia", "rank": "Marquis"},
	{"number": 70, "name": "Seere", "rank": "Prince"},
	{"number": 71, "name": "Dantalion", "rank": "Duke"},
	{"number": 72, "name": "Andromalius", "rank": "Count"},
]


## E2.3. "The roster extends past the Goetia with original seals for things
## this world grew on its own." This world's own IP, not a real tradition's —
## the Choir of Marrow and Soft Rot Communion already exist and already have
## a register; CellOutz's is its own corporate one; the two entries under
## `wizardsonlyfoolz` are the "original counterparts rather than a mirrored
## seven" the Tree axis comment in `world_history.gd` already promised, tied
## to the two Ascent entities `ascent_entities.gd` actually built rather than
## invented fresh here.
const ORIGINAL := [
	{"id": "marrow_keeper", "name": "The Marrow-Keeper", "faction_id": "choir_of_marrow", "note": "Drawn on whatever bone is nearest when the surgeon starts talking."},
	{"id": "filed_tooth", "name": "The Filed Tooth", "faction_id": "choir_of_marrow", "note": "A lesser relic-seal; every convert files one tooth to a point and keeps the shaving."},
	{"id": "second_bloom", "name": "Cap of the Second Bloom", "faction_id": "soft_rot", "note": "Pressed into a fresh cap before it opens; the Communion reads the spore pattern that results."},
	{"id": "warranty_seal", "name": "The Warranty Seal", "faction_id": "celloutz", "note": "Stamped on every liability waiver. Nobody has ever successfully claimed against it."},
	{"id": "clear_frequency_mark", "name": "The Clear Frequency's Mark", "entity_id": "clear_frequency", "note": "Not drawn so much as tuned — the closest this order comes to a sigil is a hum held at one pitch."},
	{"id": "still_ledger_mark", "name": "The Still Ledger's Mark", "entity_id": "still_ledger", "note": "A column of tally marks that is never shown to add up to the same total twice."},
]


static func seal(number: int) -> Dictionary:
	for entry in GOETIA:
		if int(entry.number) == number:
			return entry
	return {}


static func by_name(name: String) -> Dictionary:
	var lowered := name.to_lower()
	for entry in GOETIA:
		if str(entry.name).to_lower() == lowered:
			return entry
	for entry in ORIGINAL:
		if str(entry.name).to_lower() == lowered or str(entry.id) == lowered:
			return entry
	return {}


static func original_for_faction(faction_id: String) -> Array:
	var out: Array = []
	for entry in ORIGINAL:
		if str(entry.get("faction_id", "")) == faction_id:
			out.append(entry)
	return out


static func original_for_entity(entity_id: String) -> Dictionary:
	for entry in ORIGINAL:
		if str(entry.get("entity_id", "")) == entity_id:
			return entry
	return {}
