extends GdUnitTestSuite

func test_limbo_blackboard_can_store_character_state() -> void:
	assert_bool(ClassDB.class_exists("Blackboard")).is_true()
	var blackboard = ClassDB.instantiate("Blackboard")
	blackboard.set_var("target_id", "installation-check")
	assert_str(blackboard.get_var("target_id")).is_equal("installation-check")

func test_terrain_extension_is_registered() -> void:
	assert_bool(ClassDB.class_exists("Terrain3D")).is_true()
	assert_bool(ClassDB.class_exists("Terrain3DData")).is_true()

func test_dialogue_and_scatter_scripts_compile() -> void:
	for path in ["res://addons/dialogue_manager/dialogue_manager.gd", "res://addons/proton_scatter/src/scatter.gd"]:
		var script = load(path) as Script
		assert_object(script).is_not_null()
		assert_bool(script.can_instantiate()).is_true()
