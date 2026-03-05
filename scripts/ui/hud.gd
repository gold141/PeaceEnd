# scripts/ui/hud.gd
extends CanvasLayer

@onready var angle_label: Label = $AngleLabel
@onready var power_label: Label = $PowerLabel
@onready var reload_bar: ProgressBar = $ReloadBar
@onready var charge_buttons: Array[Button] = [
	$ChargePanel/Charge1,
	$ChargePanel/Charge2,
	$ChargePanel/Charge3,
]
@onready var money_label: Label = $MoneyLabel
@onready var speed_label: Label = $SpeedLabel

var aiming_system: Node2D
var economy: Node
var unit_control: Node2D = null
var controlled_unit: Node2D = null

const CHARGE_LABELS = ["1", "2", "3"]
const CHARGE_COLORS_ACTIVE = [
	Color(0.3, 0.6, 0.3),  # green - weak
	Color(0.7, 0.6, 0.2),  # yellow - medium
	Color(0.7, 0.25, 0.2), # red - strong
]
const CHARGE_COLOR_INACTIVE = Color(0.25, 0.25, 0.25)

# Ускорение времени
var time_scale: float = 1.0
const TIME_SCALES = [1.0, 2.0, 4.0, 8.0]
var time_scale_index: int = 0


func setup(aim_sys: Node2D, econ: Node = null) -> void:
	aiming_system = aim_sys
	economy = econ
	aiming_system.charge_changed.connect(_on_charge_changed)

	for i in range(charge_buttons.size()):
		charge_buttons[i].pressed.connect(_on_charge_button.bind(i))

	# Set initial charge
	aiming_system.set_charge(0)


func _on_charge_button(index: int) -> void:
	aiming_system.set_charge(index)


func _on_charge_changed(charge: int) -> void:
	_update_charge_visuals(charge)


func _update_charge_visuals(active: int) -> void:
	for i in range(charge_buttons.size()):
		if i == active:
			charge_buttons[i].add_theme_color_override("font_color", Color.WHITE)
			charge_buttons[i].add_theme_stylebox_override("normal", _make_stylebox(CHARGE_COLORS_ACTIVE[i]))
			charge_buttons[i].add_theme_stylebox_override("hover", _make_stylebox(CHARGE_COLORS_ACTIVE[i].lightened(0.2)))
			charge_buttons[i].add_theme_stylebox_override("pressed", _make_stylebox(CHARGE_COLORS_ACTIVE[i].darkened(0.2)))
		else:
			charge_buttons[i].add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			charge_buttons[i].add_theme_stylebox_override("normal", _make_stylebox(CHARGE_COLOR_INACTIVE))
			charge_buttons[i].add_theme_stylebox_override("hover", _make_stylebox(CHARGE_COLOR_INACTIVE.lightened(0.15)))
			charge_buttons[i].add_theme_stylebox_override("pressed", _make_stylebox(CHARGE_COLOR_INACTIVE))


