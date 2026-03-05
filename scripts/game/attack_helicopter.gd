# scripts/game/attack_helicopter.gd
# Ударный вертолёт — летит к позиции, зависает, обстреливает ракетами
extends Node2D

## Здоровье
@export var max_hp: int = 5
## Скорость полёта (пикселей/сек)
@export var speed: float = 60.0
## Скорость отступления (пикселей/сек)
@export var retreat_speed: float = 80.0
## HP для начала отступления
@export var retreat_hp: int = 2
## Интервал стрельбы (секунды)
@export var fire_interval: float = 2.0
## Дальность стрельбы (горизонтальная, пиксели)
@export var fire_range: float = 350.0
## Цвет фюзеляжа
@export var fuselage_color: Color = Color(0.28, 0.32, 0.22)
## Цвет кабины
@export var cockpit_color: Color = Color(0.4, 0.55, 0.42)
## Цвет хвостовой балки
@export var tail_color: Color = Color(0.25, 0.3, 0.2)

var unit_type: String = "attack_helicopter"
var team: String = "enemy"
var min_fire_angle: float = -165.0
var max_fire_angle: float = -15.0
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0

# Бой
var projectiles_container: Node2D
var projectile_scenes: Dictionary = {}
var battle_manager: Node2D

# AI: состояния
enum State { APPROACH, HOVER, RETREAT, DEAD }
var state: int = State.APPROACH
var hover_x: float = 0.0
var fire_timer: float = 0.0

# Визуальные эффекты
var rotor_angle: float = 0.0
var tail_rotor_angle: float = 0.0
var hover_time: float = 0.0
var muzzle_flash_timer: float = 0.0
const MUZZLE_FLASH_DURATION: float = 0.2

# Дым при повреждении
var smoke_particles: Array = []
var smoke_spawn_timer: float = 0.0

signal destroyed
signal fired_rocket(proj: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("air_units")
	add_to_group("enemy_units")
	hover_x = randf_range(2000.0, 4500.0)
	fire_timer = randf_range(0.5, fire_interval)


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, manager: Node2D) -> void:
	projectiles_container = proj_container
	projectile_scenes = proj_scenes
	battle_manager = manager


func _process(delta: float) -> void:
	# Ротор всегда крутится (даже у мёртвого — замедляясь)
	if alive:
		rotor_angle += 15.0 * delta
		tail_rotor_angle += 25.0 * delta
	else:
		rotor_angle += 5.0 * delta  # Замедленный ротор
		tail_rotor_angle += 8.0 * delta

	if rotor_angle > TAU:
		rotor_angle -= TAU
	if tail_rotor_angle > TAU:
		tail_rotor_angle -= TAU

	match state:
		State.APPROACH:
			_process_approach(delta)
		State.HOVER:
			_process_hover(delta)
		State.RETREAT:
			_process_retreat(delta)
		State.DEAD:
			_process_dead(delta)

	# ПВО
	if alive:
		_check_aa_hits()

	# Дым
	if alive and hp < max_hp:
		_update_smoke(delta)
	elif not alive:
		_update_smoke(delta)

	queue_redraw()


func _process_approach(delta: float) -> void:
	position.x -= speed * delta

	if position.x <= hover_x:
		position.x = hover_x
		state = State.HOVER
		hover_time = 0.0


func _process_hover(delta: float) -> void:
	hover_time += delta

	# Плавное покачивание
	position.y += sin(hover_time * 2.0) * 0.5

	# Стрельба
	fire_timer -= delta
	if fire_timer <= 0:
		fire_timer = fire_interval + randf_range(-0.3, 0.3)
		_try_fire()

	# Проверяем: нужно отступить?
	if hp <= retreat_hp:
		state = State.RETREAT


func _process_retreat(delta: float) -> void:
	position.x += retreat_speed * delta

	if position.x > 6600:
		queue_free()


func _process_dead(delta: float) -> void:
	# Падает и вращается
	position.y += 80.0 * delta
	position.x -= 20.0 * delta
	rotation += 1.5 * delta

	if position.y > 600:
		queue_free()


func _try_fire() -> void:
	if not projectile_scenes.has("rocket") or not projectiles_container:
		return

	var target = _find_ground_target()
	if not target:
		return

	var target_pos = target.global_position

	# Рассчитываем параметры ракеты вниз-влево
	var to_target = target_pos - global_position
	var angle_rad = atan2(-to_target.y, to_target.x)
	var angle_deg = rad_to_deg(angle_rad)

	# Ограничиваем: ракета должна лететь вниз (отрицательный угол = вниз)
	angle_deg = clampf(angle_deg, -75.0, -15.0)

	var rocket = projectile_scenes["rocket"].instantiate()
	rocket.global_position = global_position + Vector2(-10, 8)
	rocket.is_enemy = true
	# Вертолётная ракета — средняя скорость, умеренная гравитация
	rocket.booster_speed = 180.0
	rocket.sustainer_accel = 400.0
	rocket.max_speed = 350.0
	rocket.gravity_force = 60.0
	rocket.smoke_color = Color(0.6, 0.6, 0.55)
	rocket.launch(angle_deg)
	projectiles_container.add_child(rocket)
	fired_rocket.emit(rocket)
	shots_fired += 1

	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()


