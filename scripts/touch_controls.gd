extends Control
class_name TouchControls

var game
var font: Font
var buttons: Array = []

func _ready() -> void:
	font = load("res://assets/PressStart2P-Regular.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	return s

func _button(text: String, pos: Vector2, sz: Vector2, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	b.add_theme_color_override("font_hover_color", Config.YELLOW)
	b.add_theme_color_override("font_pressed_color", Config.YELLOW)
	b.add_theme_stylebox_override("normal", _style(Color(0.02, 0.03, 0.06, 0.55), Color(0.25, 0.4, 0.7, 0.45)))
	b.add_theme_stylebox_override("hover", _style(Color(0.04, 0.07, 0.13, 0.75), Config.CYAN))
	b.add_theme_stylebox_override("pressed", _style(Color(0.01, 0.02, 0.04, 0.85), Config.YELLOW))
	add_child(b)
	buttons.append(b)
	return b

func _build() -> void:
	var up := _button("^", Vector2(108, 466), Vector2(64, 64), 22)
	up.button_down.connect(_dir.bind("up"))
	var left := _button("<", Vector2(40, 534), Vector2(64, 64), 22)
	left.button_down.connect(_dir.bind("left"))
	var right := _button(">", Vector2(176, 534), Vector2(64, 64), 22)
	right.button_down.connect(_dir.bind("right"))
	var down := _button("v", Vector2(108, 602), Vector2(64, 64), 22)
	down.button_down.connect(_dir.bind("down"))

	var pause := _button("II", Vector2(884, 604), Vector2(48, 44), 12)
	pause.button_down.connect(func(): if game: game.toggle_pause())
	var mute := _button("M", Vector2(830, 604), Vector2(48, 44), 12)
	mute.button_down.connect(func(): if game: game._toggle_mute())

	var label := Label.new()
	label.text = "TACTIL"
	label.position = Vector2(40, 444)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", Color(0.4, 0.55, 0.8, 0.8))
	add_child(label)

func _dir(name: String) -> void:
	if game:
		game.set_local_dir(name)
