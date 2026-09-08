extends Control

const INK := Color("263c31")
const MUTED := Color("6d7b70")
const SURFACE := Color("fafbf9")
const CARD := Color("ffffff")
const RAIL := Color("eaf0e6")
const RAIL_HOVER := Color("e3ebdd")
const RAIL_ACTIVE := Color("dce8d3")
const PRIMARY := Color("c6e88c")
const PRIMARY_HOVER := Color("d4eabf")
const PRIMARY_PRESSED := Color("b0d174")
const NEUTRAL := Color("eef2ed")
const NEUTRAL_HOVER := Color("e3ebdd")
const NEUTRAL_PRESSED := Color("d6e2cc")
const DISABLED := Color("e9ece4")
const DISABLED_INK := Color("949d90")
const LINE := Color("dce4d6")
const FOCUS_LINE := Color("8fb56b")
const FIELD := Color("f5f7f1")
const FRAME := Color("f4f6f2")
const POPUP := Color("fafbf6")
const BUBBLE := Color("f0f4eb")
const TRACK := Color("f0f3ed")
const FILL := Color("b4d879")
const PLACEHOLDER := Color("8b978b")
const SHADE := Color(0.1, 0.16, 0.12, 0.28)
const SHADOW := Color(0.12, 0.22, 0.14, 0.07)
const ACCENT_INK := Color("4f7a35")
var root_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
var data_dir := ""
var current: Dictionary = {}
var ideas: Array = []
var active_job := ""
var pid := -1
var busy := false
var started := 0
var picker: OptionButton
var input: TextEdit
var chat: VBoxContainer
var chat_scroll: ScrollContainer
var plan_text: Label
var status: Label
var send: Button
var confirm: Button
var cancel: Button
var choices: VBoxContainer
var page: VBoxContainer
var home_button: Button
var lab_button: Button
var dashboard: Control
var home_garden: Control
var library: ScrollContainer
var home_input: TextEdit
var home_send: Button
var home_model_controls: Button
var workspace_model_controls: Button
var home_plus: MenuButton
var home_model_picker: OptionButton
var home_effort_picker: OptionButton
var delivery_undecided: Button
var delivery_native: Button
var delivery_web: Button
var delivery_note: Label
var delivery_group := ButtonGroup.new()
var home_mascot: Control
var home_file_dialog: FileDialog
var home_selected_folder := ""
var home_attachment: Dictionary = {}
var pending_asset_upload: Dictionary = {}
var pending_asset_generation: Dictionary = {}
var style_reference_selection: Dictionary = {}
var asset_task_selection: Dictionary = {}
var choosing_home_folder := false
var project_list: VBoxContainer
var route := "home"
var route_title: Label
var hint: Label
var prepare: Button
var show_build := false
var made_game: Dictionary = {}
var build_game_button: Button
var preview_heading: Label
var dimension_picker: OptionButton
var dimension_choices: Dictionary = {}
var play_game_button: Button
var restore_game_button: Button
var game_versions: OptionButton
var game_label: Label
var flow_label: Label
var sidebar_projects: VBoxContainer
var composer_mode: OptionButton
var model_picker: OptionButton
var effort_picker: OptionButton
var attachment_button: Button
var chat_file_dialog: FileDialog
var detail_view := "效果"
var effect_box: VBoxContainer
var plan_box: VBoxContainer
var history_box: VBoxContainer
var preview: TextureRect
var preview_empty: VBoxContainer
var preview_note: Label
var refresh_preview: Button
var history_text: Label
var version_list: VBoxContainer
var version_heading: Label
var version_meta: Label
var version_summary_text: Label
var progress_bar: ProgressBar
var pending_prompt := ""
var stopped_request: Dictionary = {}
var retry_reason := "已停止本轮操作。"
var stop_requested := false
var pending_action := ""
var next_hint: Label
var process_toggle: Button
var process_scroll: ScrollContainer
var process_details: Label
var process_open := false
var build_after_confirm := false
var sidebar: PanelContainer
var detail_overlay: Control
var detail_heading: Label
var workspace_tools: HBoxContainer
var resource_tools: VBoxContainer
var more_menu: MenuButton
var chat_column: PanelContainer
var modal_close: Button
var sidebar_collapsed := false
var brand_name: Label
var brand_tagline: Label
var sidebar_caption: Label
var sidebar_footer: Label
var sidebar_toggle: Button
var brand_logo: Button
var storage_button: Button
var account_button: Button
var storage_box: VBoxContainer
var storage_path: Label
var storage_message: Label
var folder_dialog: FileDialog
var choose_folder_button: Button
var pending_home_prompt := ""
var account_box: VBoxContainer
var account_status: Label
var account_message: Label
var account_login_button: Button
var account_logout_button: Button
var gpt_logged_in := false
var gpt_login_pid := -1
var project_context: PopupMenu
var context_project_id := ""
var rename_dialog: ConfirmationDialog
var rename_input: LineEdit
var delete_dialog: ConfirmationDialog
var delete_project_label: Label
var delete_path_label: Label

func toggle_sidebar() -> void:
	sidebar_collapsed = not sidebar_collapsed
	apply_sidebar()
	save_selection()

func nav_icon(name: String) -> Texture2D:
	return load("res://assets/ui/" + name + ".svg")

func nav_button(text: String, icon_name: String, action: Callable) -> Button:
	var b := compact(button(text, action))
	b.icon = nav_icon(icon_name)
	b.add_theme_constant_override("h_separation", 12)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 48
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 24)
	b.add_theme_font_size_override("font_size", 15)
	b.tooltip_text = text
	return b

func expand_sidebar() -> void:
	sidebar_collapsed = false
	apply_sidebar()
	save_selection()

func apply_sidebar() -> void:
	sidebar.custom_minimum_size.x = 80 if sidebar_collapsed else 260
	var box: StyleBoxFlat = sidebar.get_theme_stylebox("panel").duplicate()
	box.content_margin_left = 16
	box.content_margin_right = 16
	sidebar.add_theme_stylebox_override("panel", box)
	for item in [brand_name, brand_tagline, sidebar_caption, sidebar_footer]:
		item.visible = not sidebar_collapsed
	sidebar_toggle.visible = not sidebar_collapsed
	brand_logo.tooltip_text = "展开侧栏" if sidebar_collapsed else "Playseed"
	for item in [home_button, account_button] + sidebar_projects.get_children():
		item.text = "" if sidebar_collapsed else item.tooltip_text
		item.custom_minimum_size.x = 0
		item.custom_minimum_size.y = 48
		item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if sidebar_collapsed else HORIZONTAL_ALIGNMENT_LEFT
		item.alignment = HORIZONTAL_ALIGNMENT_CENTER if sidebar_collapsed else HORIZONTAL_ALIGNMENT_LEFT
		var item_active: bool = (item == home_button and route == "home") or (route == "workspace" and item.get_meta("active", false))
		for pair in [["normal", RAIL_ACTIVE if item_active else RAIL], ["hover", RAIL_ACTIVE if item_active else RAIL_HOVER], ["pressed", RAIL_ACTIVE], ["focus", RAIL_ACTIVE if item_active else RAIL_HOVER]]:
			var item_style := style(pair[1])
			item_style.content_margin_left = 12
			item_style.content_margin_right = 12
			item_style.content_margin_top = 8
			item_style.content_margin_bottom = 8
			if pair[0] == "focus":
				item_style.set_border_width_all(2)
				item_style.border_color = FOCUS_LINE
			item.add_theme_stylebox_override(pair[0], item_style)

func games_directory() -> String:
	return str(read_json(data_dir.path_join("storage.json")).get("games_directory", data_dir.path_join("created_games")))

func game_directory_for(idea: Dictionary) -> String:
	var selected := str(idea.get("project_directory", ""))
	if not selected.is_empty() and selected.is_absolute_path():
		return selected
	return games_directory().path_join(str(idea.get("id", "")))

func codex_path() -> String:
	if OS.has_environment("PLAYSEED_CODEX"):
		return OS.get_environment("PLAYSEED_CODEX")
	for path in ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", "/Applications/ChatGPT.app/Contents/Resources/codex"]:
		if FileAccess.file_exists(path):
			return path
	return "codex"

func refresh_gpt_account() -> void:
	var output: Array = []
	var result := OS.execute(codex_path(), PackedStringArray(["login", "status"]), output, true)
	var response := "\n".join(output)
	gpt_logged_in = result == 0 and response.contains("Logged in")
	var uses_chatgpt := response.contains("ChatGPT")
	if account_button == null:
		return
	account_button.tooltip_text = "GPT 账号 · 已登录" if gpt_logged_in else "登录 GPT 账号"
	account_button.text = "" if sidebar_collapsed else account_button.tooltip_text
	if account_status != null:
		account_status.text = "已连接 ChatGPT 账号" if uses_chatgpt else "已连接 OpenAI 账号" if gpt_logged_in else "尚未登录 GPT 账号"
		account_status.add_theme_color_override("font_color", ACCENT_INK if gpt_logged_in else MUTED)
		account_login_button.text = "切换 GPT 账号…" if gpt_logged_in else "登录 GPT 账号…"
		account_logout_button.visible = gpt_logged_in
		if gpt_login_pid > 0 and OS.is_process_running(gpt_login_pid):
			account_message.text = "登录正在浏览器中进行。完成后回到 Playseed。"
		elif gpt_logged_in:
			account_message.text = "对话和游戏生成会使用这个账号可用的 GPT 模型及额度。"
		else:
			account_message.text = "登录后才能使用 GPT 整理方案和生成游戏。Playseed 不保存你的密码。"

func begin_gpt_login() -> void:
	if gpt_logged_in:
		OS.execute(codex_path(), PackedStringArray(["logout"]), [], true)
		gpt_logged_in = false
	gpt_login_pid = OS.create_process(codex_path(), PackedStringArray(["login"]))
	account_message.text = "正在打开 OpenAI 登录页面。请在浏览器中登录自己的 ChatGPT 账号。"
	refresh_gpt_account()

func logout_gpt() -> void:
	OS.execute(codex_path(), PackedStringArray(["logout"]), [], true)
	gpt_login_pid = -1
	refresh_gpt_account()

func show_storage() -> void:
	select_detail("保存位置")

func open_storage_picker() -> void:
	pending_home_prompt = ""
	folder_dialog.title = "选择游戏保存位置"
	folder_dialog.popup_centered_ratio(0.7)

func selected_model() -> String:
	if model_picker == null or model_picker.selected < 0:
		return "gpt-5.6-sol"
	return str(model_picker.get_item_metadata(model_picker.selected))

func selected_effort() -> String:
	if effort_picker == null or effort_picker.selected < 0:
		return "medium"
	return str(effort_picker.get_item_metadata(effort_picker.selected))

func selected_home_model() -> String:
	if home_model_picker == null or home_model_picker.selected < 0:
		return "gpt-5.6-sol"
	return str(home_model_picker.get_item_metadata(home_model_picker.selected))

func selected_home_effort() -> String:
	if home_effort_picker == null or home_effort_picker.selected < 0:
		return "medium"
	return str(home_effort_picker.get_item_metadata(home_effort_picker.selected))

func home_mascot_say(message: String) -> void:
	var input_rect := home_input.get_global_rect()
	var base := dashboard.get_global_rect()
	home_mascot.say(message, Rect2(input_rect.position - base.position, input_rect.size))

func set_home_hint(message: String) -> void:
	if hint == null:
		return
	hint.text = message
	hint.visible = not message.is_empty()

func update_home_hint() -> void:
	var parts := PackedStringArray()
	if not home_selected_folder.is_empty():
		parts.append("项目文件夹：" + home_selected_folder.get_file())
	if not home_attachment.is_empty():
		parts.append("参考图：" + str(home_attachment.get("name", "已添加")))
	set_home_hint("  ·  ".join(parts) if not parts.is_empty() else "")

func choose_home_folder() -> void:
	choosing_home_folder = true
	folder_dialog.title = "选择或新建项目文件夹"
	folder_dialog.current_dir = root_dir.get_base_dir()
	folder_dialog.popup_centered_ratio(0.7)

func attach_home_file(path: String) -> void:
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size() > 8 * 1024 * 1024:
		set_home_hint("请选择 8 MB 以内的图片。")
		return
	var image := Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_width() > 4096 or image.get_height() > 4096:
		set_home_hint("图片无法读取，或宽高超过 4096 像素。")
		return
	var bytes := image.save_png_to_buffer()
	home_attachment = {"name": path.get_file().get_basename(), "role": "参考图", "png_base64": Marshalls.raw_to_base64(bytes)}
	update_home_hint()

func folder_selected(path: String) -> void:
	if choosing_home_folder:
		choosing_home_folder = false
		home_selected_folder = path
		update_home_hint()
		if not pending_home_prompt.is_empty():
			launch_home_creation()
		return
	if pending_home_prompt.is_empty():
		start_job({"action": "set_games_directory", "parent_directory": path})
		return
	home_selected_folder = path
	launch_home_creation()

func launch_home_creation() -> void:
	if pending_home_prompt.is_empty() or home_selected_folder.is_empty():
		return
	stopped_request = {}
	var first_prompt := pending_home_prompt
	pending_home_prompt = ""
	current = {}
	show_build = false
	detail_view = "效果"
	resource_tools.select_tab("游戏")
	picker.select(0)
	for i in range(model_picker.item_count):
		if model_picker.get_item_metadata(i) == selected_home_model():
			model_picker.select(i)
			break
	sync_model_efforts(model_picker, effort_picker)
	for i in range(effort_picker.item_count):
		if effort_picker.get_item_metadata(i) == selected_home_effort():
			effort_picker.select(i)
			break
	input.text = first_prompt
	show_idea()
	navigate("workspace")
	var request := {"action": "discuss", "prompt": first_prompt, "project_directory": home_selected_folder, "model": selected_home_model(), "reasoning_effort": selected_home_effort()}
	var pressed_delivery: Button = delivery_group.get_pressed_button()
	var delivery: String = str(pressed_delivery.get_meta("value")) if pressed_delivery != null else ""
	if not delivery.is_empty():
		request.delivery = delivery
	if not home_attachment.is_empty():
		request.attachment = home_attachment
	start_job(request)
	delivery_undecided.button_pressed = true
	if busy:
		input.text = ""
		home_input.text = ""
		show_idea()

