# scripts/game/player_tank.gd
# Танк игрока — тяжёлая броня, параболическая стрельба вправо
extends StaticBody2D

## Здоровье
@export var max_hp: int = 8
## Скорость езды (пикселей/сек)
@export var drive_speed: float = 20.0
## Дальность стрельбы (пиксели)
@export var fire_range: float = 500.0
## Интервал стрельбы (секунды)
@export var fire_interval: float = 4.0
## Разброс угла (градусы)
@export var spread_degrees: float = 6.0
## Сила выстрела (px/s)
@export var fire_power: float = 900.0
## Разброс силы (процент)
@export var spread_power: float = 0.1
## Урон
@export var damage: float = 2.0
## Цвет корпуса
@export var body_color: Color = Color(0.35, 0.4, 0.3)
## Цвет гусениц
@export var track_color: Color = Color(0.2, 0.2, 0.18)
## Цвет башни
@export var turret_color: Color = Color(0.3, 0.35, 0.25)
## Время дыма после уничтожения (секунды)
@export var smoke_duration: float = 60.0

var unit_type: String = "player_tank"
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

# Вспышка выстрела
var muzzle_flash_timer: float = 0.0
const MUZZLE_FLASH_DURATION: float = 0.2

# Дым при уничтожении
var smoking: bool = false
var smoke_timer: float = 0.0
var smoke_particles: Array = []
var smoke_spawn_timer: float = 0.0

signal destroyed
signal fired_projectile(proj: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("player_units")
	add_to_group("player_vehicles")
	deploy_x = randf_range(150.0, 2500.0)
	fire_timer = randf_range(1.0, fire_interval)


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, manager: Node2D) -> void:
	projectiles_container = proj_container
	projectile_scenes = proj_scenes
	battle_manager = manager


func _process(delta: float) -> void:
	if alive and not deployed:
		# Едем к позиции развёртывания
		position.x += drive_speed * delta

		if position.x >= deploy_x:
			position.x = deploy_x
			deployed = true

		queue_redraw()

	elif alive and deployed:
		# Стреляем
		var best_target = _find_closest_target()
		if best_target != Vector2.ZERO:
			fire_timer -= delta
			if fire_timer <= 0:
				fire_timer = fire_interval + randf_range(-0.5, 0.5)
				_fire_at(best_target)

		if muzzle_flash_timer > 0:
			muzzle_flash_timer -= delta
			queue_redraw()

	# Дым при уничтожении
	if smoking:
		smoke_timer += delta
		if smoke_timer >= smoke_duration:
			smoking = false
			smoke_particles.clear()
			queue_redraw()

		smoke_spawn_timer += delta
		if smoke_spawn_timer >= 0.15:
			smoke_spawn_timer = 0.0
			_spawn_smoke()

	# Обновляем частицы дыма
	var i = 0
	while i < smoke_particles.size():
		var p = smoke_particles[i]
		p["age"] += delta
		if p["age"] >= p["max_age"]:
			smoke_particles.remove_at(i)
			continue
		p["pos"] += p["vel"] * delta
		p["size"] += 8.0 * delta
		i += 1

	if smoking or smoke_particles.size() > 0:
		queue_redraw()


func _find_closest_target() -> Vector2:
	var best_pos = Vector2.ZERO
	var best_dist = fire_range

	# Проверяем вражеские танки
	for unit in get_tree().get_nodes_in_group("enemy_tanks"):
		if not unit.alive:
			continue
		var dist = abs(unit.global_position.x - global_position.x)
		if dist < best_dist:
			best_dist = dist
			best_pos = unit.global_position

	# Проверяем вражескую пехоту
	for unit in get_tree().get_nodes_in_group("enemy_infantry_group"):
		if "alive" in unit and not unit.alive:
			continue
		var dist = abs(unit.global_position.x - global_position.x)
		if dist < best_dist:
			best_dist = dist
			best_pos = unit.global_position

	# Проверяем общую группу врагов
	for unit in get_tree().get_nodes_in_group("enemy_units"):
		if "alive" in unit and not unit.alive:
			continue
		var dist = abs(unit.global_position.x - global_position.x)
		if dist < best_dist:
			best_dist = dist
			best_pos = unit.global_position

	return best_pos


