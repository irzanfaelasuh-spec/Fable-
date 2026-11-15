extends Node

signal connected_to_server
signal disconnected_from_server(reason: String)
signal connection_error(reason: String)
signal message_received(payload: Dictionary)

var _socket: WebSocketPeer
var _url := ""
var _connecting := false
var _was_open := false
var _queue: Array[Dictionary] = []
var _heartbeat_clock := 0.0

func connect_to_server(url: String) -> void:
	close_connection()
	_url = url.strip_edges()
	if not (_url.begins_with("ws://") or _url.begins_with("wss://")):
		connection_error.emit("Server URL harus diawali ws:// atau wss://.")
		return
	_socket = WebSocketPeer.new()
	_socket.heartbeat_interval = 0.0
	_socket.inbound_buffer_size = 65535
	_socket.outbound_buffer_size = 65535
	var err := _socket.connect_to_url(_url)
	if err != OK:
		_socket = null
		connection_error.emit("Tidak dapat memulai koneksi WebSocket. Periksa URL server.")
		return
	_connecting = true
	_was_open = false
	_heartbeat_clock = 0.0

func send_data(payload: Dictionary) -> bool:
	if _socket == null:
		return false
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return _send_now(payload)
	if _queue.size() >= 32:
		return false
	_queue.append(payload.duplicate(true))
	return true

func _send_now(payload: Dictionary) -> bool:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	var result := _socket.send_text(JSON.stringify(payload))
	return result == OK

func is_connected_to_server() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func close_connection() -> void:
	if _socket != null:
		if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_socket.close(1000, "client closing")
		_socket = null
	_connecting = false
	_was_open = false
	_queue.clear()

func _process(delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		_connecting = false
		connected_to_server.emit()
		for item in _queue:
			_send_now(item)
		_queue.clear()
	elif state == WebSocketPeer.STATE_CLOSED:
		var reason := _socket.get_close_reason()
		var was_open := _was_open
		var was_connecting := _connecting
		_socket = null
		_connecting = false
		_was_open = false
		_queue.clear()
		if was_open:
			disconnected_from_server.emit(reason if not reason.is_empty() else "Koneksi terputus.")
		elif was_connecting:
			connection_error.emit("Server tidak tersedia. Periksa alamat server atau coba lagi.")
		return
	if state == WebSocketPeer.STATE_OPEN:
		_heartbeat_clock += delta
		if _heartbeat_clock >= 25.0:
			_heartbeat_clock = 0.0
			_send_now({"type": "heartbeat"})
		while _socket != null and _socket.get_available_packet_count() > 0:
			var packet := _socket.get_packet()
			if not _socket.was_string_packet():
				continue
			var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if parsed is Dictionary:
				message_received.emit(parsed)
