# scripts/game/enemy_tank.gd
extends StaticBody2D

## Здоровье танка
@export var max_hp: int = 3
## Скорость движения (пикс/сек, влево)
@export var speed: float = 20.0
## Интервал стрельбы (секунды)
@export var fire_interval: float = 4.0
## Разброс угла (градусы)
@export var spread_degrees: float = 6.0
## Разброс силы (процент)
@export var spread_power: float = 0.1
## Сила выстрела (px/s — высокая для пологих снарядов)
@export var fire_power: float = 900.0
## Дальность атаки для визуализации (px)
@export var fire_range: float = 500.0
## Цвет корпуса
@export var body_color: Color = Color(0.35, 0.4, 0.3)
## Цвет гусениц
@export var track_color: Color = Color(0.2, 0.2, 0.18)
## Цвет башни
@export var turret_color: Color = Color(0.3, 0.35, 0.25)
## Время дыма после уничтожения (секунды)
@export var smoke_duration: float = 60.0

var hp: int
var alive: bool = true
var smoking: bool = false
var smoke_timer: float = 0.0

# Стрельба
var fire_timer: float = 0.0
var projectile_scene: PackedScene
var target_position: Vector2
var projectiles_container: Node2D

# Частицы дыма
var smoke_particles: Array = []
var smoke_spawn_timer: float = 0.0

signal destroyed
signal fired_projectile(proj: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("enemy_tanks")
	fire_timer = randf_range(1.0, fire_interval)


func setup_firing(proj_scene: PackedScene, target_pos: Vector2, container: Node2D) -> void:
	projectile_scene = proj_scene
	target_position = target_pos
	projectiles_container = container


func _process(delta: float) -> void:
	if alive:
		position.x -= speed * delta

		# Стрельба
		if projectile_scene and projectiles_container:
			fire_timer -= delta
			if fire_timer <= 0:
				fire_timer = fire_interval + randf_range(-0.5, 0.5)
				_fire()

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


func _fire() -> void:
	var distance = abs(target_position.x - global_position.x)
	var gravity = 120.0  # Пониженная гравитация для пологих снарядов

	# Рассчитываем угол для параболической траектории
	var power = fire_power + fire_power * randf_range(-spread_power, spread_power)
	var sin_2phi = distance * gravity / (power * power)
	sin_2phi = clampf(sin_2phi, 0.0, 1.0)
	var phi_deg = rad_to_deg(0.5 * asin(sin_2phi))

	# Добавляем разброс
	phi_deg += randf_range(-spread_degrees, spread_degrees)
	phi_deg = clampf(phi_deg, 3.0, 35.0)  # Максимум 35° — танки стреляют пологo

	# Угол для стрельбы влево (180 - elevation)
	var launch_angle = 180.0 - phi_deg

	var proj = projectile_scene.instantiate()
	proj.is_enemy = true
	# Танковые снаряды — пологие и быстрые
	proj.gravity_force = 120.0
	proj.air_drag = 0.08
	proj.trail_color = Color(0.95, 0.85, 0.5)
	proj.global_position = global_position + Vector2(-34, -16)
	proj.launch(launch_angle, power)
	projectiles_container.add_child(proj)
	fired_projectile.emit(proj)


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
	# Гусеницы
	draw_rect(Rect2(-30, 5, 60, 12), track_color)
	for i in range(5):
		var wx = -24.0 + i * 12.0
		draw_circle(Vector2(wx, 11), 4.0, Color(0.15, 0.15, 0.13) if alive else Color(0.1, 0.1, 0.08))
		draw_circle(Vector2(wx, 11), 2.0, Color(0.25, 0.25, 0.22) if alive else Color(0.13, 0.13, 0.11))

	# Корпус
	draw_rect(Rect2(-28, -8, 56, 16), body_color)
	draw_rect(Rect2(-28, -8, 56, 3), Color(body_color, 0.7).lightened(0.15))

	# Башня
	draw_rect(Rect2(-12, -20, 24, 14), turret_color)
	draw_circle(Vector2(0, -14), 3.0, turret_color.darkened(0.2))

	# Ствол (влево)
	draw_rect(Rect2(-32, -16, 22, 4), turret_color.darkened(0.1))
	draw_rect(Rect2(-34, -18, 4, 8), turret_color.darkened(0.15))

	# Дым
	for p in smoke_particles:
		var t = p["age"] / p["max_age"]
		var alpha = p["alpha"] * (1.0 - t)
		var gray = randf_range(0.05, 0.2)
		draw_circle(p["pos"], p["size"], Color(gray, gray, gray, alpha))
