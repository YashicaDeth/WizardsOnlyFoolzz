extends Node3D
## Original mechanical blockout. No retail maps, assets or game code.
var arena: Node3D
var player: CharacterBody3D
var camera: Camera3D
var model: Node3D
var hud: Label
var prompt: Label
var menu: PanelContainer
var crosshair: Label
var rng = RandomNumberGenerator.new()
var mode = "menu"
var run_seed = 7707
var hp = 100.0
var speed = 0.0
var boost = 100.0
var credits = 0
var ammo = 24
var score = 0
var timer = 90.0
var yaw = 0.0
var pitch = -0.12
var first_person = false
var cooldown = 0.0
var hit_cooldown = 0.0
var bots: Array = []
var loot: Array = []
var traders: Array = []
var landmarks: Array = []
var ended = false
var notice = ""
var notice_time = 0.0
var last_impact_zone = "HULL INTACT"
var combo = 0
var combo_time = 0.0
var heat = 0
var risk_multiplier = 1.0
var event_time = 0.0
var event_name = "NO ACTIVE BOUNTY"
var contract_name = "UNASSIGNED"
var contract_type = 0
var contract_target = 3
var contract_progress = 0
var contract_bonus = 250
var contract_complete = false
var karma_path = "LIMBO"
var banter_cooldown = 0.0
var radio_cooldown = 8.0
var contract_settled = false
var dossier: Label
var chronicle = {"runs": 0, "best": 0, "pages": []}
const PROFILE = "user://celloutz-chronicle-v1.json"
var fx_rng = RandomNumberGenerator.new()
var sky = Color("191e27")
var copper = Color("c87750")
var teal = Color("68b9af")

func _ready():
	fx_rng.randomize()
	load_chronicle()
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8b4ad")
	env.ambient_light_energy = 0.55
	world.environment = env
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("ffd2a8")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.far = 300
	add_child(camera)
	make_ui()
	start("derby", 7707)
	show_menu()
	if "--lab-smoke" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	if "--lab-capture" in OS.get_cmdline_user_args():
		call_deferred("capture_preview")

func material(color: Color, emission = false):
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
	if emission:
		m.emission_enabled = true
		m.emission = color
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid = false):
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		var body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		var bounds = BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.position = pos
		parent.add_child(body)
		body.add_child(collision)
	return mesh

func sign_at(text: String, pos: Vector3, color = Color("f4d6b0")):
	var label = Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 24
	label.pixel_size = 0.024
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arena.add_child(label)
	return label

func actor(pos: Vector3, color: Color, boat: bool):
	var body = CharacterBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.1, 1.3, 3.3) if boat else Vector3(0.7, 1.8, 0.7)
	collision.shape = shape
	collision.position.y = 0.8
	body.add_child(collision)
	arena.add_child(body)
	body.position = pos
	var visual = Node3D.new()
	body.add_child(visual)
	if boat:
		box(visual, Vector3(0, 0.8, 0), Vector3(2, 0.65, 3.5), color)
		box(visual, Vector3(0, 1.25, 0.3), Vector3(1.2, 0.6, 1.5), color.lightened(0.15))
		box(visual, Vector3(0, 1.3, -0.49), Vector3(1.05, 0.38, 0.06), Color("162e32"))
		var left_panel: MeshInstance3D
		var right_panel: MeshInstance3D
		for x in [-1.05, 1.05]:
			for z in [-1.1, 1.1]:
				var panel = box(visual, Vector3(x, 0.38, z), Vector3(0.35, 0.65, 0.65), Color("25282a"))
				if x < 0: left_panel = panel
				else: right_panel = panel
		box(visual, Vector3(0, 0.8, -1.85), Vector3(1.7, 0.35, 0.35), Color("d7bb88"))
		body.set_meta("left_panel", left_panel)
		body.set_meta("right_panel", right_panel)
	else:
		box(visual, Vector3(0, 0.85, 0), Vector3(0.65, 1.3, 0.4), color)
		var driver_part = box(visual, Vector3(0, 1.7, 0), Vector3(0.42, 0.4, 0.4), Color("c7ae91"))
		var right_arm = box(visual, Vector3(0.42, 1.13, -0.35), Vector3(0.2, 0.2, 0.85), Color("28262d"))
		var left_arm = box(visual, Vector3(-0.42, 1.13, -0.35), Vector3(0.2, 0.2, 0.85), Color("28262d"))
		body.set_meta("driver_part", driver_part)
		body.set_meta("right_panel", right_arm)
		body.set_meta("left_panel", left_arm)
	body.set_meta("visual", visual)
	if boat and ResourceLoader.exists("res://art/scrap_skiff.glb"):
		for child in visual.get_children():
			visual.remove_child(child)
			child.queue_free()
		var skiff = load("res://art/scrap_skiff.glb").instantiate()
		visual.add_child(skiff)
		for key in ["left_panel", "right_panel", "driver_part"]:
			var part = skiff.find_child("driver_head" if key == "driver_part" else key, true, false)
			body.set_meta(key,part)
		var hull = skiff.find_child("hull",true,false)
		if hull: hull.material_override = material(color)
	return body

