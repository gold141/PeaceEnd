# scripts/game/aa_missile.gd
# Зенитная ракета — наводится на воздушную цель, белый дымовой шлейф
extends Area2D

@export var speed: float = 500.0
@export var turn_rate: float = 3.5
@export var lifetime: float = 4.0

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false
var is_enemy: bool = false
var damage: float = 3.0
var target: Node2D = null
var age: float = 0.0

var trail_points: Array = []
const TRAIL_LENGTH: int = 30
const TRAIL_LIFETIME: float = 0.8
const TRAIL_MAX_WIDTH: float = 2.5

signal hit(position: Vector2, body: Node2D)
signal off_screen()


func launch_at(target_node: Node2D, initial_dir: Vector2) -> void:
	target = target_node
	velocity = initial_dir.normalized() * speed
	launched = true
	age = 0.0


func _process(delta: float) -> void:
	if not launched:
		return

	age += delta
	if age >= lifetime:
		queue_free()
		return

	# Наведение на цель
	if is_instance_valid(target):
		var target_alive = true
		if "alive" in target and not target.alive:
			target_alive = false
		if target_alive:
			var to_target = (target.global_position - global_position).normalized()
			var current_dir = velocity.normalized()
			var new_dir = current_dir.lerp(to_target, turn_rate * delta).normalized()
			velocity = new_dir * speed

	position += velocity * delta
	rotation = velocity.angle()

	trail_points.append({"pos": global_position, "age": 0.0})
	if trail_points.size() > TRAIL_LENGTH:
		trail_points.pop_front()

	var i = 0
	while i < trail_points.size():
		trail_points[i]["age"] += delta
		if trail_points[i]["age"] >= TRAIL_LIFETIME:
			trail_points.remove_at(i)
		else:
			i += 1

	queue_redraw()

	if position.y > 600 or position.y < -100 or position.x > 1400 or position.x < -100:
		off_screen.emit()
		queue_free()


func _draw() -> void:
	# Тело ракеты
	draw_rect(Rect2(-4, -1.5, 8, 3), Color(0.7, 0.7, 0.65))
	# Головка
	draw_circle(Vector2(5, 0), 2.0, Color(0.85, 0.3, 0.2))
	# Стабилизаторы
	draw_line(Vector2(-4, 0), Vector2(-7, -3), Color(0.5, 0.5, 0.45), 1.5)
	draw_line(Vector2(-4, 0), Vector2(-7, 3), Color(0.5, 0.5, 0.45), 1.5)

	# Двигатель
	var flicker = randf_range(0.6, 1.0)
	draw_circle(Vector2(-6, 0), 2.5 * flicker, Color(1.0, 0.7, 0.2, 0.9))

	# Шлейф
	var count = trail_points.size()
	if count < 2:
		return

	for j in range(1, count):
		var t = float(j) / float(count - 1)
		var age_alpha = 1.0 - trail_points[j]["age"] / TRAIL_LIFETIME
		var alpha = t * age_alpha * 0.5
		var width = t * TRAIL_MAX_WIDTH * age_alpha

		var from = to_local(trail_points[j - 1]["pos"])
		var to = to_local(trail_points[j]["pos"])
		draw_line(from, to, Color(0.85, 0.85, 0.8, alpha), maxf(width, 0.3))


func _on_body_entered(body: Node2D) -> void:
	hit.emit(global_position, body)
	queue_free()
