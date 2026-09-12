extends Control

const CellOutzType := preload("res://systems/celloutz_type.gd")

var seal_seeds: Array = []


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.045, 0.04))
	var bone := Color("ead4ad")
	var columns := 3
	var gallery_height := size.y - 220
	var cell := Vector2(size.x / columns, gallery_height / 2.0)
	for index in seal_seeds.size():
		var col := index % columns
		var row := index / columns
		var center := Vector2(cell.x * (col + 0.5), cell.y * (row + 0.5))
		var radius := minf(cell.x, cell.y) * 0.36
		CellOutzType.draw_seal(self, center, radius, seal_seeds[index], bone, 6)
	# One seal each in forming/corrupted/burning, so all three read against
	# the plain gallery above.
	var demo_y := gallery_height + 100
	CellOutzType.draw_seal_forming(self, Vector2(size.x / 6.0, demo_y), 80, 11, bone, 0.55)
	CellOutzType.draw_seal_corrupted(self, Vector2(size.x * 0.5, demo_y), 80, 11, bone, 0.45)
	CellOutzType.draw_seal_burning(self, Vector2(size.x * 5.0 / 6.0, demo_y), 80, 11, bone, 0.4)
