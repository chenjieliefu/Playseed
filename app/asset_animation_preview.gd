extends Control
var frames: SpriteFrames
var elapsed := 0.0
func _process(delta: float) -> void:
	if not is_visible_in_tree() or frames == null: return
	elapsed += delta
	queue_redraw()
func _draw() -> void:
	if frames == null: return
	var count := frames.get_frame_count("default")
	var frame := int(elapsed * frames.get_animation_speed("default"))
	frame = frame % count if frames.get_animation_loop("default") else mini(frame, count - 1)
	var texture := frames.get_frame_texture("default", frame)
	var scale_by := minf((size.x - 12) / texture.get_width(), (size.y - 12) / texture.get_height())
	var dimensions := texture.get_size() * scale_by
	draw_texture_rect(texture, Rect2((size - dimensions) / 2, dimensions), false)
