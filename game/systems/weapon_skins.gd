class_name WeaponSkins
extends RefCounted

## Skins for what you hold and wear (Greg, 24 September: "a csgo case type
## thing with gun and knife skin raritys with gold being the 0.01%").
##
## A skin is a finish for one particular thing -- the MERCY NINE, the ASHLINE
## CLEAVER, the breach ram, one jester part -- painted by `skin_pattern.gdshader`
## rather than from a texture file, so every drop carries its own pattern seed
## and no two are the same. Each one also carries a wear value that it rolled
## when it was minted and that keeps rising while you use it: fighting scuffs
## and bloods a skin, and a clean one sells for more (`SkinMarket`).
##
## Skins are items in `Carry` (kind "skin"). Applying one paints the matching
## weapon or garment; taking it off returns the item. Nothing here rolls dice:
## `SkinCase` decides which skin a case gives, this file says what it is.

const SHADER := preload("res://systems/skin_pattern.gdshader")

## The rarity ladder, CS-shaped and in the game's own words. Weights are per
## ten thousand so gold is exactly one: 0.01%.
const TIERS := [
	{"id": "issue", "label": "FACILITY ISSUE", "weight": 7992, "ink": "b0b6ba"},
	{"id": "contraband", "label": "CONTRABAND", "weight": 1598, "ink": "4b8bd8"},
	{"id": "restricted", "label": "RESTRICTED", "weight": 320, "ink": "8a55d8"},
	{"id": "covert", "label": "COVERT", "weight": 63, "ink": "d0409a"},
	{"id": "relic", "label": "RELIC", "weight": 26, "ink": "e0321e"},
	{"id": "gold", "label": "GOLD", "weight": 1, "ink": "e4b43a"},
]

## Wear, as CS names its float bands, in the facility's words.
const WEAR_BANDS := [
	{"below": 0.07, "label": "VAT FRESH", "short": "VF", "value": 1.6},
	{"below": 0.15, "label": "LIGHTLY HANDLED", "short": "LH", "value": 1.25},
	{"below": 0.38, "label": "FIELD WORN", "short": "FW", "value": 1.0},
	{"below": 0.45, "label": "WELL WORN", "short": "WW", "value": 0.8},
	{"below": 1.01, "label": "BATTLE SCARRED", "short": "BS", "value": 0.62},
]

## What each finish number in the shader is.
const FINISHES := {
	"camo": 0, "fade": 1, "marble": 2, "case_hardened": 3, "blood_rust": 4,
	"circuit": 5, "bone_inlay": 6, "gold": 7, "motley": 8, "tiger": 9,
}

## What a target is, and its name on the skin. Guns and blades are the Hunt's
## arsenal ids; "ram" is the breach tool; cloth targets are `Outfit` parts.
const TARGETS := {
	"sidearm": {"label": "MERCY NINE", "class": "gun"},
	"facility_sidearm": {"label": "BREACH NINE", "class": "gun"},
	"shotgun": {"label": "BONE YARD 12G", "class": "gun"},
	"sniper": {"label": "ASHLINE LONGVIEW", "class": "gun"},
	"sword": {"label": "ASHLINE CLEAVER", "class": "blade"},
	"ram": {"label": "BREACH RAM", "class": "ram"},
	"jester_cap": {"label": "BELLED CAP", "class": "cloth"},
	"jester_doublet": {"label": "RUFF AND DOUBLET", "class": "cloth"},
	"jester_sleeves": {"label": "GLOVES AND SLEEVES", "class": "cloth"},
	"jester_hose": {"label": "PANTALOONS AND SHOES", "class": "cloth"},
}