func attach_chat_file(path: String) -> void:
	if current.is_empty():
		status.text = "先完成第一轮想法梳理，再添加角色或场景图片。"
		return
	var task: String = str(pending_asset_upload.get("task", ""))
	if not pending_asset_upload.is_empty() and (pending_asset_upload.idea_id != current.id or pending_asset_upload.revision != current.revision):
		pending_asset_upload = {}
		status.text = "方案或项目已变化，请重新选择要提供的素材。"
		return
	pending_asset_upload = {}
	var name := path.get_file().get_basename()
	var note := "我提供了一张图片《%s》，请先确认它在游戏里作为角色、场景还是参考图使用。" % name
	if not task.is_empty(): note = "我为方案中的「%s」提供了图片《%s》，请保留这张素材并确认具体用途。" % [task, name]
	if resource_tools.import_image(path, "参考图", task):
		input.text = input.text + ("\n\n" if not input.text.strip_edges().is_empty() else "") + note

func advance_creation() -> void:
	if has_build_plan():
		created_action("build_game")
	else:
		prepare_build()

func update_storage() -> void:
	var uses_project_folder := not current.is_empty() and not str(current.get("project_directory", "")).is_empty()
	var path := game_directory_for(current) if not current.is_empty() else games_directory()
	storage_path.text = path
	storage_message.text = status.text if busy or pending_action == "set_games_directory" else "这个项目的游戏、素材和所有版本都会保存在这里。" if uses_project_folder else "旧项目仍使用统一保存位置。新建游戏时，Playseed 会先让你选择独立文件夹。"
	choose_folder_button.disabled = busy
	choose_folder_button.visible = not uses_project_folder

func open_game_folder() -> void:
	var path := game_directory_for(current) if not current.is_empty() else games_directory()
	if not DirAccess.dir_exists_absolute(path):
		show_storage()
		storage_message.text = "还没有游戏文件夹，制作第一版游戏后会出现在这里。"
		return
	OS.shell_open(path)

func close_details() -> void:
	detail_view = "效果"
	show_build = false
	update_buttons()

func delivery_pill(parent: Node, text_value: String, value: String) -> Button:
	var b := compact(button(text_value, func(): pass))
	b.toggle_mode = true
	b.button_group = delivery_group
	b.set_meta("value", value)
	b.toggled.connect(func(is_on: bool):
		if is_on and delivery_note != null:
			delivery_note.text = {"native": "做成下载后在电脑上打开玩的游戏。", "web": "做成网页，把链接发给朋友就能玩。"}.get(value, "")
	)
	parent.add_child(b)
	return b

func compact(b: Button) -> Button:
	b.custom_minimum_size.y = 34
	b.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		box.content_margin_left = 12
		box.content_margin_right = 12
		b.add_theme_stylebox_override(state, box)
	return b

func round_action(b: Button, size_px: int, primary: bool = false, font_size: int = 22) -> Button:
	b.flat = false
	b.custom_minimum_size = Vector2(size_px, size_px)
	b.add_theme_font_size_override("font_size", font_size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(color_name, INK)
	b.add_theme_color_override("font_disabled_color", DISABLED_INK)
	var colors := button_states(primary)
	for state_name in colors:
		var box := style(colors[state_name])
		box.set_corner_radius_all(size_px / 2)
		box.content_margin_left = 0
		box.content_margin_right = 0
		box.content_margin_top = 0
		box.content_margin_bottom = 0
		if state_name == "focus":
			box.set_border_width_all(2)
			box.border_color = FOCUS_LINE
		b.add_theme_stylebox_override(state_name, box)
	return b

func style_selector(picker_control: OptionButton, width: int) -> OptionButton:
	picker_control.custom_minimum_size = Vector2(width, 42)
	picker_control.add_theme_font_size_override("font_size", 13)
	picker_control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var states := button_states(false)
	for state_name in states:
		var box := style(states[state_name])
		if state_name == "focus":
			box.set_border_width_all(2)
			box.border_color = FOCUS_LINE
		picker_control.add_theme_stylebox_override(state_name, box)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		picker_control.add_theme_color_override(color_name, INK)
	picker_control.add_theme_color_override("font_disabled_color", DISABLED_INK)
	style_choice_popup(picker_control)
	return picker_control

func style_choice_popup(control: OptionButton) -> void:
	var menu := control.get_popup()
	style_popup_menu(menu)
	menu.about_to_popup.connect(func(): position_choice_popup.call_deferred(control))

func style_popup_menu(menu: PopupMenu) -> void:
	var background := style(CARD)
	background.set_corner_radius_all(14)
	background.set_border_width_all(1)
	background.border_color = LINE
	background.content_margin_left = 10
	background.content_margin_right = 10
	background.content_margin_top = 10
	background.content_margin_bottom = 10
	background.shadow_size = 14
	background.shadow_color = Color(0.12, 0.22, 0.14, 0.07)
	background.shadow_offset = Vector2(0, 5)
	menu.add_theme_stylebox_override("panel", background)
	var hover := style(Color("eaf1e1"))
	hover.set_corner_radius_all(8)
	menu.add_theme_stylebox_override("hover", hover)
	menu.add_theme_font_size_override("font_size", 14)
	menu.add_theme_constant_override("v_separation", 10)
	menu.add_theme_constant_override("h_separation", 12)
	menu.add_theme_constant_override("item_start_padding", 8)
	menu.add_theme_constant_override("item_end_padding", 8)
	for name in ["font_color", "font_hover_color", "font_accelerator_color"]:
		menu.add_theme_color_override(name, INK)
	menu.add_theme_icon_override("radio_checked", nav_icon("selected-check"))
	menu.add_theme_icon_override("radio_unchecked", nav_icon("empty-check"))

func position_project_menu() -> void:
	var menu := more_menu.get_popup()
	if not menu.visible: return
	menu.size.x = 224
	var anchor := more_menu.get_global_rect()
	var bounds := get_viewport_rect()
	if not menu.is_embedded():
		anchor = get_viewport().get_screen_transform() * anchor
		bounds = Rect2(DisplayServer.screen_get_usable_rect())
	menu.position = Vector2i(clampf(anchor.end.x - menu.size.x, bounds.position.x + 12, bounds.end.x - menu.size.x - 12), clampf(anchor.end.y + 8, bounds.position.y + 12, bounds.end.y - menu.size.y - 12))

func position_choice_popup(control) -> void:
	var menu: PopupMenu = control.get_popup()
	if not menu.visible: return
	menu.size.x = maxi(220, int(control.size.x))
	var anchor: Rect2 = control.get_global_rect()
	var toolbar := (control.get_parent() as Control).get_global_rect()
	var bounds := get_viewport_rect()
	if control.get_viewport() != get_viewport():
		var to_root: Transform2D = get_viewport().get_screen_transform().affine_inverse() * control.get_viewport().get_screen_transform()
		anchor = to_root * anchor
		toolbar = to_root * toolbar
	if not menu.is_embedded():
		var transform := get_viewport().get_screen_transform()
		anchor = transform * anchor
		toolbar = transform * toolbar
		bounds = Rect2(DisplayServer.screen_get_usable_rect())
	var right_edge := minf(bounds.end.x - 12, toolbar.end.x)
	var x := clampf(anchor.position.x, bounds.position.x + 12, maxf(bounds.position.x + 12, right_edge - menu.size.x))
	var is_home: bool = control == home_model_picker or control == home_effort_picker
	var below: float = anchor.end.y + 10
	var above: float = anchor.position.y - menu.size.y - 10
	var y: float = below if is_home and below + menu.size.y <= bounds.end.y - 12 else above
	if y < bounds.position.y + 12: y = below
	menu.position = Vector2i(x, clampf(y, bounds.position.y + 12, maxf(bounds.position.y + 12, bounds.end.y - menu.size.y - 12)))

func workspace_selector(width: int) -> OptionButton:
	var control := style_selector(OptionButton.new(), width)
	control.custom_minimum_size.y = 34
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.fit_to_longest_item = false
	control.add_theme_font_size_override("font_size", 12)
	control.add_theme_constant_override("arrow_margin", 6)
	for state_name in button_states(false):
		var box: StyleBoxFlat = control.get_theme_stylebox(state_name).duplicate()
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		box.set_corner_radius_all(8)
		if state_name == "normal": box.bg_color = CARD
		control.add_theme_stylebox_override(state_name, box)
	return control

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and detail_overlay.visible:
		close_details()
		get_viewport().set_input_as_handled()

# Enter sends, Shift+Enter keeps writing on a new line.
func wire_enter_send(field: TextEdit, action: Callable) -> void:
	field.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not event.shift_pressed:
			field.accept_event()
			action.call()
	)


func _ready() -> void:
	TranslationServer.set_locale("zh_CN")
	get_window().title = "Playseed · AI 游戏创作"
	data_dir = root_dir.path_join(".playseed")
	get_window().min_size = Vector2i(1100, 760)
	configure_startup_window.call_deferred()
	build_ui()
	sidebar_collapsed = bool(read_json(data_dir.path_join("creator-ui.json")).get("sidebar_collapsed", false))
	load_dimension_choices()
	load_ideas()
	apply_sidebar()
	navigate("home")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--idea="):
			load_ideas(argument.trim_prefix("--idea="))
			if not current.is_empty():
				navigate("workspace")
	var timer := Timer.new()
	timer.wait_time = 0.3
	timer.timeout.connect(poll_job)
	add_child(timer)
	timer.start()
	refresh_gpt_account()
	var account_timer := Timer.new()
	account_timer.wait_time = 3.0
	account_timer.timeout.connect(refresh_gpt_account)
	add_child(account_timer)
	account_timer.start()

func configure_startup_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var target := Vector2i(usable.size * 0.9)
	get_window().min_size = Vector2i(mini(1100, target.x), mini(760, target.y))
	get_window().size = target
	get_window().position = usable.position + (usable.size - target) / 2
	# The bundled editor runtime adds a debug suffix to Window.title.
	# Set the native title only; runtime diagnostics remain enabled.
	DisplayServer.window_set_title("Playseed · AI 游戏创作", get_window().get_window_id())

func fill_models(control: OptionButton) -> void:
	control.clear()
	var catalog := read_json(root_dir.path_join("app/model_catalog.json"))
	for entry in catalog.get("models", []):
		control.add_item(entry.name)
		control.set_item_metadata(control.item_count - 1, entry.id)
		if entry.id == catalog.get("default_model", "gpt-5.6-sol"): control.select(control.item_count - 1)

func sync_model_efforts(model_state: OptionButton, effort_state: OptionButton) -> void:
	var previous: String = str(effort_state.get_item_metadata(effort_state.selected)) if effort_state.selected >= 0 else "medium"
	var names := {"low":"低", "medium":"中", "high":"高", "xhigh":"超高", "max":"最高"}
	for entry in read_json(root_dir.path_join("app/model_catalog.json")).get("models", []):
		if entry.id != model_state.get_item_metadata(model_state.selected): continue
		effort_state.clear()
		for value in entry.efforts:
			effort_state.add_item("强度：" + names[value])
			effort_state.set_item_metadata(effort_state.item_count - 1, value)
		var selected: int = entry.efforts.find(previous)
		effort_state.select(selected if selected >= 0 else entry.efforts.find("high"))

func composer_surface() -> StyleBoxFlat:
	var surface := style(CARD)
	surface.set_corner_radius_all(20)
	surface.set_border_width_all(1)
	surface.border_color = LINE
	surface.shadow_color = SHADOW
	surface.shadow_size = 14
	surface.shadow_offset = Vector2(0, 5)
	return surface

