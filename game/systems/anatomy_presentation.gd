class_name AnatomyPresentation
extends RefCounted

## AX1.6. "Explicit anatomy and the mosaic/censorship presentation are equally
## complete."
##
## The word the direction doc uses is **equally**, and it is the whole
## requirement. A mosaic option that is really "the explicit version with
## something missing" is the version this item exists to prevent -- the player
## who turns it on should get a deliberate presentation, not a punishment for
## choosing it.
##
## So parity is enforced rather than intended: every region the explicit mode
## renders has a mosaic treatment defined for it, and the test fails if one is
## ever added to one mode and not the other. You cannot add a body part to this
## game and quietly leave the censored build with a hole in it.
##
## The player emerges naked, wounded and helpless -- that is the scene, in both
## modes. Mosaic changes how it is shown, never whether it happened.

const SETTINGS_ID := "settings"
const MODES := ["EXPLICIT", "MOSAIC"]
const DEFAULT_MODE := "MOSAIC"

## Regions the explicit presentation renders in full.
const EXPLICIT_REGIONS := ["groin", "chest", "buttocks", "wounds_deep", "birth_scars"]

## The censored treatment for each, and none of them is "hide it". A mosaic
## that removes the wound removes the story of the wound; it pixelates the
## surface and keeps the shape, the blood and the fact of it.
const MOSAIC_TREATMENT := {
	"groin": {"cell": 14.0, "keeps_silhouette": true, "keeps_blood": false},
	"chest": {"cell": 12.0, "keeps_silhouette": true, "keeps_blood": true},
	"buttocks": {"cell": 14.0, "keeps_silhouette": true, "keeps_blood": false},
	# The deep wounds are the reason the mosaic cannot simply be a black bar:
	# AN6 spent a whole section making a wound an opening you can see into, and
	# the censored build still has to say "this person has been opened".
	"wounds_deep": {"cell": 9.0, "keeps_silhouette": true, "keeps_blood": true},
	"birth_scars": {"cell": 10.0, "keeps_silhouette": true, "keeps_blood": false},
}


static func mode() -> String:
	var chosen := str(WorldHistory.subject(SETTINGS_ID).get("anatomy_presentation", DEFAULT_MODE)).to_upper()
	return chosen if MODES.has(chosen) else DEFAULT_MODE


static func set_mode(next: String) -> String:
	var chosen := next.to_upper()
	if not MODES.has(chosen):
		return mode()
	WorldHistory.update_subject(SETTINGS_ID, {"anatomy_presentation": chosen}, "anatomy_presentation_set")
	return chosen


static func is_explicit() -> bool:
	return mode() == "EXPLICIT"


## What to do with one region under the current mode. An unknown region is a
## bug rather than a default: returning something plausible for a part nobody
## registered is how a censored build ends up showing something it should not.
static func treatment(region: String) -> Dictionary:
	if not EXPLICIT_REGIONS.has(region):
		return {"ok": false, "reason": "UNREGISTERED REGION"}
	if is_explicit():
		return {"ok": true, "mode": "EXPLICIT", "cell": 0.0, "keeps_silhouette": true, "keeps_blood": true}
	var censored: Dictionary = MOSAIC_TREATMENT.get(region, {})
	return {
		"ok": true,
		"mode": "MOSAIC",
		"cell": float(censored.get("cell", 12.0)),
		"keeps_silhouette": bool(censored.get("keeps_silhouette", true)),
		"keeps_blood": bool(censored.get("keeps_blood", false)),
	}


## Parity, as a function rather than a promise. Returns the regions that exist
## in one mode and not the other; an empty array is the contract holding.
static func parity_gaps() -> Array:
	var gaps: Array = []
	for region in EXPLICIT_REGIONS:
		if not MOSAIC_TREATMENT.has(region):
			gaps.append(region)
	for region in MOSAIC_TREATMENT.keys():
		if not EXPLICIT_REGIONS.has(region):
			gaps.append(str(region))
	return gaps
