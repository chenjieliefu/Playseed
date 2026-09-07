extends SceneTree
class Probe extends "res://creator.gd":
	var sent_request: Dictionary = {}
	func save_selection() -> void: pass
	func start_job(request: Dictionary) -> void: sent_request = request
func _initialize(): call_deferred("run_tests")
func run_tests():
	var host = Probe.new()
	root.add_child(host)
	root.size = Vector2i(1320,850)
	await process_frame
	var folder: String = host.root_dir.path_join(".playseed/qa/audio-ui")
	make_fixture(folder)
	host.current = {"id":"audio_ui_probe", "revision":1,"status":"confirmed","title":"声音验收","project_directory":folder}
	host.made_game = {"current_revision":6,"source_revision":1}
	host.navigate("workspace")
	host.resource_tools.select_tab("素材")
	var editor = load("res://audio_library.gd").new()
	host.add_child(editor)
	editor.setup(host)
	await process_frame
	assert(editor.picker.use_native_dialog)
	editor.submit_import()
	assert(host.sent_request.is_empty())
	editor.select_file(folder.path_join("import.wav"))
	editor.source.text = "程序合成测试"
	editor.license_picker.select(4)
	editor.submit_import()
	assert(host.sent_request.action == "import_audio" and host.sent_request.role == "音效")
	assert(host.sent_request.license == "其他（见来源说明）" and not host.sent_request.wav_base64.is_empty())
	editor.sliders.music.value = 0
	editor.sliders.sfx.value = 22
	editor.submit_levels()
	assert(host.sent_request.action == "set_audio_levels" and host.sent_request.levels.music == 0 and is_equal_approx(host.sent_request.levels.sfx,0.22))
	var manifest: Dictionary = host.read_json(folder.path_join("audio-library/library.json"))
	assert(manifest.tracks.size() == 6)
	editor.play_track(manifest.tracks[0])
	assert(editor.player.playing)
	editor.player.stop()
	host.input.text = "保留草稿"
	editor.propose(manifest.tracks[0])
	assert(host.input.text == "保留草稿")
	host.busy = true
	var before: Dictionary = host.sent_request.duplicate(true)
	editor.submit_levels()
	assert(host.sent_request == before)
	host.busy = false
	var saved: Dictionary = host.current.duplicate(true)
	host.current.id = "different"
	editor.submit_import()
	assert(host.sent_request == before)
	host.current = saved
	if "--visual" in OS.get_cmdline_user_args():
		editor.message.text = "素材已入库 · 试听后添加到对话，再制作新版本。"
		editor.sliders.music.value = 35
		editor.sliders.sfx.value = 70
		for i in range(6): await process_frame
		assert(editor.size.y <= 690)
		print("AUDIO_DIALOG_SIZE:", editor.size)
		for child in editor.get_children():
			if child is Control: print(child.get_class(), child.size, child.get_combined_minimum_size())
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder.path_join("audio-library-ui.png"))
	host.input.text = ""
	editor.propose(manifest.tracks[0])
	assert(host.input.text.contains(manifest.tracks[0].id) and host.composer_mode.selected == 1)
	await process_frame
	host.queue_free()
	await process_frame
	print("AUDIO_UI_TESTS_PASSED: import, source, levels, playback, draft protection, project isolation")
	quit()

func make_fixture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder.path_join("audio-library"))
	var tracks: Array = []
	var names = ["开火", "命中", "升级", "胜利", "失败", "背景音乐"]
	for index in range(6):
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var raw = PackedByteArray()
		raw.resize(5292)
		for i in range(2646): raw.encode_s16(i*2, int(2000*sin(TAU*(220+index*110)*float(i)/22050)))
		stream.data = raw
		var temporary = folder.path_join("import.wav")
		assert(stream.save_to_wav(temporary) == OK)
		var data = FileAccess.get_file_as_bytes(temporary)
		var hashing = HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(data)
		var id = hashing.finish().hex_encode().left(32)
		var output = FileAccess.open(folder.path_join("audio-library/"+id+".wav"),FileAccess.WRITE)
		output.store_buffer(data)
		output.close()
		tracks.append({"id":id,"name":names[index],"role":"背景音乐" if index==5 else "音效","source":"本机合成的界面检查短音，不含外部录音或采样。","license":"其他（见来源说明）","duration":0.12})
	var manifest = FileAccess.open(folder.path_join("audio-library/library.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"tracks":tracks,"levels":{"music":0.35,"sfx":0.7}}))
	manifest.close()
