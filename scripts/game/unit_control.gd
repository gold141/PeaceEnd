# scripts/game/unit_control.gd
# Manages manual player control of individual units
extends Node2D

## Reference to range visualizer (for reading hovered_unit)
var range_visualizer: Node2D
## Reference to aiming system (to block/unblock artillery)
var aiming_system: Node2D
## Reference to camera
var camera: Camera2D

## Currently controlled unit
var controlled_unit: Node2D = null
## Is unit control mode active?
var active: bool = false

## Selection threshold (pixels from unit center)
const SELECT_THRESHOLD: float = 35.0
## Crosshair size
const CROSSHAIR_SIZE: float = 10.0
## Outline pulse speed
var outline_pulse: float = 0.0

signal unit_selected(unit: Node2D)
signal unit_deselected()


func setup(rv: Node2D, aim: Node2D, cam: Camera2D) -> void:
	range_visualizer = rv
	aiming_system = aim
	camera = cam


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Mouse button up (release) — select or fire
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			# Don't interact if cursor is in action panel area
			var mouse_screen_y = get_viewport().get_mouse_position().y
			if mouse_screen_y > 520:
				return

			if active:
				# Already controlling a unit — check if clicking another unit
				var clicked_unit = _find_player_unit_at_mouse()
				if clicked_unit and clicked_unit != controlled_unit:
					_switch_to_unit(clicked_unit)
				else:
					# Fire at cursor position
					_manual_fire()
			else:
				# Not controlling — check if clicking a player unit
				var clicked_unit = _find_player_unit_at_mouse()
				if clicked_unit:
					_select_unit(clicked_unit)

		# LMB press while active — we handle release for fire, block press
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and active:
			var mouse_screen_y = get_viewport().get_mouse_position().y
			if mouse_screen_y <= 520:
				get_viewport().set_input_as_handled()

		# RMB or ESC — deselect
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and active:
			_deselect_unit()

	elif event is InputEventKey and event.pressed and active:
		if event.keycode == KEY_ESCAPE:
			_deselect_unit()


func _process(delta: float) -> void:
	if not active or not is_instance_valid(controlled_unit):
		if active:
			_deselect_unit()
		return

	# Check if unit died
	if "alive" in controlled_unit and not controlled_unit.alive:
		_deselect_unit()
		return

	# Movement via A/D
	var move_speed = _get_unit_move_speed()
	if move_speed > 0:
		if Input.is_key_pressed(KEY_A):
			controlled_unit.position.x -= move_speed * delta
			controlled_unit.position.x = maxf(controlled_unit.position.x, 10.0)
		if Input.is_key_pressed(KEY_D):
			controlled_unit.position.x += move_speed * delta
			controlled_unit.position.x = minf(controlled_unit.position.x, 6400.0)

	# AA Gun: aim turret at mouse
	if controlled_unit.has_method("manual_aim_at"):
		controlled_unit.manual_aim_at(get_global_mouse_position())

	# Hide system cursor in game area
	var mouse_screen_y = get_viewport().get_mouse_position().y
	if mouse_screen_y <= 520:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Outline pulse
	outline_pulse += delta * 3.0
	if outline_pulse > TAU:
		outline_pulse -= TAU

	queue_redraw()


func _find_player_unit_at_mouse() -> Node2D:
	var mouse = get_global_mouse_position()
	var best_unit: Node2D = null
	var best_dist: float = SELECT_THRESHOLD

	var groups = ["infantry", "player_units", "player_vehicles", "anti_air_units"]
	var checked: Array = []

	for group_name in groups:
		for unit in get_tree().get_nodes_in_group(group_name):
			if unit in checked:
				continue
			checked.append(unit)

			if "alive" in unit and not unit.alive:
				continue
			if "team" in unit and unit.team != "player":
				continue
			if "deployed" in unit and not unit.deployed:
				continue

			var offset = Vector2(0, -15) if unit.global_position.y > 400 else Vector2.ZERO
			var dist = mouse.distance_to(unit.global_position + offset)
			if dist < best_dist:
				best_dist = dist
				best_unit = unit

	return best_unit


func _select_unit(unit: Node2D) -> void:
	if controlled_unit and is_instance_valid(controlled_unit):
		controlled_unit.manually_controlled = false

	controlled_unit = unit
	controlled_unit.manually_controlled = true
	active = true
	aiming_system.input_blocked = true
	outline_pulse = 0.0

	unit_selected.emit(unit)


