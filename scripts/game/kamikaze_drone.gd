# scripts/game/kamikaze_drone.gd
# Дрон-камикадзе — маленький, дешёвый, летит к цели и взрывается
extends Node2D

## Здоровье (очень хрупкий)
@export var max_hp: int = 1
## Скорость полёта (пикселей/сек)
@export var speed: float = 150.0
## Урон при попадании
@export var impact_damage: int = 4
## Радиус взрыва
@export var blast_radius: float = 30.0
## Радиус попадания (дистанция до цели для подрыва)
@export var impact_radius: float = 20.0
## Цвет корпуса
@export var body_color: Color = Color(0.2, 0.22, 0.2)
## Цвет пропеллеров
@export var prop_color: Color = Color(0.3, 0.32, 0.28)

var unit_type: String = "kamikaze_drone"
var team: String = "enemy"
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0

# Бой
var projectiles_container: Node2D
var projectile_scenes: Dictionary = {}
var battle_manager: Node2D

# AI: цель
var target: Node2D = null
var no_target_dir: Vector2 = Vector2(-1, 0)  # Если нет цели — летим влево

# Визуальные эффекты
var prop_angle: float = 0.0
var led_timer: float = 0.0
var led_on: bool = true
var flight_time: float = 0.0

# Шлейф дыма
var trail_points: Array = []
const TRAIL_LENGTH: int = 20
const TRAIL_LIFETIME: float = 0.5
const TRAIL_MAX_WIDTH: float = 2.0

signal destroyed


func _ready() -> void:
	hp = max_hp
	add_to_group("air_units")
	add_to_group("enemy_units")
	_find_new_target()


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, manager: Node2D) -> void:
	projectiles_container = proj_container
	projectile_scenes = proj_scenes
	battle_manager = manager


func _process(delta: float) -> void:
	if not alive:
		return

	flight_time += delta

	# Пропеллеры крутятся
	prop_angle += 20.0 * delta
	if prop_angle > TAU:
		prop_angle -= TAU

	# Мигание LED
	led_timer += delta
	if led_timer >= 0.3:
		led_timer = 0.0
		led_on = not led_on

	# Проверяем жива ли цель
	if target and is_instance_valid(target):
		if "alive" in target and not target.alive:
			target = null
			_find_new_target()
	elif target:
		# Цель уничтожена
		target = null
		_find_new_target()

	# Движение
	if target and is_instance_valid(target):
		var target_pos = target.global_position
		var dir = (target_pos - global_position).normalized()
		position += dir * speed * delta

		# Проверяем попадание
		var dist = global_position.distance_to(target_pos)
		if dist < impact_radius:
			_explode()
			return
	else:
		# Нет цели — летим влево и вниз
		position += no_target_dir * speed * delta
		if position.x < -100 or position.y > 600:
			queue_free()
			return

	# ПВО
	_check_aa_hits()

	# Шлейф
	_update_trail(delta)

	queue_redraw()


func _find_new_target() -> void:
	# Приоритет: танки > техника > пехота
	var best: Node2D = null
	var best_priority: int = 0
	var best_dist: float = 99999.0

	# Танки (высший приоритет)
	for unit in get_tree().get_nodes_in_group("player_vehicles"):
		if "alive" in unit and not unit.alive:
			continue
		var dist = global_position.distance_to(unit.global_position)
		if best_priority < 3 or (best_priority == 3 and dist < best_dist):
			best = unit
			best_priority = 3
			best_dist = dist

	# Пехота (низший приоритет)
	if not best:
		for group_name in ["player_units", "infantry"]:
			for unit in get_tree().get_nodes_in_group(group_name):
				if "alive" in unit and not unit.alive:
					continue
				var dist = global_position.distance_to(unit.global_position)
				if best_priority < 1 or (best_priority == 1 and dist < best_dist):
					best = unit
					best_priority = 1
					best_dist = dist

	target = best

	if not target:
		# Нет целей — летим влево
		no_target_dir = Vector2(-1, 0.2).normalized()


func _explode() -> void:
	alive = false
	shots_fired += 1

	# Прямой урон по ближайшей цели
	var impact_target = _find_impact_target()
	if impact_target and impact_target.has_method("take_damage"):
		impact_target.take_damage(impact_damage)
		shots_hit += 1

	# Осколочный урон по юнитам в радиусе взрыва
	_apply_blast_damage()

	destroyed.emit()
	queue_free()


