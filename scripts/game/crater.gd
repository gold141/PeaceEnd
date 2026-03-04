# scripts/game/crater.gd
extends Node2D

## Радиус воронки
@export var radius: float = 20.0
## Цвет воронки (тёмная земля)
@export var color: Color = Color(0.15, 0.1, 0.05, 0.85)

var _rand_offset: Vector2
var _rand_scale: Vector2


func _ready() -> void:
	# Небольшая рандомизация формы
	_rand_offset = Vector2(randf_range(-3, 3), randf_range(-1, 1))
	_rand_scale = Vector2(randf_range(0.85, 1.15), randf_range(0.5, 0.7))


func _draw() -> void:
	# Основная эллиптическая воронка
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var segments := 16

	for i in range(segments + 1):
		var angle = TAU * float(i) / float(segments)
		var p = Vector2(cos(angle) * radius * _rand_scale.x, sin(angle) * radius * _rand_scale.y)
		points.append(p + _rand_offset)
		colors.append(color)

	if points.size() > 2:
		draw_polygon(points, colors)

	# Тёмный центр
	var inner_points := PackedVector2Array()
	var inner_colors := PackedColorArray()
	var inner_r = radius * 0.4

	for i in range(segments + 1):
		var angle = TAU * float(i) / float(segments)
		var p = Vector2(cos(angle) * inner_r * _rand_scale.x, sin(angle) * inner_r * _rand_scale.y)
		inner_points.append(p + _rand_offset)
		inner_colors.append(Color(0.08, 0.05, 0.02, 0.9))

	if inner_points.size() > 2:
		draw_polygon(inner_points, inner_colors)