func start(which: String, seed_value: int):
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
	arena = Node3D.new()
	add_child(arena)
	bots.clear()
	loot.clear()
	traders.clear()
	landmarks.clear()
	mode = which
	run_seed = seed_value
	rng.seed = run_seed
	hp = 100
	last_impact_zone = "HULL INTACT"
	combo = 0
	combo_time = 0.0
	heat = 0
	risk_multiplier = 1.0
	event_time = 0.0
	event_name = "NO ACTIVE BOUNTY"
	contract_progress = 0
	contract_complete = false
	contract_settled = false
	roll_contract()
	cooldown = 0.0
	hit_cooldown = 0.0
	first_person = false
	banter_cooldown = 0.0
	radio_cooldown = 8.0
	speed = 0
	boost = 100
	credits = 0
	ammo = 24
	score = 0
	timer = 90
	yaw = 0
	pitch = -0.12
	ended = false
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "world" else Input.MOUSE_MODE_VISIBLE
	if mode == "derby":
		build_derby()
	else:
		build_world()
	model = player.get_meta("visual")
	camera.position = player.position + Vector3(0, 6, 10)
	message("RAM / BREAK / COLLECT" if mode == "derby" else "Explore outposts. Recover salvage. Return to the teal market.")

func build_derby():
	var ground = box(arena, Vector3(0,-0.55,0), Vector3(76,1,76), Color("292b2a"), true)
	var ground_mat = material(Color("323431"))
	var noise = FastNoiseLite.new()
	noise.seed = 7707
	noise.frequency = 0.12
	var texture = NoiseTexture2D.new()
	texture.noise = noise
	ground_mat.albedo_texture = texture
	ground_mat.uv1_scale = Vector3(16,16,16)
	ground.material_override = ground_mat
	for z in [-38,38]: box(arena,Vector3(0,1.5,z),Vector3(78,3,1),Color("663b2d"),true)
	for x in [-38,38]: box(arena,Vector3(x,1.5,0),Vector3(1,3,78),Color("663b2d"),true)
	for i in range(12):
		var a = i * TAU / 12
		box(arena, Vector3(cos(a)*21,0.75,sin(a)*21), Vector3(3,1.5,3), Color("807564"),true)
	for i in range(5):
		var pos = Vector3(cos(i*TAU/5)*28,0.2,sin(i*TAU/5)*28)
		var body = actor(pos, copper if i%2==0 else Color("855347"),true)
		bots.append({"body":body,"hp":60.0,"cooldown":0.0,"name":contract_name if i==0 else "WRECKER %02d" % (i+1),"marked":i==0})
		if i==0:
			var tag=sign_at("BOUNTY / "+contract_name,Vector3(0,3.3,0),Color("ffcf81"))
			tag.reparent(body,false)
	player = actor(Vector3(0,0.2,12),teal,true)
	sign_at("C E L L O U T Z\nSCRAP TIDE / WRECKING YARD",Vector3(0,6,-35))
	for z in range(-32,33,8):
		box(arena,Vector3(0,0.01,z),Vector3(0.3,0.03,3),Color("c2a07d"))
	for x in [-34,34]:
		for z in [-28,0,28]:
			box(arena,Vector3(x,4,z),Vector3(.3,8,.3),Color("383f40"))
			box(arena,Vector3(x,7.5,z),Vector3(2,.3,.5),teal)
	if ResourceLoader.exists("res://art/polarity.webp"):
		var billboard=box(arena,Vector3(0,8,-37),Vector3(12,10,.2),Color.WHITE)
		var paint=material(Color.WHITE)
		paint.albedo_texture=load("res://art/polarity.webp")
		billboard.material_override=paint

