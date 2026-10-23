extends Control
class_name Lobby

var game
var font: Font
var room: Dictionary = {}
var player_id := ""
var host_id := ""
var selected_role := "pac"
var selected_color := "yellow"
var selected_ghost := "blinky"
var selected_bots := 2
var connected := false
var local_practice := false

var join_panel: Panel
var room_panel: Panel
var join_ui: Control
var room_ui: Control
var ui_parent: Control = null
var name_edit: LineEdit
var code_edit: LineEdit
var room_code_label: Label
var players_label: Label
var status_label: Label
var start_button: Button
var leave_button: Button
var copy_button: Button
var touch_check: CheckBox
var role_pac_button: Button
var role_ghost_button: Button
var bots_label: Label
var bot_minus: Button
var bot_plus: Button
var color_buttons: Array = []
var create_button: Button
var join_button: Button
var practice_button: Button

func _ready() -> void:
	font = load("res://assets/PressStart2P-Regular.ttf")
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 8
	theme = th
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	show_lobby()

func _style(fill: Color, border: Color, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s

func _panel_style() -> StyleBoxFlat:
	return _style(Color(0.035, 0.047, 0.086, 0.96), Color(0.13, 0.2, 0.34, 1.0), 10)

func _label(text: String, size: int, color: Color, pos: Vector2,
		width := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if width > 0.0:
		l.size = Vector2(width, 40)
		l.horizontal_alignment = align
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var parent: Control = ui_parent if ui_parent != null else self
	parent.add_child(l)
	return l

func _button(text: String, pos: Vector2, sz: Vector2, color := Config.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Config.YELLOW)
	b.add_theme_color_override("font_pressed_color", Config.YELLOW)
	var normal := _style(Color(0.07, 0.1, 0.17, 1), Color(0.2, 0.3, 0.5, 1), 6)
	var hover := _style(Color(0.1, 0.15, 0.26, 1), Config.CYAN, 6)
	var pressed := _style(Color(0.04, 0.06, 0.1, 1), Config.YELLOW, 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", _style(Color(0.04, 0.05, 0.08, 1), Color(0.1, 0.13, 0.2, 1), 6))
	var parent: Control = ui_parent if ui_parent != null else self
	parent.add_child(b)
	return b

func _line_edit(pos: Vector2, sz: Vector2, placeholder: String, max_len := 16) -> LineEdit:
	var e := LineEdit.new()
	e.position = pos
	e.size = sz
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.add_theme_font_override("font", font)
	e.add_theme_font_size_override("font_size", 9)
	e.add_theme_color_override("font_color", Config.WHITE)
	e.add_theme_color_override("placeholder_color", Config.GREY)
	e.add_theme_stylebox_override("normal", _style(Color(0.015, 0.02, 0.04, 1), Color(0.18, 0.26, 0.42, 1), 5))
	e.add_theme_stylebox_override("focus", _style(Color(0.015, 0.02, 0.04, 1), Config.CYAN, 5))
	var parent: Control = ui_parent if ui_parent != null else self
	parent.add_child(e)
	return e

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.016, 0.033, 0.58)
	bg.position = Vector2.ZERO
	bg.size = Vector2(Config.WIDTH, Config.HEIGHT)
	add_child(bg)

	_label("PAC-MAN ONLINE", 40, Config.YELLOW, Vector2(0, 34), Config.WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
	_label("4 JUGADORES  ·  SALAS POR CODIGO  ·  FANTASMAS", 8, Config.CYAN,
		Vector2(0, 92), Config.WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
	var line := ColorRect.new()
	line.color = Color(0.16, 0.24, 0.42, 1.0)
	line.position = Vector2(150, 120)
	line.size = Vector2(700, 1)
	add_child(line)

	join_ui = Control.new()
	join_ui.position = Vector2.ZERO
	join_ui.size = Vector2(Config.WIDTH, Config.HEIGHT)
	join_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(join_ui)
	ui_parent = join_ui

	join_panel = Panel.new()
	join_panel.position = Vector2(65, 145)
	join_panel.size = Vector2(405, 390)
	join_panel.add_theme_stylebox_override("panel", _panel_style())
	join_ui.add_child(join_panel)

	_label("TU NOMBRE", 8, Config.GREY, Vector2(90, 165))
	name_edit = _line_edit(Vector2(90, 188), Vector2(350, 40), "JUGADOR")
	name_edit.text = "JUGADOR"

	_label("CODIGO DE SALA", 8, Config.GREY, Vector2(90, 248))
	code_edit = _line_edit(Vector2(90, 271), Vector2(130, 40), "ABCD", 4)
	code_edit.text_changed.connect(_on_code_changed)

	create_button = _button("CREAR SALA", Vector2(90, 330), Vector2(350, 44), Config.YELLOW)
	create_button.pressed.connect(_on_create)
	join_button = _button("UNIRSE CON CODIGO", Vector2(90, 386), Vector2(350, 44), Config.CYAN)
	join_button.pressed.connect(_on_join)

	var hint := _label("Comparte el codigo o el enlace con tus amigos.", 6, Config.DIM,
		Vector2(90, 446), 350)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	practice_button = _button("PRACTICA LOCAL", Vector2(90, 484), Vector2(350, 34), Config.GREEN)
	practice_button.pressed.connect(func(): game.start_local_practice())

	room_ui = Control.new()
	room_ui.position = Vector2.ZERO
	room_ui.size = Vector2(Config.WIDTH, Config.HEIGHT)
	room_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_ui.visible = false
	add_child(room_ui)
	ui_parent = room_ui

	room_panel = Panel.new()
	room_panel.position = Vector2(510, 145)
	room_panel.size = Vector2(425, 440)
	room_panel.add_theme_stylebox_override("panel", _panel_style())
	room_ui.add_child(room_panel)

	_label("SALA", 8, Config.GREY, Vector2(535, 160))
	room_code_label = _label("----", 30, Config.YELLOW, Vector2(535, 181))
	copy_button = _button("COPIAR ENLACE", Vector2(765, 188), Vector2(145, 30), Config.CYAN)
	copy_button.add_theme_font_size_override("font_size", 6)
	copy_button.pressed.connect(_on_copy)

	_label("JUGADORES", 8, Config.GREY, Vector2(535, 225))
	players_label = _label("", 8, Config.WHITE, Vector2(535, 247), 370)
	players_label.size = Vector2(370, 80)
	players_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_label("TU ROL", 8, Config.GREY, Vector2(535, 330))
	role_pac_button = _button("PAC-MAN", Vector2(535, 350), Vector2(125, 30), Config.YELLOW)
	role_pac_button.pressed.connect(func(): _on_role("pac"))
	role_ghost_button = _button("FANTASMA", Vector2(670, 350), Vector2(125, 30), Config.CYAN)
	role_ghost_button.pressed.connect(func(): _on_role("ghost"))

	_label("TU COLOR", 8, Config.GREY, Vector2(535, 386))
	for i in range(4):
		var b := _button("", Vector2(535 + i * 88, 405), Vector2(82, 30), Config.WHITE)
		b.add_theme_font_size_override("font_size", 5)
		b.pressed.connect(_on_color_index.bind(i))
		color_buttons.append(b)

	bots_label = _label("BOTS: 2", 8, Config.WHITE, Vector2(535, 440))
	bot_minus = _button("-", Vector2(650, 438), Vector2(28, 28), Config.WHITE)
	bot_minus.pressed.connect(func(): _on_bots(-1))
	bot_plus = _button("+", Vector2(690, 438), Vector2(28, 28), Config.WHITE)
	bot_plus.pressed.connect(func(): _on_bots(1))

	touch_check = CheckBox.new()
	touch_check.text = "CONTROLES TACTILES"
	touch_check.position = Vector2(535, 492)
	touch_check.size = Vector2(320, 28)
	touch_check.focus_mode = Control.FOCUS_NONE
	touch_check.add_theme_font_override("font", font)
	touch_check.add_theme_font_size_override("font_size", 7)
	touch_check.add_theme_color_override("font_color", Config.WHITE)
	touch_check.toggled.connect(_on_touch_toggled)
	room_ui.add_child(touch_check)

	start_button = _button("INICIAR PARTIDA", Vector2(535, 530), Vector2(230, 34), Config.GREEN)
	start_button.pressed.connect(_on_start_pressed)
	leave_button = _button("SALIR", Vector2(780, 530), Vector2(120, 34), Config.SALMON)
	leave_button.pressed.connect(_on_leave)

	ui_parent = null
	status_label = _label("CONECTANDO AL SERVIDOR...", 7, Config.GREY,
		Vector2(65, 592), 870)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_label("ARROWS/WASD O D-PAD  ·  ELIGE COLOR  ·  EL HOST INICIA", 6, Config.DIM,
		Vector2(0, 622), Config.WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
	_label("FAN-MADE TRIBUTE  ·  NO AFILIADO A BANDAI NAMCO", 5,
		Color(0.2, 0.24, 0.34, 1), Vector2(0, 642), Config.WIDTH, HORIZONTAL_ALIGNMENT_CENTER)

	if OS.has_feature("web"):
		var r: String = str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('room') || ''"))
		if r != "":
			code_edit.text = r.to_upper()
			code_edit.caret_column = code_edit.text.length()
	join_ui.visible = true
	room_ui.visible = false

func show_lobby() -> void:
	visible = true
	if game:
		game.state = Config.LOBBY
		game.world.visible = false
		game.hud.visible = false
		if game.touch_ui:
			game.touch_ui.hide()
	if room.is_empty():
		join_ui.visible = true
		room_ui.visible = false
	else:
		join_ui.visible = false
		room_ui.visible = true
	refresh_ui()

func hide_lobby() -> void:
	visible = false

func reset_room() -> void:
	room = {}
	player_id = ""
	host_id = ""
	room_code_label.text = "----"
	players_label.text = ""
	join_ui.visible = true
	room_ui.visible = false
	status_label.text = ""
	refresh_ui()

func set_connected(value: bool) -> void:
	connected = value
	create_button.disabled = not value
	join_button.disabled = not value
	if value:
		set_status("CONECTADO. CREA UNA SALA O UNETE.", Config.GREEN)
	else:
		set_status("SIN CONEXION. RECONECTANDO...", Config.RED)

func set_status(text: String, color := Config.GREY) -> void:
	if status_label:
		status_label.text = text
		status_label.add_theme_color_override("font_color", color)

func on_welcome(pid: String, hid: String, code: String) -> void:
	player_id = pid
	host_id = hid
	join_ui.visible = false
	room_ui.visible = true
	room_code_label.text = code
	if game and game.net:
		game.net.room_code = code
	set_status("SALA %s. ESPERANDO JUGADORES." % code, Config.GREEN)
	refresh_ui()

func on_room(r: Dictionary) -> void:
	room = r
	host_id = str(r.get("hostId", host_id))
	if r.has("code"):
		room_code_label.text = str(r.get("code", "----"))
	var settings = r.get("settings", {})
	if typeof(settings) == TYPE_DICTIONARY:
		selected_bots = clampi(int(settings.get("bots", selected_bots)), 0, 4)
	var found := false
	for p in r.get("players", []):
		if str(p.get("id", "")) == player_id:
			selected_role = "ghost" if str(p.get("role", "pac")) == "ghost" else "pac"
			selected_color = str(p.get("color", selected_color))
			var gn := str(p.get("ghost_name", selected_ghost))
			if Config.GHOST_ORDER.has(gn):
				selected_ghost = gn
			found = true
			break
	if not found and player_id != "":
		# El jugador ya no está en la sala.
		reset_room()
		return
	join_ui.visible = false
	room_ui.visible = true
	refresh_ui()

func set_touch_checked(value: bool) -> void:
	if touch_check and touch_check.button_pressed != value:
		touch_check.set_pressed_no_signal(value)
	if game:
		game.touch_enabled = value

func _is_host() -> bool:
	if local_practice:
		return true
	return player_id != "" and player_id == host_id

func _player_color_name(cid: String) -> String:
	return Config.PAC_COLOR_NAMES.get(cid, cid.to_upper())

func _human_pac_count() -> int:
	var count := 0
	for p in room.get("players", []):
		if str(p.get("role", "pac")) != "ghost":
			count += 1
	return count

func _free_pac_slots() -> int:
	return maxi(0, 4 - _human_pac_count())

func _has_pac_choice() -> bool:
	return _human_pac_count() > 0 or selected_bots > 0

func _used_other_palette(role: String) -> Dictionary:
	var used := {}
	for p in room.get("players", []):
		if str(p.get("id", "")) == player_id:
			continue
		if role == "pac" and str(p.get("role", "pac")) != "ghost":
			used[str(p.get("color", "yellow"))] = true
		elif role == "ghost" and str(p.get("role", "pac")) == "ghost":
			used[str(p.get("ghost_name", "blinky"))] = true
	return used

func _first_free_palette(role: String) -> String:
	var palette: Array = Config.PAC_COLOR_ORDER if role == "pac" else Config.GHOST_ORDER
	var used := _used_other_palette(role)
	for cid in palette:
		if not used.has(cid):
			return str(cid)
	return ""

func _send_profile() -> void:
	if local_practice:
		for p in room.get("players", []):
			if str(p.get("id", "")) == player_id:
				p["role"] = selected_role
				p["color"] = selected_color
				p["ghost_name"] = selected_ghost
		room["settings"] = {"bots": selected_bots}
		refresh_ui()
		return
	if game and game.net:
		game.net.send_dict({
			"type": "profile",
			"role": selected_role,
			"color": selected_color,
			"ghost_name": selected_ghost,
		})

func show_local_practice() -> void:
	local_practice = true
	connected = true
	player_id = "local"
	host_id = "local"
	selected_role = "pac"
	selected_color = "yellow"
	selected_ghost = "blinky"
	selected_bots = 2
	room = {
		"code": "LOCAL", "hostId": "local",
		"players": [
			{"id": "local", "name": "JUGADOR", "role": "pac", "color": "yellow", "ghost_name": "blinky"},
		],
		"settings": {"bots": selected_bots},
	}
	show_lobby()

func _on_start_pressed() -> void:
	if local_practice:
		game.start_local_custom()
	else:
		game.start_host_game()

func refresh_ui() -> void:
	if not is_inside_tree():
		return
	var host := _is_host()
	role_pac_button.visible = room_ui.visible
	role_ghost_button.visible = room_ui.visible
	start_button.visible = host
	start_button.disabled = not host or not connected or not _has_pac_choice()
	leave_button.visible = room_ui.visible
	copy_button.visible = room_ui.visible
	bot_minus.visible = host and room_ui.visible
	bot_plus.visible = host and room_ui.visible
	bots_label.visible = room_ui.visible
	bots_label.text = "BOTS: %d" % selected_bots
	if host and selected_bots > _free_pac_slots():
		bots_label.text = "BOTS: %d (MAX %d)" % [selected_bots, _free_pac_slots()]
	role_pac_button.text = ("> " if selected_role == "pac" else "") + "PAC-MAN"
	role_ghost_button.text = ("> " if selected_role == "ghost" else "") + "FANTASMA"

	var palette: Array = Config.PAC_COLOR_ORDER if selected_role == "pac" else Config.GHOST_ORDER
	var selected_key := selected_color if selected_role == "pac" else selected_ghost
	var used := _used_other_palette(selected_role)
	for i in range(color_buttons.size()):
		var b: Button = color_buttons[i]
		var cid := str(palette[i])
		var label := str(Config.PAC_COLOR_NAMES.get(cid, cid.to_upper()))
		var col: Color = Config.PAC_COLORS.get(cid, Config.WHITE)
		if selected_role == "ghost":
			label = str(Config.GHOST_NAME_LABELS.get(cid, cid.to_upper()))
			col = Config.GHOST_COLORS.get(cid, Config.WHITE)
		b.text = ("> " if cid == selected_key else "") + label
		b.disabled = not room_ui.visible or (used.has(cid) and cid != selected_key)
		b.add_theme_color_override("font_color", col)

	if room.is_empty():
		players_label.text = ""
		return
	var lines := ""
	var players: Array = room.get("players", [])
	for p in players:
		var pid := str(p.get("id", ""))
		var tag := ">" if pid == player_id else " "
		var host_tag := " *" if pid == host_id else ""
		var role := str(p.get("role", "pac"))
		var detail := ""
		if role == "ghost":
			detail = "GHOST " + str(Config.GHOST_NAME_LABELS.get(str(p.get("ghost_name", "blinky")), "BLINKY"))
		else:
			detail = "PAC " + _player_color_name(str(p.get("color", "yellow")))
		lines += "%s %s%s  %s\n" % [tag, str(p.get("name", "JUGADOR")), host_tag, detail]
	players_label.text = lines
	if host:
		if not _has_pac_choice():
			set_status("FALTA UN PAC-MAN. AGREGA UN BOT O CAMBIA DE ROL.", Config.RED)
		else:
			set_status("ELIGE ROL, COLOR Y BOTS. PULSA INICIAR.", Config.YELLOW)
	else:
		set_status("ELIGE ROL Y COLOR. ESPERANDO AL HOST...", Config.CYAN)

func _on_code_changed(new_text: String) -> void:
	var up := new_text.to_upper()
	if up != new_text:
		code_edit.text = up
		code_edit.caret_column = up.length()

func _on_create() -> void:
	if not connected:
		set_status("SIN CONEXION AL SERVIDOR.", Config.RED)
		return
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "JUGADOR"
	game.net.send_dict({
		"type": "create", "name": n, "color": selected_color,
		"role": selected_role, "ghost_name": selected_ghost,
	})
	set_status("CREANDO SALA...", Config.YELLOW)

func _on_join() -> void:
	if not connected:
		set_status("SIN CONEXION AL SERVIDOR.", Config.RED)
		return
	var code := code_edit.text.strip_edges().to_upper()
	if code.length() != 4:
		set_status("EL CODIGO DEBE TENER 4 LETRAS.", Config.RED)
		return
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "JUGADOR"
	game.net.send_dict({
		"type": "join", "room": code, "name": n, "color": selected_color,
		"role": selected_role, "ghost_name": selected_ghost,
	})
	set_status("UNIENDOSE A %s..." % code, Config.YELLOW)

func _on_role(role: String) -> void:
	if role == selected_role:
		return
	var cid := _first_free_palette(role)
	if cid == "":
		set_status("NO HAY HUECO PARA ESE ROL.", Config.RED)
		return
	selected_role = role
	if role == "pac":
		selected_color = cid
	else:
		selected_ghost = cid
	_send_profile()
	refresh_ui()

func _on_color_index(index: int) -> void:
	var palette: Array = Config.PAC_COLOR_ORDER if selected_role == "pac" else Config.GHOST_ORDER
	var cid := str(palette[index])
	if _used_other_palette(selected_role).has(cid):
		set_status("ESE COLOR YA ESTA OCUPADO.", Config.RED)
		return
	if selected_role == "pac":
		selected_color = cid
	else:
		selected_ghost = cid
	_send_profile()
	refresh_ui()

func _on_bots(delta: int) -> void:
	if not _is_host():
		return
	selected_bots = clampi(selected_bots + delta, 0, 4)
	if local_practice:
		room["settings"] = {"bots": selected_bots}
		refresh_ui()
		return
	if game and game.net:
		game.net.send_dict({"type": "lobby", "data": {"bots": selected_bots}})
	refresh_ui()

func _on_touch_toggled(pressed: bool) -> void:
	if game:
		game.touch_enabled = pressed
		game._update_touch_visibility()

func _on_leave() -> void:
	if game and game.net:
		game.net.send_dict({"type": "leave"})
		game.net.room_code = ""
	reset_room()
	set_status("SALISTE DE LA SALA.", Config.GREY)

func _on_copy() -> void:
	var code := room_code_label.text
	if code == "----":
		return
	if OS.has_feature("web"):
		var url: String = str(JavaScriptBridge.eval("window.location.origin + window.location.pathname")) + "?room=" + code
		JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(" + JSON.stringify(url) + ")")
		set_status("ENLACE COPIADO: %s" % url, Config.GREEN)
	else:
		DisplayServer.clipboard_set(code)
		set_status("CODIGO COPIADO: %s" % code, Config.GREEN)
