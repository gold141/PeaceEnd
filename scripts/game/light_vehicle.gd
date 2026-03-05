# scripts/game/light_vehicle.gd
# Лёгкая техника (Technical) — быстрый пикап с пулемётом
extends StaticBody2D

## Здоровье
@export var max_hp: int = 5
## Скорость езды (пикселей/сек)
@export var drive_speed: float = 80.0
## Дальность стрельбы (пиксели)
@export var fire_range: float = 350.0
## Интервал стрельбы (секунды)
@export var fire_interval: float = 1.5
## Разброс угла (градусы)
@export var spread_degrees: float = 5.0
## Урон за пулю
@export var damage: float = 1.0

var unit_type: String = "light_vehicle"
var team: String = "player"
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0

# Езда
var deployed: bool = false
var deploy_x: float = 0.0

# Стрельба
var fire_timer: float = 0.0
var projectiles_container: Node2D
var projectile_scenes: Dictionary = {}
var battle_manager: Node2D

# Визуальные цвета
var body_color: Color = Color(0.45, 0.5, 0.35)  # Оливковый/песочный
var cab_color: Color = Color(0.4, 0.45, 0.32)
var wheel_color: Color = Color(0.15, 0.15, 0.13)
var wheel_hub_color: Color = Color(0.25, 0.25, 0.2)
var gun_color: Color = Color(0.2, 0.2, 0.18)
var window_color: Color = Color(0.25, 0.35, 0.4, 0.7)

# Вспышка выстрела
var muzzle_flash_timer: float = 0.0
const MUZZLE_FLASH_DURATION: float = 0.12

# Пылевые частицы (при езде)
var dust_particles: Array = []
var dust_spawn_timer: float = 0.0

# Дым при уничтожении
var smoking: bool = false
var smoke_timer: float = 0.0
var smoke_particles: Array = []
var smoke_spawn_timer: float = 0.0
const SMOKE_DURATION: float = 30.0

signal destroyed
signal fired_bullet(proj: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("player_units")
	add_to_group("player_vehicles")
	deploy_x = randf_range(200.0, 3500.0)
	fire_timer = 1.0


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, manager: Node2D) -> void:
	projectiles_container = proj_container
	projectile_scenes = proj_scenes
	battle_manager = manager


func _process(delta: float) -> void:
	if alive and not deployed:
		# Едем к позиции
		position.x += drive_speed * delta

		# Пыль при езде
		dust_spawn_timer += delta
		if dust_spawn_timer >= 0.06:
			dust_spawn_timer = 0.0
			_spawn_dust()

		if position.x >= deploy_x:
			position.x = deploy_x
			deployed = true

		queue_redraw()

	elif alive and deployed:
		# Стреляем
		fire_timer -= delta
		if fire_timer <= 0:
			fire_timer = fire_interval + randf_range(-0.2, 0.2)
			_try_fire()

		if muzzle_flash_timer > 0:
			muzzle_flash_timer -= delta
			queue_redraw()

	# Обновляем пылевые частицы
	var i = 0
	while i < dust_particles.size():
		var p = dust_particles[i]
		p["age"] += delta
		if p["age"] >= p["max_age"]:
			dust_particles.remove_at(i)
			continue
		p["pos"] += p["vel"] * delta
		p["size"] += 12.0 * delta
		i += 1

	if dust_particles.size() > 0:
		queue_redraw()

	# Дым при уничтожении
	if smoking:
		smoke_timer += delta
		if smoke_timer >= SMOKE_DURATION:
			smoking = false
			smoke_particles.clear()
			queue_redraw()

		smoke_spawn_timer += delta
		if smoke_spawn_timer >= 0.2:
			smoke_spawn_timer = 0.0
			_spawn_smoke()

	var j = 0
	while j < smoke_particles.size():
		var p = smoke_particles[j]
		p["age"] += delta
		if p["age"] >= p["max_age"]:
			smoke_particles.remove_at(j)
			continue
		p["pos"] += p["vel"] * delta
		p["size"] += 6.0 * delta
		j += 1

	if smoke_particles.size() > 0:
		queue_redraw()


func _try_fire() -> void:
	if not projectile_scenes.has("bullet") or not projectiles_container:
		return

	var target = _find_target()
	if not target:
		return

	# Почти горизонтальный огонь
	var angle = randf_range(0.0, 5.0)
	angle += randf_range(-spread_degrees, spread_degrees)
	angle = clampf(angle, -3.0, 8.0)

	var bullet_scene = projectile_scenes["bullet"]
	var proj = bullet_scene.instantiate()
	proj.global_position = global_position + Vector2(16, -22)
	proj.damage = damage
	proj.launch(angle, 900.0)
	projectiles_container.add_child(proj)
	fired_bullet.emit(proj)
	shots_fired += 1

	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()


