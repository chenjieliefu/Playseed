extends SceneTree

var folder := ""
var manifest: Dictionary = {}
var feedback: Dictionary = {"answers": {}}
var page := 0
var testing := false
var box: VBoxContainer
var status: Label
var launch: Button
var next: Button
var experience: OptionButton
var outcome: OptionButton
var goal: TextEdit
var blocker: TextEdit
var change: TextEdit
var improvement: TextEdit
var willingness: OptionButton
var poll_age := 0.0
var pending_launch := false
var last_status := ""
var poll_key := ""

func _initialize() -> void:
	call_deferred("setup")

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func save_json(path: String, value: Dictionary) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func setup() -> void:
	var args = OS.get_cmdline_user_args()
	if args.is_empty(): quit(1); return
	folder = args[0]
	testing = "--self-test" in args
	manifest = read_json(folder.path_join("session.json"))
	if manifest.get("stages", []).size() != 3: quit(1); return
	if testing and manifest.get("kind") != "automated_ui_fixture": quit(1); return
	feedback = read_json(folder.path_join("feedback.json"))
	if feedback.is_empty(): feedback = {"answers": {}}
	page = clampi(int(feedback.get("page", 0)), 0, 3)
	root.title = "Playseed · 新手试玩记录"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(740, 820)
	root.min_size = Vector2i(680, 720)
	root.position = Vector2i(50, 60)
	root.close_requested.connect(close_draft)
	auto_accept_quit = false
	build_page()
	if testing: call_deferred("self_test")

func label(text: String, size := 16) -> Label:
	var item = Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", Color("34483b"))
	box.add_child(item)
	return item

func select(options: Array, saved: String) -> OptionButton:
	var item = OptionButton.new()
	for option in options: item.add_item(option)
	for i in range(item.item_count):
		if item.get_item_text(i) == saved: item.select(i)
	item.custom_minimum_size.y = 36
	item.add_theme_font_size_override("font_size", 16)
	item.add_theme_color_override("font_color", Color("34483b"))
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color("e9eddf")
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 10
	item.add_theme_stylebox_override("normal", panel)
	box.add_child(item)
	return item

func field(title: String, saved: String, hint: String) -> TextEdit:
	label(title)
	var item = TextEdit.new()
	item.custom_minimum_size.y = 64
	item.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	item.placeholder_text = hint
	item.text = saved
	item.add_theme_color_override("font_color", Color("34483b"))
	item.add_theme_font_size_override("font_size", 16)
	item.add_theme_color_override("font_placeholder_color", Color("788171"))
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color("ffffff")
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 10
	panel.content_margin_top = 7
	item.add_theme_stylebox_override("normal", panel)
	box.add_child(item)
	return item

func button(title: String, action: Callable) -> Button:
	var item = Button.new()
	item.text = title
	item.custom_minimum_size.y = 40
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color("dce9c7")
	panel.set_corner_radius_all(10)
	item.add_theme_stylebox_override("normal", panel)
	item.add_theme_color_override("font_color", Color("34483b"))
	item.add_theme_font_size_override("font_size", 16)
	item.pressed.connect(action)
	box.add_child(item)
	return item

