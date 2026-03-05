# scripts/game/manpads.gd
# Солдат с ПЗРК — идёт пешком, затем разворачивается и стреляет зенитными ракетами
extends Node2D

## Здоровье
@export var max_hp: int = 2
## Скорость ходьбы (пикселей/сек)
@export var walk_speed: float = 30.0
## Дальность стрельбы (2D расстояние до воздушной цели)
@export var fire_range: float = 400.0
## Интервал стрельбы (секунды)
@export var fire_interval: float = 5.0
## Разброс угла (градусы)
@export var spread_degrees: float = 3.0

var unit_type: String = "manpads"
var team: String = "player"
var hp: int
var alive: bool = true
var shots_fired: int = 0
var shots_hit: int = 0

# Ходьба
var deployed: bool = false
var deploy_x: float = 0.0
var walk_timer: float = 0.0  # анимация ног

# Стрельба
var fire_timer: float = 0.0
var projectiles_container: Node2D
var projectile_scenes: Dictionary = {}
var battle_manager: Node2D

# Визуальные цвета
var uniform_color: Color = Color(0.3, 0.35, 0.25)
var skin_color: Color = Color(0.55, 0.5, 0.4)
var helmet_color: Color = Color(0.3, 0.35, 0.25)
var tube_color: Color = Color(0.28, 0.3, 0.25)
var tube_tip_color: Color = Color(0.35, 0.33, 0.28)

# Вспышка/выхлоп при пуске
var backblast_timer: float = 0.0
const BACKBLAST_DURATION: float = 0.4

signal destroyed
signal fired_missile(proj: Node2D)


func _ready() -> void:
	hp = max_hp
	add_to_group("player_units")
	add_to_group("infantry")
	add_to_group("anti_air_units")
	deploy_x = randf_range(80.0, 1750.0)
	fire_timer = 1.5


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
	fire_timer -= delta
	if fire_timer <= 0:
		fire_timer = fire_interval + randf_range(-0.5, 0.5)
		_try_fire()

	if backblast_timer > 0:
		backblast_timer -= delta
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
	if not projectile_scenes.has("aa_missile") or not projectiles_container:
		return

	var target = _find_air_target()
	if not target:
		return

	var missile = projectile_scenes["aa_missile"].instantiate()
	missile.global_position = global_position + Vector2(8, -25)  # Конец трубы
	missile.launch_at(target, Vector2(0.3, -1).normalized())  # Вверх и немного вправо
	projectiles_container.add_child(missile)
	fired_missile.emit(missile)
	shots_fired += 1

	backblast_timer = BACKBLAST_DURATION
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
	uniform_color = Color(0.18, 0.18, 0.16)
	skin_color = Color(0.3, 0.28, 0.25)
	helmet_color = Color(0.18, 0.18, 0.16)
	tube_color = Color(0.15, 0.15, 0.13)
	tube_tip_color = Color(0.18, 0.16, 0.14)
	modulate = Color.WHITE
	queue_redraw()
	var timer = get_tree().create_timer(10.0)
	timer.timeout.connect(queue_free)


func _draw() -> void:
	if not deployed:
		_draw_walking()
		return

	# === РАЗВЁРНУТАЯ ПОЗИЦИЯ: солдат на колене с ПЗРК ===
	if not alive:
		# Мёртвый солдат — просто серый силуэт
		draw_rect(Rect2(-5, -16, 10, 16), uniform_color)
		draw_line(Vector2(3, -14), Vector2(14, -22), tube_color, 3.0)
		return

	# Ноги (на колене)
	# Левая нога — согнута вперёд (колено)
	draw_line(Vector2(-2, -4), Vector2(4, 0), uniform_color.darkened(0.15), 3.0)
	# Правая нога — назад (сидит на ней)
	draw_line(Vector2(0, -4), Vector2(-6, 0), uniform_color.darkened(0.15), 3.0)

	# Тело (присевший — короче)
	draw_rect(Rect2(-5, -18, 10, 14), uniform_color)

	# Голова
	draw_circle(Vector2(0, -24), 5.0, skin_color)

	# Каска
	draw_arc(Vector2(0, -26), 6.0, PI, TAU, 12, helmet_color, 2.5)

	# ПЗРК труба на плече (толстая линия от плеча вверх-вправо)
	var tube_start = Vector2(3, -16)  # Плечо
	var tube_end = Vector2(14, -28)   # Конец трубы (вверх-вправо)
	draw_line(tube_start, tube_end, tube_color, 4.0)

	# Раструб на конце трубы
	var tube_dir = (tube_end - tube_start).normalized()
	var tube_perp = Vector2(-tube_dir.y, tube_dir.x)
	draw_line(tube_end - tube_perp * 3, tube_end + tube_perp * 3, tube_tip_color, 2.5)

	# Прицел на трубе
	draw_rect(Rect2(8, -24, 3, 3), Color(0.2, 0.2, 0.18))

	# Руки держат трубу
	draw_line(Vector2(1, -14), Vector2(6, -18), skin_color, 2.0)
	draw_line(Vector2(1, -10), Vector2(10, -22), skin_color, 2.0)

	# === Выхлоп при пуске (backblast) ===
	if backblast_timer > 0:
		var t = backblast_timer / BACKBLAST_DURATION
		# Задний выхлоп (позади трубы)
		var back_dir = -tube_dir
		var blast_pos = tube_start + back_dir * 6.0
		# Оранжево-белое облако
		draw_circle(blast_pos, 8.0 * t, Color(1.0, 0.7, 0.3, 0.6 * t))
		draw_circle(blast_pos + back_dir * 5.0, 6.0 * t, Color(0.9, 0.85, 0.7, 0.4 * t))
		draw_circle(blast_pos + back_dir * 10.0, 4.0 * t, Color(0.7, 0.7, 0.65, 0.25 * t))
		# Передняя вспышка (на конце трубы)
		draw_circle(tube_end, 4.0 * t, Color(1.0, 0.9, 0.4, 0.8 * t))


func _draw_walking() -> void:
	# Идущий солдат с трубой ПЗРК на плече
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

	# ПЗРК труба на плече (несёт горизонтально)
	draw_line(Vector2(3, -18 + bob), Vector2(20, -22 + bob), tube_color, 3.5)
	# Раструб
	draw_line(Vector2(-4, -15 + bob), Vector2(3, -18 + bob), tube_color, 3.0)
