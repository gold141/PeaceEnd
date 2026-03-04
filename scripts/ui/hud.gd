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

	# Player units
	var player_units = get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("infantry")
	var player_vehicles = get_tree().get_nodes_in_group("player_vehicles")
	print("Player units (foot): %d" % player_units.size())
	print("Player vehicles: %d" % player_vehicles.size())

	for unit in player_units:
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

	# Enemy units
	var enemy_units = get_tree().get_nodes_in_group("enemy_units") + get_tree().get_nodes_in_group("enemy_tanks")
	print("Enemy units: %d" % enemy_units.size())

	for unit in enemy_units:
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
