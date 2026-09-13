class_name Smokeables
extends RefCounted

## AU1.8. "Smoking is a real act: cigarettes, vapes, joints, spliffs, blunts,
## bongs, alien devices."
##
## A real act, which rules out the obvious implementation. `use_item()` that
## subtracts a charge and adds a buff is not an act - it is a transaction with
## an animation in front of it. The thing that makes smoking feel like anything
## is that **you hold it**, and holding it longer is both better and worse:
## the hit gets bigger and the harshness catches up with you. So the input is
## press-and-hold, the output is a curve with a sweet spot you can overshoot,
## and every device puts that sweet spot somewhere different.
##
## Geometry is procedural from primitives, same rule as every other object in
## this game - nothing imported, and `held_gear.gd`'s own helpers do the work
## so a cigarette is built the way a sword is.
##
## What this file does NOT do: cost anything, change anatomy, or decide what you
## see. `Substances.take()` still owns the body price and
## `substance_experience.gd` still owns the curve. This owns the object in your
## hand and the quality of the draw.

const HeldGearRef := preload("res://systems/held_gear.gd")
const SubstanceExperience := preload("res://systems/substance_experience.gd")

## `draw_ideal` is where the sweet spot sits, in seconds of held input.
## `forgiveness` is how wide that spot is - a cigarette is nearly impossible to
## get wrong and a bong is nearly impossible to get right, which is the entire
## difference between them as objects.
## `harshness` is what an overshoot costs. `yield_scale` multiplies the dose.
## `charges` is how many draws the object has before it is spent.
const CATALOG := {
	"cigarette": {
		"label": "Cigarette", "substance": "marrow_dust",
		"draw_ideal": 1.6, "forgiveness": 1.1, "harshness": 0.35,
		"yield_scale": 0.45, "charges": 9, "two_handed": false,
		"exhale": 1.1, "ember": true,
		"voice": "Barely an event. Which is the point - it is the one you do while thinking about something else.",
	},
	"vape": {
		"label": "Vape", "substance": "marrow_dust",
		"draw_ideal": 2.4, "forgiveness": 1.6, "harshness": 0.12,
		"yield_scale": 0.6, "charges": 40, "two_handed": false,
		"exhale": 1.6, "ember": false,
		"voice": "Forgiving, plentiful, and completely without ceremony. Nobody has ever passed one to somebody and meant something by it.",
	},
	"joint": {
		"label": "Joint", "substance": "choir_bloom",
		"draw_ideal": 2.2, "forgiveness": 0.8, "harshness": 0.5,
		"yield_scale": 0.85, "charges": 7, "two_handed": false,
		"exhale": 1.5, "ember": true,
		"voice": "Wants a steady draw. Snatch at it and you get ash and a cough.",
	},
	"spliff": {
		"label": "Spliff", "substance": "choir_bloom",
		"draw_ideal": 2.0, "forgiveness": 0.95, "harshness": 0.42,
		"yield_scale": 0.7, "charges": 9, "two_handed": false,
		"exhale": 1.4, "ember": true,
		"voice": "Cut with tobacco, so it burns longer, hits softer, and lies about what it is doing to you.",
	},
	"bong": {
		"label": "Bong", "substance": "choir_bloom",
		"draw_ideal": 3.4, "forgiveness": 0.55, "harshness": 0.85,
		"yield_scale": 1.6, "charges": 3, "two_handed": true,
		"exhale": 2.4, "ember": true,
		"voice": "The only one that can actually go wrong. Pull it right and nothing else in the shed compares; pull it long and you are on the floor.",
	},
}

## The three things a draw can be. Named, because the HUD should be able to say
## which one happened without inventing its own vocabulary (I0 - a gauge is an
## object, and this is what the gauge is reading).
const WEAK := "weak"
const CLEAN := "clean"
const HARSH := "harsh"

## Below this the draw did not really happen. Above `1.0 + forgiveness` it is
## overcooked. Clean is the band between.
const WEAK_FLOOR := 0.45


