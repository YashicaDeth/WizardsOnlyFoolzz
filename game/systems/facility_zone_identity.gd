extends Node3D
## Each facility zone reads as its own place, without clutter (Greg, 5 Oct
## ~19:00: "Facility zones: give each zone identity with props, textures and
## landmarks WITHOUT making it cluttered.").
##
## Per zone, on top of the shells `facility.gd` builds:
##   - its own surface set (ambientCG CC0, `art/textures/facility/`), swapped
##     onto that zone's walls and floor after the build;
##   - one landmark you can see from where you come in;
##   - three to six story props (Poly Haven CC0, `art/props/polyhaven/`), each
##     the one hero in its own pool of light, with empty floor between.
## Lighting stays the house rule: dark, green-white pools, red only on danger.
## Nothing here is named or written on.
##
## The Growing Floor and the examiner's station live in `vat_chamber.gd`
## (bone arches, the rows of failed vats, the lab tile) and already read as
## their own place; this node dresses the zones `facility.gd` owns.
##
## No class_name on purpose (see generated_model.gd); facility.gd preloads it.

const TUNNEL_KIT := preload("res://systems/facility_tunnel_kit.gd")

const TEXTURE_DIR := "res://art/textures/facility/"
const PROP_DIR := "res://art/props/polyhaven/"
const LAMP_COLOR := Color("d2ecc0")
## Dial (REMASTER_LOG imp-67): the ember glow on the Lower Works vessels. It is
## heat, not danger: copper-amber in the metal, never the danger red (the
## first pass, b5521d, rendered as four red bars over the heat lift). 0 = off.
const HEAT_GLOW_ENERGY := 1.4
const HEAT_COLOR := Color("b0782e")
## The painted route line wears into each zone's own floor set: this much of
## the paint colour over the floor's tint (it read as a lit debug stripe on
## the darker tile and plate in concrete).
const ROUTE_PAINT := 0.3
const ROUTE_COLOR := Color("81906f")
## Dial: the one sign over the arcade stalls flickers. false = steady.
const SIGN_FLICKER := true

## Zone -> surface -> [ambientCG set, tint]. The tint pulls each set into
## the house darkness; the sets themselves are what tell the zones apart.
const SURFACES := {
	"service_artery": {"wall": ["Concrete042A", Color("6c6860")], "floor": ["MetalWalkway010", Color("9a9a90")]},
	"service_arcade": {"wall": ["PaintedPlaster016", Color("6a665a")], "floor": ["Tiles133A", Color("4c4e46")]},
	"transit_lift": {"wall": ["CorrugatedSteel005", Color("5c5c56")], "floor": ["DiamondPlate008A", Color("5a5a56")]},
	"lower_works": {"wall": ["MetalPlates013", Color("7a7064")], "floor": ["DiamondPlate008A", Color("66665e")]},
	"heat_lift": {"wall": ["MetalPlates011", Color("6a5446")]},
}

## The hall wall slots `facility.gd` `_dress_walls` offers (zone, z of the
## slot): the zone's own hero prop, or "" for deliberate empty floor. A slot
## not listed falls back to the kit dressing.
const WALL_SLOTS := {
	"service_arcade": {
		-6: "steel_frame_shelves_01",
		-17: "industrial_storage_cart",
		-28: "",
		-38: "hand_truck",
		-49: "utility_box_02",
		-57: "",
	},
	"lower_works": {
		-72: "",
		-80: "old_military_compressor",
		-88: "drill_press_01",
		-96: "",
		-104: "portable_welding_cart",
		-112: "portable_generator",
		-120: "metal_tool_chest",
		-128: "",
	},
}

## Files that do not ship in metres (measured with the bounds below). The
## shutter file is a 1 m door; its slats run across, so it widens to a stall.
const PROP_SCALE := {"steel_frame_shelves_01": Vector3.ONE * 0.1, "rollershutter_door": Vector3(2.7, 1.0, 1.0)}
## Files that carry variants side by side: keep only this node. (The shutter's
## other variant is tagged with graffiti, and nothing here is written on.)
const PROP_KEEP := {"rollershutter_door": "rollershutter_door"}
## Files too clean for the house darkness: their albedo is dimmed by this.
const PROP_GRIME := {"rollershutter_door": Color(0.5, 0.52, 0.47)}

var _materials := {}
var _flicker: Array = []
var _clock := 0.0


