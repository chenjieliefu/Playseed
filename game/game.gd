extends Node2D

signal finished(won: bool)

const ARENA := Rect2(36, 92, 888, 472)
const DEFAULTS := {
	"title": "小芽的森林试炼", "description": "躲开小怪物，守住这一分钟。",
	"player_speed": 250.0, "enemy_speed": 80.0, "enemy_count": 5,
	"duration": 60.0, "theme": "meadow", "player_color": "#c9ef84",
	"enemy_color": "#ed9984", "dash_enabled": true, "shield_count": 1,
	"collectible_count": 0, "initial_lives": 1, "max_lives": 1, "heart_count": 0
}
var config: Dictionary = DEFAULTS.duplicate()
var player := Vector2(480, 330)
var enemies: Array[Vector2] = []
var seeds: Array[Vector2] = []
var hearts: Array[Vector2] = []
var lives := 1
var particles: Array[Dictionary] = []
var elapsed := 0.0
var dash_cooldown := 0.0
var dash_time := 0.0
var invincible := 0.0
var shields := 0
var collected := 0
var playing := false
var ended := false
var won := false
var accept_input := true
var dash_key_was_down := false
var title_label: Label
var hud_label: Label
var life_label: Label
var overlay: PanelContainer
var overlay_title: Label
var overlay_note: Label
var start_button: Button
var status_label: Label
var backdrop := Color("182e29")
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	if FileAccess.file_exists("res://game.json"):
		var loaded = JSON.parse_string(FileAccess.get_file_as_string("res://game.json"))
		if loaded is Dictionary:
			configure(loaded)
	_make_ui()
	reset_game(false)

func configure(values: Dictionary) -> void:
	config = DEFAULTS.duplicate()
	config.merge(values, true)
	backdrop = {"meadow": Color("182e29"), "night": Color("202a43"), "desert": Color("433629")}.get(config.theme, Color("182e29"))
	if is_instance_valid(title_label):
		reset_game(false)

func _label(text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _make_ui() -> void:
	title_label = _label(config.title, Vector2(36, 19), 26, Color("f4f7e9"))
	title_label.size.x = 540
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud_label = _label("", Vector2(600, 27), 18, Color("d7e7c9"))
	life_label = _label("", Vector2(36, 60), 18, Color("f4b6c6"))
	status_label = _label("WASD / 方向键移动     空格冲刺     R 重开", Vector2(36, 568), 15, Color("a5baaa"))
	overlay = PanelContainer.new()
	overlay.position = Vector2(210, 190)
	overlay.size = Vector2(540, 236)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f3f4e9")
	style.set_corner_radius_all(22)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	overlay.add_theme_stylebox_override("panel", style)
	add_child(overlay)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	overlay.add_child(box)
	overlay_title = Label.new()
	overlay_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 28)
	overlay_title.add_theme_color_override("font_color", Color("22382d"))
	box.add_child(overlay_title)
	overlay_note = Label.new()
	overlay_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_note.add_theme_font_size_override("font_size", 17)
	overlay_note.add_theme_color_override("font_color", Color("556255"))
	overlay_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_note.custom_minimum_size.x = 470
	box.add_child(overlay_note)
	start_button = Button.new()
	start_button.text = "开始冒险"
	start_button.custom_minimum_size.y = 48
	start_button.add_theme_font_size_override("font_size", 19)
	start_button.add_theme_color_override("font_color", Color("203426"))
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("c6eb80")
	button_style.set_corner_radius_all(14)
	start_button.add_theme_stylebox_override("normal", button_style)
	button_style = button_style.duplicate()
	button_style.bg_color = Color("b9df70")
	start_button.add_theme_stylebox_override("hover", button_style)
	start_button.add_theme_stylebox_override("pressed", button_style)
	start_button.pressed.connect(func(): reset_game(true); start_button.release_focus())
	box.add_child(start_button)

