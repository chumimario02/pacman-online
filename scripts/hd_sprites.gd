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

static func _tint_cell(sheet: Image, x: int, y: int, w: int, h: int, tint: Color) -> ImageTexture:
	var region := sheet.get_region(Rect2i(x, y, w, h))
	var out_size := 36
	var scale := minf(float(out_size) / float(w), float(out_size) / float(h))
	var nw := maxi(1, int(round(w * scale)))
	var nh := maxi(1, int(round(h * scale)))
	region.resize(nw, nh, Image.INTERPOLATE_BILINEAR)
	for yy in range(region.get_height()):
		for xx in range(region.get_width()):
			var c := region.get_pixel(xx, yy)
			if c.a < 0.05:
				continue
			if c.r > 0.85 and c.g > 0.85 and c.b > 0.85:
				continue
			region.set_pixel(xx, yy, Color(tint.r, tint.g, tint.b, c.a))
	var out := Image.create(out_size, out_size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(region, Rect2i(0, 0, nw, nh), Vector2i((out_size - nw) / 2, (out_size - nh) / 2))
	return ImageTexture.create_from_image(out)

static func _sheet_cell_trim(sheet: Image, x: int, y: int, w: int, h: int) -> ImageTexture:
	var region := sheet.get_region(Rect2i(x, y, w, h))
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for yy in range(h):
		for xx in range(w):
			if region.get_pixel(xx, yy).a > 0.05:
				minx = mini(minx, xx)
				miny = mini(miny, yy)
				maxx = maxi(maxx, xx)
				maxy = maxi(maxy, yy)
	if maxx < minx or maxy < miny:
		return _sheet_cell(sheet, x, y, w, h)
	var cw := maxx - minx + 1
	var ch := maxy - miny + 1
	var crop := region.get_region(Rect2i(minx, miny, cw, ch))
	var scale := minf(32.0 / float(cw), 32.0 / float(ch))
	var nw := maxi(1, int(round(cw * scale)))
	var nh := maxi(1, int(round(ch * scale)))
	crop.resize(nw, nh, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(crop, Rect2i(0, 0, nw, nh), Vector2i((32 - nw) / 2, (32 - nh) / 2))
	return ImageTexture.create_from_image(out)

static func _sheet_cell(sheet: Image, x: int, y: int, w: int, h: int) -> ImageTexture:
	var region := sheet.get_region(Rect2i(x, y, w, h))
	var out_size := 36
	var scale := minf(float(out_size) / float(w), float(out_size) / float(h))
	var nw := maxi(1, int(round(w * scale)))
	var nh := maxi(1, int(round(h * scale)))
	region.resize(nw, nh, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(out_size, out_size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(region, Rect2i(0, 0, nw, nh), Vector2i((out_size - nw) / 2, (out_size - nh) / 2))
	return ImageTexture.create_from_image(out)

static func _sheet() -> Image:
	var tex: Texture2D = load("res://assets/hd/cedx.png")
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	return img.duplicate()

static func build_pac_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("chomp")
	var sheet := _sheet()
	if sheet != null:
		for y in [2, 52, 102, 152, 202, 252, 202, 152, 102, 52]:
			sf.add_frame("chomp", _sheet_cell(sheet, 854, y, 50, 50))
	sf.set_animation_loop("chomp", true)
	sf.set_animation_speed("chomp", 18.0)
	return sf

static func build_ghost_frames(ghost_name: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var sheet := _sheet()
	var gx := 3
	match ghost_name:
		"pinky": gx = 53
		"inky": gx = 103
		"clyde": gx = 153
	for anim in ["right", "left", "up", "down"]:
		sf.add_animation(anim)
		if sheet != null:
			for y in [4, 54, 104, 154]:
				sf.add_frame(anim, _sheet_cell(sheet, gx, y, 50, 50))
		sf.set_animation_loop(anim, true)
		sf.set_animation_speed(anim, 10.0)
	sf.add_animation("fright")
	if sheet != null:
		for y in [504, 554, 604, 654]:
			sf.add_frame("fright", _sheet_cell(sheet, 3, y, 50, 50))
	sf.set_animation_loop("fright", true)
	sf.set_animation_speed("fright", 10.0)
	sf.add_animation("flash")
	if sheet != null:
		for y in [504, 554, 604, 654]:
			sf.add_frame("flash", _tint_cell(sheet, 3, y, 50, 50, Color(1, 1, 1, 1)))
	sf.set_animation_loop("flash", true)
	sf.set_animation_speed("flash", 10.0)
	for dir_name in ["left", "down", "right", "up"]:
		var anim_name: String = "eyes_" + dir_name
		sf.add_animation(anim_name)
		if sheet != null:
			sf.add_frame(anim_name, _sheet_cell(sheet, 854, 2, 50, 50))
		sf.set_animation_loop(anim_name, false)
		sf.set_animation_speed(anim_name, 1.0)
	return sf
