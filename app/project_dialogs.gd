extends RefCounted

static func content(host: Control, dialog: ConfirmationDialog, heading: String, subtitle: String, danger := false) -> VBoxContainer:
	dialog.size = Vector2i(540, 440)
	dialog.borderless = true
	dialog.exclusive = true
	dialog.cancel_button_text = "取消"
	dialog.theme = host.theme.duplicate()
	var surface: StyleBoxFlat = host.composer_surface()
	surface.bg_color = Color("fafbf7")
	surface.content_margin_left = 24
	surface.content_margin_right = 24
	surface.content_margin_top = 24
	surface.content_margin_bottom = 20
	dialog.add_theme_stylebox_override("panel", surface)
	for control in [dialog.get_cancel_button(), dialog.get_ok_button()]:
		control.custom_minimum_size.y = 42
		for state in ["normal", "hover", "pressed", "focus"]:
			var color := Color("eaf0e4")
			if control == dialog.get_ok_button(): color = Color("b34e3e") if danger else Color("cee991")
			if state == "hover": color = color.darkened(0.05)
			if state == "pressed": color = color.darkened(0.10)
			var box: StyleBoxFlat = host.style(color)
			box.set_corner_radius_all(12)
			control.add_theme_stylebox_override(state, box)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			control.add_theme_color_override(state, Color.WHITE if danger and control == dialog.get_ok_button() else host.INK)
	var body := VBoxContainer.new()
	body.custom_minimum_size.x = 480
	body.add_theme_constant_override("separation", 16)
	dialog.add_child(body)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 18)
	body.add_child(hero)
	var mascot := TextureRect.new()
	mascot.texture = load("res://assets/playseed-mascot-farmer-v1.png")
	mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mascot.custom_minimum_size = Vector2(78, 96)
	hero.add_child(mascot)
	var words := VBoxContainer.new()
	words.custom_minimum_size.x = 384
	words.size = Vector2(384, 96)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 8)
	hero.add_child(words)
	words.add_child(host.label(heading, 23, host.INK))
	var caption: Label = host.label(subtitle, 14, host.MUTED, true)
	caption.custom_minimum_size.x = 384
	words.add_child(caption)
	return body