func build_world():
	box(arena,Vector3(0,-0.55,0),Vector3(220,1,220),Color("6d6651"),true)
	box(arena,Vector3(0,0.01,0),Vector3(9,0.03,205),Color("34393c"))
	box(arena,Vector3(0,0.02,0),Vector3(205,0.03,9),Color("34393c"))
	player = actor(Vector3(0,0.1,12),teal,false)
	var cells: Array = []
	for x in [-65,0,65]:
		for z in [-65,0,65]:
			if x != 0 or z != 0: cells.append(Vector3(x,0,z))
	# Fisher-Yates uses this run's RNG, so layouts reproduce from a seed.
	for i in range(cells.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var tmp = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	var names = ["DUST EXCHANGE","ASH RELAY","THE SUNKEN GATE","BROKEN CROWN","SALT DEPOT","DEAD SIGNAL"]
	for i in range(6):
		var pos = cells[i] + Vector3(rng.randf_range(-6,6),0,rng.randf_range(-6,6))
		landmarks.append({"name":names[i],"position":pos})
		var tint = teal if i == 0 else copper
		box(arena,pos+Vector3(0,0.1,0),Vector3(22,0.2,22),Color("403d38"))
		for j in range(3):
			var h = rng.randf_range(3,7)
			box(arena,pos+Vector3(-8+j*8,h/2,-8),Vector3(5,h,5),Color("847662"),true)
		if i % 2 == 0:
			box(arena,pos+Vector3(-4,5,3),Vector3(1.3,10,1.3),tint,true)
			box(arena,pos+Vector3(4,5,3),Vector3(1.3,10,1.3),tint,true)
			box(arena,pos+Vector3(0,10,3),Vector3(10,1.4,2),tint,true)
		else:
			for j in range(4): box(arena,pos+Vector3(0,j*2+1,0),Vector3(7-j,2,7-j),tint,true)
		sign_at(names[i]+("\nWAYFARERS / TRADE" if i == 0 else "\nCINDERS / HOSTILE"),pos+Vector3(0,13,0),tint)
		if i == 0:
			var trader = actor(pos+Vector3(0,0,8),teal,false)
			traders.append(trader)
		else:
			for j in range(2):
				var body = actor(pos+Vector3(-4+j*8,0,7),copper,false)
				bots.append({"body":body,"hp":45.0,"cooldown":0.0,"name":"CINDER %02d" % (i*2+j)})
		for j in range(3): add_loot(pos+Vector3(-7+j*7,0.7,11))
	# Small neutral shop close to spawn makes the first loop readable.
	var vendor = actor(Vector3(7,0,9),teal,false)
	traders.append(vendor)
	sign_at("WAYFARER\n5 SCRAP = REPAIR + 12 AMMO",Vector3(7,3,9),teal)
	for i in range(50):
		var pos = Vector3(rng.randf_range(-100,100),0,rng.randf_range(-100,100))
		if abs(pos.x)<12 or abs(pos.z)<12: continue
		var near = false
		for mark in landmarks:
			if pos.distance_to(mark.position)<19: near=true
		if not near: box(arena,pos+Vector3(0,1,0),Vector3(rng.randf_range(1,4),2,rng.randf_range(1,4)),Color("61594c"),true)

func add_loot(pos: Vector3):
	var mesh = box(arena,pos,Vector3(0.9,0.7,0.9),Color("e0b16b"))
	loot.append(mesh)

func roll_contract():
	var names = ["THE COPPER SAINT", "MOTH-EATEN JACKAL", "THE LAST BOATMAN", "SALT-WOUND MARAUDER", "TEAL VULTURE"]
	contract_type = rng.randi_range(0,2)
	contract_name = names[rng.randi_range(0,names.size()-1)]
	contract_target = [3,4,1][contract_type]
	contract_bonus = 250 + rng.randi_range(0,3)*75

func resolve_contract():
	if contract_settled: return
	contract_settled = true
	contract_complete = contract_progress >= contract_target
	if contract_complete:
		score += contract_bonus
		message("CONTRACT CLEARED / %s / +%d bonus" % [contract_name,contract_bonus])
	else:
		message("CONTRACT EXPIRED / %s / %d of %d" % [contract_name,contract_progress,contract_target])
	if hp>0 and contract_complete:
		var page=karma_path+" / "+contract_name
		if not page in chronicle.pages: chronicle.pages.append(page)
	chronicle.runs+=1
	chronicle.best=max(chronicle.best,score)
	if not "--lab-smoke" in OS.get_cmdline_user_args():
		var save=FileAccess.open(PROFILE,FileAccess.WRITE)
		if save: save.store_string(JSON.stringify(chronicle))

func load_chronicle():
	if "--lab-smoke" in OS.get_cmdline_user_args(): return
	if FileAccess.file_exists(PROFILE):
		var record=JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
		if record is Dictionary and record.get("pages") is Array:
			chronicle={"runs":int(record.get("runs",0)),"best":int(record.get("best",0)),"pages":record.pages}

func detach_part(part):
	if not is_instance_valid(part) or not part.visible: return
	var debris=RigidBody3D.new()
	var mesh=part.duplicate()
	debris.add_child(mesh)
	arena.add_child(debris)
	debris.global_transform=part.global_transform
	mesh.transform=Transform3D.IDENTITY
	debris.collision_layer=0
	debris.collision_mask=0
	debris.linear_velocity=Vector3(fx_rng.randf_range(-4,4),5,fx_rng.randf_range(-4,4))
	debris.angular_velocity=Vector3(3,2,5)
	part.hide()
	get_tree().create_timer(3).timeout.connect(func():
		if is_instance_valid(debris): debris.queue_free())

func make_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(28,20)
	hud.add_theme_font_size_override("font_size",22)
	hud.add_theme_color_override("font_color",Color("f4ddba"))
	canvas.add_child(hud)
	var hud_style=StyleBoxFlat.new()
	hud_style.bg_color=Color(0.035,0.045,0.045,.92)
	hud_style.border_color=teal
	hud_style.set_border_width_all(1)
	hud_style.set_content_margin_all(14)
	hud.add_theme_stylebox_override("normal",hud_style)
	hud.add_theme_font_size_override("font_size",18)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -86
	prompt.offset_left = 28
	prompt.offset_right = -28
	prompt.add_theme_stylebox_override("normal",hud_style)
	prompt.add_theme_font_size_override("font_size",18)
	canvas.add_child(prompt)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.add_theme_font_size_override("font_size",28)
	canvas.add_child(crosshair)
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(330,125)
	menu.size = Vector2(620,460)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("170e12")
	style.border_color = copper
	style.set_border_width_all(2)
	style.set_content_margin_all(32)
	menu.add_theme_stylebox_override("panel",style)
	canvas.add_child(menu)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",20)
	menu.add_child(column)
	var title = Label.new()
	title.text = "CELL OUTZ / FIELD GUIDE\nSCRAP TIDE"
	title.add_theme_font_size_override("font_size",26)
	column.add_child(title)
	var resume = Button.new()
	resume.text = "Resume current run"
	resume.custom_minimum_size.y = 38
	resume.pressed.connect(func():
		menu.hide()
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if mode=="world" else Input.MOUSE_MODE_VISIBLE)
	column.add_child(resume)
	for item in [["01   SCRAP TIDE — demolition driving","derby"],["02   DUST CIRCUIT — seeded sandbox","world"]]:
		var button = Button.new()
		button.text = item[0]
		button.custom_minimum_size.y = 65
		button.pressed.connect(start.bind(item[1],run_seed))
		column.add_child(button)
	var help = Label.new()
	help.text = "WASD drive · Shift boost · F cockpit / chase camera\nR retry seed · N new seed · Esc pause\nDust Circuit: mouse aim · click fire · E loot / trade"
	column.add_child(help)
	var paths=HBoxContainer.new()
	column.add_child(paths)
	for path in ["ASCENT","LIMBO","DESCENT"]:
		var choose=Button.new()
		choose.text=path
		choose.pressed.connect(func(): karma_path=path; refresh_dossier())
		paths.add_child(choose)
	dossier=Label.new()
	dossier.add_theme_font_size_override("font_size",15)
	dossier.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(dossier)
	refresh_dossier()
	var radar=Control.new()
	radar.position=Vector2(1040,24)
	radar.custom_minimum_size=Vector2(210,210)
	radar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(radar)
	radar.draw.connect(func():
		if mode!="world" or menu.visible: return
		radar.draw_rect(Rect2(0,0,200,200),Color(0.06,0.08,0.08,0.85))
		radar.draw_rect(Rect2(0,0,200,200),teal,false,1)
		radar.draw_line(Vector2(100,5),Vector2(100,195),Color("615f4b"),6)
		radar.draw_line(Vector2(5,100),Vector2(195,100),Color("615f4b"),6)
		for mark in landmarks:
			var point=Vector2(mark.position.x,mark.position.z)*0.9+Vector2(100,100)
			radar.draw_circle(point,5,copper)
		for trader in traders:
			radar.draw_circle(Vector2(trader.position.x,trader.position.z)*0.9+Vector2(100,100),3,teal)
		var p=Vector2(player.position.x,player.position.z)*0.9+Vector2(100,100)
		radar.draw_circle(p,4,Color.WHITE)
		radar.draw_line(p,p+Vector2(-sin(yaw),-cos(yaw))*12,Color.WHITE,2))
	get_tree().process_frame.connect(func():
		radar.position.x=get_viewport().get_visible_rect().size.x-224
		radar.queue_redraw())

func show_menu():
	menu.visible = true
	refresh_dossier()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crosshair.visible = false

func refresh_dossier():
	if not is_instance_valid(dossier): return
	dossier.text="TREE / %s   PAGES %d   BEST %d\n" % [karma_path,chronicle.pages.size(),chronicle.best]
	dossier.text+="Clear a contract and survive to inscribe a page.\n" if chronicle.pages.is_empty() else str(chronicle.pages[-1])+"\n"
	menu.position=Vector2(max(12,(get_viewport().get_visible_rect().size.x-620)/2),35)

func message(value: String):
	notice = value
	notice_time = 4.0

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: start("derby",run_seed)
			KEY_2: start("world",run_seed)
			KEY_ESCAPE: show_menu()
			KEY_R: start(mode,run_seed)
			KEY_N: start(mode,randi_range(1,999999))
			KEY_F: first_person = not first_person
			KEY_E:
				if mode=="world" and not menu.visible and not ended: interact()
	if event is InputEventMouseMotion and mode=="world" and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clamp(pitch-event.relative.y*0.003,-1.1,0.7)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and mode=="world" and not menu.visible and not ended:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		shoot()

func _physics_process(delta):
	if not is_instance_valid(player): return
	if menu.visible: return
	cooldown=max(0,cooldown-delta)
	hit_cooldown=max(0,hit_cooldown-delta)
	notice_time=max(0,notice_time-delta)
	banter_cooldown=max(0,banter_cooldown-delta)
	radio_cooldown=max(0,radio_cooldown-delta)
	combo_time=max(0,combo_time-delta)
	if combo_time<=0: combo=0
	if event_time>0:
		event_time=max(0,event_time-delta)
		if event_time<=0:
			risk_multiplier=1.0
			event_name="NO ACTIVE BOUNTY"
	if not ended:
		if mode=="derby": drive(delta)
		else: walk(delta)
		if not ended: update_bots(delta)
		if mode == "world" and radio_cooldown <= 0:
			radio_burst()
			radio_cooldown = 18.0
		if hp<=0:
			ended=true
			if mode=="derby": resolve_contract()
			message("WRECKED / Press R to retry this seed or N for another")
	update_camera(delta)
	update_hud()

func drive(delta):
	var throttle = float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S))
	var steer = float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D))
	var boosting = Input.is_physical_key_pressed(KEY_SHIFT) and boost>1 and throttle>0
	boost=clamp(boost+(-35 if boosting else 17)*delta,0,100)
	speed=move_toward(speed,throttle*(31 if boosting else 20),delta*(18 if throttle!=0 else 9))
	player.rotation.y += steer * clamp(abs(speed)/8,0,1) * 1.8 * delta * (-1 if speed<0 else 1)
	var forward = -player.basis.z
	player.velocity=Vector3(forward.x*speed,-2,forward.z*speed)
	player.move_and_slide()
	for i in range(player.get_slide_collision_count()):
		var collision = player.get_slide_collision(i)
		var collider=collision.get_collider()
		for bot in bots:
			if bot.body==collider and bot.hp>0 and bot.cooldown<=0 and abs(speed)>5:
				damage_bot(bot,abs(speed)*1.4, impact_zone(bot, collision.get_position()))
				hp-=3
				speed*=0.45
	timer=max(0,timer-delta)
	for item in loot.duplicate():
		if player.position.distance_to(item.position)<3:
			score+=int(25*risk_multiplier)
			hp=min(100,hp+6)
			loot.erase(item)
			item.queue_free()
			if contract_type == 1: contract_progress += 1
	if timer<=0 or (alive_bots()==0 and (contract_type!=1 or contract_progress>=contract_target)):
		ended=true
		resolve_contract()

