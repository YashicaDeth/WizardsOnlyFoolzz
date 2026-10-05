extends Node3D

## The service artery and its side tunnels on 0C, built from the tunnel kit
## (systems/facility_tunnel_kit.gd) on the 4 m grid of DESIGN/FACILITY.md.
## Part of facility.tscn: no scene change anywhere in it.
##
## Assistant layout (positions can move; no story attached): the artery runs
## east from the Growing Floor's staff door through a crossroads and a sliding
## door to the Service Arcade's west wall. Side tunnels off the crossroads end
## in a vent grate (south) and, north past a pipe run, a T to a bulkhead (west)
## and a corner to a second vent (east). Lamps alternate with dark cells:
## pools of light, not an evenly lit corridor.

const KIT := preload("res://systems/facility_tunnel_kit.gd")

## Facility-frame centre of cell (0, 0): the artery's first cell east of the
## staff door. Cells step 4 m in +X (i) and +Z (j).
const ORIGIN := Vector3(10.75, 0.0, -2.5)

## {cell: [kind, open sides, lamp energy, reach]}
const LAYOUT := {
	Vector2i(0, 0): ["straight", "ew", 1.8, {"w": 0.75}],
	Vector2i(1, 0): ["cross", "nesw", 2.2, {}],
	Vector2i(2, 0): ["door", "ew", 1.4, {}],
	Vector2i(1, 1): ["vent", "n", 1.2, {}],
	Vector2i(1, -1): ["pipe_run", "ns", 0.0, {}],
	Vector2i(1, -2): ["t", "esw", 2.0, {}],
	Vector2i(0, -2): ["dead_end", "e", 0.0, {}],
	Vector2i(2, -2): ["corner", "nw", 1.6, {}],
	Vector2i(2, -3): ["vent", "s", 0.0, {}],
}
## Open sides that meet a room, not another cell: cell -> sides.
const PORTS := {Vector2i(0, 0): "w", Vector2i(2, 0): "e"}
const STEP := {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}
const OPPOSITE := {"n": "s", "s": "n", "e": "w", "w": "e"}

var pieces := {}


func _ready() -> void:
	for cell: Vector2i in LAYOUT:
		var entry: Array = LAYOUT[cell]
		var piece := KIT.build(entry[0], entry[1], entry[3], entry[2])
		piece.name = "%s_%d_%d" % [entry[0], cell.x, cell.y]
		piece.position = cell_centre(cell)
		add_child(piece)
		pieces[cell] = piece
	var sign := Label3D.new()
	sign.text = "SERVICE ARTERY"
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.modulate = Color("c8a070")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = cell_centre(Vector2i(0, 0)) + Vector3(0, 3.3, 0)
	add_child(sign)


## Local (network-frame) floor centre of a cell.
static func cell_centre(cell: Vector2i) -> Vector3:
	return ORIGIN + Vector3(cell.x * KIT.CELL, 0.0, cell.y * KIT.CELL)


## Every open side either meets the matching open side of the next cell or is
## a declared room port. Returns the mismatches (empty = no gaps, no dead
## openings into the void).
static func joint_errors() -> Array[String]:
	var errors: Array[String] = []
	for cell: Vector2i in LAYOUT:
		var open: String = LAYOUT[cell][1]
		if not KIT.valid_openings(LAYOUT[cell][0], open):
			errors.append("%s at %s cannot open %s" % [LAYOUT[cell][0], cell, open])
		for side: String in STEP:
			var next: Vector2i = cell + STEP[side]
			var here_open := open.contains(side)
			var port := str(PORTS.get(cell, "")).contains(side)
			if not LAYOUT.has(next):
				if here_open and not port:
					errors.append("%s side %s opens on nothing" % [cell, side])
				continue
			var there_open := str(LAYOUT[next][1]).contains(OPPOSITE[side])
			if here_open != there_open:
				errors.append("%s side %s does not match %s" % [cell, side, next])
	return errors


## A walk that visits every cell (out and back along each spur), staff door
## to arcade wall: facility-frame floor points.
static func walk_route() -> Array[Vector3]:
	var order := [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 0),
		Vector2i(1, -1), Vector2i(1, -2), Vector2i(0, -2), Vector2i(1, -2),
		Vector2i(2, -2), Vector2i(2, -3), Vector2i(2, -2), Vector2i(1, -2),
		Vector2i(1, -1), Vector2i(1, 0), Vector2i(2, 0),
	]
	var route: Array[Vector3] = []
	for cell: Vector2i in order:
		route.append(cell_centre(cell))
	return route
