extends Node2D

## Visual proof for AL1.5. The three figures are produced by the real Carry
## ledger and WorldClock; this scene only typesets the receipt they leave.

var figures: Array[int] = []
var receipt_days := 0
var office_clause := ""


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.world_minute = 0.0
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("choir_of_marrow", {"name": "Choir of Marrow", "kind": "faction"})
	var account := Carry.new()
	account.borrow(100, "choir_of_marrow")
	figures.append(account.debt_to("choir_of_marrow"))
	WorldClock.pass_time(24.0)
	figures.append(account.debt_to("choir_of_marrow"))
	WorldClock.pass_time(48.0)
	var reopened := Carry.new()
	figures.append(reopened.debt_to("choir_of_marrow"))
	office_clause = str((reopened.account_statement("choir_of_marrow").get("clauses", []) as Array)[0])
	var last := WorldHistory.recent_events(1)
	if not last.is_empty():
		receipt_days = int((last[0].details as Dictionary).get("days", 0))
	queue_redraw()
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := "P:/GameDev/Temp/bank_interest_demo.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	var error := get_viewport().get_texture().get_image().save_png(output)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", output)
	get_tree().quit(0 if error == OK else 1)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 1280, 720), Color("090706"))
	# One physical docket, not a dashboard. The ragged carbon-copy shadow and
	# punched holes make the numbers belong to an institution with paperwork.
	draw_rect(Rect2(176, 58, 944, 604), Color("2b0d09"), true)
	draw_rect(Rect2(160, 44, 944, 604), Color("d0bb8d"), true)
	for y in range(78, 630, 42):
		draw_circle(Vector2(174, y), 6.0, Color("090706"))
		draw_circle(Vector2(1090, y), 6.0, Color("090706"))
	draw_string(font, Vector2(205, 105), "CELLOUTZ CREDIT OFFICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("301b12"))
	draw_string(font, Vector2(205, 139), "ACCOUNT 000001  //  CHOIR OF MARROW", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("6e1c12"))
	draw_line(Vector2(205, 162), Vector2(1055, 162), Color("6e1c12"), 3.0)

	var xs := [260.0, 630.0, 990.0]
	var labels := ["OPEN", "ONE DAY", "THREE DAYS"]
	for index in figures.size():
		var at := Vector2(xs[index], 310)
		draw_circle(at, 14.0, Color("8f2818"), true)
		if index < figures.size() - 1:
			draw_line(at, Vector2(xs[index + 1], 310), Color("8f2818"), 5.0)
		draw_string(font, Vector2(at.x - 55, 245), labels[index], HORIZONTAL_ALIGNMENT_CENTER, 110, 16, Color("4b3627"))
		draw_string(font, Vector2(at.x - 80, 390), str(figures[index]), HORIZONTAL_ALIGNMENT_CENTER, 160, 58, Color("301b12"))
		draw_string(font, Vector2(at.x - 70, 421), "RUST SCRIP", HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color("6e1c12"))

	draw_rect(Rect2(205, 474, 850, 74), Color("bba577"), true)
	draw_string(font, Vector2(230, 510), "SECURITY: LIVER  //  NAMED  //  REPOSSESSABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("301b12"))
	draw_string(font, Vector2(230, 535), "LAST RECEIPT CAUGHT UP %d UNATTENDED DAYS" % receipt_days, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("6e1c12"))
	draw_string(font, Vector2(205, 590), office_clause, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("6e1c12"))
	draw_string(font, Vector2(205, 621), "THE BUILDING WAS CLOSED. THE ACCOUNT WAS NOT.", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("8f2818"))
