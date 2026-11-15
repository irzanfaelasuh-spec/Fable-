extends Node2D

const NetworkClientScript = preload("res://scripts/network_client.gd")
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const RemotePlayerScript = preload("res://scripts/remote_player.gd")
const VirtualJoystickScript = preload("res://scripts/virtual_joystick.gd")
const ItemDropScript = preload("res://scripts/item_drop.gd")

const UI_BG := Color("#14232a")
const UI_PANEL := Color("#1d3037")
const UI_PANEL_LIGHT := Color("#29434a")
const UI_LINE := Color("#527a72")
const UI_TEXT := Color("#edf0dc")
const UI_MUTED := Color("#a6b8aa")
const UI_ACCENT := Color("#a8cd82")
const UI_ACCENT_DARK := Color("#547d5b")
const UI_DANGER := Color("#d78373")

var network
var ui_layer: CanvasLayer
var ui_root: Control
var world_node
var player_node
var remote_players: Dictionary = {}
var game_hud: Control
var chat_panel: PanelContainer
var chat_feed: VBoxContainer
var chat_input: LineEdit
var chat_toggle: Button
var chat_notice: Label
var inventory_label: Label
var inventory_panel: PanelContainer
var inventory_items_label: Label
var action_notice: Label
var room_status_label: Label

var auth_mode := "login"
var auth_username: LineEdit
var auth_password: LineEdit
var auth_confirm: LineEdit
var auth_server: LineEdit
var auth_status: Label
var pending_auth: Dictionary = {}
var current_username := ""
var current_player_id := ""
var server_url := ""
var world_records: Array = []
var selected_world: Dictionary = {}
var current_world_name := ""
var is_multiplayer := false
var is_host := false
var room_code := ""
var room_seed := 1
var room_players: Array = []
var game_position_clock := 0.0
var autosave_clock := 0.0
var notification_clock := 0.0
var chat_unread := 0
var current_screen := "splash"
var settings_server: LineEdit
var settings_status: Label

func _ready() -> void:
	if OS.has_feature("android"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	randomize()
	_load_settings()
	_load_world_records()
	network = NetworkClientScript.new()
	add_child(network)
	network.connected_to_server.connect(_on_network_connected)
	network.disconnected_from_server.connect(_on_network_disconnected)
	network.connection_error.connect(_on_network_error)
	network.message_received.connect(_on_network_message)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)
	_show_splash()

func _process(delta: float) -> void:
	if current_screen != "game":
		queue_redraw()
	if player_node != null and is_multiplayer and network.is_connected_to_server():
		game_position_clock += delta
		if game_position_clock >= 0.08:
			game_position_clock = 0.0
			network.send_data({"type": "move", "x": player_node.position.x, "y": player_node.position.y})
	if player_node != null and not is_multiplayer:
		autosave_clock += delta
		if autosave_clock >= 25.0:
			autosave_clock = 0.0
			_save_current_world()
	if notification_clock > 0.0:
		notification_clock -= delta
		if notification_clock <= 0.0 and chat_notice != null and is_instance_valid(chat_notice):
			chat_notice.visible = false

func _draw() -> void:
	if current_screen == "game":
		return
	var size := get_viewport_rect().size
	var width := size.x
	var height := size.y
	for band in range(10):
		var t := float(band) / 9.0
		var a := Color("#6f9fb0").lerp(Color("#e1c49a"), t)
		draw_rect(Rect2(0, height * t, width, height / 10.0 + 2.0), a)
	draw_circle(Vector2(width * 0.79, height * 0.22), 42.0, Color("#f4d49b"))
	_draw_menu_hills(width, height)
	_draw_menu_clouds(width, height)

func _draw_menu_hills(width: float, height: float) -> void:
	var back := PackedVector2Array([Vector2(0, height * 0.61)])
	for i in range(13):
		var x := float(i) * width / 12.0
		var y := height * 0.57 + sin(float(i) * 1.7) * 38.0
		back.append(Vector2(x, y))
	back.append(Vector2(width, height))
	back.append(Vector2(0, height))
	draw_colored_polygon(back, Color("#78917b"))
	var front := PackedVector2Array([Vector2(0, height * 0.75)])
	for i in range(13):
		var x := float(i) * width / 12.0
		var y := height * 0.72 + sin(float(i) * 1.3 + 0.8) * 43.0
		front.append(Vector2(x, y))
	front.append(Vector2(width, height))
	front.append(Vector2(0, height))
	draw_colored_polygon(front, Color("#456d57"))
	draw_rect(Rect2(0, height * 0.87, width, height * 0.13), Color("#375b4a"))
	for i in range(22):
		var x := fposmod(float(i) * 79.0 + 19.0, width)
		var y := height * 0.87 + fposmod(float(i) * 17.0, height * 0.12)
		draw_rect(Rect2(x, y, 4, 7), Color("#a4bd7d"))
	# Small silhouette cottage: drawn geometry, not an image.
	var hx := width * 0.18
	var hy := height * 0.77
	draw_rect(Rect2(hx, hy - 64, 100, 66), Color("#bd9871"))
	draw_colored_polygon(PackedVector2Array([Vector2(hx - 12, hy - 63), Vector2(hx + 50, hy - 116), Vector2(hx + 112, hy - 63)]), Color("#76534b"))
	draw_rect(Rect2(hx + 42, hy - 35, 19, 37), Color("#674638"))
	draw_rect(Rect2(hx + 13, hy - 48, 18, 18), Color("#98c0b9"))
	draw_rect(Rect2(hx + 72, hy - 48, 18, 18), Color("#98c0b9"))
	for i in range(5):
		var tx := width * 0.54 + float(i) * 95.0
		var ty := height * 0.84 + sin(float(i) * 2.0) * 12.0
		draw_rect(Rect2(tx - 5, ty - 64, 10, 66), Color("#79513a"))
		draw_rect(Rect2(tx - 31, ty - 95, 62, 48), Color("#3e7654"))
		draw_rect(Rect2(tx - 21, ty - 109, 42, 25), Color("#5b9460"))

