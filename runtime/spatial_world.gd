extends Node3D

const Player = preload("res://spatial_player.gd")
const Models = preload("res://spatial_models.gd")
var model_instances: Array = []
var specification: Dictionary
var player: CharacterBody3D
var camera: Camera3D
var objects: Array = []
var exit_object: Node3D
var collected: Array = []
var held: Dictionary = {}
var won := false
var paused := false
var message := "靠近发光物品，按 E 互动。"
var progress_label: Label
var hint_label: Label
var end_panel: PanelContainer

func box(size: Vector3, at: Vector3, tint: Color, solid := true) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	add_child(node)
	node.position = at
	var visual = MeshInstance3D.new()
	var mesh_shape = BoxMesh.new()
	mesh_shape.size = size
	visual.mesh = mesh_shape
	var material = StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.85
	visual.material_override = material
	node.add_child(visual)
	if solid:
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	return node

func caption(parent: Node3D, text: String) -> void:
	var item = Label3D.new()
	item.text = text
	item.position.y = 1.1
	item.font_size = 42
	item.pixel_size = 0.008
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item.modulate = Color("243a36")
	item.outline_modulate = Color("fff8e7")
	item.outline_size = 12
	parent.add_child(item)

func _ready() -> void:
	specification = JSON.parse_string(FileAccess.get_file_as_string("res://world.json"))
	var sx: float = specification.size[0]
	var sz: float = specification.size[1]
	box(Vector3(sx,0.5,sz), Vector3(0,-0.25,0), Color(specification.floor_color))
	for sign_value in [-1,1]:
		box(Vector3(sx+0.4,1.0,0.3),Vector3(0,0.5,sign_value*(sz/2+0.15)),Color(specification.wall_color))
		box(Vector3(0.3,1.0,sz),Vector3(sign_value*(sx/2+0.15),0.5,0),Color(specification.wall_color))
	for obstacle in specification.obstacles:
		var extent = Vector3(obstacle.size[0],obstacle.size[1],obstacle.size[2])
		var body = box(extent,Vector3(obstacle.position[0],obstacle.size[1]/2,obstacle.position[1]),Color(obstacle.color))
		if not str(obstacle.get("model_id","")).is_empty():
			var model_visual = Models.load_visual(obstacle.model_id,extent)
			assert(model_visual != null,"模型没有成功入场")
			if model_visual != null:
				body.get_child(0).hide()
				body.add_child(model_visual)
				model_instances.append(model_visual)
				box(Vector3(extent.x,.06,extent.z),Vector3(obstacle.position[0],.03,obstacle.position[1]),Color("b6ad90"),false)
	for data in specification.items:
		var item = box(Vector3(.55,.65,.55),Vector3(data.position[0],.65,data.position[1]),Color(data.color),false)
		caption(item,data.name)
		objects.append(item)
	exit_object = box(Vector3(1.2,.08,1.2),Vector3(specification.exit.position[0],.05,specification.exit.position[1]),Color(specification.exit.color),false)
	caption(exit_object,specification.exit.name)
	player = Player.new()
	add_child(player)
	player.speed = specification.speed
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(sx,sz) * 1.05 + 3.5
	camera.position = Vector3(0,24,18)
	camera.look_at(Vector3.ZERO)
	camera.near = 0.1
	camera.far = 80
	camera.current = true
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-30,0)
	light.light_energy = 0.65
	light.shadow_enabled = true
	add_child(light)
	var ambient = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("dfe9e2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff6de")
	environment.ambient_light_energy = .3
	ambient.environment = environment
	add_child(ambient)
	build_ui()
	fit_camera()
	reset_game()

func camera_framing_version() -> int: return 2

func fit_camera() -> void:
	# Fit the room and character height to the usable area between the two HUD cards.
	var corners: Array[Vector3] = []
	for x in [-float(specification.size[0])/2, float(specification.size[0])/2]:
		for z in [-float(specification.size[1])/2, float(specification.size[1])/2]:
			for y in [0.0,2.0]: corners.append(Vector3(x,y,z))
	camera.size = 1.0
	var bounds = Rect2(camera.unproject_position(corners[0]),Vector2.ZERO)
	for corner in corners: bounds = bounds.expand(camera.unproject_position(corner))
	camera.size = maxf(bounds.size.x/900.0,bounds.size.y/352.0)*1.02
	bounds = Rect2(camera.unproject_position(corners[0]),Vector2.ZERO)
	for corner in corners: bounds = bounds.expand(camera.unproject_position(corner))
	var origin = camera.unproject_position(Vector3.ZERO)
	var pixels_per_unit = origin.distance_to(camera.unproject_position(camera.global_basis.y))
	var offset = bounds.get_center()-Vector2(480,324)
	camera.position += camera.basis.x*offset.x/pixels_per_unit-camera.basis.y*offset.y/pixels_per_unit


