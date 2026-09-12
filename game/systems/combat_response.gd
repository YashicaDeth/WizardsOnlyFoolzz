class_name CombatResponse
extends RefCounted

## Converts a body's real condition and the force of a real hit into combat
## cadence. This is deliberately not health-based poise: pain, ruined legs and
## missing arms make somebody easier to interrupt because their body changed.

const STAGGER_THRESHOLD := 24.0

static func from_hit(attack: Dictionary, anatomy: AnatomyComponent, hit: Dictionary) -> Dictionary:
	var force := float(attack.get("impulse", 0.0))
	var pain := float(hit.get("pain", anatomy.pain))
	var footing_loss := (1.0 - anatomy.mobility_ratio()) * 18.0
	var guard_loss := (1.0 - anatomy.combat_ratio()) * 12.0
	var severity := force * (1.25 if bool(attack.get("heavy", false)) else 0.72) + pain * 0.16 + footing_loss + guard_loss
	var staggered := severity >= STAGGER_THRESHOLD and not anatomy.dead and not anatomy.downed
	return {
		"staggered": staggered,
		"severity": snappedf(severity, 0.1),
		"duration": clampf(0.22 + (severity - STAGGER_THRESHOLD) * 0.018, 0.22, 1.05) if staggered else 0.0,
		"interrupts_attack": staggered,
	}