## Called by `_dress_walls` for each wall slot. True = handled here (a zone
## prop placed or the slot left empty on purpose).
func wall_slot(zone: String, at: Vector3, inward: float) -> bool:
	if not WALL_SLOTS.has(zone):
		return false
	var slots: Dictionary = WALL_SLOTS[zone]
	var key := roundi(at.z)
	if not slots.has(key):
		return false
	var prop_id: String = slots[key]
	if prop_id != "":
		# Turned to face the hall, its back a hand's width off the wall.
		var prop := place(prop_id, at, Vector3(inward, 0, 0), zone, "hero")
		if prop != null:
			prop.position.x += inward * (float(prop.get_meta("depth", 1.0)) * 0.5 + 0.1)
	return true


## After the whole map is built: surfaces per zone, landmarks, the rest of
## the story props.
func apply(facility: Node3D) -> void:
	_reskin(facility)
	_service_artery()
	_service_arcade()
	_transit_lift()
	_lower_works(facility)
	_heat_lift()


func _process(delta: float) -> void:
	if _flicker.is_empty():
		return
	_clock += delta
	for entry: Array in _flicker:
		var level := _flicker_level(_clock)
		(entry[0] as StandardMaterial3D).emission_energy_multiplier = 1.6 * level
		(entry[1] as OmniLight3D).light_energy = 4.5 * level


## A tube on its way out: mostly on, a stutter every few seconds, now and
## then a dead half-second. Fixed pattern, no randomness.
static func _flicker_level(t: float) -> float:
	var cycle := fposmod(t, 6.3)
	if cycle > 5.2 and cycle < 5.75:
		return 0.08
	if cycle > 2.1 and cycle < 2.5:
		return 0.35 if fposmod(t * 23.0, 1.0) > 0.5 else 1.0
	return 0.92 + 0.08 * sin(t * 61.0)


# --- Zones ------------------------------------------------------------------

## Service artery (tunnel kit): cast concrete over a steel grate. Landmark: a
## caged lamp hung low over the crossroads, its silhouette seen straight down
## the artery from the staff door.
func _service_artery() -> void:
	var lamp := place("caged_hanging_light", Vector3(14.75, 2.75, -2.5), Vector3(1, 0, 0), "service_artery", "landmark")
	if lamp != null:
		_glow_under(lamp, Vector3(14.75, 2.6, -2.5), 1.6, 4.2)
	place("power_box_01", Vector3(10.75, 1.3, -4.3), Vector3(0, 0, 1), "service_artery", "hero")
	place("utility_box_01", Vector3(14.75, 0.0, -12.3), Vector3(0, 0, 1), "service_artery", "hero")


## Service Arcade: peeling plaster over grimy small tile. Landmark: a row of
## shuttered stalls on the west wall between the bays, one blank lightbox
## over them failing on and off.
func _service_arcade() -> void:
	for z: float in [-13.4, -17.95, -22.5]:
		place("rollershutter_door", Vector3(21.08, 0.0, z), Vector3(1, 0, 0), "service_arcade", "landmark")
	var box := MeshInstance3D.new()
	box.name = "StallLightbox"
	var mesh := BoxMesh.new()
	# A blank blade sign standing out from the wall over the middle stall,
	# so it faces you down the hall from the entry (laid flat on the wall it
	# showed only its edge from there).
	mesh.size = Vector3(1.1, 0.5, 0.12)
	box.mesh = mesh
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("2a3326")
	glow.emission_enabled = true
	glow.emission = LAMP_COLOR
	glow.emission_energy_multiplier = 1.6
	box.material_override = glow
	box.position = Vector3(21.65, 3.0, -17.95)
	_register(box, "service_arcade", "landmark")
	var spill := OmniLight3D.new()
	spill.name = "LightboxSpill"
	spill.light_color = LAMP_COLOR
	spill.light_energy = 4.5
	spill.omni_range = 9.0
	spill.omni_attenuation = 1.0
	spill.position = Vector3(22.6, 2.7, -17.95)
	add_child(spill)
	if SIGN_FLICKER:
		_flicker.append([glow, spill])


## Transit lift: corrugated shaft and landings. Landmark: a caged floodlight
## over the lift mouth on each level, the one fitting you walk towards.
func _transit_lift() -> void:
	for spot: Array in [[Vector3(28.0, 3.35, -58.15), Vector3(0, 0, 1)], [Vector3(28.0, -8.65, -66.4), Vector3(0, 0, -1)]]:
		var at: Vector3 = spot[0]
		var facing: Vector3 = spot[1]
		place("security_light", at, facing, "transit_lift", "landmark")
		var flood := SpotLight3D.new()
		flood.name = "LiftMouthFlood"
		flood.light_color = LAMP_COLOR
		flood.light_energy = 6.0
		flood.spot_range = 6.5
		flood.spot_angle = 38.0
		flood.spot_attenuation = 0.7
		add_child(flood)
		flood.look_at_from_position(at + facing * 0.4 + Vector3(0, -0.2, 0), at + facing * 3.0 + Vector3(0, -3.4, 0))
	place("power_box_01", Vector3(26.72, 1.2, -59.35), Vector3(1, 0, 0), "transit_lift", "hero")
	place("industrial_pastic_container", Vector3(31.4, -12.0, -68.6), Vector3(-1, 0, 0), "transit_lift", "hero")


