extends HSlider

# Draw discrete levels on the centerline, inside the same track as the thumb.
func marker_positions() -> PackedVector2Array:
	var points := PackedVector2Array()
	var inset := get_theme_icon("grabber").get_width() * 0.5
	for i in range(int(max_value) + 1):
		points.append(Vector2(lerpf(inset, size.x - inset, float(i) / maxf(max_value, 1)), size.y * 0.5))
	return points

func _draw() -> void:
	var points := marker_positions()
	for i in range(points.size()):
		if i == int(value): continue
		draw_circle(points[i], 2.5, Color("dce9c8") if i < value else Color("aeb8ac"), true, -1.0, true)
