extends SceneTree
class VisualCreator extends "res://creator.gd":
	func _ready():
		data_dir = root_dir.path_join(".playseed")
		build_ui()
		load_ideas()
		navigate("workspace")
	func save_selection():
		pass
func _initialize():
	call_deferred("capture")
func shot(ui: Control, name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ui.root_dir.path_join(".playseed/qa/" + name + ".png"))
func capture():
	var ui = VisualCreator.new()
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.current = {}
	ui.busy = true
	ui.pending_action = "discuss"
	ui.pending_prompt = "我想做一个小人打架的游戏"
	ui.status.text = "Playseed 正在理解你的想法… · 16 秒"
	ui.show_idea()
	ui.refresh_projects()
	await shot(ui, "ux-thinking")
	ui.busy = false
	ui.pending_prompt = ""
	ui.status.text = ""
	ui.update_buttons()
	ui.navigate("home")
	await shot(ui, "ux-home")
	ui.load_ideas("df3d28a9de624eba92ae3bfd0f092441")
	ui.navigate("workspace")
	await shot(ui, "ux-playable")
	for tab_name in ["素材", "动画", "特效", "扩展", "代码"]:
		ui.resource_tools.select_tab(tab_name)
		await create_timer(0.35).timeout
		await shot(ui, "tools-" + tab_name)
	ui.resource_tools.select_tab("游戏")
	ui.toggle_sidebar()
	await shot(ui, "ux-collapsed")
	ui.expand_sidebar()
	ui.show_storage()
	await shot(ui, "ux-storage")
	ui.close_details()
	ui.select_detail("版本")
	await shot(ui, "ux-history")
	ui.close_details()
	root.size = Vector2i(1100, 760)
	ui.load_ideas("1284d51af2704f6eb6a670b2d7258223")
	ui.navigate("workspace")
	await shot(ui, "ux-small-draft")
	ui.select_detail("方案")
	await shot(ui, "ux-small-plan")
	ui.close_details()
	ui.navigate("home")
	await shot(ui, "ux-home-small")
	quit()
