# scripts/game/fighter_jet.gd
# Истребитель — быстрый пролёт, сброс бомбы на скопление юнитов, уход за экран
extends Node2D

## Здоровье
@export var max_hp: int = 3
## Скорость полёта (пикселей/сек, влево)
@export var speed: float = 300.0
## Цвет фюзеляжа
@export var fuselage_color: Color = Color(0.28, 0.3, 0.32)
## Цвет крыльев
@export var wing_color: Color = Color(0.25, 0.27, 0.3)
## Цвет хвоста
@export var tail_color: Color = Color(0.22, 0.24, 0.28)

var unit_type: String = "fighter_jet"
var team: String = "enemy"
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0

# Бой
var projectiles_container: Node2D
var projectile_scenes: Dictionary = {}
var battle_manager: Node2D

# AI
var bomb_target_x: float = -1.0
var bomb_dropped: bool = false

# Визуальные эффекты
var afterburner_timer: float = 0.0
var trail_points: Array = []
const TRAIL_LENGTH: int = 40
const TRAIL_LIFETIME: float = 0.6

# Дым при повреждении
var smoke_particles: Array = []
var smoke_spawn_timer: float = 0.0

signal destroyed
signal fired_bomb(proj: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("air_units")
	add_to_group("enemy_units")
	_calculate_bomb_target()


func setup_battle(proj_container: Node2D, proj_scenes: Dictionary, manager: Node2D) -> void:
	projectiles_container = proj_container
	projectile_scenes = proj_scenes
	battle_manager = manager


func _calculate_bomb_target() -> void:
	# Находим X с наибольшей концентрацией наземных юнитов игрока
	var cluster_scores: Dictionary = {}
	var all_targets: Array = []

	for group_name in ["infantry", "player_units", "player_vehicles"]:
		for unit in get_tree().get_nodes_in_group(group_name):
			if "alive" in unit and not unit.alive:
				continue
			all_targets.append(unit.global_position.x)

	if all_targets.is_empty():
		# Нет целей — бомбим середину поля
		bomb_target_x = 500.0
		return

	# Считаем плотность в окнах по 80 пикселей
	var best_x: float = all_targets[0]
	var best_count: int = 0

	for tx in all_targets:
		var count = 0
		for ox in all_targets:
			if abs(ox - tx) < 80.0:
				count += 1
		if count > best_count:
			best_count = count
			best_x = tx

	bomb_target_x = best_x


func _process(delta: float) -> void:
	if not alive:
		_update_smoke(delta)
		_update_trail(delta)
		position.x -= speed * 0.5 * delta  # Падающий самолёт замедляется
		position.y += 60.0 * delta  # Падает
		rotation += 2.0 * delta  # Вращается
		queue_redraw()
		if position.x < -150 or position.y > 600:
			queue_free()
		return

	# Движение влево
	position.x -= speed * delta

	# Проверка попаданий ПВО
	_check_aa_hits()

	# Сброс бомбы
	if not bomb_dropped and position.x <= bomb_target_x:
		_drop_bomb()

	# Форсаж — визуальный таймер
	afterburner_timer += delta

	# Шлейф
	_update_trail(delta)

	# Дым при повреждении
	if hp < max_hp:
		_update_smoke(delta)

	queue_redraw()

	# Выход за экран
	if position.x < -150:
		queue_free()


func _drop_bomb() -> void:
	bomb_dropped = true
	shots_fired += 1

	if not projectile_scenes.has("bomb") or not projectiles_container:
		return

	var bomb = projectile_scenes["bomb"].instantiate()
	bomb.global_position = global_position + Vector2(0, 5)
	bomb.is_enemy = true
	# Бомба наследует часть горизонтальной скорости самолёта
	bomb.launch(-speed * 0.3, 0.0)
	projectiles_container.add_child(bomb)
	fired_bomb.emit(bomb)


func _check_aa_hits() -> void:
	if not alive or not projectiles_container:
		return
	for proj in projectiles_container.get_children():
		if not is_instance_valid(proj):
			continue
		# Только снаряды игрока могут попасть
		if "is_enemy" in proj and proj.is_enemy:
			continue
		var dist = proj.global_position.distance_to(global_position)
		if dist < 25.0:
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
		destroyed.emit()
		_start_death()


func _flash() -> void:
	modulate = Color(3.0, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func _start_death() -> void:
	# Самолёт продолжает лететь, но горит и падает
	fuselage_color = Color(0.15, 0.15, 0.13)
	wing_color = Color(0.12, 0.12, 0.1)
	tail_color = Color(0.1, 0.1, 0.08)
	modulate = Color.WHITE
	# Удаляем через 3 секунды в любом случае
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func(): if is_instance_valid(self): queue_free())


func _update_trail(delta: float) -> void:
	trail_points.append({"pos": global_position + Vector2(22, 2), "age": 0.0})
	if trail_points.size() > TRAIL_LENGTH:
		trail_points.pop_front()

	var i = 0
	while i < trail_points.size():
		trail_points[i]["age"] += delta
		if trail_points[i]["age"] >= TRAIL_LIFETIME:
			trail_points.remove_at(i)
		else:
			i += 1


func _update_smoke(delta: float) -> void:
	smoke_spawn_timer += delta
	if smoke_spawn_timer >= 0.08:
		smoke_spawn_timer = 0.0
		smoke_particles.append({
			"pos": Vector2(randf_range(5, 15), randf_range(-3, 3)),
			"vel": Vector2(randf_range(20, 50), randf_range(-25, -10)),
			"size": randf_range(3, 6),
			"alpha": randf_range(0.5, 0.9),
			"age": 0.0,
			"max_age": randf_range(0.8, 1.5),
		})

	var i = 0
	while i < smoke_particles.size():
		var p = smoke_particles[i]
		p["age"] += delta
		if p["age"] >= p["max_age"]:
			smoke_particles.remove_at(i)
			continue
		p["pos"] += p["vel"] * delta
		p["size"] += 6.0 * delta
		i += 1


func _draw() -> void:
	# === ШЛЕЙФ ДВИГАТЕЛЯ ===
	var count = trail_points.size()
	if count >= 2:
		for j in range(1, count):
			var t = float(j) / float(count - 1)
			var age_alpha = 1.0 - trail_points[j]["age"] / TRAIL_LIFETIME
			var alpha = t * age_alpha * 0.4
			var width = t * 4.0 * age_alpha

			var from = to_local(trail_points[j - 1]["pos"])
			var to = to_local(trail_points[j]["pos"])
			# Градиент от оранжевого (ближе к самолёту) к серому (дальний конец)
			var trail_r = lerp(0.5, 1.0, t)
			var trail_g = lerp(0.5, 0.7, t)
			var trail_b = lerp(0.5, 0.3, t)
			draw_line(from, to, Color(trail_r, trail_g, trail_b, alpha), maxf(width, 0.5))

	# === ДЫМ ===
	for p in smoke_particles:
		var t = p["age"] / p["max_age"]
		var alpha = p["alpha"] * (1.0 - t)
		var gray = 0.15
		if not alive:
			# Чёрный дым при горении
			draw_circle(p["pos"], p["size"], Color(0.05, 0.05, 0.05, alpha))
			draw_circle(p["pos"] + Vector2(1, -1), p["size"] * 0.6, Color(0.9, 0.4, 0.1, alpha * 0.5))
		else:
			draw_circle(p["pos"], p["size"], Color(gray, gray, gray, alpha))

	# === КОРПУС САМОЛЁТА ===

	# Хвостовой стабилизатор (рисуем первым — позади)
	# Вертикальный киль
	var tail_pts_vert = PackedVector2Array([
		Vector2(18, -2),
		Vector2(22, -10),
		Vector2(24, -10),
		Vector2(22, 0),
	])
	draw_colored_polygon(tail_pts_vert, tail_color)

	# Горизонтальные стабилизаторы
	var tail_pts_h_top = PackedVector2Array([
		Vector2(16, 0),
		Vector2(22, -5),
		Vector2(24, -4),
		Vector2(20, 1),
	])
	draw_colored_polygon(tail_pts_h_top, tail_color.lightened(0.05))

	var tail_pts_h_bot = PackedVector2Array([
		Vector2(16, 2),
		Vector2(22, 7),
		Vector2(24, 6),
		Vector2(20, 1),
	])
	draw_colored_polygon(tail_pts_h_bot, tail_color.lightened(0.05))

	# Фюзеляж — вытянутый ромб/обтекаемая форма
	var fuselage_pts = PackedVector2Array([
		Vector2(-22, 0),   # Нос
		Vector2(-10, -4),  # Верхний скос
		Vector2(10, -3),   # Верхняя часть
		Vector2(22, -1),   # Хвост верх
		Vector2(22, 2),    # Хвост низ
		Vector2(10, 4),    # Нижняя часть
		Vector2(-10, 3),   # Нижний скос
	])
	draw_colored_polygon(fuselage_pts, fuselage_color)

	# Блик на фюзеляже (верхняя полоса)
	draw_line(Vector2(-18, -2), Vector2(8, -2), fuselage_color.lightened(0.15), 1.5)

	# Крылья — дельтавидные, отведены назад
	# Верхнее крыло
	var wing_top_pts = PackedVector2Array([
		Vector2(-4, -3),
		Vector2(8, -3),
		Vector2(12, -16),
		Vector2(6, -14),
		Vector2(-2, -4),
	])
	draw_colored_polygon(wing_top_pts, wing_color)

	# Нижнее крыло
	var wing_bot_pts = PackedVector2Array([
		Vector2(-4, 3),
		Vector2(8, 3),
		Vector2(12, 16),
		Vector2(6, 14),
		Vector2(-2, 4),
	])
	draw_colored_polygon(wing_bot_pts, wing_color)

	# Пилон под крылом (ракеты/бомба — если не сброшена)
	if not bomb_dropped:
		draw_rect(Rect2(-2, 4, 4, 4), Color(0.35, 0.35, 0.3))
		draw_circle(Vector2(0, 9), 2.5, Color(0.4, 0.35, 0.3))

	# Кабина пилота (стеклянная)
	var canopy_pts = PackedVector2Array([
		Vector2(-16, -1),
		Vector2(-10, -4),
		Vector2(-6, -4),
		Vector2(-8, -1),
	])
	draw_colored_polygon(canopy_pts, Color(0.4, 0.55, 0.65, 0.85))
	# Блик кабины
	draw_line(Vector2(-14, -2.5), Vector2(-8, -3), Color(0.7, 0.85, 0.95, 0.5), 1.0)

	# Форсажное пламя (за хвостом)
	if alive:
		var flicker1 = randf_range(0.7, 1.0)
		var flicker2 = randf_range(0.5, 1.0)
		var flame_phase = sin(afterburner_timer * 30.0) * 0.3 + 0.7

		# Внутреннее ядро — голубовато-белое
		draw_circle(Vector2(24, 1), 3.0 * flicker1, Color(0.8, 0.85, 1.0, 0.9 * flame_phase))
		# Среднее пламя — жёлтое
		draw_circle(Vector2(27, 1), 4.0 * flicker2, Color(1.0, 0.85, 0.3, 0.6 * flame_phase))
		# Внешнее пламя — оранжевое
		draw_circle(Vector2(30, 1), 3.0 * flicker1 * flicker2, Color(1.0, 0.5, 0.15, 0.35 * flame_phase))
