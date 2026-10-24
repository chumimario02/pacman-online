extends Control
class_name NameTags

var game
var font: Font

func _ready() -> void:
	font = load("res://assets/PressStart2P-Regular.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 20
	set_process(true)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var local_id: String = str(game.local_player_id)
	for p in game.pacs:
		if p == null or not is_instance_valid(p) or not p.active:
			continue
		if str(p.player_id) == "" or str(p.player_id) == local_id:
			continue
		var pos: Vector2 = p.pos() + Vector2(0.0, -18.0)
		var col: Color = Config.PAC_COLORS.get(p.color_id, Config.WHITE)
		_draw_name(str(p.player_name), pos, col)
	for g in game.ghosts:
		if g == null or not is_instance_valid(g) or not g.visible:
			continue
		if str(g.player_id) == "" or str(g.player_id) == local_id:
			continue
		var pos: Vector2 = g.pos() + Vector2(0.0, -18.0)
		var col: Color = Config.GHOST_COLORS.get(g.ghost_name, Config.WHITE)
		_draw_name(str(g.player_name), pos, col)

func _draw_name(text: String, pos: Vector2, color: Color) -> void:
	if font == null or text == "":
		return
	var w := 90.0
	draw_string(font, Vector2(pos.x - w * 0.5, pos.y), text, HORIZONTAL_ALIGNMENT_CENTER, w, 6, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(pos.x - w * 0.5, pos.y - 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 6, color)