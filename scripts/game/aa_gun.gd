# scripts/game/aa_gun.gd
# Зенитная установка — стационарная, стреляет пулями по воздушным целям
extends Node2D

## Здоровье
@export var max_hp: int = 4
## Дальность стрельбы (2D расстояние до воздушной цели)
@export var fire_range: float = 450.0
## Интервал стрельбы (секунды)
@export var fire_interval: float = 0.4
## Разброс угла (градусы)
@export var spread_degrees: float = 5.0

var unit_type: String = "aa_gun"
var team: String = "player"
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0

# Стрельба
var fire_timer: float = 0.0
var projectiles_container: Node2D
var projectile_scenes: Dictionary = {}
var battle_manager: Node2D

# Ствол отслеживает цель
var gun_angle: float = -PI / 2  # По умолчанию: вверх
var current_target: Node2D = null

# Визуальные цвета
var bag_color: Color = Color(0.6, 0.5, 0.3)
var bag_color2: Color = Color(0.55, 0.45, 0.28)
var mount_color: Color = Color(0.2, 0.2, 0.18)
var barrel_color: Color = Color(0.15, 0.15, 0.13)
var ammo_box_color: Color = Color(0.25, 0.25, 0.2)

# Вспышка выстрела
var muzzle_flash_timer: float = 0.0
const MUZZLE_FLASH_DURATION: float = 0.08
var manually_controlled: bool = false
var can_move: bool = false  # AA Gun is stationary
var min_fire_angle: float = -10.0
var max_fire_angle: float = 170.0
signal destroyed
signal fired_bullet(proj: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("player_units")
	add_to_group("anti_air_units")
	fire_timer = 0.5


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, manager: Node2D) -> void:
	projectiles_container = proj_container
	projectile_scenes = proj_scenes
	battle_manager = manager


func _process(delta: float) -> void:
	if not alive:
		return

	if not manually_controlled:
		current_target = _find_air_target()

		if current_target:
			var to_target = current_target.global_position - global_position
			gun_angle = to_target.angle()
		else:
			gun_angle = lerp_angle(gun_angle, -PI / 2, delta * 2.0)

		fire_timer -= delta
		if fire_timer <= 0:
			fire_timer = fire_interval + randf_range(-0.05, 0.05)
			_try_fire()
	else:
		if fire_timer > 0:
			fire_timer -= delta

	if muzzle_flash_timer > 0:
		muzzle_flash_timer -= delta

	queue_redraw()


