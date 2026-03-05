# scripts/game/enemy_infantry.gd
# Вражеская пехота — идёт справа налево, стреляет из автомата по юнитам игрока
extends Node2D

## Здоровье
@export var max_hp: int = 2
## Скорость ходьбы (пикс/сек, влево)
@export var walk_speed: float = 30.0
## Дальность стрельбы (пиксели)
@export var fire_range: float = 250.0
## Интервал стрельбы (секунды)
@export var fire_interval: float = 1.0
## Разброс угла (градусы)
@export var spread_degrees: float = 3.0
## Сила выстрела пули
@export var fire_power: float = 800.0

var unit_type: String = "enemy_infantry"
var team: String = "enemy"
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0

# Движение
var deploy_x: float = 0.0
var deployed: bool = false
var walk_phase: float = 0.0

# Стрельба
var fire_timer: float = 0.0
var projectile_scene: PackedScene
var projectiles_container: Node2D
var target_position: Vector2 = Vector2(100, 425)

# Визуал
var skin_color: Color = Color(0.45, 0.4, 0.32)
var helmet_color: Color = Color(0.22, 0.25, 0.2)
var uniform_color: Color = Color(0.2, 0.24, 0.18)
var weapon_color: Color = Color(0.18, 0.18, 0.15)

# Вспышка выстрела
var muzzle_flash_timer: float = 0.0
const MUZZLE_FLASH_DURATION: float = 0.1

signal destroyed
signal fired_bullet(proj: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("enemy_infantry_group")
	add_to_group("enemy_units")
	fire_timer = randf_range(0.5, fire_interval)
	deploy_x = randf_range(3500.0, 5500.0)


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, _manager: Node2D) -> void:
	projectile_scene = proj_scenes["bullet"]
	projectiles_container = proj_container
	target_position = Vector2(100, 425)


func _process(delta: float) -> void:
	if not alive:
		return

	# Движение влево до позиции развёртывания
	if not deployed:
		position.x -= walk_speed * delta
		walk_phase += delta * 8.0
		if position.x <= deploy_x:
			deployed = true
			walk_phase = 0.0
		queue_redraw()
		return

	# Стрельба
	if projectile_scene and projectiles_container:
		var best_target = _find_closest_target()
		if best_target != Vector2.ZERO:
			fire_timer -= delta
			if fire_timer <= 0:
				fire_timer = fire_interval + randf_range(-0.2, 0.2)
				_fire_at(best_target)

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
	# Пуля почти горизонтально влево
	var distance = abs(target_pos.x - global_position.x)
	var elevation = remap(distance, 50.0, fire_range, 0.5, 3.0)
	var launch_angle = 180.0 - elevation

	# Разброс
	launch_angle += randf_range(-spread_degrees, spread_degrees)
	launch_angle = clampf(launch_angle, 174.0, 183.0)

	var proj = projectile_scene.instantiate()
	proj.is_enemy = true
	proj.global_position = global_position + Vector2(-18, -30)
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
	skin_color = Color(0.3, 0.28, 0.25)
	helmet_color = Color(0.15, 0.15, 0.13)
	uniform_color = Color(0.15, 0.15, 0.13)
	weapon_color = Color(0.12, 0.12, 0.1)
	modulate = Color.WHITE
	queue_redraw()
	var timer = get_tree().create_timer(10.0)
	timer.timeout.connect(queue_free)


func _draw() -> void:
	if not alive:
		# Мёртвый солдат — серый силуэт на земле
		draw_circle(Vector2(0, -5), 4.0, skin_color)
		draw_rect(Rect2(-4, -3, 8, 6), uniform_color)
		return

	# Ноги (анимация ходьбы)
	if not deployed:
		var leg_offset = sin(walk_phase) * 3.0
		draw_line(Vector2(-2, -8), Vector2(-4 + leg_offset, 0), uniform_color, 2.0)
		draw_line(Vector2(2, -8), Vector2(4 - leg_offset, 0), uniform_color, 2.0)
	else:
		# Стоячая поза
		draw_line(Vector2(-2, -8), Vector2(-3, 0), uniform_color, 2.0)
		draw_line(Vector2(2, -8), Vector2(3, 0), uniform_color, 2.0)

	# Тело (тёмная форма)
	draw_rect(Rect2(-5, -22, 10, 14), uniform_color)

	# Голова
	draw_circle(Vector2(0, -28), 5.0, skin_color)

	# Каска (тёмная)
	draw_arc(Vector2(0, -30), 6.0, PI, TAU, 12, helmet_color, 2.5)

	# Винтовка (влево — враг стреляет налево)
	draw_line(Vector2(-3, -20), Vector2(-22, -26), weapon_color, 2.5)
	# Приклад
	draw_line(Vector2(-3, -18), Vector2(2, -15), weapon_color, 2.0)

	# Вспышка выстрела (слева от дула)
	if muzzle_flash_timer > 0:
		var t = muzzle_flash_timer / MUZZLE_FLASH_DURATION
		var flash_pos = Vector2(-24, -27)
		draw_circle(flash_pos, 3.5 * t, Color(1.0, 0.9, 0.3, 0.9 * t))
		draw_circle(flash_pos + Vector2(-2, 0), 2.0 * t, Color(1.0, 0.7, 0.2, 0.6 * t))
