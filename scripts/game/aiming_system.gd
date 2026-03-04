# scripts/game/aiming_system.gd
extends Node2D

## Сцена снаряда для инстанцирования
@export var projectile_scene: PackedScene
## Уровни силы выстрела (3 заряда пороха)
@export var power_levels: Array[float] = [500.0, 600.0, 700.0]
## Текущий заряд (0-2)
var current_charge: int = 0
## Текущая сила (вычисляется из charge)
var launch_power: float = 500.0
## Гравитация (должна совпадать с projectile.gd)
@export var gravity_force: float = 245.0
## Сопротивление воздуха (должна совпадать с projectile.gd)
@export var air_drag: float = 0.3
## Перезарядка (секунды)
@export var reload_time: float = 2.0
## Минимальный угол (от горизонтали вверх)
@export var min_angle: float = 5.0
## Максимальный угол
@export var max_angle: float = 85.0
## Размер прицела (пиксели)
@export var crosshair_size: float = 12.0

var current_angle: float = 45.0
var can_fire: bool = true
var reload_timer: float = 0.0

# Следы прицелов после выстрелов (макс 2), храним локальные позиции
var ghost_crosshairs: Array[Vector2] = []
const MAX_GHOSTS: int = 2

## Ссылка на контейнер снарядов
@export var projectiles_container: Node2D

signal fired(angle: float, power: float)
signal charge_changed(charge: int)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func set_charge(charge: int) -> void:
	current_charge = clampi(charge, 0, power_levels.size() - 1)
	launch_power = power_levels[current_charge]
	charge_changed.emit(current_charge)


func _process(delta: float) -> void:
	if not can_fire:
		reload_timer -= delta
		if reload_timer <= 0:
			can_fire = true

	_update_aim_from_mouse()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_fire()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			set_charge(0)
		elif event.keycode == KEY_2:
			set_charge(1)
		elif event.keycode == KEY_3:
			set_charge(2)


func _update_aim_from_mouse() -> void:
	var mouse_pos = get_global_mouse_position()
	var direction = mouse_pos - global_position

	var angle_rad = atan2(-direction.y, direction.x)
	var angle_deg = rad_to_deg(angle_rad)

	current_angle = clamp(angle_deg, min_angle, max_angle)


func _fire() -> void:
	if not can_fire:
		return

	# Сохраняем след прицела
	ghost_crosshairs.append(get_local_mouse_position())
	if ghost_crosshairs.size() > MAX_GHOSTS:
		ghost_crosshairs.pop_front()

	if projectile_scene and projectiles_container:
		var proj = projectile_scene.instantiate()
		proj.global_position = global_position
		proj.launch(current_angle, launch_power)
		projectiles_container.add_child(proj)

		fired.emit(current_angle, launch_power)

	can_fire = false
	reload_timer = reload_time


func _draw() -> void:
	var s = crosshair_size

	# Рисуем призрачные прицелы (старые выстрелы)
	for i in range(ghost_crosshairs.size()):
		# Чем старше (меньше индекс), тем прозрачнее
		var alpha = 0.15 + 0.15 * float(i) / max(ghost_crosshairs.size() - 1, 1)
		var ghost_color = Color(0.6, 0.8, 0.6, alpha)
		var pos = ghost_crosshairs[i]

		draw_line(pos + Vector2(-s, 0), pos + Vector2(s, 0), ghost_color, 1.5)
		draw_line(pos + Vector2(0, -s), pos + Vector2(0, s), ghost_color, 1.5)
		draw_arc(pos, s * 0.8, 0, TAU, 24, ghost_color, 1.0)

	# Активный прицел
	var mouse_local = get_local_mouse_position()
	var color = Color.GREEN if can_fire else Color(0.5, 0.5, 0.5)

	draw_line(mouse_local + Vector2(-s, 0), mouse_local + Vector2(s, 0), color, 2.0)
	draw_line(mouse_local + Vector2(0, -s), mouse_local + Vector2(0, s), color, 2.0)
	draw_arc(mouse_local, s * 0.8, 0, TAU, 24, color, 1.5)

	# Линия от пушки к прицелу
	draw_line(Vector2.ZERO, mouse_local, Color(color, 0.3), 1.0)
