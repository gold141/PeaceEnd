# scripts/game/projectile.gd
extends Area2D

## Гравитация (пиксели/сек²)
@export var gravity_force: float = 245.0
## Сопротивление воздуха (замедление пропорционально скорости)
@export var air_drag: float = 0.3
## Радиус взрыва
@export var explosion_radius: float = 50.0
## Максимальное количество точек шлейфа
@export var trail_length: int = 40
## Время жизни точки шлейфа (секунды)
@export var trail_lifetime: float = 0.8
## Максимальная ширина шлейфа (у головы)
@export var trail_max_width: float = 3.0
## Цвет шлейфа
@export var trail_color: Color = Color(1.0, 0.95, 0.8)

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false
var is_enemy: bool = false

# Шлейф: массив {pos: Vector2, age: float}
var trail_points: Array = []

signal hit(position: Vector2, body: Node2D)
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
	if position.y > 600 or position.x > 6600 or position.x < -100:
		off_screen.emit()
		queue_free()


func _draw() -> void:
	var count = trail_points.size()
	if count < 2:
		return

	for i in range(1, count):
		# Позиция в шлейфе: 0.0 = хвост (старый), 1.0 = голова (новый)
		var t = float(i) / float(count - 1)
		var t_prev = float(i - 1) / float(count - 1)

		# Затухание по возрасту
		var age_alpha = 1.0 - trail_points[i]["age"] / trail_lifetime
		var age_alpha_prev = 1.0 - trail_points[i - 1]["age"] / trail_lifetime

		# Итоговая прозрачность = позиция × возраст (двойная градация)
		var alpha = t * age_alpha
		var alpha_prev = t_prev * age_alpha_prev
		var avg_alpha = (alpha + alpha_prev) * 0.5

		# Ширина: толстая у головы, тонкая у хвоста
		var width = t * trail_max_width * age_alpha

		# Конвертируем глобальные позиции в локальные
		var from = to_local(trail_points[i - 1]["pos"])
		var to = to_local(trail_points[i]["pos"])

		draw_line(from, to, Color(trail_color.r, trail_color.g, trail_color.b, avg_alpha * 0.85), maxf(width, 0.3))


func _on_body_entered(body: Node2D) -> void:
	# Вражеские снаряды не попадают по своим танкам
	if is_enemy and body.is_in_group("enemy_tanks"):
		return
	hit.emit(global_position, body)
	queue_free()
