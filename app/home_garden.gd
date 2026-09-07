extends Control
# Decorative, non-interactive drawing: never captures typing or mouse clicks.
var warmth := 0.0
var target_warmth := 0.0
var drift := Vector2.ZERO
var elapsed := 0.0
var tick := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func respond_to_idea(text: String) -> void:
	target_warmth = clampf(text.strip_edges().length() / 80.0, 0.0, 1.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += delta
	tick += delta
	if tick < 0.033:
		return
	var target := (get_local_mouse_position() - size * 0.5) * 0.012
	target = target.limit_length(6.0)
	drift = drift.lerp(target, 0.08)
	warmth = lerpf(warmth, target_warmth, 0.08)
	tick = 0.0
	queue_redraw()

func star(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		var angle := i * PI / 4.0
		points.append(at + Vector2(cos(angle), sin(angle)) * (radius if i % 2 == 0 else radius * 0.25))
	draw_colored_polygon(points, color)

func leaf(start: Vector2, tip: Vector2, width: float, color: Color) -> void:
	var points := PackedVector2Array()
	var normal := (tip - start).normalized().orthogonal()
	for side in [1.0, -1.0]:
		for i in range(21):
			var t := float(i if side > 0 else 20 - i) / 20.0
			points.append(start.lerp(tip, t) + normal * sin(t * PI) * width * side)
	draw_colored_polygon(points, color)

func sprout(at: Vector2, scale_value: float, color: Color) -> void:
	draw_set_transform(at, -0.15 + sin(elapsed * 0.6) * 0.025, Vector2.ONE * scale_value)
	draw_polyline(PackedVector2Array([Vector2(0, 14), Vector2(0, 0), Vector2(5, -12)]), color, 2.0, true)
	leaf(Vector2(0, 0), Vector2(-19, -19), 6.0, color)
	leaf(Vector2(3, -6), Vector2(20, -27), 6.5, color.lightened(0.12))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.39)
	# Soft sunlight behind the heading; no panels, cards, or extra content.
	for i in range(18, 0, -1):
		draw_circle(center, float(i) * 15.0, Color(0.83, 0.90, 0.64, 0.009 + warmth * 0.002))
	var green := Color("b3c895")
	var gold := Color("dfc785")
	sprout(Vector2(size.x * 0.16, size.y * 0.20) + drift, 1.15 + warmth * 0.15, green)
	star(Vector2(size.x * 0.84, size.y * 0.26) - drift, 15, gold)
	star(Vector2(size.x * 0.80, size.y * 0.20) + drift, 5, green)
	star(Vector2(size.x * 0.13, size.y * 0.74) - drift, 9, gold)
	sprout(Vector2(size.x * 0.86, size.y * 0.79) - drift, 0.65 + warmth * 0.2, green)
	for i in range(12):
		var x := 0.12 + fmod(i * 0.173, 0.76)
		var y := 0.14 + fmod(i * 0.291, 0.71)
		if y > 0.30 and y < 0.72:
			continue
		var point := Vector2(size.x * x, size.y * y + sin(elapsed * 0.7 + i) * 3.0) + drift
		draw_circle(point, 1.8 + warmth, Color(0.61, 0.72, 0.47, 0.36))