func _draw_menu_clouds(width: float, height: float) -> void:
	var t := float(Time.get_ticks_msec()) * 0.003
	for i in range(5):
		var x := fposmod(float(i) * 310.0 + t * 8.0, width + 160.0) - 80.0
		var y := height * (0.16 + float(i % 3) * 0.09)
		var color := Color(0.96, 0.97, 0.89, 0.72)
		draw_rect(Rect2(x, y + 8, 74, 19), color)
		draw_rect(Rect2(x + 13, y, 38, 28), color)
		draw_rect(Rect2(x + 50, y + 9, 30, 17), color)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		server_url = str(config.get_value("network", "server_url", ""))
	else:
		server_url = ""

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("network", "server_url", server_url)
	config.save("user://settings.cfg")

func _load_world_records() -> void:
	world_records.clear()
	if not FileAccess.file_exists("user://worlds.json"):
		return
	var file := FileAccess.open("user://worlds.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				world_records.append(item)

func _write_world_records() -> void:
	var file := FileAccess.open("user://worlds.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(world_records, "\t"))

func _show_splash() -> void:
	current_screen = "splash"
	_clear_ui()
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_CENTER)
	stack.position = Vector2(-260, -115)
	stack.size = Vector2(520, 230)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	ui_root.add_child(stack)
	var title := _make_label("FABLEBRINK", 46, UI_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var tagline := _make_label("BUILD BEYOND THE KNOWN", 13, Color("#e4d8b5"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(tagline)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(360, 12)
	progress.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI_ACCENT
	progress.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.15, 0.17, 0.8)
	background.border_color = UI_LINE
	background.set_border_width_all(1)
	progress.add_theme_stylebox_override("background", background)
	stack.add_child(progress)
	var tween := create_tween()
	tween.tween_property(progress, "value", 100.0, 1.55).from(0.0)
	var loading := _make_label("PREPARING THE WORLD", 11, UI_MUTED)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(loading)
	await get_tree().create_timer(1.7).timeout
	_show_auth("login")

func _clear_ui() -> void:
	if ui_root == null:
		return
	for child in ui_root.get_children():
		child.queue_free()
	game_hud = null
	chat_panel = null
	chat_feed = null
	chat_input = null
	chat_toggle = null
	chat_notice = null
	inventory_label = null
	inventory_panel = null
	inventory_items_label = null
	action_notice = null
	room_status_label = null

func _make_panel(title_text: String, subtitle_text: String = "", panel_size: Vector2 = Vector2(860, 560)) -> VBoxContainer:
	_clear_ui()
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_size.x / 2.0
	panel.offset_right = panel_size.x / 2.0
	panel.offset_top = -panel_size.y / 2.0
	panel.offset_bottom = panel_size.y / 2.0
	panel.add_theme_stylebox_override("panel", _panel_style(UI_PANEL, UI_LINE, 2))
	ui_root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var heading := _make_label(title_text, 27, UI_TEXT)
	stack.add_child(heading)
	if not subtitle_text.is_empty():
		var subtitle := _make_label(subtitle_text, 12, UI_MUTED)
		stack.add_child(subtitle)
	var line := ColorRect.new()
	line.color = UI_LINE
	line.custom_minimum_size = Vector2(0, 2)
	stack.add_child(line)
	return stack

func _make_label(text_value: String, size: int = 16, color: Color = UI_TEXT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _panel_style(bg: Color, border: Color = UI_LINE, thickness: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(thickness)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 14
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_button(text_value: String, callback: Callable, min_height: float = 46.0) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, min_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", Color("#152b26"))
	button.add_theme_color_override("font_pressed_color", Color("#152b26"))
	button.add_theme_stylebox_override("normal", _panel_style(UI_PANEL_LIGHT, UI_LINE, 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_ACCENT, UI_ACCENT, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#82ad70"), UI_ACCENT_DARK, 1))
	button.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), UI_ACCENT, 1))
	button.pressed.connect(callback)
	return button

func _make_line_edit(parent: Node, placeholder: String, secret: bool = false) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.secret = secret
	edit.custom_minimum_size = Vector2(0, 42)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 14)
	edit.add_theme_color_override("font_color", UI_TEXT)
	edit.add_theme_color_override("font_placeholder_color", UI_MUTED)
	edit.add_theme_stylebox_override("normal", _panel_style(Color("#101f26"), Color("#425f5c"), 1))
	edit.add_theme_stylebox_override("focus", _panel_style(Color("#101f26"), UI_ACCENT, 2))
	if parent != null:
		parent.add_child(edit)
	return edit

func _show_auth(mode: String) -> void:
	current_screen = "auth"
	auth_mode = mode
	var stack := _make_panel("ACCOUNT ACCESS", "Create a new identity or sign in to continue.", Vector2(900, 590))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 28)
	stack.add_child(row)
	var brand := VBoxContainer.new()
	brand.custom_minimum_size = Vector2(310, 0)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(brand)
	var mark := _make_label("FB", 54, UI_ACCENT)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_child(mark)
	var brand_title := _make_label("FABLEBRINK", 22, UI_TEXT)
	brand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_child(brand_title)
	var brand_note := _make_label("A small world can hold\na very long adventure.", 13, UI_MUTED)
	brand_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_child(brand_note)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 9)
	row.add_child(form)
	var mode_row := HBoxContainer.new()
	form.add_child(mode_row)
	mode_row.add_child(_make_button("LOGIN", func(): _show_auth("login"), 38))
	mode_row.add_child(_make_button("CREATE ACCOUNT", func(): _show_auth("create"), 38))
	form.add_child(_make_label("USERNAME", 11, UI_MUTED))
	auth_username = _make_line_edit(form, "3–16 characters · letters, numbers, _")
	form.add_child(_make_label("PASSWORD", 11, UI_MUTED))
	auth_password = _make_line_edit(form, "At least 8 characters", true)
	if auth_mode == "create":
		form.add_child(_make_label("CONFIRM PASSWORD", 11, UI_MUTED))
		auth_confirm = _make_line_edit(form, "Repeat your password", true)
	else:
		auth_confirm = null
	form.add_child(_make_label("SERVER ADDRESS", 11, UI_MUTED))
	auth_server = _make_line_edit(form, "wss://your-server.example/ws")
	auth_server.text = server_url
	auth_status = _make_label("", 12, UI_MUTED)
	form.add_child(auth_status)
	var submit_text := "CREATE ACCOUNT" if auth_mode == "create" else "LOGIN"
	form.add_child(_make_button(submit_text, _submit_auth, 50))
	var footer := _make_label("Usernames are unique. Passwords are protected on the server.", 10, UI_MUTED)
	form.add_child(footer)
	if auth_mode == "create":
		auth_confirm.grab_focus()
	else:
		auth_username.grab_focus()

func _submit_auth() -> void:
	var username := auth_username.text.strip_edges()
	var password := auth_password.text
	server_url = auth_server.text.strip_edges()
	_save_settings()
	if not (server_url.begins_with("wss://") or server_url.begins_with("ws://")):
		auth_status.text = "Masukkan alamat WebSocket server yang valid."
		auth_status.add_theme_color_override("font_color", UI_DANGER)
		return
	var username_rule := RegEx.new()
	username_rule.compile("^[A-Za-z0-9_]{3,16}$")
	if username_rule.search(username) == null:
		auth_status.text = "Username 3–16 karakter: huruf, angka, atau underscore."
		auth_status.add_theme_color_override("font_color", UI_DANGER)
		return
	if password.length() < 8:
		auth_status.text = "Password minimal 8 karakter."
		auth_status.add_theme_color_override("font_color", UI_DANGER)
		return
	if auth_mode == "create" and (auth_confirm == null or auth_confirm.text != password):
		auth_status.text = "Konfirmasi password tidak cocok."
		auth_status.add_theme_color_override("font_color", UI_DANGER)
		return
	pending_auth = {"type": "register" if auth_mode == "create" else "login", "username": username, "password": password}
	auth_status.text = "Menghubungkan ke server..."
	auth_status.add_theme_color_override("font_color", UI_ACCENT)
	network.connect_to_server(server_url)

func _on_network_connected() -> void:
	if not pending_auth.is_empty():
		network.send_data(pending_auth)
		pending_auth.clear()

func _on_network_error(reason: String) -> void:
	if current_screen == "auth" and auth_status != null and is_instance_valid(auth_status):
		auth_status.text = "SERVER UNAVAILABLE · " + reason
		auth_status.add_theme_color_override("font_color", UI_DANGER)
	else:
		_show_room_notice("SERVER UNAVAILABLE · Periksa koneksi internet dan alamat server.")

func _on_network_disconnected(reason: String) -> void:
	if current_screen == "game" and is_multiplayer:
		_show_notice("Koneksi terputus: " + reason)

func _on_network_message(payload: Dictionary) -> void:
	var message_type := str(payload.get("type", ""))
	match message_type:
		"server_ready", "heartbeat_ack":
			pass
		"auth_result":
			if bool(payload.get("ok", false)):
				current_username = str(payload.get("username", "Player"))
				current_player_id = str(payload.get("playerId", ""))
				pending_auth.clear()
				_show_menu()
			else:
				var code := str(payload.get("code", "server_error"))
				if auth_status != null and is_instance_valid(auth_status):
					auth_status.text = _auth_error_text(code)
					auth_status.add_theme_color_override("font_color", UI_DANGER)
		"room_created", "room_joined":
			room_code = str(payload.get("code", ""))
			room_seed = int(payload.get("seed", 1))
			room_players = payload.get("players", [])
			is_host = str(payload.get("hostId", "")) == current_player_id
			_show_lobby()
		"room_update":
			room_players = payload.get("players", [])
			is_host = str(payload.get("hostId", "")) == current_player_id
			if current_screen == "lobby":
				_show_lobby()
			elif current_screen == "game":
				_sync_remote_players(room_players)
		"game_started":
			room_seed = int(payload.get("seed", room_seed))
			room_players = payload.get("players", room_players)
			_enter_game({"name": "Online World", "seed": room_seed, "changes": {}}, true)
		"room_error":
			_show_room_notice(_room_error_text(str(payload.get("code", "server_error"))))
		"player_moved":
			var player_id := str(payload.get("id", ""))
			if remote_players.has(player_id):
				remote_players[player_id].set_target(Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0))))
		"block_changed":
			if world_node != null:
				world_node.apply_remote_change(str(payload.get("action", "break")), int(payload.get("x", 0)), int(payload.get("y", 0)), int(payload.get("block", 2)))
		"chat_message":
			_add_chat_message(str(payload.get("username", "Player")), str(payload.get("message", "")))
		"chat_rejected":
			_show_notice("Pesan terlalu cepat. Coba sebentar lagi.")
		"player_emote":
			var emote_player_id := str(payload.get("id", ""))
			if emote_player_id == current_player_id and player_node != null:
				player_node.show_emote(str(payload.get("emote", "hi")))
			elif remote_players.has(emote_player_id):
				remote_players[emote_player_id].show_emote(str(payload.get("emote", "hi")))
		"room_closed", "left_room":
			if current_screen == "game" or current_screen == "lobby":
				_end_game(false)
				_show_menu()
		"logout_result":
			pass
		"error":
			_show_notice("Terjadi kesalahan komunikasi dengan server.")

