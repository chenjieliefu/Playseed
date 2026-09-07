extends SceneTree
func _initialize(): call_deferred("check")
func check():
	var builder = load(ProjectSettings.globalize_path("res://../runtime/playseed_sprite_frames.gd"))
	var image = Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(8,0,8,8),Color.RED)
	image.fill_rect(Rect2i(0,8,8,8),Color.GREEN)
	image.fill_rect(Rect2i(8,8,8,8),Color.BLUE)
	var config = {"columns":2,"rows":2,"first_frame":1,"frame_count":3,"fps":12,"loop":false}
	var frames = builder.build(ImageTexture.create_from_image(image),config)
	assert(frames != null and frames.get_frame_count("default") == 3)
	assert(frames.get_frame_texture("default",0).region == Rect2(8,0,8,8))
	assert(frames.get_frame_texture("default",1).region == Rect2(0,8,8,8))
	assert(frames.get_frame_texture("default",2).region == Rect2(8,8,8,8))
	assert(not frames.get_animation_loop("default"))
	var actor = AnimatedSprite2D.new()
	actor.sprite_frames = frames
	root.add_child(actor)
	actor.play("default")
	await create_timer(0.4).timeout
	assert(actor.frame == 2 and not actor.is_playing())
	actor.stop(); actor.frame = 0; actor.frame_progress = 0
	assert(actor.frame == 0 and actor.frame_progress == 0)
	actor.play("default")
	await create_timer(0.12).timeout
	actor.pause()
	var paused = actor.frame
	await create_timer(0.15).timeout
	assert(actor.frame == paused)
	config.columns = 3
	assert(builder.build(ImageTexture.create_from_image(image),config) == null)
	var sheet := Image.create(32,16,false,Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	sheet.fill_rect(Rect2i(3,2,5,5), Color.WHITE)
	sheet.set_pixel(4,15,Color(1,1,1,0.02))
	sheet.set_pixel(4,1,Color(1,1,1,0.05))
	sheet.fill_rect(Rect2i(19,7,5,5), Color.GREEN)
	var aligned = builder.build(ImageTexture.create_from_image(sheet), {"columns":2,"rows":1,"first_frame":0,"frame_count":2,"fps":8,"loop":true,"align_bottom":true})
	var a: Image = aligned.get_frame_texture("default",0).get_image()
	var b: Image = aligned.get_frame_texture("default",1).get_image()
	assert(builder.visible_bottom(a) == 12 and builder.visible_bottom(b) == 12)
	assert(a.get_height() == 21 and b.get_height() == 21)
	assert(a.get_pixel(4,20).a > 0.01)
	assert(a.get_pixel(3,7).is_equal_approx(Color.WHITE))
	assert(a.get_pixel(4,6).a > 0.04 and a.get_pixel(4,6).a < 0.06)
	assert(b.get_pixel(3,7).is_equal_approx(Color.GREEN))
	assert(sheet.get_pixel(3,2).is_equal_approx(Color.WHITE))
	var original_mass := 0.0
	var aligned_mass := 0.0
	for y in range(16):
		for x in range(32): original_mass += sheet.get_pixel(x,y).a
	for y in range(a.get_height()):
		for x in range(16): aligned_mass += a.get_pixel(x,y).a + b.get_pixel(x,y).a
	assert(absf(original_mass-aligned_mass) < 0.001)
	actor.queue_free()
	await process_frame
	print("SPRITE_FRAMES_OK: grid order, non-loop finish, pause, reset, optional baseline alignment and alpha preservation")
	quit()
