# scripts/game/destructible_terrain.gd
# Простой статический террейн (визуал + коллизия)
extends Node2D

## Ширина террейна
@export var terrain_width: int = 1280
## Высота террейна
@export var terrain_height: int = 105
## Позиция верха террейна (Y)
@export var terrain_top_y: float = 615.0
## Цвет земли
@export var ground_color: Color = Color(0.25, 0.18, 0.1)
## Цвет травы
@export var grass_color: Color = Color(0.2, 0.35, 0.1)
## Толщина травы (пиксели)
@export var grass_thickness: int = 8


func _ready() -> void:
	_create_visual()
	_create_collision()


func _create_visual() -> void:
	# Трава
	var grass = ColorRect.new()
	grass.color = grass_color
	grass.position = Vector2(0, terrain_top_y)
	grass.size = Vector2(terrain_width, grass_thickness)
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grass)

	# Земля
	var ground = ColorRect.new()
	ground.color = ground_color
	ground.position = Vector2(0, terrain_top_y + grass_thickness)
	ground.size = Vector2(terrain_width, terrain_height - grass_thickness)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)


func _create_collision() -> void:
	var body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	add_child(body)

	var shape = RectangleShape2D.new()
	shape.size = Vector2(terrain_width, terrain_height)

	var col = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(terrain_width * 0.5, terrain_top_y + terrain_height * 0.5)
	body.add_child(col)