func _find_air_target() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = fire_range

	for unit in get_tree().get_nodes_in_group("air_units"):
		if "alive" in unit and not unit.alive:
			continue
		var dist = global_position.distance_to(unit.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = unit

	return closest


func _try_fire() -> void:
	if not projectile_scenes.has("bullet") or not projectiles_container:
		return

	if not current_target:
		return

	# Направление к цели
	var to_target = (current_target.global_position - global_position).normalized()
	var angle = rad_to_deg(atan2(-to_target.y, to_target.x))
	angle += randf_range(-spread_degrees, spread_degrees)

	var barrel_len = 20.0
	var barrel_dir = Vector2(cos(gun_angle), sin(gun_angle))
	var launch_pos = global_position + Vector2(0, -30) + barrel_dir * barrel_len

	var bullet_scene = projectile_scenes["bullet"]
	var proj = bullet_scene.instantiate()
	proj.global_position = launch_pos
	proj.launch(angle, 800.0)
	projectiles_container.add_child(proj)
	fired_bullet.emit(proj)
	shots_fired += 1

	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()


func is_auto_fire() -> bool:
	return true


func manual_aim_at(target_pos: Vector2) -> void:
	if not alive:
		return
	var to_target = target_pos - global_position
	gun_angle = to_target.angle()
	queue_redraw()


func manual_fire_at(target_pos: Vector2) -> bool:
	if not alive:
		return false
	if fire_timer > 0:
		return false
	if not projectile_scenes.has("bullet") or not projectiles_container:
		return false

	var to_target = (target_pos - global_position).normalized()
	var angle = rad_to_deg(atan2(-to_target.y, to_target.x))
	angle += randf_range(-spread_degrees, spread_degrees)

	var barrel_dir = Vector2(cos(gun_angle), sin(gun_angle))
	var launch_pos = global_position + Vector2(0, -30) + barrel_dir * 20.0

	var bullet_scene = projectile_scenes["bullet"]
	var proj = bullet_scene.instantiate()
	proj.global_position = launch_pos
	proj.launch(angle, 800.0)
	projectiles_container.add_child(proj)
	fired_bullet.emit(proj)
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
	bag_color = Color(0.3, 0.28, 0.25)
	bag_color2 = Color(0.28, 0.25, 0.22)
	mount_color = Color(0.12, 0.12, 0.1)
	barrel_color = Color(0.1, 0.1, 0.08)
	ammo_box_color = Color(0.15, 0.15, 0.12)
	modulate = Color.WHITE
	queue_redraw()
	var timer = get_tree().create_timer(10.0)
	timer.timeout.connect(queue_free)


func _draw() -> void:
	# === Мешки с песком (база) ===
	var bag_w = 16.0
	var bag_h = 10.0
	var base_y = -bag_h

	# Нижний ряд (3 мешка)
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

	# === Крепление орудия (прямоугольник поверх мешков) ===
	var mount_y = top_y - 6
	draw_rect(Rect2(-8, mount_y, 16, 6), mount_color)
	draw_rect(Rect2(-8, mount_y, 16, 6), mount_color.darkened(0.3), false, 1.0)

	# === Ящик с боеприпасами (сбоку) ===
	draw_rect(Rect2(12, top_y - 4, 10, 8), ammo_box_color)
	draw_rect(Rect2(12, top_y - 4, 10, 8), ammo_box_color.darkened(0.3), false, 1.0)
	# Детали на ящике
	draw_line(Vector2(14, top_y - 2), Vector2(20, top_y - 2), ammo_box_color.lightened(0.15), 1.0)

	# === Спаренные стволы (вращаются) ===
	var pivot = Vector2(0, mount_y)
	var barrel_dir = Vector2(cos(gun_angle), sin(gun_angle))
	var barrel_perp = Vector2(-barrel_dir.y, barrel_dir.x)  # Перпендикуляр
	var barrel_len = 22.0
	var barrel_spacing = 2.5

	# Два параллельных ствола
	var barrel1_start = pivot + barrel_perp * barrel_spacing
	var barrel1_end = barrel1_start + barrel_dir * barrel_len
	var barrel2_start = pivot - barrel_perp * barrel_spacing
	var barrel2_end = barrel2_start + barrel_dir * barrel_len

	draw_line(barrel1_start, barrel1_end, barrel_color, 2.5)
	draw_line(barrel2_start, barrel2_end, barrel_color, 2.5)

	# Дульные тормоза на концах стволов
	var brake_size = 3.0
	draw_circle(barrel1_end, brake_size, barrel_color.lightened(0.1))
	draw_circle(barrel2_end, brake_size, barrel_color.lightened(0.1))

	# Основание вращения (круг)
	draw_circle(pivot, 4.0, mount_color.lightened(0.05))

	# === Вспышка выстрела ===
	if muzzle_flash_timer > 0:
		var t = muzzle_flash_timer / MUZZLE_FLASH_DURATION
		# Вспышка на конце каждого ствола
		draw_circle(barrel1_end, 5.0 * t, Color(1.0, 0.95, 0.5, 0.95 * t))
		draw_circle(barrel2_end, 5.0 * t, Color(1.0, 0.95, 0.5, 0.95 * t))
		# Внешнее свечение
		var mid_flash = (barrel1_end + barrel2_end) / 2.0
		draw_circle(mid_flash, 8.0 * t, Color(1.0, 0.7, 0.2, 0.4 * t))
