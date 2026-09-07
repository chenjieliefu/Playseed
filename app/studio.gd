extends Control

const INK := Color("263c31")
const MUTED := Color("6d7b70")
const GREEN := Color("c6e88c")
const PAPER := Color("f6f7ef")
var root_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
var data_dir := ""
var python := "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3"
var projects: Array = []
var current: Dictionary = {}
var active_job := ""
var worker_pid := -1
var started_at := 0
var busy := false
var project_picker: OptionButton
var version_picker: OptionButton
var prompt_box: TextEdit
var send_button: Button
var sample_button: Button
var cancel_button: Button
var restore_button: Button
var export_button: Button
var external_button: Button
var new_button: Button
var status_text: Label
var stage_text: Label
var project_title: Label
var params_text: Label
var response_text: Label
var revision_text: Label
var preview: SubViewport
var preview_container: SubViewportContainer
var game: Node2D
var blank: Label
var restore_dialog: ConfirmationDialog
var timer: Timer
var play_hint: Label
var window_active := true
var embedded_mode := false

func _ready() -> void:
	if not embedded_mode:
		get_window().title = "Playseed · 试玩实验区"
	data_dir = root_dir.path_join(".playseed")
	if OS.has_environment("PLAYSEED_PYTHON"):
		python = OS.get_environment("PLAYSEED_PYTHON")
	get_window().min_size = Vector2i(1100, 760)
	_build_ui()
	get_viewport().gui_focus_changed.connect(_sync_game_input)
	visibility_changed.connect(_sync_game_input)
	get_window().focus_exited.connect(func(): window_active = false; _sync_game_input())
	get_window().focus_entered.connect(func(): window_active = true; _sync_game_input())
	for popup in [project_picker.get_popup(), version_picker.get_popup(), restore_dialog]:
		popup.visibility_changed.connect(_sync_game_input)
	_load_projects()
	_focus_preview()
	timer = Timer.new()
	timer.wait_time = 0.4
	timer.timeout.connect(_poll_job)
	add_child(timer)
	timer.start()

func _style(color: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _wrapped(text: String, font_size: int = 16, color: Color = MUTED) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 42
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _style(GREEN if primary else Color("e9ede3"), 12))
	b.add_theme_stylebox_override("hover", _style(Color("b7dc77") if primary else Color("dfe7d7"), 12))
	b.add_theme_stylebox_override("pressed", _style(Color("b0cf7c"), 12))
	b.add_theme_stylebox_override("disabled", _style(Color("edf0e8"), 12))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("a0a99c"))
	b.pressed.connect(callback)
	return b

func _gap(parent: Node, pixels: float, expand: bool = false) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = pixels
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)

func _panel(parent: Node, color: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(color, 18))
	parent.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	p.add_child(box)
	return box

