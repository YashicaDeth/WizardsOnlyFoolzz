extends Node

## Y4. Mail out of the game.
##
## The parts that can be wrong without looking wrong: the address, the encoding
## (a mailto whose body is one long line looks fine until somebody sends one),
## and whether a report quietly carries more than the sender expected.

const SUPPORT_MAIL := preload("res://systems/support_mail.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("Y4 - support, from inside the game")

	_check(SUPPORT_MAIL.ADDRESS == "wizardsonlyfoolzthegame@gmail.com", "the address is Greg's, spelled right")

	# --- the three doors, one mechanism ------------------------------------
	var support: Dictionary = SUPPORT_MAIL.compose("support", "the derby will not load")
	var bug: Dictionary = SUPPORT_MAIL.compose("bug", "the derby will not load")
	var idea: Dictionary = SUPPORT_MAIL.compose("idea", "co-op for the hunts")
	_check(support.subject != bug.subject and bug.subject != idea.subject, "each kind gets its own subject, so mail lands sorted")
	for mail: Dictionary in [support, bug, idea]:
		_check(str(mail.subject).contains("Wizards Only Fools"), "and every subject names the game (%s)" % mail.subject)

	# --- Y4.2: the player does not type what the game already knows --------
	_check(str(bug.body).contains("the derby will not load"), "the player's own sentence is in the body, first")
	_check(str(bug.body).contains("--- what the game knows ---"), "and what is attached is under a line that says so")
	for expected in ["build", "engine", "platform", "when"]:
		_check(str(bug.body).contains(expected + ":"), "the report carries the %s without being asked" % expected)

	var seeded: Dictionary = SUPPORT_MAIL.compose("bug", "rivals stopped spawning", {"seed": 4471, "hours": 12.5})
	_check(str(seeded.body).contains("seed: 4471"), "a caller can attach the run's own state")
	_check(str(seeded.body).contains("hours: 12.5"), "and anything else it knows")

	# Nothing arrives that the caller did not put there.
	var bare: Dictionary = SUPPORT_MAIL.context()
	_check(not bare.has("seed"), "and nothing is attached that nobody asked for")

	# An empty note is a real case - somebody opens support and sends nothing.
	var empty: Dictionary = SUPPORT_MAIL.compose("support", "   ")
	_check(str(empty.body).begins_with("--- what the game knows ---"), "an empty note does not leave a blank line pretending to be a message")

	# --- the encoding ------------------------------------------------------
	var uri: String = SUPPORT_MAIL.mailto("bug", "it broke & then it broke again")
	_check(uri.begins_with("mailto:wizardsonlyfoolzthegame@gmail.com?"), "the uri is a mailto to the right address")
	_check(uri.contains("subject=") and uri.contains("&body="), "with both fields")
	_check(not uri.contains("it broke & then"), "an ampersand in the note is encoded, not left to end the query string early")
	_check(not uri.substr(uri.find("&body=")).contains(" "), "and no raw spaces survive into the body")
	_check(uri.contains("%0D%0A") or uri.contains("%0d%0a"), "line breaks are encoded CRLF, so the body is not one long line")

	# --- Y4.3: it never silently fails --------------------------------------
	var sent: Dictionary = SUPPORT_MAIL.send("support", "hello")
	_check(sent.has("sent") and sent.has("reason"), "sending reports whether it worked and why not")
	_check(str(sent.address) == SUPPORT_MAIL.ADDRESS, "and hands the address back either way, so the page always has something to show")
	_check(not bool(sent.sent), "and does not open a mail client during a test run")

	print("")
	if failures.is_empty():
		print("Y4 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
