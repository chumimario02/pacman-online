extends Node2D

const HIGHSCORE_PATH := "user://highscore.json"
const GHOST_NAMES := ["blinky", "pinky", "inky", "clyde"]
const MODE_TEAM := "team"
const MODE_GHOST := "ghost"
const MAX_PLAYERS := Config.MAX_PLAYERS

var audio
var maze
var state := Config.LOBBY
var paused := false
var time := 0.0
var menu_time := 0.0

var high_score := 0
var score := 0
var lives := 3
var level := 1
var next_extra := 10000

var pacs: Array = []
var pac = null
var ghosts: Array = []
var mode := "scatter"
var mode_idx := 0
var mode_timer := 7.0
var frightened := false
var fright_timer := 0.0
var ghost_combo := 0
var freeze_timer := 0.0

var ready_timer := 0.0
var death_timer := 0.0
var level_timer := 0.0
var gameover_timer := 0.0

var popups: Array = []
var particles: Array = []
var shake := 0.0

var fruit_active := false
var fruit_timer := 0.0
var fruit_history: Array = []
var fruit_thresholds := [false, false]
var pellets_eaten := 0
var waka_toggle := false

var sheet: Texture2D
var power_texture: Texture2D
var bg_texture: Texture2D
var scanlines_texture: Texture2D
var fruit_glow_texture: Texture2D
var pac_frames: SpriteFrames
var ghost_frames: Dictionary = {}
var fruit_level_textures: Array = []

var world: Node2D
var name_tags
var maze_view
var effects
var hud
var fruit_sprite: Sprite2D
var fruit_glow: Sprite2D
var suppress_save := false
var smoke_ok := true
var smoke_running := false

# ------------------------------------------------------------------ online
var net: NetClient
var lobby
var touch_ui
var backdrop
var intro
var fullscreen_button
var hd_button
var use_hd_sprites := false
var nostalgia_mode := false
var last_input_seq: Dictionary = {}
var zoomed := false
var online_role := "offline"   # offline | host | client
var online_mode := MODE_TEAM
var roster: Array = []
var online_ghost_names: Array = []
var local_custom_mode := false
var local_player_id := ""
var dying_player := ""
var winner := ""
var touch_enabled := false
var snapshot_accum := 0.0
var snapshot_full := true
var eaten_delta: Array = []
var net_events: Array = []
var client_snapshot_seen := false
var client_paused := false
var local_input_seq := 0
var pending_inputs: Array = []
var last_snapshot_time := 0.0
var host_local_tile: Vector2i = Vector2i.ZERO
var host_local_progress := 0.0
var host_local_dir: String = ""

func _ready() -> void:
	randomize()
	_load_high()
	_load_assets()
	_build_frames()
	_build_fruit_textures()

	audio = GameAudio.new()
	audio.name = "Audio"
	add_child(audio)

	if bg_texture:
		var bg := Sprite2D.new()
		bg.name = "Background"
		bg.texture = bg_texture
		bg.centered = false
		bg.z_index = -100
		add_child(bg)

	world = Node2D.new()
	world.name = "World"
	world.position = Vector2(Config.MAZE_X, Config.MAZE_Y)
	add_child(world)

	name_tags = NameTags.new()
	name_tags.name = "NameTags"
	name_tags.game = self
	name_tags.z_index = 20
	world.add_child(name_tags)

	maze = Maze.new()
	maze_view = MazeView.new()
	maze_view.name = "MazeView"
	maze_view.game = self
	maze_view.maze = maze
	world.add_child(maze_view)

	_create_fruit()

	effects = Effects.new()
	effects.name = "Effects"
	effects.game = self
	effects.z_index = 10
	world.add_child(effects)

	_create_hud()
	_create_online_ui()
	_setup_level(true, true)
	state = Config.LOBBY
	paused = false
	world.visible = false
	hud.visible = false

	if scanlines_texture:
		var scan_layer := CanvasLayer.new()
		scan_layer.name = "Scanlines"
		scan_layer.layer = 20
		add_child(scan_layer)
		var scan := Sprite2D.new()
		scan.texture = scanlines_texture
		scan.centered = false
		scan_layer.add_child(scan)

	_position_window.call_deferred()
	_connect_network()
	if lobby:
		lobby.set_connected(net != null and net.status == "online")
	_show_intro()
	if DisplayServer.is_touchscreen_available():
		touch_enabled = true
	_update_touch_visibility()
	if "--smoke" in OS.get_cmdline_user_args():
		_run_smoke.call_deferred()
	if "--online-smoke" in OS.get_cmdline_user_args():
		_run_online_smoke.call_deferred()

# -------------------------------------------------------------------- setup
func _load_assets() -> void:
	if ResourceLoader.exists("res://assets/sprites32.png"):
		sheet = load("res://assets/sprites32.png")
	if ResourceLoader.exists("res://assets/power.png"):
		power_texture = load("res://assets/power.png")
	if ResourceLoader.exists("res://assets/bg.png"):
		bg_texture = load("res://assets/bg.png")
	if ResourceLoader.exists("res://assets/scanlines.png"):
		scanlines_texture = load("res://assets/scanlines.png")
	if ResourceLoader.exists("res://assets/fruit_glow.png"):
		fruit_glow_texture = load("res://assets/fruit_glow.png")

func _build_frames() -> void:
	if use_hd_sprites:
		pac_frames = HDSprites.build_pac_frames()
		ghost_frames.clear()
		for n in GHOST_NAMES:
			ghost_frames[n] = HDSprites.build_ghost_frames(n)
		return
	if sheet == null:
		pac_frames = SpriteFrames.new()
		return
	pac_frames = SpriteFrames.new()
	pac_frames.add_animation("chomp")
	for col in [0, 1, 2, 1]:
		pac_frames.add_frame("chomp", _atlas(col, 0))
	pac_frames.set_animation_loop("chomp", true)
	pac_frames.set_animation_speed("chomp", 16.0)

	ghost_frames.clear()
	for n in GHOST_NAMES:
		var row: int = Config.GHOST_ROWS[n]
		var sf := SpriteFrames.new()
		_add_anim(sf, "right", [0, 1], row, 7.0, true)
		_add_anim(sf, "left", [2, 3], row, 7.0, true)
		_add_anim(sf, "up", [4, 5], row, 7.0, true)
		_add_anim(sf, "down", [6, 7], row, 7.0, true)
		_add_anim(sf, "fright", [0, 1], 7, 7.0, true)
		_add_anim(sf, "flash", [2, 3], 7, 7.0, true)
		_add_anim(sf, "eyes_left", [0], 6, 1.0, false)
		_add_anim(sf, "eyes_down", [2], 6, 1.0, false)
		_add_anim(sf, "eyes_right", [4], 6, 1.0, false)
		_add_anim(sf, "eyes_up", [6], 6, 1.0, false)
		ghost_frames[n] = sf

func _add_anim(sf: SpriteFrames, anim: String, cols: Array, row: int, speed: float, loop: bool) -> void:
	sf.add_animation(anim)
	for col in cols:
		sf.add_frame(anim, _atlas(col, row))
	sf.set_animation_speed(anim, speed)
	sf.set_animation_loop(anim, loop)

func _atlas(col: int, row: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = sheet
	t.region = Rect2(col * 32, row * 32, 32, 32)
	return t

func _build_fruit_textures() -> void:
	fruit_level_textures.clear()
	if sheet == null:
		return
	for col in Config.FRUIT_COLUMNS:
		fruit_level_textures.append(_atlas(col, 8))

func _create_fruit() -> void:
	fruit_glow = Sprite2D.new()
	fruit_glow.name = "FruitGlow"
	fruit_glow.texture = fruit_glow_texture
	fruit_glow.centered = false
	fruit_glow.z_index = 1
	if fruit_glow_texture:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		fruit_glow.material = mat
	world.add_child(fruit_glow)

	fruit_sprite = Sprite2D.new()
	fruit_sprite.name = "Fruit"
	fruit_sprite.centered = false
	fruit_sprite.z_index = 2
	world.add_child(fruit_sprite)
	fruit_sprite.visible = false
	fruit_glow.visible = false

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	hud.name = "Hud"
	hud.game = self
	hud.position = Vector2.ZERO
	hud.size = Vector2(Config.WIDTH, Config.HEIGHT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)

func _create_online_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "OnlineLayer"
	layer.layer = 30
	add_child(layer)

	backdrop = ArcadeBg.new()
	backdrop.name = "ArcadeBackdrop"
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(Config.WIDTH, Config.HEIGHT)
	layer.add_child(backdrop)

	lobby = Lobby.new()
	lobby.name = "Lobby"
	lobby.game = self
	lobby.position = Vector2.ZERO
	lobby.size = Vector2(Config.WIDTH, Config.HEIGHT)
	layer.add_child(lobby)
	lobby.hide()

	touch_ui = TouchControls.new()
	touch_ui.name = "TouchControls"
	touch_ui.game = self
	touch_ui.position = Vector2.ZERO
	touch_ui.size = Vector2(Config.WIDTH, Config.HEIGHT)
	touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(touch_ui)
	touch_ui.hide()

	intro = Intro.new()
	intro.name = "Intro"
	intro.game = self
	intro.position = Vector2.ZERO
	intro.size = Vector2(Config.WIDTH, Config.HEIGHT)
	layer.add_child(intro)
	intro.hide_intro()
	intro.started.connect(_enter_menu)

	var fs_layer := CanvasLayer.new()
	fs_layer.name = "FullscreenLayer"
	fs_layer.layer = 40
	add_child(fs_layer)
	var btn_font := load("res://assets/PressStart2P-Regular.ttf")
	fullscreen_button = Button.new()
	fullscreen_button.name = "Fullscreen"
	fullscreen_button.text = "PANTALLA COMPLETA"
	fullscreen_button.position = Vector2(842, 14)
	fullscreen_button.size = Vector2(144, 28)
	fullscreen_button.focus_mode = Control.FOCUS_NONE
	fullscreen_button.add_theme_font_override("font", btn_font)
	fullscreen_button.add_theme_font_size_override("font_size", 6)
	fullscreen_button.add_theme_color_override("font_color", Config.CYAN)
	fullscreen_button.add_theme_color_override("font_hover_color", Config.YELLOW)
	fullscreen_button.add_theme_color_override("font_pressed_color", Config.YELLOW)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.03, 0.06, 0.12, 0.82)
	normal.border_color = Color(0.12, 0.42, 0.72, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.06, 0.12, 0.22, 0.95)
	hover.border_color = Config.CYAN
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	fullscreen_button.add_theme_stylebox_override("normal", normal)
	fullscreen_button.add_theme_stylebox_override("hover", hover)
	fullscreen_button.add_theme_stylebox_override("pressed", hover)
	fullscreen_button.pressed.connect(toggle_fullscreen)
	fs_layer.add_child(fullscreen_button)

	hd_button = Button.new()
	hd_button.name = "HDToggle"
	hd_button.text = "HD: OFF"
	hd_button.position = Vector2(16, 620)
	hd_button.size = Vector2(96, 28)
	hd_button.focus_mode = Control.FOCUS_NONE
	hd_button.add_theme_font_override("font", btn_font)
	hd_button.add_theme_font_size_override("font_size", 6)
	hd_button.add_theme_color_override("font_color", Config.YELLOW)
	hd_button.add_theme_color_override("font_hover_color", Config.CYAN)
	hd_button.add_theme_color_override("font_pressed_color", Config.CYAN)
	var hd_normal := StyleBoxFlat.new()
	hd_normal.bg_color = Color(0.03, 0.06, 0.12, 0.82)
	hd_normal.border_color = Color(0.85, 0.7, 0.1, 0.85)
	hd_normal.set_border_width_all(1)
	hd_normal.set_corner_radius_all(6)
	var hd_hover := StyleBoxFlat.new()
	hd_hover.bg_color = Color(0.06, 0.12, 0.22, 0.95)
	hd_hover.border_color = Config.YELLOW
	hd_hover.set_border_width_all(1)
	hd_hover.set_corner_radius_all(6)
	hd_button.add_theme_stylebox_override("normal", hd_normal)
	hd_button.add_theme_stylebox_override("hover", hd_hover)
	hd_button.add_theme_stylebox_override("pressed", hd_hover)
	hd_button.pressed.connect(toggle_hd)
	fs_layer.add_child(hd_button)

