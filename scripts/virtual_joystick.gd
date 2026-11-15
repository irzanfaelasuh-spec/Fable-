extends Control

signal axis_changed(value: float)

var _active := false
var _pointer_index := -1
var _axis := 0.0
var _knob_offset := Vector2.ZERO
var _radius := 54.0

func _ready() -> void:
	custom_minimum_size = Vector2(144, 144)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_active = true
			_pointer_index = event.index
			_update_from_position(event.position)
			accept_event()
		elif not event.pressed and _active and event.index == _pointer_index:
			_release_stick()
			accept_event()
	elif event is InputEventScreenDrag and _active and event.index == _pointer_index:
		_update_from_position(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _active:
			_active = true
			_pointer_index = -2
			_update_from_position(event.position)
			accept_event()
		elif not event.pressed and _pointer_index == -2:
			_release_stick()
			accept_event()
	elif event is InputEventMouseMotion and _active and _pointer_index == -2:
		_update_from_position(event.position)
		accept_event()

func _update_from_position(point: Vector2) -> void:
	var center := size * 0.5
	var delta := point - center
	var clamped := delta.limit_length(_radius)
	_knob_offset = clamped
	_axis = clampf(clamped.x / _radius, -1.0, 1.0)
	axis_changed.emit(_axis)
	queue_redraw()

func _release_stick() -> void:
	_active = false
	_pointer_index = -1
	_axis = 0.0
	_knob_offset = Vector2.ZERO
	axis_changed.emit(0.0)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, _radius + 9.0, Color(0.035, 0.075, 0.082, 0.46))
	draw_circle(center, _radius, Color(0.11, 0.19, 0.19, 0.82))
	draw_arc(center, _radius, 0.0, TAU, 48, Color("#78968a"), 3.0, false)
	draw_circle(center + _knob_offset, 27.0, Color("#a9ce86", 0.96))
	draw_arc(center + _knob_offset, 27.0, 0.0, TAU, 32, Color("#e4edc7"), 2.0, false)
