extends Node
## Greg's playtest: every way out comes up in its own area, and the first
## run's side exits stay shut until you have escaped once.

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	WorldHistory.clear_history()
	var spots := {}
	for id: String in FacilityRoutes.ROUTES:
		var route: Dictionary = FacilityRoutes.ROUTES[id]
		if route.has("surface_position"):
			spots[id] = route.surface_position
		for outcome: String in route.get("outcomes", {}):
			spots["%s/%s" % [id, outcome]] = route.outcomes[outcome].surface_position
	var ids := spots.keys()
	for a in ids.size():
		for b in range(a + 1, ids.size()):
			var gap: float = (spots[ids[a]] as Vector3).distance_to(spots[ids[b]])
			check(gap >= 40.0, "%s and %s surface %.0f m apart" % [ids[a], ids[b], gap])
	for id in ids:
		var at: Vector3 = spots[id]
		check(absf(at.x) < 225.0 and absf(at.z) < 175.0, "%s comes up on the ground" % id)
	check(not FacilityRoutes.escaped_once(), "a fresh world has not escaped")
	WorldHistory.amend_subject(FacilityRoutes.SUBJECT, {"completed_routes": [FacilityRoutes.ROUTE_HEAT_ELEVATOR]})
	check(FacilityRoutes.escaped_once(), "after the heat elevator, the side exits open")
	print("ROUTE_SURFACING_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
