# scripts/game/bullet.gd
# Пуля — быстрая, почти прямая, тонкий шлейф
extends Area2D

@export var gravity_force: float = 30.0
@export var air_drag: float = 0.05
@export var trail_color: Color = Color(1.0, 0.95, 0.5)

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false
var is_enemy: bool = false
var damage: float = 0.3

var trail_points: Array = []
const TRAIL_LENGTH: int = 15
const TRAIL_LIFETIME: float = 0.3
const TRAIL_MAX_WIDTH: float = 1.0

signal hit(position: Vector2, body: Node2D)
signal off_screen()


func launch(angle_deg: float, power: float) -> void:
	var angle_rad = deg_to_rad(angle_deg)
	velocity.x = power * cos(angle_rad)
	velocity.y = -power * sin(angle_rad)
	launched = true


func _process(delta: float) -> void:
	if not launched:
		return

	velocity -= velocity * air_drag * delta
	velocity.y += gravity_force * delta
	position += velocity * delta
	rotation = velocity.angle()

	trail_points.append({"pos": global_position, "age": 0.0})
	if trail_points.size() > TRAIL_LENGTH:
		trail_points.pop_front()

	var i = 0
	while i < trail_points.size():
		trail_points[i]["age"] += delta
		if trail_points[i]["age"] >= TRAIL_LIFETIME:
			trail_points.remove_at(i)
		else:
			i += 1

	queue_redraw()

	if position.y > 600 or position.x > 1400 or position.x < -100:
		off_screen.emit()
		queue_free()


func _draw() -> void:
	# Тело пули
	draw_circle(Vector2.ZERO, 1.5, Color(0.8, 0.75, 0.4))

	var count = trail_points.size()
	if count < 2:
		return

	for i in range(1, count):
		var t = float(i) / float(count - 1)
		var age_alpha = 1.0 - trail_points[i]["age"] / TRAIL_LIFETIME
		var alpha = t * age_alpha * 0.6
		var width = t * TRAIL_MAX_WIDTH * age_alpha

		var from = to_local(trail_points[i - 1]["pos"])
		var to = to_local(trail_points[i]["pos"])
		draw_line(from, to, Color(trail_color.r, trail_color.g, trail_color.b, alpha), maxf(width, 0.3))


func _on_body_entered(body: Node2D) -> void:
	# Пули своих не бьют
	if is_enemy and body.is_in_group("enemy_tanks"):
		return
	if not is_enemy and body.is_in_group("player_vehicles"):
		return
	hit.emit(global_position, body)
	queue_free()