func style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(12)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func label(text: String, size: int = 17, color: Color = INK, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func button_states(primary: bool) -> Dictionary:
	return {
		"normal": PRIMARY if primary else NEUTRAL,
		"hover": PRIMARY_HOVER if primary else NEUTRAL_HOVER,
		"pressed": PRIMARY_PRESSED if primary else NEUTRAL_PRESSED,
		"focus": PRIMARY_HOVER if primary else NEUTRAL_HOVER,
		"disabled": DISABLED
	}

func button(text: String, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var states := button_states(primary)
	for state_name in states:
		var box := style(states[state_name])
		if state_name == "focus":
			box.set_border_width_all(2)
			box.border_color = FOCUS_LINE
		b.add_theme_stylebox_override(state_name, box)
	for name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(name, INK)
	b.add_theme_color_override("font_disabled_color", DISABLED_INK)
	b.pressed.connect(action)
	return b

func panel(parent: Node) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(CARD))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	return v

func build_ui() -> void:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Arial"])
	t.default_font = font
	t.default_font_size = 16
	var option_states := button_states(false)
	for state in option_states:
		t.set_stylebox(state, "OptionButton", style(option_states[state]))
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "OptionButton", INK)
	t.set_color("font_disabled_color", "OptionButton", DISABLED_INK)
	t.set_stylebox("panel", "PopupMenu", style(POPUP))
	t.set_color("font_color", "OptionButton", INK)
	t.set_color("font_color", "PopupMenu", INK)
	# Popups that are not styled individually keep the product light highlight, never the system dark bar.
	var popup_hover := style(Color("eaf1e1"))
	popup_hover.set_corner_radius_all(8)
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_stylebox("pressed", "PopupMenu", popup_hover)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_color("font_pressed_color", "PopupMenu", INK)
	# Selected text inside inputs and the code view stays in the light palette.
	for text_kind in ["LineEdit", "TextEdit"]:
		t.set_color("selection_color", text_kind, Color("cfe2b8"))
		t.set_color("caret_color", text_kind, ACCENT_INK)
	for check_state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(check_state, "CheckButton", INK)
	t.set_color("font_disabled_color", "CheckButton", DISABLED_INK)
	# Tooltips keep the light product look instead of the system dark bar.
	var tip_panel := style(CARD)
	tip_panel.set_corner_radius_all(10)
	tip_panel.set_border_width_all(1)
	tip_panel.border_color = LINE
	tip_panel.shadow_color = Color(0.12, 0.22, 0.14, 0.08)
	tip_panel.shadow_size = 8
	tip_panel.shadow_offset = Vector2(0, 3)
	tip_panel.content_margin_left = 10
	tip_panel.content_margin_right = 10
	tip_panel.content_margin_top = 7
	tip_panel.content_margin_bottom = 7
	t.set_stylebox("panel", "TooltipPanel", tip_panel)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 13)
	# Keep the hit area comfortable while drawing a slimmer, quiet scroll thumb.
	var track := StyleBoxFlat.new()
	track.bg_color = Color.TRANSPARENT
	track.content_margin_left = 7
	track.content_margin_right = 7
	for state in ["scroll", "scroll_focus"]: t.set_stylebox(state, "VScrollBar", track)
	for spec in [["grabber", "bdc8ba"], ["grabber_highlight", "98aa92"], ["grabber_pressed", "788e71"]]:
		var thumb := StyleBoxFlat.new()
		thumb.bg_color = Color(spec[1])
		thumb.set_corner_radius_all(4)
		thumb.content_margin_left = 7
		thumb.content_margin_right = 7
		thumb.content_margin_top = 14
		thumb.content_margin_bottom = 14
		thumb.expand_margin_left = -3
		thumb.expand_margin_right = -3
		t.set_stylebox(spec[0], "VScrollBar", thumb)
	var empty_icon := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	empty_icon.fill(Color.TRANSPARENT)
	for icon_name in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
		t.set_icon(icon_name, "VScrollBar", ImageTexture.create_from_image(empty_icon))
	theme = t
	var bg := ColorRect.new()
	bg.color = SURFACE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shell := HBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 0)
	add_child(shell)
	var side_panel := PanelContainer.new()
	sidebar = side_panel
	side_panel.custom_minimum_size.x = 188
	side_panel.size_flags_horizontal = Control.SIZE_FILL
	var side_style := style(RAIL)
	side_style.set_corner_radius_all(0)
	side_style.content_margin_top = 18
	side_panel.add_theme_stylebox_override("panel", side_style)
	shell.add_child(side_panel)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side_panel.add_child(side)
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 8)
	side.add_child(brand)
	brand_logo = Button.new()
	brand_logo.icon = load("res://assets/playseed-icon.png")
	brand_logo.expand_icon = true
	brand_logo.add_theme_constant_override("icon_max_width", 36)
	brand_logo.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand_logo.custom_minimum_size = Vector2(48, 48)
	brand_logo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		brand_logo.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	brand_logo.pressed.connect(expand_sidebar)
	brand.add_child(brand_logo)
	brand_name = label("Playseed", 25)
	brand_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(brand_name)
	brand_tagline = label("让每个人都有自己的游戏", 12, MUTED)
	side.add_child(brand_tagline)
	sidebar_toggle = Button.new()
	sidebar_toggle.icon = nav_icon("collapse")
	sidebar_toggle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sidebar_toggle.custom_minimum_size = Vector2(32, 40)
	sidebar_toggle.tooltip_text = "收起侧栏"
	sidebar_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]:
		sidebar_toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	sidebar_toggle.pressed.connect(toggle_sidebar)
	brand.add_child(sidebar_toggle)
	home_button = nav_button("创作主页", "home", func(): expand_sidebar(); navigate("home"))
	side.add_child(home_button)
	lab_button = button("", func(): pass)
	lab_button.visible = false
	side.add_child(lab_button)
	sidebar_caption = label("项目", 13, MUTED)
	side.add_child(sidebar_caption)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(side_scroll)
	sidebar_projects = VBoxContainer.new()
	sidebar_projects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_projects.add_theme_constant_override("separation", 6)
	side_scroll.add_child(sidebar_projects)
	account_button = nav_button("登录 GPT 账号", "account", func(): expand_sidebar(); select_detail("账号"))
	account_button.icon = load("res://assets/playseed-mascot-farmer-v1.png")
	account_button.add_theme_constant_override("icon_max_width", 40)
	side.add_child(account_button)
	sidebar_footer = label("本机创作 · 0.8.39", 12, MUTED)
	side.add_child(sidebar_footer)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	shell.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	route_title = label("创作首页", 16, INK)
	route_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	route_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(route_title)
	workspace_tools = HBoxContainer.new()
	workspace_tools.add_theme_constant_override("separation", 6)
	header.add_child(workspace_tools)
	var tools_separator := VSeparator.new()
	workspace_tools.add_child(tools_separator)
	more_menu = MenuButton.new()
	more_menu.text = "项目  ▾"
	more_menu.flat = false
	more_menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	more_menu.tooltip_text = "方案、版本和项目设置"
	more_menu.custom_minimum_size = Vector2(88, 44)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var background := style(NEUTRAL if state == "normal" else Color("e4eed8"))
		background.set_corner_radius_all(12)
		background.content_margin_left = 14
		background.content_margin_right = 14
		more_menu.add_theme_stylebox_override(state, background)
	more_menu.add_theme_font_size_override("font_size", 13)
	for text_state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		more_menu.add_theme_color_override(text_state, INK)
	style_popup_menu(more_menu.get_popup())
	more_menu.get_popup().about_to_popup.connect(func(): position_project_menu.call_deferred())
	more_menu.get_popup().add_item("游戏方案", 0)
	more_menu.get_popup().add_item("制作清单", 1)
	more_menu.get_popup().add_item("版本历史", 2)
	more_menu.get_popup().add_separator()
	more_menu.get_popup().add_item("打开项目文件夹", 3)
	more_menu.get_popup().id_pressed.connect(func(id):
		if id == 0: select_detail("方案")
		elif id == 1: select_detail("制作清单")
		elif id == 2: select_detail("版本")
		elif id == 3: open_game_folder()
	)
	workspace_tools.add_child(more_menu)
	build_project_dialogs()
	build_home(outer)
	library = ScrollContainer.new()
	library.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	library.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(library)
	project_list = VBoxContainer.new()
	project_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_list.add_theme_constant_override("separation", 14)
	library.add_child(project_list)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(page)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)
	var left := panel(body)
	left.get_parent().custom_minimum_size.x = 400
	chat_column = left.get_parent()
	left.add_theme_constant_override("separation", 8)
	left.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var chat_heading := HBoxContainer.new()
	left.add_child(chat_heading)
	chat_heading.add_child(mascot_mark(24))
	chat_heading.add_child(label("Playseed", 15))
	var chat_hint := label("创作助手", 12, MUTED)
	chat_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chat_heading.add_child(chat_hint)
	left.add_child(HSeparator.new())
	flow_label = label("第 1 步 · 说出想法", 13, MUTED, true)
	left.add_child(flow_label)
	picker = OptionButton.new()
	picker.item_selected.connect(func(i): select_idea(i - 1))
	picker.visible = false
	left.add_child(picker)
	chat_scroll = ScrollContainer.new()
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.custom_minimum_size.y = 120
	left.add_child(chat_scroll)
	chat = VBoxContainer.new()
	chat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat.add_theme_constant_override("separation", 14)
	var timeline := VBoxContainer.new()
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.add_theme_constant_override("separation", 12)
	chat_scroll.add_child(timeline)
	timeline.add_child(chat)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	timeline.add_child(choices)
	next_hint = label("", 13, MUTED, true)
	left.add_child(next_hint)
	confirm = button("确认方案", confirm_plan, true)
	left.add_child(confirm)
	build_game_button = button("准备素材和制作清单", advance_creation, true)
	left.add_child(build_game_button)
	dimension_picker = OptionButton.new()
	dimension_picker.add_item("制作 2D 游戏")
	dimension_picker.add_item("实验性 3D · 房间寻物")
	dimension_picker.tooltip_text = "3D首轮支持几何体房间、行走碰撞、寻物与出口；静态基础色GLB可作障碍外观；贴图、跳跃、战斗和3D声音尚未接通。"
	dimension_picker.item_selected.connect(select_dimension)
	left.add_child(dimension_picker)
	progress_bar = ProgressBar.new()
	progress_bar.indeterminate = true
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 4
	for entry in [["background", TRACK], ["fill", FILL]]:
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = entry[1]
		bar_style.set_corner_radius_all(2)
		progress_bar.add_theme_stylebox_override(entry[0], bar_style)
	left.add_child(progress_bar)
	status = label("", 13, MUTED, true)
	left.add_child(status)
	process_toggle = button("查看本轮过程 ▾", func(): process_open = not process_open; update_process())
	compact(process_toggle)
	process_toggle.custom_minimum_size.y = 28
	process_toggle.add_theme_font_size_override("font_size", 12)
	left.add_child(process_toggle)
	process_scroll = ScrollContainer.new()
	process_scroll.custom_minimum_size.y = 100
	process_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(process_scroll)
	process_details = label("", 13, MUTED, true)
	process_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	process_scroll.add_child(process_details)
	cancel = round_action(button("■", cancel_job), 40, false, 14)
	cancel.tooltip_text = "停止本次生成"
	input = TextEdit.new()
	input.text_changed.connect(func():
		if not pending_asset_generation.is_empty() and not input.text.begins_with(str(pending_asset_generation.prefix)):
			pending_asset_generation = {}
	)
	input.custom_minimum_size.y = 64
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.placeholder_text = "说说你的想法，或者想调整的地方…"
	for state in ["normal", "read_only"]:
		var text_style := style(CARD)
		text_style.content_margin_left = 8
		text_style.content_margin_right = 8
		text_style.content_margin_top = 8
		text_style.content_margin_bottom = 8
		input.add_theme_stylebox_override(state, text_style)
	input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	input.add_theme_color_override("font_color", INK)
	input.add_theme_color_override("font_readonly_color", INK)
	input.add_theme_color_override("font_placeholder_color", PLACEHOLDER)
	input.add_theme_color_override("caret_color", INK)
	var composer := PanelContainer.new()
	var composer_style := composer_surface()
	composer_style.set_corner_radius_all(20)
	composer_style.set_border_width_all(1)
	composer_style.border_color = LINE
	composer_style.shadow_color = SHADOW
	composer_style.shadow_size = 14
	composer_style.shadow_offset = Vector2(0, 5)
	composer_style.content_margin_left = 16
	composer_style.content_margin_right = 16
	composer_style.content_margin_top = 8
	composer_style.content_margin_bottom = 12
	composer.add_theme_stylebox_override("panel", composer_style)
	left.add_child(composer)
	input.focus_entered.connect(func():
		composer_style.border_color = FOCUS_LINE
		composer.queue_redraw()
	)
	input.focus_exited.connect(func():
		composer_style.border_color = LINE
		composer.queue_redraw()
	)
	var compose_content := VBoxContainer.new()
	compose_content.add_theme_constant_override("separation", 8)
	composer.add_child(compose_content)
	compose_content.add_child(input)
	var compose_actions := HBoxContainer.new()
	compose_actions.add_theme_constant_override("separation", 8)
	compose_content.add_child(compose_actions)
	composer_mode = OptionButton.new()
	composer_mode.add_item("聊方案")
	composer_mode.add_item("改游戏")
	composer_mode.visible = false
	attachment_button = round_action(button("", func(): chat_file_dialog.popup_centered_ratio(0.7)), 40, false, 23)
	attachment_button.icon = nav_icon("plus")
	attachment_button.expand_icon = false
	attachment_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	attachment_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attachment_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	attachment_button.add_theme_constant_override("icon_max_width", 22)
	attachment_button.tooltip_text = "添加角色、场景或参考图片"
	compose_actions.add_child(attachment_button)
	model_picker = workspace_selector(116)
	model_picker.tooltip_text = "选择本次创作使用的模型"
	compose_actions.add_child(model_picker)
	effort_picker = workspace_selector(88)
	for effort in [["强度：低", "low"], ["强度：中", "medium"], ["强度：高", "high"], ["强度：超高", "xhigh"], ["强度：最高", "max"]]:
		effort_picker.add_item(effort[0])
		effort_picker.set_item_metadata(effort_picker.item_count - 1, effort[1])
	effort_picker.select(1)
	effort_picker.tooltip_text = "选择本次创作的思考强度；越高通常越慢"
	compose_actions.add_child(effort_picker)
	workspace_model_controls = load("res://model_controls.gd").new()
	compose_actions.add_child(workspace_model_controls)
	fill_models(model_picker)
	workspace_model_controls.setup(self, model_picker, effort_picker, false)
	var compose_space := Control.new()
	compose_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compose_space.custom_minimum_size.x = 8
	compose_actions.add_child(compose_space)
	send = round_action(button("↑", submit_composer, true), 40, true, 20)
	send.tooltip_text = "发送（回车；Shift+回车换行）"
	compose_actions.add_child(send)
	compose_actions.add_child(cancel)
	wire_enter_send(input, submit_composer)
	var right := panel(body)
	var preview_toolbar := HBoxContainer.new()
	right.add_child(preview_toolbar)
	preview_heading = label("游戏预览",14,MUTED)
	preview_toolbar.add_child(preview_heading)
	var preview_space := Control.new()
	preview_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_toolbar.add_child(preview_space)
	play_game_button = compact(button("打开试玩 ↗", func(): created_action("play_created"), true))
	preview_toolbar.add_child(play_game_button)
	effect_box = VBoxContainer.new()
	effect_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(effect_box)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", style(FRAME))
	effect_box.add_child(frame)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(preview)
	preview_empty = VBoxContainer.new()
	preview_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_empty.add_theme_constant_override("separation", 18)
	frame.add_child(preview_empty)
	preview_empty.add_child(mascot_mark(64))
	preview_note = label("先聊一个想法\n做好的游戏会展示在这里", 18, MUTED, true)
	preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_empty.add_child(preview_note)
	game_label = label("", 14, MUTED, true)
	effect_box.add_child(game_label)
	var effect_actions := HBoxContainer.new()
	effect_box.add_child(effect_actions)
	refresh_preview = button("生成画面预览", func(): created_action("preview_created"))
	refresh_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_actions.add_child(refresh_preview)
	var effect_spacer := Control.new()
	effect_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_actions.add_child(effect_spacer)

	resource_tools = load("res://workspace_resources.gd").new()
	right.add_child(resource_tools)
	resource_tools.setup(self, workspace_tools)

	detail_overlay = Control.new()
	detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(detail_overlay)
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_overlay.add_child(shade)
	shade.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: close_details()
	)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_overlay.add_child(center)
	var modal := panel(center)
	modal.get_parent().custom_minimum_size = Vector2(760, 560)
	modal.get_parent().mouse_filter = Control.MOUSE_FILTER_STOP
	var modal_header := HBoxContainer.new()
	modal.add_child(modal_header)
	detail_heading = label("游戏方案", 21)
	detail_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_header.add_child(detail_heading)
	modal_close = compact(button("关闭 ×", close_details))
	modal_header.add_child(modal_close)
	modal.add_child(HSeparator.new())
	plan_box = VBoxContainer.new()
	plan_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal.add_child(plan_box)
	var plan_scroll := ScrollContainer.new()
	plan_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	plan_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plan_box.add_child(plan_scroll)
	plan_text = label("", 17, INK, true)
	plan_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_text.add_theme_constant_override("line_spacing", 6)
	plan_scroll.add_child(plan_text)
	prepare = button("准备制作清单", prepare_build)
	plan_box.add_child(prepare)
	history_box = VBoxContainer.new()
	history_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_box.add_theme_constant_override("separation", 14)
	modal.add_child(history_box)
	history_box.add_child(label("每次制作和修改都会留下一个版本。选择左边的版本查看详情。", 14, MUTED, true))
	game_versions = OptionButton.new()
	game_versions.fit_to_longest_item = false
	game_versions.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	game_versions.item_selected.connect(func(_i): show_version_details())
	game_versions.visible = false
	history_box.add_child(game_versions)
	var history_body := HBoxContainer.new()
	history_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_body.add_theme_constant_override("separation", 16)
	history_box.add_child(history_body)
	var version_list_panel := PanelContainer.new()
	version_list_panel.custom_minimum_size.x = 230
	version_list_panel.size_flags_horizontal = Control.SIZE_FILL
	version_list_panel.add_theme_stylebox_override("panel", style(FRAME))
	history_body.add_child(version_list_panel)
	var version_list_wrap := VBoxContainer.new()
	version_list_wrap.add_theme_constant_override("separation", 8)
	version_list_panel.add_child(version_list_wrap)
	version_list_wrap.add_child(label("所有版本", 14, MUTED))
	var version_list_scroll := ScrollContainer.new()
	version_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	version_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	version_list_wrap.add_child(version_list_scroll)
	version_list = VBoxContainer.new()
	version_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_list.add_theme_constant_override("separation", 7)
	version_list_scroll.add_child(version_list)
	var version_detail := VBoxContainer.new()
	version_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	version_detail.add_theme_constant_override("separation", 8)
	history_body.add_child(version_detail)
	version_heading = label("还没有版本", 22)
	version_detail.add_child(version_heading)
	version_meta = label("", 13, MUTED, true)
	version_detail.add_child(version_meta)
	version_summary_text = label("制作游戏后，这里会记录每一次变化。", 16, INK, true)
	version_detail.add_child(version_summary_text)
	version_detail.add_child(HSeparator.new())
	var history_scroll := ScrollContainer.new()
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	version_detail.add_child(history_scroll)
	history_text = label("", 15, INK, true)
	history_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_text.add_theme_constant_override("line_spacing", 5)
	history_scroll.add_child(history_text)
	restore_game_button = button("恢复为新版本", restore_created_game, true)
	version_detail.add_child(restore_game_button)
	account_box = VBoxContainer.new()
	account_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	account_box.add_theme_constant_override("separation", 18)
	modal.add_child(account_box)
	account_status = label("正在检查 GPT 账号…", 22)
	account_box.add_child(account_status)
	account_message = label("Playseed 使用 OpenAI 的登录流程，不会保存你的密码。", 16, MUTED, true)
	account_box.add_child(account_message)
	var account_help := panel(account_box)
	account_help.add_child(label("登录以后", 15))
	account_help.add_child(label("• 使用你账号可用的 GPT 模型\n• 消耗该账号对应的使用额度\n• 退出登录后停止新的 AI 请求", 15, MUTED, true))
	var account_space := Control.new()
	account_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	account_box.add_child(account_space)
	account_login_button = button("登录 GPT 账号…", begin_gpt_login, true)
	account_box.add_child(account_login_button)
	account_logout_button = button("退出 GPT 账号", logout_gpt)
	account_box.add_child(account_logout_button)

	storage_box = VBoxContainer.new()
	storage_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	storage_box.add_theme_constant_override("separation", 18)
	modal.add_child(storage_box)
	storage_box.add_child(label("这个项目的保存位置", 16))
	storage_path = label("", 17, INK, true)
	storage_box.add_child(storage_path)
	storage_message = label("", 15, MUTED, true)
	storage_box.add_child(storage_message)
	choose_folder_button = button("选择文件夹…", open_storage_picker, true)
	storage_box.add_child(choose_folder_button)
	storage_box.add_child(button("打开保存文件夹", func():
		if DirAccess.dir_exists_absolute(games_directory()): OS.shell_open(games_directory())
		else: storage_message.text = "制作第一版游戏后，这个文件夹会自动建立。"
	))
	folder_dialog = FileDialog.new()
	folder_dialog.title = "选择游戏保存位置"
	folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	folder_dialog.use_native_dialog = true
	folder_dialog.ok_button_text = "选择此文件夹"
	folder_dialog.cancel_button_text = "取消"
	folder_dialog.current_dir = root_dir
	folder_dialog.dir_selected.connect(folder_selected)
	folder_dialog.canceled.connect(func():
		choosing_home_folder = false
		if not pending_home_prompt.is_empty():
			set_home_hint("还没有选择文件夹，你的想法仍然保留在这里。")
		pending_home_prompt = ""
	)
	add_child(folder_dialog)
	chat_file_dialog = FileDialog.new()
	chat_file_dialog.title = "添加角色、场景或参考图片"
	chat_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	chat_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	chat_file_dialog.use_native_dialog = true
	chat_file_dialog.ok_button_text = "添加图片"
	chat_file_dialog.cancel_button_text = "取消"
	chat_file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片文件"])
	chat_file_dialog.file_selected.connect(attach_chat_file)
	chat_file_dialog.canceled.connect(func(): pending_asset_upload = {})
	add_child(chat_file_dialog)