## Lower Works: riveted rusted plate over diamond-plate floor. Landmark: the
## overhead crane straddling the route mid-hall, lit from its own trolley,
## and the process vessels glowing with heat at their base.
func _lower_works(facility: Node3D) -> void:
	var crane := place("overhead_crane", Vector3(28.0, -12.0, -96.0), Vector3(0, 0, 1), "lower_works", "landmark")
	if crane != null:
		# Its rails just under the trusses, the hook block down near the lamps.
		var top := _bounds(crane).end.y
		crane.position.y += -3.2 - top
		var work := SpotLight3D.new()
		work.name = "CraneWorkLight"
		work.light_color = LAMP_COLOR
		work.light_energy = 10.0
		work.spot_range = 12.0
		work.spot_angle = 30.0
		work.spot_attenuation = 0.6
		work.shadow_enabled = true
		work.distance_fade_enabled = true
		work.distance_fade_begin = 40.0
		work.distance_fade_length = 10.0
		add_child(work)
		work.look_at_from_position(Vector3(28.0, -7.6, -96.0), Vector3(28.0, -12.0, -96.2))
		# The girder catches light from below so its line reads from the lift.
		_glow_under(crane, Vector3(28.0, -8.8, -93.0), 7.0, 11.0)
		# And at each end of the bridge, so the whole span reads, not the hook.
		for x: float in [22.6, 33.4]:
			_glow_under(crane, Vector3(x, -6.6, -93.4), 5.0, 6.5)
	if HEAT_GLOW_ENERGY <= 0.0:
		return
	for prop in get_tree().get_nodes_in_group("facility_story_props"):
		if prop.get_parent() == facility and prop is MeshInstance3D and (prop as MeshInstance3D).mesh is CylinderMesh and prop.get_meta("facility_story_prop", "") == "tank" and prop.get_meta("facility_zone", "") == "lower_works":
			_heat_band(prop as MeshInstance3D)


## Heat lift: scorched plate in the shaft. Landmark: a vent grille over its
## 0D mouth breathing heat, seen down the hall past the crane. A tool cart
## at the mouth and drums at the top, nothing else.
func _heat_lift() -> void:
	var grille := Node3D.new()
	grille.name = "HeatGrille"
	grille.position = Vector3(28.0, -9.35, -120.12)
	_register(grille, "heat_lift", "landmark")
	var slat_hot := StandardMaterial3D.new()
	slat_hot.albedo_color = Color("1a0d08")
	slat_hot.emission_enabled = true
	slat_hot.emission = HEAT_COLOR
	slat_hot.emission_energy_multiplier = maxf(HEAT_GLOW_ENERGY, 0.3) * 0.5
	var frame := surface_material("MetalPlates011", Color("6a5446"))
	for row in 4:
		var slat := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(2.0, 0.045, 0.05)
		slat.mesh = bar
		slat.material_override = slat_hot
		slat.position = Vector3(0, -0.24 + row * 0.16, 0)
		grille.add_child(slat)
	# Dark louvres behind the hot slats, so it reads as a vent, not a sign.
	var back := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(2.1, 0.72, 0.04)
	back.mesh = plate
	back.material_override = frame
	back.position = Vector3(0, 0, -0.05)
	grille.add_child(back)
	for side: int in [-1, 1]:
		var stile := MeshInstance3D.new()
		var post := BoxMesh.new()
		post.size = Vector3(0.1, 0.72, 0.1)
		stile.mesh = post
		stile.material_override = frame
		stile.position = Vector3(side * 1.05, 0, 0.02)
		grille.add_child(stile)
	if HEAT_GLOW_ENERGY > 0.0:
		var breath := OmniLight3D.new()
		breath.name = "HeatGrilleWarmth"
		breath.light_color = HEAT_COLOR
		breath.light_energy = HEAT_GLOW_ENERGY
		breath.omni_range = 3.6
		breath.omni_attenuation = 1.3
		breath.position = grille.position + Vector3(0, -0.2, 0.6)
		add_child(breath)
	place("tool_cart", Vector3(24.2, -12.0, -118.4), Vector3(1, 0, 0), "heat_lift", "hero")
	place("Barrel_01", Vector3(25.0, 20.0, -125.0), Vector3(0, 0, 1), "heat_lift", "hero")
	place("Barrel_01", Vector3(25.7, 20.0, -125.5), Vector3(0, 0, 1), "heat_lift", "hero")


