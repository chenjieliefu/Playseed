extends Control
# Home-page mascot speech bubble. Appears inside the empty idea input to
# nudge gently, instead of a bare hint line. Purely decorative: it never
# captures typing or clicks, and fades away by itself.
const INK := Color("263c31")
const LINE := Color("dce4d6")
const CARD := Color("ffffff")
const TAIL := Color("f0f5ea")
const SHOW_SECONDS := 4.6

var message := ""
var icon: Texture2D
var _age := 999.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon = load("res://assets/playseed-mascot-farmer-v1.png")

func say(text_value: String, input_rect: Rect2) -> void:
	message = text_value
	var bubble_w: float = maxf(150.0, text_value.length() * 14.0 + 44.0)
	size = Vector2(64.0 + bubble_w, 72.0)
	position = Vector2(input_rect.end.x - size.x - 12.0, input_rect.end.y - size.y - 10.0)
	_age = 0.0
	visible = true
	modulate.a = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	var alpha: float = 1.0
	if _age < 0.25:
		alpha = _age / 0.25
	elif _age > SHOW_SECONDS - 0.45:
		alpha = maxf(0.0, (SHOW_SECONDS - _age) / 0.45)
	modulate.a = alpha
	if _age >= SHOW_SECONDS:
		visible = false
	queue_redraw()

func _draw() -> void:
	var bob := sin(minf(_age, 1.2) * 6.0) * 2.0 if _age < 1.2 else 0.0
	var icon_size := 56.0
	var gap := 6.0
	var bubble_x := icon_size + gap
	var bubble_h := 52.0
	var bubble_y := (size.y - bubble_h) / 2.0 + bob
	var bubble_w := size.x - bubble_x
	# Speech bubble card.
	var body := StyleBoxFlat.new()
	body.bg_color = CARD
	body.set_corner_radius_all(16)
	body.set_border_width_all(1)
	body.border_color = LINE
	body.content_margin_left = 16
	body.content_margin_right = 16
	body.shadow_color = Color(0.12, 0.22, 0.14, 0.06)
	body.shadow_size = 6
	body.shadow_offset = Vector2(0, 3)
	draw_style_box(body, Rect2(bubble_x, bubble_y, bubble_w, bubble_h))
	# Small tail pointing to the mascot on the left.
	var tail_top := Vector2(bubble_x + 2.0, bubble_y + bubble_h * 0.42)
	var tail_tip := Vector2(bubble_x - gap * 0.6, bubble_y + bubble_h * 0.5)
	var tail_bottom := Vector2(bubble_x + 2.0, bubble_y + bubble_h * 0.58)
	draw_colored_polygon(PackedVector2Array([tail_top, tail_tip, tail_bottom]), TAIL)
	draw_line(tail_top, tail_tip, LINE, 1.0)
	draw_line(tail_bottom, tail_tip, LINE, 1.0)
	# Mascot portrait, softly framed.
	draw_circle(Vector2(icon_size / 2.0, size.y / 2.0 + bob), icon_size / 2.0 + 3.0, Color("e6edd9"))
	if icon != null:
		draw_texture_rect(icon, Rect2(2.0, size.y / 2.0 - icon_size / 2.0 + bob, icon_size, icon_size), true)
	# Bubble text.
	var font := get_theme_default_font()
	draw_string(font, Vector2(bubble_x + 16.0, bubble_y + bubble_h / 2.0 + 5.0), message,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, INK)