func walk(delta):
	player.rotation.y=yaw
	var input=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var direction=player.basis*Vector3(input.x,0,input.y)
	var pace=10 if Input.is_physical_key_pressed(KEY_SHIFT) else 6
	player.velocity.x=direction.x*pace
	player.velocity.z=direction.z*pace
	player.velocity.y-=22*delta
	if player.is_on_floor(): player.velocity.y=-1
	player.move_and_slide()
	player.position.x=clamp(player.position.x,-105,105)
	player.position.z=clamp(player.position.z,-105,105)
	model.visible=not first_person

func update_bots(delta):
	for bot in bots:
		if bot.hp<=0: continue
		bot.cooldown=max(0,bot.cooldown-delta)
		var body=bot.body
		var difference=player.position-body.position
		difference.y=0
		var distance=difference.length()
		if mode=="world" and distance>24: continue
		if distance>0.01:
			body.rotation.y=lerp_angle(body.rotation.y,atan2(-difference.x,-difference.z),delta*2.2)
		var direction=-body.basis.z if mode=="derby" else difference.normalized()
		var handicap=0.35 if bot.get("driver_lost",false) else 1.0
		body.velocity=direction*(12 if mode=="derby" else 3.2)*handicap
		body.velocity.y=-4
		body.move_and_slide()
		if distance<(3.2 if mode=="derby" else 1.9) and hit_cooldown<=0:
			hp-=8 if mode=="derby" else 9
			hit_cooldown=0.9
			message("IMPACT" if mode=="derby" else "%s hit you / keep moving" % bot.name)
		if mode == "world" and distance < 8.0 and banter_cooldown <= 0:
			proximity_banter(bot)
			banter_cooldown = 5.5
	if mode=="world" and banter_cooldown<=0:
		for trader in traders:
			if player.position.distance_to(trader.position)<5:
				proximity_banter({"name":"WAYFARER"})
				banter_cooldown=8
				break