func _build_ui() -> void:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Arial"])
	t.default_font = font
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "OptionButton", INK)
	t.set_color("font_hover_color", "OptionButton", INK)
	t.set_stylebox("normal", "OptionButton", _style(Color("e9ede3"), 10))
	t.set_stylebox("hover", "OptionButton", _style(Color("dfe7d7"), 10))
	t.set_stylebox("panel", "PopupMenu", _style(Color("fafbf6"), 10))
	t.set_color("font_color", "PopupMenu", INK)
	theme = t
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	var top := HBoxContainer.new()
	top.visible = not embedded_mode
	top.add_theme_constant_override("separation", 18)
	page.add_child(top)
	var mark := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/mascot.png")
	atlas.region = Rect2(240, 60, 520, 560)
	mark.texture = atlas
	mark.custom_minimum_size = Vector2(50, 50)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(mark)
	top.add_child(_label("Playseed", 30))
	top.add_child(_label("让你的想法，长成游戏", 16, MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_label("本机创作原型  /  0.2.1", 14, MUTED))
	new_button = _button("＋ 新想法", _new_project)
	top.add_child(new_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	page.add_child(body)
	var left := _panel(body, Color.WHITE)
	left.get_parent().custom_minimum_size.x = 330
	left.get_parent().size_flags_horizontal = Control.SIZE_FILL
	left.add_child(_label("创作工作台", 24))
	left.add_child(_wrapped("先做一款小小的游戏，再一点点把它变成你的。", 16))
	project_picker = OptionButton.new()
	project_picker.custom_minimum_size.y = 42
	project_picker.item_selected.connect(_choose_project)
	left.add_child(project_picker)
	left.add_child(_label("告诉 Playseed，你想改什么？", 16))
	prompt_box = TextEdit.new()
	prompt_box.custom_minimum_size = Vector2(0, 170)
	prompt_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	prompt_box.placeholder_text = "例如：做一个夜晚躲怪物游戏，角色跑快一点，坚持 30 秒获胜。"
	prompt_box.add_theme_color_override("font_color", INK)
	prompt_box.add_theme_color_override("font_placeholder_color", Color("84907f"))
	prompt_box.add_theme_color_override("caret_color", INK)
	prompt_box.add_theme_stylebox_override("normal", _style(Color("f5f7f0"), 12))
	var focus_style := _style(Color("f5f7f0"), 12)
	focus_style.border_color = Color("a3bd80")
	focus_style.set_border_width_all(2)
	prompt_box.add_theme_stylebox_override("focus", focus_style)
	left.add_child(prompt_box)
	var examples := HBoxContainer.new()
	examples.add_theme_constant_override("separation", 8)
	left.add_child(examples)
	for suggestion in ["怪物减少一半", "加 8 颗收集光点"]:
		var b := _button(suggestion, func(): prompt_box.text = suggestion; prompt_box.grab_focus())
		b.add_theme_font_size_override("font_size", 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		examples.add_child(b)
	send_button = _button("生成我的游戏", _send, true)
	left.add_child(send_button)
	sample_button = _button("先玩一个示例 · 不调用 AI", func(): _start_job({"action": "demo"}))
	left.add_child(sample_button)
	left.add_child(_wrapped("支持躲避、收集、生命、爱心回血、速度、数量、配色、冲刺和护盾。AI 使用本机 Codex 账户及其额度。", 13))
	_gap(left, 1)
	var status_box := _panel(left, Color("f0f4e9"))
	stage_text = _label("准备就绪", 15)
	status_box.add_child(stage_text)
	status_text = _wrapped("写下想法，或者先打开示例。", 14)
	status_box.add_child(status_text)
	cancel_button = _button("取消本次修改", _cancel)
	cancel_button.visible = false
	status_box.add_child(cancel_button)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	var preview_header := HBoxContainer.new()
	right.add_child(preview_header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_header.add_child(title_box)
	project_title = _label("你的第一款游戏", 23)
	project_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(project_title)
	revision_text = _label("生成后，游戏会在这里等你", 14, MUTED)
	title_box.add_child(revision_text)
	external_button = _button("独立窗口试玩", _play_external)
	preview_header.add_child(external_button)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _style(Color("182e29"), 18))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(frame)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.6
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(aspect)
	preview_container = SubViewportContainer.new()
	preview_container.focus_mode = Control.FOCUS_ALL
	preview_container.stretch = true
	preview_container.gui_input.connect(_preview_input)
	aspect.add_child(preview_container)
	preview = SubViewport.new()
	preview.size = Vector2i(960, 600)
	preview.size_2d_override = Vector2i(960, 600)
	preview.size_2d_override_stretch = true
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(preview)
	blank = _label("写下第一颗游戏种子", 26, Color("d0e2b8"))
	blank.position = Vector2(290, 295)
	preview.add_child(blank)
	var hint_row := HBoxContainer.new()
	right.add_child(hint_row)
	play_hint = _label("点击游戏画面后操作 · WASD / 方向键移动 · 空格冲刺", 14, MUTED)
	play_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(play_hint)
	hint_row.add_child(_button("重新开始", func():
		if is_instance_valid(game):
			_focus_preview()
			game.reset_game(false)))
	params_text = _wrapped("你的玩法参数会显示在这里。", 15)
	right.add_child(params_text)
	var bottom := _panel(right, Color.WHITE)
	var version_row := HBoxContainer.new()
	version_row.add_theme_constant_override("separation", 10)
	bottom.add_child(version_row)
	version_row.add_child(_label("版本", 16))
	version_picker = OptionButton.new()
	version_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_picker.item_selected.connect(func(_i): _update_buttons())
	version_row.add_child(version_picker)
	restore_button = _button("恢复所选版本", func():
		restore_dialog.dialog_text = "恢复第 %d 版的玩法，并保存为新版本。\n现有历史会完整保留。" % version_picker.get_item_id(version_picker.selected)
		restore_dialog.popup_centered(Vector2i(490, 180)))
	version_row.add_child(restore_button)
	export_button = _button("导出工程", func(): _start_job({"action": "export", "project_id": current.id}))
	version_row.add_child(export_button)
	response_text = _wrapped("这里记录每次真正生效的变化。", 15)
	response_text.custom_minimum_size.y = 48
	bottom.add_child(response_text)
	var footer := HBoxContainer.new()
	page.add_child(footer)
	footer.add_child(_label("想法属于你，游戏也属于你。", 13, MUTED))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(space)
	footer.add_child(_button("打开项目文件夹", func(): OS.shell_open(root_dir.path_join(".playseed/projects")) ))
	restore_dialog = ConfirmationDialog.new()
	restore_dialog.title = "恢复游戏版本"
	restore_dialog.dialog_text = "恢复所选版本的玩法，并保存为一个新版本。\n现有历史会完整保留。"
	restore_dialog.ok_button_text = "恢复"
	restore_dialog.cancel_button_text = "取消"
	restore_dialog.get_label().add_theme_color_override("font_color", Color("f3f4e9"))
	restore_dialog.confirmed.connect(func(): _start_job({"action": "restore", "project_id": current.id, "revision": version_picker.get_item_id(version_picker.selected)}))
	add_child(restore_dialog)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _write(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(value))

func _load_projects(preferred_id: String = "") -> void:
	projects.clear()
	project_picker.clear()
	var base := data_dir.path_join("projects")
	DirAccess.make_dir_recursive_absolute(base)
	for folder in DirAccess.get_directories_at(base):
		var data := _read(base.path_join(folder).path_join("project.json"))
		if not data.is_empty():
			projects.append(data)
	projects.sort_custom(func(a, b): return str(a.updated_at) > str(b.updated_at))
	project_picker.add_item("＋ 创建一款新游戏")
	var selected := 0
	for i in range(projects.size()):
		project_picker.add_item(str(projects[i].title))
		if str(projects[i].id) == preferred_id:
			selected = i + 1
	if preferred_id.is_empty() and not projects.is_empty():
		selected = 1
	project_picker.select(selected)
	_choose_project(selected)

func _choose_project(index: int) -> void:
	if busy:
		return
	current = projects[index - 1] if index > 0 and index <= projects.size() else {}
	_show_current()

func _new_project() -> void:
	current = {}
	project_picker.select(0)
	prompt_box.text = ""
	_show_current()
	prompt_box.grab_focus()

func _show_current() -> void:
	version_picker.clear()
	if is_instance_valid(game):
		preview.remove_child(game)
		game.queue_free()
	blank.visible = current.is_empty()
	if current.is_empty():
		project_title.text = "你的第一款游戏"
		revision_text.text = "先从一场小小的森林冒险开始"
		params_text.text = "描述角色速度、怪物数量、时间或收集目标。"
		response_text.text = "这是一个受限玩法原型：AI 生成玩法配置，再构建可运行的 Godot 工程。"
	else:
		project_title.text = current.title
		revision_text.text = "第 %d 版 · 可运行的 Godot 工程" % int(current.current_revision)
		var c: Dictionary = current.config
		params_text.text = "速度 %d · 怪物 %d · %d 秒 · 生命 %d/%d · 爱心 %d · 护盾 %d · 收集 %d · %s" % [c.player_speed, c.enemy_count, c.duration, c.get("initial_lives", 1), c.get("max_lives", 1), c.get("heart_count", 0), c.shield_count, c.collectible_count, "可冲刺" if c.dash_enabled else "无冲刺"]
		var versions: Array = current.versions.duplicate()
		versions.reverse()
		for v in versions:
			version_picker.add_item("第 %d 版 · %s" % [int(v.revision), str(v.summary).left(26)], int(v.revision))
		version_picker.select(0)
		response_text.text = current.versions[-1].summary
		game = load("res://game_preview.gd").new()
		game.configure(c)
		game.accept_input = false
		preview.add_child(game)
		game.start_button.pressed.connect(_focus_preview)
	_sync_game_input()
	_update_buttons()

func _update_buttons() -> void:
	send_button.text = "让 AI 生成游戏" if current.is_empty() else "让 AI 修改游戏"
	for button in [send_button, sample_button, new_button]:
		button.disabled = busy
	project_picker.disabled = busy
	version_picker.disabled = busy or current.is_empty()
	prompt_box.editable = not busy
	export_button.disabled = busy or current.is_empty()
	external_button.disabled = current.is_empty()
	restore_button.disabled = busy or current.is_empty() or version_picker.selected < 0 or version_picker.get_item_id(version_picker.selected) == int(current.get("current_revision", 0))
	cancel_button.visible = busy

func _send() -> void:
	if prompt_box.text.strip_edges().is_empty():
		status_text.text = "先写下一句想法吧。"
		prompt_box.grab_focus()
		return
	var request := {"action": "create" if current.is_empty() else "modify", "prompt": prompt_box.text.strip_edges()}
	if not current.is_empty():
		request.project_id = current.id
	_start_job(request)

func _start_job(request: Dictionary) -> void:
	if busy:
		return
	var token := "%d-%d" % [Time.get_unix_time_from_system(), randi()]
	active_job = data_dir.path_join("jobs").path_join(token)
	DirAccess.make_dir_recursive_absolute(active_job)
	_write(active_job.path_join("request.json"), request)
	worker_pid = OS.create_process(python, PackedStringArray([root_dir.path_join("backend.py"), "--request", active_job.path_join("request.json")]))
	if worker_pid < 0:
		status_text.text = "无法启动本地服务，请检查 Python 安装。"
		return
	busy = true
	started_at = Time.get_ticks_msec()
	stage_text.text = "开始处理"
	status_text.text = "正在准备本次操作…"
	_update_buttons()

func _poll_job() -> void:
	if not busy:
		return
	var result := _read(active_job.path_join("status.json"))
	if result.is_empty():
		if not OS.is_process_running(worker_pid) and Time.get_ticks_msec() - started_at > 1500:
			busy = false
			stage_text.text = "没有完成"
			status_text.text = "本地服务意外退出，游戏未被覆盖。"
			_update_buttons()
		return
	var state: String = result.get("state", "")
	var elapsed := (Time.get_ticks_msec() - started_at) / 1000
	stage_text.text = str({"thinking": "理解想法", "building": "生成工程", "checking": "运行检查", "done": "已完成", "error": "没有完成", "cancelled": "已取消"}.get(state, "处理中")) + " · %ds" % elapsed
	status_text.text = result.get("message", "")
	if state in ["done", "error", "cancelled"]:
		busy = false
		if state == "done":
			var data := _read(active_job.path_join("result.json"))
			if data.has("export_path"):
				OS.shell_show_in_file_manager(data.export_path)
			else:
				prompt_box.text = ""
				_load_projects(data.get("id", ""))
		_update_buttons()
	elif not OS.is_process_running(worker_pid):
		busy = false
		stage_text.text = "处理已中断"
		status_text.text = "服务退出，当前游戏保持不变。"
		_update_buttons()

func _cancel() -> void:
	var file := FileAccess.open(active_job.path_join("cancel"), FileAccess.WRITE)
	if file:
		file.store_string("cancel")
	status_text.text = "正在停止；旧版本会保留。"

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_focus_preview()
	elif event is InputEventKey and event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE]:
		# The game reads physical keys. Stop their separate GUI navigation action.
		preview_container.accept_event()

func _focus_preview() -> void:
	preview_container.grab_focus()
	_sync_game_input()

func _sync_game_input(_focus: Control = null) -> void:
	var enabled := is_visible_in_tree() and window_active and preview_container.has_focus() and not restore_dialog.visible and not project_picker.get_popup().visible and not version_picker.get_popup().visible
	if is_instance_valid(game):
		game.accept_input = enabled
	play_hint.text = "试玩操作 · WASD / 方向键移动 · 空格冲刺 · Tab 返回工作台" if enabled else "试玩已暂停 · 点击游戏画面继续"

func _play_external() -> void:
	if current.is_empty():
		return
	var path := data_dir.path_join("projects").path_join(current.id).path_join("revisions/%04d" % int(current.current_revision))
	OS.create_process(OS.get_executable_path(), PackedStringArray(["--path", path]))
