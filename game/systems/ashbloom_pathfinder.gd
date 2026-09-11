extends RefCounted

const CELL := 2.0
const ORIGIN := Vector2(-234, -184)
var grid := AStarGrid2D.new()

func build(lots: Array) -> void:
	grid.region = Rect2i(0, 0, 235, 185)
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = ORIGIN
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for lot: Rect2 in lots:
		var expanded := lot.grow(1.0)
		var first := cell(expanded.position)
		var last := cell(expanded.end)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				grid.set_point_solid(Vector2i(x, y))

func cell(point: Vector2) -> Vector2i:
	var result := Vector2i(((point - ORIGIN) / CELL).round())
	return Vector2i(clampi(result.x, 0, 234), clampi(result.y, 0, 184))

func clear_cell(point: Vector2) -> Vector2i:
	var start := cell(point)
	if not grid.is_point_solid(start):
		return start
	for radius in range(1, 15):
		for x in range(-radius, radius + 1):
			for y in [-radius, radius]:
				var candidate := start + Vector2i(x, y)
				if grid.region.has_point(candidate) and not grid.is_point_solid(candidate):
					return candidate
		for y in range(-radius + 1, radius):
			for x in [-radius, radius]:
				var candidate := start + Vector2i(x, y)
				if grid.region.has_point(candidate) and not grid.is_point_solid(candidate):
					return candidate
	return start

func safe_position(point: Vector3) -> Vector3:
	var id := clear_cell(Vector2(point.x, point.z))
	var p := grid.get_point_position(id)
	return Vector3(p.x, point.y, p.y)

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	return grid.get_point_path(clear_cell(Vector2(from.x, from.z)), clear_cell(Vector2(to.x, to.z)))
