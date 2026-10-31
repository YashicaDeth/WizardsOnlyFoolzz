extends RefCounted

## One way into everything breakable (Greg, 24 September: destruction physics
## first; `DESIGN/GOAL_LOOP_2.md` 0.1, bullets and blades break things).
##
## Before this, each breakable spoke its own language and only the scene that
## built one could hit it: a streetlight took a 0..1 amount, a barricade a
## closing speed, a door a weapon name. A round or a blow that met the world
## just left a scar. Now any caller hands in what hit (the collider) and how
## hard (the weapon's own damage number: a pistol round about 24, the
## cleaver 44), and this finds the breakable that owns the collider and
## speaks its language. Each hit is filed in WorldHistory.

## Streetlights and anything else on `WorldDamage`'s 0..1 condition.
const CONDITION_PER_DAMAGE := 0.01
## Barricades, crates and other `BreakableProp`s take the damage directly.
const PROP_PER_DAMAGE := 0.6


## `weapon` is the arsenal id or kind; `kind` is "firearm" or "melee".
static func hit(collider: Object, damage: float, cause: String, point: Vector3, direction: Vector3, weapon := "", kind := "melee") -> Dictionary:
	if collider == null or damage <= 0.0:
		return {}
	var door := BreakableDoor.door_of(collider)
	if door != null:
		var result: Dictionary = door.hit(door_weapon(weapon, kind), point, direction)
		return _filed(result, "door", door.door_id, cause, weapon)
	var node := collider as Node
	for _depth in 6:
		if node == null:
			break
		if node is BreakableProp:
			var prop := node as BreakableProp
			# Filed under its own name, so the record says which crate, not "a crate".
			var struck := prop.strike(damage * PROP_PER_DAMAGE, direction)
			struck["kind"] = prop.kind
			return _filed(struck, "prop", str(prop.name), cause, weapon)
		if node.has_method("strike") and node.get("subject_id") != null:
			var result: Dictionary = node.strike(damage * CONDITION_PER_DAMAGE, cause, direction)
			return _filed(result, "object", str(node.get("subject_id")), cause, weapon)
		node = node.get_parent()
	return {}


## What a door understands: a gun is a gun, a heavy blade is an axe, bare
## hands are a body, and anything else is the restraint's blunt metal.
static func door_weapon(weapon: String, kind: String) -> String:
	if kind == "firearm":
		return "gun"
	if weapon in ["sword", "cleaver", "axe", "breach_tool", "machete"]:
		return "axe"
	if weapon in ["", "fists", "unarmed", "body"]:
		return "body"
	return "restraint"


static func _filed(result: Dictionary, what: String, id: String, cause: String, weapon: String) -> Dictionary:
	if result.is_empty():
		return result
	var out := result.duplicate()
	out["what"] = what
	out["id"] = id
	WorldHistory.record_event("world_object_struck", {
		"what": what, "id": id, "kind": str(out.get("kind", what)), "cause": cause, "weapon": weapon,
		"broke": bool(out.get("broken", false)) or str(out.get("band", "")) in ["sparking", "hanging"] or not str(out.get("broke", "")).is_empty(),
	})
	return out


## A blow from the player's eye: whatever the held tool meets within `reach`,
## if it breaks. The facility scenes have no melee of their own, only a ram on
## the attack button, so this is how that blow reaches a crate there.
static func swing(camera: Camera3D, damage: float, weapon: String, holder: CollisionObject3D = null, reach := 2.4) -> Dictionary:
	if camera == null or not camera.is_inside_tree():
		return {}
	var from := camera.global_position
	var direction := -camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach)
	if holder != null:
		query.exclude = [holder.get_rid()]
	var met := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if met.is_empty():
		return {}
	return hit(met.collider, damage, "melee", met.position, direction, weapon, "melee")
