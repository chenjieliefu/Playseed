extends SceneTree

class Probe extends "res://creator.gd":
	var sent_request: Dictionary = {}
	func save_selection() -> void: pass
	func start_job(request: Dictionary) -> void: sent_request = request

func _initialize() -> void: call_deferred("run_tests")

func run_tests() -> void:
	var host = Probe.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size = Vector2i(1320,850)
	await process_frame
	host.data_dir = host.root_dir.path_join(".playseed/qa/spatial-mode-persistence")
	DirAccess.make_dir_recursive_absolute(host.data_dir)
	host.dimension_choices = {}
	host.current = {"id":"spatial_ui_fixture","title":"温室寻物","revision":1,"status":"confirmed","confirmed_revision":1,"ready":true,"messages":[],"questions":[],
		"plan":{"title":"温室寻物","premise":"在3D温室寻找两枚种子。","player_goal":"收集后从出口离开。","core_loop":["行走","靠近收集"],"visual_style":"低多边形", "first_version":["3D房间","碰撞与交互"],"asset_plan":["使用几何体临时形象"],"later":[],"assumptions":[]}}
	host.show_idea()
	host.navigate("workspace")
	assert(host.dimension_picker.visible and host.dimension_picker.selected == 0)
	host.dimension_picker.select(1)
	host.dimension_picker.item_selected.emit(1)
	host.created_action("build_game")
	assert(host.sent_request.format == "room3d-v1")
	host.dimension_choices.clear()
	host.load_dimension_choices()
	host.created_action("build_game")
	assert(host.sent_request.format == "room3d-v1", "重开后丢失3D制作方式")
	var saved_dir: String = host.data_dir
	host.data_dir = saved_dir.path_join("missing/subfolder")
	host.select_dimension(0)
	assert(host.dimension_choices.spatial_ui_fixture == 1 and host.status.text.contains("未能保存"))
	host.data_dir = saved_dir

	host.current.id = "another_project"
	host.show_idea()
	assert(host.dimension_picker.selected == 0)
	host.created_action("build_game")
	assert(not host.sent_request.has("format"))
	host.current.id = "spatial_ui_fixture"
	host.show_idea()
	assert(host.dimension_picker.selected == 1)
	host.busy = true
	host.show_idea()
	assert(host.dimension_picker.disabled)
	host.busy = false
	host.show_idea()
	if "--visual" in OS.get_cmdline_user_args():
		for i in range(5): await process_frame
		RenderingServer.force_draw(false)
		var folder: String = host.root_dir.path_join(".playseed/qa/spatial-ui")
		DirAccess.make_dir_recursive_absolute(folder)
		root.get_texture().get_image().save_png(folder.path_join("ui.png"))
	host.queue_free()
	await process_frame
	print("SPATIAL_UI_TESTS_PASSED: persistent mode, correct request after reload, write failure, project isolation, busy state")
	quit()
