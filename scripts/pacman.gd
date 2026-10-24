extends AnimatedSprite2D
class_name PacMan

var maze
var tile: Vector2i = Config.START_TILE
var dir = Config.DIRS["left"]
var facing = Config.DIRS["left"]
var desired = null
var progress := 0.0
var move_speed := Config.PACMAN_SPEED
var arrivals: Array = []
var anim := 0.0
var moving := false

# Datos online
var player_id := ""
var player_name := ""
var color_id := "yellow"
var tint_color: Color = Config.PAC_COLORS["yellow"]
var spawn_tile: Vector2i = Config.START_TILE
var is_ai := false
var connected := true
var score := 0
var lives := Config.ONLINE_LIVES
var active := true

# Interpolacion para clientes
var net_prev_pos := Vector2.ZERO
var net_target_pos := Vector2.ZERO
var net_lerp := 1.0
var net_moving := false
var net_anim := 0.0

func setup(maze_ref, frames: SpriteFrames, p_id := "", p_color := "yellow",
		p_spawn: Vector2i = Config.START_TILE) -> void:
	maze = maze_ref
	sprite_frames = frames
	player_id = p_id
	color_id = p_color
	tint_color = Config.PAC_COLORS.get(p_color, Config.PAC_COLORS["yellow"])
	spawn_tile = p_spawn
	_apply_tint()
	animation = "chomp"
	frame = 1
	pause()
	respawn(spawn_tile)

func _apply_tint() -> void:
	var shader = load("res://scripts/pac_tint.gdshader")
	if shader == null:
		modulate = tint_color
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", tint_color)
	material = mat

func respawn(at_tile: Vector2i = spawn_tile) -> void:
	tile = at_tile
	dir = Config.DIRS["left"]
	facing = dir
	desired = null
	progress = 0.0
	arrivals = [tile]
	anim = 0.0
	moving = false
	active = true
	visible = true
	net_lerp = 1.0
	position = pos()
	net_prev_pos = position
	net_target_pos = position
	rotation = angle_for_dir(dir)

func pos() -> Vector2:
	var c: Vector2 = maze.center(tile)
	if dir == null:
		return c
	return c + Vector2(dir.x, dir.y) * progress

func take_arrivals() -> Array:
	var out := arrivals
	arrivals = []
	return out

func angle_for_dir(d) -> float:
	if d == null:
		return 0.0
	if d == Vector2i(1, 0):
		return 0.0
	if d == Vector2i(-1, 0):
		return PI
	if d == Vector2i(0, -1):
		return -PI * 0.5
	return PI * 0.5

func update_pac(dt: float) -> void:
	moving = false
	if progress <= 1e-9:
		_choose()
	elif desired != null and dir != null and desired == Vector2i(-dir.x, -dir.y):
		var nxt = maze.neighbor(tile, dir)
		if nxt != null:
			tile = nxt
			progress = Config.TILE - progress
			dir = desired

	var remaining := move_speed * dt
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
		moving = true
		if progress >= Config.TILE - 1e-9:
			_arrive()
	if moving:
		anim += dt

func _choose() -> void:
	if desired != null:
		var nt = maze.neighbor(tile, desired)
		if maze.is_walkable(nt, true):
			dir = desired
			facing = dir
			return
	if dir != null and maze.is_walkable(maze.neighbor(tile, dir), true):
		facing = dir
		return
	dir = null

func _arrive() -> void:
	var nxt = maze.neighbor(tile, dir)
	if nxt == null:
		dir = null
		progress = 0.0
		return
	tile = nxt
	progress = 0.0
	arrivals.append(nxt)
	_choose()

func sync_visual() -> void:
	position = pos()
	rotation = angle_for_dir(dir if dir != null else facing)
	var f := 1
	if moving:
		f = int(anim / 0.06) % 4
	frame = f
	pause()

func apply_network(tile_ref: Vector2i, dir_name: String, prog: float,
		is_moving: bool, net_animation: float, is_visible: bool) -> void:
	var target_dir = null
	if dir_name != "":
		target_dir = Config.DIRS.get(dir_name, null)
	if net_lerp < 1.0:
		net_prev_pos = position
	else:
		net_prev_pos = net_target_pos
	tile = tile_ref
	dir = target_dir
	if target_dir != null:
		facing = target_dir
	progress = prog
	net_moving = is_moving
	net_anim = net_animation
	active = is_visible
	visible = is_visible
	net_target_pos = pos()
	net_lerp = 0.0
	if net_prev_pos.distance_to(net_target_pos) > Config.MAZE_W * 0.5:
		net_prev_pos = net_target_pos
	rotation = angle_for_dir(dir if dir != null else facing)
	frame = int(net_anim / 0.06) % 4 if net_moving else 1
	pause()

func interpolate_network(dt: float) -> void:
	if net_lerp < 1.0:
		net_lerp = minf(1.0, net_lerp + dt / Config.NET_TICK)
		position = net_prev_pos.lerp(net_target_pos, net_lerp)
	else:
		position = net_target_pos
