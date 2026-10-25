extends RefCounted
class_name Config

# Ventana
const WIDTH := 1000
const HEIGHT := 680
const TILE := 16
const COLS := 28
const ROWS := 31
const MAZE_W := COLS * TILE
const MAZE_H := ROWS * TILE
const MAZE_X := 276
const MAZE_Y := 100

# Modo Remake: mapa neon 55x34 a 16 px por celda (880x544), sin deformar.
const REMAKE_COLS := 55
const REMAKE_ROWS := 34
const REMAKE_W := REMAKE_COLS * TILE
const REMAKE_H := REMAKE_ROWS * TILE
const REMAKE_X := 60
const REMAKE_Y := 68

# Estados
const MENU := "menu"
const LOBBY := "lobby"
const READY := "ready"
const PLAYING := "playing"
const DYING := "dying"
const LEVEL_CLEAR := "levelclear"
const GAME_OVER := "gameover"

# Online
const MAX_PLAYERS := 4
const NET_TICK := 0.02
const LOBBY_TITLE := "PAC-MAN ONLINE"
const PAC_COLORS := {
	"yellow": Color(1.0, 0.9137, 0.0, 1.0),
	"blue": Color(0.2314, 0.4784, 1.0, 1.0),
	"green": Color(0.1176, 0.9412, 0.3529, 1.0),
	"pink": Color(1.0, 0.4353, 0.7804, 1.0),
}
const PAC_COLOR_NAMES := {
	"yellow": "AMARILLO",
	"blue": "AZUL",
	"green": "VERDE",
	"pink": "ROSA",
}
const PAC_COLOR_ORDER := ["yellow", "blue", "green", "pink"]
const GHOST_ORDER := ["blinky", "pinky", "inky", "clyde"]
const GHOST_NAME_LABELS := {
	"blinky": "BLINKY",
	"pinky": "PINKY",
	"inky": "INKY",
	"clyde": "CLYDE",
}
const PAC_STARTS := [
	Vector2i(13, 23), Vector2i(12, 23), Vector2i(14, 23), Vector2i(15, 23),
]
const ONLINE_LIVES := 3
const GHOST_CATCH_SCORE := 200
const GHOST_RESPAWN_TIME := 4.5
const PAC_RESPAWN_TIME := 2.1
const ONLINE_READY_TIME := 2.0

# Colores
const BG_TOP := Color(0.0196, 0.0235, 0.0471, 1.0)
const BG_BOTTOM := Color(0.0353, 0.0471, 0.0863, 1.0)
const PANEL := Color(0.0392, 0.0510, 0.0941, 0.92)
const PANEL_BORDER := Color(0.1098, 0.1569, 0.2588, 1.0)
const YELLOW := Color(1.0, 0.9137, 0.0, 1.0)
const YELLOW_SOFT := Color(1.0, 0.8392, 0.2510, 1.0)
const BLUE := Color(0.1294, 0.1294, 1.0, 1.0)
const SALMON := Color(0.9804, 0.7255, 0.6902, 1.0)
const CYAN := Color(0.0, 0.8980, 1.0, 1.0)
const PINK := Color(1.0, 0.7216, 1.0, 1.0)
const RED := Color(1.0, 0.2314, 0.3608, 1.0)
const ORANGE := Color(1.0, 0.6471, 0.2353, 1.0)
const GREEN := Color(0.0, 1.0, 0.6118, 1.0)
const WHITE := Color(0.9569, 0.9725, 1.0, 1.0)
const GREY := Color(0.5412, 0.5882, 0.6902, 1.0)
const DIM := Color(0.1412, 0.1725, 0.2431, 1.0)

# Reglas
const PACMAN_SPEED := 118.0
const GHOST_BASE_SPEED := 104.0
const GHOST_MAX_SPEED := 134.0
const FRIGHT_SPEED := 70.0
const EATEN_SPEED := 235.0
const LEAVE_SPEED := 72.0

const READY_TIME := 2.3
const DEATH_TIME := 2.1
const LEVEL_CLEAR_TIME := 2.6
const FRUIT_TIME := 9.5
const FRUIT_SCORE := [100, 300, 500, 700, 1000, 2000, 3000, 5000]
const FRUIT_COLUMNS := [3, 2, 1, 0, 4, 5, 6, 7]

const START_TILE := Vector2i(13, 23)
const HOUSE_CENTER := Vector2i(13, 14)
const HOUSE_EXIT := Vector2i(13, 11)
const FRUIT_TILE := Vector2i(13, 17)

static var DOOR_TILES := [Vector2i(13, 12), Vector2i(14, 12)]

static var SCATTER_TARGETS := {
	"blinky": Vector2i(25, -3),
	"pinky": Vector2i(2, -3),
	"inky": Vector2i(27, 32),
	"clyde": Vector2i(0, 32),
}

