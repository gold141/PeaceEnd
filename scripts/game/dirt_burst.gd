# scripts/game/dirt_burst.gd
# Частицы земли, разлетающиеся при взрыве
extends Node2D

## Количество частиц
@export var particle_count: int = 20
## Скорость разлёта
@export var burst_speed: float = 180.0
## Гравитация частиц
@export var gravity: float = 300.0
## Время жизни
@export var lifetime: float = 0.9

var particles: Array = []  # {pos, vel, size, color, age}


func _ready() -> void:
	for i in range(particle_count):
		# Больше частиц летят вертикально вверх
		var angle = randf_range(-PI * 0.85, -PI * 0.15)
		# Часть частиц — строго вертикальный столб
		if i < particle_count / 3:
			angle = randf_range(-PI * 0.65, -PI * 0.35)
		var speed = randf_range(burst_speed * 0.3, burst_speed)
		var size = randf_range(1.5, 4.5)
		# Оттенки земли
		var brown = randf_range(0.1, 0.3)
		var clr = Color(brown + 0.1, brown, brown * 0.5, 1.0)

		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"size": size,
			"color": clr,
			"age": 0.0,
		})


func _process(delta: float) -> void:
	var alive = false
	for p in particles:
		p["age"] += delta
		if p["age"] >= lifetime:
			continue
		alive = true
		p["vel"].y += gravity * delta
		p["pos"] += p["vel"] * delta

	queue_redraw()

	if not alive:
		queue_free()


func _draw() -> void:
	for p in particles:
		if p["age"] >= lifetime:
			continue
		var alpha = 1.0 - p["age"] / lifetime
		var clr = p["color"]
		clr.a = alpha
		draw_rect(Rect2(p["pos"] - Vector2(p["size"], p["size"]) * 0.5, Vector2(p["size"], p["size"])), clr)
