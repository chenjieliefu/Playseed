extends VBoxContainer

const CATALOG := {
	"动画": [
		["弹出登场", "出场", "animate_pop", "角色或道具出现时，先缩小再弹出。", "在角色或重要道具登场时加入自然的弹出动画，保留原玩法。"],
		["轻轻悬浮", "循环", "animate_float", "让可收集物轻轻上下浮动。", "让可收集的道具轻轻上下悬浮，方便识别；不要影响碰撞。"],
		["呼吸缩放", "循环", "animate_pulse", "用缓慢缩放提示可以交互的物体。", "给重要的可交互物体加入轻微呼吸缩放，保持碰撞范围不变。"],
		["挤压回弹", "反馈", "animate_squash", "落地或点击后短暂变形，再回弹。", "为落地或交互动作加入挤压回弹反馈，不改变角色移动规则。"],
		["旋转一圈", "反馈", "animate_spin", "获得奖励时转一圈庆祝。", "在获得奖励时给对应物体加入一次旋转庆祝动画。"],
		["柔和淡入", "出场", "animate_fade", "让新出现的物体渐渐显现。", "让新出现的场景物体柔和淡入，保留原来的颜色和玩法。"]
	],
	"特效": [
		["星点迸发", "命中", "effect_burst", "命中或拾取位置散开一圈亮点。", "在命中或拾取位置触发星点迸发，颜色与当前美术风格协调。"],
		["扩散光环", "反馈", "effect_ring", "升级、交互成功时向外扩散。", "成功交互或升级时，在对应位置加入短暂扩散光环。"],
		["发光拖尾", "移动", "effect_trail", "为冲刺、飞行或弹道添加轨迹。", "为冲刺或移动中的弹体添加节制的发光拖尾，不遮挡场景。"],
		["能量光束", "命中", "effect_beam", "一闪而过的水平光束效果。", "在合适的攻击或机关事件中加入短暂能量光束；如不适合当前玩法，请先解释。"]
	],
	"扩展": [
		["生命与回血", "规则", "health", "受伤扣血、拾取回血，显示生命上限。", "加入生命值、受伤保护和回血道具，满血时不能继续增加，并显示清楚的生命界面。"],
		["暂停与继续", "界面", "pause", "暂停时冻结玩法，保留继续和重开。", "加入暂停菜单：暂停冻结角色、敌人和计时，能继续和重新开始。"],
		["金币与奖励", "规则", "coins", "收集奖励，记录数量并给出反馈。", "加入可收集金币和清楚的计数、拾取反馈，重开时重置本局金币。"],
		["关卡与波次", "关卡", "waves", "从简单到困难，完成后进入下一轮。", "在适合当前玩法的前提下加入三段递进关卡或波次，展示进度和最终胜利。"],
		["昼夜氛围", "场景", "daynight", "用色彩和亮度变化营造时间流逝。", "加入缓慢循环的昼夜氛围，用背景色和光感变化表现，保证物体始终清晰可见。"],
		["角色对话", "界面", "dialogue", "靠近角色后互动，逐句显示对话。", "加入适合当前世界观的角色和简单对话框，靠近互动后逐句阅读，关闭后继续游戏。"]
	]
}
var host: Control
var active := "游戏"
var tabs: HBoxContainer
var search: LineEdit
var category: OptionButton
var content: VBoxContainer
var code_box: VBoxContainer
var code: CodeEdit
var files: OptionButton
var notice: Label
var import_dialog: FileDialog
var export_dialog: FileDialog
var import_button: Button
var asset_role: OptionButton
var copy_button: Button
var export_button: Button
var cached_key := ""
var audio_button: Button