## Every skin. `colors` are base, accent, third; `wear` is the range a mint can
## roll (fades only come clean, as in CS).
const SKINS := {
	# --- facility issue ------------------------------------------------------
	"sidearm_dry_falls": {"target": "sidearm", "name": "DRY FALLS CAMO", "tier": "issue", "finish": "camo", "colors": ["5c4a38", "7d6446", "2e2620"]},
	"shotgun_scrap_primer": {"target": "shotgun", "name": "SCRAP PRIMER", "tier": "issue", "finish": "camo", "colors": ["4a4d4f", "7a2a20", "2b2c2d"]},
	"sword_field_grey": {"target": "sword", "name": "FIELD GREY", "tier": "issue", "finish": "camo", "colors": ["55595b", "3c4042", "6e7274"]},
	"ram_hazard": {"target": "ram", "name": "HAZARD STRIPE", "tier": "issue", "finish": "tiger", "colors": ["2a2a2a", "d8a21e", "1a1a1a"]},
	"jester_cap_sackcloth": {"target": "jester_cap", "name": "SACKCLOTH", "tier": "issue", "finish": "camo", "colors": ["6b6257", "8a7f6c", "4a453c"]},
	"jester_hose_ash": {"target": "jester_hose", "name": "ASH MOTLEY", "tier": "issue", "finish": "motley", "colors": ["3b3a38", "6d6a64", "222"]},
	# --- contraband ------------------------------------------------------------
	"sidearm_ossuary": {"target": "sidearm", "name": "OSSUARY", "tier": "contraband", "finish": "bone_inlay", "colors": ["d9c7a0", "d9c7a0", "1c1512"]},
	"sniper_carrion_tiger": {"target": "sniper", "name": "CARRION TIGER", "tier": "contraband", "finish": "tiger", "colors": ["3a2a1e", "b8691e", "1a1410"]},
	"shotgun_blood_rust": {"target": "shotgun", "name": "BLOOD RUST", "tier": "contraband", "finish": "blood_rust", "colors": ["5a5f62", "b0201a", "6a3a1e"]},
	"sword_rib_cage": {"target": "sword", "name": "RIB CAGE", "tier": "contraband", "finish": "bone_inlay", "colors": ["e2d3b0", "e2d3b0", "3a0d0b"]},
	"jester_doublet_wine": {"target": "jester_doublet", "name": "WINE MOTLEY", "tier": "contraband", "finish": "motley", "colors": ["5a1030", "d9c7a0", "222"]},
	"jester_sleeves_bone_blood": {"target": "jester_sleeves", "name": "BONE AND BLOOD", "tier": "contraband", "finish": "motley", "colors": ["cfc2a4", "8a1a1a", "222"]},
	# --- restricted ------------------------------------------------------------
	"facility_sidearm_wetwire": {"target": "facility_sidearm", "name": "WETWIRE", "tier": "restricted", "finish": "circuit", "colors": ["101a1c", "3fe0c8", "0a0f10"]},
	"sword_abattoir_marble": {"target": "sword", "name": "ABATTOIR MARBLE", "tier": "restricted", "finish": "marble", "colors": ["d8d2cc", "7a1418", "2a0808"]},
	"ram_case_hardened": {"target": "ram", "name": "CASE HARDENED", "tier": "restricted", "finish": "case_hardened", "colors": ["8a8478", "2a4fa8", "b8902a"]},
	"jester_cap_wetwire": {"target": "jester_cap", "name": "WETWIRE", "tier": "restricted", "finish": "circuit", "colors": ["141c1e", "3fe0c8", "0a0f10"]},
	# --- covert ----------------------------------------------------------------
	"sidearm_celloutz_fade": {"target": "sidearm", "name": "CELLOUTZ FADE", "tier": "covert", "finish": "fade", "colors": ["dc5827", "e0321e", "278f87"], "wear": [0.0, 0.08]},
	"shotgun_case_hardened": {"target": "shotgun", "name": "CASE HARDENED", "tier": "covert", "finish": "case_hardened", "colors": ["8a8478", "2a4fa8", "b8902a"]},
	"sword_slaughter": {"target": "sword", "name": "SLAUGHTER", "tier": "covert", "finish": "blood_rust", "colors": ["b8bcc0", "e0321e", "7a1010"]},
	"jester_doublet_fade": {"target": "jester_doublet", "name": "CELLOUTZ FADE", "tier": "covert", "finish": "fade", "colors": ["dc5827", "5a1030", "278f87"], "wear": [0.0, 0.08]},
	# --- relic -----------------------------------------------------------------
	"sniper_frequency_fade": {"target": "sniper", "name": "FREQUENCY FADE", "tier": "relic", "finish": "fade", "colors": ["ff354b", "b98ad8", "5be8ff"], "wear": [0.0, 0.08]},
	"sword_first_frequency": {"target": "sword", "name": "FIRST FREQUENCY", "tier": "relic", "finish": "circuit", "colors": ["0a1420", "5be8ff", "050a10"]},
	"jester_hose_oil_slick": {"target": "jester_hose", "name": "OIL SLICK", "tier": "relic", "finish": "case_hardened", "colors": ["1d1a2a", "2a8fa8", "a82a8f"]},
	# --- gold: one in ten thousand ----------------------------------------------
	"sword_saints_tooth": {"target": "sword", "name": "SAINT'S TOOTH", "tier": "gold", "finish": "gold", "colors": ["d9a52a", "7a5310", "f4d27a"], "wear": [0.0, 0.8]},
	"sidearm_midas_nine": {"target": "sidearm", "name": "MIDAS NINE", "tier": "gold", "finish": "gold", "colors": ["e4b43a", "8a5a14", "f4d27a"], "wear": [0.0, 0.8]},
	"facility_sidearm_gilded_case": {"target": "facility_sidearm", "name": "GILDED CASE HARDENED", "tier": "gold", "finish": "case_hardened", "colors": ["d9a52a", "2a4fa8", "f4d27a"], "wear": [0.0, 0.8]},
}


static func tier(tier_id: String) -> Dictionary:
	for entry: Dictionary in TIERS:
		if entry.id == tier_id:
			return entry
	return TIERS[0]


