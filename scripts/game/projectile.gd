# scripts/game/projectile.gd
extends Area2D

## Начальная скорость (пиксели/сек)
@export var speed: float = 500.0
## Угол запуска (градусы от горизонтали)
@export var launch_angle: float = 45.0
## Гравитация (пиксели/сек²)
@export var gravity: float = 980.0
## Радиус взрыва
@export var explosion_radius: float = 50.0

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false

signal hit(position: Vector2)
signal off_screen()


func launch(angle_deg: float, power: float) -> void:
	var angle_rad = deg_to_rad(angle_deg)
	velocity.x = power * cos(angle_rad)
	velocity.y = -power * sin(angle_rad)  # Negative = up in Godot
	launched = true


func _process(delta: float) -> void:
	if not launched:
		return

	# Apply gravity
	velocity.y += gravity * delta

	# Move
	position += velocity * delta

	# Rotate sprite to match trajectory
	rotation = velocity.angle()

	# Check if off screen (below ground or too far)
	if position.y > 800 or position.x > 1400 or position.x < -100:
		off_screen.emit()
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	hit.emit(global_position)
	queue_free()
