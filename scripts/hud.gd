extends Control
class_name Hud

var game
var font: Font
var panel_style: StyleBoxFlat
var panel_inner: StyleBoxFlat
var menu_panel_style: StyleBoxFlat
var gameover_style: StyleBoxFlat
var gameover_inner: StyleBoxFlat

func _ready() -> void:
	font = load("res://assets/PressStart2P-Regular.ttf")
	panel_style = _make_style(Config.PANEL, Config.PANEL_BORDER, 10)
	panel_inner = _make_style(Color(0, 0, 0, 0), Color(0.0667, 0.0863, 0.1490, 1), 6)
	menu_panel_style = _make_style(Config.PANEL, Color(0.1569, 0.2353, 0.3765, 1), 10)
	gameover_style = _make_style(Color(0.0314, 0.0353, 0.0627, 1), Color(0.5490, 0.1333, 0.2431, 1), 14)
	gameover_inner = _make_style(Color(0, 0, 0, 0), Color(0.0667, 0.0863, 0.1490, 1), 10)

func _make_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or font == null:
		return
	if game.state == Config.MENU:
		_draw_menu()
	elif game.state == Config.LOBBY:
		return
	else:
		if game.maze_mode == "remake":
			_draw_remake_hud()
		else:
			_draw_header()
			_draw_panels()
			_draw_footer()
		_draw_maze_overlay()
		if game.state == Config.GAME_OVER:
			_draw_game_over()
		elif game.paused:
			_draw_pause()

# --------------------------------------------------------------------- texto
func _text(text: String, size: int, color: Color, pos: Vector2, align := 0,
		glow := Color(0, 0, 0, 0)) -> void:
	if font == null:
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == 1:
		x -= w * 0.5
	elif align == 2:
		x -= w
	var baseline := Vector2(x, pos.y + font.get_ascent(size))
	if glow.a > 0.0:
		var step := maxi(1, int(size / 8.0))
		var radii := [step, step * 2, step * 3]
		var alphas := [0.27, 0.16, 0.09]
		for i in range(3):
			var radius: int = radii[i]
			var a: float = alphas[i]
			var gc := Color(glow.r, glow.g, glow.b, a)
			for ang in range(0, 360, 45):
				var off := Vector2(cos(deg_to_rad(ang)), sin(deg_to_rad(ang))) * float(radius)
				draw_string(font, baseline + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, gc)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _textc(text: String, size: int, color: Color, center: Vector2,
		glow := Color(0, 0, 0, 0)) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var h := font.get_height(size)
	_text(text, size, color, Vector2(center.x - w * 0.5, center.y - h * 0.5), 0, glow)

func _hline(color: Color, x1: float, x2: float, y: float) -> void:
	draw_line(Vector2(x1, y), Vector2(x2, y), color, 1.0)

func _panel(rect: Rect2, style: StyleBoxFlat, inner: StyleBoxFlat) -> void:
	draw_style_box(style, rect)
	draw_style_box(inner, rect.grow(-4.0))

func _panel_label(text: String, x: float, y: float) -> void:
	_text(text, 8, Config.GREY, Vector2(x, y))

func _with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

func _region(tex: Texture2D, dest: Rect2, col: int, row: int, modulate := Color.WHITE) -> void:
	if tex == null:
		return
	draw_texture_rect_region(tex, dest, Rect2(col * 32, row * 32, 32, 32), modulate)

func _is_online() -> bool:
	return game.online_role != "offline"

func _local_pac():
	if game.has_method("_local_pac"):
		return game._local_pac()
	return game.pac

func _local_ghost():
	if game.has_method("_local_ghost"):
		return game._local_ghost()
	return null

func _local_lives() -> int:
	var p = _local_pac()
	if p != null:
		return int(p.lives)
	return int(game.lives)

func _short_name(n: String, max_len := 9) -> String:
	if n.length() <= max_len:
		return n
	return n.substr(0, max_len)

func _pac_icon(pos: Vector2, color: Color, radius := 8.0) -> void:
	draw_circle(pos, radius, color)
	var wedge := PackedVector2Array([
		pos,
		pos + Vector2(radius * 1.15, -radius * 0.55),
		pos + Vector2(radius * 1.15, radius * 0.55),
	])
	draw_colored_polygon(wedge, Color(0.031, 0.039, 0.075, 1.0))