func _fire_at(target_pos: Vector2) -> void:
	if not projectile_scenes.has("shell") or not projectiles_container:
		return

	var distance = abs(target_pos.x - global_position.x)
	var gravity = 120.0

	# Рассчитываем параболический угол — стрельба ВПРАВО
	var power = fire_power + randf_range(-90.0, 90.0)
	var sin_2phi = distance * gravity / (power * power)
	sin_2phi = clampf(sin_2phi, 0.0, 1.0)
	var phi_deg = rad_to_deg(0.5 * asin(sin_2phi))

	# Добавляем разброс
	phi_deg += randf_range(-spread_degrees, spread_degrees)
	phi_deg = clampf(phi_deg, 3.0, 35.0)

	# Угол для стрельбы вправо (0° = вправо, elevation вверх)
	var launch_angle = phi_deg

	var shell_scene = projectile_scenes["shell"]
	var proj = shell_scene.instantiate()
	proj.is_enemy = false
	# Танковые снаряды — пологие и быстрые
	proj.gravity_force = 120.0
	proj.air_drag = 0.08
	proj.trail_color = Color(0.5, 0.85, 0.5)  # Зеленоватый шлейф
	proj.global_position = global_position + Vector2(34, -16)  # Дуло справа
	proj.launch(launch_angle, power)
	projectiles_container.add_child(proj)
	fired_projectile.emit(proj)
	shots_fired += 1

	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()


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
	body_color = Color(0.18, 0.18, 0.16)
	track_color = Color(0.12, 0.12, 0.1)
	turret_color = Color(0.15, 0.15, 0.13)
	modulate = Color.WHITE
	smoking = true
	smoke_timer = 0.0
	queue_redraw()


func _spawn_smoke() -> void:
	smoke_particles.append({
		"pos": Vector2(randf_range(-10, 10), -20),
		"vel": Vector2(randf_range(-8, 8), randf_range(-40, -20)),
		"size": randf_range(4, 8),
		"alpha": randf_range(0.5, 0.8),
		"age": 0.0,
		"max_age": randf_range(2.0, 4.0),
	})


func _draw() -> void:
	# === ГУСЕНИЦЫ (зеркало enemy_tank — те же, но танк смотрит вправо) ===
	draw_rect(Rect2(-30, 5, 60, 12), track_color)
	for i in range(5):
		var wx = -24.0 + i * 12.0
		draw_circle(Vector2(wx, 11), 4.0, Color(0.15, 0.15, 0.13) if alive else Color(0.1, 0.1, 0.08))
		draw_circle(Vector2(wx, 11), 2.0, Color(0.25, 0.25, 0.22) if alive else Color(0.13, 0.13, 0.11))

	# === КОРПУС ===
	draw_rect(Rect2(-28, -8, 56, 16), body_color)
	# Полоса-блик на верхней части корпуса
	draw_rect(Rect2(-28, -8, 56, 3), Color(body_color, 0.7).lightened(0.15))

	# === БАШНЯ ===
	draw_rect(Rect2(-12, -20, 24, 14), turret_color)
	# Люк командира
	draw_circle(Vector2(0, -14), 3.0, turret_color.darkened(0.2))

	# === СТВОЛ (ВПРАВО — зеркало enemy_tank) ===
	draw_rect(Rect2(10, -16, 22, 4), turret_color.darkened(0.1))
	# Дульный тормоз
	draw_rect(Rect2(30, -18, 4, 8), turret_color.darkened(0.15))

	# === ВСПЫШКА ВЫСТРЕЛА ===
	if muzzle_flash_timer > 0 and alive:
		var t = muzzle_flash_timer / MUZZLE_FLASH_DURATION
		var flash_pos = Vector2(36, -14)
		# Яркая вспышка
		draw_circle(flash_pos, 6.0 * t, Color(1.0, 0.85, 0.3, 0.9 * t))
		# Внешнее свечение
		draw_circle(flash_pos, 10.0 * t, Color(1.0, 0.6, 0.15, 0.3 * t))
		# Дым от выстрела
		draw_circle(flash_pos + Vector2(4, -3), 4.0 * t, Color(0.6, 0.6, 0.5, 0.25 * t))

	# === ДЫМ ===
	for p in smoke_particles:
		var t = p["age"] / p["max_age"]
		var alpha = p["alpha"] * (1.0 - t)
		var gray = randf_range(0.05, 0.2)
		draw_circle(p["pos"], p["size"], Color(gray, gray, gray, alpha))
