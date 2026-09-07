extends Node2D
# Playseed's trusted helpers. Generated code can use these without file APIs.
const Feedback = preload("res://playseed_feedback.gd")
var _asset_cache: Dictionary = {}
var _animation_cache: Dictionary = {}

func asset_texture(asset_id: String) -> Texture2D:
	if asset_id.length() != 32 or not asset_id.is_valid_hex_number():
		return null
	if _asset_cache.has(asset_id):
		return _asset_cache[asset_id]
	var image := Image.load_from_file("res://assets/" + asset_id + ".png")
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_asset_cache[asset_id] = texture
	return texture

func animate_pop(target: Node2D) -> Tween:
	var original := target.scale
	target.scale = original * 0.1
	var tween := target.create_tween()
	tween.tween_property(target, "scale", original, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

func animate_float(target: Node2D) -> Tween:
	var y := target.position.y
	var tween := target.create_tween().set_loops()
	tween.tween_property(target, "position:y", y - 7, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "position:y", y, 0.8).set_trans(Tween.TRANS_SINE)
	return tween

func animate_pulse(target: Node2D) -> Tween:
	var scale_start := target.scale
	var tween := target.create_tween().set_loops()
	tween.tween_property(target, "scale", scale_start * 1.12, 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "scale", scale_start, 0.55).set_trans(Tween.TRANS_SINE)
	return tween

func animate_squash(target: Node2D) -> Tween:
	var scale_start := target.scale
	var tween := target.create_tween()
	tween.tween_property(target, "scale", scale_start * Vector2(1.3, 0.7), 0.12)
	tween.tween_property(target, "scale", scale_start, 0.3).set_trans(Tween.TRANS_BACK)
	return tween

func animate_spin(target: Node2D) -> Tween:
	var tween := target.create_tween()
	tween.tween_property(target, "rotation", target.rotation + TAU, 0.8).set_trans(Tween.TRANS_CUBIC)
	return tween

func animate_fade(target: Node2D) -> Tween:
	target.modulate.a = 0.0
	var tween := target.create_tween()
	tween.tween_property(target, "modulate:a", 1.0, 0.8)
	return tween

func effect_burst(at: Vector2, tint: Color = Color("d5ef94")) -> Node2D:
	return _feedback("burst", at, tint)

func effect_ring(at: Vector2, tint: Color = Color("9bdbcf")) -> Node2D:
	return _feedback("ring", at, tint)

func effect_trail(at: Vector2, tint: Color = Color("e9d495")) -> Node2D:
	return _feedback("trail", at, tint)

func effect_beam(at: Vector2, tint: Color = Color("a2d9f1")) -> Node2D:
	return _feedback("beam", at, tint)

func _feedback(kind: String, at: Vector2, tint: Color) -> Node2D:
	var fx := Feedback.new()
	fx.kind = kind
	fx.tint = tint
	fx.position = at
	add_child(fx)
	return fx

func asset_animation(asset_id: String) -> SpriteFrames:
	if _animation_cache.has(asset_id): return _animation_cache[asset_id]
	var texture := asset_texture(asset_id)
	if texture == null or not FileAccess.file_exists("res://assets/animations.json"): return null
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations.json"))
	if not config is Dictionary or not config.get(asset_id) is Dictionary: return null
	var frames = load("res://playseed_sprite_frames.gd").build(texture, config[asset_id])
	if frames != null: _animation_cache[asset_id] = frames
	return frames

var _audio_runtime: Node
func _audio() -> Node:
	if not is_instance_valid(_audio_runtime):
		_audio_runtime = preload("res://playseed_audio.gd").new()
		add_child(_audio_runtime)
	return _audio_runtime

func play_sound(asset_id: String) -> bool:
	return _audio().sound(asset_id)

func play_music(asset_id: String) -> bool:
	return _audio().start_music(asset_id)

func reset_audio() -> void:
	_audio().stop_all()

func pause_audio(value: bool) -> void:
	_audio().pause_audio(value)

func set_audio_volume(group: String, value: float) -> void:
	_audio().set_level(group, value)

func audio_snapshot() -> Dictionary:
	return _audio().snapshot()
