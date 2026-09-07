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
	var folder: String = host.root_dir.path_join(".playseed/qa/model-library-ui")
	DirAccess.make_dir_recursive_absolute(folder.path_join("model-library"))
	var id = "a".repeat(64)
	var item = {"id":id,"name":"温室花盆","purpose":"替换中央花台外观","source":"独立自动检查夹具，不是真人素材","license":"自有原创"}
	var manifest = FileAccess.open(folder.path_join("model-library/library.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"models":[item]}));manifest.close()
	var glb = FileAccess.open(folder.path_join("import.glb"),FileAccess.WRITE)
	glb.store_string("UI请求夹具，实际格式由后台另行测试");glb.close()
	host.current={"id":"model_ui_fixture","revision":1,"status":"confirmed","title":"模型素材检查","project_directory":folder}
	var editor = load("res://model_library.gd").new()
	host.add_child(editor);editor.setup(host)
	assert(editor.picker.use_native_dialog)
	editor.submit()
	assert(host.sent_request.is_empty())
	editor.select_file(folder.path_join("import.glb"))
	editor.purpose.text="中央花台外观"
	editor.source.text="原创测试"
	editor.license_picker.select(1)
	editor.submit()
	assert(host.sent_request.action=="import_model" and host.sent_request.has("glb_base64"))
	editor.edit(item)
	editor.name_input.text="改名后的花盆"
	editor.submit()
	assert(host.sent_request.action=="update_model_metadata" and host.sent_request.model_id==id and host.sent_request.name=="改名后的花盆")
	var previous: Dictionary = host.sent_request.duplicate(true)
	host.busy=true;editor.submit();assert(host.sent_request==previous)
	host.busy=false;host.current.id="another";editor.submit();assert(host.sent_request==previous)
	host.current.id="model_ui_fixture"
	host.input.text="保留我的草稿";editor.propose(item);assert(host.input.text=="保留我的草稿")
	if "--visual" in OS.get_cmdline_user_args():
		editor.message.text="模型已入库。预览和补齐资料后，通过对话制作新版本。"
		for i in range(6): await process_frame
		assert(editor.size.y<=720)
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder.path_join("ui.png"))
	host.input.text="";editor.propose(item)
	assert(host.input.text.contains(id) and host.sent_request==previous)
	await process_frame
	host.queue_free();await process_frame
	print("MODEL_LIBRARY_UI_TESTS_PASSED: import, provenance, edit, context, draft, propose without sending")
	quit()
