# scripts/game/projectile.gd
extends Area2D

## Гравитация (пиксели/сек²)
@export var gravity_force: float = 245.0
## Сопротивление воздуха (замедление пропорционально скорости)
@export var air_drag: float = 0.3
## Радиус взрыва
@export var explosion_radius: float = 50.0
## Максимальное количество точек шлейфа
@export var trail_length: int = 30
## Время жизни точки шлейфа (секунды)
@export var trail_lifetime: float = 0.6

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false

# Шлейф: массив {pos: Vector2, age: float}
var trail_points: Array = []

signal hit(position: Vector2)
signal off_screen()


func launch(angle_deg: float, power: float) -> void:
	var angle_rad = deg_to_rad(angle_deg)
	velocity.x = power * cos(angle_rad)
	velocity.y = -power * sin(angle_rad)
	launched = true


func _process(delta: float) -> void:
	if not launched:
		return

	# Сопротивление воздуха
	velocity -= velocity * air_drag * delta

	# Гравитация
	velocity.y += gravity_force * delta

	# Движение
	position += velocity * delta

	# Поворот спрайта по траектории
	rotation = velocity.angle()

	# Добавляем точку шлейфа (глобальная позиция)
	trail_points.append({"pos": global_position, "age": 0.0})
	if trail_points.size() > trail_length:
		trail_points.pop_front()

	# Старение точек и удаление старых
	var i = 0
	while i < trail_points.size():
		trail_points[i]["age"] += delta
		if trail_points[i]["age"] >= trail_lifetime:
			trail_points.remove_at(i)
		else:
			i += 1

	queue_redraw()

	# Удаление за экраном
	if position.y > 800 or position.x > 1400 or position.x < -100:
		off_screen.emit()
		queue_free()


func _draw() -> void:
	if trail_points.size() < 2:
		return

	for i in range(1, trail_points.size()):
		var alpha = 1.0 - trail_points[i]["age"] / trail_lifetime
		var prev_alpha = 1.0 - trail_points[i - 1]["age"] / trail_lifetime
		var avg_alpha = (alpha + prev_alpha) * 0.5
		var width = avg_alpha * 2.5

		# Конвертируем глобальные позиции в локальные
		var from = to_local(trail_points[i - 1]["pos"])
		var to = to_local(trail_points[i]["pos"])

		draw_line(from, to, Color(1, 1, 1, avg_alpha * 0.7), maxf(width, 0.5))


func _on_body_entered(body: Node2D) -> void:
	hit.emit(global_position)
	queue_free()
