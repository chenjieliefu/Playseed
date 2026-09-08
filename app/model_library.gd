extends AcceptDialog

var host: Control
var project_id := ""
var revision := 0
var folder := ""
var selected_file := ""
var selected_model := ""
var picker: FileDialog
var filename: Label
var name_input: LineEdit
var purpose: LineEdit
var source: LineEdit
var license_picker: OptionButton
var save_button: Button
var message: Label
var listing: VBoxContainer
var last_key := ""
var age := 0.0

func setup(owner_ui: Control) -> void:
	host = owner_ui
	project_id = str(host.current.id)
	revision = int(host.current.revision)
	folder = host.game_directory_for(host.current).path_join("model-library")
	theme = host.theme.duplicate()
	var model_surface: StyleBoxFlat = host.composer_surface()
	model_surface.bg_color = Color("fbfaf4")
	# The borderless viewport clips outer shadows into square corner patches.
	model_surface.shadow_size = 0
	model_surface.content_margin_top = 22
	model_surface.content_margin_bottom = 18
	theme.set_stylebox("panel", "AcceptDialog", model_surface)
	for state in ["normal", "focus"]: theme.set_stylebox(state, "LineEdit", host.style(Color("edf1e9")))
	theme.set_color("font_color", "LineEdit", host.INK)
	theme.set_color("font_placeholder_color", "LineEdit", host.MUTED)
	exclusive = true
	borderless = true
	transparent = true
	title = "模型素材与来源"
	ok_button_text = "关闭"
	min_size = Vector2i(620, 600)
	for state in ["normal", "hover", "pressed", "focus"]: get_ok_button().add_theme_stylebox_override(state, host.style(Color("e5eedb")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: get_ok_button().add_theme_color_override(state, host.INK)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	close_requested.connect(queue_free)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	add_child(box)
	box.add_child(host.label("模型素材与来源", 23, host.INK))
	box.add_child(host.label("导入或制作模型，补齐资料后添加到对话，用于替换 3D 障碍外观。", 14, host.MUTED, true))
	box.add_child(host.compact(host.button("描述道具，用 Blender 制作…",start_generation)))
	box.add_child(host.label("静态基础色GLB可用作3D障碍外观。模型等比放入外盒，碰撞按整块盒形计算，镂空暂不能穿过。",14,host.MUTED,true))
	box.add_child(host.compact(host.button("选择新 GLB…",func(): picker.popup_centered_ratio(.7))))
	filename = host.label("单个20 MB以内 · 贴图、透明、骨骼与动画尚未接通",13,host.MUTED,true)
	box.add_child(filename)
	name_input = field(box,"名称，例如：温室花盆",48)
	purpose = field(box,"用途，例如：替换中央花台的外观",300)
	source = field(box,"来源：作者、网址或自己的制作说明",1000)
	license_picker = OptionButton.new()
	for text in ["选择授权依据","自有原创","CC0","已获授权","其他（见来源说明）"]: license_picker.add_item(text)
	box.add_child(license_picker)
	save_button = host.compact(host.button("导入模型",submit,true))
	box.add_child(save_button)
	message = host.label("先预览、补资料，再添加到对话制作新版本。平台不自动核验授权。",13,host.MUTED,true)
	box.add_child(message)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 130
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	listing = VBoxContainer.new()
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(listing)
	picker = FileDialog.new()
	picker.title = "选择静态GLB模型"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.glb ; GLB模型"])
	picker.file_selected.connect(select_file)
	add_child(picker)
	refresh()
	popup_centered(Vector2i(660,680))
	call_deferred("fit_layout")

func fit_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	popup_centered(Vector2i(660,680))

func field(box: VBoxContainer, hint: String, cap: int) -> LineEdit:
	var item = LineEdit.new()
	item.placeholder_text = hint
	item.max_length = cap
	box.add_child(item)
	return item

func valid_context() -> bool:
	return host.current.get("id","") == project_id and int(host.current.get("revision",0)) == revision

func select_file(path: String) -> void:
	selected_model = ""
	selected_file = path
	name_input.text = path.get_file().get_basename()
	purpose.text = ""
	source.text = ""
	license_picker.select(0)
	filename.text = path.get_file()
	save_button.text = "导入模型"

func submit() -> void:
	if not valid_context() or host.busy:
		message.text = "项目已变化或上一步还在进行，请回到当前项目再操作。"
		return
	if name_input.text.strip_edges().is_empty() or purpose.text.strip_edges().is_empty() or source.text.strip_edges().is_empty() or license_picker.selected == 0:
		message.text = "请补齐名称、用途、来源和授权依据。"
		return
	var request = {"name":name_input.text.strip_edges(),"purpose":purpose.text.strip_edges(),"source":source.text.strip_edges(),"license":license_picker.get_item_text(license_picker.selected)}
	if selected_model.is_empty():
		if selected_file.is_empty(): message.text = "先选择GLB文件。"; return
		var file = FileAccess.open(selected_file,FileAccess.READ)
		if file == null or file.get_length() > 20*1024*1024:
			message.text = "模型不可读取或超过20 MB。"
			return
		request.glb_base64 = Marshalls.raw_to_base64(file.get_buffer(file.get_length()))
		file.close()
		host.created_action("import_model",request)
	else:
		request.model_id = selected_model
		host.created_action("update_model_metadata",request)
	message.text = "正在保存模型资料…"

func edit(item: Dictionary) -> void:
	selected_model = item.id
	selected_file = ""
	filename.text = "编辑已入库模型 · " + item.id.left(8)
	name_input.text = item.name
	purpose.text = item.get("purpose","")
	source.text = item.get("source","")
	license_picker.select(0)
	for i in range(license_picker.item_count):
		if license_picker.get_item_text(i) == item.get("license",""): license_picker.select(i)
	save_button.text = "保存资料"

func propose(item: Dictionary) -> void:
	if not valid_context() or host.busy: message.text = "请等本轮结束并回到当前项目。"; return
	if item.get("purpose","").is_empty() or item.get("source","").is_empty() or item.get("license","").is_empty():
		message.text = "先编辑并补齐模型用途、来源和授权依据。"
		return
	if not host.input.text.strip_edges().is_empty():
		message.text = "输入框已有草稿，请先处理草稿，再添加模型。"
		return
	host.resource_tools.propose("请在3D游戏中使用模型「%s」（编号%s）作为障碍外观。用途：%s。保留已有玩法，按外盒碰撞；先说明要替换哪个障碍。" % [item.name,item.id,item.purpose])
	queue_free()

func preview(item: Dictionary) -> void:
	if not valid_context(): message.text = "请先回到打开此窗口时的项目。"; return
	host.resource_tools.open_3d_preview(item.id)

func refresh() -> void:
	for child in listing.get_children(): child.queue_free()
	var saved = host.read_json(folder.path_join("library.json"))
	var items: Dictionary = {}
	for item in saved.get("models",[]): items[item.id] = item
	if DirAccess.dir_exists_absolute(folder):
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".glb") and not items.has(file.get_basename()):
				items[file.get_basename()] = {"id":file.get_basename(),"name":"道具-"+file.left(8)}
	for item in items.values():
		var card: VBoxContainer = host.panel(listing)
		card.add_child(host.label(item.name,17,host.INK,true))
		card.add_child(host.label(item.get("purpose","用途待补充"),13,host.MUTED,true))
		card.add_child(host.label("来源："+item.get("source","待补充"),12,host.MUTED,true))
		card.add_child(host.label("授权依据："+item.get("license","待补充"),12,host.MUTED,true))
		var row = HBoxContainer.new()
		card.add_child(row)
		row.add_child(host.compact(host.button("重新预览 ↗",func(): preview(item))))
		row.add_child(host.compact(host.button("编辑资料",func(): edit(item))))
		row.add_child(host.compact(host.button("添加到对话",func(): propose(item))))
	if items.is_empty(): listing.add_child(host.label("尚未导入模型。",15,host.MUTED))

func _process(delta: float) -> void:
	age += delta
	if age < .4 or host == null: return
	age = 0
	var content = FileAccess.get_file_as_string(folder.path_join("library.json")) if FileAccess.file_exists(folder.path_join("library.json")) else ""
	if content != last_key:
		last_key = content
		refresh()
	if not host.busy and message.text == "正在保存模型资料…": message.text = host.status.text

func start_generation() -> void:
	if not valid_context() or host.busy: message.text = "请等本轮结束并回到当前项目。"; return
	preload("res://model_drafts.gd").prepare(host)
	queue_free()
