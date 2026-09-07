extends Node
# Trusted bounded mixer. The generated game sees IDs and operations, not paths.
var tracks: Dictionary = {}
var streams: Dictionary = {}
var levels: Dictionary = {"music": 0.35, "sfx": 0.7}
var music: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var music_id := ""
var panel: PanelContainer
var paused := false
var event_counts: Dictionary = {}

func _ready() -> void:
	if FileAccess.file_exists("res://audio/manifest.json"):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://audio/manifest.json"))
		if manifest is Dictionary:
			for track in manifest.get("tracks", []): tracks[str(track.id)] = track
			for group in ["music", "sfx"]: levels[group] = clampf(float(manifest.get("levels", {}).get(group, levels[group])), 0, 1)
	music = AudioStreamPlayer.new()
	music.name = "背景音乐"
	add_child(music)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.name = "音效%d" % i
		add_child(player)
		effects.append(player)
	_apply_levels()
	if not tracks.is_empty(): _build_controls()

func _stream(id: String) -> AudioStreamWAV:
	if not tracks.has(id) or id.length() != 32 or not id.is_valid_hex_number(): return null
	if streams.has(id): return streams[id]
	var bytes := FileAccess.get_file_as_bytes("res://audio/" + id + ".wav")
	if bytes.size() < 44 or bytes.size() > 16 * 1024 * 1024: return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = bytes.decode_u16(22) == 2
	stream.mix_rate = bytes.decode_u32(24)
	stream.data = bytes.slice(44)
	if tracks[id].role == "背景音乐":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
	streams[id] = stream
	return stream

func sound(id: String) -> bool:
	if paused or not tracks.has(id) or tracks[id].role != "音效": return false
	var stream := _stream(id)
	if stream == null: return false
	for player in effects:
		if not player.playing:
			player.stream = stream
			player.play()
			event_counts[id] = int(event_counts.get(id, 0)) + 1
			return true
	return false

func start_music(id: String) -> bool:
	if not tracks.has(id) or tracks[id].role != "背景音乐": return false
	if music_id == id and music.playing: return true
	var stream := _stream(id)
	if stream == null: return false
	music.stop()
	music.stream = stream
	music_id = id
	music.play()
	music.stream_paused = paused
	return true

func stop_all() -> void:
	music.stop()
	music_id = ""
	for player in effects:
		player.stop()
		player.stream_paused = false
	paused = false
	music.stream_paused = false
	event_counts.clear()

func pause_audio(value: bool) -> void:
	paused = value
	music.stream_paused = value
	for player in effects: player.stream_paused = value

func set_level(group: String, value: float) -> void:
	if group not in ["music", "sfx"] or not is_finite(value): return
	levels[group] = clampf(value, 0.0, 1.0)
	_apply_levels()

func _apply_levels() -> void:
	music.volume_linear = float(levels.music)
	for player in effects: player.volume_linear = float(levels.sfx)

func snapshot() -> Dictionary:
	var active := 0
	for player in effects:
		if player.playing: active += 1
	return {"music_playing":music.playing,"music_id":music_id,"active_sfx":active,"levels":levels.duplicate(),"paused":paused,"events":event_counts.duplicate(),"players":effects.size()+1}

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	var button := Button.new()
	button.name = "声音设置"
	button.text = "声音"
	button.position = Vector2(880, 8)
	button.size = Vector2(64, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.theme = theme
	layer.add_child(button)
	panel = PanelContainer.new()
	panel.position = Vector2(632, 56)
	panel.size = Vector2(312, 180)
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7f2e4")
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	panel.hide()
	layer.add_child(panel)
	button.pressed.connect(func(): panel.visible = not panel.visible)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	for group in ["music", "sfx"]:
		var title := Label.new()
		title.text = "背景音乐" if group == "music" else "音效"
		title.add_theme_color_override("font_color", Color("263e36"))
		box.add_child(title)
		var slider := HSlider.new()
		slider.name = group
		slider.max_value = 100
		slider.value = float(levels[group]) * 100
		slider.custom_minimum_size = Vector2(270, 24)
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(value): set_level(group, value / 100.0))
		box.add_child(slider)
	var hint := Label.new()
	hint.text = "调到0即静音 · 本次试玩有效"
	hint.add_theme_color_override("font_color", Color("596c60"))
	box.add_child(hint)
