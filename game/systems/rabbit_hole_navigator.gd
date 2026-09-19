class_name RabbitHoleNavigator
extends RefCounted

## Typed, reversible navigation shared by the Pyramid, Wire and physical tools.
## This stores references, not copied subject/site data. Presentation layers are
## responsible for resolving a route against the canonical service that owns it.

signal route_changed(route: Dictionary, direction: String)

const ROOTS := ["pyramid", "wire", "body", "inventory", "map", "radio", "memory"]
const KINDS := [
	"root", "subject", "dossier", "evidence", "post", "account", "site",
	"relationship", "body_part", "item", "memory", "keyword", "place",
	"frequency", "signal", "quest", "grave"
]

var _trail: Array[Dictionary] = []
var _cursor := -1


func follow(kind: String, id: String, root: String, context: Dictionary = {}) -> Dictionary:
	var route := _normalise({
		"kind": kind,
		"id": id,
		"root": root,
		"context": context,
	})
	if route.is_empty():
		return {}
	if _cursor + 1 < _trail.size():
		_trail.resize(_cursor + 1)
	if not _trail.is_empty() and _same_destination(_trail.back(), route):
		_trail[_trail.size() - 1] = route
	else:
		_trail.append(route)
	_cursor = _trail.size() - 1
	route_changed.emit(route.duplicate(true), "deeper")
	return route.duplicate(true)


func back() -> Dictionary:
	if _cursor <= 0:
		return {}
	_cursor -= 1
	var route := current()
	route_changed.emit(route, "back")
	return route


func forward() -> Dictionary:
	if _cursor < 0 or _cursor + 1 >= _trail.size():
		return {}
	_cursor += 1
	var route := current()
	route_changed.emit(route, "forward")
	return route


func current() -> Dictionary:
	if _cursor < 0 or _cursor >= _trail.size():
		return {}
	return _trail[_cursor].duplicate(true)


func breadcrumbs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(_cursor + 1):
		result.append(_trail[index].duplicate(true))
	return result


func clear() -> void:
	_trail.clear()
	_cursor = -1


func snapshot() -> Dictionary:
	return {"version": 1, "cursor": _cursor, "trail": _trail.duplicate(true)}


func restore(data: Dictionary) -> Dictionary:
	clear()
	var restored: Array = data.get("trail", [])
	for candidate in restored:
		if candidate is Dictionary:
			var route := _normalise(candidate)
			if not route.is_empty():
				_trail.append(route)
	if _trail.is_empty():
		return {}
	_cursor = clampi(int(data.get("cursor", _trail.size() - 1)), 0, _trail.size() - 1)
	var route := current()
	route_changed.emit(route, "restore")
	return route


func _normalise(candidate: Dictionary) -> Dictionary:
	var kind := str(candidate.get("kind", "")).strip_edges().to_lower()
	var id := str(candidate.get("id", "")).strip_edges()
	var root := str(candidate.get("root", "")).strip_edges().to_lower()
	if not KINDS.has(kind) or id == "" or not ROOTS.has(root):
		return {}
	var context_value = candidate.get("context", {})
	var context: Dictionary = context_value if context_value is Dictionary else {}
	return {
		"kind": kind,
		"id": id,
		"root": root,
		"context": context.duplicate(true),
	}


func _same_destination(left: Dictionary, right: Dictionary) -> bool:
	return left.get("kind") == right.get("kind") \
		and left.get("id") == right.get("id") \
		and left.get("root") == right.get("root")

