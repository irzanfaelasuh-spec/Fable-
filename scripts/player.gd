extends Node2D

signal position_changed(position_value: Vector2)
signal inventory_changed(inventory_value: Dictionary)
signal action_message(message: String)

const GRAVITY := 920.0
const MOVE_SPEED := 205.0
const JUMP_SPEED := 350.0

var display_name := "Player"
var world
var velocity_y := 0.0
var facing := 1.0
var animation_clock := 0.0
var touch_axis := 0.0
var touch_jump := false
var touch_mine := false
var touch_place := false
var mine_clock := 0.0
var place_clock := 0.0
var inventory := {"dirt": 20, "wood": 0, "stone": 0, "pickaxe": 1}
var last_sent_position := Vector2.ZERO
var emote_text := ""
var emote_time := 0.0

func configure(player_name: String, world_node, spawn: Vector2) -> void:
	display_name = player_name
	world = world_node
	position = spawn
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.zoom = Vector2(1.0, 1.0)
	add_child(camera)
	camera.make_current()
	queue_redraw()

func set_touch_axis(value: float) -> void:
	touch_axis = clampf(value, -1.0, 1.0)

func show_emote(value: String) -> void:
	var labels := {"hi": "HI!", "sad": ":(", "happy": ":D"}
	emote_text = str(labels.get(value, ""))
	emote_time = 2.2
	queue_redraw()

func _process(delta: float) -> void:
	if world == null:
		return
	animation_clock += delta
	var axis := touch_axis
	if absf(axis) < 0.01:
		axis = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	if absf(axis) > 0.05:
		facing = sign(axis)
	position.x += axis * MOVE_SPEED * delta
	position.x = clampf(position.x, 20.0, world.get_world_width() - 20.0)
	if touch_jump or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		if _is_grounded():
			velocity_y = -JUMP_SPEED
	touch_jump = false
	velocity_y = minf(velocity_y + GRAVITY * delta, 650.0)
	position.y += velocity_y * delta
	var floor_y: float = world.get_ground_y_at(position.x)
	if floor_y < INF and position.y + 13.0 >= floor_y and velocity_y >= 0.0:
		position.y = floor_y - 13.0
		velocity_y = 0.0
	if touch_mine or Input.is_key_pressed(KEY_F):
		mine_clock += delta
		if mine_clock >= 0.16:
			mine_clock = 0.0
			_mine_target()
	else:
		mine_clock = 0.0
		if has_meta("mine_started"):
			remove_meta("mine_started")
	if touch_place or Input.is_key_pressed(KEY_G):
		place_clock += delta
		if place_clock >= 0.22:
			place_clock = 0.0
			_place_target()
	else:
		place_clock = 0.0
	if position.distance_to(last_sent_position) > 2.0:
		last_sent_position = position
		position_changed.emit(position)
	if emote_time > 0.0:
		emote_time -= delta
		if emote_time <= 0.0:
			emote_text = ""
	queue_redraw()

func _is_grounded() -> bool:
	if world == null:
		return false
	var floor_y: float = world.get_ground_y_at(position.x)
	return floor_y < INF and position.y + 14.0 >= floor_y - 2.0 and velocity_y >= -4.0

func _mine_target() -> void:
	var cell: Vector2i = world.get_target_cell(position, facing)
	var block_type: int = world.get_block_type(cell.x, cell.y)
	if block_type == 0:
		return
	if block_type == 3 and int(inventory.get("pickaxe", 0)) <= 0:
		action_message.emit("Batu terlalu keras. Kamu memerlukan pickaxe.")
		return
	var duration := 0.9 if block_type == 3 else (0.5 if block_type == 4 else 0.65)
	# The button has to be held for a real mining duration.
	if not has_meta("mine_started"):
		set_meta("mine_started", Time.get_ticks_msec())
		return
	var started := int(get_meta("mine_started"))
	if Time.get_ticks_msec() - started < int(duration * 1000.0):
		return
	remove_meta("mine_started")
	world.break_block(cell.x, cell.y)

func add_inventory_item(item_key: String, amount: int = 1) -> void:
	if not inventory.has(item_key):
		return
	inventory[item_key] = int(inventory[item_key]) + maxi(amount, 0)
	inventory_changed.emit(inventory.duplicate(true))

func _place_target() -> void:
	if int(inventory.get("dirt", 0)) <= 0:
		action_message.emit("Tidak ada dirt untuk dipasang.")
		return
	var cell: Vector2i = world.get_target_cell(position, facing)
	if world.get_block_type(cell.x, cell.y) != 0:
		cell.y -= 1
	if world.get_block_type(cell.x, cell.y) != 0:
		return
	if world.place_block(cell.x, cell.y, 2):
		inventory["dirt"] = int(inventory["dirt"]) - 1
		inventory_changed.emit(inventory.duplicate(true))


func _draw() -> void:
	var moving := absf(touch_axis) > 0.05 or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)
	var stride := sin(animation_clock * 12.0) * 2.5 if moving else 0.0
	var outline := Color("#24343a")
	var skin := Color("#edc39b")
	var shirt := Color("#a7c984")
	# A compact original pixel character, drawn entirely with rectangles.
	draw_rect(Rect2(-10.0, -27.0, 20.0, 25.0), outline)
	draw_rect(Rect2(-8.0, -25.0, 16.0, 21.0), shirt)
	draw_rect(Rect2(-10.0, -37.0, 20.0, 13.0), outline)
	draw_rect(Rect2(-8.0, -35.0, 16.0, 9.0), skin)
	draw_rect(Rect2(-9.0, -40.0, 18.0, 5.0), Color("#56433a"))
	draw_rect(Rect2(-8.0, -10.0 + stride, 7.0, 9.0), outline)
	draw_rect(Rect2(1.0, -10.0 - stride, 7.0, 9.0), outline)
	draw_rect(Rect2(-8.0, -2.0 + stride, 7.0, 2.0), Color("#554a42"))
	draw_rect(Rect2(1.0, -2.0 - stride, 7.0, 2.0), Color("#554a42"))
	draw_rect(Rect2(3.0 * facing, -32.0, 2.0, 2.0), Color("#25343a"))
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_rect(Rect2(-text_size.x / 2.0 - 7.0, -62.0, text_size.x + 14.0, 18.0), Color(0.055, 0.10, 0.12, 0.90))
	draw_rect(Rect2(-text_size.x / 2.0 - 7.0, -62.0, text_size.x + 14.0, 18.0), Color("#86a991"), false, 1.0)
	draw_string(font, Vector2(-text_size.x / 2.0, -49.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f2f0dd"))
	if not emote_text.is_empty():
		draw_string(font, Vector2(-13.0, -72.0), emote_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffedaa"))