func _deselect_unit() -> void:
	if controlled_unit and is_instance_valid(controlled_unit):
		controlled_unit.manually_controlled = false

	controlled_unit = null
	active = false
	aiming_system.input_blocked = false

	unit_deselected.emit()
	queue_redraw()


func _switch_to_unit(new_unit: Node2D) -> void:
	if controlled_unit and is_instance_valid(controlled_unit):
		controlled_unit.manually_controlled = false

	controlled_unit = new_unit
	controlled_unit.manually_controlled = true
	outline_pulse = 0.0

	unit_selected.emit(new_unit)


func _manual_fire() -> void:
	if not controlled_unit or not is_instance_valid(controlled_unit):
		return
	if controlled_unit.has_method("manual_fire_at"):
		controlled_unit.manual_fire_at(get_global_mouse_position())


func _get_unit_move_speed() -> float:
	if not controlled_unit:
		return 0.0

	# AA Gun is stationary
	if "can_move" in controlled_unit and not controlled_unit.can_move:
		return 0.0

	if "drive_speed" in controlled_unit:
		return controlled_unit.drive_speed
	if "walk_speed" in controlled_unit:
		return controlled_unit.walk_speed

	return 0.0


func _draw() -> void:
	if not active or not is_instance_valid(controlled_unit):
		return

	# --- Green pulsing outline around controlled unit ---
	var center = to_local(controlled_unit.global_position)
	var pulse_alpha = 0.4 + 0.25 * sin(outline_pulse)
	var outline_color = Color(0.3, 1.0, 0.3, pulse_alpha)

	# Draw selection box
	var box_size = 30.0
	if "unit_type" in controlled_unit:
		match controlled_unit.unit_type:
			"player_tank":
				box_size = 40.0
			"light_vehicle":
				box_size = 35.0
			"aa_gun":
				box_size = 30.0

	var box_offset = Vector2(0, -15)
	var rect = Rect2(center + box_offset - Vector2(box_size, box_size), Vector2(box_size * 2, box_size * 2))
	draw_rect(rect, outline_color, false, 2.0)

	# Corner markers
	var corner_len = 8.0
	var tl = rect.position
	var tr = Vector2(rect.end.x, rect.position.y)
	var bl = Vector2(rect.position.x, rect.end.y)
	var br = rect.end

	for corner in [tl, tr, bl, br]:
		var dx = corner_len if corner.x == tl.x else -corner_len
		var dy = corner_len if corner.y == tl.y else -corner_len
		draw_line(corner, corner + Vector2(dx, 0), outline_color, 2.5)
		draw_line(corner, corner + Vector2(0, dy), outline_color, 2.5)

	# --- Yellow crosshair at mouse ---
	var mouse_screen_y = get_viewport().get_mouse_position().y
	if mouse_screen_y <= 520:
		var mouse_local = to_local(get_global_mouse_position())
		var s = CROSSHAIR_SIZE

		# Check if unit can fire (fire_timer <= 0)
		var can_fire = true
		if "fire_timer" in controlled_unit:
			can_fire = controlled_unit.fire_timer <= 0

		var xhair_color = Color(1.0, 0.9, 0.2) if can_fire else Color(0.5, 0.5, 0.4)

		draw_line(mouse_local + Vector2(-s, 0), mouse_local + Vector2(s, 0), xhair_color, 2.0)
		draw_line(mouse_local + Vector2(0, -s), mouse_local + Vector2(0, s), xhair_color, 2.0)
		draw_arc(mouse_local, s * 0.7, 0, TAU, 24, xhair_color, 1.5)

		# Line from unit to cursor
		draw_line(center + box_offset, mouse_local, Color(xhair_color, 0.25), 1.0)

	# --- Reload indicator under the unit ---
	if "fire_timer" in controlled_unit and "fire_interval" in controlled_unit:
		var progress = 1.0 - maxf(controlled_unit.fire_timer, 0.0) / controlled_unit.fire_interval
		var bar_width = 30.0
		var bar_y = center.y + box_size + 5
		var bar_bg_rect = Rect2(center.x - bar_width / 2, bar_y, bar_width, 4)
		draw_rect(bar_bg_rect, Color(0.2, 0.2, 0.2, 0.6))
		var bar_fill_rect = Rect2(center.x - bar_width / 2, bar_y, bar_width * progress, 4)
		var bar_color = Color(0.3, 1.0, 0.3) if progress >= 1.0 else Color(0.8, 0.6, 0.2)
		draw_rect(bar_fill_rect, bar_color)
