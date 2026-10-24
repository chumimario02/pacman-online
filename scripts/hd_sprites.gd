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

static func build_pac_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("chomp")
	var mouths := [0.75, 0.45, 0.12, 0.45]
	for frame in range(mouths.size()):
		var img := _img()
		var mouth: float = mouths[frame]
		var da := 0.0  # right-facing; sprite rotates via game code
		for y in range(64):
			for x in range(64):
				var dx := float(x) - 32.0
				var dy := float(y) - 32.0
				var rr := dx * dx + dy * dy
				if rr > 28.0 * 28.0:
					continue
				var ang := atan2(dy, dx) - da
				while ang > PI:
					ang -= TAU
				while ang < -PI:
					ang += TAU
				if abs(ang) > mouth:
					img.set_pixel(x, y, Color(1.0, 0.9, 0.0, 1.0))
		sf.add_frame("chomp", _tex(img))
	sf.set_animation_loop("chomp", true)
	sf.set_animation_speed("chomp", 18.0)
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
			elif y > 24 and y <= 44 and abs(dx) <= 28.0:
				inside = true
			# Triangular skirt
			elif y > 44 and y <= 56 and abs(dx) <= 28.0:
				var tri := fmod(float(x) + frame * 5.0, 12.0)
				if tri > 6.0:
					tri = 12.0 - tri
				var maxy := 44.0 + tri
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
static func build_ghost_frames(ghost_name: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var base_color := Color(1, 0.2, 0.2, 1)
	match ghost_name:
		"pinky": base_color = Color(1.0, 0.6, 0.85, 1)
		"inky": base_color = Color(0.0, 0.9, 0.9, 1)
		"clyde": base_color = Color(1.0, 0.6, 0.2, 1)
	for anim in ["right", "left", "up", "down"]:
		sf.add_animation(anim)
		for frame in range(2):
			var img := _img()
			_ghost_body(img, base_color, frame)
			_ghost_eyes(img, anim, false, false)
			sf.add_frame(anim, _tex(img))
		sf.set_animation_loop(anim, true)
		sf.set_animation_speed(anim, 8.0)
	# frightened
	sf.add_animation("fright")
	for frame in range(2):
		var img := _img()
		_ghost_body(img, Color(0.1, 0.2, 0.9, 1), frame)
		# scared eyes
		_circle(img, 20.0, 24.0, 7.0, Color(1, 1, 1, 1))
		_circle(img, 44.0, 24.0, 7.0, Color(1, 1, 1, 1))
		# small pupils
		_circle(img, 20.0, 24.0, 3.0, Color(0.8, 0.0, 0.0, 1))
		_circle(img, 44.0, 24.0, 3.0, Color(0.8, 0.0, 0.0, 1))
		# zigzag mouth
		_ghost_zigzag(img, Color(1, 1, 1, 1), 38)
		sf.add_frame("fright", _tex(img))
	sf.set_animation_loop("fright", true)
	sf.set_animation_speed("fright", 8.0)
	# flash
	sf.add_animation("flash")
	for frame in range(2):
		var img := _img()
		var col := Color(1, 1, 1, 1) if frame == 0 else Color(0.1, 0.2, 0.9, 1)
		var eye_col := Color(0.1, 0.2, 0.9, 1) if frame == 0 else Color(1, 1, 1, 1)
		var mouth_col := Color(0.1, 0.2, 0.9, 1) if frame == 0 else Color(1, 1, 1, 1)
		_ghost_body(img, col, frame)
		_circle(img, 20.0, 24.0, 7.0, eye_col)
		_circle(img, 44.0, 24.0, 7.0, eye_col)
		_circle(img, 20.0, 24.0, 3.0, mouth_col)
		_circle(img, 44.0, 24.0, 3.0, mouth_col)
		_ghost_zigzag(img, mouth_col, 38)
		sf.add_frame("flash", _tex(img))
	sf.set_animation_loop("flash", true)
	sf.set_animation_speed("flash", 8.0)
	# eyes
	for dir_name in ["left", "down", "right", "up"]:
		var anim_name: String = "eyes_" + dir_name
		sf.add_animation(anim_name)
		var img := _img()
		# transparent body, just eyes
		var px := 0.0
		var py := 0.0
		match dir_name:
			"right": px = 4.0
			"left": px = -4.0
			"up": py = -4.0
			"down": py = 4.0
		_circle(img, 20.0, 24.0, 6.0, Color(1, 1, 1, 1))
		_circle(img, 22.0 + px, 24.0 + py, 2.0, Color(0.0, 0.2, 0.9, 1))
		_circle(img, 44.0, 24.0, 6.0, Color(1, 1, 1, 1))
		_circle(img, 42.0 + px, 24.0 + py, 2.0, Color(0.0, 0.2, 0.9, 1))
		sf.add_frame(anim_name, _tex(img))
		sf.set_animation_loop(anim_name, false)
		sf.set_animation_speed(anim_name, 1.0)
	return sf


