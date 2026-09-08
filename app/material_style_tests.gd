extends SceneTree
class Probe extends "res://creator.gd":
	func save_selection() -> void: pass
	func start_job(_request: Dictionary) -> void: pass
func _initialize(): call_deferred("run_tests")
func run_tests():
	root.size = Vector2i(1320,850)
	var host = Probe.new();root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	host.current = {"id":"material_style_fixture","revision":1,"status":"confirmed","project_directory":host.root_dir.path_join(".playseed/qa/material-style/fixture")}
	DirAccess.make_dir_recursive_absolute(host.root_dir.path_join(".playseed/qa/material-style"))
	var failures: Array = []
	var toggle = host.resource_tools.extra_material_tools
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		var color = toggle.get_theme_color(state)
		if color.get_luminance() > .45: failures.append("开关文字在%s状态变浅" % state)
	host.made_game = {}
	host.navigate("workspace")
	host.resource_tools.select_tab("素材")
	host.resource_tools.scope_user.button_pressed = true
	host.resource_tools.on_scope_changed()
	await process_frame
	await process_frame
	var original_rect: Rect2 = toggle.get_global_rect()
	for expanded in [true,false]:
		toggle.button_pressed = expanded
		await process_frame
		await process_frame
		if toggle.get_global_rect() != original_rect: failures.append("展开工具后按钮位置或尺寸变化")
		if host.resource_tools.get_meta("audio_row").visible != expanded: failures.append("工具展开状态不一致")
		if "--visual" in OS.get_cmdline_user_args():
			var pointer = InputEventMouseMotion.new()
			pointer.position = toggle.get_global_rect().get_center()
			root.push_input(pointer)
			await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(host.root_dir.path_join(".playseed/qa/material-style/tools-%s.png" % str(expanded)))
	for script in ["audio_library","model_library"]:
		var dialog = load("res://"+script+".gd").new();host.add_child(dialog);dialog.setup(host)
		await process_frame
		if not dialog.transparent_bg: failures.append(script+"圆角外仍有不透明视口底色")
		if "--visual" in OS.get_cmdline_user_args():
			await create_timer(.4).timeout
			RenderingServer.force_draw()
			var folder = host.root_dir.path_join(".playseed/qa/material-style")
			DirAccess.make_dir_recursive_absolute(folder)
			root.get_texture().get_image().save_png(folder.path_join(script+".png"))
			var img = dialog.get_texture().get_image()
			for point in [Vector2i(1,1),Vector2i(img.get_width()-2,1),Vector2i(1,img.get_height()-2),Vector2i(img.get_width()-2,img.get_height()-2)]:
				if img.get_pixelv(point).a > .01: failures.append(script+"圆角像素不透明")
		dialog.queue_free();await process_frame
	print("MATERIAL_STYLE_TESTS_PASSED" if failures.is_empty() else "MATERIAL_STYLE_TESTS_FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
