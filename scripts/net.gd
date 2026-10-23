extends Node
class_name NetClient

signal connected
signal disconnected
signal welcome(player_id, host_id, room_code)
signal room_updated(room)
signal started(data)
signal snapshot(data)
signal input_received(data)
signal room_closed(reason)
signal lobby_return
signal peer_left(player_id)
signal error_message(text)

var ws: WebSocketPeer = null
var player_id := ""
var host_id := ""
var room_code := ""
var url := ""
var status := "offline"
var auto_reconnect := true
var last_error := ""
var retry_timer := 0.0
var was_open := false
var intentional_close := false

func _ready() -> void:
	url = default_url()
	connect_to_server()

func default_url() -> String:
	if OS.has_feature("web"):
		var base: String = str(JavaScriptBridge.eval("window.location.protocol + '//' + window.location.host"))
		return base.replace("http://", "ws://").replace("https://", "wss://") + "/ws"
	var env := OS.get_environment("PACMAN_WS")
	if env != "":
		return env
	return "ws://127.0.0.1:3000/ws"

func connect_to_server(target := "") -> void:
	if target != "":
		url = target
	intentional_close = false
	if ws != null:
		ws.close()
	ws = WebSocketPeer.new()
	var err := ws.connect_to_url(url)
	if err != OK:
		status = "error"
		last_error = "No se pudo abrir el WebSocket (%s)" % err
		emit_signal("error_message", last_error)
		return
	status = "connecting"
	was_open = false
	retry_timer = 0.0

func close() -> void:
	intentional_close = true
	if ws != null:
		ws.close()
	status = "offline"
	player_id = ""
	host_id = ""
	room_code = ""

func _process(delta: float) -> void:
	if ws == null:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not was_open:
			was_open = true
			status = "online"
			last_error = ""
			emit_signal("connected")
		while ws.get_available_packet_count() > 0:
			var packet := ws.get_packet()
			if packet.is_empty():
				continue
			var text := packet.get_string_from_utf8()
			_handle_text(text)
	elif st == WebSocketPeer.STATE_CLOSED:
		if was_open:
			was_open = false
			status = "offline"
			player_id = ""
			host_id = ""
			room_code = ""
			emit_signal("disconnected")
		if not intentional_close:
			retry_timer -= delta
			if retry_timer <= 0.0:
				retry_timer = 2.0
				connect_to_server()

func send_dict(msg: Dictionary) -> bool:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	ws.send_text(JSON.stringify(msg))
	return true

func _handle_text(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = parsed
	match str(msg.get("type", "")):
		"welcome":
			player_id = str(msg.get("playerId", ""))
			host_id = str(msg.get("hostId", ""))
			room_code = str(msg.get("room", ""))
			status = "in_room"
			emit_signal("welcome", player_id, host_id, room_code)
		"room":
			var room = msg.get("room", {})
			if typeof(room) == TYPE_DICTIONARY:
				host_id = str(room.get("hostId", host_id))
				room_code = str(room.get("code", room_code))
				emit_signal("room_updated", room)
		"start":
			emit_signal("started", msg.get("data", {}))
		"snapshot":
			emit_signal("snapshot", msg.get("data", {}))
		"input":
			emit_signal("input_received", msg)
		"host_changed":
			host_id = str(msg.get("hostId", host_id))
		"lobby_return":
			status = "in_room"
			emit_signal("lobby_return")
		"peer_left":
			emit_signal("peer_left", str(msg.get("playerId", "")))
		"room_closed":
			status = "online"
			room_code = ""
			host_id = ""
			emit_signal("room_closed", str(msg.get("reason", "closed")))
		"error":
			var e := str(msg.get("message", "Error de red"))
			last_error = e
			emit_signal("error_message", e)
