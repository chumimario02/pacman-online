extends RefCounted
class_name Maze

var grid: Array = []
var base_pellets: Dictionary = {}
var pellets: Dictionary = {}
var total := 0
var dist_exit: Dictionary = {}
var dist_home: Dictionary = {}
var house_tiles: Dictionary = {}

var mode := "classic"
var cols := Config.COLS
var rows := Config.ROWS
var tile_w := Config.TILE
var tile_h := Config.TILE
var tunnel_rows: Array = [14]

func _init() -> void:
	set_mode("classic")

func set_mode(value: String) -> void:
	mode = value
	grid.clear()
	base_pellets.clear()
	pellets.clear()
	house_tiles.clear()
	dist_exit.clear()
	dist_home.clear()
	if mode == "remake":
		_build_remake()
	else:
		_build_classic()
	total = base_pellets.size()
	pellets = base_pellets.duplicate()
	dist_exit = _distance_field(house_exit(), true)
	dist_home = _distance_field(house_center(), true)

func _build_classic() -> void:
	cols = Config.COLS
	rows = Config.ROWS
	tile_w = Config.TILE
	tile_h = Config.TILE
	tunnel_rows = [14]
	for row in Config.MAZE_LAYOUT:
		var line: Array = []
		for ch in row:
			line.append(ch == ".")
		grid.append(line)

	for x in range(11, 17):
		for y in range(13, 16):
			house_tiles[Vector2i(x, y)] = true
	for tile in Config.DOOR_TILES:
		house_tiles[tile] = true

	# .dat se incluye sin procesar en el PCK; el .csv queda como respaldo
	# para ejecuciones locales (Godot lo trata como fuente de traduccion).
	var f := FileAccess.open("res://assets/pellets.dat", FileAccess.READ)
	if f == null:
		f = FileAccess.open("res://assets/pellets.csv", FileAccess.READ)
	if f:
		while not f.eof_reached():
			var line := f.get_line().strip_edges()
			if line == "":
				continue
			var parts := line.split(",")
			if parts.size() < 3:
				continue
			var tx := int(parts[0])
			var ty := int(parts[1])
			var area := int(parts[2])
			base_pellets[Vector2i(tx, ty)] = 50 if area > 100 else 10

func _build_remake() -> void:
	cols = Config.REMAKE_COLS
	rows = Config.REMAKE_ROWS
	tile_w = Config.TILE
	tile_h = Config.TILE
	tunnel_rows = Config.REMAKE_TUNNEL_ROWS.duplicate()
	for row in Config.REMAKE_LAYOUT:
		var line: Array = []
		for ch in row:
			line.append(ch == ".")
		grid.append(line)

	# Sin casa cerrada: los fantasmas salen del corredor central.
	for tile in Config.REMAKE_POWER_PELLETS:
		if is_walkable(tile):
			base_pellets[tile] = 50

	# Pellets en todas las celdas alcanzables (centrados en cada hueco).
	var reachable := _reachable_from(start_tile())
	for y in range(rows):
		for x in range(cols):
			var tile := Vector2i(x, y)
			if not reachable.has(tile):
				continue
			if not base_pellets.has(tile):
				base_pellets[tile] = 10

