class_name FieldCamera
extends RefCounted

## C3. A camera on the handheld, and photographs that are objects rather than
## screenshots.
##
## The reason this is a system and not a screenshot key is `DESIGN/RITUAL_AND_KARMA.md`:
## *"rituals are completed by photographing evidence... the photograph has to
## actually contain a destroyed head, which means the game has to check the real
## anatomy state of a real body in frame."* So a photograph here is not an
## image. It is a record of **what was actually in shot and what state it was
## actually in**, taken from the same rig the fight happened to.
##
## That gives three things at once: rituals that cannot be satisfied by standing
## in the right place (E3), Wire posts with real contents behind them (C3.4),
## and an object the index can inspect like any other (C3.2).
##
## What it deliberately does not do is render an image. The contents are the
## photograph; a picture of them is a presentation problem, and the ritual
## checker, the Wire and the dossier all want the contents rather than pixels.

## Anything further than this is in the picture but not legibly in it — you
## cannot photograph a severed head from across the quarry and call it evidence.
const LEGIBLE_RANGE := 26.0


## Is this body actually in shot? The frustum is the engine's own answer, so
## this agrees with what the player can see rather than approximating it.
static func in_frame(camera: Camera3D, rig: BaselineHuman) -> bool:
	if camera == null or not is_instance_valid(camera) or rig == null or not is_instance_valid(rig):
		return false
	if not rig.is_inside_tree() or not camera.is_inside_tree():
		return false
	var at := rig.global_position + Vector3.UP
	if camera.global_position.distance_to(at) > LEGIBLE_RANGE:
		return false
	return camera.is_position_in_frustum(at)


## What is true about this body, read off the rig rather than described. This is
## the half that makes a photograph evidence: every claim in it is a claim the
## anatomy component would also make.
static func contents_of(rig: BaselineHuman) -> Dictionary:
	var anatomy: Dictionary = rig.anatomy.snapshot()
	var ruptured: Array[String] = []
	for organ_id in (anatomy.get("organs", {}) as Dictionary):
		if bool((anatomy.organs[organ_id] as Dictionary).get("ruptured", false)):
			ruptured.append(str(organ_id))
	var destroyed: Array[String] = []
	var opened: Dictionary = {}
	for zone_id in (anatomy.get("zones", {}) as Dictionary):
		if float((anatomy.zones[zone_id] as Dictionary).get("health", 1.0)) <= 0.0:
			destroyed.append(str(zone_id))
		var depth := rig.exposed_layer(str(zone_id))
		if depth > 0:
			opened[str(zone_id)] = depth
	return {
		"subject_id": rig.subject_id,
		"severed": rig.severed.duplicate(),
		"destroyed": destroyed,
		"ruptured": ruptured,
		"opened": opened,
		"dead": bool(anatomy.get("dead", false)),
		"downed": bool(anatomy.get("downed", false)),
	}


## Take the picture. Returns the photograph, which is a thing with contents.
static func capture(camera: Camera3D, rigs: Array, location: String = "") -> Dictionary:
	var contents: Array = []
	for entry in rigs:
		var rig := entry as BaselineHuman
		if in_frame(camera, rig):
			contents.append(contents_of(rig))
	var photo := {
		"id": "photo_%d" % (WorldHistory.next_sequence),
		"taken_msec": Time.get_ticks_msec(),
		"location": location,
		"contents": contents,
		"caption": describe(contents),
	}
	return photo


## What the picture is of, in the game's own voice. Generated from the contents
## so a caption can never claim something the body was not doing.
static func describe(contents: Array) -> String:
	if contents.is_empty():
		return "NOTHING IN FRAME"
	var parts: Array[String] = []
	for entry in contents:
		var record: Dictionary = entry
		var state := "ALIVE"
		if bool(record.get("dead", false)):
			state = "DEAD"
		elif bool(record.get("downed", false)):
			state = "DOWN"
		var wounds: Array[String] = []
		for zone in (record.get("severed", []) as Array):
			wounds.append("%s OFF" % str(zone).replace("_", " ").to_upper())
		for organ in (record.get("ruptured", []) as Array):
			wounds.append("%s RUPTURED" % str(organ).replace("_", " ").to_upper())
		var tail := ", ".join(PackedStringArray(wounds)) if not wounds.is_empty() else "INTACT"
		parts.append("%s / %s / %s" % [str(record.subject_id).to_upper(), state, tail])
	return "  ·  ".join(PackedStringArray(parts))


## C3.3. Does this photograph show what somebody is asking to be shown? The
## requirement is data so E3 can author rituals without this file knowing what
## a ritual is.
##
## Supported: `zone` with `state` of severed / destroyed / opened, `organ` with
## ruptured, `state` of dead or downed, an optional `subject`, and a `count` of
## how many separate bodies must satisfy it.
static func verify(photo: Dictionary, requirement: Dictionary) -> Dictionary:
	var matched: Array[String] = []
	for entry in (photo.get("contents", []) as Array):
		var record: Dictionary = entry
		var wanted_subject := str(requirement.get("subject", ""))
		if wanted_subject != "" and str(record.get("subject_id", "")) != wanted_subject:
			continue
		if not _satisfies(record, requirement):
			continue
		if not matched.has(str(record.subject_id)):
			matched.append(str(record.subject_id))
	var needed := maxi(1, int(requirement.get("count", 1)))
	return {
		"ok": matched.size() >= needed,
		"matched": matched,
		"needed": needed,
		"reason": "" if matched.size() >= needed else "%d of %d in frame" % [matched.size(), needed],
	}


static func _satisfies(record: Dictionary, requirement: Dictionary) -> bool:
	var state := str(requirement.get("state", ""))
	if state == "dead" and not bool(record.get("dead", false)):
		return false
	if state == "downed" and not (bool(record.get("downed", false)) or bool(record.get("dead", false))):
		return false
	var organ := str(requirement.get("organ", ""))
	if organ != "" and not (record.get("ruptured", []) as Array).has(organ):
		return false
	var zone := str(requirement.get("zone", ""))
	if zone == "":
		return true
	match state:
		"severed":
			return (record.get("severed", []) as Array).has(zone)
		"destroyed":
			return (record.get("destroyed", []) as Array).has(zone)
		"opened":
			var opened: Dictionary = record.get("opened", {})
			return int(opened.get(zone, 0)) >= int(requirement.get("depth", 1))
		_:
			# A zone named with no state asked of it only has to be on a body
			# that is in shot at all.
			return true


## The album. Photographs persist like everything else, so one taken before a
## ritual existed can still satisfy it later.
static func store(photo: Dictionary) -> Dictionary:
	var album: Array = (WorldHistory.subject("photographs").get("frames", []) as Array).duplicate()
	album.append(photo)
	while album.size() > 40:
		album.pop_front()
	WorldHistory.register_subject("photographs", {"kind": "album", "frames": []})
	WorldHistory.amend_subject("photographs", {"frames": album})
	return photo


static func album() -> Array:
	return (WorldHistory.subject("photographs").get("frames", []) as Array).duplicate()
