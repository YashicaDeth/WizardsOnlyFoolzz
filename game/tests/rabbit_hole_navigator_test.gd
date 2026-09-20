extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var navigator := RabbitHoleNavigator.new()
	check(navigator.follow("subject", "gray_trestle", "pyramid").id == "gray_trestle", "a Pyramid subject opens")
	navigator.follow("dossier", "gray_trestle", "pyramid", {"subject_id": "gray_trestle"})
	navigator.follow("post", "post_0042", "wire", {"subject_id": "gray_trestle"})
	navigator.follow("site", "grave-contractors-home", "wire")
	check(navigator.breadcrumbs().size() == 4, "the cross-root rabbit hole stays visible")
	check(navigator.back().kind == "post", "back returns to the post")
	check(navigator.forward().kind == "site", "forward returns to the site")

	var saved := navigator.snapshot()
	var restored := RabbitHoleNavigator.new()
	check(restored.restore(saved).id == "grave-contractors-home", "the trail restores on the same object")
	check(restored.breadcrumbs().size() == 4, "the restored trail keeps its history")
	check(restored.follow("nonsense", "x", "wire").is_empty(), "unknown object kinds are rejected")
	check(restored.follow("site", "", "wire").is_empty(), "empty identities are rejected")

	# Following the current object refreshes its context without manufacturing a
	# second breadcrumb. This matters when a post accumulates new evidence.
	var before := restored.breadcrumbs().size()
	restored.follow("site", "grave-contractors-home", "wire", {"visited": true})
	check(restored.breadcrumbs().size() == before, "refreshing one object does not duplicate it")
	check(bool(restored.current().context.visited), "and its live context is refreshed")

	print("RABBIT_HOLE_NAVIGATOR_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

