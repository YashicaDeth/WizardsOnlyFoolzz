extends Node

## Greg: *"want to implement this video i made ... or theese videos i have on my
## computer that u could somewhat edit"*.
##
## Before anything is wired into the cold open, this answers the one question
## that decides whether video is possible at all here: **does this Godot build
## actually play the file?**
##
## It is worth checking rather than assuming. Godot 4 plays exactly one video
## format natively — Ogg Theora — so none of Greg's material (MJPEG .mov out of
## DaVinci, H.264 .mp4 out of OBS) can be used without conversion, and a
## `VideoStreamPlayer` that fails to open a stream does so *silently*: it simply
## never produces a frame, reports no error, and looks exactly like a video that
## has not started yet.
##
## So this loads the derived stream, plays it, waits, and then checks the one
## thing that cannot be faked — that the player's own texture has non-black
## pixels in it. A test that only asserted `is_playing()` would pass on a
## completely black screen.
##
## Usage:
##   Godot --path game res://tests/video_playback_test.tscn -- --out=P:/GameDev/Temp

const CLIPS := ["res://art/derived/video/intro.ogv", "res://art/derived/video/mandala.ogv"]

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")

	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	await tree.process_frame

	for clip: String in CLIPS:
		# `name` is `Node.name`; shadowing it is a hard error, not a warning.
		var clip_name: String = clip.get_file()
		check(ResourceLoader.exists(clip), "%s exists as a resource" % clip_name)
		if not ResourceLoader.exists(clip):
			continue

		var stream: VideoStream = load(clip)
		check(stream != null, "%s loads as a VideoStream" % clip_name)
		if stream == null:
			continue

		var player := VideoStreamPlayer.new()
		player.stream = stream
		player.expand = true
		player.size = Vector2(1280, 720)
		player.autoplay = false
		add_child(player)
		player.play()

		# Theora decodes on its own thread; a frame is not ready on the frame
		# `play()` was called and asking too early reads as failure.
		for _settle in 40:
			await tree.process_frame

		check(player.is_playing(), "%s reports playing" % clip_name)

		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		var path := "%s/video_%s.png" % [out_dir, clip_name.get_basename()]
		shot.save_png(path)
		print("CAPTURED: ", path)

		# The check that matters. A silently-failed stream leaves a black rect,
		# and every other assertion above still passes against one.
		var lit := 0
		var total := 0
		for x in range(0, shot.get_width(), 12):
			for y in range(0, shot.get_height(), 12):
				var p := shot.get_pixel(x, y)
				if p.r + p.g + p.b > 0.10:
					lit += 1
				total += 1
		var share := float(lit) / maxf(1.0, float(total))
		print("   %s: %.1f%% of sampled pixels carry light" % [clip_name, share * 100.0])
		check(share > 0.05, "%s is putting real frames on screen, not a black rect" % clip_name)

		player.stop()
		player.queue_free()
		await tree.process_frame

	if failures.is_empty():
		print("video playback: fine")
		tree.quit(0)
	else:
		print("video playback FAILURES: ", failures)
		tree.quit(1)
