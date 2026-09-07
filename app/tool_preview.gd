extends SubViewportContainer
var kind := "animate_pop"
var stage: Node2D
var clock := 3.0
var body: Sprite2D
func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 126)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	stage = load("res://playseed_base.gd").new()
	viewport.add_child(stage)
func _process(delta: float) -> void:
	if not is_visible_in_tree() or stage == null:
		return
	clock += delta
	if clock < (1.1 if kind.begins_with("effect_") else 2.4):
		return
	clock = 0.0
	if is_instance_valid(body):
		body.queue_free()
	body = Sprite2D.new()
	body.texture = load("res://assets/playseed-icon.png")
	body.scale = Vector2.ONE * 0.10
	body.position = Vector2(get_child(0).size) * 0.5
	stage.add_child(body)
	if kind.begins_with("effect_"):
		body.visible = false
		stage.call(kind, body.position)
	else:
		stage.call(kind, body)
