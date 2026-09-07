extends RefCounted

static func collect(node: Node, parent_transform: Transform3D, result: Array) -> void:
	var transform = parent_transform * node.transform if node is Node3D else parent_transform
	if node is MeshInstance3D and node.mesh != null:
		var visual = MeshInstance3D.new()
		visual.mesh = node.mesh
		visual.transform = transform
		for surface in range(node.mesh.get_surface_count()):
			var material = node.get_surface_override_material(surface)
			if material != null: visual.set_surface_override_material(surface,material)
		result.append(visual)
	for child in node.get_children(): collect(child,transform,result)

static func load_visual(id: String, extent: Vector3) -> Node3D:
	var bytes = FileAccess.get_file_as_bytes("res://models/"+id+".glb")
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	if context.finish().hex_encode() != id:
		push_error("模型快照内容不一致。")
		return null
	var document = GLTFDocument.new()
	var state = GLTFState.new()
	if document.append_from_buffer(bytes,"",state) != OK:
		push_error("GLB模型解析失败。")
		return null
	var imported = document.generate_scene(state)
	if imported == null:
		push_error("GLB没有可用的场景。")
		return null
	# Only copy mesh visuals; imported cameras, lights and arbitrary nodes never enter the game tree.
	var meshes: Array = []
	collect(imported,Transform3D.IDENTITY,meshes)
	imported.free()
	if meshes.is_empty():
		push_error("GLB没有可见网格。")
		return null
	var bounds: AABB = meshes[0].transform * meshes[0].get_aabb()
	for mesh in meshes: bounds = bounds.merge(mesh.transform * mesh.get_aabb())
	if not bounds.size.is_finite() or bounds.size.x < .0001 or bounds.size.y < .0001 or bounds.size.z < .0001:
		for mesh in meshes: mesh.free()
		push_error("模型必须有有效的立体尺寸。")
		return null
	var factor = minf(extent.x/bounds.size.x,minf(extent.y/bounds.size.y,extent.z/bounds.size.z))
	var visual = Node3D.new()
	visual.name = "模型外观"
	for mesh in meshes: visual.add_child(mesh)
	visual.scale = Vector3.ONE * factor
	visual.position = Vector3(-bounds.get_center().x*factor,-extent.y/2-bounds.position.y*factor,-bounds.get_center().z*factor)
	visual.set_meta("model_id",id)
	visual.set_meta("source_bounds",bounds)
	visual.set_meta("fit_scale",factor)
	return visual