# --- Surfaces ----------------------------------------------------------------

## Which zone a shell piece belongs to, by where it stands. "" = leave it.
static func zone_at(at: Vector3) -> String:
	if at.y > 18.0:
		return ""
	if at.x > 26.0 and at.x < 30.0 and at.z < -117.5 and at.z > -126.5:
		return "heat_lift"
	if at.x > 26.0 and at.x < 30.0 and at.z < -58.45 and at.z > -66.05:
		return "transit_lift"
	if at.y > -1.0 and at.x > 8.0 and at.x < 20.8 and at.z > -17.0 and at.z < 4.0:
		return "service_artery"
	if at.y > -1.0 and at.x > 20.6 and at.x < 35.4 and at.z > -58.6 and at.z < 5.7:
		return "service_arcade"
	if at.y < -1.0 and at.x > 12.8 and at.x < 43.2 and at.z > -136.3 and at.z < -65.9:
		return "lower_works"
	return ""


func _reskin(facility: Node3D) -> void:
	var kit := {TUNNEL_KIT.material("wall"): "wall", TUNNEL_KIT.material("floor"): "floor"}
	var walls := {}
	for lift: Node3D in facility.get("lifts").values():
		var zone := "heat_lift" if lift.name == "HeatElevator" else "transit_lift"
		for body in lift.get_children():
			# The moving car keeps the kit's local-triplanar steel: a world-
			# triplanar zone set would swim over it as it rides.
			if body is StaticBody3D and body != lift.get("cab"):
				for part in body.get_children():
					if part is MeshInstance3D:
						walls[part] = zone
	for mesh: MeshInstance3D in facility.find_children("*", "MeshInstance3D", true, false):
		var is_route: bool = mesh.get_meta("facility_story_prop", "") == "route"
		if not is_route and (mesh.is_in_group("facility_story_props") or mesh.get_parent().is_in_group("facility_story_props")):
			continue
		var zone := ""
		var surface := ""
		if walls.has(mesh):
			zone = walls[mesh]
			surface = "wall"
		elif mesh.get_meta("facility_story_prop", "") == "route":
			zone = zone_at(mesh.global_position)
			# The line runs on past the halls into the lift mouths: it is the
			# hall's paint, so it wears the hall's floor on that level.
			if zone == "" or not SURFACES[zone].has("floor"):
				zone = "lower_works" if mesh.global_position.y < -1.0 else "service_arcade"
			if mesh.global_position.y < 18.0:
				var floor_set: Array = SURFACES[zone]["floor"]
				mesh.material_override = surface_material(floor_set[0], (floor_set[1] as Color).lerp(ROUTE_COLOR, ROUTE_PAINT))
			continue
		elif kit.has(mesh.material_override):
			surface = kit[mesh.material_override]
			zone = zone_at(mesh.global_position)
		if zone != "":
			var set: Dictionary = SURFACES[zone]
			mesh.material_override = surface_material(set[surface][0], set[surface][1])


## A zone surface: the same world-triplanar 2 m tiling as the tunnel kit, so
## the zones keep its PS2 crunch and meet without seams.
func surface_material(set_name: String, tint: Color) -> StandardMaterial3D:
	var key := "%s/%s" % [set_name, tint.to_html()]
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.roughness = 0.88
	var albedo := TEXTURE_DIR + set_name + "_Color.jpg"
	if ResourceLoader.exists(albedo):
		made.albedo_texture = load(albedo)
		made.albedo_color = tint
		for map: String in ["NormalGL", "Roughness", "Metalness"]:
			var path := TEXTURE_DIR + "%s_%s.jpg" % [set_name, map]
			if not ResourceLoader.exists(path):
				continue
			match map:
				"NormalGL":
					made.normal_enabled = true
					made.normal_texture = load(path)
				"Roughness":
					made.roughness_texture = load(path)
					made.roughness = 1.0
				"Metalness":
					made.metallic_texture = load(path)
					made.metallic = 1.0
		made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		made.uv1_triplanar = true
		made.uv1_world_triplanar = true
		made.uv1_scale = Vector3.ONE / TUNNEL_KIT.TILE_METRES
	else:
		made.albedo_color = tint.darkened(0.6)
	_materials[key] = made
	return made