func _find_ground_target() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = fire_range

	# Приоритет: пехота, потом юниты, потом техника
	for group_name in ["infantry", "player_units", "player_vehicles"]:
		for unit in get_tree().get_nodes_in_group(group_name):
			if "alive" in unit and not unit.alive:
				continue
			var dx = abs(unit.global_position.x - global_position.x)
			if dx < closest_dist:
				closest_dist = dx
				closest = unit

	return closest


func _check_aa_hits() -> void:
	if not alive or not projectiles_container:
		return
	for proj in projectiles_container.get_children():
		if not is_instance_valid(proj):
			continue
		if "is_enemy" in proj and proj.is_enemy:
			continue
		var dist = proj.global_position.distance_to(global_position)
		if dist < 28.0:  # Вертолёт крупнее — чуть больший хитбокс
			take_damage(2)
			proj.queue_free()
			break


func take_damage(amount: int = 1) -> void:
	if not alive:
		return
	hp -= amount
	_flash()
	if hp <= 0:
		alive = false
		state = State.DEAD
		destroyed.emit()
		_start_death()
	elif hp <= retreat_hp and state == State.HOVER:
		state = State.RETREAT


func _flash() -> void:
	modulate = Color(3.0, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func _start_death() -> void:
	fuselage_color = Color(0.15, 0.15, 0.12)
	cockpit_color = Color(0.2, 0.2, 0.18)
	tail_color = Color(0.12, 0.12, 0.1)
	modulate = Color.WHITE
	# Удаляем через 4 секунды в любом случае
	var timer = get_tree().create_timer(4.0)
	timer.timeout.connect(func(): if is_instance_valid(self): queue_free())


func _update_smoke(delta: float) -> void:
	smoke_spawn_timer += delta
	var interval = 0.06 if not alive else 0.12
	if smoke_spawn_timer >= interval:
		smoke_spawn_timer = 0.0
		smoke_particles.append({
			"pos": Vector2(randf_range(-5, 10), randf_range(-5, 5)),
			"vel": Vector2(randf_range(10, 30), randf_range(-30, -15)),
			"size": randf_range(3, 6),
			"alpha": randf_range(0.5, 0.9),
			"age": 0.0,
			"max_age": randf_range(0.8, 1.8),
		})

	var i = 0
	while i < smoke_particles.size():
		var p = smoke_particles[i]
		p["age"] += delta
		if p["age"] >= p["max_age"]:
			smoke_particles.remove_at(i)
			continue
		p["pos"] += p["vel"] * delta
		p["size"] += 5.0 * delta
		i += 1


func _draw() -> void:
	# === ДЫМ (рисуем позади всего) ===
	for p in smoke_particles:
		var t = p["age"] / p["max_age"]
		var alpha = p["alpha"] * (1.0 - t)
		if not alive:
			draw_circle(p["pos"], p["size"], Color(0.05, 0.05, 0.05, alpha))
			draw_circle(p["pos"] + Vector2(1, -1), p["size"] * 0.5, Color(0.85, 0.35, 0.1, alpha * 0.4))
		else:
			var gray = 0.18
			draw_circle(p["pos"], p["size"], Color(gray, gray, gray, alpha))

	# === ХВОСТОВАЯ БАЛКА ===
	# Тонкая балка вправо от фюзеляжа
	draw_rect(Rect2(10, -2, 28, 4), tail_color)
	# Коническое сужение
	draw_line(Vector2(10, -2), Vector2(38, -1), tail_color.lightened(0.1), 1.0)

	# Хвостовой ротор (вертикальная линия, вращающаяся)
	var tr_len = 8.0
	var tr_x = 38.0
	var tr_y = -1.0
	var tr_dx = cos(tail_rotor_angle) * 0.5  # Видимая часть (перспектива)
	var tr_dy = sin(tail_rotor_angle) * tr_len * 0.5
	draw_line(Vector2(tr_x + tr_dx, tr_y - tr_dy), Vector2(tr_x - tr_dx, tr_y + tr_dy),
		Color(0.5, 0.5, 0.45, 0.7), 1.5)

	# Хвостовой стабилизатор
	var stab_pts = PackedVector2Array([
		Vector2(34, -2),
		Vector2(40, -8),
		Vector2(42, -7),
		Vector2(38, -1),
	])
	draw_colored_polygon(stab_pts, tail_color.lightened(0.05))

	# === ФЮЗЕЛЯЖ ===
	# Основное тело — скруглённый прямоугольник (рисуем полигоном)
	var body_pts = PackedVector2Array([
		Vector2(-18, -2),   # Нос верх
		Vector2(-22, 2),    # Нос низ (скос вниз)
		Vector2(-20, 6),    # Подбородок
		Vector2(-8, 8),     # Низ передний
		Vector2(12, 6),     # Низ задний
		Vector2(14, 2),     # Зад низ
		Vector2(14, -2),    # Зад верх
		Vector2(8, -6),     # Верх задний
		Vector2(-8, -6),    # Верх передний
		Vector2(-16, -4),   # Верх-нос
	])
	draw_colored_polygon(body_pts, fuselage_color)

	# Блик на фюзеляже
	draw_line(Vector2(-14, -4), Vector2(6, -5), fuselage_color.lightened(0.15), 1.5)

	# === КАБИНА (стеклянный пузырь) ===
	var canopy_pts = PackedVector2Array([
		Vector2(-20, -1),
		Vector2(-22, 3),
		Vector2(-18, 5),
		Vector2(-12, 4),
		Vector2(-10, -2),
		Vector2(-14, -3),
	])
	draw_colored_polygon(canopy_pts, cockpit_color)
	# Блик стекла
	draw_line(Vector2(-19, 0), Vector2(-13, -1), Color(0.65, 0.8, 0.7, 0.5), 1.5)

	# === РАКЕТНЫЕ ПОДВЕСЫ (под фюзеляжем) ===
	# Левый пилон
	draw_rect(Rect2(-8, 8, 3, 4), Color(0.3, 0.3, 0.25))
	# Ракетные трубы
	draw_rect(Rect2(-10, 10, 7, 3), Color(0.22, 0.24, 0.2))
	draw_circle(Vector2(-10, 11.5), 1.5, Color(0.18, 0.18, 0.15))

	# Правый пилон
	draw_rect(Rect2(2, 8, 3, 4), Color(0.3, 0.3, 0.25))
	draw_rect(Rect2(0, 10, 7, 3), Color(0.22, 0.24, 0.2))
	draw_circle(Vector2(0, 11.5), 1.5, Color(0.18, 0.18, 0.15))

	# === ГЛАВНЫЙ РОТОР ===
	# Ось ротора
	draw_rect(Rect2(-1, -8, 2, 3), Color(0.35, 0.35, 0.3))

	# Лопасти — две линии через центр, вращающиеся
	var rotor_len = 32.0
	var rotor_cx = 0.0
	var rotor_cy = -9.0

	# Лопасть 1
	var r1_dx = cos(rotor_angle) * rotor_len
	var r1_dy = sin(rotor_angle) * rotor_len * 0.15  # Перспективное сплющивание (вид сбоку)
	draw_line(
		Vector2(rotor_cx - r1_dx, rotor_cy - r1_dy),
		Vector2(rotor_cx + r1_dx, rotor_cy + r1_dy),
		Color(0.4, 0.42, 0.38, 0.75), 2.0
	)

	# Лопасть 2 (перпендикулярна первой)
	var r2_dx = cos(rotor_angle + PI * 0.5) * rotor_len
	var r2_dy = sin(rotor_angle + PI * 0.5) * rotor_len * 0.15
	draw_line(
		Vector2(rotor_cx - r2_dx, rotor_cy - r2_dy),
		Vector2(rotor_cx + r2_dx, rotor_cy + r2_dy),
		Color(0.4, 0.42, 0.38, 0.65), 2.0
	)

	# Диск ротора (полупрозрачный круг для эффекта вращения)
	draw_circle(Vector2(rotor_cx, rotor_cy), rotor_len * 0.4, Color(0.5, 0.52, 0.48, 0.08))

	# === ВСПЫШКА ВЫСТРЕЛА ===
	if muzzle_flash_timer > 0 and alive:
		var t = muzzle_flash_timer / MUZZLE_FLASH_DURATION
		var flash_pos = Vector2(-12, 10)
		draw_circle(flash_pos, 4.0 * t, Color(1.0, 0.8, 0.3, 0.85 * t))
		draw_circle(flash_pos + Vector2(0, 3), 3.0 * t, Color(1.0, 0.6, 0.15, 0.5 * t))

	# === ОГНИ (если жив) ===
	if alive:
		# Навигационный красный огонь на хвосте
		var blink = fmod(hover_time * 2.0, 1.0) < 0.5 if state == State.HOVER else true
		if blink:
			draw_circle(Vector2(38, -3), 1.5, Color(1.0, 0.15, 0.1, 0.8))
