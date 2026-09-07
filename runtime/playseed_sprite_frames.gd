extends RefCounted
# Shared by the creator preview and the trusted runtime.
static func visible_bottom(frame: Image) -> int:
	# Ignore faint residual pixels for positioning, but retain them in the output.
	for y in range(frame.get_height()-1, -1, -1):
		for x in range(frame.get_width()):
			if frame.get_pixel(x, y).a >= 0.5: return y + 1
	return frame.get_used_rect().end.y

static func build(texture: Texture2D, config: Dictionary) -> SpriteFrames:
	if texture == null: return null
	var columns := int(config.get("columns", 0))
	var rows := int(config.get("rows", 0))
	var first := int(config.get("first_frame", -1))
	var count := int(config.get("frame_count", 0))
	var fps := int(config.get("fps", 0))
	if columns < 1 or columns > 16 or rows < 1 or rows > 16 or first < 0 or count < 2 or count > 128 or first + count > columns * rows or fps < 1 or fps > 30: return null
	if texture.get_width() % columns != 0 or texture.get_height() % rows != 0: return null
	var cell := Vector2i(texture.get_width() / columns, texture.get_height() / rows)
	if cell.x < 4 or cell.y < 4: return null
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", bool(config.get("loop", true)))
	var aligned: Array[Image] = []
	var bottoms: Array[int] = []
	var baseline := 0
	if bool(config.get("align_bottom", false)):
		var sheet := texture.get_image()
		if sheet == null: return null
		for index in range(first, first + count):
			var frame_image := sheet.get_region(Rect2i(Vector2i((index % columns) * cell.x, (index / columns) * cell.y), cell))
			frame_image.convert(Image.FORMAT_RGBA8)
			var bottom := visible_bottom(frame_image)
			aligned.append(frame_image)
			bottoms.append(bottom)
			baseline = maxi(baseline, bottom)
	for index in range(first, first + count):
		if not aligned.is_empty():
			var output := Image.create(cell.x, cell.y + baseline - bottoms.min(), false, Image.FORMAT_RGBA8)
			output.fill(Color.TRANSPARENT)
			output.blit_rect(aligned[index-first], Rect2i(Vector2i.ZERO, cell), Vector2i(0, baseline-bottoms[index-first]))
			frames.add_frame("default", ImageTexture.create_from_image(output))
			continue
		var part := AtlasTexture.new()
		part.atlas = texture
		part.region = Rect2(Vector2((index % columns) * cell.x, (index / columns) * cell.y), Vector2(cell))
		part.filter_clip = true
		frames.add_frame("default", part)
	return frames
