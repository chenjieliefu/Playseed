extends Node2D
var kind := "burst"
var tint := Color("d5ef94")
var age := 0.0
func _process(delta: float) -> void:
	age += delta
	if age >= 0.85:
		queue_free()
	else:
		queue_redraw()
func _draw() -> void:
	var t := age / 0.85
	var color := Color(tint, 1.0 - t)
	if kind == "ring":
		draw_arc(Vector2.ZERO, 5 + t * 48, 0, TAU, 48, color, 3 * (1.0 - t) + 1, true)
	elif kind == "beam":
		draw_line(Vector2(-55, 0), Vector2(55, 0), Color(tint, (1 - t) * 0.18), 16, true)
		draw_line(Vector2(-55, 0), Vector2(55, 0), color, 5 * (1 - t) + 1, true)
		draw_circle(Vector2(55, 0), 5 * (1 - t), Color.WHITE)
	elif kind == "trail":
		for i in range(8):
			var p := Vector2(-i * 8 + t * 35, sin(float(i) * 0.6) * 8)
			draw_circle(p, (7 - i * 0.7) * (1 - t), color)
	else:
		for i in range(12):
			var angle := i * TAU / 12.0
			var p := Vector2(cos(angle), sin(angle)) * (6 + t * 43)
			draw_circle(p, 3 * (1 - t) + 1, color)
