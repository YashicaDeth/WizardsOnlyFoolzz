extends Node

## Brief 1, `ladder-seats`, proof frames. The wall itself is brief 3; this is the
## board's own data drawn flat so the seat mechanics can be looked at:
##
##   before  47 holds an office seat, Hollis waits a band below him
##   vacant  the seat stands empty and names the dawn it fills
##   after   Hollis has moved up, and the seat he left is waiting for the next
##
## Render: P:/GameDev/AgentHub/render_one.cmd ladder_board_capture

const Society := preload("res://systems/pyramid_society.gd")
const Ladder := preload("res://systems/ladder_seats.gd")

var ladder: Ladder
var panel: Label


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp/ladder_seats"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	# The arcade shift opens in the afternoon, as the game does.
	WorldHistory.world_minute = 13.0 * 60.0
	ladder = Ladder.new()
	ladder.begin(Society.new(), "celloutz")
	ladder.register_facility()

	var layer := CanvasLayer.new()
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.055, 0.05, 0.045)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	panel = Label.new()
	panel.add_theme_font_size_override("font_size", 17)
	panel.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	panel.position = Vector2(64, 48)
	panel.size = Vector2(1150, 640)
	layer.add_child(panel)

	await _shot("%s/ladder_before.png" % out_dir)

	# 47 is killed in the Service Arcade. The seat empties at once, and names the
	# dawn it fills: the next one, not this frame.
	WorldHistory.world_minute = 13.4 * 60.0
	ladder.vacate("guard_celloutz_47", {"cause": "killed", "location_id": "service_arcade"})
	await _shot("%s/ladder_vacant.png" % out_dir)

	# Sleep to dawn. Hollis is the longest-serving person beneath the office, so
	# the seat is his, and his own seat now waits for the dawn after.
	var dawn := Ladder.next_dawn(WorldHistory.world_minute)
	WorldHistory.world_minute = dawn
	var changes := ladder.catch_up()
	print("CAPTURE dawn changes=", JSON.stringify(changes))
	await _shot("%s/ladder_after.png" % out_dir)
	get_tree().quit(0)


func _shot(path: String) -> void:
	panel.text = _draw()
	for _settle in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(path) != OK:
		print("CAPTURE_FAILED ", path)
		get_tree().quit(1)
	print("CAPTURED ", path)


func _draw() -> String:
	var board := ladder.board()
	var lines: PackedStringArray = []
	lines.append("THE LADDER  //  %s  //  %s" % [str(board.faction_id).to_upper(), Ladder.stamp(WorldHistory.world_minute)])
	lines.append("")
	for row in board.rows:
		var seats: Array = row.seats
		if seats.is_empty():
			lines.append("%-12s THE CROWD  (%d)" % [str(row.band_label), (board.crowd as Array).size()])
			continue
		var empty: Array = []
		var filled: Array = []
		for seat in seats:
			if bool(seat.get("empty", false)):
				empty.append(seat)
			else:
				filled.append(seat)
		lines.append("%-12s %d SEAT%s  ·  %d EMPTY" % [str(row.band_label), seats.size(), "" if seats.size() == 1 else "S", empty.size()])
		for seat in filled:
			var traits: Array = seat.traits
			var note := "seated"
			if not str(seat.get("promoted_into", "")).is_empty():
				note = "promoted into %s's seat" % str(seat.promoted_into)
			lines.append("   %-24s %s  ·  %s  ·  %s" % [
				str(seat.name), str(seat.side),
				" / ".join([str(traits[0]), str(traits[1]), str(traits[2])]), note,
			])
		# A run of empty seats is drawn as the run, with the one fact that
		# matters: the soonest hour one of them fills, and who held it.
		var soonest := {}
		for seat in empty:
			if float(seat.fills_at) <= 0.0:
				continue
			if soonest.is_empty() or float(seat.fills_at) < float(soonest.fills_at):
				soonest = seat
		if not soonest.is_empty():
			var why := "DIED" if str(soonest.get("emptied_by", "")) == "death" else "PROMOTED AWAY"
			lines.append("   %-24s EMPTY  ·  FILLS %s  ·  WAS %s (%s)" % ["—", str(soonest.fills_at_stamp), str(soonest.was), why])
			var waiting := empty.filter(func(seat): return float(seat.fills_at) > 0.0).size() - 1
			if waiting > 0:
				lines.append("   %-24s (and %d more, waiting on their own dawns)" % ["", waiting])
		elif not empty.is_empty():
			var vacant := empty.filter(func(seat): return not str(seat.was).is_empty())
			if vacant.is_empty():
				lines.append("   %-24s EMPTY  ·  NEVER HELD" % "—")
			else:
				lines.append("   %-24s EMPTY  ·  NO CANDIDATE BENEATH  ·  WAS %s" % ["—", str(vacant[0].was)])
	lines.append("")
	lines.append("FALLEN")
	for grave in board.fallen:
		lines.append("   %-24s %s  ·  DIED %s" % [str(grave.name), str(grave.band_label), Ladder.stamp(float(grave.died_at))])
	if (board.fallen as Array).is_empty():
		lines.append("   —")
	lines.append("")
	lines.append("EMPTY SEATS: %d      NEXT FILL: %s" % [int(board.empty_seats), str(board.next_fill) if not str(board.next_fill).is_empty() else "—"])
	return "\n".join(lines)
