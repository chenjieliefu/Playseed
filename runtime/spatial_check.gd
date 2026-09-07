extends SceneTree

var game
var spec: Dictionary
var tested_collisions := 0
var frames := 0

func _initialize() -> void: call_deferred("run_checks")

func tick(count := 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
		frames += 1

func key(code: int, down := true) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func press(code: int) -> void:
	key(code)
	await tick(2)
	key(code,false)
	await tick()

func free_point(p: Vector2) -> bool:
	if absf(p.x) > float(spec.size[0])/2-.5 or absf(p.y) > float(spec.size[1])/2-.5: return false
	for obstacle in spec.obstacles:
		if absf(p.x-obstacle.position[0]) <= float(obstacle.size[0])/2+.5 and absf(p.y-obstacle.position[1]) <= float(obstacle.size[2])/2+.5: return false
	return true

func position2() -> Vector2:
	return Vector2(game.player.position.x,game.player.position.z)

func path_to(target: Vector2, required := true):
	var start = (position2()*2).round()/2
	var queue: Array = [start]
	var previous: Dictionary = {start: start}
	var cursor := 0
	while cursor < queue.size():
		var point: Vector2 = queue[cursor]
		cursor += 1
		if point == target: break
		for offset in [Vector2(.5,0),Vector2(-.5,0),Vector2(0,.5),Vector2(0,-.5)]:
			var next_point: Vector2 = point + offset
			if not previous.has(next_point) and free_point(next_point):
				previous[next_point] = point
				queue.append(next_point)
	if not previous.has(target):
		assert(not required,"无法规划可达路径")
		return null
	var result: Array = []
	var at = target
	while at != start:
		result.push_front(at)
		at = previous[at]
	return result

func walk(target: Vector2) -> void:
	for waypoint in path_to(target):
		var guard := 0
		while position2().distance_to(waypoint) > .12 and guard < 90:
			guard += 1
			var offset: Vector2 = waypoint-position2()
			var code = (KEY_D if offset.x > 0 else KEY_A) if absf(offset.x)>absf(offset.y) else (KEY_S if offset.y>0 else KEY_W)
			key(code)
			await tick()
			key(code,false)
		assert(position2().distance_to(waypoint) <= .15,"真实角色未能沿路径到达，可能有碰撞阻断")
	await tick(2)

func run_checks() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await tick(5)
	assert(game is Node3D and game.player is CharacterBody3D and game.camera is Camera3D)
	spec = game.specification
	if game.has_method("fit_camera"):
		for x in [-float(spec.size[0])/2,float(spec.size[0])/2]:
			for z in [-float(spec.size[1])/2,float(spec.size[1])/2]:
				for y in [0.0,2.0]:
					var screen = game.camera.unproject_position(Vector3(x,y,z))
					assert(screen.y>=147 and screen.y<=501 and screen.x>=29 and screen.x<=931,"3D物体进入HUD或画面边界")
	if game.has_method("fit_camera") and game.has_method("camera_framing_version"):
		var original_size: float = game.camera.size
		var original_position: Vector3 = game.camera.position
		game.fit_camera()
		assert(absf(original_size-game.camera.size)<.01 and original_position.distance_to(game.camera.position)<.01,"重复取景改变了相机")
		var bounds = Rect2(game.camera.unproject_position(Vector3(-float(spec.size[0])/2,0,-float(spec.size[1])/2)),Vector2.ZERO)
		for x in [-float(spec.size[0])/2,float(spec.size[0])/2]:
			for z in [-float(spec.size[1])/2,float(spec.size[1])/2]:
				for y in [0.0,2.0]: bounds = bounds.expand(game.camera.unproject_position(Vector3(x,y,z)))
		assert(bounds.size.x>=870 or bounds.size.y>=340,"相机没有充分使用可玩区域")
		assert(bounds.get_center().distance_to(Vector2(480,324))<2,"房间未居中于可玩区域")
	var initial_nodes: int = game.get_child_count()
	if game.get("model_instances") != null:
		var expected := 0
		for obstacle in spec.obstacles:
			if not str(obstacle.get("model_id","")).is_empty(): expected += 1
		assert(game.model_instances.size()==expected,"模型引用没有全部入场")
		for visual in game.model_instances:
			assert(visual.get_child_count()>0,"模型没有网格")
			assert(is_equal_approx(visual.scale.x,visual.scale.y) and is_equal_approx(visual.scale.y,visual.scale.z),"模型被拉伸")
			var body = visual.get_parent()
			var extent: Vector3 = body.get_child(1).shape.size
			var bounds: AABB = visual.transform * visual.get_child(0).transform * visual.get_child(0).get_aabb()
			for mesh in visual.get_children(): bounds = bounds.merge(visual.transform * mesh.transform * mesh.get_aabb())
			assert(bounds.position.x>=-extent.x/2-.001 and bounds.end.x<=extent.x/2+.001 and bounds.position.z>=-extent.z/2-.001 and bounds.end.z<=extent.z/2+.001,"模型超出碰撞底座")
			assert(absf(bounds.position.y+extent.y/2)<.001 and bounds.end.y<=extent.y/2+.001,"模型没有贴地或超高")
			assert(not body.get_child(0).visible,"替换模型后仍显示占位方块")
	var spawn = Vector2(spec.spawn[0],spec.spawn[1])
	assert(not game.won and game.collected.is_empty())
	await press(KEY_E)
	assert(game.collected.is_empty() and not game.won,"远距离交互生效")
	await press(KEY_ESCAPE)
	key(KEY_D)
	await tick(15)
	key(KEY_D,false)
	assert(position2().distance_to(spawn)<.1,"暂停时仍移动")
	await press(KEY_ESCAPE)
	# Boundaries must physically stop movement, even under sustained input.
	var boundary_checked := false
	var left = -floorf((float(spec.size[0])/2-.5)*2)/2
	for zi in range(int(-float(spec.size[1])+1),int(float(spec.size[1]))):
		var point = Vector2(left,zi*.5)
		if not free_point(point) or path_to(point,false) == null: continue
		await walk(point)
		key(KEY_A)
		await tick(100)
		key(KEY_A,false)
		assert(absf(game.player.position.x-(-float(spec.size[0])/2+.32))<.07,"外墙碰撞没有阻止越界")
		boundary_checked = true
		await press(KEY_R)
		break
	assert(boundary_checked,"没有验证可达的外墙")
	# The exit remains locked until the real items have been collected.
	await walk(Vector2(spec.exit.position[0],spec.exit.position[1]))
	await press(KEY_E)
	assert(not game.won,"未收集就完成目标")
	await press(KEY_R)
	assert(position2().distance_to(spawn)<.1)
	# Walk into each obstacle's reachable face; collision must stop the body.
	for obstacle in spec.obstacles:
		var center = Vector2(obstacle.position[0],obstacle.position[1])
		for direction in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:
			var half_size: float = float(obstacle.size[0] if direction.x != 0 else obstacle.size[2])/2
			var point = center + direction*(ceilf((half_size+.6)*2)/2)
			if not free_point(point) or path_to(point,false) == null: continue
			await walk(point)
			var code = (KEY_D if direction.x<0 else KEY_A) if direction.x!=0 else (KEY_S if direction.y<0 else KEY_W)
			key(code)
			await tick(80)
			key(code,false)
			var delta = position2()-center
			assert(delta.dot(direction)>=half_size+.29,"角色穿入障碍")
			tested_collisions += 1
			await press(KEY_R)
			break
	for i in range(game.objects.size()):
		var data = spec.items[i]
		await walk(Vector2(data.position[0],data.position[1]))
		var before: int = game.collected.size()
		await press(KEY_E)
		assert(game.collected.size()==before+1 and not game.objects[i].visible,"交互没有改变真实物品")
		await press(KEY_E)
		assert(game.collected.size()==before+1,"重复收集")
	await walk(Vector2(spec.exit.position[0],spec.exit.position[1]))
	await press(KEY_E)
	assert(game.won and game.end_panel.visible,"不能通关")
	var ending = position2()
	key(KEY_A)
	await tick(20)
	key(KEY_A,false)
	assert(position2().distance_to(ending)<.1,"结算后仍可走动")
	for i in range(20):
		await press(KEY_R)
		assert(not game.won and game.collected.is_empty() and position2().distance_to(spawn)<.1)
		assert(game.get_child_count()==initial_nodes,"重开重复创建节点")
	assert(absf(game.player.position.y)<.1,"没有站在实际地面上")
	print("SPATIAL_CHECK_OK:", JSON.stringify({"frames":frames,"wall_tested":boundary_checked,"obstacles_tested":tested_collisions,"items":game.objects.size(),"resets":20}))
	quit()
