# scripts/game/infantry.gd
# Пехотный юнит — солдат за мешками с песком, стреляет ПТ-ракетами (РПГ)
extends Node2D

## Здоровье
@export var max_hp: int = 2
## Дальность стрельбы (пиксели)
@export var fire_range: float = 300.0
## Интервал стрельбы (секунды)
@export var fire_interval: float = 3.5
## Разброс угла (градусы) — tilt
@export var spread_degrees: float = 4.0

var unit_type: String = "infantry"
var team: String = "player"
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0
var fire_timer: float = 0.0

# Ходьба
var walk_speed: float = 30.0
var deploy_x: float = -1.0
var deployed: bool = false
var walk_timer: float = 0.0  # анимация ног
var manually_controlled: bool = false

# Сцена ракеты и контейнер — устанавливаются из battle_manager
var rocket_scene: PackedScene
var projectiles_container: Node2D

# Визуальные цвета
var bag_color: Color = Color(0.6, 0.5, 0.3)
var bag_color2: Color = Color(0.55, 0.45, 0.28)
var uniform_color: Color = Color(0.3, 0.35, 0.25)
var skin_color: Color = Color(0.55, 0.5, 0.4)
var helmet_color: Color = Color(0.3, 0.35, 0.25)
var weapon_color: Color = Color(0.2, 0.2, 0.18)
var rpg_color: Color = Color(0.3, 0.32, 0.25)

# Вспышка выстрела
var muzzle_flash_timer: float = 0.0
const MUZZLE_FLASH_DURATION: float = 0.15

signal destroyed
signal fired_rocket(rocket: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("infantry")
	add_to_group("player_units")
	fire_timer = 0.1

	# Если заспавнен за левым краем — идёт к позиции развёртывания
	if global_position.x < 0:
		deploy_x = randf_range(100.0, 2500.0)
		deployed = false
	else:
		# Размещён вручную (infantry_placer) — сразу развёрнут
		deployed = true


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, _manager: Node2D) -> void:
	projectiles_container = proj_container
	rocket_scene = proj_scenes["rocket"]


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
			fire_timer = fire_interval + randf_range(-0.3, 0.3)
			_try_fire()
	else:
		# Timer still ticks for reload tracking
		if fire_timer > 0:
			fire_timer -= delta

	if muzzle_flash_timer > 0:
		muzzle_flash_timer -= delta
		queue_redraw()


func _try_fire() -> void:
	if not rocket_scene or not projectiles_container:
		return

	# Ищем ближайший танк в радиусе
	var targets = get_tree().get_nodes_in_group("enemy_tanks")
	var closest: Node2D = null
	var closest_dist: float = fire_range

	for tank in targets:
		if not tank.alive:
			continue
		var dist = abs(tank.global_position.x - global_position.x)
		if dist < closest_dist:
			closest_dist = dist
			closest = tank

	if not closest:
		return

	# РПГ целится почти прямо в танк — минимальный подъём для компенсации гравитации
	# Чем дальше цель, тем чуть выше (но максимум 5°)
	var elevation = remap(closest_dist, 50.0, fire_range, 1.0, 6.0)
	var launch_angle = elevation

	# Добавляем разброс (tilt)
	launch_angle += randf_range(-spread_degrees, spread_degrees)
	launch_angle = clampf(launch_angle, -3.0, 8.0)

	# Создаём ракету
	var rocket = rocket_scene.instantiate()
	rocket.global_position = global_position + Vector2(18, -30)
	rocket.launch(launch_angle)
	projectiles_container.add_child(rocket)
	fired_rocket.emit(rocket)
	shots_fired += 1

	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()


func manual_fire_at(target_pos: Vector2) -> bool:
	if not alive or not deployed:
		return false
	if fire_timer > 0:
		return false
	if not rocket_scene or not projectiles_container:
		return false

	# Calculate angle to target (RPG-style: elevation based on distance)
	var distance = abs(target_pos.x - global_position.x)
	var elevation = remap(distance, 50.0, fire_range, 1.0, 6.0)
	elevation += randf_range(-spread_degrees, spread_degrees)
	elevation = clampf(elevation, -3.0, 8.0)

	var rocket = rocket_scene.instantiate()
	rocket.global_position = global_position + Vector2(18, -30)
	rocket.launch(elevation)
	projectiles_container.add_child(rocket)
	fired_rocket.emit(rocket)
	shots_fired += 1

	fire_timer = fire_interval
	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()
	return true


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
	# Становимся серыми руинами
	bag_color = Color(0.3, 0.28, 0.25)
	bag_color2 = Color(0.28, 0.25, 0.22)
	uniform_color = Color(0.18, 0.18, 0.16)
	skin_color = Color(0.3, 0.28, 0.25)
	helmet_color = Color(0.18, 0.18, 0.16)
	rpg_color = Color(0.15, 0.15, 0.13)
	modulate = Color.WHITE
	queue_redraw()
	# Удаляем через 10 секунд
	var timer = get_tree().create_timer(10.0)
	timer.timeout.connect(queue_free)


func _draw() -> void:
	if not deployed:
		_draw_walking()
		return

	# === РАЗВЁРНУТАЯ ПОЗИЦИЯ: мешки + солдат + РПГ ===

	# Центр = позиция юнита (на уровне земли)

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
	draw_circle(Vector2(0, soldier_y - 8), 5.0, skin_color)

	# Каска
	draw_arc(Vector2(0, soldier_y - 10), 6.0, PI, TAU, 12, helmet_color, 2.5)

	# Тело
	draw_rect(Rect2(-5, soldier_y - 2, 10, 14), uniform_color)

	# РПГ (труба на плече вправо)
	draw_line(Vector2(3, soldier_y - 2), Vector2(22, soldier_y - 8), rpg_color, 3.0)
	# Раструб РПГ сзади
	draw_line(Vector2(-2, soldier_y + 2), Vector2(3, soldier_y - 2), rpg_color, 2.5)
	# Боеголовка
	draw_rect(Rect2(20, soldier_y - 11, 5, 6), Color(0.45, 0.4, 0.3))

	# Вспышка выстрела + задний выхлоп
	if muzzle_flash_timer > 0:
		var t = muzzle_flash_timer / MUZZLE_FLASH_DURATION
		# Передняя вспышка
		var flash_pos = Vector2(26, soldier_y - 8)
		draw_circle(flash_pos, 4.0 * t, Color(1.0, 0.8, 0.2, 0.9 * t))
		# Задний выхлоп РПГ
		var back_pos = Vector2(-6, soldier_y + 4)
		draw_circle(back_pos, 6.0 * t, Color(0.8, 0.6, 0.2, 0.5 * t))
		draw_circle(back_pos + Vector2(-4, 2), 4.0 * t, Color(0.6, 0.6, 0.5, 0.3 * t))


func _draw_walking() -> void:
	# Идущий солдат (без мешков, ноги анимированы, несёт РПГ)
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

	# РПГ несёт на плече (диагонально вверх-вправо)
	draw_line(Vector2(3, -16 + bob), Vector2(20, -22 + bob), rpg_color, 3.0)
	# Раструб сзади
	draw_line(Vector2(-4, -12 + bob), Vector2(3, -16 + bob), rpg_color, 2.5)
	# Боеголовка на конце
	draw_rect(Rect2(18, -25 + bob, 5, 5), Color(0.45, 0.4, 0.3))
