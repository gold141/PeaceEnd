# scripts/game/range_visualizer.gd
# Показывает дальность атаки при наведении мыши на юнитов
extends Node2D

## Порог расстояния для «наведения» (пиксели)
const HOVER_THRESHOLD: float = 35.0
## Цвет дальности пехоты (зелёный)
const INFANTRY_COLOR: Color = Color(0.3, 0.85, 0.3, 0.12)
const INFANTRY_OUTLINE: Color = Color(0.3, 0.85, 0.3, 0.35)
## Цвет дальности танков (красный)
const TANK_COLOR: Color = Color(0.85, 0.25, 0.25, 0.12)
const TANK_OUTLINE: Color = Color(0.85, 0.25, 0.25, 0.35)

var hovered_unit: Node2D = null
var hovered_range: float = 0.0
var hovered_color: Color = Color.TRANSPARENT
var hovered_outline: Color = Color.TRANSPARENT
var hovered_is_tank: bool = false


func _process(_delta: float) -> void:
	var mouse = get_global_mouse_position()
	# Не показываем если мышь в панели
	if mouse.y > 520:
		if hovered_unit:
			hovered_unit = null
			queue_redraw()
		return

	var best_unit: Node2D = null
	var best_dist: float = HOVER_THRESHOLD
	var best_range: float = 0.0
	var best_is_tank: bool = false

	# Проверяем пехоту
	for unit in get_tree().get_nodes_in_group("infantry"):
		if not unit.alive:
			continue
		var dist = mouse.distance_to(unit.global_position + Vector2(0, -15))
		if dist < best_dist:
			best_dist = dist
			best_unit = unit
			best_range = unit.fire_range
			best_is_tank = false

	# Проверяем танки
	for tank in get_tree().get_nodes_in_group("enemy_tanks"):
		if not tank.alive:
			continue
		var dist = mouse.distance_to(tank.global_position)
		if dist < best_dist:
			best_dist = dist
			best_unit = tank
			best_range = tank.fire_range
			best_is_tank = true

	if best_unit != hovered_unit:
		hovered_unit = best_unit
		if hovered_unit:
			hovered_range = best_range
			hovered_is_tank = best_is_tank
			if best_is_tank:
				hovered_color = TANK_COLOR
				hovered_outline = TANK_OUTLINE
			else:
				hovered_color = INFANTRY_COLOR
				hovered_outline = INFANTRY_OUTLINE
		queue_redraw()


func _draw() -> void:
	if not hovered_unit or not is_instance_valid(hovered_unit):
		return

	var center = to_local(hovered_unit.global_position)
	var r = hovered_range

	# Полукруг — пехота стреляет вправо, танки влево
	var start_angle: float
	var end_angle: float
	if hovered_is_tank:
		# Танк стреляет влево (PI/2 .. 3PI/2)
		start_angle = PI * 0.5
		end_angle = PI * 1.5
	else:
		# Пехота стреляет вправо (-PI/2 .. PI/2)
		start_angle = -PI * 0.5
		end_angle = PI * 0.5

	# Заполненный полукруг через полигон
	var points: PackedVector2Array = PackedVector2Array()
	points.append(center)
	var segments = 32
	for i in range(segments + 1):
		var angle = start_angle + (end_angle - start_angle) * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, hovered_color)

	# Контур
	draw_arc(center, r, start_angle, end_angle, segments, hovered_outline, 1.5)
	# Линии по краям полукруга
	var p1 = center + Vector2(cos(start_angle), sin(start_angle)) * r
	var p2 = center + Vector2(cos(end_angle), sin(end_angle)) * r
	draw_line(center, p1, hovered_outline, 1.0)
	draw_line(center, p2, hovered_outline, 1.0)
