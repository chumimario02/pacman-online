extends Control
class_name Intro

signal started

var game
var font: Font
var time := 0.0
var active := false

func _ready() -> void:
	font = load("res://assets/PressStart2P-Regular.ttf")
	position = Vector2.ZERO
	size = Vector2(Config.WIDTH, Config.HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	active = false
	set_process(false)
	set_process_unhandled_input(false)

func show_intro() -> void:
	visible = true
	active = true
	time = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	set_process_unhandled_input(true)
	queue_redraw()

func hide_intro() -> void:
	visible = false
	active = false
	set_process(false)
	set_process_unhandled_input(false)

func _start() -> void:
	if not active:
		return
	active = false
	started.emit()

func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_start()
	elif event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		_start()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_start()

func _process(dt: float) -> void:
	time += dt
	queue_redraw()

func _text(text: String, y: float, size: int, color: Color, alpha := 1.0) -> void:
	if font == null:
		return
	var shadow := Color(0, 0, 0, 0.65 * alpha)
	draw_string(font, Vector2(0.0, y + 3.0), text, HORIZONTAL_ALIGNMENT_CENTER, float(Config.WIDTH), size, shadow)
	draw_string(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, float(Config.WIDTH), size,
		Color(color.r, color.g, color.b, alpha))

func _glow_text(text: String, y: float, size: int, color: Color, alpha := 1.0) -> void:
	if font == null:
		return
	for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(font, Vector2(off.x, y + off.y), text, HORIZONTAL_ALIGNMENT_CENTER, float(Config.WIDTH), size,
			Color(color.r, color.g, color.b, 0.10 * alpha))
	_text(text, y, size, color, alpha)

func _draw() -> void:
	var w := float(Config.WIDTH)
	var h := float(Config.HEIGHT)
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.005, 0.008, 0.025, 0.30))

	# Logo.
	_glow_text("PAC-MAN", 142.0, 54, Config.YELLOW)
	_glow_text("ONLINE", 190.0, 22, Config.CYAN)
	_text("4 JUGADORES  ·  ELIGE PAC-MAN O FANTASMA", 224.0, 7, Config.PINK)

	# Separador de neón.
	var line_y := 246.0
	draw_line(Vector2(115.0, line_y), Vector2(w - 115.0, line_y), Color(0.1, 0.72, 1.0, 0.34), 1.0)
	draw_line(Vector2(115.0, line_y + 4.0), Vector2(w - 115.0, line_y + 4.0), Color(1.0, 0.25, 0.72, 0.20), 1.0)

	# Pac-Man huyendo de los fantasmas, con estela de puntos.
	var chase_y := 344.0 + sin(time * 2.1) * 3.0
	var pac_x := 150.0 + fmod(time * 78.0, 760.0)
	var sprite := 60.0
	for i in range(16):
		var px := 110.0 + i * 55.0
		var eaten := px < pac_x - 24.0
		var pc := Color(1.0, 0.84, 0.25, 0.16) if eaten else Color(1.0, 0.93, 0.44, 0.72)
		draw_circle(Vector2(px, chase_y + sprite * 0.5), 2.2, pc)

	if game != null and game.pac_frames != null:
		var mouth := int(time * 11.0) % 4
		var pac_tex: Texture2D = game.pac_frames.get_frame_texture("chomp", mouth)
		if pac_tex != null:
			draw_circle(Vector2(pac_x + sprite * 0.5, chase_y + sprite * 0.5), 40.0, Color(1.0, 0.82, 0.0, 0.10))
			draw_texture_rect(pac_tex, Rect2(pac_x, chase_y, sprite, sprite), false)

	var ghost_names := ["blinky", "pinky", "inky", "clyde"]
	for i in range(ghost_names.size()):
		var gn: String = ghost_names[i]
		var gx := pac_x - 64.0 - i * 55.0
		if gx < -70.0:
			continue
		var gy := chase_y + sin(time * 3.0 + i * 0.8) * 4.0
		var gcol: Color = Config.GHOST_COLORS.get(gn, Config.WHITE)
		draw_circle(Vector2(gx + sprite * 0.5, gy + sprite * 0.5), 37.0,
			Color(gcol.r, gcol.g, gcol.b, 0.10))
		if game.ghost_frames.has(gn):
			var sf: SpriteFrames = game.ghost_frames[gn]
			var gtex: Texture2D = sf.get_frame_texture("right", int(time * 8.0 + i) % 2)
			if gtex != null:
				draw_texture_rect(gtex, Rect2(gx, gy, sprite, sprite), false)

	# PRESS START parpadeante.
	var pulse := 0.62 + 0.38 * (0.5 + 0.5 * sin(time * 4.0))
	var blink := pulse if int(time * 2.0) % 2 == 0 else 0.36
	var box := Rect2(w * 0.5 - 190.0, 454.0 - 32.0, 380.0, 58.0)
	draw_rect(box, Color(0.01, 0.03, 0.08, 0.72), true)
	draw_rect(box, Color(1.0, 0.83, 0.1, 0.58 * blink), false, 2.0)
	_glow_text("PRESS START", 474.0, 22, Config.YELLOW, blink)
	_text("CLICK / TAP / ENTER PARA ENTRAR", 512.0, 7, Config.WHITE, 0.78)
	_text("F  =  PANTALLA COMPLETA", 540.0, 7, Config.CYAN, 0.72)
	_text("CREA SALA, UNETE CON CODIGO O JUEGA EN LOCAL", 578.0, 6, Config.GREY, 0.85)

	draw_line(Vector2(115.0, 612.0), Vector2(w - 115.0, 612.0), Color(0.1, 0.72, 1.0, 0.22), 1.0)
	_text("FAN-MADE TRIBUTE  ·  NO AFILIADO A BANDAI NAMCO", 642.0, 5, Color(0.42, 0.48, 0.62, 1.0))
