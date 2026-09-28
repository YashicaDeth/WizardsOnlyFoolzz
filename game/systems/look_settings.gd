extends RefCounted

## How the mouse and camera feel, from the pause menu's CAMERA page (Greg's
## checklist, B5: sensitivity, invert Y, FOV). Stored on the settings subject
## in WorldHistory like every other setting, and read by every scene's mouse
## look, so one change applies everywhere.

const SETTINGS_ID := "settings"
const SENSITIVITY_RANGE := Vector2(0.25, 3.0)
const FOV_RANGE := Vector2(-15.0, 30.0)


static func sensitivity() -> float:
	return clampf(float(WorldHistory.subject(SETTINGS_ID).get("look_sensitivity", 1.0)), SENSITIVITY_RANGE.x, SENSITIVITY_RANGE.y)


static func invert_y() -> bool:
	return bool(WorldHistory.subject(SETTINGS_ID).get("invert_y", false))


## Degrees added to the Hunt's field of view.
static func fov_offset() -> float:
	return clampf(float(WorldHistory.subject(SETTINGS_ID).get("fov_offset", 0.0)), FOV_RANGE.x, FOV_RANGE.y)


## The mouse's sideways move, scaled by sensitivity.
static func dx(relative: Vector2) -> float:
	return relative.x * sensitivity()


## The mouse's vertical move, scaled and inverted if asked.
static func dy(relative: Vector2) -> float:
	return relative.y * sensitivity() * (-1.0 if invert_y() else 1.0)


static func set_value(key: String, value: Variant) -> void:
	WorldHistory.update_subject(SETTINGS_ID, {key: value}, "look_setting_changed")
