class_name StrikeHeading
extends RefCounted

## Which way a melee strike goes. First person aims where you look — that view
## is the precise one. Third person is the combat stance Greg wants to fight
## omnidirectionally in: the blow goes where you are pushing, so a body behind
## or beside you is a target the moment you lean into it, and the hunter turns
## into the strike instead of the camera having to come round first.

## Below this much stick/key input, the push is noise and the view decides.
const PUSH_THRESHOLD := 0.2


static func heading(flat_view: Vector3, wish: Vector3, third_person: bool) -> Vector3:
	var view := Vector3(flat_view.x, 0.0, flat_view.z)
	var push := Vector3(wish.x, 0.0, wish.z)
	if third_person and push.length() > PUSH_THRESHOLD:
		return push.normalized()
	return view.normalized() if view.length_squared() > 0.0001 else Vector3.FORWARD