func _auth_error_text(code: String) -> String:
	match code:
		"username_taken": return "Username sudah digunakan. Coba username lain."
		"invalid_input": return "Username atau password tidak memenuhi aturan."
		"invalid_credentials": return "Username atau password salah."
		"rate_limited": return "Terlalu banyak percobaan. Coba lagi sebentar."
		"server_error": return "Server mengalami kesalahan. Coba lagi nanti."
		_: return "Login atau pendaftaran gagal: " + code

func _show_room_notice(message: String) -> void:
	if room_status_label != null and is_instance_valid(room_status_label):
		room_status_label.text = message
		room_status_label.add_theme_color_override("font_color", UI_DANGER)
	else:
		_show_notice(message)

func _room_error_text(code: String) -> String:
	match code:
		"invalid_code": return "INVALID CODE · Kode room tidak ditemukan."
		"full": return "SERVER FULL · Room sudah berisi 5 pemain."
		"expired": return "ROOM EXPIRED · Host sudah memulai permainan atau room ditutup."
		"not_host": return "Hanya host yang dapat melakukan tindakan ini."
		"not_authenticated": return "Login ulang diperlukan."
		_: return "ROOM ERROR · " + code

func _show_menu() -> void:
	current_screen = "menu"
	var stack := _make_panel("FABLEBRINK", "A living pixel world, made to be shaped together.", Vector2(900, 560))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 30)
	stack.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(365, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(left)
	var monogram := _make_label("F / B", 42, UI_ACCENT)
	monogram.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(monogram)
	var welcome := _make_label("WELCOME BACK, " + current_username.to_upper(), 13, UI_TEXT)
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(welcome)
	var lore := _make_label("Explore the ridgelines.\nBuild a place to return to.\nBring a friend along.", 14, UI_MUTED)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(lore)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 11)
	body.add_child(right)
	right.add_child(_make_button("PLAY  /  SINGLEPLAYER", _show_world_select, 54))
	right.add_child(_make_button("MULTIPLAYER", _show_multiplayer, 54))
	right.add_child(_make_button("SETTINGS", _show_settings, 44))
	right.add_child(_make_button("ABOUT", _show_about, 44))
	right.add_child(_make_button("LOG OUT", _logout, 42))
	right.add_child(_make_button("EXIT", func(): get_tree().quit(), 42))
	var foot := _make_label("ANDROID LANDSCAPE  ·  PC KEYBOARD  ·  ONLINE CO-OP 5P", 10, UI_MUTED)
	stack.add_child(foot)

