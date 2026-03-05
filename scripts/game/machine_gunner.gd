# scripts/game/machine_gunner.gd
# Пулемётчик — быстрый огонь по пехоте и дронам, за мешками с песком
extends Node2D

## Здоровье
@export var max_hp: int = 2
## Скорость ходьбы (пикселей/сек)
@export var walk_speed: float = 30.0
## Дальность стрельбы (пиксели)
@export var fire_range: float = 200.0
## Интервал стрельбы (секунды) — быстрая очередь
@export var fire_interval: float = 0.25
## Разброс угла (градусы)
@export var spread_degrees: float = 3.0
## Урон за пулю
@export var damage: float = 0.3

var unit_type: String = "machine_gunner"
var team: String = "player"
var min_fire_angle: float = -4.0
var max_fire_angle: float = 12.0
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0

# Ходьба
var deployed: bool = false
var deploy_x: float = 0.0
var walk_timer: float = 0.0  # анимация ног
var manually_controlled: bool = false

# Стрельба
var fire_timer: float = 0.0
var projectiles_container: Node2D
var projectile_scenes: Dictionary = {}
var battle_manager: Node2D

# Визуальные цвета
var bag_color: Color = Color(0.6, 0.5, 0.3)
var bag_color2: Color = Color(0.55, 0.45, 0.28)
var uniform_color: Color = Color(0.3, 0.35, 0.25)
var skin_color: Color = Color(0.55, 0.5, 0.4)
var helmet_color: Color = Color(0.3, 0.35, 0.25)
var weapon_color: Color = Color(0.2, 0.2, 0.18)
var mg_color: Color = Color(0.22, 0.22, 0.2)
var tripod_color: Color = Color(0.25, 0.25, 0.2)

# Вспышка выстрела
var muzzle_flash_timer: float = 0.0
const MUZZLE_FLASH_DURATION: float = 0.08  # Короче, чем у РПГ

signal destroyed
signal fired_bullet(proj: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("player_units")
	add_to_group("infantry")
	deploy_x = randf_range(80.0, 2000.0)
	fire_timer = 0.5


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, manager: Node2D) -> void:
	projectiles_container = proj_container
	projectile_scenes = proj_scenes
	battle_manager = manager


func _process(delta: float) -> void:
	if not alive:
		return

	if not deployed:
		# Идём к позиции развёртывания
		position.x += walk_speed * delta
		walk_timer += delta

		if position.x >= deploy_x:
			position.x = deploy_x
			deployed = true
			walk_timer = 0.0

		queue_redraw()
		return

	# Развёрнуты — стреляем
	if not manually_controlled:
		fire_timer -= delta
		if fire_timer <= 0:
			fire_timer = fire_interval + randf_range(-0.03, 0.03)
			_try_fire()
	else:
		if fire_timer > 0:
			fire_timer -= delta

	if muzzle_flash_timer > 0:
		muzzle_flash_timer -= delta
		queue_redraw()


func _try_fire() -> void:
	if not projectile_scenes.has("bullet") or not projectiles_container:
		return

	var target = _find_target()
	if not target:
		return

	# Почти горизонтальный огонь
	var angle = randf_range(0.0, 3.0)
	angle += randf_range(-spread_degrees, spread_degrees)
	angle = clampf(angle, -4.0, 12.0)

	var bullet_scene = projectile_scenes["bullet"]
	var proj = bullet_scene.instantiate()
	proj.global_position = global_position + Vector2(26, -28)
	proj.damage = damage
	proj.launch(angle, 900.0)
	projectiles_container.add_child(proj)
	fired_bullet.emit(proj)
	shots_fired += 1

	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()


func manual_fire_at(target_pos: Vector2) -> bool:
	if not alive or not deployed:
		return false
	if fire_timer > 0:
		return false
	if not projectile_scenes.has("bullet") or not projectiles_container:
		return false

	var angle = randf_range(0.0, 3.0)
	angle += randf_range(-spread_degrees, spread_degrees)
	angle = clampf(angle, -4.0, 12.0)

	var bullet_scene = projectile_scenes["bullet"]
	var proj = bullet_scene.instantiate()
	proj.global_position = global_position + Vector2(26, -28)
	proj.damage = damage
	proj.launch(angle, 900.0)
	projectiles_container.add_child(proj)
	fired_bullet.emit(proj)
	shots_fired += 1

	fire_timer = fire_interval
	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()
	return true


func _find_target() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = fire_range

	# Приоритет 1: вражеская пехота
	for unit in get_tree().get_nodes_in_group("enemy_infantry_group"):
		if not unit.alive:
			continue
		var dist = abs(unit.global_position.x - global_position.x)
		if dist < closest_dist:
			closest_dist = dist
			closest = unit

	if closest:
		return closest

	# Приоритет 2: дроны (воздушные юниты на малой высоте)
	for unit in get_tree().get_nodes_in_group("air_units"):
		if "alive" in unit and not unit.alive:
			continue
		if unit.global_position.y > 300:
			continue  # Слишком высоко для пулемёта — пропускаем
		var dist = abs(unit.global_position.x - global_position.x)
		if dist < closest_dist:
			closest_dist = dist
			closest = unit

	return closest


func take_damage(amount: int = 1) -> void:
	if not alive:
		return
	hp -= amount
	_flash()
	if hp <= 0:
		alive = false
		destroyed.emit()
		_die()


func _flash() -> void:
	modulate = Color(3.0, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)