func reset_game(start: bool = true) -> void:
	player = ARENA.get_center()
	elapsed = 0.0
	dash_cooldown = 0.0
	dash_time = 0.0
	invincible = 0.0
	shields = int(config.shield_count)
	lives = int(config.initial_lives)
	collected = 0
	enemies.clear()
	seeds.clear()
	hearts.clear()
	particles.clear()
	for i in range(int(config.enemy_count)):
		var angle := TAU * i / maxf(float(config.enemy_count), 1.0)
		enemies.append(player + Vector2(cos(angle) * 380, sin(angle) * 195))
	for i in range(int(config.collectible_count)):
		seeds.append(Vector2(rng.randf_range(70, 890), rng.randf_range(125, 530)))
	# Spread hearts across cells so they do not stack or spawn on the player.
	var cells: Array[Vector2] = []
	for y in range(4):
		for x in range(6):
			var spot := Vector2(100 + x * 150, 145 + y * 120)
			if spot.distance_to(player) > 90:
				cells.append(spot)
	for i in range(mini(int(config.heart_count), cells.size())):
		var index := rng.randi_range(0, cells.size() - 1)
		hearts.append(cells[index] + Vector2(rng.randf_range(-15, 15), rng.randf_range(-12, 12)))
		cells.remove_at(index)
	playing = start
	ended = false
	won = false
	if is_instance_valid(overlay):
		overlay.visible = not start
		overlay_title.text = config.title
		var objective := "%d 秒内收集全部 %d 颗光点，同时躲避怪物。" % [int(config.duration), int(config.collectible_count)] if int(config.collectible_count) > 0 else "躲开怪物，坚持 %d 秒获胜。" % int(config.duration)
		overlay_note.text = objective + "\n" + "护盾 %d 个 · %s" % [int(config.shield_count), "空格可以冲刺" if bool(config.dash_enabled) else "冲刺已关闭"]
		if int(config.max_lives) > 1 or int(config.heart_count) > 0:
			overlay_note.text += "\n初始 %d 命，上限 %d 命；粉色爱心恢复 1 命。" % [lives, int(config.max_lives)]
		start_button.text = "开始冒险"
		title_label.text = config.title
	queue_redraw()

func move_player(direction: Vector2, delta: float) -> void:
	var speed := float(config.player_speed) * (3.2 if dash_time > 0 else 1.0)
	player += direction.limit_length() * speed * delta
	player.x = clampf(player.x, ARENA.position.x + 18, ARENA.end.x - 18)
	player.y = clampf(player.y, ARENA.position.y + 18, ARENA.end.y - 18)

func finish_game(success: bool) -> void:
	playing = false
	ended = true
	won = success
	overlay.visible = true
	overlay_title.text = "小芽，做到了！" if success else "再试一次，你可以的"
	overlay_note.text = "存活 %.1f 秒 · 收集 %d 颗光点\n回工作台说一句话，就能调整难度。" % [elapsed, collected]
	start_button.text = "再玩一次"
	finished.emit(success)

func _process(delta: float) -> void:
	var dash_key_down := Input.is_physical_key_pressed(KEY_SPACE)
	if accept_input and dash_key_down and not dash_key_was_down and playing and bool(config.dash_enabled) and dash_cooldown <= 0:
		dash_time = 0.18
		dash_cooldown = 2.0
	dash_key_was_down = dash_key_down
	if accept_input and Input.is_physical_key_pressed(KEY_R) and ended:
		reset_game(true)
	if playing and accept_input:
		var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		step(delta, direction)
	if is_instance_valid(hud_label):
		life_label.text = "生命 %d / %d  " % [lives, int(config.max_lives)] + "♥".repeat(lives) + "♡".repeat(maxi(0, int(config.max_lives) - lives))
		hud_label.text = "%02d 秒  ·  护盾 %d" % [int(ceil(maxf(0.0, float(config.duration) - elapsed))), shields]
		if int(config.collectible_count) > 0:
			hud_label.text += "  ·  %d/%d" % [collected, int(config.collectible_count)]
		status_label.text = "WASD / 方向键移动     " + ("空格冲刺（%.1fs）" % dash_cooldown if dash_cooldown > 0 else "空格冲刺" if bool(config.dash_enabled) else "冲刺已关闭") + "     R 重开"
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		particles[i].pos += particles[i].vel * delta
		if particles[i].life <= 0:
			particles.remove_at(i)
	queue_redraw()