static var GHOST_ROWS := {"blinky": 2, "pinky": 3, "inky": 4, "clyde": 5}
static var GHOST_COLORS := {
	"blinky": Color(1.0, 0.1569, 0.1569),
	"pinky": Color(1.0, 0.6667, 0.8627),
	"inky": Color(0.0, 0.9020, 0.9020),
	"clyde": Color(1.0, 0.6667, 0.2353),
}
static var GHOST_START := {
	"blinky": HOUSE_EXIT,
	"pinky": HOUSE_CENTER,
	"inky": Vector2i(11, 14),
	"clyde": Vector2i(15, 14),
}
static var GHOST_RELEASE := {"blinky": 0.0, "pinky": 1.6, "inky": 4.0, "clyde": 6.4}

static var MODE_SCHEDULE := [
	[7.0, "scatter"], [20.0, "chase"], [7.0, "scatter"],
	[20.0, "chase"], [5.0, "scatter"], [20.0, "chase"],
	[5.0, "scatter"],
]
const CHASE_FOREVER := 999999.0
const USE_HD_SPRITES := false

static var MAZE_LAYOUT := [
	"############################",
	"#............##............#",
	"#.####.#####.##.#####.####.#",
	"#.####.#####.##.#####.####.#",
	"#.####.#####.##.#####.####.#",
	"#..........................#",
	"#.####.##.########.##.####.#",
	"#.####.##.########.##.####.#",
	"#......##....##....##......#",
	"######.#####.##.#####.######",
	"######.#####.##.#####.######",
	"######.##..........##.######",
	"######.##.###..###.##.######",
	"######.##.#......#.##.######",
	"..........#......#..........",
	"######.##.#......#.##.######",
	"######.##.########.##.######",
	"######.##..........##.######",
	"######.##.########.##.######",
	"######.##.########.##.######",
	"#............##............#",
	"#.####.#####.##.#####.####.#",
	"#.####.#####.##.#####.####.#",
	"#...##................##...#",
	"###.##.##.########.##.##.###",
	"###.##.##.########.##.##.###",
	"#......##....##....##......#",
	"#.##########.##.##########.#",
	"#.##########.##.##########.#",
	"#..........................#",
	"############################",
]

static var REMAKE_LAYOUT := [
	"#######################################################",
	"#######################################################",
	"##.....................####.####.....................##",
	"##..#######...#######..####.####..#######...#######..##",
	"##.#########.#########.####.####.#########.#########.##",
	"##.#########.#########.####.####.#########.#########.##",
	"##..#######...#######...##...##...#######...#######..##",
	"##...................................................##",
	"##..#######...############...############...#######..##",
	"##.#########.##############.##############.#########.##",
	"##.######.##.##############.##############.##.######.##",
	"##..######.#..############...############..#.######..##",
	"##......##.#...............................#.##......##",
	"######..#..#..#######...##...##...#######..#..#..######",
	"#######.#..#.#########.####.####.#########.#..#.#######",
	"#######.####.#########.####.####.#########.####.#######",
	"######...##...#######..#..#.#..#..#######...##...######",
	".......................#..#.#..#.......................",
	"######...##...#######..#..#.#..#..#######...##...######",
	"#######.####.#########.#..#.#..#.#########.####.#######",
	"#######.####.#########.####.####.#########.####.#######",
	"######..#..#..#######...##...##...#######..#..#..######",
	"##......##.#...............................#.##......##",
	"##..######.#..############...############..#.######..##",
	"##.######..#.##############.##############.#..######.##",
	"##.#########.##############.##############.#########.##",
	"##..#######...############...############...#######..##",
	"##...................................................##",
	"##..#######...#######...##...##...#######...#######..##",
	"##.#########.#########.####.####.#########.#########.##",
	"##.#########.#########.####.####.#########.#########.##",
	"##..#######...#######..####.####..#######...#######..##",
	"##.....................####.####.....................##",
	"#######################################################",
]

# Remake: casa en el corredor central, salida arriba y tunel horizontal.
static var REMAKE_HOUSE_CENTER := Vector2i(27, 17)
static var REMAKE_HOUSE_EXIT := Vector2i(27, 13)
static var REMAKE_DOOR_TILES := []
static var REMAKE_TUNNEL_ROWS := [17]
static var REMAKE_GHOST_START := {
	"blinky": REMAKE_HOUSE_EXIT,
	"pinky": REMAKE_HOUSE_CENTER,
	"inky": Vector2i(25, 17),
	"clyde": Vector2i(29, 17),
}
static var REMAKE_GHOST_RELEASE := {"blinky": 0.0, "pinky": 1.2, "inky": 3.0, "clyde": 5.0}
static var REMAKE_PAC_STARTS := [
	Vector2i(27, 28), Vector2i(22, 28), Vector2i(32, 28), Vector2i(13, 27),
]
static var REMAKE_SCATTER_TARGETS := {
	"blinky": Vector2i(54, -3),
	"pinky": Vector2i(0, -3),
	"inky": Vector2i(55, 36),
	"clyde": Vector2i(0, 36),
}
static var REMAKE_FRUIT_TILE := Vector2i(27, 27)
static var REMAKE_POWER_PELLETS := [
	Vector2i(3, 2), Vector2i(51, 2), Vector2i(3, 31), Vector2i(51, 31),
]

static var DIRS := {
	"right": Vector2i(1, 0),
	"left": Vector2i(-1, 0),
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
}
static var DIR_ORDER := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
