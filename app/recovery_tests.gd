extends SceneTree
class Probe extends "res://creator.gd":
	var sent_request: Dictionary = {}
	func save_selection() -> void: pass
	func start_job(request: Dictionary) -> void: sent_request = request
func _initialize() -> void: call_deferred("run_tests")
func write(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
func run_tests() -> void:
	var host = Probe.new();root.add_child(host)
	await process_frame
	host.data_dir=host.root_dir.path_join(".playseed/qa/recovery-ui")
	DirAccess.make_dir_recursive_absolute(host.data_dir)
	host.current = {"id":"spatial_ui_fixture","title":"温室寻物","revision":1,"status":"confirmed","confirmed_revision":1,"ready":true,"messages":[],"questions":[],
		"plan":{"title":"温室寻物","premise":"在3D温室寻找两枚种子。","player_goal":"收集后从出口离开。","core_loop":["行走","靠近收集"],"visual_style":"低多边形", "first_version":["3D房间","碰撞与交互"],"asset_plan":["使用几何体临时形象"],"later":[],"assumptions":[]}}

	host.navigate("workspace")
	host.active_job=host.data_dir.path_join("job")
	DirAccess.make_dir_recursive_absolute(host.active_job)
	for format in ["2d","room3d-v1"]:
		var request={"action":"build_game","idea_id":host.current.id,"revision":1,"game_revision":0,"format":format,"prompt":"保留这个想法"}
		write(host.active_job.path_join("request.json"),request)
		write(host.active_job.path_join("status.json"),{"state":"error","message":"检查未通过，旧版保留"})
		host.pending_action="build_game";host.pending_prompt=request.prompt;host.busy=true
		host.input.text="下一条还没发送的草稿"
		host.poll_job()
		assert(not host.busy and host.stopped_request.format==format and host.retry_reason.contains("检查未通过"))
		assert(host.input.text=="下一条还没发送的草稿")
		host.retry_operation();assert(host.sent_request.action=="build_game" and host.sent_request.format==format)
		host.sent_request={};host.current.revision=2;host.retry_operation();assert(host.sent_request.is_empty())
		host.current.revision=1
	var restore={"action":"restore_created","idea_id":host.current.id,"revision":1,"game_revision":4,"restore_revision":2}
	write(host.active_job.path_join("request.json"),restore)
	host.remember_retry("恢复失败")
	host.made_game={"current_revision":4};host.retry_operation()
	assert(host.sent_request.action=="restore_created" and host.sent_request.restore_revision==2)
	host.sent_request={};host.made_game.current_revision=5;host.retry_operation();assert(host.sent_request.is_empty())
	host.made_game={};host.current.id="other";host.retry_operation();assert(host.sent_request.is_empty())
	write(host.active_job.path_join("request.json"),{"action":"delete_project","idea_id":"other"})
	host.remember_retry("删除取消");assert(host.stopped_request.is_empty())
	host.queue_free();await process_frame
	print("RECOVERY_UI_TESTS_PASSED: 2D/3D retry, failure message, draft preservation, restore target, stale request, project isolation")
	quit()