# --------------------------------------------------------------------- game
func _draw_header() -> void:
	_text("PAC-MAN", 16, Config.YELLOW, Vector2(24, 24), 0, Color(1.0, 0.8235, 0.0))
	_text("ARCADE", 7, Config.GREY, Vector2(24, 46))
	var online := _is_online()
	var header_mode := "TEAM" if not online or game.online_mode == "team" else "GHOST"
	_text(header_mode if online else "1UP", 9, Config.CYAN, Vector2(Config.MAZE_X, 18))
	_text("%06d" % game.score, 18, Config.WHITE, Vector2(Config.MAZE_X - 2, 34))
	if online:
		_text("YOU", 9, Config.PINK, Vector2(Config.MAZE_X + 190, 18))
		var lp = _local_pac()
		var lg = _local_ghost()
		var mine := 0
		var tag := "PAC"
		if lp != null:
			mine = int(lp.score)
			tag = "PAC"
		elif lg != null:
			mine = int(lg.score)
			tag = "GHOST"
		_text("%06d" % mine, 18, Config.PAC_COLORS.get(lp.color_id, Config.WHITE) if lp != null else Config.WHITE,
			Vector2(Config.MAZE_X + 188, 34))
		_text(tag, 6, Config.DIM, Vector2(Config.MAZE_X + 190, 58))
	_text("HIGH SCORE", 9, Config.PINK, Vector2(Config.WIDTH - 24, 18), 2)
	_text("%06d" % game.high_score, 18, Config.WHITE, Vector2(Config.WIDTH - 24, 34), 2)
	_hline(Color(0.1176, 0.1725, 0.2902, 1), 24, Config.WIDTH - 24, 78)

func _draw_remake_hud() -> void:
	_text("REMAKE", 10, Config.CYAN, Vector2(24, 16))
	_text("SCORE %06d" % game.score, 11, Config.WHITE, Vector2(24, 38))
	var lp = _local_pac()
	if lp != null:
		_text("LIVES x%d" % int(lp.lives), 9, Config.YELLOW, Vector2(24, 58))
	_text("HIGH %06d" % game.high_score, 9, Config.PINK, Vector2(Config.WIDTH - 24, 16), 2)
	_text("LEVEL %02d" % game.level, 9, Config.YELLOW, Vector2(Config.WIDTH - 24, 38), 2)
	_text("P PAUSE   M MUTE   ESC LOBBY", 6, Config.GREY, Vector2(Config.WIDTH * 0.5, 634), 1)
	_hline(Color(0.1176, 0.1725, 0.2902, 1), 24, Config.WIDTH - 24, 66)

