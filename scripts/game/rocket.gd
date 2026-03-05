# scripts/game/rocket.gd
# Противотанковая ракета (РПГ) — двухступенчатая физика
# Фаза 1: вышибной заряд (начальная скорость, без тяги)
# Фаза 2: маршевый двигатель (ускорение, дымовой шлейф)
# Фаза 3: инерция (двигатель выгорел, гравитация тянет вниз)
extends Area2D

## Начальная скорость вышибного заряда (px/s)
@export var booster_speed: float = 200.0
## Время вышибной фазы (секунды)
@export var booster_duration: float = 0.12
## Ускорение маршевого двигателя (px/s²)
@export var sustainer_accel: float = 550.0
## Время работы маршевого двигателя (секунды)
@export var sustainer_duration: float = 0.5
## Максимальная скорость ракеты (px/s)
@export var max_speed: float = 450.0
## Гравитация (слабая — ракета пологая)
@export var gravity_force: float = 80.0
## Сопротивление воздуха (слабое для ракеты)
@export var air_drag: float = 0.1
## Цвет шлейфа (дым)
@export var smoke_color: Color = Color(0.7, 0.7, 0.65)
## Цвет огня двигателя
@export var flame_color: Color = Color(1.0, 0.6, 0.15)

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false
var flight_time: float = 0.0
var direction: Vector2 = Vector2.RIGHT

# Шлейф
var trail_points: Array = []
const TRAIL_LENGTH: int = 45
const TRAIL_LIFETIME: float = 1.0
const TRAIL_MAX_WIDTH: float = 3.0

signal hit(position: Vector2, body: Node2D)
signal off_screen()


func launch(angle_deg: float, _power_unused: float = 0.0) -> void:
	var angle_rad = deg_to_rad(angle_deg)
	direction = Vector2(cos(angle_rad), -sin(angle_rad)).normalized()
	velocity = direction * booster_speed
	launched = true
	flight_time = 0.0


func _process(delta: float) -> void:
	if not launched:
		return

	flight_time += delta

	# Определяем фазу полёта
	if flight_time < booster_duration:
		# Фаза 1: вышибной — только начальная скорость, слабая гравитация
		velocity.y += gravity_force * 0.3 * delta
	elif flight_time < booster_duration + sustainer_duration:
		# Фаза 2: маршевый двигатель — ускорение вдоль направления
		var speed = velocity.length()
		if speed < max_speed:
			velocity += velocity.normalized() * sustainer_accel * delta
			# Ограничиваем
			if velocity.length() > max_speed:
				velocity = velocity.normalized() * max_speed
		velocity.y += gravity_force * 0.5 * delta
	else:
		# Фаза 3: инерция — двигатель выгорел
		velocity -= velocity * air_drag * delta
		velocity.y += gravity_force * delta

	position += velocity * delta
	rotation = velocity.angle()

	# Шлейф — на всём протяжении полёта
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

	# Удаление за экраном
	if position.y > 600 or position.x > 6600 or position.x < -100:
		off_screen.emit()
		queue_free()


func _draw() -> void:
	# Тело ракеты (маленькое)
	draw_rect(Rect2(-3, -0.5, 5, 1), Color(0.35, 0.38, 0.3))
	# Головка
	draw_circle(Vector2(3, 0), 1.0, Color(0.5, 0.45, 0.35))

	# Огонёк на голове (маленький)
	var head_flicker = randf_range(0.6, 1.0)
	draw_circle(Vector2(4, 0), 1.5 * head_flicker, Color(1.0, 0.5, 0.15, 0.9))

	# Огонь двигателя (фаза 2)
	var engine_on = flight_time >= booster_duration and flight_time < booster_duration + sustainer_duration
	if engine_on:
		var flicker = randf_range(0.7, 1.0)
		draw_circle(Vector2(-4, 0), 2.0 * flicker, flame_color)
		draw_circle(Vector2(-6, 0), 1.5 * flicker, Color(1.0, 0.9, 0.4, 0.8))

	# Шлейф дыма
	var count = trail_points.size()
	if count < 2:
		return

	for j in range(1, count):
		var t = float(j) / float(count - 1)
		var age_alpha = 1.0 - trail_points[j]["age"] / TRAIL_LIFETIME
		var alpha = t * age_alpha * 0.6
		var width = t * TRAIL_MAX_WIDTH * age_alpha

		var from = to_local(trail_points[j - 1]["pos"])
		var to = to_local(trail_points[j]["pos"])

		# Дымовой шлейф — серый
		var c = Color(smoke_color.r, smoke_color.g, smoke_color.b, alpha)
		draw_line(from, to, c, maxf(width, 0.3))


func _on_body_entered(body: Node2D) -> void:
	hit.emit(global_position, body)
	queue_free()
