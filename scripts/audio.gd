extends Node
class_name GameAudio

const NAMES := [
	"waka1", "waka2", "power", "eatghost", "fruit", "extra", "death",
	"select", "start", "intro", "siren", "fright",
]

var ok := false
var muted := false
var streams: Dictionary = {}
var players: Array = []
var waka_player: AudioStreamPlayer
var loop_player: AudioStreamPlayer
var loop_name := ""
var loop_volume := 0.42
var rr := 0

func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)
	waka_player = AudioStreamPlayer.new()
	waka_player.bus = "Master"
	add_child(waka_player)
	loop_player = AudioStreamPlayer.new()
	loop_player.bus = "Master"
	add_child(loop_player)
	loop_player.finished.connect(_on_loop_finished)

	for n in NAMES:
		var path: String = "res://assets/sounds/" + n + ".wav"
		if ResourceLoader.exists(path):
			var st = load(path)
			if st is AudioStream:
				streams[n] = st
	ok = not streams.is_empty()

func _db(volume: float) -> float:
	return linear_to_db(clampf(volume, 0.0001, 1.0))

func play(name: String, volume := 0.9) -> void:
	if not ok or muted or not streams.has(name):
		return
	var p: AudioStreamPlayer = null
	for q in players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = players[rr % players.size()]
		rr += 1
	p.stream = streams[name]
	p.volume_db = _db(volume)
	p.play()

func play_waka(alternate: bool) -> void:
	if not ok or muted:
		return
	var name := "waka2" if alternate else "waka1"
	if not streams.has(name):
		return
	waka_player.stream = streams[name]
	waka_player.volume_db = _db(0.55)
	waka_player.play()

func set_loop(name: String, volume := 0.35) -> void:
	if not ok:
		return
	if muted:
		stop_loop()
		return
	if name == loop_name:
		loop_volume = volume
		return
	loop_player.stop()
	loop_name = name
	loop_volume = volume
	if name != "" and streams.has(name):
		loop_player.stream = streams[name]
		loop_player.volume_db = _db(volume)
		loop_player.play()

func stop_loop() -> void:
	loop_name = ""
	if loop_player:
		loop_player.stop()

func stop_all() -> void:
	stop_loop()
	if waka_player:
		waka_player.stop()
	for p in players:
		p.stop()

func toggle_mute() -> bool:
	if not ok:
		return muted
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	if muted:
		stop_all()
	return muted

func _on_loop_finished() -> void:
	if loop_name != "" and not muted and loop_player.stream != null:
		loop_player.play()