func _show_world_select() -> void:
	current_screen = "world_select"
	var stack := _make_panel("YOUR WORLDS", "Each world has its own name, seed, and local save.", Vector2(900, 580))
	stack.add_child(_make_button("+  CREATE NEW WORLD", _show_create_world, 48))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	if world_records.is_empty():
		list.add_child(_make_label("No worlds yet. Create your first world to begin.", 14, UI_MUTED))
	else:
		for index in range(world_records.size()):
			var record: Dictionary = world_records[index]
			var world_index := index
			var label_text := str(record.get("name", "Unnamed")) + "    ·    SEED " + str(record.get("seed", 0))
			list.add_child(_make_button(label_text + "     [ PLAY ]", func(): _open_saved_world(world_index), 48))
	stack.add_child(_make_button("BACK TO MENU", _show_menu, 42))

func _show_create_world() -> void:
	current_screen = "world_create"
	var stack := _make_panel("CREATE WORLD", "Choose a name. The generated terrain will be saved on this device.", Vector2(760, 470))
	stack.add_child(_make_label("WORLD NAME", 11, UI_MUTED))
	var name_edit := _make_line_edit(stack, "e.g. Quiet Valley")
	var status := _make_label("World names can contain up to 24 characters.", 11, UI_MUTED)
	stack.add_child(status)
	stack.add_child(_make_button("CREATE & PLAY", func():
		var title := name_edit.text.strip_edges()
		if title.length() < 2 or title.length() > 24:
			status.text = "Nama dunia harus terdiri dari 2–24 karakter."
			status.add_theme_color_override("font_color", UI_DANGER)
			return
		var record := {"id": str(Time.get_unix_time_from_system()) + "_" + str(randi_range(1000, 9999)), "name": title, "seed": randi_range(1000, 2147483000), "changes": {}, "updated": Time.get_unix_time_from_system()}
		world_records.append(record)
		_write_world_records()
		selected_world = record
		_enter_game(record, false)
	, 52))
	stack.add_child(_make_button("CANCEL", _show_world_select, 42))