## The quality of one draw, from how long the button was held.
##
## `held` is seconds. Returns `strength` (what you actually got, 0-1+),
## `harsh` (what it cost you, 0-1) and `grade`. A too-short draw is not
## punished, it is simply thin - the punishment is reserved for greed, which is
## the only reading of a long pull that is true to the act.
static func draw_quality(device_id: String, held: float) -> Dictionary:
	var device: Dictionary = CATALOG.get(device_id, {})
	if device.is_empty():
		return {"ok": false, "reason": "NO SUCH DEVICE"}
	var ideal := float(device["draw_ideal"])
	var width := float(device["forgiveness"])
	var ratio := held / maxf(ideal, 0.01)

	var strength := 0.0
	var harsh := 0.0
	var grade := WEAK
	if ratio < WEAK_FLOOR:
		# Thin. Scales up from nothing rather than snapping on at a threshold.
		strength = (ratio / WEAK_FLOOR) * 0.45
		grade = WEAK
	elif ratio <= 1.0:
		# Climbing to the sweet spot.
		strength = lerpf(0.45, 1.0, (ratio - WEAK_FLOOR) / (1.0 - WEAK_FLOOR))
		grade = CLEAN
	elif ratio <= 1.0 + width:
		# Past ideal but inside forgiveness: still climbing, slower, and
		# starting to bite.
		var over := (ratio - 1.0) / width
		strength = 1.0 + over * 0.35
		harsh = over * over * float(device["harshness"])
		grade = CLEAN if over < 0.55 else HARSH
	else:
		# Greed. The yield stops climbing and the cost does not.
		var far := ratio - (1.0 + width)
		strength = 1.35
		harsh = clampf(float(device["harshness"]) * (1.0 + far * 1.4), 0.0, 1.0)
		grade = HARSH

	strength *= float(device["yield_scale"])
	return {
		"ok": true, "device": device_id, "held": held,
		"strength": strength, "harsh": clampf(harsh, 0.0, 1.0), "grade": grade,
		"substance": str(device["substance"]),
		"exhale": float(device["exhale"]),
	}


## AU1.8's "observable buzz". A hit is a real, short dose on top of whatever is
## already running: it uses the same curve machinery as a swallowed dose, just
## compressed, so a smoked substance and an eaten one cannot drift into being
## two systems. `now` is supplied for the same reason it is in
## `substance_experience.gd` - so a test can run a session in a loop.
static func hit(subject_id: String, device_id: String, held: float, now: float) -> Dictionary:
	var quality := draw_quality(device_id, held)
	if not bool(quality.get("ok", false)):
		return quality
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}

	var substance_id := str(quality["substance"])
	var potency := clampf(float(quality["strength"]), 0.05, 2.0)
	var began := SubstanceExperience.begin(subject_id, substance_id, now, potency)

	# Harshness is a body cost and goes where body costs go, not into a
	# separate "cough" counter nobody else reads.
	if float(quality["harsh"]) > 0.0:
		var anatomy: Dictionary = (subject.get("anatomy_state", {}) as Dictionary).duplicate()
		anatomy["consciousness"] = clampf(float(anatomy.get("consciousness", 100.0)) - float(quality["harsh"]) * 9.0, 0.0, 100.0)
		anatomy["pain"] = clampf(float(anatomy.get("pain", 0.0)) + float(quality["harsh"]) * 6.0, 0.0, 100.0)
		WorldHistory.amend_subject(subject_id, {"anatomy_state": anatomy})

	WorldHistory.record_event("smoked", {
		"subject_id": subject_id, "device": device_id,
		"grade": str(quality["grade"]), "held": held,
		"strength": float(quality["strength"]), "harsh": float(quality["harsh"]),
	})
	quality["dose"] = began.get("dose", {})
	return quality


## --- the objects ---------------------------------------------------------
## Built from primitives, in the metric the rest of the game uses (a cigarette
## is 0.084m because a cigarette is 84mm).

const PAPER := Color("e6e0d2")
const TOBACCO := Color("8a6a3c")
const ASH := Color("b9b2a6")
const COAL := Color("d4441c")
const GLASS := Color("cfe0dd")
const RESIN := Color("4c3b1e")
const CARD_TIP := Color("bfae8c")
const PLASTIC := Color("1d1f21")