func update_process() -> void:
	var request := read_json(active_job.path_join("request.json")) if not active_job.is_empty() else {}
	var result := read_json(active_job.path_join("result.json")) if not active_job.is_empty() else {}
	var matches: bool = busy or (not current.is_empty() and (request.get("idea_id", "") == current.id or result.get("idea", {}).get("id", "") == current.id))
	process_toggle.visible = matches
	process_scroll.visible = matches and process_open
	process_toggle.text = "收起本轮过程 ▴" if process_open else "查看本轮过程 ▾"
	if not matches:
		return
	var history := read_json(active_job.path_join("events.json"))
	var lines := PackedStringArray()
	for event in history.get("events", []):
		var marker: String = "已停止" if event.state == "cancelled" else "未完成" if event.state == "error" else "已返回" if event.state == "done" else "进行到"
		lines.append("%s · %s" % [marker, event.message])
	process_details.text = "\n\n".join(lines) if not lines.is_empty() else "请求已提交，正在等待本地服务。"

func prepare_asset_task(task: String, source: String) -> void:
	if busy or current.is_empty() or current.get("status", "") != "confirmed":
		status.text = "先确认方案，并等待本轮任务结束。"
		return
	if source == "upload":
		pending_asset_upload = {"task": task, "idea_id": current.id, "revision": current.revision}
		chat_file_dialog.popup_centered_ratio(0.7)
		return
	if not input.text.strip_edges().is_empty():
		status.text = "输入框里还有草稿，请先发送或清空，再准备这项素材。"
		return
	input.text = "生成图片：为「%s」制作一张2D游戏素材。用途要求：%s。统一画风：%s。先只生成这一项。" % [current.plan.title, task, current.plan.visual_style]
	pending_asset_generation = {"task": task, "idea_id": current.id, "revision": current.revision, "prefix": input.text.get_slice("统一画风：", 0)}
	input.grab_focus()
	input.set_caret_column(input.text.length())
	status.text = "需求已填入聊天框；采用生成图片后会自动关联这项素材。"

func asset_assignment_text(task: String) -> String:
	var manifest := read_json(game_directory_for(current).path_join("library/library.json"))
	var asset_id: String = str(manifest.get("task_bindings", {}).get(str(current.revision), {}).get(task, ""))
	for asset in manifest.get("assets", []):
		if asset.id == asset_id:
			if not FileAccess.file_exists(game_directory_for(current).path_join("library/" + asset_id + ".png")):
				return "关联图片已丢失，请重新导入或更换。"
			return "已关联：%s · 尚未验证用于游戏" % asset.name
	return "尚未关联图片"

func add_asset_binding(guide: VBoxContainer, selector: OptionButton, tasks: Array) -> void:
	var state := label(asset_assignment_text(str(tasks[selector.selected])), 13, MUTED, true)
	guide.add_child(state)
	selector.item_selected.connect(func(i): state.text = asset_assignment_text(str(tasks[i])))
	var choose := MenuButton.new()
	choose.name = "AssetBindingMenu"
	choose.text = "关联已入库图片  ▾"
	choose.flat = false
	choose.custom_minimum_size.y = 38
	choose.add_theme_font_size_override("font_size", 13)
	for name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		choose.add_theme_color_override(name, INK)
	for name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		choose.add_theme_stylebox_override(name, style(NEUTRAL))
	var menu := choose.get_popup()
	style_popup_menu(menu)
	menu.max_size = Vector2i(360, 360)
	menu.about_to_popup.connect(func(): position_choice_popup.call_deferred(choose))
	var manifest := read_json(game_directory_for(current).path_join("library/library.json"))
	var assets: Array = manifest.get("assets", [])
	menu.add_item("解除关联（保留图片）", 0)
	menu.add_separator()
	for i in range(assets.size()):
		var asset_name: String = str(assets[i].name)
		menu.add_item(asset_name.left(14) + ("…" if asset_name.length() > 14 else ""), i + 1)
		menu.set_item_tooltip(i + 2, asset_name)
	var idea_id: String = current.id
	var revision: int = current.revision
	menu.id_pressed.connect(func(id):
		if busy: return
		start_job({"action": "bind_asset_task", "idea_id": idea_id, "revision": revision, "task": str(tasks[selector.selected]), "asset_id": "" if id == 0 else str(assets[id - 1].id)})
	)
	choose.disabled = busy or assets.is_empty()
	choose.tooltip_text = "请先上传图片或采用一张生成草稿" if assets.is_empty() else "选择图片后保存对应关系；不会自动修改游戏"
	guide.add_child(choose)

func current_asset_tasks() -> Array:
	var originals: Array = current.get("plan", {}).get("asset_plan", [])
	var manifest := read_json(game_directory_for(current).path_join("library/library.json"))
	var splits: Dictionary = manifest.get("task_splits", {}).get(str(current.revision), {})
	var tasks: Array = []
	for i in range(originals.size()):
		var split: Dictionary = splits.get(str(originals[i]), {})
		if split.get("state", "") == "accepted":
			for item in split.items: tasks.append("素材%d · %s" % [i + 1, item])
		else: tasks.append(originals[i])
	return tasks

func show_asset_split_reviews(guide: VBoxContainer = null) -> void:
	var manifest := read_json(game_directory_for(current).path_join("library/library.json"))
	var splits: Dictionary = manifest.get("task_splits", {}).get(str(current.revision), {})
	for parent in splits:
		var split: Dictionary = splits[parent]
		if split.get("state", "") != "review": continue
		if guide == null: guide = panel(chat)
		guide.add_child(label("单张图片任务 · 待确认", 14, INK))
		guide.add_child(label(str(split.explanation), 14, MUTED, true))
		guide.add_child(label(bullets(split.items), 15, INK, true))
		guide.add_child(label("仅拆分准备任务，原图片、关联和游戏均保留。", 13, MUTED, true))
		for spec in [["确认这份拆分", "accept_asset_split"], ["保留原任务", "discard_asset_split"]]:
			var action: String = spec[1]
			var task: String = str(parent)
			var split_id: String = split.id
			var choice := button(spec[0], func(): created_action(action, {"task": task, "split_id": split_id}))
			choice.disabled = busy
			guide.add_child(choice)

func style_reference_key() -> String:
	return str(current.get("id", "")) + ":" + str(current.get("revision", 0))

