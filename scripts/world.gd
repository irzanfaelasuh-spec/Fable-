extends Node2D

signal block_changed(action_name: String, cell: Vector2i, block_type: int)
signal item_dropped(item_type: int, world_position: Vector2, can_collect: bool)

const TILE := 24
const WORLD_WIDTH := 115200.0 # 4,800 tiles: large deterministic landscape.
const WORLD_DEPTH := 70

var world_seed := 1
var world_name := "New World"
var overrides: Dictionary = {}
var cloud_clock := 0.0
var day_clock := 0.0

func configure(seed_value: int, title: String = "New World", saved_changes: Dictionary = {}) -> void:
	world_seed = maxi(seed_value, 1)
	world_name = title
	overrides = saved_changes.duplicate(true)
	queue_redraw()

func _process(delta: float) -> void:
	cloud_clock += delta * 8.0
	day_clock += delta * 0.012
	queue_redraw()

func get_world_width() -> float:
	return WORLD_WIDTH

func _surface_row(tile_x: int) -> int:
	var a := sin(float(tile_x) * 0.055 + float(world_seed % 131) * 0.11) * 2.0
	var b := sin(float(tile_x) * 0.017 + float(world_seed % 79) * 0.07) * 3.2
	var c := sin(float(tile_x) * 0.13 + float(world_seed % 37)) * 0.65
	return clampi(24 + int(round(a + b + c)), 16, 34)

func _key(tile_x: int, tile_y: int) -> String:
	return str(tile_x) + ":" + str(tile_y)

func get_block_type(tile_x: int, tile_y: int) -> int:
	var key := _key(tile_x, tile_y)
	if overrides.has(key):
		var replacement := int(overrides[key])
		return 0 if replacement < 0 else replacement
	if tile_x < 0 or tile_x >= int(WORLD_WIDTH / TILE) or tile_y < 0 or tile_y >= WORLD_DEPTH:
		return 0
	var surface := _surface_row(tile_x)
	if tile_y < surface:
		var tree_hash := abs(tile_x * 7919 + world_seed * 104729)
		if tree_hash % 23 == 0 and tile_x % 3 == 0 and tile_y >= surface - 3 and tile_y < surface:
			return 4 # breakable wood trunk
		return 0
	var depth := tile_y - surface
	if depth == 0:
		return 1 # grass
	if depth < 7:
		return 2 # dirt
	# Deterministic pockets create occasional small underground caverns.
	if depth >= 10 and depth < 38:
		var cave_noise := sin(float(tile_x) * 0.19 + float(tile_y) * 0.13 + float(world_seed % 97)) * 0.82 + cos(float(tile_x) * 0.075 - float(tile_y) * 0.17 + float(world_seed % 53)) * 0.68
		if cave_noise > 1.12:
			return 0
	return 3 # stone

func get_ground_y_at(world_x: float) -> float:
	var tile_x := floori(world_x / float(TILE))
	# Search from the top so placed blocks and short tree trunks can support the player.
	for tile_y in range(0, WORLD_DEPTH):
		if get_block_type(tile_x, tile_y) != 0:
			return float(tile_y * TILE)
	return INF

func get_target_cell(player_position: Vector2, facing: float) -> Vector2i:
	var target_x := floori((player_position.x + facing * 28.0) / float(TILE))
	var feet_y := floori((player_position.y + 8.0) / float(TILE))
	var candidates := [Vector2i(target_x, feet_y - 1), Vector2i(target_x, feet_y), Vector2i(target_x, feet_y - 2)]
	for cell in candidates:
		if get_block_type(cell.x, cell.y) != 0:
			return cell
	var surface := _surface_row(target_x)
	return Vector2i(target_x, surface)

func break_block(tile_x: int, tile_y: int) -> int:
	var block_type := get_block_type(tile_x, tile_y)
	if block_type == 0:
		return 0
	if block_type == 4:
		var surface := _surface_row(tile_x)
		for trunk_y in range(surface - 3, surface):
			overrides[_key(tile_x, trunk_y)] = -1
	else:
		overrides[_key(tile_x, tile_y)] = -1
	queue_redraw()
	block_changed.emit("break", Vector2i(tile_x, tile_y), block_type)
	item_dropped.emit(block_type, Vector2(tile_x * TILE + TILE * 0.5, tile_y * TILE + TILE * 0.5), true)
	return block_type