# --- Props -------------------------------------------------------------------

## A Poly Haven prop standing on `at` (its base centred there), its front
## (+Z in the file) turned to `facing`. Null when the file is missing.
func place(prop_id: String, at: Vector3, facing: Vector3, zone: String, kind: String) -> Node3D:
	var path := PROP_DIR + "%s/%s_1k.gltf" % [prop_id, prop_id]
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	var holder := Node3D.new()
	holder.name = prop_id.to_pascal_case()
	holder.add_child(model)
	if PROP_KEEP.has(prop_id):
		for part in model.get_children():
			if part.name != PROP_KEEP[prop_id]:
				model.remove_child(part)
				part.free()
	model.scale *= PROP_SCALE.get(prop_id, Vector3.ONE) as Vector3
	var box := _bounds(model)
	model.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	holder.basis = Basis.looking_at(-facing, Vector3.UP)
	holder.position = at
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		_matte(mesh, PROP_GRIME.get(prop_id, Color.WHITE))
		# Props in a pool do not need to darken their neighbours' pools.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind == "landmark" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_register(holder, zone, kind)
	holder.set_meta("facility_prop_source", prop_id)
	holder.set_meta("depth", box.size.z)
	return holder


## The facility has no sky or reflection probe, so bare metal reflects black:
## the shutters rendered as a lone highlight bar. Painted, dirty metal it is.
func _matte(mesh: MeshInstance3D, grime: Color) -> void:
	for index in mesh.get_surface_override_material_count():
		var source := mesh.get_active_material(index) as StandardMaterial3D
		if source == null:
			continue
		var key := "matte/%d" % source.get_instance_id()
		if not _materials.has(key):
			var made := source.duplicate() as StandardMaterial3D
			made.metallic = minf(made.metallic, 1.0) * 0.3
			made.albedo_color *= grime
			_materials[key] = made
		mesh.set_surface_override_material(index, _materials[key])


func _register(prop: Node3D, zone: String, kind: String) -> void:
	add_child(prop)
	prop.set_meta("facility_story_prop", kind)
	prop.set_meta("facility_zone", zone)
	prop.add_to_group("facility_story_props")
	prop.add_to_group("facility_zone_identity")


## Combined mesh bounds of `root`, in root's parent space.
static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var base := root.transform
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var into := base * _relative(root, mesh)
		var part := into * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != root:
		if at is Node3D:
			t = (at as Node3D).transform * t
		at = at.get_parent()
	return t


## A soft light just under a hung landmark so its outline reads in the dark.
func _glow_under(prop: Node3D, at: Vector3, energy: float, reach: float) -> void:
	var glow := OmniLight3D.new()
	glow.name = "%sGlow" % prop.name
	glow.light_color = LAMP_COLOR
	glow.light_energy = energy
	glow.omni_range = reach
	glow.omni_attenuation = 1.3
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 40.0
	glow.distance_fade_length = 10.0
	glow.position = at
	add_child(glow)


## The heat in a Lower Works vessel: a dull ember band in the metal at its
## foot and the warmth it throws on the floor round it.
func _heat_band(tank: MeshInstance3D) -> void:
	var cylinder := tank.mesh as CylinderMesh
	if cylinder == null:
		return
	var band := MeshInstance3D.new()
	band.name = "HeatBand"
	var ring := CylinderMesh.new()
	ring.top_radius = cylinder.bottom_radius * 1.015
	ring.bottom_radius = cylinder.bottom_radius * 1.02
	ring.height = 0.28
	ring.radial_segments = cylinder.radial_segments
	ring.cap_top = false
	ring.cap_bottom = false
	band.mesh = ring
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color("1a0d08")
	ember.emission_enabled = true
	ember.emission = HEAT_COLOR
	ember.emission_energy_multiplier = HEAT_GLOW_ENERGY
	ember.roughness = 0.6
	band.material_override = ember
	band.position = tank.position + Vector3(0, -cylinder.height * 0.5 + 0.55, 0)
	_register(band, "lower_works", "heat")
	var warmth := OmniLight3D.new()
	warmth.name = "HeatWarmth"
	warmth.light_color = HEAT_COLOR
	warmth.light_energy = HEAT_GLOW_ENERGY * 0.9
	warmth.omni_range = cylinder.bottom_radius + 2.4
	warmth.omni_attenuation = 1.4
	warmth.distance_fade_enabled = true
	warmth.distance_fade_begin = 36.0
	warmth.distance_fade_length = 8.0
	warmth.position = band.position + Vector3(0, -0.2, 0)
	add_child(warmth)