func add_style_reference_picker(guide: VBoxContainer) -> void:
	guide.add_child(label("生成画风参考 · 可选", 13, MUTED))
	var picker := style_selector(OptionButton.new(), 0)
	picker.name = "StyleReferencePicker"
	picker.fit_to_longest_item = false
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("不使用参考图")
	picker.set_item_metadata(0, "")
	var assets: Array = read_json(game_directory_for(current).path_join("library/library.json")).get("assets", [])
	for asset in assets:
		picker.add_item(str(asset.name).left(24))
		picker.set_item_metadata(picker.item_count - 1, str(asset.id))
	var key := style_reference_key()
	var selected: String = str(style_reference_selection.get(key, ""))
	for i in range(picker.item_count):
		if picker.get_item_metadata(i) == selected: picker.select(i)
	picker.disabled = busy
	guide.add_child(picker)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(80, 72)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	guide.add_child(preview)
	var update := func(i):
		var id: String = str(picker.get_item_metadata(i))
		style_reference_selection[key] = id
		preview.texture = null
		preview.visible = not id.is_empty()
		if not id.is_empty():
			var image := Image.load_from_file(game_directory_for(current).path_join("library/" + id + ".png"))
			if image != null: preview.texture = ImageTexture.create_from_image(image)
	picker.item_selected.connect(update)
	update.call(picker.selected)
	guide.add_child(label("只参考配色与笔触，生成后仍需预览确认。可通过＋先上传参考图。", 13, MUTED, true))

func show_asset_preparation() -> void:
	var guide := panel(chat)
	guide.add_child(label("准备游戏画面", 14, MUTED))
	add_style_reference_picker(guide)
	var tasks: Array = current_asset_tasks()
	if tasks.is_empty():
		guide.add_child(label("先描述需要的角色、场景或道具，每次准备一张。", 15, MUTED, true))
		var generate := button("描述要生成的图片", prepare_asset_prompt)
		generate.disabled = busy
		guide.add_child(generate)
		return
	guide.add_child(label("按方案逐项准备。选择一项，再决定由平台生成，或提供自己的图片。", 15, MUTED, true))
	var selector := style_selector(OptionButton.new(), 0)
	selector.fit_to_longest_item = false
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(tasks.size()): selector.add_item("素材 %d · %s" % [i + 1, str(tasks[i]).left(18)])
	selector.disabled = busy
	var remembered: int = tasks.find(asset_task_selection.get(current.id, ""))
	selector.select(maxi(0, remembered))
	guide.add_child(selector)
	var detail := label(str(tasks[selector.selected]), 15, INK, true)
	guide.add_child(detail)
	selector.item_selected.connect(func(i):
		detail.text = str(tasks[i])
		asset_task_selection[current.id] = str(tasks[i])
	)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	guide.add_child(actions)
	var generate := button("平台生成", func(): prepare_asset_task(str(tasks[selector.selected]), "generate"))
	var upload := button("我提供图片", func(): prepare_asset_task(str(tasks[selector.selected]), "upload"))
	for action in [generate, upload]:
		action.disabled = busy
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(action)
	add_asset_binding(guide, selector, tasks)
	var split_button := button("拆成单张图片任务", func(): created_action("prepare_asset_split", {"task": str(tasks[selector.selected])}))
	split_button.disabled = busy or not str(tasks[selector.selected]) in current.plan.asset_plan
	split_button.text = "这一项有多个角色？分别准备…"
	split_button.tooltip_text = "例如小鸟和小猪：拆开后逐张生成，避免混在一张图片里。"
	selector.item_selected.connect(func(i): split_button.disabled = busy or not str(tasks[i]) in current.plan.asset_plan)
	guide.add_child(split_button)

func prepare_asset_prompt() -> void:
	pending_asset_generation = {}
	input.text = "生成图片："
	input.grab_focus()
	input.set_caret_column(input.text.length())
	status.text = "描述要生成的角色、道具或场景，以及画风。每次生成一张，先预览再采用。"

func show_asset_drafts() -> void:
	var folder := game_directory_for(current).path_join("image-drafts")
	if not DirAccess.dir_exists_absolute(folder):
		return
	var files: Array = Array(DirAccess.get_files_at(folder)).filter(func(file): return str(file).ends_with(".json"))
	files.sort_custom(func(a, b): return str(read_json(folder.path_join(a)).get("created_at", "")) < str(read_json(folder.path_join(b)).get("created_at", "")))
	for file in files:
		if not file.ends_with(".json"):
			continue
		var draft := read_json(folder.path_join(file))
		if draft.get("state", "") != "review":
			continue
		var card := panel(chat)
		card.add_child(label("本机去背景稿 · 请检查" if draft.get("provider", "") == "macOS本机背景分离" else "透明背景修复稿 · 请检查" if draft.has("repairs_draft_id") else "素材草稿 · 等你确认", 14, MUTED))
		for reference in draft.get("style_references", []):
			card.add_child(label("画风参考：" + str(reference.name), 13, MUTED, true))
		card.add_child(label(str(draft.get("prompt", "")), 16, INK, true))
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(180, 220)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var image := Image.load_from_file(folder.path_join(str(draft.id) + ".png"))
		if image != null:
			picture.texture = ImageTexture.create_from_image(image)
		var preview_frame := PanelContainer.new()
		preview_frame.add_theme_stylebox_override("panel", style(Color("f4f6f1")))
		preview_frame.add_child(picture)
		card.add_child(preview_frame)
		if draft.has("repairs_draft_id"):
			var backdrop := style_selector(OptionButton.new(), 0)
			for title in ["预览底色：浅色", "预览底色：深色", "预览底色：草绿"]: backdrop.add_item(title)
			backdrop.item_selected.connect(func(i): preview_frame.add_theme_stylebox_override("panel", style([Color("f4f6f1"), Color("26352b"), Color("a8c889")][i])))
			card.add_child(backdrop)
			var original_id: String = str(draft.get("repairs_draft_id", ""))
			var original_image := Image.load_from_file(folder.path_join(original_id + ".png")) if original_id.length() == 32 else null
			if original_image != null:
				var original_texture := ImageTexture.create_from_image(original_image)
				var result_texture = picture.texture
				var compare := CheckButton.new()
				compare.text = "对照原稿（关闭后看处理结果）"
				compare.add_theme_font_size_override("font_size", 13)
				for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: compare.add_theme_color_override(state, INK)
				compare.toggled.connect(func(on): picture.texture = original_texture if on else result_texture)
				card.add_child(compare)
			card.add_child(button("放大检查处理结果", func(): OS.shell_open(folder.path_join(str(draft.id) + ".png"))))
		if draft.has("repairs_draft_id") and image != null and image.detect_alpha() != Image.ALPHA_NONE:
			card.add_child(label("已检测到真实透明像素；仍需检查主体是否完整、边缘是否干净。", 14, MUTED, true))
		if image != null and str(draft.get("role", "")) in ["角色", "道具"] and image.detect_alpha() == Image.ALPHA_NONE:
			card.add_child(label("这张图片没有透明像素。如果需要独立角色或道具，请检查底色，调整描述后重新生成。", 14, INK, true))
		card.add_child(label("采用后自动关联到「%s」；若已有图片则替换关联，原图片保留。" % draft.task if draft.has("task") else "采用后保存为素材，游戏不会立即改变。", 14, MUTED, true))
		var id: String = str(draft.id)
		var prompt: String = str(draft.prompt)
		var current_brief := int(draft.get("source_revision", 0)) == int(current.revision)
		var accept := button("采用这张图片", func(): created_action("accept_asset", {"draft_id": id}), true)
		accept.disabled = busy or not current_brief or (draft.get("requires_transparency", false) and image != null and image.detect_alpha() == Image.ALPHA_NONE)
		card.add_child(accept)
		if image != null:
			var cutout_options := HBoxContainer.new()
			var edge := style_selector(OptionButton.new(), 0)
			edge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for title in ["收边：不收缩", "收边：轻微", "收边：适中", "收边：较强", "收边：最强"]: edge.add_item(title)
			edge.disabled = busy
			cutout_options.add_child(edge)
			var cleanup := CheckButton.new()
			cleanup.text = "清理浅色残边"
			cleanup.disabled = busy
			cleanup.add_theme_font_size_override("font_size", 14)
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: cleanup.add_theme_color_override(state, INK)
			var cutout := button("本机去背景", func(): created_action("cutout_asset", {"draft_id": id, "edge_inset": edge.selected * 2, "cleanup_light_edges": cleanup.button_pressed}))
			cutout.disabled = busy or not current_brief
			cutout_options.add_child(cutout)
			card.add_child(cutout_options)
			card.add_child(cleanup)
			card.add_child(label("清理只作用于边缘附近，白色主体或细毛请谨慎开启。", 13, MUTED, true))
			card.add_child(label("不使用GPT额度，另存待确认稿。收边可能减少细节，请切换深浅底色检查。", 13, MUTED, true))
		if image != null and image.detect_alpha() == Image.ALPHA_NONE:
			var repair := button("生成透明背景修复稿", func(): created_action("repair_asset_transparency", {"draft_id": id}))
			repair.disabled = busy or not current_brief
			card.add_child(repair)
			card.add_child(label("会发起一次新的图片编辑，使用账号额度。原稿保留，修复后需重新预览采用。", 13, MUTED, true))
			if draft.get("requires_transparency", false):
				card.add_child(label("修复未达到透明要求，暂不能采用。", 14, INK, true))
		var retry := button("调整描述 / 重新生成", func():
			pending_asset_generation = {}
			var references: Array = draft.get("style_references", [])
			style_reference_selection[style_reference_key()] = str(references[0].id) if current_brief and not references.is_empty() else ""
			input.text = "生成图片：" + prompt
			if draft.has("task") and current_brief:
				pending_asset_generation = {"task": draft.task, "idea_id": current.id, "revision": current.revision, "prefix": input.text.get_slice("统一画风：", 0)}
			show_idea()
			input.grab_focus()
		)
		retry.disabled = busy
		card.add_child(retry)
		var discard := button("放弃这张", func(): created_action("discard_asset", {"draft_id": id}))
		discard.disabled = busy
		card.add_child(discard)
		if not current_brief:
			card.add_child(label("方案已经更新，请按新方案重新生成。", 14, MUTED, true))

func submit_composer() -> void:
	if busy:
		status.text = "上一步还在进行。可以先写好这条，等这轮结束再发送。"
		return
	if detail_view != "效果":
		# Sending from behind the modal closes it instead of failing silently.
		close_details()
	var message := input.text.strip_edges()
	if message.begins_with("设置动画：") or message.begins_with("设置动画:"):
		created_action("configure_asset_animation_text", {"prompt": message})
		if busy: input.text = ""
		return
	if message in ["打开3D素材预览", "打开 3D 素材预览"]:
		resource_tools.select_tab("素材")
		resource_tools.open_3d_preview()
		return
	if message.begins_with("生成模型：") or message.begins_with("生成模型:"):
		var description := message.substr(5).strip_edges()
		if description.is_empty(): status.text = "先描述要制作的静态道具。"; return
		created_action("generate_model", {"prompt": description})
		if busy: input.text = ""; show_idea()
		return
	if message.begins_with("生成图片：") or message.begins_with("生成图片:"):
		var description := message.substr(5).strip_edges()
		if description.is_empty():
			status.text = "先描述要生成的图片，再点击发送。"
			return
		var request := {"prompt": description}
		var reference_id: String = str(style_reference_selection.get(style_reference_key(), ""))
		if not reference_id.is_empty(): request.style_reference_id = reference_id
		if not pending_asset_generation.is_empty() and message.begins_with(str(pending_asset_generation.prefix)):
			if pending_asset_generation.idea_id != current.get("id", "") or pending_asset_generation.revision != current.get("revision", 0):
				status.text = "方案或项目已变化，请重新选择素材任务。"
				return
			if pending_asset_generation.has("task"): request.task = pending_asset_generation.task
			if pending_asset_generation.has("role"): request.role = pending_asset_generation.role
		created_action("generate_asset", request)
		if busy:
			input.text = ""
			show_idea()
		return
	if not made_game.is_empty() and current.get("status", "") == "confirmed":
		revise_created_game()
	else:
		send_message()

func select_detail(target: String) -> void:
	detail_view = target
	show_build = target == "制作清单"
	var saved_scroll := chat_scroll.scroll_vertical
	show_idea()
	chat_scroll.set_deferred("scroll_vertical", saved_scroll)
	if detail_view != "效果":
		modal_close.grab_focus()

func version_date(version: Dictionary) -> String:
	var value := str(version.get("created_at", ""))
	if value.length() >= 16:
		return value.substr(0, 10) + "  " + value.substr(11, 5)
	return "时间未记录"

func version_source(version: Dictionary) -> String:
	return {
		"build_game": "首次制作",
		"revise_game": "继续修改",
		"restore_created": "从旧版本恢复",
	}.get(str(version.get("source", "")), "游戏更新")

func version_validation_text(version: Dictionary) -> String:
	if version.has("test"):
		return "自动检查：启动正常 · 核心操作有响应 · 重开恢复正常"
	return "自动检查：启动与重开正常 · 旧版本未记录核心操作探针"

func version_short_summary(version: Dictionary) -> String:
	var summary := version_summary(version).replace("\n", " ").strip_edges()
	return summary.left(22) + ("…" if summary.length() > 22 else "")