func _draw_panels() -> void:
	var left := Rect2(24, 112, 228, 484)
	var right := Rect2(Config.WIDTH - 252, 112, 228, 484)
	_panel(left, panel_style, panel_inner)
	_panel(right, panel_style, panel_inner)

	# columna izquierda
	_panel_label("LEVEL", 44, 132)
	_text("%02d" % game.level, 30, Config.YELLOW, Vector2(42, 148), 0, Color(0.6275, 0.4706, 0.0))
	_hline(Color(0.1176, 0.1647, 0.2588, 1), 40, 236, 196)

	_panel_label("PELLETS", 44, 212)
	_text(str(game.maze.remaining()), 18, Config.WHITE, Vector2(42, 230))
	_hline(Color(0.1176, 0.1647, 0.2588, 1), 40, 236, 268)

	_panel_label("FRUIT", 44, 288)
	if game.fruit_history.size() > 0:
		var shown: int = mini(game.fruit_history.size(), 8)
		for i in range(shown):
			var col: int = game.fruit_history[game.fruit_history.size() - shown + i]
			var gx := 46 + (i % 4) * 44
			var gy := 312 + int(i / 4.0) * 38
			_region(game.sheet, Rect2(gx, gy, 30, 30), col, 8)
	else:
		var idx: int = mini(game.level - 1, 7)
		var col2: int = Config.FRUIT_COLUMNS[idx]
		_region(game.sheet, Rect2(46, 312, 30, 30), col2, 8, Color(1, 1, 1, 65.0 / 255.0))
		_text("LEVEL BONUS", 6, Config.DIM, Vector2(84, 322))

	_panel_label("POWER PELLET", 44, 410)
	if game.power_texture:
		draw_texture(game.power_texture, Vector2(46, 434))
	_text("50 PTS", 8, Config.SALMON, Vector2(70, 438))

	_panel_label("STATUS", 44, 484)
	var status := "HUNT"
	var color := Config.GREEN
	if game.state == Config.GAME_OVER:
		status = "OVER"
		color = Config.RED
	elif game.state == Config.LEVEL_CLEAR:
		status = "CLEAR"
		color = Config.GREEN
	elif game.state == Config.DYING:
		status = "OUCH!"
		color = Config.RED
	elif game.frightened:
		status = "POWER!"
		color = Config.CYAN
	elif game.state == Config.READY:
		status = "READY"
		color = Config.YELLOW
	elif game.paused:
		status = "PAUSED"
		color = Config.WHITE
	var glow := Color(0, 0, 0, 0)
	if game.frightened:
		glow = color
	_text(status, 12, color, Vector2(44, 504), 0, glow)
	if game.frightened and game.ghost_combo > 0:
		var mult := 200 * int(pow(2, mini(game.ghost_combo, 3)))
		_text("NEXT %d" % mult, 7, Config.SALMON, Vector2(44, 532))

	# columna derecha
	_panel_label("PLAYERS", 768, 132)
	var y := 158
	for p in game.pacs:
		if p == null:
			continue
		var c: Color = Config.PAC_COLORS.get(p.color_id, Config.YELLOW)
		var tag := ">" if p.player_id == game.local_player_id else " "
		_pac_icon(Vector2(776, y + 7), c, 7.0)
		_text(tag + _short_name(p.player_name if p.player_name != "" else "CPU", 7), 7,
			c if p.active else Config.DIM, Vector2(792, y - 2))
		_text("%06d" % int(p.score), 7, Config.WHITE, Vector2(792, y + 14))
		if p.is_ai:
			_text("CPU", 5, Config.DIM, Vector2(936, y))
		elif not p.connected:
			_text("OFF", 5, Config.RED, Vector2(936, y))
		_text("x%d" % int(p.lives), 7, Config.YELLOW, Vector2(936, y + 14), 2)
		y += 42

	_hline(Color(0.1176, 0.1647, 0.2588, 1), 764, 960, y + 2)
	y += 16
	_panel_label("GHOSTS", 768, y)
	y += 24
	var shown_ghosts := 0
	for g in game.ghosts:
		if g == null or not g.is_player:
			continue
		var row: int = int(Config.GHOST_ROWS.get(g.ghost_name, 1))
		_region(game.sheet, Rect2(768, y - 7, 22, 22), 0, row)
		_text(_short_name(g.player_name if g.player_name != "" else g.ghost_name.to_upper(), 7), 7,
			Config.WHITE if g.connected else Config.DIM, Vector2(796, y - 2))
		_text("%06d" % int(g.score), 7, Config.SALMON, Vector2(796, y + 13))
		y += 34
		shown_ghosts += 1
	if shown_ghosts == 0:
		_text("CPU", 7, Config.DIM, Vector2(768, y))
		y += 24

	_hline(Color(0.1176, 0.1647, 0.2588, 1), 764, 960, 506)
	_text("ARROWS/WASD  MOVE", 6, Config.CYAN, Vector2(768, 520))
	_text("P PAUSE  M MUTE", 6, Config.GREY, Vector2(768, 538))
	_text("ESC LOBBY", 6, Config.GREY, Vector2(768, 556))
	if game.frightened:
		_text("POWER %ds" % maxi(0, int(game.fright_timer + 0.999)), 6, Config.CYAN, Vector2(768, 578))