func _show_intro() -> void:
	state = Config.LOBBY
	paused = false
	world.visible = false
	hud.visible = false
	if lobby:
		lobby.hide_lobby()
	if backdrop:
		backdrop.visible = true
	if intro:
		intro.show_intro()
	if fullscreen_button:
		fullscreen_button.visible = true
	if touch_ui:
		touch_ui.hide()

func _enter_menu() -> void:
	if intro:
		intro.hide_intro()
	if backdrop:
		backdrop.visible = true
	if lobby:
		lobby.show_lobby()
		lobby.set_connected(net != null and net.status == "online")
	if fullscreen_button:
		fullscreen_button.visible = true

func toggle_hd() -> void:
	use_hd_sprites = not use_hd_sprites
	_build_frames()
	if hd_button:
		hd_button.text = "HD: " + ("ON" if use_hd_sprites else "OFF")

func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function () {
				if (!document.fullscreenElement) {
					var el = document.documentElement;
					if (el.requestFullscreen) el.requestFullscreen().catch(function () {});
				} else if (document.exitFullscreen) {
					document.exitFullscreen();
				}
			})();
		""")
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _set_zoom(enabled: bool) -> void:
	zoomed = enabled
	if enabled:
		var frame_w := float(Config.MAZE_W + 18)
		var frame_h := float(Config.MAZE_H + 18)
		var s := minf((float(Config.WIDTH) - 60.0) / frame_w, (float(Config.HEIGHT) - 60.0) / frame_h)
		world.scale = Vector2(s, s)
		var target := Vector2((float(Config.WIDTH) - frame_w * s) * 0.5, (float(Config.HEIGHT) - frame_h * s) * 0.5)
		world.position = target + Vector2(9.0, 9.0) * s
		if hud:
			hud.visible = false
	else:
		world.scale = Vector2.ONE
		world.position = Vector2(Config.MAZE_X, Config.MAZE_Y)
		if hud and state != Config.LOBBY:
			hud.visible = true
	_update_touch_visibility()
	if OS.has_feature("web"):
		return
	if DisplayServer.get_name() == "headless":
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var client_pos := DisplayServer.window_get_position()
	var outer_pos := DisplayServer.window_get_position_with_decorations()
	var outer_size := DisplayServer.window_get_size_with_decorations()
	var decor_offset := client_pos - outer_pos
	var target := usable.position + Vector2i(
		int((usable.size.x - outer_size.x) * 0.5),
		int((usable.size.y - outer_size.y) * 0.5))
	target.x = maxi(target.x, usable.position.x)
	target.y = maxi(target.y, usable.position.y)
	DisplayServer.window_set_position(target + decor_offset)

func _position_window() -> void:
	if OS.has_feature("web"):
		return
	if DisplayServer.get_name() == "headless":
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var client_pos := DisplayServer.window_get_position()
	var outer_pos := DisplayServer.window_get_position_with_decorations()
	var outer_size := DisplayServer.window_get_size_with_decorations()
	var decor_offset := client_pos - outer_pos
	var target := usable.position + Vector2i(
		int((usable.size.x - outer_size.x) * 0.5),
		int((usable.size.y - outer_size.y) * 0.5))
	target.x = maxi(target.x, usable.position.x)
	target.y = maxi(target.y, usable.position.y)
	DisplayServer.window_set_position(target + decor_offset)

func _spawn_actors() -> void:
	var old_stats: Dictionary = {}
	for p in pacs:
		if p != null and is_instance_valid(p):
			old_stats[p.player_id] = {"score": p.score, "lives": p.lives}

	_clear_actors()

	if roster.is_empty():
		pac = PacMan.new()
		pac.name = "PacMan"
		pac.setup(maze, pac_frames, "local", "yellow", Config.START_TILE)
		pac.player_name = "TÚ"
		if old_stats.has("local"):
			pac.score = int(old_stats["local"]["score"])
			pac.lives = int(old_stats["local"]["lives"])
		else:
			pac.score = 0
			pac.lives = lives
		pac.z_index = 5
		world.add_child(pac)
		pacs.append(pac)
	else:
		var pac_entries: Array = []
		for e in roster:
			if str(e.get("role", "")) == "pac":
				pac_entries.append(e)
		pac_entries.sort_custom(func(a, b): return int(a.get("pac_index", 0)) < int(b.get("pac_index", 0)))
		for e in pac_entries:
			var idx: int = int(e.get("pac_index", 0))
			var spawn: Vector2i = Config.PAC_STARTS[idx % Config.PAC_STARTS.size()]
			var p := PacMan.new()
			p.name = "Pac_" + str(e.get("id", idx))
			p.setup(maze, pac_frames, str(e.get("id", "")), str(e.get("color", "yellow")), spawn)
			p.player_name = str(e.get("name", "JUGADOR"))
			p.is_ai = bool(e.get("ai", false))
			p.connected = bool(e.get("connected", true))
			if old_stats.has(p.player_id):
				p.score = int(old_stats[p.player_id]["score"])
				p.lives = int(old_stats[p.player_id]["lives"])
			p.z_index = 5
			world.add_child(p)
			pacs.append(p)
			if p.player_id == local_player_id:
				pac = p
		if pac == null and not pacs.is_empty():
			pac = pacs[0]

	ghosts = []
	var spawned_ghosts: Array = online_ghost_names.duplicate()
	if spawned_ghosts.is_empty():
		spawned_ghosts = GHOST_NAMES.duplicate()
	for n in spawned_ghosts:
		if not GHOST_NAMES.has(n):
			continue
		var g := Ghost.new()
		g.name = n
		g.setup(self, maze, n, ghost_frames[n])
		g.z_index = 4
		var assigned = null
		for e in roster:
			if str(e.get("role", "")) == "ghost" and str(e.get("ghost_name", "")) == n:
				assigned = e
				break
		if assigned != null:
			g.set_player(str(assigned.get("id", "")), str(assigned.get("name", "")))
			g.connected = bool(assigned.get("connected", true))
			# Un fantasma humano debe poder salir y jugar de inmediato.
			g.release = 0.0
			g.house_timer = 0.0
			if old_stats.has(g.player_id):
				g.score = int(old_stats[g.player_id].get("score", 0))
		world.add_child(g)
		ghosts.append(g)

func _clear_actors() -> void:
	for p in pacs:
		if p != null and is_instance_valid(p):
			if smoke_running:
				p.free()
			else:
				p.queue_free()
	pacs.clear()
	pac = null
	for g in ghosts:
		if is_instance_valid(g):
			if smoke_running:
				g.free()
			else:
				g.queue_free()
	ghosts.clear()

func _reset_round_state() -> void:
	mode = "scatter"
	mode_idx = 0
	mode_timer = Config.MODE_SCHEDULE[0][0]
	frightened = false
	fright_timer = 0.0
	ghost_combo = 0
	freeze_timer = 0.0
	pellets_eaten = 0
	fruit_active = false
	fruit_timer = 0.0
	fruit_thresholds = [false, false]
	ready_timer = Config.ONLINE_READY_TIME if online_role != "offline" else Config.READY_TIME
	death_timer = 0.0
	gameover_timer = 0.0
	shake = 0.0
	dying_player = ""
	winner = ""

func _setup_level(new_game := false, silent := false) -> void:
	maze.reset()
	_spawn_actors()
	if not new_game:
		lives = 4
		for p in pacs:
			if p != null and is_instance_valid(p):
				p.lives = 4
	_reset_round_state()
	state = Config.READY
	paused = false
	if new_game:
		fruit_history = []
	if not silent:
		audio.play("intro" if new_game else "start")
	world.visible = true
	snapshot_full = true

func _reset_after_death(p) -> void:
	if p == null:
		state = Config.PLAYING
		return
	p.respawn(p.spawn_tile)
	mode = "scatter"
	mode_idx = 0
	mode_timer = Config.MODE_SCHEDULE[0][0]
	frightened = false
	fright_timer = 0.0
	ghost_combo = 0
	freeze_timer = 0.0
	fruit_active = false
	ready_timer = 1.2
	death_timer = 0.0
	shake = 0.0
	state = Config.READY
	audio.stop_loop()
	audio.play("start", 0.7)
	world.visible = true

func start_new_game() -> void:
	score = 0
	lives = 4
	level = 1
	next_extra = 10000
	popups = []
	particles = []
	audio.stop_all()
	_clear_actors()
	_setup_level(true)

func start_local_single() -> void:
	online_role = "offline"
	online_mode = MODE_TEAM
	roster = []
	online_ghost_names = []
	local_player_id = "local"
	local_custom_mode = false
	dying_player = ""
	winner = ""
	lobby.hide_lobby()
	hud.visible = true
	if intro:
		intro.hide_intro()
	if backdrop:
		backdrop.visible = false
	if fullscreen_button:
		fullscreen_button.visible = false
	start_new_game()
	_update_touch_visibility()

func start_local_practice() -> void:
	online_role = "offline"
	local_player_id = "local"
	local_custom_mode = false
	dying_player = ""
	winner = ""
	if lobby:
		lobby.local_practice = true
		lobby.show_local_practice()
	world.visible = false
	hud.visible = false
	if intro:
		intro.hide_intro()
	if backdrop:
		backdrop.visible = true
	if fullscreen_button:
		fullscreen_button.visible = true
	_update_touch_visibility()

func start_local_custom() -> void:
	local_custom_mode = true
	var payload := build_start_payload()
	if payload.is_empty():
		if lobby:
			lobby.set_status("FALTA UN PAC-MAN. AGREGA UN BOT O CAMBIA DE ROL.", Config.RED)
		return
	_begin_local(payload)

func _begin_local(data: Dictionary) -> void:
	online_role = "offline"
	online_mode = str(data.get("mode", MODE_TEAM))
	roster = data.get("roster", [])
	online_ghost_names = []
	for gn in data.get("ghosts", []):
		if Config.GHOST_ORDER.has(gn) and not online_ghost_names.has(gn):
			online_ghost_names.append(gn)
	if online_ghost_names.is_empty():
		online_ghost_names = GHOST_NAMES.duplicate()
	local_player_id = "local"
	level = 1
	score = 0
	lives = 4
	next_extra = 10000
	popups = []
	particles = []
	fruit_history = []
	dying_player = ""
	winner = ""
	maze.reset()
	_clear_actors()
	_spawn_actors()
	_reset_round_state()
	state = Config.READY
	ready_timer = Config.READY_TIME
	world.visible = true
	if lobby:
		lobby.hide_lobby()
	if intro:
		intro.hide_intro()
	if backdrop:
		backdrop.visible = false
	if fullscreen_button:
		fullscreen_button.visible = false
	_set_zoom(false)
	hud.visible = true
	audio.stop_all()
	audio.play("intro")
	pending_inputs.clear()
	local_input_seq = 0
	last_snapshot_time = 0.0
	_update_touch_visibility()
	audio.stop_all()

# ------------------------------------------------------------------- update
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	time += dt
	_update_effects(dt)
	if backdrop:
		backdrop.visible = state == Config.LOBBY
	if fullscreen_button:
		fullscreen_button.visible = state == Config.LOBBY
	if hd_button:
		hd_button.visible = state == Config.LOBBY
		hd_button.text = "HD: " + ("ON" if use_hd_sprites else "OFF")

	if state == Config.LOBBY:
		menu_time += dt
		return
	if online_role == "client":
		_client_process(dt)
		return
	if state == Config.GAME_OVER:
		gameover_timer += dt
	elif not paused:
		if state == Config.READY:
			ready_timer -= dt
			if ready_timer <= 0.0:
				state = Config.PLAYING
				audio.set_loop("siren", 0.42)
		elif state == Config.PLAYING:
			_update_play(dt)
		elif state == Config.DYING:
			death_timer -= dt
			if death_timer <= 0.0:
				_after_death()
		elif state == Config.LEVEL_CLEAR:
			level_timer -= dt
			if level_timer <= 0.0:
				level += 1
				_setup_level()
				if online_role == "host":
					_host_send_snapshot(true)
	_sync_visuals()

	if online_role == "host":
		snapshot_accum += dt
		if snapshot_accum >= Config.NET_TICK:
			snapshot_accum = 0.0
			_host_send_snapshot()

func _client_process(dt: float) -> void:
	if paused:
		_sync_visuals_client()
		return
	for p in pacs:
		if p == null or not is_instance_valid(p):
			continue
		if p == _local_pac():
			p.update_pac(dt)
			var dist: int = abs(p.tile.x - host_local_tile.x) + abs(p.tile.y - host_local_tile.y)
			if dist > 5:
				p.tile = host_local_tile
				p.progress = host_local_progress
				if Config.DIRS.has(host_local_dir):
					p.dir = Config.DIRS[host_local_dir]
		else:
			p.interpolate_network(dt)
	for g in ghosts:
		if g == null or not is_instance_valid(g):
			continue
		if g == _local_ghost():
			g.update_ghost(dt)
			var gdist: int = abs(g.tile.x - host_local_tile.x) + abs(g.tile.y - host_local_tile.y)
			if gdist > 5:
				g.tile = host_local_tile
				g.progress = host_local_progress
				if Config.DIRS.has(host_local_dir):
					g.dir = Config.DIRS[host_local_dir]
		else:
			g.interpolate_network(dt)
	_sync_visuals_client()

func _update_play(dt: float) -> void:
	if freeze_timer > 0.0:
		freeze_timer -= dt
		return

	_update_mode(dt)
	if frightened:
		fright_timer -= dt
		if fright_timer <= 0.0:
			_end_fright()

	for p in pacs:
		if p == null or not p.active:
			continue
		if p.is_ai:
			_ai_pac_update(p, dt)
		else:
			p.update_pac(dt)
		for tile in p.take_arrivals():
			_eat(p, tile)

	for g in ghosts:
		g.update_ghost(dt)
	_update_fruit(dt)
	if _check_collisions():
		return

	if maze.remaining() == 0:
		_start_level_clear()
		return

	if frightened:
		audio.set_loop("fright", 0.50)
	else:
		audio.set_loop("siren", 0.42)

func _update_mode(dt: float) -> void:
	if frightened:
		return
	mode_timer -= dt
	if mode_timer > 0.0:
		return
	mode_idx += 1
	if mode_idx < Config.MODE_SCHEDULE.size():
		var entry = Config.MODE_SCHEDULE[mode_idx]
		mode_timer = entry[0]
		mode = entry[1]
	else:
		mode = "chase"
		mode_timer = Config.CHASE_FOREVER
	for g in ghosts:
		g.reverse()

func _ai_pac_update(p, dt: float) -> void:
	if p.progress <= 1e-9 or p.desired == null:
		var best = null
		var best_score := 1e9
		for d in Config.DIR_ORDER:
			var nt = maze.neighbor(p.tile, d)
			if not maze.is_walkable(nt, true):
				continue
			if p.dir != null and d == Vector2i(-p.dir.x, -p.dir.y):
				continue
			var pellet_dist: int = maze.distance_to_nearest_pellet(nt)
			var ghost_dist := 999.0
			for g in ghosts:
				if g == null or not is_instance_valid(g):
					continue
				if g.state in ["eaten", "dead", "house"]:
					continue
				var gd := float(abs(nt.x - g.tile.x) + abs(nt.y - g.tile.y))
				if gd < ghost_dist:
					ghost_dist = gd
			var score := float(pellet_dist)
			if frightened and ghost_dist < 12.0:
				# En modo poder, perseguir al fantasma mas cercano.
				score = ghost_dist * 0.8
			elif frightened:
				score = float(pellet_dist)
			elif ghost_dist <= 5.0:
				# Evitar fantasmas peligrosos, con mas fuerza cuanto mas cerca.
				score += (6.0 - ghost_dist) * 12.0
			if p.dir == d:
				score -= 0.35
			if score < best_score:
				best_score = score
				best = d
		if best == null:
			for d in Config.DIR_ORDER:
				var nt = maze.neighbor(p.tile, d)
				if maze.is_walkable(nt, true):
					best = d
					break
		if best != null:
			p.desired = best
	p.update_pac(dt)

# -------------------------------------------------------------------- rules
func add_score(points: int, p = null) -> void:
	score += points
	if p != null:
		p.score += points
	if score > high_score:
		high_score = score
	while score >= next_extra:
		if p != null:
			p.lives += 1
		else:
			lives += 1
		next_extra += 10000
		audio.play("extra", 0.7)
		if p != null:
			var pp: Vector2 = p.pos()
			popup(pp.x, pp.y - 8.0, "1UP", Config.GREEN, 10)
		if online_role == "host":
			net_events.append({"t": "extra"})

func _eat(p, tile: Vector2i) -> void:
	var value: int = maze.eat(tile)
	if value == 0:
		return
	pellets_eaten += 1
	if online_role == "host":
		eaten_delta.append([tile.x, tile.y])
	if value >= 50:
		add_score(50, p)
		audio.play("power", 0.7)
		frightened = true
		fright_timer = maxf(2.0, 8.0 - (level - 1) * 0.6)
		ghost_combo = 0
		for g in ghosts:
			g.set_frightened(true)
		for g in ghosts:
			if g.state in ["normal", "leaving"]:
				g.reverse()
		shake = maxf(shake, 0.12)
		if online_role == "host":
			net_events.append({"t": "power"})
	else:
		add_score(10, p)
		audio.play_waka(waka_toggle)
		if online_role == "host":
			net_events.append({"t": "waka", "alt": waka_toggle})
		waka_toggle = not waka_toggle
	_check_fruit_spawn()

func _end_fright() -> void:
	frightened = false
	fright_timer = 0.0
	ghost_combo = 0
	for g in ghosts:
		g.set_frightened(false)

func _check_fruit_spawn() -> void:
	var thresholds := [70, 170]
	for i in range(2):
		if not fruit_thresholds[i] and pellets_eaten >= thresholds[i]:
			fruit_thresholds[i] = true
			fruit_active = true
			fruit_timer = Config.FRUIT_TIME
			audio.play("fruit", 0.5)

func _update_fruit(dt: float) -> void:
	if not fruit_active:
		return
	fruit_timer -= dt
	if fruit_timer <= 0.0:
		fruit_active = false
		return
	var fx: Vector2 = maze.center(Config.FRUIT_TILE)
	for p in pacs:
		if p == null or not p.active:
			continue
		var px: Vector2 = p.pos()
		if px.distance_squared_to(fx) < 15.0 * 15.0:
			var idx: int = mini(level - 1, 7)
			var pts: int = Config.FRUIT_SCORE[idx]
			add_score(pts, p)
			popup(fx.x, fx.y - 6.0, str(pts), Config.PINK, 8)
			_burst(fx.x, fx.y, Config.PINK, 16)
			fruit_active = false
			audio.play("fruit", 0.7)
			if fruit_history.size() < 8:
				fruit_history.append(Config.FRUIT_COLUMNS[idx])
			if online_role == "host":
				net_events.append({
					"t": "fruit", "x": fx.x, "y": fx.y, "pts": pts,
					"col": Config.FRUIT_COLUMNS[idx],
				})
			break

func _check_collisions() -> bool:
	for p in pacs:
		if p == null or not p.active:
			continue
		var ppos: Vector2 = p.pos()
		for g in ghosts:
			if g.state in ["eaten", "dead", "house"]:
				continue
			var gpos: Vector2 = g.pos()
			if ppos.distance_squared_to(gpos) > 12.5 * 12.5:
				continue
			if g.is_edible():
				_eat_ghost(p, g)
				return true
			_die(p, g)
			return true
	return false

func _eat_ghost(p, g) -> void:
	var points := 200 * int(pow(2, mini(ghost_combo, 3)))
	ghost_combo += 1
	add_score(points, p)
	var gp: Vector2 = g.pos()
	popup(gp.x, gp.y - 6.0, str(points), Config.CYAN, 8)
	_burst(gp.x, gp.y, Config.CYAN, 16)
	g.eaten_by_player()
	audio.play("eatghost", 0.7)
	shake = maxf(shake, 0.18)
	freeze_timer = 0.42
	if online_role == "host":
		net_events.append({"t": "ghost", "x": gp.x, "y": gp.y, "pts": points})

func _die(p, g = null) -> void:
	if p == null or not p.active:
		return
	p.lives -= 1
	lives = p.lives
	if g != null and g.is_player:
		g.score += Config.GHOST_CATCH_SCORE
	state = Config.DYING
	death_timer = Config.DEATH_TIME
	dying_player = p.player_id
	paused = false
	audio.stop_loop()
	audio.play("death", 0.8)
	shake = 0.6
	freeze_timer = 0.0
	if online_role == "host":
		var pp: Vector2 = p.pos()
		net_events.append({
			"t": "death", "x": pp.x, "y": pp.y, "pid": p.player_id,
			"gid": g.player_id if g != null else "",
		})

func _after_death() -> void:
	var p = _find_pac_by_id(dying_player)
	if p == null:
		state = Config.PLAYING
		dying_player = ""
		return
	if p.lives > 0:
		_reset_after_death(p)
		dying_player = ""
		return
	p.active = false
	p.visible = false
	dying_player = ""
	var any_active := false
	for q in pacs:
		if q.active:
			any_active = true
			break
	if not any_active:
		_game_over("ghosts" if online_mode == MODE_GHOST else "")
	else:
		state = Config.PLAYING
		audio.set_loop("siren", 0.42)

func _start_level_clear() -> void:
	state = Config.LEVEL_CLEAR
	level_timer = Config.LEVEL_CLEAR_TIME
	fruit_active = false
	audio.stop_loop()
	audio.play("extra", 0.7)
	shake = 0.0
	if online_role == "host":
		net_events.append({"t": "levelclear"})

func _game_over(winning_side := "") -> void:
	state = Config.GAME_OVER
	gameover_timer = 0.0
	winner = winning_side
	high_score = maxi(high_score, score)
	save_high()
	audio.stop_all()
	if online_role == "host":
		net_events.append({"t": "gameover", "winner": winning_side})
		_host_send_snapshot(true)

# ----------------------------------------------------------------------- IA
func _active_pacs() -> Array:
	var out: Array = []
	for p in pacs:
		if p != null and p.active:
			out.append(p)
	return out

func _target_pac(g):
	var active := _active_pacs()
	if active.is_empty():
		return null
	var idx: int = GHOST_NAMES.find(g.ghost_name)
	if idx < 0:
		idx = 0
	return active[idx % active.size()]

func ghost_target(g) -> Vector2i:
	if mode == "scatter":
		var st: Vector2i = Config.SCATTER_TARGETS[g.ghost_name]
		return st
	var target = _target_pac(g)
	if target == null:
		return Config.SCATTER_TARGETS[g.ghost_name]
	var pt: Vector2i = target.tile
	var d: Vector2i = target.dir if target.dir != null else Vector2i(-1, 0)
	if g.ghost_name == "blinky":
		return pt
	if g.ghost_name == "pinky":
		return pt + d * 4
	if g.ghost_name == "inky":
		var b: Vector2i = Config.HOUSE_EXIT
		for other in ghosts:
			if other != null and other.ghost_name == "blinky":
				b = other.tile
				break
		var p2: Vector2i = pt + d * 2
		return p2 * 2 - b
	var dx: int = g.tile.x - pt.x
	var dy: int = g.tile.y - pt.y
	if dx * dx + dy * dy > 64:
		return pt
	var ct: Vector2i = Config.SCATTER_TARGETS["clyde"]
	return ct

func _find_pac_by_id(pid: String):
	for p in pacs:
		if p != null and p.player_id == pid:
			return p
	return null

func _find_ghost_by_id(pid: String):
	for g in ghosts:
		if g != null and g.player_id == pid:
			return g
	return null

func _local_pac():
	if local_player_id == "":
		return pac
	return _find_pac_by_id(local_player_id)

func _local_ghost():
	if local_player_id == "":
		return null
	return _find_ghost_by_id(local_player_id)

func _reconcile_local_pac(last_seq: int) -> void:
	var remaining: Array = []
	for inp in pending_inputs:
		if int(inp.get("seq", 0)) > last_seq and str(inp.get("kind", "")) == "pac":
			remaining.append(inp)
	pending_inputs = remaining

func _reconcile_local_ghost(last_seq: int) -> void:
	var remaining: Array = []
	for inp in pending_inputs:
		if int(inp.get("seq", 0)) > last_seq and str(inp.get("kind", "")) == "ghost":
			remaining.append(inp)
	pending_inputs = remaining

# -------------------------------------------------------------------- effect
func popup(x: float, y: float, text: String, color: Color, size := 8) -> void:
	popups.append({"x": x, "y": y, "text": text, "color": color, "size": size, "life": 1.0})

func _burst(x: float, y: float, color: Color, count := 12) -> void:
	for i in range(count):
		var ang := randf() * TAU
		var spd := randf_range(25.0, 95.0)
		particles.append({
			"x": x, "y": y,
			"vx": cos(ang) * spd, "vy": sin(ang) * spd,
			"life": randf_range(0.35, 0.7), "max": 0.7,
			"color": color, "size": [1, 2, 2, 3][randi() % 4],
		})

func _update_effects(dt: float) -> void:
	for p in popups:
		p["life"] -= dt
		p["y"] -= 20.0 * dt
	var keep: Array = []
	for p in popups:
		if p["life"] > 0.0:
			keep.append(p)
	popups = keep

	for p in particles:
		p["life"] -= dt
		p["x"] += p["vx"] * dt
		p["y"] += p["vy"] * dt
		p["vy"] += 60.0 * dt
		p["vx"] *= 0.985
	var keep2: Array = []
	for p in particles:
		if p["life"] > 0.0:
			keep2.append(p)
	particles = keep2

	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 1.4)

func _shake_offset() -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	var amp := minf(7.0, shake * 11.0)
	return Vector2(sin(time * 93.0) * amp, cos(time * 71.0) * amp)

func _animate_death(p) -> void:
	var prog := clampf((Config.DEATH_TIME - death_timer) / 1.55, 0.0, 1.0)
	p.position = p.pos()
	p.frame = 0
	p.pause()
	if prog < 0.01:
		p.scale = Vector2.ONE
		p.rotation = 0.0
		p.modulate.a = 1.0
	else:
		p.rotation = deg_to_rad(prog * 540.0)
		p.scale = Vector2.ONE * maxf(0.06, 1.0 - prog)
		p.modulate.a = 1.0 - prog * 0.55

func _sync_visuals() -> void:
	world.position = Vector2(Config.MAZE_X, Config.MAZE_Y) + _shake_offset()

	for p in pacs:
		if p == null or not is_instance_valid(p):
			continue
		p.visible = p.active and state != Config.GAME_OVER
		if not p.visible:
			continue
		if state == Config.DYING and p.player_id == dying_player:
			_animate_death(p)
		else:
			p.scale = Vector2.ONE
			p.modulate = Color.WHITE
			p.sync_visual()

	for g in ghosts:
		if not is_instance_valid(g):
			continue
		g.visible = not (state in [Config.DYING, Config.GAME_OVER])
		if g.visible:
			g.sync_visual()

	_sync_fruit()

func _sync_visuals_client() -> void:
	world.position = Vector2(Config.MAZE_X, Config.MAZE_Y) + _shake_offset()
	for p in pacs:
		if p == null or not is_instance_valid(p):
			continue
		p.visible = p.active and state != Config.GAME_OVER
		if not p.visible:
			continue
		if state == Config.DYING and p.player_id == dying_player:
			_animate_death(p)
		else:
			p.scale = Vector2.ONE
			p.modulate = Color.WHITE
			p.sync_visual()
	for g in ghosts:
		if g == null or not is_instance_valid(g):
			continue
		g.visible = g.net_visible and not (state in [Config.DYING, Config.GAME_OVER])
		if g.visible:
			g.sync_visual()
	_sync_fruit()

func _sync_fruit() -> void:
	if fruit_active and fruit_sprite != null and fruit_glow != null:
		var idx: int = mini(level - 1, 7)
		if idx < fruit_level_textures.size():
			fruit_sprite.texture = fruit_level_textures[idx]
		var fp: Vector2 = maze.center(Config.FRUIT_TILE)
		fp.y += sin(time * 4.0) * 2.0
		fruit_sprite.position = fp - Vector2(16, 16)
		fruit_glow.position = fp - Vector2(26, 26)
		var blink := fruit_timer < 2.4 and int(time * 8.0) % 2 == 0
		fruit_sprite.visible = not blink
		fruit_glow.visible = not blink
		var a := (55.0 + 30.0 * (0.5 + 0.5 * sin(time * 5.0))) / 255.0
		fruit_glow.modulate = Color(1, 1, 1, a)
	else:
		if fruit_sprite != null:
			fruit_sprite.visible = false
		if fruit_glow != null:
			fruit_glow.visible = false

# --------------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state in [Config.READY, Config.PLAYING] and not lobby.visible:
			var s := world.scale.x
			var rect := Rect2(world.position, Vector2(Config.MAZE_W, Config.MAZE_H) * s)
			if rect.has_point(event.position) or zoomed:
				_set_zoom(not zoomed)
				return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode, event.physical_keycode)

func _start_key(k: int) -> bool:
	return k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE

func _handle_key(k: int, pk: int) -> void:
	if k == KEY_Z:
		if state in [Config.READY, Config.PLAYING]:
			_set_zoom(not zoomed)
		return
	if k == KEY_F11 or k == KEY_F:
		toggle_fullscreen()
		return
	if k == KEY_M or pk == KEY_M:
		_toggle_mute()
		return

	if state == Config.LOBBY:
		return

	if state == Config.GAME_OVER:
		if online_role in ["offline", "host"] and (_start_key(k) or _start_key(pk)):
			if online_role == "host":
				_restart_online()
			elif local_custom_mode:
				start_local_custom()
			else:
				start_local_single()
		elif k == KEY_ESCAPE:
			_return_to_lobby()
		return

	if paused:
		if k == KEY_ESCAPE and online_role == "client":
			_return_to_lobby()
			return
		if k == KEY_P or k == KEY_ESCAPE:
			toggle_pause()
		return

	if k == KEY_P:
		toggle_pause()
		return
	if k == KEY_ESCAPE:
		_return_to_lobby()
		return

	if state in [Config.READY, Config.PLAYING]:
		if k == KEY_LEFT or k == KEY_A or pk == KEY_A:
			set_local_dir("left")
		elif k == KEY_RIGHT or k == KEY_D or pk == KEY_D:
			set_local_dir("right")
		elif k == KEY_UP or k == KEY_W or pk == KEY_W:
			set_local_dir("up")
		elif k == KEY_DOWN or k == KEY_S or pk == KEY_S:
			set_local_dir("down")

func set_local_dir(dir_name: String) -> void:
	if not Config.DIRS.has(dir_name):
		return
	var d = Config.DIRS[dir_name]
	if online_role == "client":
		if net != null:
			local_input_seq += 1
			net.send_dict({"type": "input", "data": {"dir": dir_name, "seq": local_input_seq}})
		# Respuesta inmediata local para reducir el lag percibido.
		var p = _local_pac()
		if p != null and p.active:
			p.desired = d
			p.update_pac(0.0)
			pending_inputs.append({"seq": local_input_seq, "dir": dir_name, "time": time, "kind": "pac"})
		var g = _local_ghost()
		if g != null:
			g.desired_dir = d
			g.update_ghost(0.0)
			pending_inputs.append({"seq": local_input_seq, "dir": dir_name, "time": time, "kind": "ghost"})
		return
	var p = _local_pac()
	if p != null and p.active:
		p.desired = d
	var g = _local_ghost()
	if g != null:
		g.desired_dir = d

func toggle_pause() -> void:
	if online_role == "client":
		return
	if not (state in [Config.PLAYING, Config.READY]):
		return
	paused = not paused
	if paused:
		audio.stop_loop()
	elif state == Config.PLAYING:
		audio.set_loop("fright" if frightened else "siren", 0.42)
	if online_role == "host":
		_host_send_snapshot(true)

func _toggle_mute() -> void:
	audio.toggle_mute()
	if not audio.muted and state == Config.PLAYING and not paused:
		audio.set_loop("fright" if frightened else "siren", 0.42)

func _quit_game() -> void:
	high_score = maxi(high_score, score)
	save_high()
	if audio != null:
		audio.stop_all()
	if net != null:
		net.close()
	get_tree().quit()

# ------------------------------------------------------------------ online
func _connect_network() -> void:
	net = NetClient.new()
	net.name = "Net"
	net.connected.connect(_on_net_connected)
	net.disconnected.connect(_on_net_disconnected)
	net.welcome.connect(_on_net_welcome)
	net.room_updated.connect(_on_room_updated)
	net.started.connect(_on_net_started)
	net.snapshot.connect(_on_net_snapshot)
	net.input_received.connect(_on_net_input)
	net.room_closed.connect(_on_room_closed)
	net.lobby_return.connect(_on_lobby_return)
	net.peer_left.connect(_on_peer_left)
	net.error_message.connect(_on_net_error)
	add_child(net)

func _on_net_connected() -> void:
	if lobby:
		lobby.set_connected(true)

func _on_net_disconnected() -> void:
	if lobby:
		lobby.set_connected(false)
		lobby.set_status("DESCONECTADO. RECONECTANDO...", Config.RED)
	if state != Config.LOBBY and online_role != "offline":
		if lobby:
			lobby.reset_room()
		_reset_to_lobby("CONEXION PERDIDA. VUELVE A ENTRAR.")

func _on_net_welcome(player_id: String, host_id: String, room_code: String) -> void:
	local_player_id = player_id
	if lobby:
		lobby.on_welcome(player_id, host_id, room_code)

func _on_room_updated(room: Dictionary) -> void:
	if lobby:
		lobby.on_room(room)
	if online_role == "host" and state != Config.LOBBY:
		_mark_connections(room)

func _mark_connections(room: Dictionary) -> void:
	var connected_ids := {}
	for p in room.get("players", []):
		connected_ids[str(p.get("id", ""))] = true
	for p in pacs:
		if p != null and p.player_id != "" and not p.player_id.begins_with("ai_"):
			p.connected = connected_ids.has(p.player_id)
			if not p.connected:
				p.is_ai = true
	for g in ghosts:
		if g != null and g.player_id != "" and not g.player_id.begins_with("ai_"):
			g.connected = connected_ids.has(g.player_id)
			if not g.connected:
				g.desired_dir = null

func _on_net_started(data: Dictionary) -> void:
	if online_role == "host":
		return
	if data.is_empty():
		return
	_begin_online(data, false)

func _on_net_snapshot(data: Dictionary) -> void:
	if online_role != "client":
		return
	_apply_snapshot(data)

func _on_net_input(msg: Dictionary) -> void:
	if online_role != "host":
		return
	var pid := str(msg.get("playerId", ""))
	var data = msg.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return
	var dname := str(data.get("dir", ""))
	if not Config.DIRS.has(dname):
		return
	var seq := int(data.get("seq", 0))
	if seq > 0:
		last_input_seq[pid] = seq
	var p = _find_pac_by_id(pid)
	if p != null and p.active:
		p.desired = Config.DIRS[dname]
		p.update_pac(0.0)
	var g = _find_ghost_by_id(pid)
	if g != null:
		g.desired_dir = Config.DIRS[dname]
		g.update_ghost(0.0)
	_host_send_snapshot()

func _on_room_closed(reason: String) -> void:
	if lobby:
		lobby.reset_room()
		lobby.set_status("SALA CERRADA (%s)" % reason, Config.RED)
	_reset_to_lobby("")

func _on_lobby_return() -> void:
	_reset_to_lobby("")

func _on_peer_left(pid: String) -> void:
	if lobby:
		lobby.set_status("UN JUGADOR SALIÓ", Config.ORANGE)

func _on_net_error(text: String) -> void:
	if lobby:
		lobby.set_status(text, Config.RED)

func _next_free_color(used: Dictionary) -> String:
	for c in Config.PAC_COLOR_ORDER:
		if not used.has(c):
			return str(c)
	return Config.PAC_COLOR_ORDER[0]

func _next_free_ghost_name(used: Dictionary) -> String:
	for n in Config.GHOST_ORDER:
		if not used.has(n):
			return str(n)
	return Config.GHOST_ORDER[0]

func build_start_payload() -> Dictionary:
	var players: Array = []
	if lobby != null and lobby.room is Dictionary:
		players = lobby.room.get("players", [])

	var human_pacs: Array = []
	var human_ghosts: Array = []
	for p in players:
		if str(p.get("role", "pac")) == "ghost":
			human_ghosts.append(p)
		else:
			human_pacs.append(p)

	var requested_bots := int(lobby.selected_bots) if lobby != null else 2
	var free_pac_slots := maxi(0, 4 - human_pacs.size())
	var bot_count := clampi(requested_bots, 0, free_pac_slots)
	if human_pacs.size() + bot_count < 1:
		return {}

	# Fantasmas IA:
	# - online: se completa la banda si no hay humanos o hay bots Pac-Man.
	# - practica local: cantidad elegida por separado.
	var ghost_bot_count := 0
	var available_ghost_slots := maxi(0, 4 - human_ghosts.size())
	if lobby != null and lobby.local_practice:
		ghost_bot_count = clampi(int(lobby.selected_ghost_bots), 0, available_ghost_slots)
	else:
		if human_ghosts.is_empty() or bot_count > 0:
			ghost_bot_count = available_ghost_slots

	var used_colors: Dictionary = {}
	var roster_out: Array = []
	for i in range(human_pacs.size()):
		var pl: Dictionary = human_pacs[i]
		var chosen := str(pl.get("color", "yellow"))
		if used_colors.has(chosen):
			chosen = _next_free_color(used_colors)
		used_colors[chosen] = true
		roster_out.append({
			"id": str(pl.get("id", "p_%d" % i)),
			"name": str(pl.get("name", "JUGADOR")),
			"color": chosen,
			"role": "pac",
			"pac_index": i,
			"ai": false,
			"connected": true,
		})

	for j in range(bot_count):
		var idx := human_pacs.size() + j
		var chosen := _next_free_color(used_colors)
		used_colors[chosen] = true
		roster_out.append({
			"id": "ai_pac_%d" % idx,
			"name": "BOT",
			"color": chosen,
			"role": "pac",
			"pac_index": idx,
			"ai": true,
			"connected": true,
		})

	# Fantasmas activos: humanos + la cantidad de fantasmas IA elegida.
	var used_ghosts: Dictionary = {}
	var active_ghosts: Array = []
	var human_ghost_names: Array = []
	for pl in human_ghosts:
		var gn := str(pl.get("ghost_name", "blinky"))
		if not Config.GHOST_ORDER.has(gn) or used_ghosts.has(gn):
			gn = _next_free_ghost_name(used_ghosts)
		used_ghosts[gn] = true
		human_ghost_names.append(gn)
		roster_out.append({
			"id": str(pl.get("id", "g_" + gn)),
			"name": str(pl.get("name", "JUGADOR")),
			"role": "ghost",
			"ghost_name": gn,
			"ai": false,
			"connected": true,
		})
	for gn in human_ghost_names:
		active_ghosts.append(gn)

	var added_ghost_bots := 0
	for gn in Config.GHOST_ORDER:
		if added_ghost_bots >= ghost_bot_count:
			break
		if used_ghosts.has(gn):
			continue
		used_ghosts[gn] = true
		active_ghosts.append(gn)
		added_ghost_bots += 1

	var pac_count := human_pacs.size() + bot_count
	var mode_now := MODE_TEAM if pac_count >= 4 and human_ghosts.is_empty() else MODE_GHOST
	return {
		"mode": mode_now,
		"pac_count": pac_count,
		"bots": bot_count,
		"roster": roster_out,
		"ghosts": active_ghosts,
		"seed": randi(),
	}

func start_host_game() -> void:
	var payload := build_start_payload()
	if payload.is_empty():
		if lobby:
			lobby.set_status("FALTA UN PAC-MAN. AGREGA UN BOT O CAMBIA DE ROL.", Config.RED)
		return
	if net == null or not net.send_dict({"type": "start", "data": payload}):
		if lobby:
			lobby.set_status("NO HAY CONEXIÓN CON EL SERVIDOR", Config.RED)
		return
	_begin_online(payload, true)

func _begin_online(data: Dictionary, is_host: bool) -> void:
	online_role = "host" if is_host else "client"
	online_mode = str(data.get("mode", MODE_TEAM))
	roster = data.get("roster", [])
	local_custom_mode = false
	online_ghost_names = []
	for gn in data.get("ghosts", []):
		if Config.GHOST_ORDER.has(gn) and not online_ghost_names.has(gn):
			online_ghost_names.append(gn)
	if online_ghost_names.is_empty():
		online_ghost_names = GHOST_NAMES.duplicate()
	local_player_id = net.player_id if net != null else ""
	level = 1
	score = 0
	lives = 4
	next_extra = 10000
	popups = []
	particles = []
	fruit_history = []
	dying_player = ""
	winner = ""
	maze.reset()
	_clear_actors()
	_spawn_actors()
	_reset_round_state()
	state = Config.READY
	ready_timer = Config.ONLINE_READY_TIME
	world.visible = true
	if lobby:
		lobby.hide_lobby()
	if intro:
		intro.hide_intro()
	if backdrop:
		backdrop.visible = false
	if fullscreen_button:
		fullscreen_button.visible = false
	_set_zoom(false)
	hud.visible = true
	audio.stop_all()
	audio.play("intro")
	snapshot_full = true
	snapshot_accum = 0.0
	eaten_delta = []
	net_events = []
	client_snapshot_seen = false
	client_paused = false
	pending_inputs.clear()
	local_input_seq = 0
	last_snapshot_time = 0.0
	if is_host:
		_host_send_snapshot(true)
	_update_touch_visibility()

func _restart_online() -> void:
	if online_role != "host":
		return
	var data := build_start_payload()
	if data.is_empty():
		return
	net.send_dict({"type": "start", "data": data})
	_begin_online(data, true)

func _return_to_lobby() -> void:
	if online_role == "host" and net != null:
		net.send_dict({"type": "lobby_return"})
	elif online_role == "client" and net != null:
		net.send_dict({"type": "leave"})
	_reset_to_lobby("")

func _reset_to_lobby(message := "") -> void:
	_set_zoom(false)
	state = Config.LOBBY
	paused = false
	world.visible = false
	hud.visible = false
	online_role = "offline"
	roster = []
	online_ghost_names = []
	local_custom_mode = false
	dying_player = ""
	winner = ""
	_clear_actors()
	maze.reset()
	popups = []
	particles = []
	audio.stop_all()
	if intro:
		intro.hide_intro()
	if backdrop:
		backdrop.visible = true
	if fullscreen_button:
		fullscreen_button.visible = true
	if lobby:
		lobby.local_practice = false
		lobby.show_lobby()
		if message != "":
			lobby.set_status(message, Config.YELLOW)
	if touch_ui:
		touch_ui.hide()

func _host_send_snapshot(force := false) -> void:
	if online_role != "host" or net == null:
		return
	var data := build_snapshot()
	data["ev"] = net_events.duplicate()
	net_events.clear()
	if snapshot_full or force:
		data["ps"] = _pellet_list()
		snapshot_full = false
	else:
		data["e"] = eaten_delta.duplicate()
	eaten_delta.clear()
	net.send_dict({"type": "snapshot", "data": data})

func _pellet_list() -> Array:
	var out: Array = []
	for tile in maze.pellets.keys():
		out.append([tile.x, tile.y, int(maze.pellets[tile])])
	return out

func _dir_name(d) -> String:
	if d == null:
		return ""
	if d == Vector2i(1, 0):
		return "right"
	if d == Vector2i(-1, 0):
		return "left"
	if d == Vector2i(0, -1):
		return "up"
	return "down"

func build_snapshot() -> Dictionary:
	var data := {
		"s": state,
		"t": time,
		"p": int(paused),
		"l": level,
		"sc": score,
		"ne": next_extra,
		"m": mode,
		"mt": mode_timer,
		"f": int(frightened),
		"ft": fright_timer,
		"gc": ghost_combo,
		"rt": ready_timer,
		"dt": death_timer,
		"lt": level_timer,
		"gt": gameover_timer,
		"fa": int(fruit_active),
		"ftm": fruit_timer,
		"fh": fruit_history.duplicate(),
		"pe": pellets_eaten,
		"dp": dying_player,
		"win": winner,
		"pa": [],
		"gh": [],
	}
	for p in pacs:
		if p == null:
			continue
		data["pa"].append({
			"id": p.player_id,
			"x": p.tile.x,
			"y": p.tile.y,
			"d": _dir_name(p.dir),
			"p": p.progress,
			"c": p.color_id,
			"sc": p.score,
			"lv": p.lives,
			"mv": int(p.moving),
			"an": p.anim,
			"vis": int(p.active),
			"seq": int(last_input_seq.get(p.player_id, 0)),
		})
	for g in ghosts:
		if g == null:
			continue
		data["gh"].append({
			"n": g.ghost_name,
			"x": g.tile.x,
			"y": g.tile.y,
			"d": _dir_name(g.dir),
			"p": g.progress,
			"st": g.state,
			"fr": int(g.frightened),
			"an": g.anim,
			"vis": int(g.visible),
			"pid": g.player_id,
			"sc": g.score,
			"seq": int(last_input_seq.get(g.player_id, 0)),
		})
	return data

func _apply_snapshot(data: Dictionary) -> void:
	client_snapshot_seen = true
	if data.has("ps"):
		maze.pellets.clear()
		for e in data["ps"]:
			if e.size() >= 3:
				maze.pellets[Vector2i(int(e[0]), int(e[1]))] = int(e[2])
	if data.has("e"):
		for e in data["e"]:
			if e.size() >= 2:
				maze.pellets.erase(Vector2i(int(e[0]), int(e[1])))
	last_snapshot_time = float(data.get("t", last_snapshot_time))
	state = str(data.get("s", Config.READY))
	client_paused = bool(int(data.get("p", 0)))
	paused = client_paused
	time = maxf(time, float(data.get("t", time)))
	level = int(data.get("l", 1))
	score = int(data.get("sc", 0))
	next_extra = int(data.get("ne", 10000))
	mode = str(data.get("m", "scatter"))
	mode_timer = float(data.get("mt", 0.0))
	frightened = bool(int(data.get("f", 0)))
	fright_timer = float(data.get("ft", 0.0))
	ghost_combo = int(data.get("gc", 0))
	ready_timer = float(data.get("rt", 0.0))
	death_timer = float(data.get("dt", 0.0))
	level_timer = float(data.get("lt", 0.0))
	gameover_timer = float(data.get("gt", 0.0))
	fruit_active = bool(int(data.get("fa", 0)))
	fruit_timer = float(data.get("ftm", 0.0))
	fruit_history = data.get("fh", [])
	pellets_eaten = int(data.get("pe", 0))
	dying_player = str(data.get("dp", ""))
	winner = str(data.get("win", ""))

	var local_pac_seq := 0
	for e in data.get("pa", []):
		var p = _find_pac_by_id(str(e.get("id", "")))
		if p == null:
			continue
		if p == _local_pac():
			local_pac_seq = int(e.get("seq", 0))
			p.color_id = str(e.get("c", p.color_id))
			p.score = int(e.get("sc", p.score))
			p.lives = int(e.get("lv", p.lives))
			host_local_tile = Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))
			host_local_progress = float(e.get("p", 0.0))
			host_local_dir = str(e.get("d", ""))
			continue
		p.color_id = str(e.get("c", p.color_id))
		p.score = int(e.get("sc", p.score))
		p.lives = int(e.get("lv", p.lives))
		p.apply_network(
			Vector2i(int(e.get("x", 0)), int(e.get("y", 0))),
			str(e.get("d", "")),
			float(e.get("p", 0.0)),
			bool(int(e.get("mv", 0))),
			float(e.get("an", 0.0)),
			bool(int(e.get("vis", 1))))
	var local_ghost_seq := 0
	for e in data.get("gh", []):
		var g = _find_ghost_by_name(str(e.get("n", "")))
		if g == null:
			continue
		if g == _local_ghost():
			local_ghost_seq = int(e.get("seq", 0))
			g.score = int(e.get("sc", g.score))
			var st := str(e.get("st", "normal"))
			host_local_tile = Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))
			host_local_progress = float(e.get("p", 0.0))
			host_local_dir = str(e.get("d", ""))
			if st in ["eaten", "dead", "house"]:
				g.apply_network(
					Vector2i(int(e.get("x", 0)), int(e.get("y", 0))),
					str(e.get("d", "")),
					float(e.get("p", 0.0)),
					st,
					bool(int(e.get("fr", 0))),
					float(e.get("an", 0.0)),
					bool(int(e.get("vis", 1))),
					str(e.get("pid", "")))
			continue
		g.score = int(e.get("sc", g.score))
		g.apply_network(
			Vector2i(int(e.get("x", 0)), int(e.get("y", 0))),
			str(e.get("d", "")),
			float(e.get("p", 0.0)),
			str(e.get("st", "normal")),
			bool(int(e.get("fr", 0))),
			float(e.get("an", 0.0)),
			bool(int(e.get("vis", 1))),
			str(e.get("pid", "")))
	_handle_events(data.get("ev", []))
	if paused:
		audio.stop_loop()
	elif state == Config.PLAYING:
		audio.set_loop("fright" if frightened else "siren", 0.42)
	elif state in [Config.READY, Config.DYING, Config.LEVEL_CLEAR, Config.GAME_OVER]:
		audio.stop_loop()
	_update_touch_visibility()

	if _local_pac() != null:
		_reconcile_local_pac(local_pac_seq)
	if _local_ghost() != null:
		_reconcile_local_ghost(local_ghost_seq)

func _find_ghost_by_name(n: String):
	for g in ghosts:
		if g.ghost_name == n:
			return g
	return null

func _handle_events(events: Array) -> void:
	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		match str(e.get("t", "")):
			"waka":
				audio.play_waka(bool(e.get("alt", false)))
			"power":
				audio.play("power", 0.7)
				shake = maxf(shake, 0.12)
			"ghost":
				var gx := float(e.get("x", 0.0))
				var gy := float(e.get("y", 0.0))
				var pts := int(e.get("pts", 200))
				audio.play("eatghost", 0.7)
				popup(gx, gy - 6.0, str(pts), Config.CYAN, 8)
				_burst(gx, gy, Config.CYAN, 16)
				shake = maxf(shake, 0.18)
			"fruit":
				var fx := float(e.get("x", 0.0))
				var fy := float(e.get("y", 0.0))
				var fp := int(e.get("pts", 100))
				audio.play("fruit", 0.7)
				popup(fx, fy - 6.0, str(fp), Config.PINK, 8)
				_burst(fx, fy, Config.PINK, 16)
			"death":
				audio.play("death", 0.8)
				shake = 0.6
			"extra":
				audio.play("extra", 0.7)
			"levelclear":
				audio.play("extra", 0.7)
			"gameover":
				audio.stop_all()

func _update_touch_visibility() -> void:
	if touch_ui == null:
		return
	var show := touch_enabled and not zoomed and state in [Config.READY, Config.PLAYING, Config.DYING, Config.GAME_OVER]
	touch_ui.visible = show
	if lobby != null:
		lobby.set_touch_checked(touch_enabled)

# ---------------------------------------------------------------- highscore
func _load_high() -> void:
	high_score = 0
	if FileAccess.file_exists(HIGHSCORE_PATH):
		var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if typeof(data) == TYPE_DICTIONARY:
				high_score = maxi(0, int(data.get("high_score", 0)))
				return
	if FileAccess.file_exists("res://assets/highscore.json"):
		var f2 := FileAccess.open("res://assets/highscore.json", FileAccess.READ)
		if f2:
			var data2 = JSON.parse_string(f2.get_as_text())
			if typeof(data2) == TYPE_DICTIONARY:
				high_score = maxi(0, int(data2.get("high_score", 0)))

func save_high() -> void:
	if suppress_save:
		return
	var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"high_score": int(high_score)}))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		high_score = maxi(high_score, score)
		save_high()
		if audio != null:
			audio.stop_all()
		if net != null:
			net.close()
		get_tree().quit()

func _exit_tree() -> void:
	if not suppress_save:
		high_score = maxi(high_score, score)
		save_high()
	if audio != null:
		audio.stop_all()
	if net != null:
		net.close()

# -------------------------------------------------------------------- smoke
func _run_online_smoke() -> void:
	suppress_save = true
	smoke_running = true
	print("ONLINE SMOKE: begin")
	if net != null:
		net.player_id = "p_host"
		net.host_id = "p_host"
		net.room_code = "TEST"
	# Roster de equipo: 2 humanos + 2 CPU, 4 fantasmas CPU.
	var team_roster: Array = [
		{"id": "p_host", "name": "HOST", "color": "yellow", "role": "pac", "pac_index": 0, "ai": false, "connected": true},
		{"id": "p_guest", "name": "GUEST", "color": "blue", "role": "pac", "pac_index": 1, "ai": false, "connected": true},
		{"id": "ai_pac_2", "name": "CPU 3", "color": "green", "role": "pac", "pac_index": 2, "ai": true, "connected": true},
		{"id": "ai_pac_3", "name": "CPU 4", "color": "pink", "role": "pac", "pac_index": 3, "ai": true, "connected": true},
		{"id": "ai_ghost_blinky", "name": "BLINKY", "role": "ghost", "ghost_name": "blinky", "ai": true, "connected": true},
		{"id": "ai_ghost_pinky", "name": "PINKY", "role": "ghost", "ghost_name": "pinky", "ai": true, "connected": true},
		{"id": "ai_ghost_inky", "name": "INKY", "role": "ghost", "ghost_name": "inky", "ai": true, "connected": true},
		{"id": "ai_ghost_clyde", "name": "CLYDE", "role": "ghost", "ghost_name": "clyde", "ai": true, "connected": true},
	]
	var payload := {"mode": "team", "pac_count": 4, "roster": team_roster, "seed": 7}
	_begin_online(payload, true)
	_smoke_check(online_role == "host", "online host role")
	_smoke_check(pacs.size() == 4, "online team has 4 pacmen")
	_smoke_check(ghosts.size() == 4, "online team has 4 ghosts")
	_smoke_check(pac != null and pac.player_id == "p_host", "host local pacman resolved")
	_smoke_check(pacs[0].color_id == "yellow" and pacs[1].color_id == "blue", "pacman colors assigned")
	state = Config.PLAYING
	for i in range(300):
		time += 1.0 / 60.0
		_update_play(1.0 / 60.0)
		_sync_visuals()
	var snap := build_snapshot()
	_smoke_check(snap.get("pa", []).size() == 4, "snapshot has 4 pacmen")
	_smoke_check(snap.get("gh", []).size() == 4, "snapshot has 4 ghosts")
	_smoke_check(snap.has("s"), "snapshot has state")
	online_role = "client"
	_apply_snapshot(snap)
	_smoke_check(state == Config.PLAYING, "client applies snapshot state")
	_smoke_check(pacs[0].tile == Vector2i(int(snap["pa"][0]["x"]), int(snap["pa"][0]["y"])), "client applies pac tile")

	# Sala personalizada: 2 Pac-Men humanos y 2 fantasmas humanos, sin bots.
	if lobby != null:
		lobby.room = {
			"code": "TEST", "hostId": "p_host",
			"players": [
				{"id": "p_host", "name": "HOST", "color": "yellow", "role": "pac"},
				{"id": "p_guest", "name": "GUEST", "color": "blue", "role": "pac"},
				{"id": "p_g1", "name": "G1", "color": "green", "role": "ghost", "ghost_name": "blinky"},
				{"id": "p_g2", "name": "G2", "color": "pink", "role": "ghost", "ghost_name": "pinky"},
			],
		}
		lobby.selected_bots = 0
		var gp := build_start_payload()
		var pacs_count := 0
		var ghosts_count := 0
		var colors := {}
		var dup := false
		for e in gp["roster"]:
			if e["role"] == "pac":
				pacs_count += 1
				if colors.has(e["color"]):
					dup = true
				colors[e["color"]] = true
			else:
				ghosts_count += 1
		_smoke_check(pacs_count == 2, "custom room has 2 human pacmen")
		_smoke_check(ghosts_count == 2, "custom room has 2 human ghosts")
		_smoke_check(gp["bots"] == 0, "zero bots respected")
		_smoke_check(gp["mode"] == MODE_GHOST, "custom room uses ghost mode")
		_smoke_check(not dup, "pacman colors are unique")
		_smoke_check(gp["ghosts"].size() == 2, "zero bots only spawns human ghosts")
		var ghost_players := 0
		for e in gp["roster"]:
			if e["role"] == "ghost" and not e["ai"]:
				ghost_players += 1
		_smoke_check(ghost_players == 2, "two human ghost players assigned")

		lobby.selected_bots = 2
		var gp_bots := build_start_payload()
		var bot_pacs := 0
		for e in gp_bots["roster"]:
			if e["role"] == "pac" and e["ai"]:
				bot_pacs += 1
		_smoke_check(bot_pacs == 2, "two CPU pacmen added")
		_smoke_check(gp_bots["pac_count"] == 4, "bot count fills pac slots")
		_smoke_check(gp_bots["ghosts"].size() == 4, "bots fill the missing ghosts")

		lobby.room = {
			"code": "TEST", "hostId": "p_host",
			"players": [
				{"id": "p_host", "name": "HOST", "color": "yellow", "role": "pac"},
			],
		}
		lobby.selected_bots = 0
		var gp_no_ghosts := build_start_payload()
		_smoke_check(gp_no_ghosts["ghosts"].size() == 4, "no human ghosts keeps 4 AI ghosts")

		lobby.room = {
			"code": "TEST", "hostId": "p_host",
			"players": [
				{"id": "p_host", "name": "HOST", "color": "yellow", "role": "ghost", "ghost_name": "clyde"},
			],
		}
		lobby.selected_bots = 0
		_smoke_check(build_start_payload().is_empty(), "room without pacman is rejected")
		lobby.selected_bots = 1
		var gp_one_bot := build_start_payload()
		_smoke_check(not gp_one_bot.is_empty() and gp_one_bot["pac_count"] == 1, "bot supplies missing pacman")

		online_role = "host"
		roster = gp["roster"]
		online_ghost_names = gp["ghosts"].duplicate()
		maze.reset()
		_clear_actors()
		_spawn_actors()
		_smoke_check(pacs.size() == 2 and ghosts.size() == 2, "ghost mode spawns only active ghosts")
		var ghost_player = null
		var pinky_ghost = null
		for g in ghosts:
			if g.is_player and ghost_player == null:
				ghost_player = g
			if g.ghost_name == "pinky":
				pinky_ghost = g
		_smoke_check(ghost_player != null, "human ghost node resolved")
		_smoke_check(pinky_ghost != null and pinky_ghost.release == 0.0, "human ghost releases immediately")
		if pinky_ghost != null:
			pinky_ghost.state = "house"
			pinky_ghost.desired_dir = null
			_on_net_input({"playerId": pinky_ghost.player_id, "data": {"dir": "right"}})
			_smoke_check(pinky_ghost.desired_dir == Config.DIRS["right"], "ghost input is queued in the house")
			pinky_ghost.state = "normal"
			pinky_ghost.tile = Vector2i(1, 1)
			pinky_ghost.progress = 0.0
			pinky_ghost.dir = null
			pinky_ghost.desired_dir = Config.DIRS["right"]
			for i in range(120):
				time += 1.0 / 60.0
				pinky_ghost.update_ghost(1.0 / 60.0)
			_smoke_check(pinky_ghost.tile.x > 1, "human ghost moves with player input")

			pinky_ghost.state = "normal"
			pinky_ghost.tile = Vector2i(1, 1)
			pinky_ghost.progress = 0.0
			pinky_ghost.dir = Config.DIRS["left"]
			pinky_ghost.desired_dir = null
			for i in range(30):
				time += 1.0 / 60.0
				pinky_ghost.update_ghost(1.0 / 60.0)
			_smoke_check(pinky_ghost.tile == Vector2i(1, 1), "human ghost stops without player input")

			pinky_ghost.state = "normal"
			pinky_ghost.frightened = true
			pinky_ghost.tile = Vector2i(5, 5)
			pinky_ghost.progress = 0.0
			pinky_ghost.dir = null
			pinky_ghost.desired_dir = Config.DIRS["left"]
			pinky_ghost.eaten_by_player()
			_smoke_check(pinky_ghost.desired_dir == null, "eaten ghost ignores player input")
			var reached_home := false
			for i in range(900):
				time += 1.0 / 60.0
				pinky_ghost.update_ghost(1.0 / 60.0)
				if pinky_ghost.tile == Config.HOUSE_CENTER and pinky_ghost.state in ["eaten", "dead"]:
					reached_home = true
			_smoke_check(reached_home, "eaten ghost reaches its house")
			_smoke_check(pinky_ghost.state != "eaten" and pinky_ghost.state != "dead", "eaten ghost respawns")

	print("ONLINE SMOKE RESULT: ALL OK" if smoke_ok else "ONLINE SMOKE RESULT: FAILED")
	get_tree().quit(0 if smoke_ok else 1)

func _smoke_check(cond: bool, label: String) -> void:
	if cond:
		print("SMOKE OK: ", label)
	else:
		smoke_ok = false
		push_error("SMOKE FAIL: " + label)

func _run_smoke() -> void:
	var backup_exists := FileAccess.file_exists(HIGHSCORE_PATH)
	var backup := ""
	if backup_exists:
		backup = FileAccess.get_file_as_string(HIGHSCORE_PATH)
	var old_high := high_score
	suppress_save = true
	smoke_running = true
	print("SMOKE: begin")

	_smoke_check(sheet != null, "sprite sheet loaded")
	_smoke_check(bg_texture != null, "background loaded")
	_smoke_check(scanlines_texture != null, "scanlines loaded")
	_smoke_check(ghost_frames.size() == 4, "ghost animations built")

	start_local_single()
	_smoke_check(state == Config.READY, "new game starts in READY")
	_smoke_check(lives == 4 and level == 1 and score == 0, "initial stats")
	_smoke_check(pac != null and ghosts.size() == 4, "actors spawned")
	_smoke_check(maze.remaining() == 244, "244 pellets")
	_smoke_check(pac.tile == Config.START_TILE, "pacman at start tile")

	state = Config.PLAYING
	var pac_frames_seen := {}
	for i in range(30):
		_update_play(1.0 / 60.0)
		_sync_visuals()
		if pac != null:
			pac_frames_seen[pac.frame] = true
	_smoke_check(pac_frames_seen.size() >= 2, "pacman animation advances")
	var ghost_frames_seen := {}
	for i in range(30):
		_update_play(1.0 / 60.0)
		_sync_visuals()
		for g in ghosts:
			if g.visible and g.state in ["normal", "leaving"]:
				ghost_frames_seen[g.ghost_name + ":" + str(g.frame)] = true
	_smoke_check(ghost_frames_seen.size() >= 2, "ghost animation advances")

	start_local_single()
	state = Config.PLAYING
	for i in range(480):
		time += 1.0 / 60.0
		for g in ghosts:
			g.update_ghost(1.0 / 60.0)
	var released := 0
	for g in ghosts:
		if g.state != "house":
			released += 1
	_smoke_check(released == 4, "all ghosts leave the house")

	start_local_single()
	state = Config.PLAYING
	pac.tile = Vector2i(1, 3)
	pac.progress = 0.0
	pac.dir = null
	pac.arrivals = [pac.tile]
	_update_play(1.0 / 60.0)
	_smoke_check(frightened and fright_timer > 7.0, "power pellet triggers fright")
	var blue := 0
	for g in ghosts:
		if g.frightened:
			blue += 1
	_smoke_check(blue == 4, "all ghosts are frightened")

	var gh = ghosts[0]
	gh.state = "normal"
	gh.frightened = true
	gh.tile = Vector2i(5, 5)
	gh.progress = 0.0
	gh.dir = null
	gh.eaten_by_player()
	_smoke_check(gh.state == "eaten", "ghost enters eaten state")
	for i in range(720):
		time += 1.0 / 60.0
		gh.update_ghost(1.0 / 60.0)
	_smoke_check(gh.state != "eaten" and gh.state != "dead", "ghost returns from the house")

	start_local_single()
	state = Config.PLAYING
	var gh2 = ghosts[1]
	gh2.state = "normal"
	gh2.frightened = false
	gh2.tile = pac.tile
	gh2.progress = 0.0
	gh2.dir = null
	_check_collisions()
	_smoke_check(state == Config.DYING and pac.lives == 3, "ghost collision starts death")

	start_local_single()
	state = Config.PLAYING
	fruit_active = true
	fruit_timer = 9.0
	pac.tile = Config.FRUIT_TILE
	pac.progress = 0.0
	pac.dir = null
	pac.arrivals = []
	var before := score
	_update_fruit(1.0 / 60.0)
	_smoke_check(score - before == 100, "fruit awards 100 points")
	_smoke_check(not fruit_active, "fruit disappears after pickup")
	_smoke_check(fruit_history.size() == 1, "fruit history records pickup")

	start_local_single()
	state = Config.PLAYING
	maze.pellets.clear()
	freeze_timer = 0.0
	_update_play(1.0 / 60.0)
	_smoke_check(state == Config.LEVEL_CLEAR, "empty maze starts level clear")
	for i in range(200):
		_process(1.0 / 60.0)
	_smoke_check(level == 2 and state == Config.READY, "next level is ready")
	_smoke_check(maze.remaining() == 244, "next level refills pellets")

	start_local_single()
	lives = 4
	score = 9990
	next_extra = 10000
	add_score(10)
	_smoke_check(lives == 5 and score == 10000, "extra life at 10000 points")

	var dirs := [Config.DIRS["left"], Config.DIRS["right"], Config.DIRS["up"], Config.DIRS["down"]]
	for run in range(3):
		start_local_single()
		state = Config.PLAYING
		for i in range(1200):
			if i % 15 == 0:
				pac.desired = dirs[randi() % 4]
			_update_play(1.0 / 60.0)
			if state != Config.PLAYING:
				break
		_smoke_check(state in [Config.PLAYING, Config.DYING, Config.READY,
			Config.LEVEL_CLEAR, Config.GAME_OVER], "stress run %d survives" % (run + 1))

	state = Config.LOBBY
	world.visible = false
	popups = []
	particles = []
	if pac != null and is_instance_valid(pac):
		pac.free()
	pac = null
	for g in ghosts:
		if is_instance_valid(g):
			g.free()
	ghosts.clear()
	pacs.clear()
	audio.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame

	high_score = old_high
	if backup_exists:
		var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(backup)
	elif FileAccess.file_exists(HIGHSCORE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(HIGHSCORE_PATH))
	suppress_save = true

	if smoke_ok:
		print("SMOKE RESULT: ALL OK")
	else:
		print("SMOKE RESULT: FAILED")
	get_tree().quit(0 if smoke_ok else 1)