func build_page() -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var bg = ColorRect.new()
	bg.color = Color("f6f5eb")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	root.add_child(margin)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	label("一起试试，这个游戏是否值得继续玩", 24)
	label("建议预留 10–15 分钟，包含三段试玩和填写反馈。可以随时退出，不必玩满。", 14)
	label("仅在本机保存匿名文字与窗口打开时长，不录屏。时长包含停留，不能代表一直在玩。", 13)
	if page < 3:
		var stage = manifest.stages[page]
		label(stage.title + "（" + stage.minutes + "）", 21)
		label(stage.task)
		if page == 0:
			experience = select(["请选择游戏制作经验", "从未做过游戏", "尝试过制作游戏", "熟悉游戏制作"], feedback.get("experience", ""))
		launch = button("打开本段游戏 ↗", launch_game)
		status = label("", 14)
		label("玩完请关闭游戏窗口，回到这里。先按你理解的方式玩，不清楚也可以直接记录。", 13)
		var answer: Dictionary = feedback.answers.get(str(page), {})
		outcome = select(["请选择本段结果", "通关", "失败", "主动结束", "没看懂如何开始"], answer.get("outcome", ""))
		goal = field("你觉得这一段要做什么？", answer.get("goal", ""), "用自己的话说，不知道也可以写不知道。")
		blocker = field("哪里卡住、没看懂或开始无聊？", answer.get("blocker", ""), "尽量写具体时机，没有可以写没有。")
		change = field("你感受到了什么变化？" if page > 0 else "操作和反馈给你什么感觉？", answer.get("change", ""), "没有察觉也可以如实写。")
		next = button("保存这一段，继续", advance)
		refresh_status()
	else:
		label("最后，说说你的感受", 21)
		experience = select(["请选择游戏制作经验", "从未做过游戏", "尝试过制作游戏", "熟悉游戏制作"], feedback.get("experience", ""))
		willingness = select(["还愿意继续玩吗？", "愿意", "不愿意", "说不清"], feedback.get("continue", ""))
		improvement = field("最希望下一版改进什么？", feedback.get("improvement", ""), "只写最重要的一点。")
		status = label("反馈保存在本机，完成后可打开记录文件夹。")
		button("完成并保存反馈", finish)
		button("打开记录文件夹", func(): OS.shell_open(folder))
	if page > 0: button("返回上一段", back)
	button("保存草稿，稍后继续", close_draft)

func capture_answers() -> void:
	feedback.page = page
	if page < 3:
		feedback.answers[str(page)] = {"outcome": outcome.get_item_text(outcome.selected), "goal": goal.text.strip_edges(), "blocker": blocker.text.strip_edges(), "change": change.text.strip_edges()}
		if page == 0: feedback.experience = experience.get_item_text(experience.selected)
	else:
		feedback.experience = experience.get_item_text(experience.selected)
		feedback["continue"] = willingness.get_item_text(willingness.selected)
		feedback.improvement = improvement.text.strip_edges()

func persist() -> bool:
	capture_answers()
	if not save_json(folder.path_join("feedback.json"), feedback):
		status.text = "没有保存成功，请检查记录文件夹是否可写。"
		return false
	return true

func attempt() -> Dictionary:
	return read_json(folder.path_join("stage-%d/attempt.json" % page))

func live(a: Dictionary) -> bool:
	return a.get("status", "") in ["starting", "running"] and (OS.is_process_running(int(a.get("worker_pid", -1))) or OS.is_process_running(int(a.get("game_pid", -1))))

func any_running() -> bool:
	for i in range(3):
		if live(read_json(folder.path_join("stage-%d/attempt.json" % i))): return true
	return false

func refresh_status() -> void:
	if page >= 3: return
	var a = attempt()
	var running = live(a)
	launch.disabled = pending_launch or any_running() or feedback.get("submitted", false)
	next.disabled = pending_launch or running or a.get("status") != "finished"
	if pending_launch: status.text = "正在打开游戏…"
	elif running: status.text = "游戏窗口已打开。结束后请关闭它，再填写下方反馈。"
	elif a.get("status") == "finished": status.text = "游戏窗口已关闭 · 打开了 %.1f 分钟（含停留）" % (float(a.get("window_seconds", 0)) / 60.0)
	elif a.get("status") in ["starting", "running"]: status.text = "上次记录意外中断，未计为完成。请确认旧游戏窗口已关闭后重试。"
	elif a.get("status") == "failed": status.text = str(a.get("error", "未正常结束，请重试或保留草稿。"))
	else: status.text = "本段尚未开始。"

func launch_game() -> void:
	if testing or any_running() or pending_launch or feedback.get("submitted", false): return
	if not persist(): return
	pending_launch = true
	last_status = JSON.stringify(attempt())
	var pid = OS.create_process(manifest.python, [manifest.script, "--session", folder, "--run-stage", str(page)])
	if pid <= 0:
		pending_launch = false
		status.text = "未能打开游戏，请保存草稿后重试。"
	else:
		poll_launch(pid)
	refresh_status()

