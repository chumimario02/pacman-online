extends Control
class_name ArcadeBg

var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Config.WIDTH, Config.HEIGHT)
	position = Vector2.ZERO
	set_process(true)

func _process(dt: float) -> void:
	time += dt
	queue_redraw()

func _draw() -> void:
	var w := float(Config.WIDTH)
	var h := float(Config.HEIGHT)
	var bands := 40
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		var top := Color(0.008, 0.012, 0.035, 1.0)
		var bottom := Color(0.055, 0.018, 0.105, 1.0)
		draw_rect(Rect2(0.0, i * h / bands, w, h / bands + 1.0), top.lerp(bottom, t))

	var glow_x := w * 0.5 + sin(time * 0.45) * 72.0
	var glow_y := h * 0.38 + cos(time * 0.65) * 18.0
	draw_circle(Vector2(glow_x, glow_y), 245.0, Color(0.18, 0.08, 0.38, 0.10))
	draw_circle(Vector2(w - glow_x * 0.35, h * 0.72), 190.0, Color(0.0, 0.28, 0.42, 0.06))

	# Cuadricula en perspectiva que ondula con el tiempo.
	var horizon := 148.0
	var center := w * 0.5
	for i in range(-15, 16):
		var t := float(i) / 15.0
		var x0 := center + t * 118.0
		var x1 := center + t * 790.0 + sin(time * 0.75 + i * 0.68) * 22.0
		var a := 0.12 + 0.08 * (1.0 - absf(t))
		draw_line(Vector2(x0, horizon), Vector2(x1, h), Color(0.18, 0.33, 0.66, a), 1.0)

	for j in range(18):
		var t2 := float(j) / 17.0
		var y := horizon + pow(t2, 1.55) * (h - horizon)
		var pts := PackedVector2Array()
		for k in range(41):
			var x := float(k) / 40.0 * w
			var wave := sin(x * 0.013 + time * 1.25 + j * 0.47) * (3.0 + j * 0.72)
			pts.append(Vector2(x, y + wave))
		draw_polyline(pts, Color(0.14, 0.42, 0.78, 0.20), 1.0)

	# Destellos tipo polvo de estrellas.
	for i in range(44):
		var sx := fmod(float(i) * 137.0 + time * (4.0 + float(i % 4)) * 2.6, w)
		var sy := fmod(float(i) * 83.0 + 17.0, h * 0.86)
		var tw := 0.18 + 0.22 * (0.5 + 0.5 * sin(time * 1.8 + i))
		draw_circle(Vector2(sx, sy), 1.0 + float(i % 2), Color(0.55, 0.78, 1.0, tw))

	# Lineas de neón superior e inferior.
	draw_line(Vector2(0.0, 6.0), Vector2(w, 6.0), Color(0.1, 0.7, 1.0, 0.20), 1.0)
	draw_line(Vector2(0.0, h - 6.0), Vector2(w, h - 6.0), Color(1.0, 0.25, 0.75, 0.16), 1.0)

	# Viñeta.
	for i in range(18):
		var a2 := 0.006 + i * 0.0027
		draw_rect(Rect2(0.0, i * 3.0, w, 3.0), Color(0, 0, 0, a2))
		draw_rect(Rect2(0.0, h - (i + 1) * 3.0, w, 3.0), Color(0, 0, 0, a2))
