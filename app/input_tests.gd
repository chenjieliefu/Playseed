extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func require(condition: bool, message: String) -> void:
	if not condition:
		push_error("INPUT TEST FAILED: " + message)
		quit(1)
		assert(condition, message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run_tests() -> void:
	var studio = load("res://studio.tscn").instantiate()
	root.add_child(studio)
	await process_frame
	await process_frame
	studio.timer.stop()
	var config: Dictionary = load("res://game_preview.gd").DEFAULTS.duplicate()
	studio.current = {"title": "输入回归测试", "current_revision": 1, "config": config, "versions": [{"revision": 1, "summary": "输入回归测试"}]}
	studio._show_current()
	studio.game.set_process(false)
	studio.new_button.grab_focus()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	studio._preview_input(click)
	var before := root.gui_get_focus_owner()
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.physical_keycode = KEY_DOWN
	down.pressed = true
	root.push_input(down)
	await process_frame
	var after := root.gui_get_focus_owner()
	print("Preview click then Down: focus before=", before, ", after=", after)
	if before != after or after != studio.preview_container:
		push_error("INPUT TEST FAILED: arrow keys still navigate workbench buttons after entering preview")
		quit(1)
		return
	print("INPUT TEST PASSED: arrows stay in preview")
	var game = studio.game
	game.start_button.pressed.emit()
	game.enemies.clear()
	require(game.accept_input and root.gui_get_focus_owner() == studio.preview_container, "start button transfers keyboard to preview")
	for code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D]:
		var position: Vector2 = game.player
		key(code, true)
		await process_frame
		game._process(0.1)
		key(code, false)
		require(game.player.distance_to(position) > 10, "movement key moves the player: " + str(code))
		require(root.gui_get_focus_owner() == studio.preview_container, "movement key never moves button focus")
	var job_before: String = studio.active_job
	key(KEY_SPACE, true)
	game._process(0.01)
	key(KEY_SPACE, false)
	game._process(0.01)
	require(game.dash_cooldown > 1.5 and studio.active_job == job_before, "space dashes without activating an AI or export button")
	game.dash_cooldown = 0
	key(KEY_ENTER, true)
	game._process(0.01)
	key(KEY_ENTER, false)
	require(game.dash_cooldown == 0, "Enter is not the game's dash key")
	studio.prompt_box.text = "ab"
	studio.prompt_box.grab_focus()
	studio.prompt_box.set_caret_column(2)
	require(not game.accept_input, "typing pauses gameplay immediately, without a polling delay")
	var stopped_at: Vector2 = game.player
	var elapsed: float = game.elapsed
	key(KEY_LEFT, true)
	await process_frame
	game._process(0.1)
	key(KEY_LEFT, false)
	require(studio.prompt_box.get_caret_column() == 1, "arrow still moves the text cursor")
	require(game.player == stopped_at and game.elapsed == elapsed, "editing does not move player or advance game")
	studio.new_button.grab_focus()
	require(not game.accept_input, "workbench buttons also pause gameplay")
	key(KEY_DOWN, true)
	await process_frame
	key(KEY_DOWN, false)
	require(root.gui_get_focus_owner() != studio.new_button, "arrow navigation remains available outside gameplay")
	studio._focus_preview()
	studio.restore_dialog.popup_centered()
	require(not game.accept_input, "confirmation dialog pauses gameplay")
	studio.restore_dialog.hide()
	studio._focus_preview()
	studio.project_picker.get_popup().popup()
	require(not game.accept_input, "open dropdown pauses gameplay")
	studio.project_picker.get_popup().hide()
	studio._focus_preview()
	studio.get_window().focus_exited.emit()
	require(not game.accept_input, "switching to another app pauses gameplay")
	studio.get_window().focus_entered.emit()
	require(game.accept_input, "returning to focused preview resumes gameplay")
	key(KEY_TAB, true)
	await process_frame
	key(KEY_TAB, false)
	require(root.gui_get_focus_owner() != studio.preview_container and not game.accept_input, "Tab exits preview and pauses game")
	print("INPUT REGRESSION PASSED: arrows/WASD, space, Enter, immediate typing pause, cursor editing, buttons, menus, dialogs, app focus, Tab")
	quit(0)