func proximity_banter(bot: Dictionary):
	var cinder_lines = [
		"CINDER: You walk like the road owes you money.",
		"CINDER: Keep the gun low. The dead are listening.",
		"CINDER: Wayfarer prices are a joke with teeth."
	]
	var lines = cinder_lines if bot.name.begins_with("CINDER") else [
		"WAYFARER: Easy, hunter. Your shadow is already shopping.",
		"WAYFARER: I saw your bounty before I saw your face.",
		"WAYFARER: Trade clean, leave breathing."
	]
	message(lines[rng.randi_range(0,lines.size()-1)])

func radio_burst():
	var lines = [
		"RADIO // a voice from above is counting your footsteps.",
		"RADIO // below the salt line, somebody has redrawn the tree.",
		"RADIO // LIMBO WEATHER: memory visibility dropping.",
		"RADIO // bounty notice updated / target remembers your mercy."
	]
	message(lines[rng.randi_range(0,lines.size()-1)])

func impact_zone(bot: Dictionary, hit_position: Vector3) -> String:
	var local_hit = bot.body.to_local(hit_position)
	if local_hit.y > 1.35 and not bot.get("driver_lost", false): return "DRIVER"
	if abs(local_hit.x) > 0.65: return "LEFT SIDE" if local_hit.x < 0 else "RIGHT SIDE"
	return "HULL"

