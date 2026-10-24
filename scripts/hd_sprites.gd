extends RefCounted
class_name HDSprites

static func _img(w := 64, h := 64) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

static func _circle(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, color)

static func _rect(img: Image, x0: int, y0: int, w: int, h: int, color: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)

static func _pac_dir_angle(dir_name: String) -> float:
	match dir_name:
		"right": return 0.0
		"left": return PI
		"up": return -PI * 0.5
		"down": return PI * 0.5
	return 0.0

static func _tex(img: Image) -> ImageTexture:
	var out := img.duplicate()
	out.resize(32, 32, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(out)

static func _asset(path: String) -> ImageTexture:
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img = img.duplicate()
	img.resize(32, 32, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)

static func _sheet_cell(sheet: Image, x: int, y: int, w: int, h: int) -> ImageTexture:
	var region := sheet.get_region(Rect2i(x, y, w, h))
	var scale := minf(32.0 / float(w), 32.0 / float(h))
	var nw := maxi(1, int(round(w * scale)))
	var nh := maxi(1, int(round(h * scale)))
	region.resize(nw, nh, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(region, Rect2i(0, 0, nw, nh), Vector2i((32 - nw) / 2, (32 - nh) / 2))
	return ImageTexture.create_from_image(out)

static func _sheet() -> Image:
	var tex: Texture2D = load("res://assets/hd/pac-classic.png")
	if tex == null:
		return null
	return tex.get_image()

static func build_pac_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("chomp")
	var sheet := _sheet()
	if sheet != null:
		sf.add_frame("chomp", _sheet_cell(sheet, 552, 2, 135, 157))
		sf.add_frame("chomp", _sheet_cell(sheet, 552, 173, 135, 157))
	sf.set_animation_loop("chomp", true)
	sf.set_animation_speed("chomp", 10.0)
	return sf

static func build_ghost_frames(ghost_name: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var sheet := _sheet()
	var y := 2
	match ghost_name:
		"pinky": y = 173
		"inky": y = 336
		"clyde": y = 507
	var xs := [1, 134, 278, 414]
	var ws := [105, 106, 106, 106]
	for anim in ["right", "left", "up", "down"]:
		sf.add_animation(anim)
		if sheet != null:
			for i in range(4):
				sf.add_frame(anim, _sheet_cell(sheet, xs[i], y, ws[i], 158))
		sf.set_animation_loop(anim, true)
		sf.set_animation_speed(anim, 8.0)
	# frightened uses the dark blue row
	sf.add_animation("fright")
	if sheet != null:
		for i in range(4):
			sf.add_frame("fright", _sheet_cell(sheet, xs[i], 856, ws[i], 158))
	sf.set_animation_loop("fright", true)
	sf.set_animation_speed("fright", 8.0)
	# flash uses the white/grey row
	sf.add_animation("flash")
	if sheet != null:
		for i in range(4):
			sf.add_frame("flash", _sheet_cell(sheet, xs[i], 682, ws[i], 158))
	sf.set_animation_loop("flash", true)
	sf.set_animation_speed("flash", 8.0)
	# eyes-only frames for eaten state
	for dir_name in ["left", "down", "right", "up"]:
		var anim_name: String = "eyes_" + dir_name
		sf.add_animation(anim_name)
		var img := _img()
		var px := 0.0
		var py := 0.0
		match dir_name:
			"right": px = 4.0
			"left": px = -4.0
			"up": py = -4.0
			"down": py = 4.0
		_circle(img, 20.0, 24.0, 6.0, Color(1, 1, 1, 1))
		_circle(img, 20.0 + px, 24.0 + py, 2.0, Color(0.0, 0.2, 0.9, 1))
		_circle(img, 44.0, 24.0, 6.0, Color(1, 1, 1, 1))
		_circle(img, 44.0 + px, 24.0 + py, 2.0, Color(0.0, 0.2, 0.9, 1))
		sf.add_frame(anim_name, _tex(img))
		sf.set_animation_loop(anim_name, false)
		sf.set_animation_speed(anim_name, 1.0)
	return sf
