extends RefCounted
class_name Maze

var grid: Array = []
var base_pellets: Dictionary = {}
var pellets: Dictionary = {}
var total := 0
var dist_exit: Dictionary = {}
var dist_home: Dictionary = {}
var house_tiles: Dictionary = {}

func _init() -> void:
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

	total = base_pellets.size()
	pellets = base_pellets.duplicate()
	dist_exit = _distance_field(Config.HOUSE_EXIT, true)
	dist_home = _distance_field(Config.HOUSE_CENTER, true)

func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < Config.COLS and tile.y >= 0 and tile.y < Config.ROWS

func neighbor(tile: Vector2i, direction):
	if direction == null:
		return tile
	var x: int = tile.x + int(direction.x)
	var y: int = tile.y + int(direction.y)
	if y == 14:
		if x < 0:
			x = Config.COLS - 1
		elif x >= Config.COLS:
			x = 0
	if x >= 0 and x < Config.COLS and y >= 0 and y < Config.ROWS:
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
	return Vector2(tile.x * Config.TILE + Config.TILE * 0.5,
			tile.y * Config.TILE + Config.TILE * 0.5)

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
