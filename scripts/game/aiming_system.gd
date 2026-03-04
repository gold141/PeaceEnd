# scripts/game/aiming_system.gd
extends Node2D

## Сцена снаряда для инстанцирования
@export var projectile_scene: PackedScene
## Минимальная сила выстрела
@export var min_power: float = 200.0
## Максимальная сила выстрела
@export var max_power: float = 800.0
## Чувствительность перетягивания (пиксели мыши -> сила)
@export var drag_sensitivity: float = 1.5
## Гравитация (должна совпадать с projectile.gd)
@export var gravity_force: float = 980.0
## Перезарядка (секунды)
@export var reload_time: float = 2.0
## Количество точек предсказания траектории
@export var trajectory_points: int = 40
## Интервал времени между точками траектории
@export var trajectory_time_step: float = 0.05

var is_aiming: bool = false
var aim_start: Vector2 = Vector2.ZERO
var current_angle: float = 45.0
var current_power: float = 400.0
var can_fire: bool = true
var reload_timer: float = 0.0

## Ссылка на контейнер снарядов (назначить из battle scene)
@export var projectiles_container: Node2D

signal fired(angle: float, power: float)


func _process(delta: float) -> void:
	# Reload timer
	if not can_fire:
		reload_timer -= delta
		if reload_timer <= 0:
			can_fire = true

	# Redraw trajectory line
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_aiming(event.global_position)
			else:
				_fire()

	elif event is InputEventMouseMotion and is_aiming:
		_update_aim(event.global_position)


func _start_aiming(mouse_pos: Vector2) -> void:
	if not can_fire:
		return
	is_aiming = true
	aim_start = mouse_pos


func _update_aim(mouse_pos: Vector2) -> void:
	var drag = aim_start - mouse_pos  # Drag AWAY from target = more power

	# Angle from horizontal (drag direction)
	current_angle = rad_to_deg(atan2(-drag.y, drag.x))
	current_angle = clamp(current_angle, 10.0, 85.0)

	# Power from drag distance
	current_power = clamp(drag.length() * drag_sensitivity, min_power, max_power)


func _fire() -> void:
	if not is_aiming or not can_fire:
		is_aiming = false
		return

	is_aiming = false

	if projectile_scene and projectiles_container:
		var proj = projectile_scene.instantiate()
		proj.global_position = global_position
		proj.launch(current_angle, current_power)
		projectiles_container.add_child(proj)

		fired.emit(current_angle, current_power)

	# Start reload
	can_fire = false
	reload_timer = reload_time


func _draw() -> void:
	if not is_aiming:
		return

	# Draw predicted trajectory
	var angle_rad = deg_to_rad(current_angle)
	var vel = Vector2(
		current_power * cos(angle_rad),
		-current_power * sin(angle_rad)
	)

	var prev_point = Vector2.ZERO  # local coordinates
	for i in range(1, trajectory_points):
		var t = i * trajectory_time_step
		var point = Vector2(
			vel.x * t,
			vel.y * t + 0.5 * gravity_force * t * t
		)
		draw_line(prev_point, point, Color.YELLOW, 2.0)
		prev_point = point

	# Draw power indicator
	var power_ratio = (current_power - min_power) / (max_power - min_power)
	var indicator_color = Color.GREEN.lerp(Color.RED, power_ratio)
	draw_arc(Vector2.ZERO, 30.0, 0, TAU, 32, indicator_color, 3.0)
