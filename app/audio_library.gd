extends AcceptDialog
var host: Control
var project_id: String
var revision: int
var folder: String
var picker: FileDialog
var selected_file := ""
var filename: Label
var source: LineEdit
var license_picker: OptionButton
var role: OptionButton
var import_button: Button
var save_button: Button
var message: Label
var track_list: VBoxContainer
var player: AudioStreamPlayer
var sliders: Dictionary = {}
var last_manifest := ""
var timer := 0.0

func setup(owner_ui: Control) -> void:
	host = owner_ui
	project_id = str(host.current.id)
	revision = int(host.current.revision)
	folder = host.game_directory_for(host.current).path_join("audio-library")
	theme = host.theme.duplicate()
	theme.set_stylebox("panel", "AcceptDialog", host.style(Color("fbfaf4")))
	for state in ["normal", "focus"]: theme.set_stylebox(state, "LineEdit", host.style(Color("edf1e9")))
	theme.set_color("font_color", "LineEdit", host.INK)
	theme.set_color("font_placeholder_color", "LineEdit", host.MUTED)
	exclusive = true
	title = "声音素材与音量"
	ok_button_text = "关闭"
	min_size = Vector2i(620, 560)
	add_theme_stylebox_override("panel", host.style(Color("fbfaf4")))
	for state in ["normal", "hover", "pressed", "focus"]: get_ok_button().add_theme_stylebox_override(state, host.style(Color("e5eedb")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: get_ok_button().add_theme_color_override(state, host.INK)
	get_ok_button().custom_minimum_size = Vector2(90, 36)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	close_requested.connect(queue_free)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(host.label("声音素材", 23, host.INK))
	box.add_child(host.label("先试听，再添加到对话。导入和音量设置都不会立即改变已有游戏。", 14, host.MUTED, true))
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(host.compact(host.button("选择 WAV…", func(): picker.popup_centered_ratio(0.7))))
	filename = host.label("16位PCM · 16 MB / 3分钟以内", 13, host.MUTED, true)
	filename.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(filename)
	role = OptionButton.new()
	role.add_item("音效"); role.add_item("背景音乐")
	row.add_child(role)
	source = LineEdit.new()
	source.placeholder_text = "来源说明：作者、网址，或自己的制作说明"
	box.add_child(source)
	var source_row := HBoxContainer.new()
	box.add_child(source_row)
	license_picker = OptionButton.new()
	for item in ["选择授权依据", "自有原创", "CC0", "已获授权", "其他（见来源说明）"]: license_picker.add_item(item)
	license_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_row.add_child(license_picker)
	import_button = host.compact(host.button("导入声音", submit_import, true))
	source_row.add_child(import_button)
	var manifest: Dictionary = host.read_json(folder.path_join("library.json"))
	var levels: Dictionary = manifest.get("levels", {"music":0.35,"sfx":0.7})
	for group in ["music", "sfx"]:
		var line := HBoxContainer.new()
		box.add_child(line)
		line.add_child(host.label("背景音乐" if group == "music" else "音效", 14, host.INK))
		var slider := HSlider.new()
		slider.max_value = 100
		slider.value = float(levels[group]) * 100
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(slider)
		var percent: Label = host.label("%d%%" % slider.value, 13, host.MUTED)
		percent.custom_minimum_size.x = 44
		line.add_child(percent)
		slider.value_changed.connect(func(value): percent.text = "%d%%" % value)
		sliders[group] = slider
	save_button = host.compact(host.button("保存为下一版默认音量", submit_levels))
	box.add_child(save_button)
	message = host.label("试听按上方音量播放；来源由你填写，平台不自动验证授权。", 13, host.MUTED, true)
	box.add_child(message)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 130
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	track_list = VBoxContainer.new()
	track_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(track_list)
	player = AudioStreamPlayer.new()
	add_child(player)
	box.add_child(host.compact(host.button("停止试听", func(): player.stop())))
	picker = FileDialog.new()
	picker.title = "选择声音文件"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.wav ; WAV声音"])
	picker.file_selected.connect(select_file)
	add_child(picker)
	render_tracks()
	popup_centered(Vector2i(640, 640))
	call_deferred("fit_after_layout")

func valid_context() -> bool:
	return not host.current.is_empty() and str(host.current.id) == project_id and int(host.current.revision) == revision

func select_file(path: String) -> void:
	if not valid_context(): return
	selected_file = path
	filename.text = path.get_file()

func submit_import() -> void:
	if not valid_context() or host.busy: return
	if selected_file.is_empty() or source.text.strip_edges().is_empty() or license_picker.selected == 0:
		message.text = "请选择声音，并填写来源和授权依据。"; return
	var file := FileAccess.open(selected_file, FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024:
		message.text = "声音无法读取，或超过16 MB。"; return
	var data := file.get_buffer(file.get_length())
	file.close()
	host.created_action("import_audio", {"name":selected_file.get_file().get_basename(),"role":role.get_item_text(role.selected),"source":source.text.strip_edges(),"license":license_picker.get_item_text(license_picker.selected),"wav_base64":Marshalls.raw_to_base64(data)})
	message.text = "正在检查声音格式并导入，请以处理结果为准。"

func submit_levels() -> void:
	if not valid_context() or host.busy: return
	host.created_action("set_audio_levels", {"levels":{"music":sliders.music.value / 100.0,"sfx":sliders.sfx.value / 100.0}})
	message.text = "正在保存下一版的默认音量；已有版本不变。"

func play_track(track: Dictionary) -> void:
	if not valid_context(): return
	var id: String = str(track.get("id", ""))
	if id.length() != 32 or not id.is_valid_hex_number(): return
	var path := folder.path_join(id + ".wav")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024:
		message.text = "声音已丢失，请重新导入。"; return
	var data := file.get_buffer(file.get_length())
	file.close()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(data)
	if hashing.finish().hex_encode().left(32) != id:
		message.text = "声音已被修改，请重新导入。"; return
	var stream := AudioStreamWAV.load_from_buffer(data)
	if stream == null: message.text = "声音无法播放。"; return
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	player.stop()
	player.stream = stream
	player.volume_linear = sliders.music.value / 100.0 if track.role == "背景音乐" else sliders.sfx.value / 100.0
	player.play()
	message.text = "正在试听「%s」；尚未加入游戏。" % track.name

func propose(track: Dictionary) -> void:
	if not valid_context() or host.busy: return
	if not host.input.text.strip_edges().is_empty():
		message.text = "输入框里已有草稿，请先处理，避免覆盖。"; return
	host.resource_tools.propose("把声音「%s」（编号%s）用作%s，请结合玩法安排触发或播放时机；保留原玩法和画面，并支持声音设置。" % [track.name,track.id,track.role])
	player.stop()
	queue_free()

func render_tracks() -> void:
	host.clear_children(track_list)
	var manifest: Dictionary = host.read_json(folder.path_join("library.json"))
	last_manifest = JSON.stringify(manifest)
	var tracks: Array = manifest.get("tracks", [])
	if tracks.is_empty(): track_list.add_child(host.label("还没有声音素材。", 15, host.MUTED))
	for track in tracks:
		var card: VBoxContainer = host.panel(track_list)
		card.add_child(host.label("%s · %s · %.1f秒" % [track.name,track.role,track.duration], 15, host.INK, true))
		card.add_child(host.label("%s · %s" % [track.license,track.source], 12, host.MUTED, true))
		var row := HBoxContainer.new()
		card.add_child(row)
		row.add_child(host.compact(host.button("试听", func(): play_track(track))))
		row.add_child(host.compact(host.button("添加到对话", func(): propose(track))))

func _process(delta: float) -> void:
	if not is_instance_valid(host): return
	if not valid_context():
		queue_free(); return
	import_button.disabled = host.busy
	save_button.disabled = host.busy
	timer += delta
	if timer < 0.3: return
	timer = 0.0
	var manifest: Dictionary = host.read_json(folder.path_join("library.json"))
	if JSON.stringify(manifest) != last_manifest:
		render_tracks()
		message.text = "声音素材或默认音量已更新；游戏版本尚未改变。"
	elif not host.busy and host.pending_action in ["import_audio", "set_audio_levels"]:
		message.text = host.status.text

func fit_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_queued_for_deletion(): return
	popup_centered(Vector2i(640, 640))