func damage_bot(bot: Dictionary, amount: float, zone: String = "HULL"):
	if bot.hp<=0 or amount<=0: return
	last_impact_zone = zone
	if zone == "DRIVER":
		bot.driver_hp = bot.get("driver_hp", 35.0) - amount
		if bot.driver_hp <= 0 and not bot.get("driver_lost", false):
			bot.driver_lost = true
			var driver_part = bot.body.get_meta("driver_part", null)
			if driver_part: detach_part(driver_part)
			message("DRIVER DOWN / steering compromised")
		else: message("DRIVER HIT / %d integrity" % max(0, int(bot.driver_hp)))
		bot.hp-=amount*0.5
	else:
		if zone.ends_with("SIDE"):
			var side_key = "left_side_hp" if zone.begins_with("LEFT") else "right_side_hp"
			bot[side_key] = bot.get(side_key, 35.0) - amount
			var side_part = bot.body.get_meta("left_panel" if zone.begins_with("LEFT") else "right_panel", null)
			if bot[side_key] <= 0 and side_part and side_part.visible:
				detach_part(side_part)
				message("%s / panel torn away" % zone)
			else: message("%s / %d integrity" % [zone, max(0, int(bot[side_key]))])
			bot.hp-=amount*1.25
		else:
			bot.hp-=amount
			message("HULL / %d integrity" % max(0,bot.hp))
	bot.cooldown=0.6
	score+=int(amount)
	if bot.hp<=0:
		var pos=bot.body.position
		bot.body.hide()
		bot.body.collision_layer=0
		bot.body.collision_mask=0
		for i in range(3): add_loot(pos+Vector3(i-1,0.7,i%2))
		if mode == "derby":
			if contract_type == 0: contract_progress += 1
			if contract_type == 2 and bot.get("marked",false): contract_progress=1
			combo+=1
			combo_time=7.0
			heat+=1
			score+=int(100*risk_multiplier)
			if combo%2==0: roll_bounty_event()