func _find_target() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = fire_range

	# Наземные враги — танки и пехота
	var target_groups = ["enemy_tanks", "enemy_infantry_group"]
	for group_name in target_groups:
		for unit in get_tree().get_nodes_in_group(group_name):
			if "alive" in unit and not unit.alive:
				continue
			var dist = abs(unit.global_position.x - global_position.x)
			if dist < closest_dist:
				closest_dist = dist
				closest = unit

	return closest


func _spawn_dust() -> void:
	dust_particles.append({
		"pos": Vector2(randf_range(-20, -14), randf_range(-2, 2)),
		"vel": Vector2(randf_range(-30, -10), randf_range(-15, -5)),
		"size": randf_range(3, 6),
		"alpha": randf_range(0.3, 0.5),
		"age": 0.0,
		"max_age": randf_range(0.6, 1.2),
	})


func _spawn_smoke() -> void:
	smoke_particles.append({
		"pos": Vector2(randf_range(-6, 6), -14),
		"vel": Vector2(randf_range(-6, 6), randf_range(-30, -15)),
		"size": randf_range(3, 6),
		"alpha": randf_range(0.4, 0.7),
		"age": 0.0,
		"max_age": randf_range(2.0, 3.5),
	})


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
	collision_layer = 0
	body_color = Color(0.2, 0.2, 0.18)
	cab_color = Color(0.18, 0.18, 0.16)
	wheel_color = Color(0.1, 0.1, 0.08)
	wheel_hub_color = Color(0.13, 0.13, 0.11)
	gun_color = Color(0.1, 0.1, 0.08)
	window_color = Color(0.12, 0.12, 0.12, 0.5)
	modulate = Color.WHITE
	smoking = true
	smoke_timer = 0.0
	queue_redraw()
	# Не удаляемся — остаёмся как обломки (дым уберёт через SMOKE_DURATION)


func _draw() -> void:
	# === КУЗОВ ПИКАПА ===
	# Основной кузов — прямоугольник
	draw_rect(Rect2(-22, -12, 44, 14), body_color)

	# Кабина (слева, чуть выше)
	draw_rect(Rect2(-22, -20, 18, 10), cab_color)
	# Лобовое стекло
	draw_rect(Rect2(-6, -19, 3, 8), window_color)
	# Заднее стекло
	draw_rect(Rect2(-21, -19, 3, 8), window_color)

	# Борт кузова (задняя часть — бортики)
	draw_rect(Rect2(-2, -14, 24, 2), body_color.darkened(0.15))

	# Полоса на борту (декоративная)
	draw_line(Vector2(-22, -5), Vector2(22, -5), body_color.lightened(0.1), 1.0)

	# === КОЛЁСА ===
	# Переднее левое
	draw_circle(Vector2(-14, 4), 5.0, wheel_color)
	draw_circle(Vector2(-14, 4), 2.5, wheel_hub_color)
	# Переднее правое (визуально — заднее)
	draw_circle(Vector2(14, 4), 5.0, wheel_color)
	draw_circle(Vector2(14, 4), 2.5, wheel_hub_color)

	# === УСТАНОВЛЕННЫЙ ПУЛЕМЁТ (сзади, на турели) ===
	if alive:
		# Стойка турели
		draw_line(Vector2(8, -14), Vector2(8, -20), gun_color, 2.0)
		# Поворотная платформа
		draw_rect(Rect2(4, -22, 8, 3), gun_color.lightened(0.1))
		# Ствол (вправо)
		draw_line(Vector2(12, -20), Vector2(28, -20), gun_color, 2.5)
		# Дульный тормоз
		draw_rect(Rect2(26, -22, 4, 5), gun_color.lightened(0.05))
		# Рукоятки
		draw_line(Vector2(6, -22), Vector2(4, -26), gun_color, 1.5)
		draw_line(Vector2(10, -22), Vector2(12, -26), gun_color, 1.5)

	# === ВСПЫШКА ВЫСТРЕЛА ===
	if muzzle_flash_timer > 0 and alive:
		var t = muzzle_flash_timer / MUZZLE_FLASH_DURATION
		var flash_pos = Vector2(30, -20)
		draw_circle(flash_pos, 5.0 * t, Color(1.0, 0.9, 0.4, 0.9 * t))
		draw_circle(flash_pos, 8.0 * t, Color(1.0, 0.7, 0.2, 0.35 * t))

	# === ПЫЛЬ (при езде) ===
	for p in dust_particles:
		var t = p["age"] / p["max_age"]
		var alpha = p["alpha"] * (1.0 - t)
		draw_circle(p["pos"], p["size"], Color(0.65, 0.55, 0.4, alpha))

	# === ДЫМ (при уничтожении) ===
	for p in smoke_particles:
		var t = p["age"] / p["max_age"]
		var alpha = p["alpha"] * (1.0 - t)
		var gray = randf_range(0.08, 0.22)
		draw_circle(p["pos"], p["size"], Color(gray, gray, gray, alpha))