func _open_saved_world(index: int) -> void:
	if index < 0 or index >= world_records.size():
		return
	selected_world = world_records[index]
	_enter_game(selected_world, false)

func _show_multiplayer() -> void:
	current_screen = "multiplayer"
	var stack := _make_panel("MULTIPLAYER", "Create a temporary room or join a friend using their code.", Vector2(760, 480))
	stack.add_child(_make_button("HOST A ROOM", _host_room, 58))
	stack.add_child(_make_button("JOIN A ROOM", _show_join_room, 58))
	stack.add_child(_make_label("MAXIMUM 5 PLAYERS  ·  FRIENDS CAN JOIN UNTIL THE HOST STARTS", 10, UI_MUTED))
	room_status_label = _make_label("Server address is set on the Login screen or in Settings.", 11, UI_MUTED)
	stack.add_child(room_status_label)
	stack.add_child(_make_button("BACK", _show_menu, 42))

func _host_room() -> void:
	if not network.is_connected_to_server():
		_show_room_notice("SERVER UNAVAILABLE · Periksa Server Address di Settings.")
		return
	network.send_data({"type": "create_room"})

func _show_join_room() -> void:
	current_screen = "join_room"
	var stack := _make_panel("JOIN A ROOM", "Ask the host for their 6-character room code.", Vector2(700, 430))
	stack.add_child(_make_label("ENTER THE CODE", 12, UI_MUTED))
	var code_edit := _make_line_edit(stack, "A B C 1 2 3")
	code_edit.max_length = 6
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.add_theme_font_size_override("font_size", 25)
	var status := _make_label("Codes are only valid while the host is in the lobby.", 11, UI_MUTED)
	room_status_label = status
	stack.add_child(status)
	stack.add_child(_make_button("JOIN", func():
		var code := code_edit.text.strip_edges().to_upper()
		if code.length() != 6:
			status.text = "Masukkan kode lengkap 6 karakter."
			status.add_theme_color_override("font_color", UI_DANGER)
			return
		if not network.is_connected_to_server():
			status.text = "Server tidak tersedia. Periksa koneksi."
			status.add_theme_color_override("font_color", UI_DANGER)
			return
		network.send_data({"type": "join_room", "code": code})
		status.text = "Mencari room..."
	, 52))
	stack.add_child(_make_button("BACK", _show_multiplayer, 42))

func _show_lobby() -> void:
	current_screen = "lobby"
	var stack := _make_panel("ROOM LOBBY", "Share the code. Players can join until the host starts.", Vector2(760, 560))
	var code_label := _make_label(room_code, 42, UI_ACCENT)
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(code_label)
	var count_label := _make_label("PLAYERS  %d / 5" % room_players.size(), 13, UI_TEXT)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(count_label)
	stack.add_child(_make_button("COPY ROOM CODE", func():
		DisplayServer.clipboard_set(room_code)
		if room_status_label != null and is_instance_valid(room_status_label):
			room_status_label.text = "CODE COPIED · Send it to your friends."
			room_status_label.add_theme_color_override("font_color", UI_ACCENT)
	, 38))
	room_status_label = _make_label("Waiting for friends to join.", 11, UI_MUTED)
	room_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(room_status_label)
	var list_panel := PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", _panel_style(Color("#13242a"), UI_LINE, 1))
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(list_panel)
	var list := VBoxContainer.new()
	list_panel.add_child(list)
	for player in room_players:
		if player is Dictionary:
			var badge := "HOST" if bool(player.get("host", false)) else "PLAYER"
			list.add_child(_make_label(str(player.get("username", "Player")) + "    ·    " + badge, 15, UI_TEXT))
	if room_players.is_empty():
		list.add_child(_make_label("Waiting for players...", 13, UI_MUTED))
	if is_host:
		stack.add_child(_make_button("START GAME", func(): network.send_data({"type": "start_game"}), 54))
		stack.add_child(_make_button("CLOSE ROOM", func(): network.send_data({"type": "close_room"}), 40))
	else:
		stack.add_child(_make_label("Waiting for the host to start the world...", 12, UI_MUTED))
		stack.add_child(_make_button("LEAVE ROOM", func():
			network.send_data({"type": "leave_room"})
			_show_multiplayer()
		, 42))

func _show_settings() -> void:
	current_screen = "settings"
	var stack := _make_panel("SETTINGS", "Display and connection preferences.", Vector2(760, 480))
	stack.add_child(_make_label("MULTIPLAYER SERVER URL", 11, UI_MUTED))
	settings_server = _make_line_edit(stack, "wss://your-server.example/ws")
	settings_server.text = server_url
	settings_status = _make_label("Use the secure wss:// address provided by your server host.", 11, UI_MUTED)
	stack.add_child(settings_status)
	stack.add_child(_make_button("SAVE SETTINGS", func():
		server_url = settings_server.text.strip_edges()
		if not (server_url.begins_with("wss://") or server_url.begins_with("ws://")):
			settings_status.text = "URL belum valid. Gunakan ws:// atau wss://."
			settings_status.add_theme_color_override("font_color", UI_DANGER)
			return
		_save_settings()
		settings_status.text = "Settings saved on this device."
		settings_status.add_theme_color_override("font_color", UI_ACCENT)
	, 48))
	stack.add_child(_make_label("SCREEN  Landscape only\nControls  WASD / Space / F mine / G place\nTouch  On-screen movement and action controls", 12, UI_MUTED))
	stack.add_child(_make_button("BACK", _show_menu, 42))