func roll_bounty_event():
	var event = rng.randi_range(0,2)
	event_time=12.0
	if event==0:
		risk_multiplier=1.5
		event_name="BOUNTY SURGE / 1.5X SCRAP"
		message("BOUNTY SURGE / chain the next wreck for 1.5X scrap")
	elif event==1:
		boost=100
		risk_multiplier=1.25
		event_name="CLEAN LINE / FULL BOOST"
		message("CLEAN LINE / full boost restored, keep the streak alive")
	else:
		risk_multiplier=2.0
		event_name="REDLINE / 2X BOUNTY"
		message("REDLINE / bounty doubled for 12 seconds")

func shoot():
	if cooldown>0: return
	if ammo<=0: message("OUT OF AMMO / Find salvage or trade at a teal outpost"); return
	ammo-=1
	cooldown=0.25
	var from=camera.global_position
	var to=from-camera.global_basis.z*90
	var query=PhysicsRayQueryParameters3D.create(from,to)
	query.exclude=[player.get_rid()]
	var result=get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		to=result.position
		for bot in bots:
			if bot.body==result.collider and bot.hp>0: damage_bot(bot,25,impact_zone(bot,result.position))
	var mesh=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,material(Color("ffe4a2"),true))
	mesh.surface_add_vertex(player.position+Vector3(0.35,1.3,0))
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var tracer=MeshInstance3D.new()
	tracer.mesh=mesh
	arena.add_child(tracer)
	get_tree().create_timer(0.09).timeout.connect(func(): if is_instance_valid(tracer): tracer.queue_free())

func interact():
	for trader in traders:
		if player.position.distance_to(trader.position)<3:
			if credits>=5:
				credits-=5; hp=min(100,hp+40); ammo+=12
				message("TRADE / 5 scrap for repairs and 12 rounds")
			else: message("WAYFARERS / Bring 5 scrap. Gold caches contain salvage.")
			return
	for item in loot.duplicate():
		if player.position.distance_to(item.position)<3:
			credits+=3; ammo+=3
			loot.erase(item); item.queue_free()
			message("SALVAGED / +3 scrap / +3 rounds")
			return
	message("Move closer to a gold cache or teal trader")

func alive_bots():
	var total=0
	for bot in bots:
		if bot.hp>0: total+=1
	return total