func make_version_button(index: int, version: Dictionary) -> Button:
	var revision := int(version.get("revision", index + 1))
	var current_version := revision == int(made_game.get("current_revision", 0))
	var title := "第 %d 版%s\n%s" % [revision, "  ·  当前" if current_version else "", version_short_summary(version)]
	var item := button(title, func(): select_version(index))
	item.custom_minimum_size.y = 64
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.tooltip_text = version_summary(version)
	item.disabled = busy
	var selected := game_versions.selected == index
	for pair in [["normal", RAIL_ACTIVE if selected else CARD], ["hover", RAIL_ACTIVE if selected else RAIL_HOVER], ["pressed", RAIL_ACTIVE], ["focus", RAIL_ACTIVE if selected else RAIL_HOVER]]:
		var item_style := style(pair[1])
		if pair[0] == "focus":
			item_style.set_border_width_all(2)
			item_style.border_color = FOCUS_LINE
		item.add_theme_stylebox_override(pair[0], item_style)
	return item

func refresh_version_list() -> void:
	if version_list == null:
		return
	clear_children(version_list)
	var versions: Array = made_game.get("versions", [])
	if versions.is_empty():
		version_list.add_child(label("还没有版本", 14, MUTED))
		return
	for index in range(versions.size() - 1, -1, -1):
		version_list.add_child(make_version_button(index, versions[index]))

func select_version(index: int) -> void:
	if index < 0 or index >= game_versions.item_count:
		return
	game_versions.select(index)
	show_version_details()

func show_version_details() -> void:
	if made_game.is_empty() or game_versions.selected < 0:
		version_heading.text = "还没有版本"
		version_meta.text = ""
		version_summary_text.text = "制作游戏后，这里会记录每一次变化。"
		history_text.text = ""
		restore_game_button.visible = false
		refresh_version_list()
		return
	var version: Dictionary = made_game.versions[game_versions.selected]
	var is_current := int(version.revision) == int(made_game.current_revision)
	version_heading.text = "第 %d 版%s" % [int(version.revision), "  ·  当前使用" if is_current else ""]
	version_meta.text = "%s  ·  %s" % [version_date(version), version_source(version)]
	version_summary_text.text = version_summary(version)
	history_text.text = "%s\n\n这一版已经有\n%s\n\n这一版还没有\n%s" % [version_validation_text(version), bullets(version.get("implemented", [])), bullets(version.get("limitations", []))]
	restore_game_button.visible = not is_current
	restore_game_button.disabled = busy
	restore_game_button.text = "恢复这一版，生成新版本"
	refresh_version_list()

func update_effect() -> void:
	preview.texture = null
	if not made_game.is_empty():
		var path := game_directory_for(current).path_join("revisions/%04d/preview.png" % int(made_game.current_revision))
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				preview.texture = ImageTexture.create_from_image(img)
	preview.visible = preview.texture != null
	preview_empty.visible = preview.texture == null
	refresh_preview.visible = not made_game.is_empty() and preview.texture == null
	preview_note.text = "游戏已经可以试玩\n生成预览后，画面会留在这里" if not made_game.is_empty() else "先聊一个想法\n做好的游戏会展示在这里"

func mascot_mark(size_px: int) -> TextureRect:
	var mark := TextureRect.new()
	mark.texture = load("res://assets/playseed-icon.png")
	mark.custom_minimum_size = Vector2(size_px, size_px)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return mark

