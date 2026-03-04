# scripts/ui/action_panel.gd
# Нижняя панель действий — вызов юнитов и техники (6 кнопок)
extends Control

const BG_COLOR: Color = Color(0.12, 0.12, 0.15, 0.95)
const BORDER_COLOR: Color = Color(0.3, 0.35, 0.25)
const BTN_NORMAL: Color = Color(0.2, 0.22, 0.18)
const BTN_HOVER: Color = Color(0.28, 0.32, 0.25)
const BTN_SELECTED: Color = Color(0.25, 0.45, 0.2)
const BTN_DISABLED: Color = Color(0.15, 0.15, 0.15)
const BTN_SIZE: Vector2 = Vector2(80, 80)
const BTN_MARGIN: float = 12.0
const BTN_START: Vector2 = Vector2(20, 24)

const UNIT_DEFS = [
	{"id": "infantry", "label": "RPG", "cost": 100, "hotkey": KEY_Q},
	{"id": "machine_gunner", "label": "MG", "cost": 80, "hotkey": KEY_W},
	{"id": "light_vehicle", "label": "Truck", "cost": 200, "hotkey": KEY_E},
	{"id": "player_tank", "label": "Tank", "cost": 400, "hotkey": KEY_R},
	{"id": "aa_gun", "label": "AA", "cost": 250, "hotkey": KEY_T},
	{"id": "manpads", "label": "SAM", "cost": 150, "hotkey": KEY_Y},
]

var buttons: Array = []
var selected_id: String = ""
var economy: Node = null

signal unit_selected(unit_id: String)
signal unit_deselected()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_buttons()


func setup_economy(econ: Node) -> void:
	economy = econ


func _setup_buttons() -> void:
	buttons.clear()
	for i in range(UNIT_DEFS.size()):
		var def = UNIT_DEFS[i]
		var pos = BTN_START + Vector2((BTN_SIZE.x + BTN_MARGIN) * i, 0)
		buttons.append({
			"rect": Rect2(pos, BTN_SIZE),
			"id": def["id"],
			"label": def["label"],
			"cost": def["cost"],
			"hotkey": def["hotkey"],
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		for btn in buttons:
			if event.keycode == btn["hotkey"]:
				_toggle_button(btn["id"])
				return


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


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	draw_line(Vector2(0, 0), Vector2(size.x, 0), BORDER_COLOR, 2.0)

	for btn in buttons:
		var rect: Rect2 = btn["rect"]
		var can_afford = economy == null or economy.can_player_afford(btn["id"])
		var color: Color

		if not can_afford:
			color = BTN_DISABLED
		elif btn["id"] == selected_id:
			color = BTN_SELECTED
		elif btn["hovered"]:
			color = BTN_HOVER
		else:
			color = BTN_NORMAL

		draw_rect(rect, color)
		draw_rect(rect, BORDER_COLOR, false, 1.5)

		# Иконка юнита
		var cx = rect.position.x + rect.size.x * 0.5
		var cy = rect.position.y + 28
		_draw_unit_icon(btn["id"], Vector2(cx, cy), 0.7)

		# Стоимость — полоски (каждая = $100)
		var cost_y = rect.position.y + rect.size.y - 16
		var cost_color = Color(0.9, 0.85, 0.3) if can_afford else Color(0.7, 0.2, 0.2)
		var bars = ceili(btn["cost"] / 100.0)
		var bar_w = 5.0
		var total_w = bars * bar_w + (bars - 1) * 2.0
		var start_x = cx - total_w * 0.5
		for i in range(bars):
			var bx = start_x + i * (bar_w + 2.0)
			draw_rect(Rect2(bx, cost_y - 2, bar_w, 5), Color(cost_color, 0.8))

		# Хоткей — маленький кружок в углу
		var key_names = {KEY_Q: "Q", KEY_W: "W", KEY_E: "E", KEY_R: "R", KEY_T: "T", KEY_Y: "Y"}
		var _key_str = key_names.get(btn["hotkey"], "")
		if _key_str != "":
			var key_pos = Vector2(rect.position.x + 8, rect.position.y + 10)
			draw_circle(key_pos, 7, Color(0.1, 0.1, 0.1, 0.8))
			draw_circle(key_pos, 2.5, Color(0.7, 0.7, 0.6))


func _draw_unit_icon(unit_id: String, center: Vector2, s: float) -> void:
	match unit_id:
		"infantry":
			draw_circle(center + Vector2(0, -10) * s, 4.0 * s, Color(0.55, 0.5, 0.4))
			draw_rect(Rect2(center + Vector2(-3, -5) * s, Vector2(6, 10) * s), Color(0.3, 0.35, 0.25))
			draw_line(center + Vector2(3, -4) * s, center + Vector2(10, -8) * s, Color(0.3, 0.32, 0.25), 2.0 * s)
		"machine_gunner":
			draw_circle(center + Vector2(0, -10) * s, 4.0 * s, Color(0.55, 0.5, 0.4))
			draw_rect(Rect2(center + Vector2(-3, -5) * s, Vector2(6, 10) * s), Color(0.3, 0.35, 0.25))
			draw_line(center + Vector2(-4, 5) * s, center + Vector2(-8, 10) * s, Color(0.3, 0.3, 0.28), 1.5 * s)
			draw_line(center + Vector2(4, 5) * s, center + Vector2(8, 10) * s, Color(0.3, 0.3, 0.28), 1.5 * s)
			draw_line(center + Vector2(0, 2) * s, center + Vector2(12, -2) * s, Color(0.2, 0.2, 0.18), 2.5 * s)
		"light_vehicle":
			draw_rect(Rect2(center + Vector2(-10, -4) * s, Vector2(20, 8) * s), Color(0.45, 0.5, 0.35))
			draw_circle(center + Vector2(-6, 5) * s, 3.0 * s, Color(0.2, 0.2, 0.18))
			draw_circle(center + Vector2(6, 5) * s, 3.0 * s, Color(0.2, 0.2, 0.18))
			draw_line(center + Vector2(2, -4) * s, center + Vector2(10, -8) * s, Color(0.3, 0.3, 0.28), 2.0 * s)
		"player_tank":
			draw_rect(Rect2(center + Vector2(-10, 0) * s, Vector2(20, 6) * s), Color(0.2, 0.2, 0.18))
			draw_rect(Rect2(center + Vector2(-9, -5) * s, Vector2(18, 7) * s), Color(0.35, 0.4, 0.3))
			draw_rect(Rect2(center + Vector2(-4, -10) * s, Vector2(10, 6) * s), Color(0.3, 0.35, 0.25))
			draw_line(center + Vector2(6, -8) * s, center + Vector2(14, -8) * s, Color(0.3, 0.35, 0.25), 2.5 * s)
		"aa_gun":
			draw_rect(Rect2(center + Vector2(-8, 2) * s, Vector2(16, 6) * s), Color(0.6, 0.5, 0.3))
			draw_line(center + Vector2(-2, 0) * s, center + Vector2(-4, -12) * s, Color(0.3, 0.3, 0.28), 2.0 * s)
			draw_line(center + Vector2(2, 0) * s, center + Vector2(4, -12) * s, Color(0.3, 0.3, 0.28), 2.0 * s)
		"manpads":
			draw_circle(center + Vector2(0, -10) * s, 4.0 * s, Color(0.55, 0.5, 0.4))
			draw_rect(Rect2(center + Vector2(-3, -5) * s, Vector2(6, 10) * s), Color(0.3, 0.35, 0.25))
			draw_line(center + Vector2(-2, -6) * s, center + Vector2(10, -14) * s, Color(0.25, 0.4, 0.25), 3.0 * s)
