class_name SupportMail
extends RefCounted

## Y4. Mail out of the game, to a person.
##
## Greg: *"settings has a feature where you can email my email
## wizardsonlyfoolzthegame@gmail.com for support or reporting bugs"*, and from
## Y2.3, the SOON card on multiplayer points here too — which is the only reason
## to show a door you cannot open yet.
##
## Three jobs and they are the same job with a different subject line: support,
## a bug, an idea. The part worth building properly is Y4.2 — **a player should
## not have to write down what the game already knows.** A bug report that
## arrives without the build, the seed or the hour is a bug report that costs two
## more emails, so the context is gathered here and the player writes only the
## sentence they actually wanted to write.
##
## No network, no dependency, no key: this hands a `mailto:` to the machine's own
## mail client. That fails on plenty of machines, which is why `send()` reports
## whether it worked and hands the address back rather than pretending (Y4.3).

const ADDRESS := "wizardsonlyfoolzthegame@gmail.com"

## Subject lines, so mail lands sorted without anybody filing it.
const SUBJECTS := {
	"support": "Wizards Only Fools - support",
	"bug": "Wizards Only Fools - bug report",
	"idea": "Wizards Only Fools - idea",
}

## mailto: bodies are percent-encoded and a newline is CRLF. Getting this wrong
## produces a mail whose body is one long line, which is the sort of thing that
## looks fine until somebody actually sends one.
const BREAK := "\r\n"


## What the game knows about itself. Kept separate from `compose` so a caller can
## show the player exactly what is about to be attached to their name — a report
## that quietly carries more than the sender expected is worse than one that
## carries nothing.
static func context(extra: Dictionary = {}) -> Dictionary:
	var gathered := {
		"build": ProjectSettings.get_setting("application/config/version", "dev"),
		"engine": Engine.get_version_info().get("string", ""),
		"platform": OS.get_name(),
		"when": Time.get_datetime_string_from_system(true),
	}
	for key in extra:
		gathered[key] = extra[key]
	return gathered


## The whole mail, as text, before any of it is encoded. Returned rather than
## sent so it can be shown in the settings page first.
static func compose(kind: String, note: String, extra: Dictionary = {}) -> Dictionary:
	var subject: String = SUBJECTS.get(kind, SUBJECTS["support"])
	var lines: Array[String] = []
	if not note.strip_edges().is_empty():
		lines.append(note.strip_edges())
		lines.append("")
	# Y4.2. Below the line is the part the player did not have to type.
	lines.append("--- what the game knows ---")
	var gathered := context(extra)
	for key in gathered:
		lines.append("%s: %s" % [str(key), str(gathered[key])])
	return {
		"address": ADDRESS,
		"subject": subject,
		"body": BREAK.join(lines),
	}


## `mailto:` with both fields encoded. Godot's `uri_encode` leaves the reserved
## characters a query string cannot carry alone, so the joining is done here.
static func mailto(kind: String, note: String, extra: Dictionary = {}) -> String:
	var mail := compose(kind, note, extra)
	return "mailto:%s?subject=%s&body=%s" % [
		str(mail.address),
		str(mail.subject).uri_encode(),
		str(mail.body).uri_encode(),
	]


## Hand it to the machine. Y4.3: this fails on plenty of machines and it says so
## rather than looking like it worked — the address comes back either way, so the
## settings page always has something to put on screen.
static func send(kind: String, note: String, extra: Dictionary = {}) -> Dictionary:
	var uri := mailto(kind, note, extra)
	var mail := compose(kind, note, extra)
	var result := {
		"address": ADDRESS,
		"subject": mail.subject,
		"body": mail.body,
		"uri": uri,
		"sent": false,
		"reason": "",
	}
	# Never in a test run: a headless machine opening a mail client is a hang,
	# and a capture that pops Outlook is somebody's afternoon.
	if OS.has_feature("editor") and OS.get_environment("ATG_TEST_MODE") == "1":
		result["reason"] = "test mode - not opening a mail client"
		return result
	var error := OS.shell_open(uri)
	if error == OK:
		result["sent"] = true
	else:
		result["reason"] = "no mail client answered - the address is on screen to copy"
	return result