func update_camera(delta):
	if mode=="derby":
		model.visible=not first_person
		if first_person:
			camera.position=player.position+Vector3(0,1.8,0)-player.basis.z*.3
			camera.rotation=Vector3(-.08,player.rotation.y,0)
		else:
			camera.position=camera.position.lerp(player.position+player.basis.z*8+Vector3(0,4.5,0),1-exp(-5*delta))
			camera.look_at(player.position+Vector3(0,1,0))
	else:
		camera.rotation=Vector3(pitch,yaw,0)
		var head=player.position+Vector3(0,1.65,0)
		var desired=head if first_person else head+camera.basis.z*5+camera.basis.x*0.8
		if not first_person:
			var query=PhysicsRayQueryParameters3D.create(head,desired)
			query.exclude=[player.get_rid()]
			var hit=get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): desired=hit.position+(head-hit.position).normalized()*0.25
		camera.position=desired
	crosshair.visible=mode=="world" and not ended

func update_hud():
	if mode=="derby":
		var objective=["WRECK 3 RIVALS","COLLECT 4 SALVAGE","WRECK THE MARKED TARGET"][contract_type]
		hud.text="CELL OUTZ  /  SCRAP TIDE                 %02d SEC\nHULL %03d   BOOST %03d   SCORE %05d\n%s   %d/%d\nSTREAK %d   REWARD x%.2f   HEAT %d" % [timer,hp,boost,score,objective,contract_progress,contract_target,combo,risk_multiplier,heat]
		prompt.text="WASD drive / Shift boost / F cockpit / R retry / N new seed / Esc field guide"
	else:
		var nearest=""
		var distance=999.0
		for mark in landmarks:
			var d=player.position.distance_to(mark.position)
			if d<distance: distance=d; nearest=mark.name
		hud.text="DUST CIRCUIT / SEED %d / %s PERSON / PATH %s\nHEALTH %03d   SCRAP %03d   AMMO %03d\n%s / %dm   IMPACT: %s" % [run_seed,"FIRST" if first_person else "THIRD",karma_path,hp,credits,ammo,nearest,distance,last_impact_zone]
		prompt.text="WASD / Shift sprint / Click fire / F camera / E loot or trade / N new seed / Esc guide"
	if notice_time>0 or ended: prompt.text=notice+"\n"+prompt.text

func smoke_test():
	start("derby",7707)
	assert(bots.size()==5)
	damage_bot(bots[0],100)
	assert(alive_bots()==4 and loot.size()==3)
	var paid=score
	damage_bot(bots[0],100)
	assert(score==paid and loot.size()==3, "Dead targets must not pay twice")
	contract_progress=contract_target
	resolve_contract()
	paid=score
	resolve_contract()
	assert(score==paid,"Settlement must be idempotent")
	for test_seed in range(12):
		start("derby",test_seed)
		if contract_type==2:
			damage_bot(bots[0],100)
			assert(contract_progress==1,"Marked contract must advance")
	start("derby",7707)
	first_person=true
	update_camera(.016)
	assert(not model.visible and camera.position.distance_to(player.position)<2.1)
	var victim=bots[1]
	damage_bot(victim,36,"LEFT SIDE")
	assert(not victim.body.get_meta("left_panel").visible)
	start("derby",7707)
	assert(cooldown==0 and hit_cooldown==0 and not first_person)
	start("world",12345)
	var first=landmarks.duplicate(true)
	assert(landmarks.size()==6 and traders.size()==2 and bots.size()==10)
	start("world",12345)
	assert(first==landmarks)
	start("world",67890)
	assert(first!=landmarks)
	credits=10
	player.position=traders[0].position+Vector3(1,0,0)
	interact()
	assert(credits==5 and ammo==36)
	first_person=true
	update_camera(0.016)
	assert(camera.position.distance_to(player.position+Vector3(0,1.65,0))<0.1)
	print("PLAY_LAB_SMOKE_PASS: repeat payouts blocked, settlement, marked targets, detachable meshes, camera modes, resets, seeded worlds, trading")
	get_tree().quit()

func capture_preview():
	start("world" if "--world" in OS.get_cmdline_user_args() else "derby",7707)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for frame in range(40): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var target="P:/GameDev/Temp/play-lab-"+mode+".png"
	get_viewport().get_texture().get_image().save_png(target)
	print("CAPTURED "+target)
	get_tree().quit()
