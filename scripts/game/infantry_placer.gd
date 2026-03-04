# scripts/game/infantry_placer.gd
# Система размещения пехоты — призрак-превью и установка на землю
extends Node2D

## Верхняя граница земли (Y)
@export var ground_y: float = 450.0
## Допуск по Y для зоны размещения (выше земли на столько пикселей разрешено)
@export var placement_tolerance: float = 40.0

## Цвет когда можно разместить
const COLOR_VALID: Color = Color(0.2, 0.85, 0.2, 0.4)
## Цвет когда нельзя разместить
const COLOR_INVALID: Color = Color(0.85, 0.2, 0.2, 0.4)
## Цвет контура (валидный)
const OUTLINE_VALID: Color = Color(0.3, 1.0, 0.3, 0.7)
## Цвет контура (невалидный)
const OUTLINE_INVALID: Color = Color(1.0, 0.3, 0.3, 0.7)

var placing: bool = false
var ghost_x: float = 0.0
var can_place: bool = false

# Сцена пехоты
var infantry_scene: PackedScene

signal infantry_placed(pos: Vector2)


func _ready() -> void:
	visible = false
	set_process(false)
	set_process_unhandled_input(false)


func start_placing() -> void:
	placing = true
	visible = true
	set_process(true)
	set_process_unhandled_input(true)


func stop_placing() -> void:
	placing = false
	visible = false
	set_process(false)
	set_process_unhandled_input(false)
	queue_redraw()


func _process(_delta: float) -> void:
	if not placing:
		return

	var mouse = get_global_mouse_position()
	ghost_x = mouse.x

	# Можно ставить если курсор в игровой зоне (выше нижней панели ~Y=520)
	# и не слишком высоко (разумные пределы)
	can_place = mouse.y <= ground_y + placement_tolerance and mouse.y >= 0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not placing:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and can_place:
			# Размещаем пехоту
			infantry_placed.emit(Vector2(ghost_x, ground_y))
			stop_placing()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Отмена
			stop_placing()
			get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			stop_placing()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if not placing:
		return

	var fill_color = COLOR_VALID if can_place else COLOR_INVALID
	var outline_color = OUTLINE_VALID if can_place else OUTLINE_INVALID

	# Позиция призрака — привязана к линии земли
	var pos = Vector2(ghost_x, ground_y)
	# Конвертируем в локальные координаты
	var local = to_local(pos)

	_draw_ghost_fortification(local, fill_color, outline_color)


func _draw_ghost_fortification(center: Vector2, fill: Color, outline: Color) -> void:
	# Мешки с песком (основание укрепления)
	# Нижний ряд — 3 мешка
	var bag_w = 16.0
	var bag_h = 10.0
	var base_y = center.y - bag_h

	for i in range(3):
		var bx = center.x - 1.5 * bag_w + i * bag_w
		draw_rect(Rect2(bx, base_y, bag_w - 1, bag_h), fill)
		draw_rect(Rect2(bx, base_y, bag_w - 1, bag_h), outline, false, 1.5)

	# Верхний ряд — 2 мешка
	var top_y = base_y - bag_h
	for i in range(2):
		var bx = center.x - bag_w + i * bag_w
		draw_rect(Rect2(bx, top_y, bag_w - 1, bag_h), fill)
		draw_rect(Rect2(bx, top_y, bag_w - 1, bag_h), outline, false, 1.5)

	# Солдат за мешками
	var soldier_center = center + Vector2(0, -bag_h * 2)

	# Голова
	draw_circle(soldier_center + Vector2(0, -8), 5.0, fill)
	draw_arc(soldier_center + Vector2(0, -8), 5.0, 0, TAU, 16, outline, 1.5)

	# Каска
	draw_arc(soldier_center + Vector2(0, -10), 6.0, PI, TAU, 12, outline, 2.0)

	# Тело
	var body_rect = Rect2(soldier_center + Vector2(-5, -2), Vector2(10, 14))
	draw_rect(body_rect, fill)
	draw_rect(body_rect, outline, false, 1.5)

	# Оружие (винтовка)
	draw_line(soldier_center + Vector2(5, 0), soldier_center + Vector2(18, -10), outline, 2.0)

	# Общий контур зоны (пунктирный прямоугольник)
	var zone = Rect2(center.x - 28, top_y - 28, 56, center.y - top_y + 28)
	draw_rect(zone, Color(outline, 0.3), false, 1.0)
