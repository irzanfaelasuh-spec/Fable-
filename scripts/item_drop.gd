extends Node2D

signal collected(item_type: int)

var item_type := 2
var target
var velocity := Vector2.ZERO
var age := 0.0
var landed := false
var can_collect := true

func configure(drop_type: int, start_position: Vector2, collector, collectable: bool = true) -> void:
	item_type = drop_type
	position = start_position
	target = collector
	can_collect = collectable
	velocity = Vector2(randf_range(-34.0, 34.0), -92.0)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	if not landed:
		velocity.y = minf(velocity.y + 520.0 * delta, 260.0)
		position += velocity * delta
		if target != null and is_instance_valid(target) and target.world != null:
			var ground_y: float = target.world.get_ground_y_at(position.x)
			if ground_y < INF and position.y + 6.0 >= ground_y:
				position.y = ground_y - 6.0
				velocity = Vector2.ZERO
				landed = true
	else:
		position.y += sin(age * 5.0) * delta * 2.0
	if can_collect and target != null and is_instance_valid(target) and position.distance_to(target.position) < 34.0:
		collected.emit(item_type)
		queue_free()
	elif not can_collect and age >= 3.5:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var fill := Color("#8b654b")
	match item_type:
		1, 2: fill = Color("#9b7957")
		3: fill = Color("#8a969d")
		4: fill = Color("#b47b4c")
	var alpha := 1.0 if can_collect else clampf(1.0 - maxf(age - 2.5, 0.0), 0.0, 1.0)
	fill.a = alpha
	draw_rect(Rect2(-7.0, -7.0, 14.0, 14.0), Color(0.14, 0.20, 0.23, alpha))
	draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), fill)
	draw_rect(Rect2(-4.0, -4.0, 3.0, 2.0), Color(1.0, 1.0, 1.0, 0.42 * alpha))
