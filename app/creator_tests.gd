extends SceneTree
var test_failed := false

class HomeProbe extends "res://creator.gd":
	var sent_request: Dictionary = {}
	func save_selection() -> void:
		pass
	func start_job(request: Dictionary) -> void:
		sent_request = request

func _initialize() -> void:
	call_deferred("run_tests")

func require(condition: bool, message: String) -> void:
	if not condition:
		test_failed = true
		push_error("CREATOR TEST FAILED: " + message)
		quit(1)
		assert(condition, message)

func visible_labels(node: Node) -> String:
	var result: String = node.text if node is Label else ""
	for child in node.get_children(): result += visible_labels(child)
	return result

func run_tests() -> void:
	var creator = HomeProbe.new()
	root.add_child(creator)
	await process_frame
	creator.expand_sidebar()
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		require(creator.more_menu.get_theme_color(state).get_luminance() < 0.45, "project button text stays dark in " + state)
	for choice in [creator.model_picker, creator.effort_picker, creator.home_model_picker, creator.home_effort_picker]:
		require(choice.get_popup().get_theme_font_size("font_size") == 14, "choice popup uses readable text")
		require(choice.get_popup().get_theme_icon("radio_checked").resource_path.ends_with("selected-check.svg"), "choice selection uses checkmark instead of default radio dots")
	require(creator.attachment_button.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER and not creator.attachment_button.expand_icon, "workspace attachment icon must stay centered at fixed size")
	var preview_entry_found := false
	for control in creator.resource_tools.get_meta("audio_row").get_children():
		if control is Button and control.text == "查看 / 制作简单3D模型 ↗": preview_entry_found = true
	require(preview_entry_found, "materials expose the local 3D preview entry in the expanded tools row")
	require(creator.dashboard.visible and not creator.page.visible, "launch enters creation home")
	creator.begin_from_home()
	require(creator.sent_request.is_empty() and creator.route == "home", "empty idea does not submit")
	require(creator.home_mascot != null and creator.home_mascot.visible and creator.hint.text.is_empty(), "empty home submit is answered by the mascot bubble instead of a bare hint line")
	require(not creator.dashboard is ScrollContainer, "home is a fixed canvas without page scrolling")
	require(creator.home_garden.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decoration cannot intercept input")
	require(creator.account_button != null and creator.account_box != null, "sidebar exposes GPT account management")
	require(creator.account_button.icon != null and creator.account_button.icon.resource_path.ends_with("playseed-mascot-farmer-v1.png"), "GPT account entry uses the Playseed farmer mascot")
	require(creator.model_picker.get_item_text(0) == "GPT-6 Astra" and creator.model_picker.get_item_text(1) == "GPT-5.6 Sol", "composer exposes exact GPT model names")
	require(creator.effort_picker.item_count == 5 and creator.effort_picker.get_item_metadata(4) == "max", "workspace composer exposes real reasoning levels")
	require(creator.home_plus.text.is_empty() and creator.home_plus.icon != null and creator.home_plus.custom_minimum_size.x >= 42 and creator.home_plus.custom_minimum_size.x <= 46 and creator.home_model_picker != null, "home composer uses a compact plus-only attachment control")
	var home_plus_normal: StyleBox = creator.home_plus.get_theme_stylebox("normal")
	require(home_plus_normal is StyleBoxFlat and home_plus_normal.corner_radius_top_left == 22, "home plus keeps a fixed circular background")
	require(creator.home_plus.alignment == HORIZONTAL_ALIGNMENT_CENTER and creator.home_plus.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER, "home plus icon is centered inside its circle")
	require(creator.home_plus.tooltip_text.is_empty(), "home plus does not show a tooltip below the composer")
	require(creator.hint.get_parent() == creator.home_plus.get_parent().get_parent() and creator.hint.get_index() < creator.home_plus.get_parent().get_index(), "home status sits above the control row instead of between controls")
	require(creator.home_effort_picker.item_count == 5 and creator.home_effort_picker.get_item_text(1) == "强度：中", "home composer includes reasoning strength")
	var home_plus_text := ""
	for i in range(creator.home_plus.get_popup().item_count):
		home_plus_text += creator.home_plus.get_popup().get_item_text(i) + "|"
	require(home_plus_text.contains("添加图片素材") and home_plus_text.contains("选择或新建项目文件夹"), "home plus menu is fully Chinese")
	require(creator.folder_dialog.use_native_dialog, "project folder picker delegates browsing to macOS Finder")
	require(creator.home_file_dialog.use_native_dialog, "home attachment picker delegates browsing to macOS Finder")
	require(creator.chat_file_dialog.use_native_dialog, "workspace attachment picker delegates browsing to macOS Finder")
	require(creator.resource_tools.import_dialog.use_native_dialog, "resource import picker delegates browsing to macOS Finder")
	require(creator.resource_tools.export_dialog.use_native_dialog, "project export picker delegates browsing to macOS Finder")
	creator.attach_home_file(creator.root_dir.path_join("app/assets/playseed-icon.png"))
	require(not creator.home_attachment.is_empty() and creator.hint.text.contains("参考图"), "home plus attachment is kept for the first creation request")
	creator.home_model_picker.select(0)
	creator.home_effort_picker.select(2)
	require(creator.delivery_undecided != null and creator.delivery_native != null and creator.delivery_web != null, "home asks how friends will play before creating")
	require(creator.delivery_undecided.button_pressed and not creator.delivery_web.button_pressed and creator.delivery_note.text.is_empty(), "delivery question defaults to undecided with an empty note")
	require(not creator.delivery_web.text.contains("建设中") and not creator.delivery_native.text.contains("已支持") and creator.delivery_web.tooltip_text.is_empty(), "delivery options carry no status wording or system tooltip")
	creator.delivery_web.button_pressed = true
	require(not creator.delivery_undecided.button_pressed and creator.delivery_note.text.contains("网页"), "choosing web shows its product-style note")
	creator.home_input.text = "我想做自己的解谜游戏"
	creator.begin_from_home()
	require(creator.sent_request.is_empty() and creator.pending_home_prompt.contains("解谜游戏"), "home asks for a project folder before creating")
	creator.folder_dialog.dir_selected.emit("/tmp")
	creator.folder_dialog.hide()
	require(creator.sent_request.prompt == "我想做自己的解谜游戏" and not creator.sent_request.has("idea_id"), "home creates fresh idea rather than modifying last project")
	require(creator.sent_request.project_directory == "/tmp", "new idea keeps the user-selected project folder")
	require(creator.sent_request.model == "gpt-6-astra", "home-selected GPT model reaches the first creation request")
	require(creator.sent_request.reasoning_effort == "high", "home-selected reasoning strength reaches the first creation request")
	require(creator.model_picker.get_item_text(creator.model_picker.selected) == "GPT-6 Astra" and creator.selected_effort() == "high", "home model and strength carry into the workspace")
	require(creator.sent_request.has("attachment") and creator.sent_request.attachment.role == "参考图", "home reference image reaches the first creation request")
	require(creator.sent_request.delivery == "web", "home delivery choice reaches the first creation request")
	require(creator.delivery_undecided.button_pressed and not creator.delivery_web.button_pressed, "delivery choice resets to undecided after submission")
	require(creator.route == "workspace" and creator.page.visible, "home proceeds to real conversation workspace")
	creator.navigate("library")
	require(creator.library.visible and not creator.page.visible, "project library route works")
	creator.navigate("workspace")
	creator.current = {}
	creator.show_idea()
	require(creator.confirm.disabled, "empty idea cannot be confirmed")
	creator.current = {"id": "00000000000000000000000000000000", "title": "测试", "revision": 1, "ready": false, "status": "drafting",
		"messages": [{"role": "user", "text": "小猫冒险"}, {"role": "assistant", "text": "先想想目标", "questions": []}],
		"questions": [{"question": "小猫做什么？", "choices": ["寻找主人", "经营小店", "解开谜题"]}],
		"plan": {"title": "小猫冒险", "premise": "小猫探索城市", "player_goal": "待确定", "core_loop": ["探索"], "visual_style": "温暖手绘", "first_version": ["一个街区"], "asset_plan": ["小猫：用户上传图片"], "later": ["更多街区"], "assumptions": ["暂定白天"]}}
	creator.show_idea()
	require(creator.confirm.disabled, "unanswered questions block confirmation")
	require(creator.chat.get_child_count() == 2, "clarification stays focused on the two conversation roles")
	creator.choices.get_child(0).get_child(1).pressed.emit()
	require(creator.input.text.contains("小猫做什么？") and creator.input.text.contains("寻找主人"), "suggested answer retains question context")
	creator.current.questions = []
	creator.current.ready = true
	creator.current.status = "ready"
	creator.show_idea()
	require(not creator.confirm.disabled, "ready plan can be confirmed")
	require(creator.chat.get_child_count() == 3, "ready plan appears as a conversation card")
	creator.current.status = "confirmed"
	creator.show_idea()
	require(creator.confirm.disabled and creator.confirm.text.contains("已确认"), "confirmed state is visible and cannot double submit")
	require(creator.build_game_button.visible and creator.build_game_button.text.contains("素材"), "confirmed brief enters material preparation before building")
	creator.advance_creation()
	require(creator.sent_request.action == "prepare_build", "creation flow prepares materials and checklist first")
	creator.created_action("build_game")
	require(creator.sent_request.action == "build_game" and creator.sent_request.game_revision == 0 and creator.sent_request.reasoning_effort == "high", "creation is bound to selected brief and reasoning strength")
	creator.made_game = {"current_revision": 2, "source_revision": 1}
	creator.update_buttons()
	require(creator.play_game_button.visible and creator.build_game_button.disabled, "existing playable version exposes play without accidental duplicate build")
	creator.input.text = "子弹改成双发，保留原来的配色"
	creator.revise_created_game()
	require(creator.sent_request.action == "revise_game" and creator.sent_request.game_revision == 2 and creator.sent_request.prompt.contains("双发"), "modification carries actual feedback and expected game revision")
	creator.busy = true
	creator.update_buttons()
	require(creator.picker.disabled and creator.send.disabled and creator.input.editable, "waiting blocks sending and project switching but still allows drafting the next message")
	creator.status.text = ""
	creator.sent_request = {}
	creator.submit_composer()
	require(creator.sent_request.is_empty() and creator.status.text.contains("上一步还在进行"), "sending while waiting is refused with a readable reason")
	creator.navigate("library")
	require(creator.library.visible and not creator.page.visible, "navigation still works while a job runs")
	creator.navigate("workspace")
	creator.pending_action = "discuss"
	creator.pending_prompt = "等待中的游戏想法"
	creator.show_idea()
	creator.select_detail("方案")
	require(creator.plan_box.visible and creator.effect_box.visible and creator.detail_overlay.visible, "plan opens over the preserved preview")
	require(creator.input.get_theme_stylebox("read_only").bg_color == creator.input.get_theme_stylebox("normal").bg_color, "thinking keeps the input surface bright")
	require(creator.progress_bar.visible and creator.cancel.visible and not creator.home_button.disabled, "thinking has local progress and readable navigation")
	require(visible_labels(creator.chat.get_child(-1)).contains("等待中的游戏想法"), "pending message survives inspecting another tab")
	creator.select_detail("版本")
	require(creator.history_box.visible and not creator.plan_box.visible, "history has a separate view")
	require(not creator.game_versions.visible and creator.version_list != null and creator.version_heading != null, "history uses a readable list and detail layout")
	require(creator.version_validation_text({"test": {"action": "shoot"}}).contains("核心操作有响应") and creator.version_validation_text({}).contains("旧版本"), "version history explains the real automatic check and legacy boundary")
	creator.busy = false
	creator.pending_prompt = ""
	creator.select_detail("效果")
	require(creator.effect_box.visible and not creator.history_box.visible and not creator.detail_overlay.visible, "closing details returns to preview")
	creator.select_detail("制作清单")
	require(creator.plan_box.visible and creator.detail_heading.text == "制作清单", "checklist stays accessible from more menu")
	creator.select_detail("账号")
	require(creator.account_box.visible and creator.detail_heading.text == "GPT 账号", "GPT account status opens inside the workspace")
	creator.close_details()
	creator.toggle_sidebar()
	require(creator.sidebar.visible and creator.sidebar_collapsed and creator.home_button.text == "" and creator.home_button.icon != null, "collapsed sidebar keeps functional icons")
	creator.brand_logo.pressed.emit()
	require(creator.sidebar.visible and not creator.sidebar_collapsed and creator.home_button.text == "创作主页", "project sidebar can reopen")
	creator.made_game = {"current_revision": 2, "source_revision": 1}
	creator.composer_mode.select(1)
	creator.input.text = "添加第二种敌人"
	creator.submit_composer()
	require(creator.sent_request.action == "revise_game", "single composer dispatches game modification mode")
	creator.composer_mode.select(0)
	creator.made_game = {}
	creator.current.status = "ready"
	creator.submit_composer()
	require(creator.sent_request.action == "discuss", "single composer automatically follows the planning stage")
	var fixture: Dictionary = creator.current.duplicate(true)
	fixture.updated_at = "2026-09-05"
	creator.data_dir = creator.root_dir.path_join(".playseed/qa/flow-ui-data")
	creator.active_job = creator.data_dir.path_join("jobs/confirm-test")
	DirAccess.make_dir_recursive_absolute(creator.active_job)
	DirAccess.make_dir_recursive_absolute(creator.data_dir.path_join("ideas/" + fixture.id))
	write_json(creator.data_dir.path_join("ideas/%s/idea.json" % fixture.id), fixture)
	write_json(creator.active_job.path_join("request.json"), {"action": "confirm_brief", "idea_id": fixture.id})
	write_json(creator.active_job.path_join("result.json"), {"idea": fixture})
	write_json(creator.active_job.path_join("status.json"), {"state": "done", "message": "已确认"})
	creator.pending_action = "confirm_brief"
	creator.sent_request = {}
	creator.build_after_confirm = false
	creator.busy = true
	creator.poll_job()
	require(creator.sent_request.is_empty() and not creator.build_after_confirm, "confirmation stops before material preparation and building")
	creator.sent_request = {}
	creator.build_after_confirm = true
	creator.busy = true
	creator.pending_prompt = "保留这条修改"
	creator.input.text = "" # With no next draft, failed input should be restored.
	write_json(creator.active_job.path_join("status.json"), {"state": "error", "message": "确认失败"})
	creator.poll_job()
	require(creator.sent_request.is_empty() and not creator.build_after_confirm and creator.input.text == "保留这条修改", "failed confirmation never starts building and preserves input")
	write_json(creator.active_job.path_join("events.json"), {"events": [{"state": "thinking", "message": "理解想法"}, {"state": "error", "message": "本轮未完成"}]})
	creator.process_open = true
	creator.update_process()
	require(creator.process_scroll.visible and creator.process_details.text.contains("本轮未完成"), "expandable progress comes from actual job events")
	creator.build_after_confirm = true
	creator.cancel_job()
	require(not creator.build_after_confirm, "stop cancels chained build intent")
	creator.resource_tools.select_tab("动画")
	require(creator.resource_tools.visible and not creator.effect_box.visible, "resource tab replaces only the preview area")
	require(creator.resource_tools.tabs.get_parent() == creator.workspace_tools, "all creation tools live in the upper-right toolbar")
	creator.resource_tools.search.text = "悬浮"
	creator.resource_tools.search.text_changed.emit("悬浮")
	require(creator.resource_tools.content.get_child_count() == 1, "resource search filters the catalog")
	var animation_card = creator.resource_tools.content.get_child(0).get_child(0).get_child(0)
	creator.input.text = "保留我的草稿"
	animation_card.get_child(-1).pressed.emit()
	require(creator.input.text == "保留我的草稿", "resource suggestions preserve unsent input")
	creator.input.text = ""
	animation_card.get_child(-1).pressed.emit()
	require(creator.input.text.contains("悬浮"), "resource choice is placed into the existing conversation")
	creator.resource_tools.select_tab("特效")
	require(creator.resource_tools.content.get_child_count() == 2, "four real effect presets are available")
	creator.resource_tools.select_tab("扩展")
	creator.resource_tools.category.select(1)
	creator.resource_tools.render_catalog()
	require(creator.resource_tools.content.get_child_count() == 1, "extension category filter works")
	creator.resource_tools.select_tab("素材")
	require(creator.resource_tools.scope_ai.text == "AI 生成的" and creator.resource_tools.scope_user.text == "我添加的" and creator.resource_tools.scope_ai.button_pressed, "material sources have two clear names")
	creator.resource_tools.scope_user.button_pressed = true
	require(creator.resource_tools.get_meta("import_row").visible, "user scope shows the import row")
	creator.resource_tools.scope_ai.button_pressed = true
	require(not creator.resource_tools.get_meta("import_row").visible, "AI scope hides the import row")
	var generated = {"id":"test-generated", "name":"小鸟", "role":"角色", "width":32,"height":32,"generation":{}}
	var uploaded = {"id":"test-uploaded", "name":"背景", "role":"场景", "width":32,"height":32}
	var game_assets = creator.resource_tools.image_entries([generated,uploaded],true)
	var own_assets = creator.resource_tools.image_entries([generated,uploaded],false)
	require(game_assets.size() == 1 and game_assets[0].id == generated.id and own_assets.size() == 1 and own_assets[0].id == uploaded.id, "generated and uploaded images are classified by real provenance")
	creator.input.text = ""
	creator.resource_tools.redesign_image(generated)
	require(creator.input.text.begins_with("生成图片：重新设计「小鸟」") and creator.resource_tools.notice.text.contains("原图不在素材库"), "single image redesign uses generation route and explains missing reference")
	creator.submit_composer()
	require(creator.sent_request.action == "generate_asset" and creator.sent_request.role == "角色" and not creator.sent_request.has("task"), "redesign preserves image role without inventing a task association")
	creator.input.text = ""
	for tab in creator.resource_tools.tabs.get_children():
		require(tab.text == str(tab.get_meta("target")), "all workspace tabs have visible names")

	creator.resource_tools.import_dialog.file_selected.emit(creator.root_dir.path_join("app/assets/playseed-icon.png"))
	require(creator.sent_request.action == "import_asset" and creator.sent_request.has("png_base64"), "image selection reaches the import worker")
	creator.resource_tools.select_tab("代码")
	require(not creator.resource_tools.code.editable, "generated source is read-only in the trusted UI")
	creator.resource_tools.select_tab("游戏")
	require(creator.effect_box.visible and not creator.resource_tools.visible, "game tab restores preview")
	creator.show_storage()
	require(creator.storage_box.visible and creator.storage_path.text == creator.game_directory_for(creator.current), "legacy storage dialog still renders for compatibility")
	creator.close_details()
	creator.toggle_sidebar()
	creator.home_button.pressed.emit()
	require(not creator.sidebar_collapsed and creator.route == "home", "clicking a rail icon expands sidebar and navigates")
	require(not creator.lab_button.visible, "legacy lab entry removed")
	for i in range(creator.more_menu.get_popup().item_count):
		require(not creator.more_menu.get_popup().get_item_text(i).contains("实验区"), "legacy lab removed from more menu")
		require(not creator.more_menu.get_popup().get_item_text(i).contains("先讨论方案"), "manual discussion mode removed from project menu")
	var project_menu_text := ""
	for i in range(creator.more_menu.get_popup().item_count):
		project_menu_text += creator.more_menu.get_popup().get_item_text(i) + "|"
	require(project_menu_text.contains("游戏方案") and project_menu_text.contains("制作清单") and project_menu_text.contains("版本历史") and project_menu_text.contains("打开项目文件夹"), "project menu groups plan, checklist, history, and folder access")
	require(not project_menu_text.contains("项目保存位置") and creator.storage_button == null, "legacy storage controls are removed from navigation")
	creator.context_project_id = fixture.id
	await creator.project_context_action(1)
	require(visible_labels(creator.rename_dialog).contains("文件夹会一起重命名"), "rename warns that the project folder also changes")
	creator.rename_dialog.hide()
	await creator.project_context_action(2)
	require(visible_labels(creator.delete_dialog).contains("整个项目文件夹") and visible_labels(creator.delete_dialog).contains("无法恢复"), "delete clearly warns about permanent folder deletion")
	creator.delete_dialog.hide()

	creator.busy = false
	creator.current = fixture
	creator.current.status = "confirmed"
	creator.prepare_asset_prompt()
	require(creator.input.text == "生成图片：", "chat guides user to image generation")
	creator.input.text += "一颗手绘豆苗"
	creator.submit_composer()
	require(creator.sent_request.action == "generate_asset" and creator.sent_request.prompt == "一颗手绘豆苗", "image request bypasses game revision and uses the same composer")
	require(creator.sent_request.has("model") and creator.sent_request.has("reasoning_effort"), "image generation keeps selected account model settings")

	creator.input.text = "我还在写的草稿"
	creator.prepare_asset_task("花园背景", "generate")
	require(creator.input.text == "我还在写的草稿", "asset task never overwrites existing composer draft")
	creator.input.text = ""
	creator.prepare_asset_task("花园背景", "generate")
	require(creator.input.text.contains("花园背景") and creator.input.text.contains(creator.current.plan.visual_style), "task generation includes selected need and plan visual style")
	creator.submit_composer()
	require(creator.sent_request.action == "generate_asset" and creator.sent_request.prompt.contains("花园背景"), "asset task uses real image generation request")
	require(creator.sent_request.task == "花园背景", "task identity accompanies image generation")
	creator.style_reference_selection[creator.style_reference_key()] = "a".repeat(32)
	creator.submit_composer()
	require(creator.sent_request.get("style_reference_id", "") == "a".repeat(32), "selected style reference reaches image request")
	creator.style_reference_selection.clear()
	creator.input.text = "生成图片：完全不同的需求"
	creator.submit_composer()
	require(not creator.sent_request.has("task"), "replaced prompt never inherits unrelated task")
	require(not creator.sent_request.has("style_reference_id"), "no style reference means no implicit image")
	creator.pending_asset_upload = {"task": "玩家角色", "idea_id": creator.current.id, "revision": creator.current.revision}
	var upload_path: String = creator.data_dir.path_join("qa/task-upload.png")
	DirAccess.make_dir_recursive_absolute(upload_path.get_base_dir())
	var test_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	test_image.fill(Color.GREEN)
	test_image.save_png(upload_path)
	creator.input.text = "还在写的草稿"
	creator.attach_chat_file(upload_path)
	require(creator.sent_request.action == "import_asset" and creator.sent_request.task == "玩家角色", "task upload reaches real import request")
	require(creator.input.text.begins_with("还在写的草稿") and creator.input.text.contains("玩家角色"), "upload preserves draft and names intended task")
	creator.prepare_asset_task("玩家角色", "upload")
	require(creator.pending_asset_upload.task == "玩家角色" and creator.pending_asset_upload.idea_id == creator.current.id, "task upload binds current project and need")
	creator.chat_file_dialog.canceled.emit()
	creator.chat_file_dialog.hide()
	require(creator.pending_asset_upload.is_empty(), "cancel clears upload task association")
	creator.pending_asset_upload = {"task": "旧素材", "idea_id": "old-project", "revision": 1}
	creator.attach_chat_file("/tmp/not-imported.png")
	require(creator.pending_asset_upload.is_empty() and creator.status.text.contains("方案或项目已变化"), "stale upload cannot enter another project")

	# A cancelled first message must remain in the workspace as a sent turn.
	creator.current = {}
	creator.navigate("workspace")
	creator.pending_action = "discuss"
	creator.pending_prompt = "做一个花园游戏"
	creator.input.text = "这是我正在写的下一句话"
	creator.home_input.text = ""
	creator.busy = true
	creator.active_job = creator.data_dir.path_join("qa/cancel-ui-test")
	DirAccess.make_dir_recursive_absolute(creator.active_job)
	var request_file := FileAccess.open(creator.active_job.path_join("request.json"), FileAccess.WRITE)
	request_file.store_string(JSON.stringify({"action":"discuss", "prompt":"做一个花园游戏", "project_directory":"/tmp/playseed-stop-test"}))
	request_file.close()
	var state_file := FileAccess.open(creator.active_job.path_join("status.json"), FileAccess.WRITE)
	state_file.store_string(JSON.stringify({"state":"cancelled", "message":"已停止"}))
	state_file.close()
	creator.poll_job()
	require(not creator.busy and creator.route == "workspace", "stopping first generation does not return home")
	require(creator.input.text == "这是我正在写的下一句话" and creator.home_input.text.is_empty(), "stop does not refill sent text or overwrite next draft")
	require(creator.stopped_request.prompt == "做一个花园游戏", "stopped generation retains the original sent request")
	creator.send_message()
	require(creator.sent_request.project_directory == "/tmp/playseed-stop-test", "continuing after first stop retains the chosen project folder")

	for controls in [creator.home_model_controls, creator.workspace_model_controls]:
		controls.reset_defaults()
		require(controls.slider.tick_count == 0, "native below-track ticks are disabled")
		for point in controls.slider.marker_positions():
			require(is_equal_approx(point.y, controls.slider.size.y * 0.5), "effort markers sit inside track centerline")
		controls.slider.value = 4
		require(controls.effort.get_item_metadata(controls.effort.selected) == "max", "combined slider changes real effort")
		controls.cycle_model()
		require(controls.model.get_item_metadata(controls.model.selected) == "gpt-5.6-terra", "combined model switch changes real model")
		require(controls.model_switch.item_count == 6, "six models available in both composers")
		controls.model_switch.item_selected.emit(5)
		require(controls.model.get_item_metadata(controls.model.selected) == "gpt-5.4-mini", "dropdown selects Mini request model")
		require(controls.effort.item_count == 4 and controls.slider.max_value == 3 and controls.effort.get_item_metadata(controls.effort.selected) == "high", "unsupported max clamps to high for Mini")
		controls.model_switch.item_selected.emit(2)
		controls.slider.value = 4
		require(controls.model.get_item_metadata(controls.model.selected) == "gpt-5.6-terra" and controls.effort.get_item_metadata(controls.effort.selected) == "max", "Terra restores supported max")
		controls.reset_defaults()
		require(controls.model.selected == 1 and controls.effort.selected == 1, "combined panel resets defaults")
		require(not controls.model.visible and not controls.effort.visible, "old separate model menus are hidden")

	if test_failed:
		quit(1)
		return
	print("CREATOR UI TESTS PASSED: empty/draft/ready/confirmed states, chat, choices, busy lock, route switching, hidden game input")
	quit(0)

func write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
