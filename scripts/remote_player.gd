extends Node2D

var display_name := "Player"
var target_position := Vector2.ZERO
var facing := 1.0
var animation_clock := 0.0
var emote_text := ""
var emote_time := 0.0
var tint := Color("#d5a56b")

func configure(player_name: String, start_position: Vector2, color_index: int = 0) -> void:
	display_name = player_name
	position = start_position
	target_position = start_position
	var colors := [Color("#d5a56b"), Color("#91b5a0"), Color("#a58dc4"), Color("#d08b83"), Color("#7facc8")]
	tint = colors[posmod(color_index, colors.size())]
	queue_redraw()

func set_target(next_position: Vector2) -> void:
	if next_position.x != position.x:
		facing = sign(next_position.x - position.x)
	target_position = next_position

func show_emote(value: String) -> void:
	var labels := {"hi": "HI!", "sad": ":(", "happy": ":D"}
	emote_text = str(labels.get(value, ""))
	emote_time = 2.2
	queue_redraw()

func _process(delta: float) -> void:
	animation_clock += delta
	position = position.lerp(target_position, minf(delta * 12.0, 1.0))
	if emote_time > 0.0:
		emote_time -= delta
		if emote_time <= 0.0:
			emote_text = ""
	queue_redraw()

func _draw() -> void:
	var stride := sin(animation_clock * 11.0) * 2.0 if absf(target_position.x - position.x) > 1.0 else 0.0
	var skin := Color("#efc49a")
	var outline := Color("#29343c")
	# Nameplate
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_rect(Rect2(-text_size.x / 2.0 - 6.0, -52.0, text_size.x + 12.0, 18.0), Color(0.07, 0.12, 0.15, 0.88))
	draw_rect(Rect2(-text_size.x / 2.0 - 6.0, -52.0, text_size.x + 12.0, 18.0), Color("#9bb9a2"), false, 1.0)
	draw_string(font, Vector2(-text_size.x / 2.0, -39.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f1f2dd"))
	# Pixel character
	draw_rect(Rect2(-8, -27, 16, 23), outline)
	draw_rect(Rect2(-7, -26, 14, 20), tint)
	draw_rect(Rect2(-8, -36, 16, 11), outline)
	draw_rect(Rect2(-7, -35, 14, 9), skin)
	draw_rect(Rect2(-8, -38, 16, 4), Color("#493c37"))
	var eye_x := 3.0 * facing
	draw_rect(Rect2(eye_x, -32, 2, 2), Color("#202b31"))
	draw_rect(Rect2(-7, -8 + stride, 6, 7), outline)
	draw_rect(Rect2(1, -8 - stride, 6, 7), outline)
	if not emote_text.is_empty():
		draw_string(font, Vector2(-12, -63), emote_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#fff0ad"))