func place_block(tile_x: int, tile_y: int, block_type: int) -> bool:
	if get_block_type(tile_x, tile_y) != 0 or tile_x < 0 or tile_y < 0 or tile_y >= WORLD_DEPTH:
		return false
	overrides[_key(tile_x, tile_y)] = block_type
	queue_redraw()
	block_changed.emit("place", Vector2i(tile_x, tile_y), block_type)
	return true

func apply_remote_change(action_name: String, tile_x: int, tile_y: int, block_type: int) -> void:
	if action_name == "break":
		if block_type == 4:
			var surface := _surface_row(tile_x)
			for trunk_y in range(surface - 3, surface):
				overrides[_key(tile_x, trunk_y)] = -1
		else:
			overrides[_key(tile_x, tile_y)] = -1
		if block_type > 0:
			item_dropped.emit(block_type, Vector2(tile_x * TILE + TILE * 0.5, tile_y * TILE + TILE * 0.5), false)
	elif action_name == "place":
		overrides[_key(tile_x, tile_y)] = block_type
	queue_redraw()

func serialize_changes() -> Dictionary:
	return overrides.duplicate(true)

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var center := Vector2.ZERO
	if camera != null:
		center = camera.global_position
	var view_size := get_viewport_rect().size
	var half_w := view_size.x * 0.62
	var half_h := view_size.y * 0.75
	var left := center.x - half_w
	var right := center.x + half_w
	var top := center.y - half_h
	var bottom := center.y + half_h
	var daylight := 0.5 + 0.5 * sin(day_clock)
	var sky_top := Color("#7db8cf").lerp(Color("#273c61"), 1.0 - daylight)
	var sky_bottom := Color("#d7d5b0").lerp(Color("#b67e79"), 1.0 - daylight)
	for band in range(8):
		var t := float(band) / 7.0
		draw_rect(Rect2(left, top + view_size.y * t, right - left, view_size.y / 8.0 + 2.0), sky_top.lerp(sky_bottom, t))
	# Sun and distant layers.
	var sun_x := center.x + 370.0
	var sun_y := top + 120.0 + (1.0 - daylight) * 90.0
	draw_circle(Vector2(sun_x, sun_y), 29.0, Color("#f7d99a"))
	draw_circle(Vector2(sun_x, sun_y), 37.0, Color(0.95, 0.83, 0.58, 0.12))
	_draw_hill(left, right, top, 0.23, Color("#7095a0"), center.x * 0.18)
	_draw_hill(left, right, top, 0.36, Color("#547c75"), center.x * 0.32)
	_draw_clouds(left, right, top + 70.0)
	# Ground and block tiles, culled to the visible columns.
	var first_x := maxi(0, floori(left / float(TILE)) - 2)
	var last_x := mini(int(WORLD_WIDTH / TILE), ceili(right / float(TILE)) + 2)
	var first_visible_y := maxi(0, floori(top / float(TILE)) - 2)
	var last_visible_y := mini(WORLD_DEPTH, ceili(bottom / float(TILE)) + 2)
	for tx in range(first_x, last_x):
		var surface := _surface_row(tx)
		for ty in range(maxi(surface - 6, first_visible_y), last_visible_y):
			var block := get_block_type(tx, ty)
			if block == 0:
				continue
			_draw_block(tx, ty, block)
	_draw_decor(left, right)

func _draw_hill(left: float, right: float, top: float, height_factor: float, color: Color, parallax: float) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(left, top + 390.0 * height_factor + 220.0))
	var x := left
	while x <= right + 100.0:
		var px := x + parallax
		var y := top + 390.0 * height_factor + sin(px * 0.0022) * 34.0 + sin(px * 0.0061) * 13.0
		points.append(Vector2(x, y))
		x += 54.0
	points.append(Vector2(right, top + 690.0))
	points.append(Vector2(left, top + 690.0))
	draw_colored_polygon(points, color)

