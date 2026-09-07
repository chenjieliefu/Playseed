extends SceneTree
class Probe extends "res://creator.gd":
	var sent_request: Dictionary = {}
	func save_selection() -> void: pass
	func start_job(request: Dictionary) -> void: sent_request = request
func _initialize() -> void: call_deferred("run_tests")
func find_button(node: Node, text: String):
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var match_button = find_button(child,text)
		if match_button != null: return match_button
	return null
func run_tests() -> void:
	var host = Probe.new();root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.size=Vector2i(1280,850)
	await process_frame
	var folder: String = host.root_dir.path_join(".playseed/qa/model-drafts-ui")
	var id = "b".repeat(32)
	var path: String = folder.path_join("model-drafts").path_join(id)
	DirAccess.make_dir_recursive_absolute(path)
	var record = {"id":id,"state":"review","name":"种植箱草稿","summary":"基础色静态道具；请检查两个角度。","prompt":"木箱与两株小苗","source_revision":1}
	var file = FileAccess.open(path.path_join("draft.json"),FileAccess.WRITE);file.store_string(JSON.stringify(record));file.close()
	var smoke: String = host.root_dir.path_join(".playseed/qa/blender-props-20260907/smoke/blender-work")
	for name in ["front.png","back.png"]:
		if FileAccess.file_exists(smoke.path_join(name)): DirAccess.copy_absolute(smoke.path_join(name),path.path_join(name))
	host.current={"id":"draft_ui_fixture","revision":1,"status":"confirmed","title":"道具制作","project_directory":folder}
	host.input.text="保留草稿";preload("res://model_drafts.gd").prepare(host,"新描述");assert(host.input.text=="保留草稿")
	host.input.text="";preload("res://model_drafts.gd").prepare(host,"小木箱");assert(host.input.text=="生成模型：小木箱" and host.sent_request.is_empty())
	host.submit_composer();assert(host.sent_request.action=="generate_model" and host.sent_request.prompt=="小木箱")
	for child in host.chat.get_children(): host.chat.remove_child(child);child.queue_free()
	preload("res://model_drafts.gd").render(host)
	var accept = find_button(host.chat,"采用模型");assert(accept!=null and not accept.disabled)
	accept.pressed.emit();assert(host.sent_request.action=="accept_model" and host.sent_request.draft_id==id)
	host.sent_request={};host.input.text="";find_button(host.chat,"改描述重做").pressed.emit();assert(host.input.text=="生成模型：木箱与两株小苗" and host.sent_request.is_empty())
	find_button(host.chat,"放弃草稿").pressed.emit();assert(host.sent_request.action=="discard_model")
	for child in host.chat.get_children():host.chat.remove_child(child);child.queue_free()
	host.current.revision=2;preload("res://model_drafts.gd").render(host);assert(find_button(host.chat,"采用模型").disabled)
	for child in host.chat.get_children():host.chat.remove_child(child);child.queue_free()
	host.current.revision=1;host.busy=true;preload("res://model_drafts.gd").render(host)
	for text in ["采用模型","改描述重做","放弃草稿"]:assert(find_button(host.chat,text).disabled)
	host.busy=false
	if "--visual" in OS.get_cmdline_user_args():
		host.navigate("workspace")
		for i in range(8): await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder.path_join("ui.png"))
	print("MODEL_DRAFTS_UI_TESTS_PASSED: compose, review, adoption, discard, retry, stale, busy, draft preservation")
	host.queue_free();await process_frame;quit()
