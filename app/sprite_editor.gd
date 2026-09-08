extends ConfirmationDialog

class SheetPreview extends Control:
	var backdrop := Color("26352b")
	var texture: Texture2D
	var frames: SpriteFrames
	var config: Dictionary = {}
	var current_frame := 0
	var playing := true
	var clock := 0.0
	func _process(delta: float) -> void:
		if not is_visible_in_tree() or frames == null or not playing: return
		clock += delta
		var next := int(clock * frames.get_animation_speed("default"))
		var count := frames.get_frame_count("default")
		if frames.get_animation_loop("default"): next %= count
		elif next >= count: next = count - 1; playing = false
		current_frame = next
		queue_redraw()
	func fitted(box: Rect2, dimensions: Vector2) -> Rect2:
		var scale_by := minf(box.size.x / dimensions.x, box.size.y / dimensions.y)
		var target := dimensions * scale_by
		return Rect2(box.position + (box.size - target) / 2, target)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), backdrop)
		var grid_color := Color("52683e") if backdrop.get_luminance() > 0.35 else Color("a8c889")
		if texture == null: return
		var left := fitted(Rect2(12, 12, size.x / 2 - 24, size.y - 24), texture.get_size())
		draw_texture_rect(texture, left, false)
		if frames == null: return
		var columns := int(config.columns)
		var rows := int(config.rows)
		for x in range(columns + 1):
			draw_line(left.position + Vector2(left.size.x * x / columns, 0), left.position + Vector2(left.size.x * x / columns, left.size.y), grid_color, 1)
		for y in range(rows + 1):
			draw_line(left.position + Vector2(0, left.size.y * y / rows), left.position + Vector2(left.size.x, left.size.y * y / rows), grid_color, 1)
		var index := int(config.first_frame) + current_frame
		var cell := left.size / Vector2(columns, rows)
		draw_rect(Rect2(left.position + Vector2(index % columns, index / columns) * cell, cell), Color("36562a") if backdrop.get_luminance() > 0.35 else Color("cee991"), false, 3)
		var part := frames.get_frame_texture("default", current_frame)
		var right := fitted(Rect2(size.x / 2 + 12, 12, size.x / 2 - 24, size.y - 24), part.get_size())
		draw_texture_rect(part, right, false)

var host: Control
var asset: Dictionary
var project_id: String
var revision: int
var preview: SheetPreview
var fields: Dictionary = {}
var align_option: CheckButton
var loop_option: CheckButton
var message: Label
var playback: Button
var config: Dictionary = {}
var builder

