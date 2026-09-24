class_name LootCase
extends RefCounted

## Digital cases from the dead cloud: a slot-machine box that sells the archive
## back to you one spin at a time. The fiction earns the mechanic — fragments
## are repaired, not unlocked, and a case is somebody's unfinished restoration
## sold as-is, contents unknown even to the seller.
##
## The roll is pure and the randomness stays outside it: `open()` takes the
## caller's 0..1 draw, so the distribution is exactly testable and no part of
## the game has to mock a dice service. Weights are per hundred, human
## readable, and sum-checked at roll time rather than trusted.
##
## Gold is 1 in 100 by construction, not by feel. The tiers below pay in the
## currencies the game already runs on — scrip, rounds, cloth patches — so a
## case never invents a second economy beside the rust-scrip one.

const TIERS := [
	{"id": "scrap", "weight": 60.0, "label": "SCRAP"},
	{"id": "useful", "weight": 25.0, "label": "USEFUL"},
	{"id": "rare", "weight": 10.0, "label": "RARE"},
	{"id": "relic", "weight": 4.0, "label": "RELIC"},
	{"id": "gold", "weight": 1.0, "label": "GOLD"},
]

## What each tier can hold. `kind` is one of: scrip, ammo, patch, implant.
## Amounts are ranges, rolled from the same draw so one number opens one box.
const LOOT := {
	"scrap": [{"kind": "scrip", "low": 2, "high": 8}, {"kind": "ammo", "low": 4, "high": 12}],
	"useful": [{"kind": "scrip", "low": 10, "high": 25}, {"kind": "patch", "low": 1, "high": 2}, {"kind": "ammo", "low": 12, "high": 30}],
	"rare": [{"kind": "implant", "low": 1, "high": 1}, {"kind": "scrip", "low": 30, "high": 60}, {"kind": "patch", "low": 2, "high": 4}],
	"relic": [{"kind": "implant", "low": 1, "high": 2}, {"kind": "scrip", "low": 60, "high": 120}],
	"gold": [{"kind": "gold", "low": 1, "high": 1}],
}

const CASES := {
	"celloutz_cache": {"price": 25, "label": "CELLOUTZ CACHE"},
	"choir_tithe": {"price": 60, "label": "CHOIR TITHE"},
}

## What one gold pays, in scrip, straight to the wallet. A flat fortune rather
## than an item, so gold never needs a price table of its own to feel golden.
const GOLD_VALUE := 200


## Which tier a 0..1 draw buys. Boundaries are cumulative weight over the
## total, so the table stays honest if anyone retunes a number.
static func tier_for(draw: float) -> String:
	var total := 0.0
	for tier: Dictionary in TIERS:
		total += float(tier.weight)
	var cursor := clampf(draw, 0.0, 0.999999) * total
	var running := 0.0
	for tier: Dictionary in TIERS:
		running += float(tier.weight)
		if cursor < running:
			return str(tier.id)
	return "scrap"


## Open a case. Returns the receipt: case, tier, kind, amount, and price paid.
## Refuses unknown cases and unpaid boxes rather than rolling anyway.
static func open(case_id: String, draw: float, paid: bool) -> Dictionary:
	if not CASES.has(case_id):
		return {"ok": false, "reason": "NO SUCH CASE"}
	if not paid:
		return {"ok": false, "reason": "UNPAID"}
	var tier := tier_for(draw)
	var options: Array = LOOT.get(tier, [])
	if options.is_empty():
		return {"ok": false, "reason": "EMPTY TIER"}
	# Scattered off the draw rather than read straight from it: the tier is
	# decided by which band the draw lands in, so reading the pick from the raw
	# draw would pin whole options shut — relic would pay scrip forever and
	# never its implant. One number still opens one box.
	var scatter := fposmod(draw * 13.0, 1.0)
	var pick: Dictionary = options[floori(scatter * float(options.size())) % options.size()]
	var span := int(pick.high) - int(pick.low) + 1
	var amount := int(pick.low) + floori(scatter * 7.0 * float(span)) % span
	return {
		"ok": true,
		"case": case_id,
		"label": str(CASES[case_id].label),
		"tier": tier,
		"kind": str(pick.kind),
		"amount": amount,
		"price": int(CASES[case_id].price),
	}
