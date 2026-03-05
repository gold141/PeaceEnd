# scripts/game/bomb.gd
# Авиабомба — падает с гравитацией, большой радиус взрыва
extends Area2D

@export var gravity_force: float = 300.0
@export var air_drag: float = 0.02

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false
var is_enemy: bool = true
var damage: float = 3.0
var blast_radius: float = 80.0

signal hit(position: Vector2, body: Node2D)
signal off_screen()


func launch(horizontal_speed: float = 0.0, vertical_speed: float = 0.0) -> void:
	velocity = Vector2(horizontal_speed, vertical_speed)
	launched = true


func _process(delta: float) -> void:
	if not launched:
		return

	velocity -= velocity * air_drag * delta
	velocity.y += gravity_force * delta
	position += velocity * delta
	rotation = velocity.angle()
	queue_redraw()

	if position.y > 600 or position.x > 6600 or position.x < -100:
		off_screen.emit()
		queue_free()


func _draw() -> void:
	# Корпус бомбы (ориентирован по скорости, рисуем в локальных координатах)
	draw_rect(Rect2(-3, -6, 6, 12), Color(0.3, 0.3, 0.28))
	# Стабилизаторы
	draw_line(Vector2(-4, -6), Vector2(0, -10), Color(0.4, 0.4, 0.35), 1.5)
	draw_line(Vector2(4, -6), Vector2(0, -10), Color(0.4, 0.4, 0.35), 1.5)
	# Носик
	draw_circle(Vector2(0, 6), 3.0, Color(0.5, 0.2, 0.15))


func _on_body_entered(body: Node2D) -> void:
	hit.emit(global_position, body)
	queue_free()
