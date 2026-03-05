# scripts/game/enemy_apc.gd
# Вражеский БТР — едет слева, стреляет из пулемёта, при уничтожении высаживает пехоту
extends StaticBody2D

## Здоровье
@export var max_hp: int = 6
## Скорость движения (пикс/сек, влево)
@export var drive_speed: float = 40.0
## Дальность стрельбы пулемёта (пиксели)
@export var fire_range: float = 200.0
## Интервал стрельбы (секунды)
@export var fire_interval: float = 0.5
## Разброс угла (градусы)
@export var spread_degrees: float = 4.0
## Сила выстрела пули
@export var fire_power: float = 800.0
## Время дыма после уничтожения (секунды)
@export var smoke_duration: float = 60.0

var unit_type: String = "enemy_apc"
var team: String = "enemy"
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0

# Движение
var deploy_x: float = 0.0
var deployed: bool = false
var infantry_spawned: bool = false

# Стрельба
var fire_timer: float = 0.0
var projectile_scene: PackedScene
var projectiles_container: Node2D
var target_position: Vector2 = Vector2(100, 425)

# Дым и смерть
var smoking: bool = false
var smoke_timer: float = 0.0
var smoke_particles: Array = []
var smoke_spawn_timer: float = 0.0

# Визуал
var body_color: Color = Color(0.28, 0.32, 0.25)
var body_dark: Color = Color(0.22, 0.26, 0.2)
var wheel_color: Color = Color(0.15, 0.15, 0.13)
var turret_color: Color = Color(0.25, 0.28, 0.22)
var slit_color: Color = Color(0.12, 0.15, 0.1)

# Вспышка выстрела
var muzzle_flash_timer: float = 0.0
const MUZZLE_FLASH_DURATION: float = 0.08

signal destroyed
signal fired_bullet(proj: Node2D)
signal spawn_units(unit_type: String, positions: Array, team: String)


func _ready() -> void:
	hp = max_hp
	add_to_group("enemy_tanks")
	add_to_group("enemy_units")
	fire_timer = randf_range(0.5, fire_interval)
	deploy_x = randf_range(2500.0, 4500.0)


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, _manager: Node2D) -> void:
	projectile_scene = proj_scenes["bullet"]
	projectiles_container = proj_container
	target_position = Vector2(100, 425)


func _process(delta: float) -> void:
	if alive:
		# Движение влево до позиции развёртывания
		if not deployed:
			position.x -= drive_speed * delta
			if position.x <= deploy_x:
				deployed = true
				# Высадка пехоты при прибытии
				if not infantry_spawned:
					infantry_spawned = true
					var spawn_pos = [global_position + Vector2(-20, 2), global_position + Vector2(20, 2)]
					spawn_units.emit("enemy_infantry", spawn_pos, "enemy")

		# Стрельба из пулемёта
		if projectile_scene and projectiles_container:
			var best_target = _find_closest_target()
			if best_target != Vector2.ZERO:
				fire_timer -= delta
				if fire_timer <= 0:
					fire_timer = fire_interval + randf_range(-0.1, 0.1)
					_fire_at(best_target)

	# Дым после уничтожения
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

	if muzzle_flash_timer > 0:
		muzzle_flash_timer -= delta
		queue_redraw()


func _find_closest_target() -> Vector2:
	var best_pos = Vector2.ZERO
	var best_dist = fire_range

	# Проверяем мортиру (база игрока)
	var dist_to_base = abs(target_position.x - global_position.x)
	if dist_to_base <= fire_range:
		best_dist = dist_to_base
		best_pos = target_position

	# Проверяем пехоту игрока
	for unit in get_tree().get_nodes_in_group("infantry"):
		if not unit.alive:
			continue
		var dist = abs(unit.global_position.x - global_position.x)
		if dist < best_dist:
			best_dist = dist
			best_pos = unit.global_position

	# Проверяем юниты игрока
	for unit in get_tree().get_nodes_in_group("player_units"):
		if not unit.alive:
			continue
		var dist = abs(unit.global_position.x - global_position.x)
		if dist < best_dist:
			best_dist = dist
			best_pos = unit.global_position

	# Проверяем технику игрока
	for unit in get_tree().get_nodes_in_group("player_vehicles"):
		if not unit.alive:
			continue
		var dist = abs(unit.global_position.x - global_position.x)
		if dist < best_dist:
			best_dist = dist
			best_pos = unit.global_position

	return best_pos


