extends Node

## Keeps the authored cold-open rhythm testable: the circled Algiz gets a
## visible solo hold and every title card uses a real scalar fade at its edges.

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("BOOT_SPLASH_TIMING_TEST: %s" % message)


func _ready() -> void:
	var splash = preload("res://boot_splash.tscn").instantiate()
	add_child(splash)
	await get_tree().process_frame

	var grandeur_duration: float = splash.STAGE_DURATION[splash.Stage.GRANDEUR]
	splash.stage = splash.Stage.GRANDEUR
	splash.stage_clock = 0.05
	check(splash._card_alpha(grandeur_duration) < 0.10, "publisher text begins faded")
	splash._update_grandeur_visibility()
	check(splash.grandeur_rect.modulate.a < 0.10, "Grandeur wordmark begins faded")
	splash.stage_clock = grandeur_duration * 0.5
	check(splash._card_alpha(grandeur_duration) > 0.99, "publisher text reaches full readability")
	splash._update_grandeur_visibility()
	check(splash.grandeur_rect.modulate.a > 0.99, "Grandeur wordmark reaches full readability")
	splash.stage_clock = grandeur_duration - 0.05
	check(splash._card_alpha(grandeur_duration) < 0.10, "publisher text fades out")

	splash.stage = splash.Stage.MARK
	splash.stage_clock = splash.SEAL_REVEAL_SECONDS + 0.10
	splash._update_mark_visibility()
	check(splash.seal_rect.modulate.a > 0.99, "circled Algiz finishes its fade-in")
	check(splash.mark_rect.modulate.a < 0.01, "lockup is absent during the Algiz hero beat")

	splash.stage_clock = splash.SEAL_REVEAL_SECONDS + splash.SEAL_HERO_HOLD_SECONDS - 0.10
	splash._update_mark_visibility()
	check(splash.seal_rect.modulate.a > 0.99, "circled Algiz remains fully visible through its solo hold")
	check(splash.mark_rect.modulate.a < 0.01, "lockup waits until the solo hold has ended")

	splash.stage_clock = splash.SEAL_REVEAL_SECONDS + splash.SEAL_HERO_HOLD_SECONDS + splash.LOCKUP_CROSSFADE_SECONDS * 0.5
	splash._update_mark_visibility()
	check(splash.seal_rect.modulate.a > 0.35 and splash.seal_rect.modulate.a < 0.65, "Algiz fades out during the crossfade")
	check(splash.mark_rect.modulate.a > 0.35 and splash.mark_rect.modulate.a < 0.65, "lockup fades in during the crossfade")

	print("BOOT_SPLASH_TIMING_TEST_RESULT failures=%d" % failures)
	get_tree().quit(failures)