func _die() -> void:
	bag_color = Color(0.3, 0.28, 0.25)
	bag_color2 = Color(0.28, 0.25, 0.22)
	uniform_color = Color(0.18, 0.18, 0.16)
	skin_color = Color(0.3, 0.28, 0.25)
	helmet_color = Color(0.18, 0.18, 0.16)
	mg_color = Color(0.12, 0.12, 0.1)
	tripod_color = Color(0.14, 0.14, 0.12)
	weapon_color = Color(0.1, 0.1, 0.08)
	modulate = Color.WHITE
	queue_redraw()
	var timer = get_tree().create_timer(10.0)
	timer.timeout.connect(queue_free)


func _draw() -> void:
	if not deployed:
		_draw_walking()
		return

	# === РАЗВЁРНУТАЯ ПОЗИЦИЯ: мешки + солдат + пулемёт ===

	# Мешки с песком — нижний ряд (3 мешка)
	var bag_w = 16.0
	var bag_h = 10.0
	var base_y = -bag_h

	for i in range(3):
		var bx = -1.5 * bag_w + i * bag_w
		var c = bag_color if i % 2 == 0 else bag_color2
		draw_rect(Rect2(bx, base_y, bag_w - 1, bag_h), c)
		draw_rect(Rect2(bx, base_y, bag_w - 1, bag_h), c.darkened(0.3), false, 1.0)

	# Верхний ряд (2 мешка)
	var top_y = base_y - bag_h
	for i in range(2):
		var bx = -bag_w + i * bag_w
		var c = bag_color2 if i % 2 == 0 else bag_color
		draw_rect(Rect2(bx, top_y, bag_w - 1, bag_h), c)
		draw_rect(Rect2(bx, top_y, bag_w - 1, bag_h), c.darkened(0.3), false, 1.0)

	if not alive:
		return

	# Солдат за мешками
	var soldier_y = -bag_h * 2

	# Голова
	draw_circle(Vector2(-4, soldier_y - 8), 5.0, skin_color)

	# Каска
	draw_arc(Vector2(-4, soldier_y - 10), 6.0, PI, TAU, 12, helmet_color, 2.5)

	# Тело (слегка наклонён к пулемёту)
	draw_rect(Rect2(-9, soldier_y - 2, 10, 14), uniform_color)

	# Руки к пулемёту
	draw_line(Vector2(1, soldier_y + 2), Vector2(8, soldier_y - 2), uniform_color, 2.5)
	draw_line(Vector2(1, soldier_y + 6), Vector2(12, soldier_y + 0), uniform_color, 2.5)

	# === Пулемёт на треноге ===
	# Тренога — две ноги
	draw_line(Vector2(10, soldier_y + 4), Vector2(6, base_y), tripod_color, 2.0)
	draw_line(Vector2(10, soldier_y + 4), Vector2(16, base_y), tripod_color, 2.0)

	# Тело пулемёта (коробка)
	draw_rect(Rect2(6, soldier_y - 4, 14, 6), mg_color)

	# Ствол
	draw_line(Vector2(20, soldier_y - 1), Vector2(34, soldier_y - 1), weapon_color, 2.5)
	# Дульный тормоз
	draw_rect(Rect2(32, soldier_y - 3, 4, 5), weapon_color.lightened(0.1))

	# Коробка с патронами (снизу пулемёта)
	draw_rect(Rect2(8, soldier_y + 2, 8, 5), Color(0.25, 0.25, 0.2))

	# Вспышка выстрела — быстрая и яркая
	if muzzle_flash_timer > 0:
		var t = muzzle_flash_timer / MUZZLE_FLASH_DURATION
		var flash_pos = Vector2(36, soldier_y - 1)
		# Яркая центральная вспышка
		draw_circle(flash_pos, 5.0 * t, Color(1.0, 0.95, 0.5, 0.95 * t))
		# Внешнее свечение
		draw_circle(flash_pos, 8.0 * t, Color(1.0, 0.7, 0.2, 0.4 * t))
		# Лучи-искры (короткие линии)
		var spark_len = 6.0 * t
		draw_line(flash_pos, flash_pos + Vector2(spark_len, -spark_len * 0.5), Color(1.0, 0.9, 0.3, 0.6 * t), 1.0)
		draw_line(flash_pos, flash_pos + Vector2(spark_len, spark_len * 0.5), Color(1.0, 0.9, 0.3, 0.6 * t), 1.0)


func _draw_walking() -> void:
	# Идущий солдат (без мешков, ноги анимированы)
	var bob = sin(walk_timer * 8.0) * 1.5

	# Тело
	draw_rect(Rect2(-5, -22 + bob, 10, 14), uniform_color)

	# Голова
	draw_circle(Vector2(0, -28 + bob), 5.0, skin_color)

	# Каска
	draw_arc(Vector2(0, -30 + bob), 6.0, PI, TAU, 12, helmet_color, 2.5)

	# Ноги — анимация ходьбы
	var leg_phase = sin(walk_timer * 8.0)
	var left_foot_x = -3 + leg_phase * 4.0
	var right_foot_x = 3 - leg_phase * 4.0

	draw_line(Vector2(-2, -8 + bob), Vector2(left_foot_x, 0), uniform_color.darkened(0.15), 2.5)
	draw_line(Vector2(2, -8 + bob), Vector2(right_foot_x, 0), uniform_color.darkened(0.15), 2.5)

	# Пулемёт несёт в руках (горизонтально)
	draw_line(Vector2(3, -16 + bob), Vector2(18, -18 + bob), mg_color, 2.5)
	# Ствол торчит вперёд
	draw_line(Vector2(18, -18 + bob), Vector2(26, -18 + bob), weapon_color, 2.0)