func _fire_at(target_pos: Vector2) -> void:
	var distance = abs(target_pos.x - global_position.x)
	var elevation = remap(distance, 50.0, fire_range, 0.5, 3.0)
	var launch_angle = 180.0 - elevation

	# Разброс
	launch_angle += randf_range(-spread_degrees, spread_degrees)
	launch_angle = clampf(launch_angle, 174.0, 183.0)

	var proj = projectile_scene.instantiate()
	proj.is_enemy = true
	proj.global_position = global_position + Vector2(-38, -18)
	proj.launch(launch_angle, fire_power)
	projectiles_container.add_child(proj)
	fired_bullet.emit(proj)
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

	# Высадка пехоты при уничтожении (если ещё не высадили)
	if not infantry_spawned:
		infantry_spawned = true
		var spawn_pos = [global_position + Vector2(-20, 2), global_position + Vector2(20, 2)]
		spawn_units.emit("enemy_infantry", spawn_pos, "enemy")

	# Серые руины
	body_color = Color(0.18, 0.18, 0.16)
	body_dark = Color(0.14, 0.14, 0.12)
	wheel_color = Color(0.1, 0.1, 0.08)
	turret_color = Color(0.15, 0.15, 0.13)
	slit_color = Color(0.08, 0.08, 0.06)
	modulate = Color.WHITE
	smoking = true
	smoke_timer = 0.0
	queue_redraw()


func _spawn_smoke() -> void:
	smoke_particles.append({
		"pos": Vector2(randf_range(-15, 15), -16),
		"vel": Vector2(randf_range(-8, 8), randf_range(-40, -20)),
		"size": randf_range(4, 8),
		"alpha": randf_range(0.5, 0.8),
		"age": 0.0,
		"max_age": randf_range(2.0, 4.0),
	})


func _draw() -> void:
	# === Колёса (6 штук) ===
	for i in range(6):
		var wx = -30.0 + i * 12.0
		draw_circle(Vector2(wx, 10), 5.0, wheel_color)
		draw_circle(Vector2(wx, 10), 2.5, Color(wheel_color).lightened(0.15) if alive else Color(0.08, 0.08, 0.06))

	# === Корпус — широкий прямоугольник ===
	draw_rect(Rect2(-35, -8, 70, 20), body_color)

	# Верхняя часть корпуса (чуть светлее)
	draw_rect(Rect2(-35, -8, 70, 4), Color(body_color).lightened(0.1))

	# Скос спереди (левая сторона = перед для врага)
	var front_points = PackedVector2Array([
		Vector2(-35, -8),
		Vector2(-42, 4),
		Vector2(-35, 12),
		Vector2(-35, -8),
	])
	draw_colored_polygon(front_points, body_dark)

	# Скос сзади
	var rear_points = PackedVector2Array([
		Vector2(35, -8),
		Vector2(38, 0),
		Vector2(35, 12),
		Vector2(35, -8),
	])
	draw_colored_polygon(rear_points, body_dark)

	# === Смотровые щели (3 штуки на боковой стороне) ===
	for i in range(3):
		var sx = -18.0 + i * 16.0
		draw_rect(Rect2(sx, -4, 10, 3), slit_color)

	# === Башенка с пулемётом ===
	# Маленькая башенка сверху
	draw_rect(Rect2(-8, -16, 16, 8), turret_color)
	draw_rect(Rect2(-8, -16, 16, 2), Color(turret_color).lightened(0.1))

	# Ствол пулемёта (влево)
	draw_line(Vector2(-8, -12), Vector2(-40, -14), turret_color.darkened(0.15), 2.0)
	# Дульный тормоз
	draw_rect(Rect2(-42, -16, 4, 6), turret_color.darkened(0.2))

	# === Вспышка выстрела ===
	if muzzle_flash_timer > 0:
		var t = muzzle_flash_timer / MUZZLE_FLASH_DURATION
		var flash_pos = Vector2(-44, -13)
		draw_circle(flash_pos, 3.0 * t, Color(1.0, 0.9, 0.3, 0.9 * t))
		draw_circle(flash_pos + Vector2(-2, -1), 2.0 * t, Color(1.0, 0.7, 0.2, 0.6 * t))

	# === Дым ===
	for p in smoke_particles:
		var t = p["age"] / p["max_age"]
		var alpha = p["alpha"] * (1.0 - t)
		var gray = randf_range(0.05, 0.2)
		draw_circle(p["pos"], p["size"], Color(gray, gray, gray, alpha))