func label(text: String, size: int) -> Label:
	var result = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",Color("293f36"))
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func card(at: Vector2, extent: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = at
	panel.size = extent
	var style = StyleBoxFlat.new()
	style.bg_color = Color("f9f6e9")
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	return panel

func build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	var header = card(Vector2(16,12),Vector2(928,98))
	layer.add_child(header)
	var top = VBoxContainer.new()
	header.add_child(top)
	top.add_child(label(specification.title,24))
	top.add_child(label(specification.goal,16))
	progress_label = label("",15)
	top.add_child(progress_label)
	var footer = card(Vector2(16,514),Vector2(928,74))
	layer.add_child(footer)
	var bottom = VBoxContainer.new()
	footer.add_child(bottom)
	bottom.add_child(label("WASD / 方向键移动　 E 靠近互动　 R 重开　 Esc 暂停",16))
	hint_label = label("",16)
	bottom.add_child(hint_label)
	end_panel = card(Vector2(270,215),Vector2(420,145))
	layer.add_child(end_panel)
	var ending = VBoxContainer.new()
	end_panel.add_child(ending)
	ending.add_child(label("目标完成！",28))
	ending.add_child(label("所有物品已找到，顺利抵达出口。",18))
	var again = Button.new()
	again.text = "再玩一次 · R"
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func(): playseed_action("reset"))
	ending.add_child(again)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held.clear()
		if player != null: playseed_action("move",Vector2.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.pressed:
			if code == KEY_R: playseed_action("reset")
			elif code == KEY_E: playseed_action("interact")
			elif code == KEY_ESCAPE: playseed_action("pause")
		if code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_LEFT,KEY_DOWN,KEY_RIGHT]:
			held[code] = event.pressed
			var x = int(held.get(KEY_D,false) or held.get(KEY_RIGHT,false)) - int(held.get(KEY_A,false) or held.get(KEY_LEFT,false))
			var z = int(held.get(KEY_S,false) or held.get(KEY_DOWN,false)) - int(held.get(KEY_W,false) or held.get(KEY_UP,false))
			playseed_action("move",Vector2(x,z))

func reset_game() -> void:
	won = false
	paused = false
	collected.clear()
	held.clear()
	player.reset_at(Vector2(specification.spawn[0],specification.spawn[1]))
	for item in objects: item.visible = true
	message = "靠近发光物品，按 E 互动。"
	update_ui()

func can_reach(object: Node3D) -> bool:
	if Vector2(player.position.x,player.position.z).distance_to(Vector2(object.position.x,object.position.z)) > 1.25: return false
	var query = PhysicsRayQueryParameters3D.create(player.global_position+Vector3(0,.65,0),Vector3(object.position.x,.65,object.position.z),1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func playseed_action(action: String, at: Vector2 = Vector2.ZERO) -> void:
	if action == "reset": reset_game(); return
	if action == "pause" and not won:
		paused = not paused
		player.enabled = not paused
		player.direction = Vector2.ZERO
		held.clear()
		message = "已暂停，再按 Esc 继续。" if paused else "已继续，靠近物品按 E。"
	elif action == "move": player.direction = at.limit_length(1.0) if not won and not paused else Vector2.ZERO
	elif action == "interact" and not won and not paused:
		message = "再靠近一些，按 E 互动。"
		for i in range(objects.size()):
			if not i in collected and can_reach(objects[i]):
				collected.append(i)
				objects[i].visible = false
				message = "已找到「%s」。" % specification.items[i].name
				update_ui()
				return
		if can_reach(exit_object):
			if collected.size() == objects.size():
				won = true
				player.enabled = false
				player.direction = Vector2.ZERO
				message = "完成！按 R 可以重新开始。"
			else: message = "还差 %d 个物品，找到后再来。" % (objects.size()-collected.size())
	update_ui()

func update_ui() -> void:
	progress_label.text = "已找到 %d / %d　·　出口：%s" % [collected.size(),objects.size(),specification.exit.name]
	hint_label.text = message
	end_panel.visible = won

func playseed_snapshot() -> Dictionary:
	return {"won":won,"lost":false,"progress":float(collected.size())/objects.size(),"position":[player.position.x,player.position.z],"height":player.position.y,"collected":collected.duplicate(),"paused":paused}