func _find_impact_target() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = blast_radius

	for group_name in ["infantry", "player_units", "player_vehicles"]:
		for unit in get_tree().get_nodes_in_group(group_name):
			if "alive" in unit and not unit.alive:
				continue
			if not unit.has_method("take_damage"):
				continue
			var dist = global_position.distance_to(unit.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = unit

	return closest


func _apply_blast_damage() -> void:
	# Осколочный урон 1 в радиусе blast_radius (исключая прямое попадание)
	var damaged: Array = []
	for group_name in ["infantry", "player_units", "player_vehicles"]:
		for unit in get_tree().get_nodes_in_group(group_name):
			if unit in damaged:
				continue
			if "alive" in unit and not unit.alive:
				continue
			if not unit.has_method("take_damage"):
				continue
			var dist = global_position.distance_to(unit.global_position)
			if dist <= blast_radius and dist > impact_radius * 0.5:
				unit.take_damage(1)
				damaged.append(unit)


func _check_aa_hits() -> void:
	if not alive or not projectiles_container:
		return
	for proj in projectiles_container.get_children():
		if not is_instance_valid(proj):
			continue
		if "is_enemy" in proj and proj.is_enemy:
			continue
		var dist = proj.global_position.distance_to(global_position)
		if dist < 18.0:  # Дрон маленький — меньший хитбокс
			take_damage(1)
			proj.queue_free()
			break


func take_damage(amount: int = 1) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0:
		alive = false
		destroyed.emit()
		queue_free()


func _update_trail(delta: float) -> void:
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


func _draw() -> void:
	# === ДЫМОВОЙ ШЛЕЙФ ===
	var count = trail_points.size()
	if count >= 2:
		for j in range(1, count):
			var t = float(j) / float(count - 1)
			var age_alpha = 1.0 - trail_points[j]["age"] / TRAIL_LIFETIME
			var alpha = t * age_alpha * 0.3
			var width = t * TRAIL_MAX_WIDTH * age_alpha

			var from = to_local(trail_points[j - 1]["pos"])
			var to = to_local(trail_points[j]["pos"])
			draw_line(from, to, Color(0.5, 0.5, 0.45, alpha), maxf(width, 0.3))

	# === КОРПУС ДРОНА (X-образный) ===
	var arm_len = 7.0
	var arm_w = 1.8

	# Четыре луча X-формы
	# Передний-верхний
	draw_line(Vector2(0, 0), Vector2(-arm_len, -arm_len), body_color, arm_w)
	# Передний-нижний
	draw_line(Vector2(0, 0), Vector2(-arm_len, arm_len), body_color, arm_w)
	# Задний-верхний
	draw_line(Vector2(0, 0), Vector2(arm_len, -arm_len), body_color, arm_w)
	# Задний-нижний
	draw_line(Vector2(0, 0), Vector2(arm_len, arm_len), body_color, arm_w)

	# Центральная плата (маленький квадрат)
	draw_rect(Rect2(-3, -2, 6, 4), body_color.lightened(0.1))

	# Боевая часть (снизу, чуть светлее)
	draw_rect(Rect2(-2, 2, 4, 3), Color(0.35, 0.3, 0.25))

	# === ПРОПЕЛЛЕРЫ ===
	# Четыре пропеллера на концах лучей
	var prop_positions = [
		Vector2(-arm_len, -arm_len),
		Vector2(-arm_len, arm_len),
		Vector2(arm_len, -arm_len),
		Vector2(arm_len, arm_len),
	]

	for i in range(4):
		var pp = prop_positions[i]
		var prop_r = 4.0
		# Каждый пропеллер с разной фазой
		var phase = prop_angle + i * PI * 0.5

		# Лопасти (две линии)
		var b1_dx = cos(phase) * prop_r
		var b1_dy = sin(phase) * prop_r * 0.3  # Перспективное сплющивание
		draw_line(
			pp + Vector2(-b1_dx, -b1_dy),
			pp + Vector2(b1_dx, b1_dy),
			Color(prop_color.r, prop_color.g, prop_color.b, 0.6), 1.2
		)

		var b2_dx = cos(phase + PI * 0.5) * prop_r
		var b2_dy = sin(phase + PI * 0.5) * prop_r * 0.3
		draw_line(
			pp + Vector2(-b2_dx, -b2_dy),
			pp + Vector2(b2_dx, b2_dy),
			Color(prop_color.r, prop_color.g, prop_color.b, 0.5), 1.2
		)

		# Полупрозрачный диск вращения
		draw_circle(pp, prop_r * 0.5, Color(0.4, 0.42, 0.38, 0.06))

	# === КРАСНЫЙ LED (мигающий) ===
	if led_on:
		draw_circle(Vector2(0, -3), 1.5, Color(1.0, 0.1, 0.05, 0.9))
		# Свечение вокруг LED
		draw_circle(Vector2(0, -3), 3.0, Color(1.0, 0.1, 0.05, 0.2))
	else:
		# Выключенный LED — тусклая точка
		draw_circle(Vector2(0, -3), 1.0, Color(0.3, 0.05, 0.03, 0.5))

	# === АНТЕННА (маленький штырь назад) ===
	draw_line(Vector2(3, -2), Vector2(6, -5), Color(0.4, 0.4, 0.35), 0.8)
	draw_circle(Vector2(6, -5), 0.8, Color(0.45, 0.45, 0.4))
