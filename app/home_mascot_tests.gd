extends SceneTree
func _initialize(): call_deferred("run_tests")
func run_tests():
	root.size=Vector2i(760,240)
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var mascot=load("res://home_mascot.gd").new();root.add_child(mascot)
	await process_frame
	mascot.say("先写一句你的游戏想法，几个字也可以。",Rect2(0,0,740,200))
	mascot.set_process(false);mascot._age=.6;mascot.modulate.a=1;mascot.queue_redraw()
	await process_frame;RenderingServer.force_draw()
	var img=root.get_texture().get_image();var dark_pixels=0
	for y in range(int(mascot.position.y),int(mascot.position.y+mascot.size.y)):
		for x in range(int(mascot.position.x),int(mascot.position.x+58)):
			var c=img.get_pixel(x,y)
			if c.a>.5 and c.get_luminance()<.18: dark_pixels+=1
	var folder=ProjectSettings.globalize_path("res://../.playseed/qa/home-mascot")
	DirAccess.make_dir_recursive_absolute(folder);img.save_png(folder.path_join("hint.png"))
	print("MASCOT_PIXELS: ",dark_pixels)
	if dark_pixels<70: print("MASCOT_TEST_FAILED: 圆圈内未出现吉祥物黑色面罩")
	else: print("MASCOT_TEST_PASSED")
	quit(1 if dark_pixels<70 else 0)