func _draw_maze_overlay() -> void:
	var mr: Rect2 = game.maze_rect()
	if game.state == Config.LEVEL_CLEAR:
		var phase := int((Config.LEVEL_CLEAR_TIME - game.level_timer) / 0.18)
		if phase % 2 == 0:
			draw_rect(mr, Color(60.0 / 255.0, 78.0 / 255.0, 120.0 / 255.0, 0.55))
	if game.state == Config.READY:
		var pulse := 0.65 + 0.35 * sin(game.time * 6.0)
		var col := _with_alpha(Config.YELLOW, clampf(pulse, 0.0, 1.0))
		_textc("READY!", 16, col, Vector2(mr.position.x + mr.size.x * 0.5,
			mr.position.y + mr.size.y * 0.5), Color(0.5882, 0.4706, 0.0, 1.0))
	elif game.state == Config.LEVEL_CLEAR:
		_textc("LEVEL CLEAR", 22, Config.WHITE,
			Vector2(mr.position.x + mr.size.x * 0.5, mr.position.y + mr.size.y * 0.5 - 12),
			Color(0.4706, 0.6667, 1.0, 1.0))
		_textc("LEVEL %d READY" % (game.level + 1), 8, Config.YELLOW,
			Vector2(mr.position.x + mr.size.x * 0.5, mr.position.y + mr.size.y * 0.5 + 22))

func _draw_footer() -> void:
	if _is_online():
		var role := "HOST" if game.online_role == "host" else "CLIENT"
		var room := ""
		if game.net != null:
			room = game.net.room_code
		var mode_label := "TEAM" if game.online_mode == "team" else "FANTASMA"
		_text("%s  ROOM %s  %s" % [role, room, mode_label], 6,
			Color(0.32, 0.44, 0.66, 1), Vector2(24, 620))
		if game.touch_enabled:
			_text("TOUCH ON", 6, Config.CYAN, Vector2(Config.WIDTH - 24, 620), 2)
		elif game.audio != null and game.audio.ok:
			var muted := "MUTED" if game.audio.muted else "SOUND ON"
			_text(muted, 6, Color(0.2353, 0.2824, 0.3765, 1), Vector2(Config.WIDTH - 24, 620), 2)
		return
	_text("FAN-MADE TRIBUTE  -  NOT AFFILIATED WITH BANDAI NAMCO", 6,
		Color(0.2353, 0.2824, 0.3765, 1), Vector2(Config.WIDTH * 0.5, 620), 1)
	if game.audio != null and game.audio.ok:
		var muted := "MUTED" if game.audio.muted else "SOUND ON"
		_text(muted, 6, Color(0.2353, 0.2824, 0.3765, 1), Vector2(Config.WIDTH - 24, 620), 2)

func _draw_pause() -> void:
	var mr: Rect2 = game.maze_rect()
	draw_rect(mr, Color(0, 0, 0, 185.0 / 255.0))
	_textc("PAUSED", 24, Config.CYAN,
		Vector2(mr.position.x + mr.size.x * 0.5, mr.position.y + mr.size.y * 0.5 - 18),
		Color(0.0, 0.4706, 0.6275, 1.0))
	var sub := "PRESS P TO CONTINUE"
	if game.online_role == "client":
		sub = "PAUSED BY HOST"
	_textc(sub, 8, Config.GREY,
		Vector2(mr.position.x + mr.size.x * 0.5, mr.position.y + mr.size.y * 0.5 + 22))

func _draw_game_over() -> void:
	draw_rect(Rect2(0, 0, Config.WIDTH, Config.HEIGHT), Color(0, 0, 0, 180.0 / 255.0))
	var panel := Rect2(Config.WIDTH * 0.5 - 270, 205, 540, 320)
	_panel(panel, gameover_style, gameover_inner)
	var title := "GAME OVER"
	if game.winner == "ghosts":
		title = "GHOSTS WIN"
	elif game.winner == "pacmen":
		title = "PAC-MEN WIN"
	_textc(title, 34, Config.RED if game.winner == "ghosts" else Config.YELLOW,
		Vector2(Config.WIDTH * 0.5, 252), Color(0.6275, 0.0, 0.1176, 1.0))
	var score_label := "SCORE" if game.online_mode == "ghost" else "TEAM SCORE"
	_textc("%s  %06d" % [score_label, game.score], 14, Config.WHITE, Vector2(Config.WIDTH * 0.5, 336))
	_textc("HIGH SCORE  %06d" % game.high_score, 9, Config.PINK, Vector2(Config.WIDTH * 0.5, 372))
	_hline(Color(0.2118, 0.1569, 0.2275, 1), Config.WIDTH * 0.5 - 200, Config.WIDTH * 0.5 + 200, 402)
	if game.gameover_timer > 0.55:
		var a := (130.0 + 125.0 * (0.5 + 0.5 * sin(game.time * 4.5))) / 255.0
		var prompt := "ENTER  RESTART"
		if game.online_role == "client":
			prompt = "WAITING FOR HOST"
		elif game.online_role == "offline":
			prompt = "ENTER  PLAY AGAIN"
		_textc(prompt, 10, _with_alpha(Config.YELLOW, a),
			Vector2(Config.WIDTH * 0.5, 438))
	_textc("ESC  LOBBY", 8, Config.GREY, Vector2(Config.WIDTH * 0.5, 484))