static func tier_rank(tier_id: String) -> int:
	for index in TIERS.size():
		if TIERS[index].id == tier_id:
			return index
	return 0


static func wear_band(wear: float) -> Dictionary:
	for band: Dictionary in WEAR_BANDS:
		if wear < float(band.below):
			return band
	return WEAR_BANDS[WEAR_BANDS.size() - 1]


static func skins_for(target_class: String) -> Array:
	var found: Array = []
	for skin_id: String in SKINS:
		if str(TARGETS[SKINS[skin_id].target]["class"]) == target_class:
			found.append(skin_id)
	return found


## The display name: "MERCY NINE | CELLOUTZ FADE", starred when it is gold.
static func display_name(skin_id: String) -> String:
	var skin: Dictionary = SKINS.get(skin_id, {})
	if skin.is_empty():
		return "UNKNOWN FINISH"
	var star := "★ " if str(skin.tier) == "gold" else ""
	return "%s | %s%s" % [str(TARGETS[skin.target].label), star, str(skin.name)]


## A new skin as a Carry item. `wear01` places the wear inside the skin's own
## range; `seed` is the pattern seed (0..999).
static func mint(skin_id: String, wear01: float, seed: int) -> Dictionary:
	var skin: Dictionary = SKINS.get(skin_id, {})
	if skin.is_empty():
		return {}
	var span: Array = skin.get("wear", [0.0, 1.0])
	var wear := lerpf(float(span[0]), float(span[1]), clampf(wear01, 0.0, 1.0))
	return {
		"label": display_name(skin_id),
		"kind": "skin",
		"skin": skin_id,
		"target": str(skin.target),
		"tier": str(skin.tier),
		"wear": wear,
		"seed": clampi(seed, 0, 999),
		"blood": 0.0,
		"kills": 0,
		"mass": 0.02,
		"perishes": false,
		"age": 0.0,
	}


## The painted material for a skin item as it is now.
static func material_for(item: Dictionary) -> ShaderMaterial:
	var skin: Dictionary = SKINS.get(str(item.get("skin", "")), {})
	var material := ShaderMaterial.new()
	material.shader = SHADER
	if skin.is_empty():
		return material
	var colors: Array = skin.colors
	var is_cloth := str(TARGETS[skin.target]["class"]) == "cloth"
	material.set_shader_parameter("finish", int(FINISHES.get(str(skin.finish), 0)))
	material.set_shader_parameter("base_color", Color(str(colors[0])))
	material.set_shader_parameter("accent_color", Color(str(colors[1])))
	material.set_shader_parameter("third_color", Color(str(colors[2])))
	material.set_shader_parameter("pattern_seed", float(item.get("seed", 0)))
	material.set_shader_parameter("wear", float(item.get("wear", 0.0)))
	material.set_shader_parameter("blood", float(item.get("blood", 0.0)))
	material.set_shader_parameter("cloth", is_cloth)
	material.set_shader_parameter("metal", 0.0 if is_cloth else 0.8)
	material.set_shader_parameter("gloss", 0.1 if is_cloth else 0.45)
	material.set_shader_parameter("bare_color", Color("3b342c") if is_cloth else Color("8e9296"))
	# Cloth patterns are laid out at body scale, metal at weapon scale.
	material.set_shader_parameter("pattern_scale", 7.0 if is_cloth else 16.0)
	return material


## Paint every mesh under `root` with the skin, except the hands holding it.
## Returns how many surfaces took the finish.
static func apply_to(root: Node, item: Dictionary) -> int:
	if root == null:
		return 0
	var material := material_for(item)
	material.set_shader_parameter("span", _longest_side(root))
	return _paint(root, material)


static func _longest_side(node: Node) -> float:
	var longest := 0.0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var box := (node as MeshInstance3D).mesh.get_aabb()
		longest = maxf(box.size.x, maxf(box.size.y, box.size.z)) + (node as Node3D).position.length()
	for child in node.get_children():
		longest = maxf(longest, _longest_side(child))
	return maxf(longest, 0.1)


static func _paint(node: Node, material: Material) -> int:
	var name_ := str(node.name).to_lower()
	if name_.contains("hand") or name_.contains("finger") or name_.contains("thumb") or name_.contains("palm"):
		return 0
	var count := 0
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
		count += 1
	for child in node.get_children():
		count += _paint(child, material)
	return count


## Use wears a skin. A swing, a shot, a hit: `amount` of wear, and blood when
## it went into somebody. Returns the item's new wear.
static func scuff(item: Dictionary, amount: float, bloodied := 0.0, killed := false) -> float:
	item["wear"] = clampf(float(item.get("wear", 0.0)) + maxf(amount, 0.0), 0.0, 1.0)
	item["blood"] = clampf(float(item.get("blood", 0.0)) + maxf(bloodied, 0.0), 0.0, 1.0)
	if killed:
		item["kills"] = int(item.get("kills", 0)) + 1
	return float(item.wear)
