extends RefCounted

static func prepare(host: Control, prompt := "") -> void:
	if host.busy: host.status.text = "请等本轮结束。"; return
	if not host.input.text.strip_edges().is_empty(): host.status.text = "输入框已有草稿，请先处理后再制作模型。"; return
	host.input.text = "生成模型：" + prompt
	host.input.grab_focus()
	host.input.set_caret_column(host.input.text.length())
	host.status.text = "描述一个低多边形静态道具；制作完成后先预览，再采用。"

static func render(host: Control) -> void:
	var root: String = host.game_directory_for(host.current).path_join("model-drafts")
	if not DirAccess.dir_exists_absolute(root): return
	var entries = DirAccess.get_directories_at(root)
	entries.sort()
	for id in entries:
		if id.begins_with("."): continue
		var folder: String = root.path_join(id)
		var draft: Dictionary = host.read_json(folder.path_join("draft.json"))
		if draft.get("state", "") != "review": continue
		var card: VBoxContainer = host.panel(host.chat)
		card.add_child(host.label("模型草稿 · 等你确认",14,host.MUTED))
		card.add_child(host.label(str(draft.name),20,host.INK,true))
		card.add_child(host.label(str(draft.summary),14,host.MUTED,true))
		var views = HBoxContainer.new()
		card.add_child(views)
		for name in ["front", "back"]:
			var box = VBoxContainer.new()
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			views.add_child(box)
			box.add_child(host.label("正面斜视" if name == "front" else "背面斜视",12,host.MUTED))
			var picture = TextureRect.new()
			picture.custom_minimum_size = Vector2(110,190)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var img = Image.load_from_file(folder.path_join(name + ".png"))
			if img != null: picture.texture = ImageTexture.create_from_image(img)
			box.add_child(picture)
		card.add_child(host.label("已通过文件与运行检查，请检查造型。采用后入库，游戏不会自动改变。",13,host.MUTED,true))
		var current_brief: bool = int(draft.source_revision) == int(host.current.revision)
		var row = HBoxContainer.new()
		card.add_child(row)
		var accept: Button = host.button("采用模型",func(): host.created_action("accept_model",{"draft_id":id}),true)
		accept.disabled = host.busy or not current_brief
		row.add_child(accept)
		var retry: Button = host.button("改描述重做",func(): prepare(host,str(draft.prompt)))
		retry.disabled = host.busy
		row.add_child(retry)
		var discard: Button = host.button("放弃草稿",func(): host.created_action("discard_model",{"draft_id":id}))
		discard.disabled = host.busy
		row.add_child(discard)
		if not current_brief: card.add_child(host.label("方案已更新，这份草稿不能采用；可改描述重做或放弃。",13,host.MUTED,true))