func _show_about() -> void:
	current_screen = "about"
	var stack := _make_panel("ABOUT FABLEBRINK", "A code-first pixel sandbox prototype.", Vector2(780, 500))
	stack.add_child(_make_label("Explore a procedurally generated landscape, gather materials,\nplace blocks, and share a small world with up to four friends.\n\nBuilt with Godot 4.7.2, GDScript and a lightweight Node.js\nWebSocket server. No Firebase and no bundled art packs.\n\nPrototype build 0.1.0 · Original procedural visuals", 15, UI_TEXT))
	stack.add_child(_make_button("BACK", _show_menu, 44))

func _logout() -> void:
	if network.is_connected_to_server():
		network.send_data({"type": "logout"})
	current_username = ""
	current_player_id = ""
	_show_auth("login")

func _enter_game(record: Dictionary, multiplayer: bool) -> void:
	current_screen = "game"
	is_multiplayer = multiplayer
	current_world_name = str(record.get("name", "Online World"))
	if world_node != null and is_instance_valid(world_node):
		world_node.queue_free()
	world_node = WorldScript.new()
	add_child(world_node)
	var seed_value := int(record.get("seed", room_seed))
	world_node.configure(seed_value, current_world_name, record.get("changes", {}))
	var spawn_x := 260.0
	var floor_y: float = world_node.get_ground_y_at(spawn_x)
	player_node = PlayerScript.new()
	world_node.add_child(player_node)
	player_node.configure(current_username, world_node, Vector2(spawn_x, floor_y - 13.0))
	player_node.position_changed.connect(_on_local_player_position_changed)
	player_node.inventory_changed.connect(_on_inventory_changed)
	player_node.action_message.connect(_show_notice)
	world_node.block_changed.connect(_on_local_block_changed)
	world_node.item_dropped.connect(_spawn_item_drop)
	remote_players.clear()
	if multiplayer:
		_sync_remote_players(room_players)
	_build_game_hud()
	if is_multiplayer:
		for remote in room_players:
			if remote is Dictionary and str(remote.get("id", "")) == current_player_id:
				network.send_data({"type": "move", "x": spawn_x, "y": floor_y - 13.0})
	else:
		_save_current_world()

func _build_game_hud() -> void:
	_clear_ui()
	game_hud = Control.new()
	game_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(game_hud)
	var top_left := PanelContainer.new()
	top_left.position = Vector2(18, 16)
	top_left.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.15, 0.17, 0.88), UI_LINE, 1))
	game_hud.add_child(top_left)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	top_left.add_child(title_box)
	title_box.add_child(_make_label(current_world_name.to_upper(), 13, UI_TEXT))
	title_box.add_child(_make_label("ONLINE · " + room_code if is_multiplayer else "SINGLEPLAYER · AUTOSAVE", 9, UI_ACCENT))
	var leave_button := _make_button("LEAVE", func():
		_end_game(true)
		_show_menu()
	, 38)
	leave_button.anchor_left = 1.0
	leave_button.anchor_right = 1.0
	leave_button.anchor_top = 0.0
	leave_button.anchor_bottom = 0.0
	leave_button.position = Vector2(-104, 16)
	leave_button.size = Vector2(88, 40)
	game_hud.add_child(leave_button)
	var inventory_button := _make_button("BAG", _toggle_inventory, 38)
	inventory_button.anchor_left = 1.0
	inventory_button.anchor_right = 1.0
	inventory_button.anchor_top = 0.0
	inventory_button.anchor_bottom = 0.0
	inventory_button.position = Vector2(-310, 16)
	inventory_button.size = Vector2(86, 40)
	game_hud.add_child(inventory_button)
	chat_toggle = _make_button("CHAT  0", _toggle_chat, 38)
	chat_toggle.anchor_left = 1.0
	chat_toggle.anchor_right = 1.0
	chat_toggle.anchor_top = 0.0
	chat_toggle.anchor_bottom = 0.0
	chat_toggle.position = Vector2(-210, 16)
	chat_toggle.size = Vector2(94, 40)
	game_hud.add_child(chat_toggle)
	inventory_label = _make_label("DIRT 20   WOOD 0   STONE 0   PICKAXE", 11, UI_TEXT)
	inventory_label.anchor_left = 0.5
	inventory_label.anchor_right = 0.5
	inventory_label.anchor_top = 1.0
	inventory_label.anchor_bottom = 1.0
	inventory_label.position = Vector2(-190, -54)
	inventory_label.size = Vector2(380, 28)
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_hud.add_child(inventory_label)
	var controls := _make_label("WASD MOVE  ·  SPACE JUMP  ·  F MINE  ·  G PLACE", 10, Color("#f4f0d7"))
	controls.position = Vector2(18, 76)
	controls.size = Vector2(440, 22)
	if not (DisplayServer.is_touchscreen_available() or OS.has_feature("android")):
		game_hud.add_child(controls)
	action_notice = _make_label("", 12, Color("#fff0bb"))
	action_notice.anchor_left = 0.5
	action_notice.anchor_right = 0.5
	action_notice.anchor_top = 0.0
	action_notice.anchor_bottom = 0.0
	action_notice.position = Vector2(-240, 72)
	action_notice.size = Vector2(480, 26)
	action_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_hud.add_child(action_notice)
	chat_notice = _make_label("", 12, UI_TEXT)
	chat_notice.anchor_left = 1.0
	chat_notice.anchor_right = 1.0
	chat_notice.anchor_top = 0.0
	chat_notice.anchor_bottom = 0.0
	chat_notice.position = Vector2(-390, 64)
	chat_notice.size = Vector2(370, 24)
	chat_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chat_notice.visible = false
	game_hud.add_child(chat_notice)
	_build_chat_panel()
	_build_inventory_panel()
	if DisplayServer.is_touchscreen_available() or OS.has_feature("android"):
		_build_touch_controls()
	else:
		_build_emote_controls()
	_update_inventory(player_node.inventory)

