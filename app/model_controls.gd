extends Button

var host: Control
var model: OptionButton
var effort: OptionButton
var on_home := false
var popup: PopupPanel
var slider: HSlider
var heading: Label
var model_switch: OptionButton
const LEVELS := ["低", "中", "高", "超高", "最高"]

func setup(owner_ui: Control, model_state: OptionButton, effort_state: OptionButton, home: bool) -> void:
	host = owner_ui; model = model_state; effort = effort_state; on_home = home
	model.hide(); effort.hide()
	custom_minimum_size = Vector2(190, 38)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", 13)
	for state in host.button_states(false):
		var box: StyleBoxFlat = host.style(host.CARD if state == "normal" else host.NEUTRAL)
		box.content_margin_top = 6; box.content_margin_bottom = 6
		add_theme_stylebox_override(state, box)
		add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), host.INK)
	popup = PopupPanel.new()
	popup.add_theme_stylebox_override("panel", host.composer_surface())
	add_child(popup)
	popup.size_changed.connect(func():
		if popup.visible: position_panel.call_deferred()
	)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	popup.add_child(column)
	column.add_child(host.label("选择模型", 13, host.MUTED))
	model_switch = host.style_selector(OptionButton.new(), 256)
	for i in range(model.item_count): model_switch.add_item(model.get_item_text(i))
	model_switch.item_selected.connect(func(index):
		model.select(index)
		host.sync_model_efforts(model, effort)
		refresh()
	)
	column.add_child(model_switch)
	var level_row := HBoxContainer.new()
	column.add_child(level_row)
	var title: Label = host.label("思考强度", 13, host.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(title)
	heading = host.label("中", 14, host.ACCENT_INK)
	level_row.add_child(heading)
	slider = load("res://effort_slider.gd").new()
	slider.min_value = 0; slider.max_value = 4; slider.step = 1
	slider.tick_count = 0
	slider.custom_minimum_size = Vector2(256, 32)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("e8e9e7"); track.set_corner_radius_all(12)
	track.content_margin_top = 10; track.content_margin_bottom = 10
	slider.add_theme_stylebox_override("slider", track)
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = Color("97ba65")
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(icon, host.nav_icon("slider-thumb"))
	slider.tooltip_text = "拖动选择思考强度；也可使用方向键调整"
	slider.value_changed.connect(func(value): effort.select(int(value)); refresh())
	column.add_child(slider)
	pressed.connect(open_panel)
	refresh()

func refresh() -> void:
	disabled = model.disabled
	text = model.get_item_text(model.selected) + " · " + LEVELS[effort.selected] + "  ▾"
	if heading:
		heading.text = LEVELS[effort.selected]
		model_switch.select(model.selected)
		slider.set_block_signals(true)
		slider.max_value = effort.item_count - 1
		slider.set_value_no_signal(effort.selected)
		slider.set_block_signals(false)
		slider.queue_redraw()
	if disabled and popup: popup.hide()

func cycle_model() -> void:
	model.select((model.selected + 1) % model.item_count)
	host.sync_model_efforts(model, effort)
	refresh()

func reset_defaults() -> void:
	for i in range(model.item_count):
		if model.get_item_metadata(i) == "gpt-5.6-sol": model.select(i)
	host.sync_model_efforts(model, effort); effort.select(1); refresh()

func open_panel() -> void:
	host.sync_model_efforts(model, effort)
	refresh()
	if disabled: return
	popup.size = Vector2i(292, 148)
	popup.popup()
	position_panel.call_deferred()

func position_panel() -> void:
	var anchor := get_global_rect()
	var bounds := get_viewport_rect()
	if not popup.is_embedded():
		anchor = get_viewport().get_screen_transform() * anchor
		bounds = Rect2(DisplayServer.screen_get_usable_rect())
	var below := anchor.end.y + 10
	var y := below if on_home and below + popup.size.y <= bounds.end.y - 12 else anchor.position.y - popup.size.y - 10
	popup.position = Vector2i(clampf(anchor.position.x, bounds.position.x + 12, bounds.end.x - popup.size.x - 12), clampf(y, bounds.position.y + 12, bounds.end.y - popup.size.y - 12))
