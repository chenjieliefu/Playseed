extends SceneTree
var game
var held: Dictionary = {}
var events: int = 0
var frames: int = 0
var checkpoints: Array = []
func _initialize():
    call_deferred("run_game")
func key(code: int, down: bool):
    if held.get(code, false) == down:
        return
    held[code] = down
    var event = InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = down
    Input.parse_input_event(event)
    events += 1
func tap(code: int):
    key(code, true)
    key(code, false)
func click(at: Vector2, button: int = MOUSE_BUTTON_LEFT):
    var motion = InputEventMouseMotion.new()
    motion.position = at
    motion.global_position = at
    root.push_input(motion, true)
    for down in [true, false]:
        var event = InputEventMouseButton.new()
        event.position = at
        event.global_position = at
        event.button_index = button
        event.pressed = down
        root.push_input(event, true)
        events += 1
func release_all():
    for code in held.keys():
        key(code, false)
func steer(direction: int):
    if direction > 0:
        key(KEY_A, false)
        key(KEY_D, true)
    elif direction < 0:
        key(KEY_D, false)
        key(KEY_A, true)
    else:
        key(KEY_A, false)
        key(KEY_D, false)
func tick():
    await process_frame
    frames += 1
    if CAPTURE_DIR != "" and frames == 1200:
        await capture("during")
func capture(label: String):
    if CAPTURE_DIR == "":
        return
    # Occluded macOS windows may skip normal draws; force this QA frame.
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png(CAPTURE_DIR + "/" + label + ".png")
func run_game():
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await tick()
    await exercise()
    release_all()
    var end = game.playseed_snapshot().duplicate(true)
    await capture("end")
    tap(KEY_R)
    await tick()
    var reset = game.playseed_snapshot()
    await capture("reset")
    var reset_ok = not reset.won and not reset.lost
    var passed = bool(end.get(EXPECTED, false)) and reset_ok
    print("PLAYTHROUGH_REPORT:" + JSON.stringify({"passed":passed,"end":end,"reset":reset,"input_events":events,"frames":frames,"checkpoints":checkpoints}))
    quit(0 if passed else 1)