func _make_stylebox(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


func setup_unit_control(uc: Node2D) -> void:
	unit_control = uc
	unit_control.unit_selected.connect(_on_unit_controlled)
	unit_control.unit_deselected.connect(_on_unit_released)


func _on_unit_controlled(unit: Node2D) -> void:
	controlled_unit = unit


func _on_unit_released() -> void:
	controlled_unit = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# F — ускорение/замедление времени
		if event.keycode == KEY_F:
			time_scale_index = (time_scale_index + 1) % TIME_SCALES.size()
			time_scale = TIME_SCALES[time_scale_index]
			Engine.time_scale = time_scale
		# P — вывод статистики в консоль
		elif event.keycode == KEY_P:
			_print_battle_stats()


func _process(_delta: float) -> void:
	if not aiming_system:
		return

	if controlled_unit and is_instance_valid(controlled_unit) and "alive" in controlled_unit and controlled_unit.alive:
		# Show controlled unit info
		var unit_name = controlled_unit.unit_type if "unit_type" in controlled_unit else "Unit"
		var hp_str = ""
		if "hp" in controlled_unit and "max_hp" in controlled_unit:
			hp_str = " HP:%d/%d" % [controlled_unit.hp, controlled_unit.max_hp]
		angle_label.text = "[%s]%s" % [unit_name.to_upper(), hp_str]
		power_label.text = "Range: %d" % int(controlled_unit.fire_range) if "fire_range" in controlled_unit else ""

		if "fire_timer" in controlled_unit and "fire_interval" in controlled_unit:
			var progress = (1.0 - maxf(controlled_unit.fire_timer, 0.0) / controlled_unit.fire_interval) * 100
			reload_bar.value = progress
		else:
			reload_bar.value = 100
	else:
		# Normal artillery display
		angle_label.text = "Angle: %d°" % int(aiming_system.current_angle)
		power_label.text = "Power: %d" % int(aiming_system.launch_power)

		if aiming_system.can_fire:
			reload_bar.value = 100
		else:
			var progress = (1.0 - aiming_system.reload_timer / aiming_system.reload_time) * 100
			reload_bar.value = progress

	if economy:
		money_label.text = "$%d  (+%d/s)" % [economy.player_money, int(economy.player_income)]

	if time_scale != 1.0:
		speed_label.text = "x%d [F]" % int(time_scale)
		speed_label.visible = true
	else:
		speed_label.text = "x1 [F]"
		speed_label.visible = true


func _print_battle_stats() -> void:
	print("=== BATTLE STATISTICS ===")

	# Player units (дедупликация — юниты могут быть в нескольких группах)
	var player_set: Array = []
	for unit in get_tree().get_nodes_in_group("player_units"):
		if unit not in player_set:
			player_set.append(unit)
	for unit in get_tree().get_nodes_in_group("infantry"):
		if unit not in player_set:
			player_set.append(unit)
	for unit in get_tree().get_nodes_in_group("player_vehicles"):
		if unit not in player_set:
			player_set.append(unit)
	print("Player units: %d" % player_set.size())

	for unit in player_set:
		if "unit_type" in unit and "alive" in unit:
			var status = "ALIVE" if unit.alive else "DEAD"
			var hp_str = ""
			if "hp" in unit and "max_hp" in unit:
				hp_str = " HP:%d/%d" % [unit.hp, unit.max_hp]
			var shots_str = ""
			if "shots_fired" in unit:
				shots_str = " Shots:%d" % unit.shots_fired
			if "shots_hit" in unit:
				shots_str += " Hits:%d" % unit.shots_hit
			print("  %s [%s]%s%s" % [unit.unit_type, status, hp_str, shots_str])

	# Enemy units (дедупликация)
	var enemy_set: Array = []
	for unit in get_tree().get_nodes_in_group("enemy_units"):
		if unit not in enemy_set:
			enemy_set.append(unit)
	for unit in get_tree().get_nodes_in_group("enemy_tanks"):
		if unit not in enemy_set:
			enemy_set.append(unit)
	for unit in get_tree().get_nodes_in_group("enemy_infantry_group"):
		if unit not in enemy_set:
			enemy_set.append(unit)
	for unit in get_tree().get_nodes_in_group("air_units"):
		if unit not in enemy_set:
			enemy_set.append(unit)
	print("Enemy units: %d" % enemy_set.size())

	for unit in enemy_set:
		if "unit_type" in unit and "alive" in unit:
			var status = "ALIVE" if unit.alive else "DEAD"
			var hp_str = ""
			if "hp" in unit and "max_hp" in unit:
				hp_str = " HP:%d/%d" % [unit.hp, unit.max_hp]
			var shots_str = ""
			if "shots_fired" in unit:
				shots_str = " Shots:%d" % unit.shots_fired
			if "shots_hit" in unit:
				shots_str += " Hits:%d" % unit.shots_hit
			print("  %s [%s]%s%s" % [unit.unit_type, status, hp_str, shots_str])

	# Economy
	if economy:
		print("Player money: $%d" % economy.player_money)
		print("Enemy money: $%d" % economy.enemy_money)
	print("=========================")
