extends SceneTree
# Trusted inspector: reads one image snapshot, never runs generated game code.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var image := Image.load_from_file(args[0])
	if image == null or image.is_empty():
		quit(1)
		return
	print("PLAYSEED_IMAGE:" + JSON.stringify({"has_transparent_pixels": image.detect_alpha() != Image.ALPHA_NONE, "has_visible_pixels": image.get_used_rect().has_area()}))
	quit()
