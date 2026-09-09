extends SceneTree
class Probe extends "res://creator.gd":
	var sent: Dictionary = {}
	func save_selection() -> void: pass
	func start_job(request: Dictionary) -> void: sent=request
func _initialize(): call_deferred("run_tests")
func run_tests():
	var host=Probe.new();root.add_child(host);await process_frame
	host.current={"id":"web_ui_fixture","revision":1,"delivery":"web"}
	host.update_dimension_label()
	assert(host.dimension_picker.get_item_text(1).contains("网页"))
	host.made_game={};host.dimension_choices.web_ui_fixture=0
	host.created_action("build_game");assert(host.sent.format=="web-2d-v1")
	host.dimension_choices.web_ui_fixture=1
	host.created_action("build_game");assert(host.sent.format=="web-3d-v1")
	host.current.delivery="native"
	host.update_dimension_label()
	assert(host.dimension_picker.get_item_text(1).contains("房间寻物"))
	host.created_action("build_game");assert(host.sent.format=="room3d-v1")
	host.made_game={"current_revision":2,"format":"web-3d-v1"}
	host.created_action("revise_game",{"prompt":"保留法术，增加敌人"})
	assert(host.sent.game_revision==2 and not host.sent.has("format"))
	assert(host.version_validation_text({"format":"web-3d-v1"}).contains("浏览器"))
	var hands_check := host.version_validation_text({"format":"web-3d-v1","input_validation":"synthetic-hand-landmarks"})
	assert(hands_check.contains("模拟手势") and not hands_check.contains("鼠标键盘"))
	assert(not host.version_validation_text({"format":"web-3d-v1"}).contains("鼠标键盘"))
	assert(not host.version_validation_text({"format":"web-2d-v1","input_validation":"mouse-keyboard"}).contains("连续两次"))
	assert(host.version_validation_text({"format":"web-2d-v1","input_validation":"mouse-keyboard","playability_checks":["pause_resume","restart_replay"]}).contains("连续两次重玩"))
	assert(host.version_request_text({"source":"revise_game","prompt":"只提高前后灵敏度"}).contains("只提高前后灵敏度"))
	assert(host.version_request_text({"source":"build_game","prompt":"第一版"}).is_empty())
	print("WEB_UI_TESTS_PASSED: delivery dispatch, dimension, existing version continuity")
	host.queue_free()
	await process_frame
	await process_frame
	quit()
