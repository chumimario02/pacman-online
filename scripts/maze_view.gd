extends Node2D
class_name MazeView

var game
var maze
var maze_texture: Texture2D
var maze_remake_texture: Texture2D
var power_texture: Texture2D
var power_glow_texture: Texture2D
var hide_frame := false

func _ready() -> void:
	maze_texture = load("res://assets/maze_bg.png")
	maze_remake_texture = load("res://assets/maze_remake.png")
	power_texture = load("res://assets/power.png")
	power_glow_texture = load("res://assets/power_glow.png")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or maze == null:
		return
	if maze_texture:
		if game != null and game.maze_mode == "remake" and maze_remake_texture:
			# El mapa nuevo se dibuja 1:1 desde su recuadro real (880x544).
			draw_texture_rect_region(maze_remake_texture,
				Rect2(0, 0, Config.REMAKE_W, Config.REMAKE_H),
				Rect2(80, 88, Config.REMAKE_W, Config.REMAKE_H))
		else:
			draw_texture(maze_texture, Vector2.ZERO)

	for tile in maze.pellets.keys():
		var p: Vector2 = maze.center(tile)
		var value: int = maze.pellets[tile]
		var remake: bool = game != null and game.maze_mode == "remake"
		if value >= 50:
			if power_glow_texture:
				var a := 0.18 + 0.12 * (0.5 + 0.5 * sin(game.time * 5.0))
				var gs := 24.0 if remake else 44.0
				draw_texture_rect(power_glow_texture, Rect2(p - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(1, 1, 1, a))
				draw_texture_rect(power_glow_texture, Rect2(p - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(1, 1, 1, a * 0.7))
			if power_texture:
				var ps := 10.0 if remake else 16.0
				draw_texture_rect(power_texture, Rect2(p - Vector2(ps, ps) * 0.5, Vector2(ps, ps)), false)
		else:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Config.SALMON)

	if not hide_frame and (game == null or game.maze_mode != "remake"):
		var frame := Rect2(-9, -9, Config.MAZE_W + 18, Config.MAZE_H + 18)
		draw_rect(frame, Color(0.0706, 0.1098, 0.1882, 1.0), false, 1.0)
		_brackets(Rect2(frame.position + Vector2(2, 2), frame.size - Vector2(4, 4)),
			Color(0.0, 0.4706, 0.6275, 1.0), 16.0, 1.0)

func _brackets(rect: Rect2, color: Color, length: float, width: float) -> void:
	var corners := [
		[rect.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(rect.end.x - 1, rect.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(rect.position.x, rect.end.y - 1), Vector2(1, 0), Vector2(0, -1)],
		[Vector2(rect.end.x - 1, rect.end.y - 1), Vector2(-1, 0), Vector2(0, -1)],
	]
	for c in corners:
		draw_line(c[0], c[0] + c[1] * length, color, width)
		draw_line(c[0], c[0] + c[2] * length, color, width)