func setup(owner_ui: Control, entry: Dictionary) -> void:
	host = owner_ui
	asset = entry.duplicate(true)
	project_id = str(host.current.id)
	revision = int(host.current.revision)
	theme = host.theme.duplicate()
	var sprite_surface := host.composer_surface()
	sprite_surface.bg_color = Color("f8faf6")
	sprite_surface.content_margin_top = 22
	sprite_surface.content_margin_bottom = 18
	theme.set_stylebox("panel", "AcceptDialog", sprite_surface)
	for state in ["normal", "focus", "read_only"]: theme.set_stylebox(state, "LineEdit", host.style(Color("edf1e9")))
	theme.set_color("font_color", "LineEdit", host.INK)
	theme.set_color("font_uneditable_color", "LineEdit", host.MUTED)
	for button in [get_ok_button(), get_cancel_button()]:
		for state in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, host.style(Color("e5eedb")))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: button.add_theme_color_override(state, host.INK)
	title = "切图与帧动画 · " + str(asset.name)
	ok_button_text = "保存动画设置"
	cancel_button_text = "取消"
	exclusive = true
	borderless = true
	transparent = true
	builder = load(host.root_dir.path_join("runtime/playseed_sprite_frames.gd"))
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 640
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(host.label("切图与帧动画 · " + str(asset.name), 23, host.INK))
	box.add_child(host.label("每格一帧，从左到右、再从上到下。请使用尺寸一致、排列整齐的帧图。", 14, host.INK, true))
	preview = SheetPreview.new()
	preview.custom_minimum_size = Vector2(600, 240)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var image := Image.load_from_file(host.game_directory_for(host.current).path_join("library/%s.png" % asset.id))
	if image != null: preview.texture = ImageTexture.create_from_image(image)
	box.add_child(preview)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	var saved: Dictionary = asset.get("animation", {})
	for spec in [["columns", "列数", 1, 16, 2], ["rows", "行数", 1, 16, 1], ["first_frame", "从第几格开始", 1, 256, 1], ["frame_count", "播放几帧", 2, 128, 2], ["fps", "每秒帧数", 1, 30, 8]]:
		grid.add_child(host.label(spec[1], 14, host.INK))
		var spin := SpinBox.new()
		spin.min_value = spec[2]; spin.max_value = spec[3]; spin.step = 1
		spin.value = int(saved.get(spec[0], spec[4])) + (1 if spec[0] == "first_frame" and saved.has("first_frame") else 0)
		spin.custom_minimum_size.x = 110
		fields[spec[0]] = spin
		grid.add_child(spin)
		spin.value_changed.connect(func(_v): rebuild())
	loop_option = CheckButton.new()
	loop_option.text = "循环播放"
	loop_option.button_pressed = bool(saved.get("loop", true))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: loop_option.add_theme_color_override(state, host.INK)
	loop_option.toggled.connect(func(_on): rebuild())
	grid.add_child(loop_option)
	align_option = CheckButton.new()
	align_option.text = "对齐底部"
	align_option.tooltip_text = "仅适合站立或摆动的角色、道具。跳跃、飞行等有意上下移动的动作请保留原位。原图片不变。"
	align_option.button_pressed = bool(saved.get("align_bottom", false))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: align_option.add_theme_color_override(state, host.INK)
	align_option.toggled.connect(func(_on): rebuild())
	grid.add_child(align_option)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	playback = host.compact(host.button("暂停预览", func():
		preview.playing = not preview.playing
		if preview.playing: preview.clock = 0; preview.current_frame = 0
		playback.text = "暂停预览" if preview.playing else "重新播放"
	))
	actions.add_child(playback)
	actions.add_child(host.compact(host.button("上一帧", func(): step_frame(-1))))
	actions.add_child(host.compact(host.button("下一帧", func(): step_frame(1))))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var backgrounds := ButtonGroup.new()
	for option in [["深底", "26352b"], ["浅底", "f5f3ea"], ["绿底", "bed0a6"]]:
		var color := Color(option[1])
		var button: Button = host.compact(host.button(option[0], func():
			preview.backdrop = color
			preview.queue_redraw()
		))
		button.toggle_mode = true
		button.button_group = backgrounds
		button.button_pressed = option[0] == "深底"
		button.tooltip_text = "切换审阅底色，仅用于检查透明边缘，不改变素材和游戏。"
		actions.add_child(button)
	message = host.label("", 14, host.MUTED, true)
	box.add_child(message)
	box.add_child(host.label("左边检查网格，右边查看动作。保存只记录设置，不改原图；用于游戏需发送对话并生成新版本。", 13, host.MUTED, true))
	var chat_button := add_button("改用对话设置", true, "chat")
	var extras: Array[Button] = [chat_button]
	if asset.has("animation"): extras.append(add_button("取消动画设置", true, "clear"))
	for button in extras:
		for state in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, host.style(Color("edf1e9")))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(state, host.INK)
	custom_action.connect(func(action):
		if host.busy or str(host.current.get("id", "")) != project_id or int(host.current.get("revision", 0)) != revision:
			host.status.text = "项目或方案已变化，请重新打开动画设置。"
			queue_free(); return
		if action == "clear": host.created_action("clear_asset_animation", {"asset_id":str(asset.id)})
		else:
			host.resource_tools.propose("设置动画：「%s」，%d列，%d行，从%d格开始，%d帧，每秒%d帧，%s，%s" % [asset.name,config.columns,config.rows,config.first_frame+1,config.frame_count,config.fps,"循环" if config.loop else "不循环", "底部对齐" if config.align_bottom else "保留原位"])
		queue_free()
	)
	confirmed.connect(save)
	close_requested.connect(queue_free)
	canceled.connect(queue_free)
	for child in box.get_children():
		if child is Label: child.custom_minimum_size.x = 640
	rebuild()
	box.size = Vector2(640, 550)
	await get_tree().process_frame
	await get_tree().process_frame
	popup_centered(Vector2i(700, 650))

func rebuild() -> void:
	if loop_option == null or align_option == null: return
	config = {"loop": loop_option.button_pressed, "align_bottom": align_option.button_pressed}
	for key in fields: config[key] = int(fields[key].value) - (1 if key == "first_frame" else 0)
	preview.frames = builder.build(preview.texture, config)
	preview.config = config.duplicate()
	preview.current_frame = 0; preview.clock = 0
	preview.queue_redraw()
	get_ok_button().disabled = preview.frames == null
	if preview.frames == null:
		message.text = "当前行列不能均分图片，或起始格与帧数超出了网格。请调整后再保存。"
	else:
		message.text = "原始单格 %d × %d 像素 · 共 %d 帧 · 每秒 %d 帧" % [preview.texture.get_width() / config.columns, preview.texture.get_height() / config.rows, config.frame_count, config.fps]

func step_frame(direction: int) -> void:
	if preview.frames == null: return
	preview.playing = false
	playback.text = "重新播放"
	preview.current_frame = posmod(preview.current_frame + direction, preview.frames.get_frame_count("default"))
	preview.queue_redraw()

func save() -> void:
	if host.busy or str(host.current.get("id", "")) != project_id or int(host.current.get("revision", 0)) != revision:
		host.status.text = "项目或方案已变化，请重新打开动画设置。"
		queue_free(); return
	host.created_action("configure_asset_animation", {"asset_id": str(asset.id), "animation": config})
	queue_free()