func poll_launch(pid: int) -> void:
	while pending_launch:
		await create_timer(0.3).timeout
		if JSON.stringify(attempt()) != last_status or not OS.is_process_running(pid): pending_launch = false
	refresh_status()

func advance() -> void:
	if page >= 3 or pending_launch or live(attempt()) or attempt().get("status") != "finished": return
	capture_answers()
	var a: Dictionary = feedback.answers[str(page)]
	if outcome.selected == 0 or a.goal.is_empty() or a.blocker.is_empty() or a.change.is_empty():
		status.text = "请补充这一段的反馈；不知道、没察觉或没有卡点，都可以如实写。"
		return
	if not persist(): return
	page += 1
	feedback.page = page
	save_json(folder.path_join("feedback.json"), feedback)
	build_page()

func back() -> void:
	if pending_launch or any_running(): status.text = "请先关闭试玩窗口。"; return
	if not persist(): return
	page = maxi(0, page - 1)
	build_page()

func finish() -> void:
	if willingness.selected == 0 or improvement.text.strip_edges().is_empty() or experience.selected == 0:
		status.text = "请选游戏制作经验、继续玩的意愿，并写下最希望改进的一点。"
		return
	if not persist(): return
	if testing: return
	var output: Array = []
	var code = OS.execute(manifest.python, [manifest.script, "--session", folder, "--summarize"], output)
	var report = read_json(folder.path_join("report.json"))
	if code != 0 or not report.get("feedback_complete", false):
		status.text = "反馈还没完整保存，请返回检查各段记录。"
		return
	feedback.submitted = true
	if not save_json(folder.path_join("feedback.json"), feedback): status.text = "完成标记未保存，请重试。"; return
	OS.execute(manifest.python, [manifest.script, "--session", folder, "--summarize"], output)
	status.text = "反馈已保存，谢谢！这是一份待评阅的真人记录，不会自动标为验收通过。"

func close_draft() -> void:
	if not persist(): return
	quit()

func _process(delta: float) -> bool:
	poll_age += delta
	if poll_age >= 0.5 and status != null:
		poll_age = 0
		var key = str(page) + JSON.stringify(attempt()) + str(any_running()) + str(pending_launch)
		if key != poll_key:
			poll_key = key
			refresh_status()
	return false

func self_test() -> void:
	assert(page == 0 and next.disabled)
	advance()
	assert(page == 0)
	goal.text = "测试草稿，不是真人反馈"
	assert(persist())
	assert(read_json(folder.path_join("feedback.json")).answers["0"].goal == goal.text)
	assert(not feedback.get("submitted", false))
	var a = {"status": "finished", "window_seconds": 73.0}
	assert(save_json(folder.path_join("stage-0/attempt.json"), a))
	refresh_status()
	advance()
	assert(page == 0 and status.text.contains("请补充"))
	experience.select(0) # Missing background information must not block the next game.
	outcome.select(2)
	blocker.text = "没有"
	change.text = "测试"
	advance()
	assert(page == 1)
	back()
	assert(page == 0 and goal.text == "测试草稿，不是真人反馈")
	page = 3
	build_page()
	finish()
	assert(status.text.contains("请选"))
	willingness.select(2)
	improvement.text = "自动检查填写，不是真人反馈"
	finish()
	assert(not read_json(folder.path_join("feedback.json")).get("submitted", false))
	page = 0
	build_page()
	goal.text = ""
	blocker.text = ""
	change.text = ""
	outcome.select(0)
	experience.select(0)
	DirAccess.remove_absolute(folder.path_join("stage-0/attempt.json"))
	refresh_status()
	for i in range(5): await process_frame
	if "--visual" in OS.get_cmdline_user_args():
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder.path_join("ui.png"))
	print("NOVICE_UI_TESTS_PASSED: unplayed gate, draft persistence, required answers, next and back")
	quit()