func step(delta: float, direction: Vector2) -> void:
	if not playing:
		return
	elapsed += delta
	dash_time = maxf(0.0, dash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invincible = maxf(0.0, invincible - delta)
	move_player(direction, delta)
	for i in range(enemies.size()):
		var towards := (player - enemies[i]).normalized()
		enemies[i] += towards * float(config.enemy_speed) * delta
		if player.distance_to(enemies[i]) < 29 and invincible <= 0 and dash_time <= 0:
			if shields > 0:
				shields -= 1
				_burst(player, Color("d8f2a4"))
			else:
				lives -= 1
				_burst(player, Color("f28fa8"))
				if lives <= 0:
					finish_game(false)
					return
			invincible = 1.5
			enemies[i] -= towards * 100
	for i in range(hearts.size() - 1, -1, -1):
		if lives < int(config.max_lives) and player.distance_to(hearts[i]) < 30:
			lives = mini(lives + 1, int(config.max_lives))
			_burst(hearts[i], Color("f28fa8"))
			hearts.remove_at(i)
	for i in range(seeds.size() - 1, -1, -1):
		if player.distance_to(seeds[i]) < 27:
			_burst(seeds[i], Color("efce7c"))
			seeds.remove_at(i)
			collected += 1
	if int(config.collectible_count) > 0 and seeds.is_empty():
		finish_game(true)
	elif elapsed >= float(config.duration):
		finish_game(int(config.collectible_count) == 0)

func _burst(at: Vector2, color: Color) -> void:
	for i in range(12):
		particles.append({"pos": at, "vel": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30, 150), "life": 0.5, "color": color})

func _draw_heart(at: Vector2) -> void:
	var outline := PackedVector2Array()
	for i in range(48):
		var angle := TAU * i / 48.0
		var x := 16 * pow(sin(angle), 3)
		var y := -(13 * cos(angle) - 5 * cos(2 * angle) - 2 * cos(3 * angle) - cos(4 * angle))
		outline.append(at + Vector2(x, y) * 0.85)
	draw_circle(at, 23, Color(0.96, 0.48, 0.62, 0.12))
	draw_colored_polygon(outline, Color("f28fa8"))
	draw_circle(at + Vector2(-6, -5), 2.5, Color("ffdae4"))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 600), backdrop)
	for x in range(36, 925, 32):
		for y in range(92, 565, 32):
			draw_circle(Vector2(x, y), 1.0, Color(1, 1, 1, 0.07))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(1, 1, 1, 0.025)
	panel.border_color = Color(1, 1, 1, 0.12)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(18)
	draw_style_box(panel, ARENA)
	for heart in hearts:
		_draw_heart(heart)
	for seed in seeds:
		draw_circle(seed, 13, Color(1.0, 0.85, 0.4, 0.1))
		draw_circle(seed, 6 + sin(elapsed * 4 + seed.x) * 1.4, Color("edcb77"))
	for enemy in enemies:
		draw_circle(enemy + Vector2(0, 6), 17, Color(0, 0, 0, 0.2))
		draw_circle(enemy, 15, Color(config.enemy_color))
		var gaze := (player - enemy).normalized() * 2
		draw_circle(enemy + Vector2(-5, -3) + gaze, 2.3, Color("322d31"))
		draw_circle(enemy + Vector2(5, -3) + gaze, 2.3, Color("322d31"))
		draw_line(enemy + Vector2(-5, -9), enemy + Vector2(-2, -7), Color("322d31"), 2)
		draw_line(enemy + Vector2(5, -9), enemy + Vector2(2, -7), Color("322d31"), 2)
	if invincible <= 0 or fmod(elapsed, 0.16) < 0.10:
		draw_circle(player + Vector2(0, 7), 20, Color(0, 0, 0, 0.25))
		if shields > 0:
			draw_arc(player, 26, 0, TAU, 48, Color(0.8, 0.94, 0.65, 0.4), 2, true)
		draw_circle(player, 18, Color(config.player_color))
		draw_circle(player + Vector2(-5, -1), 2.4, Color("203c30"))
		draw_circle(player + Vector2(5, -1), 2.4, Color("203c30"))
		draw_arc(player + Vector2(0, 3), 4, 0.1, PI - 0.1, 16, Color("203c30"), 1.5, true)
		draw_line(player + Vector2(0, -16), player + Vector2(0, -26), Color("8aaa5b"), 2)
		draw_colored_polygon(PackedVector2Array([player + Vector2(0, -21), player + Vector2(-11, -29), player + Vector2(-2, -31)]), Color("9fcf68"))
		draw_colored_polygon(PackedVector2Array([player + Vector2(0, -23), player + Vector2(10, -31), player + Vector2(12, -25)]), Color("b1da72"))
	for part in particles:
		var color: Color = part.color
		color.a = clampf(part.life * 2, 0, 1)
		draw_circle(part.pos, 3, color)