static func build(device_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = device_id
	match device_id:
		"cigarette": _build_rolled(root, 0.084, 0.0040, 0.0040, 0.026, PAPER, TOBACCO, Color("c2914f"), false)
		"spliff": _build_rolled(root, 0.098, 0.0040, 0.0056, 0.020, PAPER, TOBACCO, CARD_TIP, true)
		"joint": _build_rolled(root, 0.088, 0.0038, 0.0074, 0.013, PAPER, Color("6f7a3a"), CARD_TIP, true)
		"vape": _build_vape(root)
		"bong": _build_bong(root)
		_: return root
	return root


## One shape covers cigarette, spliff and joint - they differ in length, girth
## and how much of the end is filter, which is genuinely all they differ by as
## objects. A joint's filter is a rolled card tip, so it reads greener and
## shorter; the spliff is the long one because tobacco makes it burn slower.
## The three rolled shapes were the same cylinder at three lengths, so a
## cigarette, a spliff and a joint were one object with three labels. They are
## not: a cigarette is a machine-made tube with a tan acetate filter, a joint is
## hand-rolled and therefore **conical** - wider at the burning end than at the
## mouth - over a card crutch, and a spliff sits between the two because it is
## cut with tobacco and rolled longer. The taper is the whole silhouette, which
## is the thing you actually recognise one by at arm's length.
static func _build_rolled(root: Node3D, length: float, mouth_radius: float, burn_radius: float, filter_length: float, paper: Color, packed: Color, filter_tint: Color, crutch: bool) -> void:
	# `_lay()` turns the mesh's +Y toward +Z, so `top_radius` is the mouth end
	# and `bottom_radius` is the end that burns.
	var body := _lay(_taper(mouth_radius, burn_radius, length - filter_length, paper, 0.86))
	body.position = Vector3(0, 0, -(length - filter_length) * 0.5 - filter_length)
	root.add_child(body)

	var tip := _lay(_cylinder(mouth_radius * 1.02, filter_length, filter_tint, 0.95))
	tip.position = Vector3(0, 0, -filter_length * 0.5)
	root.add_child(tip)

	if crutch:
		# A rolled card crutch is a tube, not a plug - you can see down it.
		var bore := _lay(_cylinder(mouth_radius * 0.52, filter_length * 1.04, Color("2b241c"), 0.98))
		bore.position = Vector3(0, 0, -filter_length * 0.5)
		root.add_child(bore)
	else:
		# A machine filter has a seam where the tipping paper is glued on.
		var seam := _lay(_cylinder(mouth_radius * 1.035, 0.0016, filter_tint.darkened(0.22), 0.9))
		seam.position = Vector3(0, 0, -filter_length + 0.001)
		root.add_child(seam)

	# The burning end: packed face, a collar of ash that has not dropped yet,
	# and a coal that is the only thing on the object that emits.
	var packed_end := _lay(_cylinder(burn_radius * 0.98, 0.004, packed, 0.98))
	packed_end.position = Vector3(0, 0, -length + 0.002)
	root.add_child(packed_end)

	var ash := _lay(_taper(burn_radius * 0.99, burn_radius * 1.04, 0.006, ASH, 0.99))
	ash.position = Vector3(0, 0, -length + 0.007)
	root.add_child(ash)

	var coal := _lay(_cylinder(burn_radius * 0.92, 0.0022, COAL, 0.6))
	var glow: StandardMaterial3D = coal.material_override
	glow.emission_enabled = true
	glow.emission = COAL
	glow.emission_energy_multiplier = 2.4
	coal.position = Vector3(0, 0, -length - 0.001)
	coal.name = "coal"
	root.add_child(coal)

	var light := OmniLight3D.new()
	light.name = "ember_light"
	light.light_color = COAL
	# A coal lights its own hand and the thing it is resting on, not the room.
	# At 0.9m every lit end on the bench was throwing onto every other object,
	# so a filter tip half a metre away photographed as if it were glowing.
	light.light_energy = 0.5
	light.omni_range = 0.34
	light.position = Vector3(0, 0, -length)
	root.add_child(light)


static func _build_vape(root: Node3D) -> void:
	# A slab, because that is what they are. Rounded by a second, inset slab
	# rather than by a radius the primitive does not have.
	var shell := BoxMesh.new()
	shell.size = Vector3(0.026, 0.011, 0.092)
	var body := MeshInstance3D.new()
	body.mesh = shell
	body.material_override = _plastic(PLASTIC, 0.42)
	root.add_child(body)

	var band := BoxMesh.new()
	band.size = Vector3(0.0268, 0.0086, 0.030)
	var trim := MeshInstance3D.new()
	trim.mesh = band
	trim.material_override = _plastic(Color("3a3f42"), 0.28)
	trim.position = Vector3(0, 0, 0.016)
	root.add_child(trim)

	var mouth := _lay(_cylinder(0.0052, 0.014, Color("111315"), 0.5))
	mouth.position = Vector3(0, 0, -0.050)
	root.add_child(mouth)

	# The one honest detail: the tank window, which is the only part of a vape
	# anybody ever actually looks at.
	var window := BoxMesh.new()
	window.size = Vector3(0.0272, 0.0052, 0.020)
	var tank := MeshInstance3D.new()
	tank.mesh = window
	var liquid := _plastic(Color("6d4b8f"), 0.12)
	liquid.emission_enabled = true
	liquid.emission = Color("6d4b8f")
	liquid.emission_energy_multiplier = 0.5
	tank.material_override = liquid
	tank.position = Vector3(0, 0, -0.024)
	tank.name = "tank"
	root.add_child(tank)

	var led := _cylinder(0.0016, 0.0012, COAL, 0.3)
	var led_material: StandardMaterial3D = led.material_override
	led_material.emission_enabled = true
	led_material.emission = COAL
	led_material.emission_energy_multiplier = 3.0
	led.position = Vector3(0, 0.0057, 0.030)
	led.name = "led"
	root.add_child(led)


static func _build_bong(root: Node3D) -> void:
	# Beaker base, straight tube, angled downstem and a bowl. Built to scale -
	# 0.30m tall, which is why it is the only one flagged two-handed.
	var base := _cylinder(0.052, 0.055, GLASS, 0.06)
	base.position = Vector3(0, 0.0275, 0)
	_glassify(base)
	root.add_child(base)

	var shoulder := _cone(0.026, 0.052, 0.048, GLASS)
	shoulder.position = Vector3(0, 0.079, 0)
	_glassify(shoulder)
	root.add_child(shoulder)

	var tube := _cylinder(0.026, 0.185, GLASS, 0.06)
	tube.position = Vector3(0, 0.195, 0)
	_glassify(tube)
	root.add_child(tube)

	var lip := _cylinder(0.030, 0.010, GLASS, 0.06)
	lip.position = Vector3(0, 0.292, 0)
	_glassify(lip)
	root.add_child(lip)

	# Water. Flat, still, and the reason the thing works.
	var water := _cylinder(0.049, 0.026, Color("2a3a33"), 0.05)
	water.position = Vector3(0, 0.020, 0)
	var wet: StandardMaterial3D = water.material_override
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.albedo_color = Color(0.16, 0.23, 0.20, 0.72)
	root.add_child(water)

	var downstem := _cylinder(0.0085, 0.085, GLASS, 0.06)
	downstem.rotation = Vector3(deg_to_rad(-45.0), 0, 0)
	downstem.position = Vector3(0, 0.052, -0.030)
	_glassify(downstem)
	root.add_child(downstem)

	var bowl := _cone(0.020, 0.0075, 0.024, GLASS)
	bowl.rotation = Vector3(deg_to_rad(-45.0), 0, 0)
	bowl.position = Vector3(0, 0.084, -0.062)
	_glassify(bowl)
	root.add_child(bowl)

	var packed := _cylinder(0.0165, 0.008, Color("5c6330"), 0.95)
	packed.rotation = Vector3(deg_to_rad(-45.0), 0, 0)
	packed.position = Vector3(0, 0.090, -0.068)
	packed.name = "bowl_pack"
	root.add_child(packed)

	# Resin, because a clean one belongs to nobody.
	var ring := _cylinder(0.0505, 0.004, RESIN, 0.9)
	ring.position = Vector3(0, 0.033, 0)
	root.add_child(ring)


## --- primitives ----------------------------------------------------------

static func _cylinder(radius: float, height: float, tint: Color, roughness: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _plastic(tint, roughness)
	# Godot's CylinderMesh stands up the Y axis and it is left standing. An
	# earlier version laid it down here, which suited the rolled shapes and
	# silently rotated every upright part of the bong ninety degrees - the
	# tube ended up floating horizontally beside the water it is supposed to
	# reach into. A helper that bakes in an orientation is only ever right for
	# the first caller; `_lay()` below is opt-in instead.
	return node


## Lay a cylinder over so it runs down -Z, which is the axis a held object
## points along.
static func _lay(node: MeshInstance3D) -> MeshInstance3D:
	node.rotation = Vector3(PI * 0.5, 0, 0)
	return node


## A truncated cone, which is what a hand-rolled anything actually is.
static func _taper(top: float, bottom: float, height: float, tint: Color, roughness: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 14
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _plastic(tint, roughness)
	return node


static func _cone(top: float, bottom: float, height: float, tint: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 14
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _plastic(tint, 0.1)
	return node


static func _plastic(tint: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = 0.0
	return material


static func _glassify(node: MeshInstance3D) -> void:
	var material: StandardMaterial3D = node.material_override
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(GLASS.r, GLASS.g, GLASS.b, 0.24)
	material.roughness = 0.05
	material.metallic = 0.1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