func build_home(outer: VBoxContainer) -> void:
	dashboard = Control.new()
	dashboard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(dashboard)
	home_garden = load("res://home_garden.gd").new()
	home_garden.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dashboard.add_child(home_garden)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.anchor_left = 0.08
	margins.anchor_right = 0.92
	dashboard.add_child(margins)
	home_mascot = load("res://home_mascot.gd").new()
	dashboard.add_child(home_mascot)
	var home := VBoxContainer.new()
	home.alignment = BoxContainer.ALIGNMENT_CENTER
	home.add_theme_constant_override("separation", 20)
	margins.add_child(home)
	var small := label("每个游戏，都从一个小想法开始", 15, MUTED)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home.add_child(small)
	var title := label("今天，你想创造什么游戏？", 36, INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home.add_child(title)
	var subtitle := label("说说角色、世界，或一个你想玩的瞬间。剩下的，我们一起想。", 16, MUTED, true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home.add_child(subtitle)
	var space := Control.new()
	space.custom_minimum_size.y = 8
	home.add_child(space)
	var composer := PanelContainer.new()
	var cs := composer_surface()
	cs.set_corner_radius_all(20)
	cs.set_border_width_all(1)
	cs.border_color = LINE
	cs.shadow_color = SHADOW
	cs.shadow_size = 14
	cs.shadow_offset = Vector2(0, 5)
	cs.content_margin_left = 20
	cs.content_margin_right = 20
	cs.content_margin_top = 18
	cs.content_margin_bottom = 16
	composer.add_theme_stylebox_override("panel", cs)
	home.add_child(composer)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	composer.add_child(content)
	home_input = TextEdit.new()
	home_input.custom_minimum_size.y = 140
	home_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	home_input.placeholder_text = "比如：我想做一个小猫在屋顶跑酷的游戏，\n画面像温暖的绘本，还能收集鱼干、发现隐藏路线。"
	for state in ["normal", "read_only"]:
		home_input.add_theme_stylebox_override(state, style(CARD))
	home_input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	home_input.add_theme_color_override("font_color", INK)
	home_input.add_theme_color_override("caret_color", INK)
	home_input.add_theme_color_override("font_placeholder_color", PLACEHOLDER)
	home_input.add_theme_font_size_override("font_size", 18)
	home_input.text_changed.connect(func():
		home_garden.respond_to_idea(home_input.text)
		update_home_hint()
	)
	home_input.focus_entered.connect(func():
		cs.border_color = FOCUS_LINE
		composer.queue_redraw()
	)
	home_input.focus_exited.connect(func():
		cs.border_color = LINE
		composer.queue_redraw()
	)
	content.add_child(home_input)
	var delivery_row := HBoxContainer.new()
	delivery_row.add_theme_constant_override("separation", 10)
	content.add_child(delivery_row)
	var delivery_title := label("做好后，朋友怎么玩到？", 13, MUTED)
	delivery_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	delivery_row.add_child(delivery_title)
	delivery_undecided = delivery_pill(delivery_row, "还没想好", "")
	delivery_native = delivery_pill(delivery_row, "下载到电脑玩", "native")
	delivery_web = delivery_pill(delivery_row, "发链接在网页玩", "web")
	var delivery_space := Control.new()
	delivery_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delivery_row.add_child(delivery_space)
	delivery_note = label("", 13, MUTED)
	delivery_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	delivery_row.add_child(delivery_note)
	delivery_undecided.button_pressed = true
	hint = label("", 13, MUTED, true)
	hint.visible = false
	content.add_child(hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	home_plus = MenuButton.new()
	home_plus.text = ""
	home_plus.icon = nav_icon("plus")
	home_plus.expand_icon = false
	home_plus.alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_plus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_plus.add_theme_constant_override("icon_max_width", 24)
	home_plus.tooltip_text = ""
	round_action(home_plus, 44, false, 15)
	home_plus.custom_minimum_size.x = 44
	home_plus.get_popup().add_item("添加图片素材…", 0)
	home_plus.get_popup().add_item("选择或新建项目文件夹…", 1)
	home_plus.get_popup().id_pressed.connect(func(id):
		if id == 0:
			home_file_dialog.popup_centered_ratio(0.7)
		elif id == 1:
			choose_home_folder()
	)
	actions.add_child(home_plus)
	home_model_picker = style_selector(OptionButton.new(), 138)
	home_model_picker.tooltip_text = "选择本次创作使用的 GPT 模型"
	actions.add_child(home_model_picker)
	home_effort_picker = style_selector(OptionButton.new(), 104)
	for effort in [["强度：低", "low"], ["强度：中", "medium"], ["强度：高", "high"], ["强度：超高", "xhigh"], ["强度：最高", "max"]]:
		home_effort_picker.add_item(effort[0])
		home_effort_picker.set_item_metadata(home_effort_picker.item_count - 1, effort[1])
	home_effort_picker.select(1)
	home_effort_picker.tooltip_text = "选择思考强度；越高通常越慢"
	actions.add_child(home_effort_picker)
	home_model_controls = load("res://model_controls.gd").new()
	actions.add_child(home_model_controls)
	fill_models(home_model_picker)
	home_model_controls.setup(self, home_model_picker, home_effort_picker, true)
	var action_space := Control.new()
	action_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_space)
	home_send = button("开始创作  ↑", begin_from_home, true)
	home_send.custom_minimum_size.y = 44
	home_send.add_theme_font_size_override("font_size", 15)
	home_send.tooltip_text = "开始创作（回车；Shift+回车换行）"
	actions.add_child(home_send)
	wire_enter_send(home_input, begin_from_home)
	home_file_dialog = FileDialog.new()
	home_file_dialog.title = "添加参考图"
	home_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	home_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	home_file_dialog.use_native_dialog = true
	home_file_dialog.ok_button_text = "添加图片"
	home_file_dialog.cancel_button_text = "取消"
	home_file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片文件"])
	home_file_dialog.file_selected.connect(attach_home_file)
	add_child(home_file_dialog)

func navigate(destination: String) -> void:
	close_details()
	route = destination
	workspace_tools.visible = route == "workspace"
	dashboard.visible = route == "home"
	library.visible = route == "library"
	page.visible = route == "workspace"
	route_title.text = {"home": "", "library": "我的项目", "workspace": project_name(current)}.get(route, "Playseed")
	apply_sidebar()
	if route == "workspace":
		input.grab_focus()

func select_idea(index: int) -> void:
	if busy:
		status.text = "这个项目还在生成中。想换项目，先点“停止本次生成”。"
		return
	current = ideas[index] if index >= 0 and index < ideas.size() else {}
	show_build = false
	detail_view = "效果"
	resource_tools.select_tab("游戏")
	composer_mode.select(0)
	picker.select(index + 1)
	input.text = ""
	save_selection()
	show_idea()
	if not made_game.is_empty() and current.get("status", "") == "confirmed":
		composer_mode.select(1)
	update_buttons()
	refresh_projects()
	navigate("workspace")

func begin_from_home() -> void:
	if busy:
		set_home_hint("上一个任务还在进行。可以先写好这句，等这轮结束再开始。")
		return
	if home_input.text.strip_edges().is_empty():
		home_mascot_say("先写一句你的游戏想法，几个字也可以。")
		home_input.grab_focus()
		return
	pending_home_prompt = home_input.text.strip_edges()
	if not home_selected_folder.is_empty():
		launch_home_creation()
		return
	set_home_hint("下一步：选择或新建这个游戏的文件夹")
	choose_home_folder()

func build_project_dialogs() -> void:
	project_context = PopupMenu.new()
	project_context.add_item("置顶", 0)
	project_context.add_item("重命名…", 1)
	project_context.add_separator()
	project_context.add_item("删除项目…", 2)
	project_context.id_pressed.connect(project_context_action)
	add_child(project_context)
	var dialog_design = load("res://project_dialogs.gd")
	rename_dialog = ConfirmationDialog.new()
	rename_dialog.title = "重命名项目"
	rename_dialog.ok_button_text = "保存新名字"
	add_child(rename_dialog)
	var rename_body: VBoxContainer = dialog_design.content(self, rename_dialog, "给想法换个新名字", "名字变了，长出来的世界还在。")
	rename_body.add_child(label("项目名称", 14, INK))
	rename_input = LineEdit.new()
	rename_input.placeholder_text = "输入新项目名称"
	rename_input.custom_minimum_size.y = 46
	for state in ["normal", "read_only", "focus"]:
		var field := style(CARD)
		field.set_border_width_all(1)
		field.border_color = FOCUS_LINE if state == "focus" else LINE
		rename_input.add_theme_stylebox_override(state, field)
	rename_input.add_theme_color_override("font_color", INK)
	rename_input.add_theme_color_override("caret_color", INK)
	rename_body.add_child(rename_input)
	rename_body.add_child(label("项目名称和文件夹会一起重命名。
游戏、素材、对话和全部版本都会保留。", 14, MUTED, true))
	rename_input.text_changed.connect(func(value): rename_dialog.get_ok_button().disabled = value.strip_edges().is_empty())
	for child in rename_body.get_children():
		if child is Label: child.custom_minimum_size.x = 480
	rename_body.size = Vector2(480, 260)
	rename_dialog.confirmed.connect(confirm_project_rename)
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "删除项目"
	delete_dialog.ok_button_text = "永久删除项目和文件夹"
	add_child(delete_dialog)
	var delete_body: VBoxContainer = dialog_design.content(self, delete_dialog, "要和这个小世界告别吗？", "删除前，再确认一下。", true)
	delete_project_label = label("", 17, INK, true)
	delete_project_label.custom_minimum_size.x = 480
	delete_body.add_child(delete_project_label)
	var warning := PanelContainer.new()
	warning.add_theme_stylebox_override("panel", style(Color("f8eee5")))
	delete_body.add_child(warning)
	warning.add_child(label("永久删除后无法恢复
项目记录、对话、游戏、素材、全部版本，
以及整个项目文件夹都会一并删除。", 15, Color("854c38"), true))
	warning.get_child(0).custom_minimum_size.x = 448
	delete_body.add_child(label("将删除的文件夹", 13, MUTED))
	delete_path_label = label("", 13, MUTED, true)
	delete_path_label.custom_minimum_size.x = 480
	delete_path_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	delete_body.add_child(delete_path_label)
	delete_body.size = Vector2(480, 340)
	delete_dialog.confirmed.connect(confirm_project_delete)

func idea_by_id(idea_id: String) -> Dictionary:
	for idea in ideas:
		if str(idea.get("id", "")) == idea_id:
			return idea
	return {}

func project_name(idea: Dictionary) -> String:
	return str(idea.get("project_name", idea.get("title", "新游戏")))

func show_project_context(idea_id: String) -> void:
	if busy:
		status.text = "当前任务结束后再管理项目。"
		return
	var idea := idea_by_id(idea_id)
	if idea.is_empty():
		return
	context_project_id = idea_id
	project_context.set_item_text(0, "取消置顶" if bool(idea.get("pinned", false)) else "置顶")
	project_context.position = Vector2i(get_viewport().get_mouse_position())
	project_context.popup()

func project_context_action(id: int) -> void:
	var idea := idea_by_id(context_project_id)
	if idea.is_empty():
		return
	if id == 0:
		start_job({"action": "pin_project", "idea_id": context_project_id, "revision": int(idea.revision), "pinned": not bool(idea.get("pinned", false))})
	elif id == 1:
		rename_input.text = project_name(idea)
		await get_tree().process_frame
		await get_tree().process_frame
		rename_dialog.min_size = Vector2i.ZERO
		rename_dialog.max_size = Vector2i(540, 355)
		rename_dialog.popup_centered(Vector2i(540, 355))
		rename_input.call_deferred("grab_focus")
		rename_input.call_deferred("select_all")
	elif id == 2:
		var path := str(idea.get("project_directory", ""))
		if path.is_empty():
			path = "旧版共用存储中的该项目文件"
		delete_project_label.text = "项目：" + project_name(idea)
		delete_path_label.text = path
		delete_path_label.tooltip_text = path
		await get_tree().process_frame
		await get_tree().process_frame
		delete_dialog.min_size = Vector2i.ZERO
		delete_dialog.max_size = Vector2i(540, 480)
		delete_dialog.popup_centered(Vector2i(540, 480))
		delete_dialog.get_cancel_button().call_deferred("grab_focus")

func confirm_project_rename() -> void:
	var idea := idea_by_id(context_project_id)
	if idea.is_empty():
		return
	var name := rename_input.text.strip_edges()
	if name.is_empty():
		status.text = "请输入新项目名称。"
		return
	start_job({"action": "rename_project", "idea_id": context_project_id, "revision": int(idea.revision), "name": name})

func confirm_project_delete() -> void:
	var idea := idea_by_id(context_project_id)
	if idea.is_empty():
		return
	start_job({"action": "delete_project", "idea_id": context_project_id, "revision": int(idea.revision)})

func refresh_projects() -> void:
	clear_children(sidebar_projects)
	clear_children(project_list)
	project_list.add_child(label("我的项目", 30))
	project_list.add_child(label("你的想法和方案都在这里。随时回来，接着往下做。", 16, MUTED, true))
	if ideas.is_empty():
		project_list.add_child(button("开始第一个想法 →", func(): navigate("home"); home_input.grab_focus(), true))
	for i in range(ideas.size()):
		var index := i
		var item_text := ("★ " if bool(ideas[i].get("pinned", false)) else "") + project_name(ideas[i])
		var item := nav_button(item_text, "game", func(): expand_sidebar(); select_idea(index))
		item.set_meta("active", ideas[i].id == current.get("id", ""))
		item.set_meta("project_id", ideas[i].id)
		item.clip_text = true
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.custom_minimum_size.x = 156
		var project_active: bool = ideas[i].id == current.get("id", "")
		for pair in [["normal", RAIL_ACTIVE if project_active else RAIL], ["hover", RAIL_ACTIVE if project_active else RAIL_HOVER], ["pressed", RAIL_ACTIVE], ["focus", RAIL_ACTIVE if project_active else RAIL_HOVER]]:
			var item_style := style(pair[1])
			if pair[0] == "focus":
				item_style.set_border_width_all(2)
				item_style.border_color = FOCUS_LINE
			item.add_theme_stylebox_override(pair[0], item_style)
		compact(item)
		item.add_theme_font_size_override("font_size", 15)
		item.tooltip_text = item_text
		item.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				show_project_context(str(item.get_meta("project_id")))
				get_viewport().set_input_as_handled()
		)
		sidebar_projects.add_child(item)
		add_project_row(project_list, i)
	apply_sidebar()

func add_project_row(parent: VBoxContainer, index: int) -> void:
	var idea: Dictionary = ideas[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title := label(("★ " if bool(idea.get("pinned", false)) else "") + project_name(idea), 18)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	var game := read_json(game_directory_for(idea).path_join("game.json"))
	var state := "可试玩 · 第 %d 版" % int(game.current_revision) if not game.is_empty() else "方案已确认 · 尚未制作" if idea.status == "confirmed" else "方案待确认" if idea.ready else "想法完善中"
	text.add_child(label(state + "   ·   " + str(idea.get("updated_at", "")).substr(0, 10), 13, MUTED))
	row.add_child(button("继续创作 →", func(): select_idea(index)))

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var result = JSON.parse_string(FileAccess.get_file_as_string(path))
	return result if result is Dictionary else {}

func load_ideas(preferred: String = "") -> void:
	if preferred.is_empty():
		preferred = str(read_json(data_dir.path_join("creator-ui.json")).get("idea_id", ""))
	ideas.clear()
	picker.clear()
	picker.add_item("选择或开始一个新想法")
	var base := data_dir.path_join("ideas")
	DirAccess.make_dir_recursive_absolute(base)
	for id in DirAccess.get_directories_at(base):
		var idea := read_json(base.path_join(id).path_join("idea.json"))
		if not idea.is_empty():
			ideas.append(idea)
	ideas.sort_custom(func(a, b):
		var a_pinned := bool(a.get("pinned", false))
		var b_pinned := bool(b.get("pinned", false))
		if a_pinned != b_pinned:
			return a_pinned
		return str(a.updated_at) > str(b.updated_at)
	)
	var selected := 0
	for i in range(ideas.size()):
		picker.add_item(project_name(ideas[i]))
		if ideas[i].id == preferred:
			selected = i + 1
	picker.select(selected)
	current = ideas[selected - 1] if selected > 0 else {}
	save_selection()
	show_idea()
	if not made_game.is_empty() and current.get("status", "") == "confirmed":
		composer_mode.select(1)
	refresh_projects()

func load_dimension_choices() -> void:
	dimension_choices = {}
	var saved = read_json(data_dir.path_join("creation-modes.json"))
	for id in saved:
		var value = saved[id]
		if (value is int or value is float) and float(value) in [0.0,1.0]:
			dimension_choices[str(id)] = int(value)

func select_dimension(index: int) -> void:
	if busy or current.is_empty() or not made_game.is_empty() or index not in [0,1]: return
	var id = str(current.id)
	var previous = int(dimension_choices.get(id,0))
	dimension_choices[id] = index
	var target = data_dir.path_join("creation-modes.json")
	var file = FileAccess.open(target+".tmp",FileAccess.WRITE)
	var error = ERR_CANT_OPEN
	if file != null:
		file.store_string(JSON.stringify(dimension_choices))
		error = file.get_error()
		file.close()
		if error == OK: error = DirAccess.rename_absolute(target+".tmp",target)
	if error != OK:
		dimension_choices[id] = previous
		dimension_picker.select(previous)
		status.text = "制作方式未能保存，已保留原选择。请检查保存位置后重试。"

func save_selection() -> void:
	var target := data_dir.path_join("creator-ui.json")
	var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"idea_id": current.get("id", ""), "sidebar_collapsed": sidebar_collapsed}))
		file.close()
		DirAccess.rename_absolute(target + ".tmp", target)

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func version_summary(version: Dictionary) -> String:
	if int(version.get("repair_count", 0)) > 0 and version.get("source", "") == "build_game":
		return "第一版已通过检查，制作中发现的问题已自动修复。"
	return str(version.get("summary", ""))

func bullets(items: Array) -> String:
	var lines := PackedStringArray()
	for item in items:
		lines.append("• " + str(item))
	return "\n".join(lines) if not lines.is_empty() else "暂时没有"

func message_card(is_user: bool) -> VBoxContainer:
	var row = HBoxContainer.new()
	chat.add_child(row)
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 26
	if is_user: row.add_child(spacer)
	var bubble = panel(row)
	bubble.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.get_parent().add_theme_stylebox_override("panel",style(Color("e0edcf") if is_user else Color("f3f5f1")))
	if not is_user: row.add_child(spacer)
	bubble.add_child(label("我" if is_user else "Playseed",14,Color("48652e") if is_user else MUTED))
	return bubble

func show_idea() -> void:
	made_game = read_json(game_directory_for(current).path_join("game.json")) if not current.is_empty() else {}
	game_versions.clear()
	for version in made_game.get("versions", []):
		game_versions.add_item("第 %d 版" % int(version.revision))
		game_versions.set_item_metadata(game_versions.item_count - 1, int(version.revision))
	if not made_game.is_empty():
		game_versions.select(game_versions.item_count - 1)
	refresh_version_list()
	clear_children(chat)
	clear_children(choices)
	if current.is_empty():
		flow_label.text = "第 1 步 · 说出想法"
		chat.add_child(label("你想做一款什么样的游戏？", 24, INK, true))
		chat.add_child(label("可以只说一个角色、一种感觉，或者一个你想玩的场景。\n\n我会帮你理清玩法，先确定一个小而完整的第一版。", 18, MUTED, true))
		plan_text.text = "聊过以后，这里会逐渐清晰：\n\n角色和世界\n玩家想达成的目标\n主要怎么玩\n画面氛围\n第一版先做什么\n以后再丰富什么\n还需要你决定什么"
	else:
		if not made_game.is_empty():
			flow_label.text = "第 5 步 · 试玩并继续修改"
		elif current.get("status", "") == "confirmed" and has_build_plan():
			flow_label.text = "第 4 步 · 开始制作游戏"
		elif current.get("status", "") == "confirmed":
			flow_label.text = "第 3 步 · 准备素材和制作清单"
		elif current.get("ready", false):
			flow_label.text = "第 2 步 · 确认游戏方案"
		else:
			flow_label.text = "第 2 步 · 一起理清想法"
		for message in current.messages:
			var bubble := message_card(message.role == "user")
			bubble.add_child(label(message.text, 17, INK, true))
			for q in message.get("questions", []): bubble.add_child(label(q.question, 17, INK, true))
		if current.get("status", "") == "confirmed" and made_game.is_empty():
			show_asset_preparation()
		for q in current.questions:
			var row := VBoxContainer.new()
			choices.add_child(row)
			row.add_child(label(str(q.question), 14, MUTED, true))
			for choice in q.choices:
				var answer: String = q.question + "\n" + choice
				var question: String = q.question
				var b := button(str(choice), func():
					var parts := input.text.strip_edges().split("\n\n", false)
					var answers := PackedStringArray()
					for part in parts:
						if not part.begins_with(question + "\n"):
							answers.append(part)
					answers.append(answer)
					input.text = "\n\n".join(answers)
					input.grab_focus()
				)
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				compact(b)
				b.tooltip_text = choice
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.add_theme_font_size_override("font_size", 14)
				row.add_child(b)
		var p: Dictionary = current.plan
		var state := "已确认" if current.status == "confirmed" else "待你确认" if current.ready else "一起完善中"
		plan_text.text = "角色和世界\n%s\n\n玩家目标\n%s\n\n主要怎么玩\n%s\n\n画面氛围\n%s\n\n第一版先做\n%s\n\n角色与素材怎么准备\n%s\n\n以后再丰富\n%s\n\n暂定内容（可以改）\n%s" % [p.premise, p.player_goal, bullets(p.core_loop), p.visual_style, bullets(p.first_version), bullets(p.get("asset_plan", [])), bullets(p.later), bullets(p.assumptions)]
		if show_build:
			var build := read_json(data_dir.path_join("ideas/%s/builds/%04d.json" % [current.id, int(current.revision)]))
			plan_text.text = "还没有制作清单。确认方案后，可以在这里生成。"
			if not build.is_empty():
				plan_text.text = "制作清单 · 按方案列出的目标\n\n"
				for task in build.tasks:
					plan_text.text += "• " + str(task.title) + "\n\n"
				plan_text.text += "画面方向\n" + str(p.visual_style) + "\n\n验收目标\n" + str(p.player_goal) + "\n\n以后再丰富\n" + bullets(p.later)
		if not busy and made_game.is_empty() and current.get("ready", false):
			var brief := panel(chat)
			brief.add_child(label("第一版方案 · " + state, 14, MUTED))
			brief.add_child(label(str(p.player_goal), 17, INK, true))
			brief.add_child(label(bullets(p.first_version.slice(0, 3)), 15, MUTED, true))
			brief.add_child(button("查看完整方案 →", func(): select_detail("方案")))
		if current.get("status", "") == "confirmed" and has_build_plan() and made_game.is_empty():
			var build_ready := read_json(data_dir.path_join("ideas/%s/builds/%04d.json" % [current.id, int(current.revision)]))
			var prep_card := panel(chat)
			prep_card.add_child(label("制作清单已整理", 14, MUTED))
			prep_card.add_child(label("玩法、画面和试玩检查已经列入清单。需要具体图片时，请先生成或上传；清单不代表素材已完成。", 16, INK, true))
			var prep_items := PackedStringArray()
			for task in build_ready.get("tasks", []).slice(0, 4):
				prep_items.append("• " + str(task.title))
			prep_card.add_child(label("\n".join(prep_items), 14, MUTED, true))
		if not made_game.is_empty():
			var v: Dictionary = made_game.versions[-1]
			game_label.text = "第 %d 版 · 开场截图，点右上角打开试玩" % int(made_game.current_revision)
			if int(made_game.source_revision) != int(current.revision):
				game_label.text += "\n这份游戏对应旧方案，可按新方案再制作。"
			plan_text.text += "\n\n当前游戏的操作\n" + bullets(v.controls) + "\n\n制作说明\n" + version_summary(v) + "\n\n尚未实现 / 限制\n" + bullets(v.limitations)
			var changes := panel(chat)
			changes.add_child(label("最近的游戏版本", 14, MUTED))
			changes.add_child(label("第 %d 版 · %s" % [int(v.revision), version_summary(v)], 16, INK, true))
		else:
			game_label.text = "确认方案后，可以开始制作。"
		preload("res://model_drafts.gd").render(self)
		show_asset_drafts()
		show_asset_split_reviews()
		if detail_view == "效果":
			call_deferred("scroll_to_latest")
	if not busy and current.has("pending_first_prompt"):
		var resume := panel(chat)
		resume.add_child(label("想法已保存，方案尚未完成。", 14, MUTED, true))
		resume.add_child(button("继续整理方案", func():
			created_action("discuss", {"prompt":str(current.pending_first_prompt)})
			if busy: show_idea()
		))
	if not stopped_request.is_empty() and str(stopped_request.get("idea_id", "")) == str(current.get("id", "")):
		var stopped := panel(chat)
		stopped.add_child(label("你 · 已发送", 14, MUTED))
		stopped.add_child(label(str(stopped_request.get("prompt", "")), 17, INK, true))
		stopped.add_child(label(retry_reason, 14, MUTED, true))
		var retry := button("重试这一步", retry_operation)
		retry.disabled = busy or not retry_is_current()
		stopped.add_child(retry)
		if not retry_is_current(): stopped.add_child(label("方案或游戏版本已变化，请按当前项目重新选择操作。",14,MUTED,true))
	if busy and not pending_prompt.is_empty() and str(current.get("pending_first_prompt", "")) != pending_prompt:
		if current.is_empty():
			clear_children(chat)
		var pending := message_card(true)
		pending.add_child(label(pending_prompt, 17, INK, true))
	update_effect()
	show_version_details()
	update_buttons()

func scroll_to_latest() -> void:
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

func update_buttons() -> void:
	# Lock only conflicting edits; navigation keeps its normal readable appearance.
	for b in [send, home_send]:
		b.disabled = busy
	# Waiting on a job blocks sending, not typing: the next message can be drafted now.
	home_input.editable = true
	picker.disabled = busy
	input.editable = true
	composer_mode.disabled = busy
	model_picker.disabled = busy
	effort_picker.disabled = busy
	home_model_picker.disabled = busy
	home_effort_picker.disabled = busy
	for delivery_pill_button in [delivery_undecided, delivery_native, delivery_web]:
		if delivery_pill_button != null:
			delivery_pill_button.disabled = busy
	if workspace_model_controls: workspace_model_controls.refresh()
	if home_model_controls: home_model_controls.refresh()
	home_plus.disabled = busy
	attachment_button.disabled = busy or current.is_empty()
	account_login_button.disabled = busy
	account_logout_button.disabled = busy
	choices.visible = not busy
	for row in choices.get_children():
		for b in row.get_children():
			if b is BaseButton:
				b.disabled = busy
	var confirmed: bool = current.get("status", "") == "confirmed"
	var ready: bool = current.get("ready", false)
	var has_game := not made_game.is_empty()
	confirm.disabled = busy or current.is_empty() or not ready or confirmed
	confirm.text = "方案已确认" if confirmed else "确认这版方案"
	confirm.visible = ready and not confirmed
	prepare.visible = detail_view == "制作清单" and confirmed and not has_build_plan()
	prepare.disabled = busy
	prepare.text = "生成制作清单"
	build_game_button.disabled = busy or (has_game and int(made_game.source_revision) == int(current.get("revision", 0)))
	build_game_button.visible = confirmed and (not has_game or int(made_game.source_revision) != int(current.get("revision", 0)))
	build_game_button.text = "按新方案制作" if has_game else "开始制作第一版" if has_build_plan() else "准备素材和制作清单"
	dimension_picker.visible = confirmed and not has_game
	dimension_picker.disabled = busy
	dimension_picker.select(int(dimension_choices.get(str(current.get("id", "")), 0)))
	play_game_button.visible = has_game
	play_game_button.disabled = busy
	refresh_preview.disabled = busy
	composer_mode.select(1 if has_game and confirmed else 0)
	input.placeholder_text = "说说试玩后想改哪里…" if has_game else "回答问题，或继续补充你的想法…"
	send.text = "↑"
	game_versions.visible = false
	game_versions.disabled = busy
	if detail_view == "版本":
		show_version_details()
	game_label.visible = has_game
	send.visible = not busy
	cancel.visible = busy
	progress_bar.visible = busy
	effect_box.visible = resource_tools.active == "游戏"
	resource_tools.refresh()
	detail_overlay.visible = detail_view != "效果"
	detail_heading.text = {"方案": "游戏方案", "版本": "版本历史", "制作清单": "制作清单", "保存位置": "保存位置", "账号": "GPT 账号"}.get(detail_view, "游戏方案")
	plan_box.visible = detail_view in ["方案", "制作清单"]
	history_box.visible = detail_view == "版本"
	storage_box.visible = detail_view == "保存位置"
	account_box.visible = detail_view == "账号"
	update_storage()
	if detail_view == "账号":
		refresh_gpt_account()
	next_hint.text = ""
	if not busy and ready and not confirmed:
		next_hint.text = "方案已经整理好。你可以继续补充，或确认这版方案。"
	elif not busy and confirmed and not has_game:
		next_hint.text = "先准备素材和制作清单，再开始制作第一版。" if not has_build_plan() else "制作清单已整理，可以开始制作第一版。"
	if busy and made_game.is_empty():
		preview_note.text = "正在把想法变得清楚…\n完成后会告诉你下一步" if pending_action == "discuss" else "正在制作模型草稿…\n完成后请先预览并采用" if pending_action == "generate_model" else "正在处理这一步…\n进度会显示在对话区"
	elif not busy:
		update_effect()
	next_hint.visible = not next_hint.text.is_empty()
	status.visible = not status.text.is_empty()
	if route == "workspace":
		route_title.text = project_name(current)
	update_process()


func send_message() -> void:
	if input.text.strip_edges().is_empty():
		status.text = "说说你的想法，或者回答刚才的问题。"
		return
	var request := {"action": "discuss", "prompt": input.text.strip_edges(), "model": selected_model(), "reasoning_effort": selected_effort()}
	if not current.is_empty():
		request.idea_id = current.id
		request.revision = int(current.revision)
	elif not stopped_request.is_empty():
		for key in ["project_directory", "attachment"]:
			if stopped_request.has(key): request[key] = stopped_request[key]
	start_job(request)
	if busy:
		input.text = ""
		show_idea()
		call_deferred("scroll_to_latest")

func created_action(action: String, extra: Dictionary = {}) -> void:
	if current.is_empty():
		return
	var request := {"action": action, "idea_id": current.id, "revision": int(current.revision), "game_revision": int(made_game.get("current_revision", 0)), "model": selected_model(), "reasoning_effort": selected_effort()}
	if action == "build_game" and made_game.is_empty() and int(dimension_choices.get(str(current.id), 0)) == 1:
		request["format"] = "room3d-v1"
	request.merge(extra)
	start_job(request)

func revise_created_game() -> void:
	if input.text.strip_edges().is_empty():
		status.text = "写下试玩后想改的地方，再点击修改游戏。"
		return
	created_action("revise_game", {"prompt": input.text.strip_edges()})
	if busy:
		input.text = ""
		show_idea()
		call_deferred("scroll_to_latest")

func restore_created_game() -> void:
	if game_versions.selected < 0:
		return
	var selected := int(game_versions.get_item_metadata(game_versions.selected))
	if selected == int(made_game.get("current_revision", 0)):
		status.text = "当前已经是这一版。"
		return
	created_action("restore_created", {"restore_revision": selected})

func confirm_plan() -> void:
	build_after_confirm = false
	start_job({"action": "confirm_brief", "idea_id": current.id, "revision": int(current.revision)})

func prepare_build() -> void:
	if busy:
		return
	if has_build_plan():
		show_build = true
		detail_view = "制作清单"
		show_idea()
		return
	start_job({"action": "prepare_build", "idea_id": current.id, "revision": int(current.revision)})

func has_build_plan() -> bool:
	return not current.is_empty() and current.get("status", "") == "confirmed" and FileAccess.file_exists(data_dir.path_join("ideas/%s/builds/%04d.json" % [current.id, int(current.revision)]))

func start_job(request: Dictionary) -> void:
	if busy:
		return
	if str(request.get("action", "")) in ["discuss", "build_game", "revise_game", "generate_asset", "generate_model", "repair_asset_transparency", "prepare_asset_split"] and not gpt_logged_in:
		status.text = "请先登录自己的 GPT 账号，再继续这一步。"
		select_detail("账号")
		return
	active_job = data_dir.path_join("jobs/%d-%d" % [Time.get_unix_time_from_system(), randi()])
	DirAccess.make_dir_recursive_absolute(active_job)
	var file := FileAccess.open(active_job.path_join("request.json"), FileAccess.WRITE)
	if not file:
		status.text = "无法保存这次请求。请检查文件夹权限。"
		return
	file.store_string(JSON.stringify(request))
	file.close()
	var python := OS.get_environment("PLAYSEED_PYTHON") if OS.has_environment("PLAYSEED_PYTHON") else "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3"
	pid = OS.create_process(python, PackedStringArray([root_dir.path_join("backend.py"), "--request", active_job.path_join("request.json")]))
	if pid < 0:
		status.text = "本地服务未启动，请检查 Python。"
		return
	pending_action = str(request.action)
	pending_prompt = str(request.get("prompt", ""))
	busy = true
	stop_requested = false
	started = Time.get_ticks_msec()
	process_open = false
	status.text = "Playseed 正在思考…" if pending_action == "discuss" else "正在处理这一步…"
	update_buttons()

func remember_retry(reason: String) -> void:
	stopped_request = {}
	retry_reason = reason
	var request = read_json(active_job.path_join("request.json"))
	if request.get("action", "") in ["discuss", "prepare_build", "build_game", "revise_game", "restore_created", "generate_asset", "generate_model"]:
		stopped_request = request
	if current.has("pending_first_prompt"): stopped_request = {}

func retry_is_current() -> bool:
	if stopped_request.is_empty() or str(stopped_request.get("idea_id", "")) != str(current.get("id", "")): return false
	if current.is_empty(): return stopped_request.get("action", "") == "discuss" and not str(stopped_request.get("project_directory", "")).is_empty()
	if int(stopped_request.get("revision", -1)) != int(current.get("revision", 0)): return false
	if stopped_request.has("game_revision") and int(stopped_request.game_revision) != int(made_game.get("current_revision", 0)): return false
	return true

func retry_operation() -> void:
	if busy: return
	if not retry_is_current(): status.text = "方案或游戏版本已变化，请按当前项目重新选择操作。"; return
	var request = stopped_request.duplicate(true)
	request.model = selected_model()
	request.reasoning_effort = selected_effort()
	start_job(request)
	if busy: show_idea()

func poll_job() -> void:
	if not busy:
		return
	var saved_project := read_json(active_job.path_join("project-created.json"))
	if current.is_empty() and saved_project.has("idea"):
		load_ideas(saved_project.idea.id)
		home_selected_folder = ""
		home_attachment = {}
		update_home_hint()
	var state := read_json(active_job.path_join("status.json"))
	if not state.is_empty():
		status.text = str(state.message) + " · %d 秒" % ((Time.get_ticks_msec() - started) / 1000)
		update_process()
		update_storage()
		if state.state in ["done", "error", "cancelled"]:
			busy = false
			if state.state == "done":
				stopped_request = {}
				var result := read_json(active_job.path_join("result.json"))
				var completed_home_creation := pending_action == "discuss" and current.is_empty() and result.has("idea")
				resource_tools.cached_key = ""
				if result.get("project_deleted", false):
					current = {}
					input.text = ""
					home_input.text = ""
					load_ideas()
					status.text = str(result.get("summary", "项目已删除。"))
					navigate("home")
					update_buttons()
					return
				if result.get("storage_changed", false):
					refresh_projects()
					update_effect()
				if result.has("idea"):
					show_build = result.has("build_plan")
					if show_build:
						detail_view = "效果"
					elif result.has("game"):
						detail_view = "效果"
						composer_mode.select(1)
					load_ideas(result.idea.id)
					if completed_home_creation:
						home_selected_folder = ""
						home_attachment = {}
						update_home_hint()
					if build_after_confirm and pending_action == "confirm_brief":
						build_after_confirm = false
						created_action("build_game")
						return
			elif state.state == "cancelled":
				remember_retry("已停止本轮操作，已有方案和游戏保留。")
				status.text = "已停止本轮生成。消息已发送，已有方案和游戏保留。"
				show_idea()
				call_deferred("scroll_to_latest")
			else:
				remember_retry(str(state.message))
				show_idea()
			if state.state == "error" and not pending_prompt.is_empty():
				if current.is_empty() and pending_action == "discuss":
					home_input.text = pending_prompt
					set_home_hint(str(state.message))
					navigate("home")
				else:
					if input.text.strip_edges().is_empty(): input.text = pending_prompt
			build_after_confirm = false
			update_buttons()
			return
	if not OS.is_process_running(pid) and Time.get_ticks_msec() - started > 1800:
		busy = false
		build_after_confirm = false
		remember_retry("本地任务意外结束，已有方案和游戏保留。")
		show_idea()
		if not pending_prompt.is_empty() and input.text.strip_edges().is_empty():
			input.text = pending_prompt
		status.text = "这次没有完成，原对话和方案已保留。可以重试。"
		update_buttons()

func cancel_job() -> void:
	build_after_confirm = false
	if not busy or stop_requested: return
	stop_requested = true
	status.text = "正在停止本轮，已有游戏会保留。"
	var file := FileAccess.open(active_job.path_join("cancel"), FileAccess.WRITE)
	if file:
		file.store_string("cancel")
	else:
		stop_requested = false
		status.text = "停止请求未能写入，请重试。"