func _draw_clouds(left: float, right: float, y_base: float) -> void:
	var start := floori((left + cloud_clock * 9.0) / 260.0) - 1
	var finish := ceili((right + cloud_clock * 9.0) / 260.0) + 1
	for index in range(start, finish):
		var px := float(index) * 260.0 - cloud_clock * 9.0
		var py := y_base + sin(float(index) * 4.7) * 38.0
		var cloud_color := Color(0.95, 0.97, 0.91, 0.72)
		draw_rect(Rect2(px, py + 8.0, 68.0, 17.0), cloud_color)
		draw_rect(Rect2(px + 14.0, py, 35.0, 24.0), cloud_color)
		draw_rect(Rect2(px + 47.0, py + 10.0, 29.0, 14.0), cloud_color)

func _draw_block(tx: int, ty: int, block_type: int) -> void:
	var x := float(tx * TILE)
	var y := float(ty * TILE)
	var base := Color("#78a85f")
	match block_type:
		1: base = Color("#6d9f58")
		2: base = Color("#8b654b")
		3: base = Color("#68727a")
		4: base = Color("#88613f")
		5: base = Color("#477e57")
	draw_rect(Rect2(x, y, TILE, TILE), base)
	var light := Color(1.0, 1.0, 1.0, 0.10)
	var dark := Color(0.0, 0.0, 0.0, 0.10)
	draw_rect(Rect2(x + 2.0, y + 2.0, 5.0, 3.0), light)
	draw_rect(Rect2(x + 15.0, y + 14.0, 5.0, 4.0), dark)
	if block_type == 1:
		draw_rect(Rect2(x, y, TILE, 5.0), Color("#91bf6b"))
		draw_rect(Rect2(x + 4.0, y - 2.0, 3.0, 4.0), Color("#a5cb79"))
	if block_type == 4:
		draw_rect(Rect2(x + 8.0, y, 8.0, TILE), Color("#79513a"))
		draw_rect(Rect2(x + 9.0, y + 4.0, 2.0, 8.0), Color("#a77a4d"))
	if block_type == 3:
		draw_rect(Rect2(x + 5.0, y + 6.0, 4.0, 3.0), Color("#879198"))

func _draw_decor(left: float, right: float) -> void:
	var first := maxi(0, floori(left / float(TILE)) - 12)
	var last := mini(int(WORLD_WIDTH / TILE), ceili(right / float(TILE)) + 12)
	for tx in range(first, last):
		var hash_value := abs(tx * 7919 + world_seed * 104729)
		var surface_y := float(_surface_row(tx) * TILE)
		if hash_value % 23 == 0 and tx % 3 == 0 and get_block_type(tx, _surface_row(tx) - 1) == 4:
			_draw_tree(float(tx * TILE), surface_y)
		if hash_value % 97 == 0:
			_draw_flower(float(tx * TILE + 6), surface_y)
		if hash_value % 131 == 0 and tx > 10:
			_draw_house(float(tx * TILE), surface_y)

func _draw_tree(x: float, ground_y: float) -> void:
	draw_rect(Rect2(x - 34.0, ground_y - 91.0, 68.0, 38.0), Color("#3f7651"))
	draw_rect(Rect2(x - 24.0, ground_y - 107.0, 48.0, 29.0), Color("#578d5a"))
	draw_rect(Rect2(x - 13.0, ground_y - 113.0, 26.0, 12.0), Color("#76a866"))
	draw_rect(Rect2(x - 23.0, ground_y - 84.0, 12.0, 8.0), Color("#86b56e"))

func _draw_flower(x: float, ground_y: float) -> void:
	draw_rect(Rect2(x, ground_y - 10.0, 2.0, 10.0), Color("#48784d"))
	draw_rect(Rect2(x - 3.0, ground_y - 13.0, 8.0, 5.0), Color("#f0d78a"))

func _draw_house(x: float, ground_y: float) -> void:
	draw_rect(Rect2(x - 35.0, ground_y - 47.0, 70.0, 47.0), Color("#c18d65"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 44.0, ground_y - 45.0), Vector2(x, ground_y - 82.0), Vector2(x + 44.0, ground_y - 45.0)]), Color("#704e4c"))
	draw_rect(Rect2(x - 7.0, ground_y - 27.0, 15.0, 27.0), Color("#654638"))
	draw_rect(Rect2(x - 27.0, ground_y - 35.0, 11.0, 11.0), Color("#8fc0c1"))
	draw_rect(Rect2(x + 17.0, ground_y - 35.0, 11.0, 11.0), Color("#8fc0c1"))
