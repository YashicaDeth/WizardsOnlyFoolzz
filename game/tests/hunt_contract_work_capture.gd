extends Node

const CONTRACTS := preload("res://systems/hunt_contracts.gd")
const INDEX := preload("res://systems/world_index.gd")


func _ready() -> void:
	WorldHistory.clear_history()
	CosmologyFactions._seed()
	AscentEntities.seed_entities()
	TheFourHorsemen.seed_horsemen()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "bond": 30.0})
	WorldHistory.register_subject("aura_keeper", {
		"name": "AURA KEEPER", "kind": "person", "status": "active",
		"role": "Pit-floor affect engineer", "faction": "Unbound",
	})
	CONTRACTS.publish("war", "aura_keeper", "aura", "Keeps the pit's panic aura coherent after the derby feed cuts", "standing", 5.0)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var layer := CanvasLayer.new()
	add_child(layer)
	var index: Control = INDEX.new()
	layer.add_child(index)
	index.size = Vector2(1280, 720)
	index.open()
	index._go_to_page(index.PAGES.find("WORK"), 1.0)
	index.page_blend = 1.0
	for _settle in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := "P:/GameDev/AllusionsTooGrandeur/game/captures/hunt_contract_work.png"
	get_viewport().get_texture().get_image().save_png(output)
	print("CAPTURED: ", output)
	get_tree().quit()