func _build_chat_panel() -> void:
	chat_panel = PanelContainer.new()
	chat_panel.anchor_left = 1.0
	chat_panel.anchor_right = 1.0
	chat_panel.anchor_top = 0.0
	chat_panel.anchor_bottom = 0.0
	chat_panel.position = Vector2(-365, 62)
	chat_panel.size = Vector2(345, 250)
	chat_panel.visible = false
	chat_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.13, 0.16, 0.96), UI_LINE, 1))
	game_hud.add_child(chat_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	chat_panel.add_child(stack)
	stack.add_child(_make_label("WORLD CHAT", 12, UI_ACCENT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	chat_feed = VBoxContainer.new()
	chat_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(chat_feed)
	var input_row := HBoxContainer.new()
	stack.add_child(input_row)
	chat_input = _make_line_edit(input_row, "Type a message...")
	chat_input.text_submitted.connect(_send_chat)
	var send_button := _make_button("SEND", func(): _send_chat(chat_input.text), 40)
	send_button.custom_minimum_size.x = 72
	input_row.add_child(send_button)

func _build_inventory_panel() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.anchor_left = 1.0
	inventory_panel.anchor_right = 1.0
	inventory_panel.anchor_top = 0.0
	inventory_panel.anchor_bottom = 0.0
	inventory_panel.position = Vector2(-270, 64)
	inventory_panel.size = Vector2(250, 172)
	inventory_panel.visible = false
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.13, 0.16, 0.97), UI_LINE, 1))
	game_hud.add_child(inventory_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	inventory_panel.add_child(stack)
	stack.add_child(_make_label("INVENTORY", 12, UI_ACCENT))
	inventory_items_label = _make_label("[D] DIRT BLOCK  × 20\n[W] WOOD  × 0\n[S] STONE  × 0\n[P] PICKAXE  × 1", 13, UI_TEXT)
	stack.add_child(inventory_items_label)
	stack.add_child(_make_label("Selected build block: DIRT", 9, UI_MUTED))

func _toggle_inventory() -> void:
	if inventory_panel == null:
		return
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible and chat_panel != null:
		chat_panel.visible = false

func _build_touch_controls() -> void:
	var joystick = VirtualJoystickScript.new()
	joystick.size = Vector2(144, 144)
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.position = Vector2(24, -168)
	joystick.axis_changed.connect(func(value: float): player_node.set_touch_axis(value))
	game_hud.add_child(joystick)
	var jump := _touch_button("JUMP", Vector2(-104, -174), Vector2(88, 66))
	jump.anchor_left = 1.0
	jump.anchor_right = 1.0
	jump.anchor_top = 1.0
	jump.anchor_bottom = 1.0
	jump.button_down.connect(func(): player_node.touch_jump = true)
	game_hud.add_child(jump)
	var mine := _touch_button("MINE", Vector2(-202, -94), Vector2(88, 62))
	mine.anchor_left = 1.0
	mine.anchor_right = 1.0
	mine.anchor_top = 1.0
	mine.anchor_bottom = 1.0
	mine.button_down.connect(func(): player_node.touch_mine = true)
	mine.button_up.connect(func(): player_node.touch_mine = false)
	game_hud.add_child(mine)
	var place := _touch_button("PLACE", Vector2(-104, -94), Vector2(88, 62))
	place.anchor_left = 1.0
	place.anchor_right = 1.0
	place.anchor_top = 1.0
	place.anchor_bottom = 1.0
	place.button_down.connect(func(): player_node.touch_place = true)
	place.button_up.connect(func(): player_node.touch_place = false)
	game_hud.add_child(place)
	_build_emote_controls(true)

func _touch_button(text_value: String, offset: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = offset
	button.size = button_size
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.16, 0.18, 0.78), UI_LINE, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#9dc47b"), UI_ACCENT_DARK, 2))
	button.add_theme_color_override("font_pressed_color", UI_BG)
	return button

func _build_emote_controls(touch_layout: bool = false) -> void:
	var emote_row := HBoxContainer.new()
	emote_row.anchor_left = 0.0
	emote_row.anchor_right = 0.0
	emote_row.anchor_top = 0.0 if touch_layout else 1.0
	emote_row.anchor_bottom = 0.0 if touch_layout else 1.0
	emote_row.position = Vector2(18, 82) if touch_layout else Vector2(18, -52)
	emote_row.size = Vector2(250, 36)
	game_hud.add_child(emote_row)
	for pair in [["HI", "hi"], ["SAD", "sad"], ["HAPPY", "happy"]]:
		var button_label := str(pair[0])
		var emote_value := str(pair[1])
		var button := _touch_button(button_label, Vector2.ZERO, Vector2(76, 36))
		button.custom_minimum_size = Vector2(76, 36)
		button.pressed.connect(func(): _send_emote(emote_value))
		emote_row.add_child(button)

func _toggle_chat() -> void:
	if chat_panel == null:
		return
	chat_panel.visible = not chat_panel.visible
	if chat_panel.visible and inventory_panel != null:
		inventory_panel.visible = false
	if chat_panel.visible:
		chat_unread = 0
		if chat_toggle != null:
			chat_toggle.text = "CHAT  0"
			chat_input.grab_focus()

func _send_chat(text_value: String) -> void:
	if chat_input == null:
		return
	var message := text_value.strip_edges()
	if message.is_empty():
		return
	if is_multiplayer:
		network.send_data({"type": "chat", "message": message})
	else:
		_add_chat_message(current_username, message)
	chat_input.clear()

func _add_chat_message(sender: String, message: String) -> void:
	if chat_feed != null and is_instance_valid(chat_feed):
		var line := _make_label(sender + ": " + message, 11, UI_TEXT)
		chat_feed.add_child(line)
		while chat_feed.get_child_count() > 12:
			chat_feed.get_child(0).queue_free()
	if chat_panel != null and not chat_panel.visible:
		chat_unread += 1
		if chat_toggle != null:
			chat_toggle.text = "CHAT  " + str(chat_unread)
		if chat_notice != null:
			chat_notice.text = sender + ": " + message
			chat_notice.visible = true
			notification_clock = 3.5

func _send_emote(value: String) -> void:
	if player_node != null:
		player_node.show_emote(value)
	if is_multiplayer:
		network.send_data({"type": "emote", "emote": value})

func _on_local_player_position_changed(position_value: Vector2) -> void:
	if is_multiplayer and network.is_connected_to_server():
		# Position snapshots are sent at a controlled rate from _process.
		pass

func _spawn_item_drop(item_type: int, world_position: Vector2, can_collect: bool) -> void:
	if world_node == null or player_node == null:
		return
	var drop = ItemDropScript.new()
	world_node.add_child(drop)
	drop.configure(item_type, world_position, player_node, can_collect)
	if can_collect:
		drop.collected.connect(_on_item_collected)

func _on_item_collected(item_type: int) -> void:
	if player_node == null:
		return
	var item_key := "dirt" if item_type == 1 or item_type == 2 else ("stone" if item_type == 3 else ("wood" if item_type == 4 else ""))
	if not item_key.is_empty():
		player_node.add_inventory_item(item_key, 1)
		_show_notice("Picked up " + item_key.to_upper() + ".")

func _on_inventory_changed(inventory_value: Dictionary) -> void:
	_update_inventory(inventory_value)

func _update_inventory(inventory_value: Dictionary) -> void:
	var dirt_count := int(inventory_value.get("dirt", 0))
	var wood_count := int(inventory_value.get("wood", 0))
	var stone_count := int(inventory_value.get("stone", 0))
	var pickaxe_count := int(inventory_value.get("pickaxe", 0))
	if inventory_label != null and is_instance_valid(inventory_label):
		inventory_label.text = "DIRT %d   WOOD %d   STONE %d   PICKAXE %d" % [dirt_count, wood_count, stone_count, pickaxe_count]
	if inventory_items_label != null and is_instance_valid(inventory_items_label):
		inventory_items_label.text = "[D] DIRT BLOCK  × %d\n[W] WOOD  × %d\n[S] STONE  × %d\n[P] PICKAXE  × %d" % [dirt_count, wood_count, stone_count, pickaxe_count]

func _on_local_block_changed(action_name: String, cell: Vector2i, block_type: int) -> void:
	if is_multiplayer and network.is_connected_to_server():
		network.send_data({"type": "block_change", "action": action_name, "x": cell.x, "y": cell.y, "block": block_type})

func _sync_remote_players(players: Array) -> void:
	var live_ids: Array[String] = []
	for item in players:
		if not item is Dictionary:
			continue
		var id := str(item.get("id", ""))
		if id.is_empty() or id == current_player_id:
			continue
		live_ids.append(id)
		if not remote_players.has(id):
			var remote = RemotePlayerScript.new()
			world_node.add_child(remote)
			remote.configure(str(item.get("username", "Player")), Vector2(float(item.get("x", 240)), float(item.get("y", 300))), remote_players.size())
			remote_players[id] = remote
		else:
			remote_players[id].set_target(Vector2(float(item.get("x", 240)), float(item.get("y", 300))))
	for existing_id in remote_players.keys():
		if not live_ids.has(str(existing_id)):
			remote_players[existing_id].queue_free()
			remote_players.erase(existing_id)

func _show_notice(message: String) -> void:
	if action_notice != null and is_instance_valid(action_notice):
		action_notice.text = message
		action_notice.visible = true
		var label_ref := action_notice
		get_tree().create_timer(2.7).timeout.connect(func():
			if is_instance_valid(label_ref):
				label_ref.text = ""
		)

func _save_current_world() -> void:
	if is_multiplayer or selected_world.is_empty() or world_node == null:
		return
	for index in range(world_records.size()):
		if str(world_records[index].get("id", "")) == str(selected_world.get("id", "")):
			world_records[index]["changes"] = world_node.serialize_changes()
			world_records[index]["updated"] = Time.get_unix_time_from_system()
			selected_world = world_records[index]
			_write_world_records()
			return

func _end_game(send_leave: bool) -> void:
	if send_leave and is_multiplayer and network.is_connected_to_server():
		network.send_data({"type": "leave_room"})
	if not is_multiplayer:
		_save_current_world()
	if world_node != null and is_instance_valid(world_node):
		world_node.queue_free()
	world_node = null
	player_node = null
	remote_players.clear()
	is_multiplayer = false
	room_code = ""
	room_players.clear()
	selected_world = {}
	current_screen = "menu"

func _on_network_disconnected_after_game() -> void:
	if current_screen == "game" and is_multiplayer:
		_end_game(false)
		_show_menu()
