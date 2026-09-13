class_name RitualApp
extends RefCounted

## E3. "The camera is the ritual instrument... rituals are completed by
## photographing evidence... you are sent to do something, and you have to
## bring back a picture of it." — DESIGN/RITUAL_AND_KARMA.md, citing Greg's
## own worked example: kill five people and photograph their gored heads.
##
## E3.2 ("verify the photograph against real anatomy") reuses the exact photo
## shape `wire_net.gd`'s `publish_photograph()` already defined and verifies
## — `contents: [{subject_id, severed: [...], ruptured: [...], dead: bool}]`
## — rather than inventing a second one. `_photo_matches()` is a read of that
## same contract; nothing here decides what counts as evidence a second way.
##
## E3.3 ("never a confirm button"): there is no function that grants a rite's
## reward without a `photo` argument that actually satisfies the
## requirement — the photograph is the only door in.
##
## Rewards are `boons.gd` grants, on purpose: DESIGN/RITUAL_AND_KARMA.md's own
## mapping puts "the demonic sigil ritual app" on the Descent route, "boons
## are always temporary and paid in the body" — E2/E3 and E4 are one system,
## not two, so a rite pays through the same ledger a drug or a boost does,
## and free of charge inherits E4.3's escalating price on repeat.
##
## Every rite is keyed to a real seal from `goetic_seals.gd` — a name and
## rank already verified against a primary source, or an original seal
## already tied to a real faction — never a rite invented with no seal
## standing behind it.

const RITUALS := {
	"rite_of_bael": {
		"seal": "Bael", "label": "The First Rite",
		"requirement": {"kind": "dead_count", "count": 1},
		"stat": "pain_resist", "magnitude": 0.25, "duration": 90.0,
		"cost_kind": "blood", "cost_amount": 260.0,
	},
	"rite_of_paimon": {
		"seal": "Paimon", "label": "The Rite of Revealed Names",
		"requirement": {"kind": "severed_count", "count": 3},
		"stat": "combat_power", "magnitude": 0.35, "duration": 90.0,
		"cost_kind": "organ", "cost_amount": 5.0, "cost_target": "liver",
	},
	"rite_of_the_filed_tooth": {
		"seal": "The Filed Tooth", "label": "The Choir's Own Rite",
		"requirement": {"kind": "gored_heads", "count": 5},
		"stat": "combat_power", "magnitude": 0.6, "duration": 120.0,
		"cost_kind": "limb", "cost_amount": 14.0, "cost_target": "left_arm",
	},
}


static func _photo_matches(photo: Dictionary, requirement: Dictionary) -> bool:
	var contents: Array = photo.get("contents", [])
	var required := int(requirement.get("count", 1))
	match str(requirement.get("kind", "")):
		"dead_count":
			var count := 0
			for entry in contents:
				if bool((entry as Dictionary).get("dead", false)):
					count += 1
			return count >= required
		"severed_count":
			var count := 0
			for entry in contents:
				count += ((entry as Dictionary).get("severed", []) as Array).size()
			return count >= required
		"gored_heads":
			var count := 0
			for entry in contents:
				var record: Dictionary = entry
				if not bool(record.get("dead", false)):
					continue
				# `field_camera.gd` writes three separate lists into every
				# photographed record - severed, destroyed and ruptured - and
				# this only ever read two of them. A head blown apart lands in
				# `destroyed`, not `severed`, so the most obviously gored head
				# in the game did not count toward the Choir's own rite, while
				# `ritual_ledger.gd` - which asks the camera the same question
				# through `{"zone": "head", "state": "destroyed"}` - counted it.
				# The two halves of E3/E4 disagreed about what gored means.
				var severed: Array = record.get("severed", [])
				var ruptured: Array = record.get("ruptured", [])
				var destroyed: Array = record.get("destroyed", [])
				var gored := false
				for part in ["head", "brain"]:
					if severed.has(part) or ruptured.has(part) or destroyed.has(part):
						gored = true
				if gored:
					count += 1
			return count >= required
	return false


## E2.6/E2.7. Whether this casting binds the seal (a circuit completed,
## drawn additively — `Motherboard.begin_bind()`) or burns it (a scar,
## drawn subtractively — `Motherboard.begin_burn()`), and the one input that
## decides it: `taken`, the exact same repeat count `Boons.grant()` already
## keeps to price a repeat higher (E4.3). A first casting is always clean —
## the escalating cost is the whole point of E4.3, and burning it on the
## second use would never let that cost matter. After that the risk climbs
## with every repeat, seeded so the same casting count answers the same way
## twice, until a burnt seal stops answering at all (below).
static func _decide_outcome(ritual_id: String, subject_id: String, taken: int) -> String:
	if taken <= 0:
		return "bind"
	var burn_chance := clampf(float(taken) * 0.18, 0.0, 0.85)
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(ritual_id + subject_id) + taken) & 0x7fffffff
	return "burn" if rng.randf() < burn_chance else "bind"


## The only door in. `photo` must be the same dictionary shape a real
## in-world photograph produces; there is no path here that grants a reward
## without one that actually satisfies `requirement`.
static func attempt(ritual_id: String, photo: Dictionary, subject_id: String = "player") -> Dictionary:
	if not RITUALS.has(ritual_id):
		return {"ok": false, "reason": "NO SUCH RITE"}
	var subject := WorldHistory.subject(subject_id)
	# E2.7. "A burnt one is gone for the run" — a permanent refusal, not
	# merely a costlier repeat.
	var burnt: Array = (subject.get("burnt_rituals", []) as Array).duplicate()
	if burnt.has(ritual_id):
		return {"ok": false, "reason": "THIS SEAL IS BURNT. IT WILL NOT ANSWER YOU AGAIN.", "outcome": "burnt"}
	var rite: Dictionary = RITUALS[ritual_id]
	if not _photo_matches(photo, rite.requirement):
		return {"ok": false, "reason": "THE PHOTOGRAPH DOES NOT SHOW WHAT THE RITE ASKS FOR"}
	var taken := int((subject.get("boon_history", {}) as Dictionary).get(ritual_id, 0))
	var outcome := _decide_outcome(ritual_id, subject_id, taken)
	var granted := Boons.grant(
		subject_id, ritual_id, str(rite.stat), float(rite.magnitude), float(rite.duration),
		str(rite.cost_kind), float(rite.cost_amount), str(rite.get("cost_target", "")),
	)
	if not bool(granted.get("ok", false)):
		return granted
	WorldHistory.record_event("ritual_completed", {"subject_id": subject_id, "ritual_id": ritual_id, "seal": str(rite.seal), "outcome": outcome})
	if outcome == "burn":
		burnt.append(ritual_id)
		WorldHistory.update_subject(subject_id, {"burnt_rituals": burnt}, "seal_burnt")
	return {"ok": true, "ritual_id": ritual_id, "seal": str(rite.seal), "cost_paid": granted.cost_paid, "outcome": outcome}