# --------------------------------------------------------------------- menu
func _draw_menu() -> void:
	var cx := Config.WIDTH * 0.5
	_textc("PAC-MAN", 64, Config.YELLOW, Vector2(cx, 150), Color(1.0, 0.6667, 0.0, 1.0))
	_textc("A GODOT ARCADE TRIBUTE", 9, Config.CYAN, Vector2(cx, 218))
	draw_line(Vector2(cx - 220, 244), Vector2(cx + 220, 244), Color(0.1961, 0.2745, 0.4314, 1), 1.0)

	var span := Config.WIDTH - 200.0
	var pac_x := 260.0 + fmod(game.menu_time * 85.0, span)
	var base_y := 330.0 + sin(game.menu_time * 2.2) * 12.0
	var names := ["blinky", "pinky", "inky", "clyde"]
	var positions: Array = []
	for i in range(names.size()):
		positions.append([names[i], pac_x - 78.0 - i * 54.0])

	var dx := -260.0
	while dx < 0.0:
		var dot_x := int(pac_x + dx)
		if dot_x > -20 and dot_x < Config.WIDTH + 20:
			draw_circle(Vector2(dot_x, int(base_y)), 2.0, Config.SALMON)
		dx += 22.0

	for item in positions:
		var gx: float = item[1]
		var gy := base_y + sin((gx + game.menu_time * 40.0) * 0.012) * 8.0
		var frame := int(game.time * 8.0) % 2
		_region(game.sheet, Rect2(gx - 32, gy - 32, 64, 64), frame, Config.GHOST_ROWS[item[0]])
	var pac_y := base_y + sin((pac_x + game.menu_time * 40.0) * 0.012) * 8.0
	var pframe := int(game.time * 10.0) % 4
	var pcols := [0, 1, 2, 1]
	_region(game.sheet, Rect2(pac_x - 32, pac_y - 32, 64, 64), pcols[pframe], 0)

	_textc("HIGH SCORE   %06d" % game.high_score, 12, Config.WHITE, Vector2(cx, 420))
	var prompt_a := (130.0 + 125.0 * (0.5 + 0.5 * sin(game.time * 4.0))) / 255.0
	_textc("PRESS ENTER TO START", 16, _with_alpha(Config.YELLOW, prompt_a), Vector2(cx, 462))

	var panel := Rect2(cx - 250, 512, 500, 94)
	_panel(panel, menu_panel_style, panel_inner)
	_text("ARROWS / WASD   MOVE", 9, Config.WHITE, Vector2(cx, 530), 1)
	_text("P  PAUSE        M  MUTE        ESC  QUIT", 8, Config.GREY, Vector2(cx, 558), 1)
	_text("EAT ALL THE DOTS. POWER PELLETS LET YOU HUNT.", 7, Config.CYAN, Vector2(cx, 584), 1)

	_text("SPRITES: PHASER EXAMPLES  -  FONT: PRESS START 2P (OFL)", 6,
		Color(0.2353, 0.2824, 0.3922, 1), Vector2(cx, 628), 1)
	_text("FAN-MADE TRIBUTE  -  NOT AFFILIATED WITH BANDAI NAMCO", 6,
		Color(0.2039, 0.2431, 0.3373, 1), Vector2(cx, 648), 1)
