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

static func build_pac_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("chomp")
	var tex := _asset("res://assets/hd/pac.png")
	if tex != null:
		sf.add_frame("chomp", tex)
	sf.set_animation_loop("chomp", true)
	sf.set_animation_speed("chomp", 12.0)
	return sf

static func _ghost_body(img: Image, color: Color, frame: int) -> void:
	for y in range(64):
		for x in range(64):
			var dx := float(x) - 32.0
			var dy := float(y) - 26.0
			var inside := false
			# Dome (same size as Pac-Man)
			if y <= 34 and (dx * dx + dy * dy <= 28.0 * 28.0):
				inside = true
			# Body
			elif y > 24 and y <= 48 and abs(dx) <= 28.0:
				inside = true
			# Triangular skirt (bigger legs)
			elif y > 44 and y <= 62 and abs(dx) <= 28.0:
				var tri := fmod(float(x) + frame * 6.0, 10.0)
				if tri > 5.0:
					tri = 10.0 - tri
				var maxy := 44.0 + tri * 2.2
				if float(y) <= maxy:
					inside = true
			if inside:
				img.set_pixel(x, y, color)

static func _ghost_eyes(img: Image, dir_name: String, frightened: bool, flash: bool) -> void:
	var eye_color := Color(1, 1, 1, 1)
	var pupil_color := Color(0.0, 0.2, 0.9, 1)
	if frightened:
		eye_color = Color(1, 1, 1, 1)
		pupil_color = Color(1, 1, 1, 1)
	if flash:
		eye_color = Color(1, 1, 1, 1)
		pupil_color = Color(1, 1, 1, 1)
	var px := 0.0
	var py := 0.0
	match dir_name:
		"right": px = 4.0
		"left": px = -4.0
		"up": py = -4.0
		"down": py = 4.0
	# left eye
	_circle(img, 20.0, 24.0, 9.0, eye_color)
	_circle(img, 20.0 + px, 24.0 + py, 4.0, pupil_color)
	# right eye
	_circle(img, 44.0, 24.0, 9.0, eye_color)
	_circle(img, 44.0 + px, 24.0 + py, 4.0, pupil_color)

static func _ghost_zigzag(img: Image, color: Color, y0: int) -> void:
	for i in range(8):
		var x0 := 14 + i * 5
		var x1 := x0 + 3
		var y1 := y0 - 4 if i % 2 == 0 else y0 + 4
		# draw small line segments
		for t in range(0, 4):
			var x := x0 + t
			var y := y0 + int((float(t) / 3.0) * (y1 - y0))
			if x >= 0 and x < 64 and y >= 0 and y < 64:
				img.set_pixel(x, y, color)
				if y + 1 < 64:
					img.set_pixel(x, y + 1, color)
static func _tint_asset(path: String, tint: Color, flash := false) -> ImageTexture:
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img = img.duplicate()
	img.resize(32, 32, Image.INTERPOLATE_BILINEAR)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			if c.r > 0.85 and c.g > 0.85 and c.b > 0.85:
				continue  # keep white eyes
			if flash:
				img.set_pixel(x, y, Color(1, 1, 1, c.a))
			else:
				img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, c.a))
	return ImageTexture.create_from_image(img)

static func build_ghost_frames(ghost_name: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var idx := 1
	match ghost_name:
		"pinky": idx = 2
		"inky": idx = 3
		"clyde": idx = 4
	var a := _asset("res://assets/hd/ghost%d.png" % idx)
	var b := _asset("res://assets/hd/ghost%db.png" % idx)
	for anim in ["right", "left", "up", "down"]:
		sf.add_animation(anim)
		if a != null:
			sf.add_frame(anim, a)
		if b != null:
			sf.add_frame(anim, b)
		sf.set_animation_loop(anim, true)
		sf.set_animation_speed(anim, 8.0)
	# frightened: blue body, keep white eyes
	sf.add_animation("fright")
	var fb := _tint_asset("res://assets/hd/ghost%d.png" % idx, Color(0.15, 0.25, 1.0, 1.0))
	var fbb := _tint_asset("res://assets/hd/ghost%db.png" % idx, Color(0.15, 0.25, 1.0, 1.0))
	if fb != null:
		sf.add_frame("fright", fb)
	if fbb != null:
		sf.add_frame("fright", fbb)
	sf.set_animation_loop("fright", true)
	sf.set_animation_speed("fright", 8.0)
	# flash: alternate white/blue
	sf.add_animation("flash")
	var wb := _tint_asset("res://assets/hd/ghost%d.png" % idx, Color(1, 1, 1, 1), true)
	var wbb := _tint_asset("res://assets/hd/ghost%db.png" % idx, Color(1, 1, 1, 1), true)
	if wb != null:
		sf.add_frame("flash", wb)
	if fb != null:
		sf.add_frame("flash", fb)
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