func setup(owner_ui: Control, toolbar: HBoxContainer) -> void:
	host = owner_ui
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	toolbar.add_child(tabs)
	toolbar.move_child(tabs, 0)
	var icons := ["game", "materials", "animation", "effects", "addons", "code"]
	var names := ["游戏", "素材", "动画", "特效", "扩展", "代码"]
	for i in range(names.size()):
		var target: String = names[i]
		var tab: Button = host.compact(host.button("", func(): select_tab(target)))
		tab.icon = host.nav_icon(icons[i])
		tab.tooltip_text = target
		tab.set_meta("target", target)
		tab.add_theme_constant_override("h_separation", 7)
		tabs.add_child(tab)
	var filters := HBoxContainer.new()
	add_child(filters)
	search = LineEdit.new()
	search.placeholder_text = "搜索名称或用途…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.x = 80
	search.add_theme_color_override("font_color", host.INK)
	search.add_theme_color_override("font_placeholder_color", host.MUTED)
	search.add_theme_stylebox_override("normal", host.style(Color("f4f6f1")))
	search.text_changed.connect(func(_text): render_catalog())
	filters.add_child(search)
	category = OptionButton.new()
	category.item_selected.connect(func(_i): render_catalog())
	filters.add_child(category)
	notice = host.label("", 13, host.MUTED, true)
	add_child(notice)
	var import_row := HBoxContainer.new()
	add_child(import_row)
	asset_role = OptionButton.new()
	for role in ["角色", "场景", "道具", "界面", "参考图"]: asset_role.add_item(role)
	import_row.add_child(asset_role)
	import_button = host.compact(host.button("导入图片…", func(): import_dialog.popup_centered_ratio(0.7), true))
	import_row.add_child(import_button)
	var preview_3d: Button = host.compact(host.button("3D 素材预览 ↗", open_3d_preview))
	import_row.add_child(preview_3d)
	import_row.add_child(host.compact(host.button("刷新素材", render_catalog)))
	var audio_row := HBoxContainer.new()
	add_child(audio_row)
	audio_button = host.compact(host.button("声音素材与音量…", open_audio_library))
	audio_row.add_child(audio_button)
	set_meta("audio_row", audio_row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	code_box = VBoxContainer.new()
	code_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(code_box)
	var code_actions := HBoxContainer.new()
	code_box.add_child(code_actions)
	files = OptionButton.new()
	files.fit_to_longest_item = false
	files.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	files.item_selected.connect(func(_i): load_code())
	code_actions.add_child(files)
	copy_button = host.compact(host.button("复制", func(): DisplayServer.clipboard_set(code.text); notice.text = "已复制当前文件。"))
	code_actions.add_child(copy_button)
	export_button = host.compact(host.button("导出工程", func():
		export_dialog.current_file = "Playseed-v%d.zip" % int(host.made_game.get("current_revision", 0))
		export_dialog.popup_centered_ratio(0.7)
	))
	code_actions.add_child(export_button)
	code = CodeEdit.new()
	code.editable = false
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.gutters_draw_line_numbers = true
	code.add_theme_font_size_override("font_size", 13)
	code.add_theme_color_override("font_readonly_color", Color("dcebd9"))
	code.add_theme_stylebox_override("read_only", host.style(Color("20332d")))
	code_box.add_child(code)
	import_dialog = FileDialog.new()
	import_dialog.title = "为当前项目导入图片"
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.use_native_dialog = true
	import_dialog.ok_button_text = "导入图片"
	import_dialog.cancel_button_text = "取消"
	import_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片"])
	import_dialog.file_selected.connect(import_image)
	add_child(import_dialog)
	export_dialog = FileDialog.new()
	export_dialog.title = "导出当前版本源工程"
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.use_native_dialog = true
	export_dialog.ok_button_text = "导出工程"
	export_dialog.cancel_button_text = "取消"
	export_dialog.filters = PackedStringArray(["*.zip ; ZIP 工程"])
	export_dialog.file_selected.connect(func(path): host.created_action("export_created", {"export_path": path}))
	add_child(export_dialog)
	set_meta("filters", filters)
	set_meta("import_row", import_row)
	set_meta("scroll", scroll)
	select_tab("游戏")

func select_tab(target: String) -> void:
	active = target
	search.text = ""
	category.clear()
	category.add_item("全部分类")
	if active == "素材":
		for value in ["角色", "场景", "道具", "界面"]: category.add_item(value)
	else:
		if active == "动画": category.add_item("帧动画")
		var seen: Array = []
		for entry in CATALOG.get(active, []):
			if entry[1] not in seen:
				seen.append(entry[1]); category.add_item(entry[1])
	cached_key = ""
	refresh()
	host.effect_box.visible = active == "游戏"

func refresh() -> void:
	visible = active != "游戏"
	for tab in tabs.get_children():
		var selected: bool = tab.get_meta("target") == active
		tab.text = active if selected else ""
		tab.add_theme_stylebox_override("normal", host.style(Color("e5eedb") if selected else Color("f4f6f2")))
	get_meta("filters").visible = active not in ["游戏", "代码"]
	get_meta("import_row").visible = active == "素材"
	get_meta("audio_row").visible = active == "素材"
	audio_button.disabled = host.current.is_empty()
	get_meta("scroll").visible = active != "代码"
	code_box.visible = active == "代码"
	import_button.disabled = host.busy or host.current.is_empty()
	export_button.disabled = host.busy or host.made_game.is_empty()
	copy_button.disabled = host.made_game.is_empty()
	var key: String = str(host.current.get("id", "")) + ":" + str(host.made_game.get("current_revision", 0)) + ":" + str(host.busy) + ":" + active
	if key == cached_key: return
	cached_key = key
	if active == "代码": render_code()
	elif active != "游戏": render_catalog()

func revision_path() -> String:
	return host.game_directory_for(host.current).path_join("revisions/%04d" % int(host.made_game.get("current_revision", 0)))

func render_code() -> void:
	files.clear()
	code.text = ""
	if host.made_game.is_empty():
		code.text = "第一版游戏制作完成后，代码会显示在这里。"
		notice.text = "当前还没有已完成的游戏版本。"
		return
	for name in ["game.gd", "main.tscn", "project.godot", "world.json", "spatial_world.gd", "spatial_player.gd", "playseed_base.gd", "playseed_feedback.gd", "playseed_sprite_frames.gd"]:
		if FileAccess.file_exists(revision_path().path_join(name)): files.add_item(name)
	notice.text = "第 %d 版 · 只读代码。修改请在左侧描述，检查通过后会保存新版本。" % int(host.made_game.current_revision)
	load_code()

func load_code() -> void:
	if files.selected < 0: return
	code.text = FileAccess.get_file_as_string(revision_path().path_join(files.get_item_text(files.selected)))

func import_image(path: String, role_override: String = "", task: String = "") -> bool:
	if host.busy or host.current.is_empty(): return false
	if FileAccess.get_file_as_bytes(path).size() > 8 * 1024 * 1024:
		notice.text = "请选择 8 MB 以内的图片。"; return false
	var image := Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_width() > 4096 or image.get_height() > 4096:
		notice.text = "图片无法读取，或宽高超过 4096 像素。"; return false
	var bytes := image.save_png_to_buffer()
	var role := role_override if not role_override.is_empty() else asset_role.get_item_text(asset_role.selected)
	var request := {"name": path.get_file().get_basename(), "role": role, "png_base64": Marshalls.raw_to_base64(bytes)}
	if not task.is_empty(): request.task = task
	host.created_action("import_asset", request)
	return true

func propose(text: String) -> void:
	if host.busy or host.current.is_empty(): return
	host.input.text = text
	host.composer_mode.select(1 if not host.made_game.is_empty() and host.current.get("status", "") == "confirmed" else 0)
	host.update_buttons()
	host.input.grab_focus()
	notice.text = "已放入对话框。你可以补充用法，发送后再加入游戏。"

func edit_sprite(entry: Dictionary) -> void:
	if host.busy or host.current.is_empty(): return
	var editor = load("res://sprite_editor.gd").new()
	host.add_child(editor)
	editor.setup(host, entry)

func render_catalog() -> void:
	if active == "代码" or active == "游戏": return
	host.clear_children(content)
	var needle := search.text.strip_edges().to_lower()
	var selected := category.get_item_text(category.selected) if category.selected >= 0 else "全部分类"
	var entries: Array = []
	if active == "素材":
		var manifest: Dictionary = host.read_json(host.game_directory_for(host.current).path_join("library/library.json"))
		entries = manifest.get("assets", [])
		render_models()
		notice.text = "%d 张图片 · 发送消息时，AI 会查看你提到的图片及最近导入的图片，每轮最多六张。导入不会立即改变游戏。" % entries.size()
	else:
		entries = CATALOG.get(active, []).duplicate()
		if active == "动画":
			var manifest: Dictionary = host.read_json(host.game_directory_for(host.current).path_join("library/library.json"))
			for asset in manifest.get("assets", []):
				if asset.has("animation"): entries.push_front(asset)
		notice.text = "2D " + active + " · 选择后发送给 AI，生成新版本再试玩验收。" + ("下方为实际效果预览。" if active != "扩展" else "会结合当前玩法整合。")
	var count := 0
	var row: HBoxContainer
	for entry in entries:
		var is_asset := entry is Dictionary
		var name: String = entry.name if is_asset else entry[0]
		var group: String = ("帧动画" if active == "动画" else entry.role) if is_asset else entry[1]
		var desc: String = ("%d 帧 · 每秒 %d 帧" % [entry.animation.frame_count, entry.animation.fps] if active == "动画" else "%s · %d × %d" % [group, entry.width, entry.height]) if is_asset else entry[3]
		if (not needle.is_empty() and not (name + desc).to_lower().contains(needle)) or (selected != "全部分类" and selected != group): continue
		if count % 2 == 0:
			row = HBoxContainer.new(); row.add_theme_constant_override("separation", 12); content.add_child(row)
		var card: VBoxContainer = host.panel(row)
		card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var canvas := PanelContainer.new()
		canvas.custom_minimum_size.y = 126
		canvas.add_theme_stylebox_override("panel", host.style(Color("24382f") if active != "素材" else Color("f1f4ed")))
		card.add_child(canvas)
		var prompt: String
		if is_asset:
			var picture := TextureRect.new()
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var image := Image.load_from_file(host.game_directory_for(host.current).path_join("library/%s.png" % entry.id))
			if image != null and not image.is_empty():
				var ratio := minf(1.0, 512.0 / maxf(image.get_width(), image.get_height()))
				if ratio < 1.0 and active != "动画": image.resize(maxi(1, int(image.get_width() * ratio)), maxi(1, int(image.get_height() * ratio)))
				picture.texture = ImageTexture.create_from_image(image)
			if active == "动画" and image != null:
				var demo = load("res://asset_animation_preview.gd").new()
				demo.frames = load(host.root_dir.path_join("runtime/playseed_sprite_frames.gd")).build(ImageTexture.create_from_image(image), entry.animation)
				canvas.add_child(demo)
				picture.free()
			else:
				canvas.add_child(picture)
			prompt = "把项目素材「%s」（编号 %s）用作游戏中的%s，保持画面比例并适配原来的美术和玩法。" % [name, entry.id, group]
			if entry.has("animation"):
				prompt += " 使用已配置的帧动画，动作停止和重开时恢复第一帧；不要把整张帧图当作一个角色。"
		elif active == "扩展":
			var badge: Label = host.label(name, 21, Color("d3e6b8"), true)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			canvas.add_child(badge)
			prompt = entry[4]
		else:
			var demo = load("res://tool_preview.gd").new()
			demo.kind = entry[2]
			canvas.add_child(demo)
			prompt = entry[4]
		card.add_child(host.label(name, 16, host.INK, true))
		card.add_child(host.label(desc, 13, host.MUTED, true))
		var action: Button = host.compact(host.button("添加到对话", func(): propose(prompt)))
		action.disabled = host.busy or host.current.is_empty()
		card.add_child(action)
		if is_asset:
			var configure: Button = host.compact(host.button("切图与帧动画", func(): edit_sprite(entry)))
			configure.disabled = host.busy or host.current.get("status", "") != "confirmed"
			card.add_child(configure)
		count += 1
	if count == 0:
		content.add_child(host.label("还没有匹配的内容。" if not needle.is_empty() else "先为这个项目导入一张图片吧。" if active == "素材" else "这个分类暂时没有内容。", 16, host.MUTED, true))

func open_3d_preview(model_id: String = "") -> void:
	var python: String = OS.get_environment("PLAYSEED_PYTHON") if OS.has_environment("PLAYSEED_PYTHON") else "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3"
	var args = PackedStringArray([host.root_dir.path_join("scripts/preview_3d.py"), "--project", host.game_directory_for(host.current), "--idea", str(host.current.get("id", ""))])
	if not model_id.is_empty(): args.append_array(["--model",model_id])
	var process := OS.create_process(python,args)
	notice.text = "已请求打开3D模型预览。补齐资料并添加到对话，制作新版本后才会入场。" if process > 0 else "预览未能启动，请检查本机运行环境。"

func render_models() -> void:
	content.add_child(host.compact(host.button("模型素材与来源…",open_model_library)))
	var folder: String = host.game_directory_for(host.current).path_join("model-library")
	if not DirAccess.dir_exists_absolute(folder): return
	for filename in DirAccess.get_files_at(folder):
		if not filename.ends_with(".glb"): continue
		var card: VBoxContainer = host.panel(content)
		card.add_child(host.label("3D 道具 · " + filename.left(8), 16, host.INK))
		card.add_child(host.label("已保存在模型库 · 通过模型素材入口补资料、预览和使用", 13, host.MUTED))
		card.add_child(host.compact(host.button("在文件夹中查看", func(): OS.shell_open(folder))))

func open_audio_library() -> void:
	if host.current.is_empty(): return
	var editor = load("res://audio_library.gd").new()
	host.add_child(editor)
	editor.setup(host)

func open_model_library() -> void:
	if host.current.is_empty(): return
	var editor = load("res://model_library.gd").new()
	host.add_child(editor)
	editor.setup(host)