func _reachable_from(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var q: Array = [start]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d in Config.DIR_ORDER:
			var nxt = neighbor(cur, d)
			if nxt == null or seen.has(nxt):
				continue
			if not is_walkable(nxt, true):
				continue
			seen[nxt] = true
			q.append(nxt)
	return seen

func _wall_distance() -> Array:
	var dist: Array = []
	for y in range(rows):
		var line: Array = []
		for x in range(cols):
			line.append(0 if not grid[y][x] else 999)
		dist.append(line)
	var q: Array = []
	for y in range(rows):
		for x in range(cols):
			if not grid[y][x]:
				q.append(Vector2i(x, y))
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d in Config.DIR_ORDER:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx < 0 or nx >= cols or ny < 0 or ny >= rows:
				continue
			if int(dist[ny][nx]) > int(dist[cur.y][cur.x]) + 1:
				dist[ny][nx] = int(dist[cur.y][cur.x]) + 1
				q.append(Vector2i(nx, ny))
	return dist

func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < cols and tile.y >= 0 and tile.y < rows

func is_tunnel_row(y: int) -> bool:
	return tunnel_rows.has(y)

func neighbor(tile: Vector2i, direction):
	if direction == null:
		return tile
	var x: int = tile.x + int(direction.x)
	var y: int = tile.y + int(direction.y)
	if is_tunnel_row(y):
		if x < 0:
			x = cols - 1
		elif x >= cols:
			x = 0
	if x >= 0 and x < cols and y >= 0 and y < rows:
		return Vector2i(x, y)
	return null

func is_walkable(tile, pacman := false, allow_house := true) -> bool:
	if tile == null or not in_bounds(tile):
		return false
	if not grid[tile.y][tile.x]:
		return false
	if house_tiles.has(tile):
		if pacman:
			return false
		if not allow_house:
			return false
	return true

func is_house(tile: Vector2i) -> bool:
	return house_tiles.has(tile)

func center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * tile_w + tile_w * 0.5,
			tile.y * tile_h + tile_h * 0.5)

func pixel_size() -> Vector2:
	return Vector2(cols * tile_w, rows * tile_h)

func reset() -> void:
	pellets = base_pellets.duplicate()
	total = base_pellets.size()

func remaining() -> int:
	return pellets.size()

func eat(tile: Vector2i) -> int:
	if not pellets.has(tile):
		return 0
	var value: int = pellets[tile]
	pellets.erase(tile)
	return value

func house_center() -> Vector2i:
	return Config.REMAKE_HOUSE_CENTER if mode == "remake" else Config.HOUSE_CENTER

func house_exit() -> Vector2i:
	return Config.REMAKE_HOUSE_EXIT if mode == "remake" else Config.HOUSE_EXIT

func start_tile() -> Vector2i:
	return Config.REMAKE_PAC_STARTS[0] if mode == "remake" else Config.START_TILE

func pac_start(index: int) -> Vector2i:
	if mode == "remake":
		return Config.REMAKE_PAC_STARTS[index % Config.REMAKE_PAC_STARTS.size()]
	return Config.PAC_STARTS[index % Config.PAC_STARTS.size()]

func ghost_start(ghost_name: String) -> Vector2i:
	if mode == "remake":
		return Config.REMAKE_GHOST_START[ghost_name]
	return Config.GHOST_START[ghost_name]

func ghost_release(ghost_name: String) -> float:
	if mode == "remake":
		return Config.REMAKE_GHOST_RELEASE[ghost_name]
	return Config.GHOST_RELEASE[ghost_name]

func scatter_target(ghost_name: String) -> Vector2i:
	if mode == "remake":
		return Config.REMAKE_SCATTER_TARGETS[ghost_name]
	return Config.SCATTER_TARGETS[ghost_name]

func fruit_tile() -> Vector2i:
	return Config.REMAKE_FRUIT_TILE if mode == "remake" else Config.FRUIT_TILE

func distance_to_nearest_pellet(start: Vector2i, blocked: Dictionary = {}) -> int:
	# BFS usado por los Pac-Men controlados por la maquina.
	var q: Array = [start]
	var dist: Dictionary = {start: 0}
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		if pellets.has(cur):
			return int(dist[cur])
		for d in Config.DIR_ORDER:
			var nxt = neighbor(cur, d)
			if nxt == null or dist.has(nxt) or blocked.has(nxt):
				continue
			if not is_walkable(nxt, true):
				continue
			dist[nxt] = int(dist[cur]) + 1
			q.append(nxt)
	return 9999

func _distance_field(target: Vector2i, allow_house: bool) -> Dictionary:
	var dist := {target: 0}
	var q: Array = [target]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d in Config.DIR_ORDER:
			var nxt = neighbor(cur, d)
			if nxt == null or dist.has(nxt):
				continue
			if not is_walkable(nxt, false, allow_house):
				continue
			dist[nxt] = int(dist[cur]) + 1
			q.append(nxt)
	return dist
