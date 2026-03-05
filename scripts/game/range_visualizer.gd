# scripts/game/range_visualizer.gd
# Показывает дальность атаки при наведении мыши на юнитов
extends Node2D

## Порог расстояния для «наведения» (пиксели)
const HOVER_THRESHOLD: float = 35.0

## Цвета по командам
const PLAYER_COLOR: Color = Color(0.3, 0.85, 0.3, 0.12)
const PLAYER_OUTLINE: Color = Color(0.3, 0.85, 0.3, 0.35)
const ENEMY_COLOR: Color = Color(0.85, 0.25, 0.25, 0.12)
const ENEMY_OUTLINE: Color = Color(0.85, 0.25, 0.25, 0.35)
const AA_COLOR: Color = Color(0.3, 0.5, 0.9, 0.12)
const AA_OUTLINE: Color = Color(0.3, 0.5, 0.9, 0.35)
const AIR_COLOR: Color = Color(0.9, 0.6, 0.2, 0.12)
const AIR_OUTLINE: Color = Color(0.9, 0.6, 0.2, 0.35)

var hovered_unit: Node2D = null
var hovered_range: float = 0.0
var hovered_color: Color = Color.TRANSPARENT
var hovered_outline: Color = Color.TRANSPARENT
var hovered_fire_dir: String = "right"  # "right", "left", "up", "full"


func _process(_delta: float) -> void:
	var mouse = get_global_mouse_position()
	if get_viewport().get_mouse_position().y > 520:
		if hovered_unit:
			hovered_unit = null
			queue_redraw()
		return

	var best_unit: Node2D = null
	var best_dist: float = HOVER_THRESHOLD
	var best_range: float = 0.0
	var best_dir: String = "right"
	var best_color: Color = PLAYER_COLOR
	var best_outline: Color = PLAYER_OUTLINE

	# Проверяем все группы юнитов
	var groups_to_check = [
		{"group": "infantry", "dir": "right", "color": PLAYER_COLOR, "outline": PLAYER_OUTLINE},
		{"group": "player_units", "dir": "right", "color": PLAYER_COLOR, "outline": PLAYER_OUTLINE},
		{"group": "player_vehicles", "dir": "right", "color": PLAYER_COLOR, "outline": PLAYER_OUTLINE},
		{"group": "anti_air_units", "dir": "up", "color": AA_COLOR, "outline": AA_OUTLINE},
		{"group": "enemy_tanks", "dir": "left", "color": ENEMY_COLOR, "outline": ENEMY_OUTLINE},
		{"group": "enemy_infantry_group", "dir": "left", "color": ENEMY_COLOR, "outline": ENEMY_OUTLINE},
		{"group": "enemy_units", "dir": "left", "color": ENEMY_COLOR, "outline": ENEMY_OUTLINE},
		{"group": "air_units", "dir": "full", "color": AIR_COLOR, "outline": AIR_OUTLINE},
	]

	for check in groups_to_check:
		for unit in get_tree().get_nodes_in_group(check["group"]):
			if "alive" in unit and not unit.alive:
				continue
			if not "fire_range" in unit:
				continue
			var offset = Vector2(0, -15) if unit.global_position.y > 400 else Vector2.ZERO
			var dist = mouse.distance_to(unit.global_position + offset)
			if dist < best_dist:
				best_dist = dist
				best_unit = unit
				best_range = unit.fire_range
				best_dir = check["dir"]
				best_color = check["color"]
				best_outline = check["outline"]
				# AA units показывают зону "вверх"
				if unit.is_in_group("anti_air_units"):
					best_dir = "up"
					best_color = AA_COLOR
					best_outline = AA_OUTLINE

	if best_unit != hovered_unit:
		hovered_unit = best_unit
		if hovered_unit:
			hovered_range = best_range
			hovered_fire_dir = best_dir
			hovered_color = best_color
			hovered_outline = best_outline
		queue_redraw()


func _draw() -> void:
	if not hovered_unit or not is_instance_valid(hovered_unit):
		return

	var center = to_local(hovered_unit.global_position)
	var r = hovered_range

	var start_angle: float
	var end_angle: float

	# Используем реальные углы стрельбы юнита, если есть
	var unit_min = hovered_unit.get("min_fire_angle")
	var unit_max = hovered_unit.get("max_fire_angle")

	if unit_min != null and unit_max != null:
		# Конвертация: игровые углы (0°=вправо, +=вверх) → Godot draw (0=вправо, +=вниз)
		start_angle = -deg_to_rad(unit_max)
		end_angle = -deg_to_rad(unit_min)
	else:
		# Фоллбэк: generic дуга
		match hovered_fire_dir:
			"right":
				start_angle = -PI * 0.5
				end_angle = PI * 0.5
			"left":
				start_angle = PI * 0.5
				end_angle = PI * 1.5
			"up":
				start_angle = PI
				end_angle = TAU
			"full":
				start_angle = 0
				end_angle = TAU

	var segments = 32
	var arc_span = end_angle - start_angle
	var is_full_circle = absf(arc_span) >= TAU - 0.01

	var points: PackedVector2Array = PackedVector2Array()
	if not is_full_circle:
		points.append(center)
	for i in range(segments + 1):
		var angle = start_angle + arc_span * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, hovered_color)

	draw_arc(center, r, start_angle, end_angle, segments, hovered_outline, 1.5)

	if not is_full_circle:
		var p1 = center + Vector2(cos(start_angle), sin(start_angle)) * r
		var p2 = center + Vector2(cos(end_angle), sin(end_angle)) * r
		draw_line(center, p1, hovered_outline, 1.0)
		draw_line(center, p2, hovered_outline, 1.0)
