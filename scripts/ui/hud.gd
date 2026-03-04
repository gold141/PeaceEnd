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

var aiming_system: Node2D

const CHARGE_LABELS = ["1", "2", "3"]
const CHARGE_COLORS_ACTIVE = [
	Color(0.3, 0.6, 0.3),  # green - weak
	Color(0.7, 0.6, 0.2),  # yellow - medium
	Color(0.7, 0.25, 0.2), # red - strong
]
const CHARGE_COLOR_INACTIVE = Color(0.25, 0.25, 0.25)


func setup(aim_sys: Node2D) -> void:
	aiming_system = aim_sys
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
