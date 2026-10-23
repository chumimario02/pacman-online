extends Node2D
class_name Effects

var game
var font: Font

func _ready() -> void:
	font = load("res://assets/PressStart2P-Regular.ttf")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	for p in game.particles:
		var k: float = maxf(0.0, float(p["life"]) / float(p["max"]))
		var c: Color = p["color"]
		var col := Color(c.r * (0.25 + 0.75 * k), c.g * (0.25 + 0.75 * k),
			c.b * (0.25 + 0.75 * k), 1.0)
		var pos := Vector2(p["x"], p["y"])
		var s: int = p["size"]
		if s <= 2:
			draw_rect(Rect2(pos, Vector2(s, s)), col)
		else:
			draw_circle(pos, s / 2.0 + 1.0, col)
	if font == null:
		return
	for p in game.popups:
		var alpha: float = clampf(float(p["life"]), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var c2: Color = p["color"]
		var col2 := Color(c2.r, c2.g, c2.b, alpha)
		var size: int = p["size"]
		var text: String = p["text"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var h := font.get_height(size)
		var baseline := Vector2(float(p["x"]) - w * 0.5,
			float(p["y"]) - h * 0.5 + font.get_ascent(size))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col2)
