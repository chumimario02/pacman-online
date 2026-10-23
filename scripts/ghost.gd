extends AnimatedSprite2D
class_name Ghost

var game
var maze
var ghost_name := ""
var spawn: Vector2i = Config.HOUSE_CENTER
var tile: Vector2i = Config.HOUSE_CENTER
var dir = null
var progress := 0.0
var state := "house"
var frightened := false
var release := 0.0
var house_timer := 0.0
var dead_timer := 0.0
var anim := 0.0
var phase := 0.0

# Control por jugador
var player_id := ""
var player_name := ""
var is_player := false
var connected := true
var desired_dir = null
var score := 0

# Interpolacion de cliente
var net_prev_pos := Vector2.ZERO
var net_target_pos := Vector2.ZERO
var net_lerp := 1.0
var net_state := "house"
var net_frightened := false
var net_anim := 0.0
var net_visible := true

func setup(game_ref, maze_ref, name: String, frames: SpriteFrames) -> void:
	game = game_ref
	maze = maze_ref
	ghost_name = name
	sprite_frames = frames
	spawn = Config.GHOST_START[name]
	tile = spawn
	dir = null
	progress = 0.0
	state = "normal" if name == "blinky" else "house"
	frightened = false
	release = Config.GHOST_RELEASE[name]
	house_timer = 0.0
	dead_timer = 0.0
	anim = 0.0
	phase = randf() * TAU
	position = pos()
	if state == "normal":
		_choose()
	sync_visual()

func set_player(p_id: String, p_name := "") -> void:
	is_player = p_id != ""
	player_id = p_id
	player_name = p_name

func pos() -> Vector2:
	var c: Vector2 = maze.center(tile)
	if state == "house":
		return c + Vector2(0.0, sin(game.time * 3.6 + phase) * 3.0)
	if dir == null:
		return c
	return c + Vector2(dir.x, dir.y) * progress

func is_edible() -> bool:
	return frightened and state in ["normal", "leaving"]

func get_speed() -> float:
	if state == "eaten":
		return Config.EATEN_SPEED
	if state == "leaving":
		return Config.LEAVE_SPEED
	var base := Config.FRIGHT_SPEED if frightened else minf(
		Config.GHOST_MAX_SPEED, Config.GHOST_BASE_SPEED + (game.level - 1) * 4.5)
	if tile.y == 14 and (tile.x <= 5 or tile.x >= 22):
		base *= 0.6
	return base

func set_frightened(value: bool) -> void:
	if state in ["eaten", "dead"]:
		frightened = false
		return
	if value and not frightened and state in ["normal", "leaving"]:
		reverse()
	frightened = value

func eaten_by_player() -> void:
	state = "eaten"
	frightened = false
	dead_timer = 0.0
	# El jugador no puede desviar los ojos: siempre vuelven a la casa.
	desired_dir = null

func reverse() -> void:
	if not state in ["normal", "leaving"] or dir == null:
		return
	var opp := Vector2i(-dir.x, -dir.y)
	if progress <= 1e-9:
		if maze.is_walkable(maze.neighbor(tile, opp), false, _allow_house()):
			dir = opp
		return
	var nxt = maze.neighbor(tile, dir)
	if nxt != null:
		tile = nxt
		progress = Config.TILE - progress
		dir = opp

func _allow_house() -> bool:
	return state in ["leaving", "eaten"] or maze.is_house(tile)

func _moves() -> Array:
	var allow: bool = _allow_house()
	var reverse_dir = Vector2i(-dir.x, -dir.y) if dir != null else null
	var moves: Array = []
	for d in Config.DIR_ORDER:
		var nt = maze.neighbor(tile, d)
		if not maze.is_walkable(nt, false, allow):
			continue
		if d == reverse_dir:
			continue
		moves.append([d, nt])
	if moves.is_empty():
		for d in Config.DIR_ORDER:
			var nt = maze.neighbor(tile, d)
			if maze.is_walkable(nt, false, allow):
				moves.append([d, nt])
	return moves

func _player_choice():
	if not is_player or desired_dir == null or state != "normal":
		return null
	var allow: bool = _allow_house()
	var nt = maze.neighbor(tile, desired_dir)
	if maze.is_walkable(nt, false, allow):
		return desired_dir
	return null

