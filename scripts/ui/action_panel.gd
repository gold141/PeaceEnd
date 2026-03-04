# scripts/ui/action_panel.gd
# Нижняя панель действий — вызов юнитов и техники
extends Control

## Высота линии-разделителя
const DIVIDER_Y: float = 0.0
## Цвет фона панели
const BG_COLOR: Color = Color(0.12, 0.12, 0.15, 0.95)
## Цвет рамки
const BORDER_COLOR: Color = Color(0.3, 0.35, 0.25)
## Цвет кнопки (нормальный)
const BTN_NORMAL: Color = Color(0.2, 0.22, 0.18)
## Цвет кнопки (наведение)
const BTN_HOVER: Color = Color(0.28, 0.32, 0.25)
## Цвет кнопки (выбрано)
const BTN_SELECTED: Color = Color(0.25, 0.45, 0.2)
## Размер кнопки
const BTN_SIZE: Vector2 = Vector2(80, 80)
## Отступ между кнопками
const BTN_MARGIN: float = 16.0
## Начальная позиция кнопок
const BTN_START: Vector2 = Vector2(20, 30)

# Кнопки: [{rect: Rect2, label: String, id: String, hovered: bool}]
var buttons: Array = []
var selected_id: String = ""

signal unit_selected(unit_id: String)
signal unit_deselected()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_buttons()


func _setup_buttons() -> void:
	buttons.clear()
	# Пока одна кнопка — пехота
	var btn_rect = Rect2(BTN_START, BTN_SIZE)
	buttons.append({
		"rect": btn_rect,
		"label": "Infantry",
		"id": "infantry",
		"hovered": false,
	})


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local = event.position
		for btn in buttons:
			btn["hovered"] = btn["rect"].has_point(local)
		queue_redraw()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			for btn in buttons:
				if btn["rect"].has_point(event.position):
					_toggle_button(btn["id"])
					get_viewport().set_input_as_handled()
					return
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if selected_id != "":
				_deselect()
				get_viewport().set_input_as_handled()


func _toggle_button(id: String) -> void:
	if selected_id == id:
		_deselect()
	else:
		selected_id = id
		unit_selected.emit(id)
		queue_redraw()


func _deselect() -> void:
	selected_id = ""
	unit_deselected.emit()
	queue_redraw()


func _draw() -> void:
	# Фон
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	# Верхняя рамка
	draw_line(Vector2(0, 0), Vector2(size.x, 0), BORDER_COLOR, 2.0)

	# Кнопки
	for btn in buttons:
		var rect: Rect2 = btn["rect"]
		var color: Color
		if btn["id"] == selected_id:
			color = BTN_SELECTED
		elif btn["hovered"]:
			color = BTN_HOVER
		else:
			color = BTN_NORMAL

		# Фон кнопки
		draw_rect(rect, color)
		# Рамка кнопки
		draw_rect(rect, BORDER_COLOR, false, 1.5)

		# Иконка пехоты (рисуем солдата)
		var cx = rect.position.x + rect.size.x * 0.5
		var cy = rect.position.y + rect.size.y * 0.4
		_draw_soldier_icon(Vector2(cx, cy), 1.0)

		# Текст
		# Не можем draw_string без шрифта, поэтому рисуем мешки как подпись
		var label_y = rect.position.y + rect.size.y - 14
		_draw_sandbag_icon(Vector2(cx, label_y), 0.6)


func _draw_soldier_icon(center: Vector2, scale: float) -> void:
	var s = scale
	# Голова
	draw_circle(center + Vector2(0, -12) * s, 5.0 * s, Color(0.55, 0.5, 0.4))
	# Каска
	draw_arc(center + Vector2(0, -14) * s, 6.0 * s, PI, TAU, 12, Color(0.3, 0.35, 0.25), 2.0 * s)
	# Тело
	draw_rect(Rect2(center + Vector2(-4, -6) * s, Vector2(8, 14) * s), Color(0.3, 0.35, 0.25))
	# Ноги
	draw_rect(Rect2(center + Vector2(-4, 8) * s, Vector2(3, 8) * s), Color(0.25, 0.28, 0.2))
	draw_rect(Rect2(center + Vector2(1, 8) * s, Vector2(3, 8) * s), Color(0.25, 0.28, 0.2))
	# Оружие
	draw_line(center + Vector2(4, -4) * s, center + Vector2(12, -10) * s, Color(0.2, 0.2, 0.18), 2.0 * s)


func _draw_sandbag_icon(center: Vector2, scale: float) -> void:
	var s = scale
	# Два мешка
	draw_rect(Rect2(center + Vector2(-12, -4) * s, Vector2(10, 6) * s), Color(0.6, 0.5, 0.3))
	draw_rect(Rect2(center + Vector2(2, -4) * s, Vector2(10, 6) * s), Color(0.55, 0.45, 0.28))
