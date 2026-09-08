extends SceneTree
class Probe extends "res://creator.gd":
	var sent_request: Dictionary = {}
	func save_selection() -> void: pass
	func start_job(request: Dictionary) -> void: sent_request = request
	func game_directory_for(idea: Dictionary) -> String:
		if idea.get("id", "") == "materials_fixture": return root_dir.path_join(".playseed/qa/materials-clarity/fixture")
		return super.game_directory_for(idea)
func _initialize(): call_deferred("run_tests")
func run_tests():
	var host = Probe.new();root.add_child(host)
	await process_frame
	host.current = {"id":"materials_fixture","revision":1,"status":"confirmed"}
	host.made_game = {"current_revision":1,"source_revision":1}
	var base = host.game_directory_for(host.current)
	DirAccess.make_dir_recursive_absolute(base.path_join("library"))
	DirAccess.make_dir_recursive_absolute(base.path_join("revisions/0001/assets"))
	var icon = Image.load_from_file(host.root_dir.path_join("app/assets/playseed-icon.png"))
	icon.save_png(base.path_join("library/generated.png"))
	icon.save_png(base.path_join("revisions/0001/assets/uploaded.png"))
	icon.save_png(base.path_join("revisions/0001/assets/legacy.png"))
	var saved = [{"id":"generated","name":"验证角色","role":"角色","width":32,"height":32,"generation":{}},{"id":"uploaded","name":"验证背景","role":"场景","width":32,"height":32}]
	var ai_assets = host.resource_tools.image_entries(saved,true)
	assert(ai_assets.size() == 2, "AI scope keeps only generated images plus legacy version files")
	assert(ai_assets[0].status_label == "未放入游戏", "generated image waiting for a version is labelled clearly")
	assert(ai_assets[1].has("file_path") and ai_assets[1].status_label == "已在游戏中", "legacy version file still appears in the AI scope")
	var own_assets = host.resource_tools.image_entries(saved,false)
	assert(own_assets.size() == 1 and own_assets[0].id == "uploaded", "uploaded image stays in the user scope even after entering the game")
	assert(own_assets[0].status_label == "已在游戏中", "uploaded image inside the game is marked as such")
	host.input.text = ""
	host.resource_tools.redesign_image(saved[0])
	assert(host.style_reference_selection[host.style_reference_key()] == "generated")
	host.input.text += "变成蓝色"
	host.submit_composer()
	assert(host.sent_request.action == "generate_asset" and host.sent_request.style_reference_id == "generated" and host.sent_request.role == "角色")
	assert(host.sent_request.prompt.contains("变成蓝色"))
	assert(FileAccess.file_exists(base.path_join("library/generated.png")))
	host.input.text = "保留草稿"
	host.resource_tools.redesign_image(saved[1])
	assert(host.input.text == "保留草稿" and host.style_reference_selection[host.style_reference_key()] == "generated")
	print("MATERIALS_TESTS_PASSED: source classification, snapshot fallback, real reference attachment request, role, input and original preservation")
	quit()