func _choose() -> void:
	if state in ["house", "dead"]:
		return
	var moves := _moves()
	if moves.is_empty():
		dir = null
		return

	var player_pick = _player_choice()
	if player_pick != null:
		dir = player_pick
		return

	if state == "leaving":
		var best = null
		var best_d := 1e20
		for m in moves:
			var dd: float = maze.dist_exit.get(m[1], 1e20)
			if dd < best_d:
				best_d = dd
				best = m[0]
		dir = best
		return

	if state == "eaten":
		var best2 = null
		var best2_d := 1e20
		for m in moves:
			var dd2: float = maze.dist_home.get(m[1], 1e20)
			if dd2 < best2_d:
				best2_d = dd2
				best2 = m[0]
		dir = best2
		return

	if frightened:
		dir = moves[randi() % moves.size()][0]
		return

	var target: Vector2i = game.ghost_target(self)
	var best3 = null
	var best3_d := 1e20
	for m in moves:
		var nt: Vector2i = m[1]
		var d2 := float((nt.x - target.x) * (nt.x - target.x) + (nt.y - target.y) * (nt.y - target.y))
		if d2 < best3_d:
			best3_d = d2
			best3 = m[0]
	dir = best3

func update_ghost(dt: float) -> void:
	anim += dt
	if state == "house":
		house_timer += dt
		if house_timer >= release:
			state = "leaving"
			progress = 0.0
			dir = null
			_choose()
		return
	if state == "dead":
		dead_timer -= dt
		if dead_timer <= 0.0:
			tile = Config.HOUSE_CENTER
			progress = 0.0
			dir = null
			state = "leaving"
			frightened = false
			_choose()
		return

	if progress <= 1e-9:
		_choose()

	var remaining := get_speed() * dt
	var guard := 0
	while remaining > 1e-9 and guard < 10:
		guard += 1
		if dir == null:
			_choose()
			if dir == null:
				break
		var left := Config.TILE - progress
		if left <= 1e-9:
			_arrive()
			continue
		var step := minf(remaining, left)
		progress += step
		remaining -= step
		if progress >= Config.TILE - 1e-9:
			_arrive()

func _arrive() -> void:
	var nxt = maze.neighbor(tile, dir)
	if nxt == null:
		dir = null
		progress = 0.0
		return
	tile = nxt
	progress = 0.0
	if state == "eaten" and tile == Config.HOUSE_CENTER:
		state = "dead"
		dead_timer = 1.0
		dir = null
		return
	if state == "leaving" and tile == Config.HOUSE_EXIT:
		state = "normal"
		frightened = game.frightened
	_choose()

func _dir_name(d) -> String:
	if d == null:
		return "down"
	if d == Vector2i(1, 0):
		return "right"
	if d == Vector2i(-1, 0):
		return "left"
	if d == Vector2i(0, -1):
		return "up"
	return "down"

func _set_anim(anim_name: String, f: int) -> void:
	if animation != anim_name:
		animation = anim_name
	frame = f
	pause()

func sync_visual() -> void:
	position = pos()
	if state in ["eaten", "dead"]:
		var eyes_name := "eyes_up"
		if dir != null:
			eyes_name = "eyes_" + _dir_name(dir)
		_set_anim(eyes_name, 0)
	elif frightened and state in ["normal", "leaving", "house"]:
		var flash: bool = game.frightened and game.fright_timer < 2.0 and int(game.time * 9.0) % 2 == 0
		_set_anim("flash" if flash else "fright", int(anim / 0.20) % 2)
	else:
		_set_anim(_dir_name(dir), int(anim / 0.14) % 2)

func apply_network(tile_ref: Vector2i, dir_name: String, prog: float,
		ghost_state: String, is_frightened: bool, net_animation: float,
		is_visible: bool, p_id: String) -> void:
	var target_dir = null
	if dir_name != "":
		target_dir = Config.DIRS.get(dir_name, null)
	if net_lerp < 1.0:
		net_prev_pos = position
	else:
		net_prev_pos = net_target_pos
	tile = tile_ref
	dir = target_dir
	progress = prog
	state = ghost_state
	frightened = is_frightened
	net_state = ghost_state
	net_frightened = is_frightened
	net_anim = net_animation
	player_id = p_id
	is_player = p_id != ""
	net_visible = is_visible
	visible = is_visible
	net_target_pos = pos()
	net_lerp = 0.0
	if net_prev_pos.distance_to(net_target_pos) > Config.MAZE_W * 0.5:
		net_prev_pos = net_target_pos
	if state in ["eaten", "dead"]:
		var eyes_name := "eyes_up"
		if dir != null:
			eyes_name = "eyes_" + _dir_name(dir)
		_set_anim(eyes_name, 0)
	elif frightened and state in ["normal", "leaving", "house"]:
		var flash: bool = game.frightened and game.fright_timer < 2.0 and int(game.time * 9.0) % 2 == 0
		_set_anim("flash" if flash else "fright", int(net_anim / 0.20) % 2)
	else:
		_set_anim(_dir_name(dir), int(net_anim / 0.14) % 2)

func interpolate_network(dt: float) -> void:
	if net_lerp < 1.0:
		net_lerp = minf(1.0, net_lerp + dt / Config.NET_TICK)
		position = net_prev_pos.lerp(net_target_pos, net_lerp)
	else:
		position = net_target_pos
