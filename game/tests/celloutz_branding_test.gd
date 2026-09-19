extends Node

## K1.2. The brand is only useful if its existing public surfaces all point at
## the same faction identity rather than each inventing a different joke.

const Branding := preload("res://systems/celloutz_branding.gd")
const DisplayType := preload("res://systems/celloutz_type.gd")
const WarningCardScript := preload("res://systems/warning_card.gd")
const VatIntakeScript := preload("res://systems/vat_intake.gd")
const BrokenWebScript := preload("res://systems/broken_web.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func source_uses_branding(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return file.get_as_text().contains("celloutz_branding.gd")


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var faction := Branding.faction_record()
	check(WarningCardScript != null and VatIntakeScript != null and BrokenWebScript != null, "every branded surface parses with the shared copy source")
	check(str(faction.id) == "celloutz", "the brand resolves to the CellOutz faction")
	check(str(faction.axis) == "DESCENT", "the company is deliberately the below pole")
	check(str(faction.cosmology) == "demon faction below", "the brand record makes the corporate demon connection explicit")
	check(str(faction.principle) == "Ownership", "the brand names ownership as its governing principle")
	check(str(faction.register).contains("corporate") and str(faction.register).contains("bodily"), "the register stays corporate and bodily")

	var warning := Branding.copy_for("warning", "body")
	check(Branding.copy_for("warning", "heading").contains("DESCENT"), "the front-door notice names the descent")
	check(warning.contains("ledger") and warning.contains("organs") and warning.contains("ownership"), "the liability notice makes body debt and ownership legible")
	var warning_heading_width := DisplayType.width(Branding.copy_for("warning", "heading"), 11.0, 1.4)
	check(warning_heading_width <= 760.0, "the longer warning heading still fits its card (%.0f px)" % warning_heading_width)
	var intake_header := Branding.copy_for("intake", "header")
	check(intake_header.contains("DESCENT") and Branding.copy_for("intake", "body_notice").contains("COLLATERAL"), "the Growing Floor turns a body into a recorded asset")
	var intake_header_width := DisplayType.width_condensed(intake_header, 9.0, 0.7)
	check(intake_header_width <= 470.0, "the intake header stays inside the clipboard (%.0f px)" % intake_header_width)

	var support_lines := Branding.support_lines()
	check(Branding.copy_for("support", "section_label").contains("BELOW") and Branding.copy_for("support", "strap").contains("recoverable"), "customer care identifies the Below as an operating division")
	check(support_lines.any(func(line): return str(line).contains("debt")) and support_lines.any(func(line): return str(line).contains("BELOW")), "support copy preserves both debt and descent")

	for path in [
		"res://systems/warning_card.gd",
		"res://systems/vat_intake.gd",
		"res://systems/broken_web.gd",
	]:
		check(source_uses_branding(path), "%s uses the shared CellOutz brand source" % path.get_file())

	print("CELLOUTZ_BRANDING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
