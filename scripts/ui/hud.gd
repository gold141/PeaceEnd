# scripts/ui/hud.gd
extends CanvasLayer

@onready var angle_label: Label = $AngleLabel
@onready var power_label: Label = $PowerLabel
@onready var reload_bar: ProgressBar = $ReloadBar

var aiming_system: Node2D


func setup(aim_sys: Node2D) -> void:
	aiming_system = aim_sys


func _process(_delta: float) -> void:
	if not aiming_system:
		return

	angle_label.text = "Angle: %d°" % int(aiming_system.current_angle)
	power_label.text = "Power: %d" % int(aiming_system.current_power)

	if aiming_system.can_fire:
		reload_bar.value = 100
	else:
		var progress = (1.0 - aiming_system.reload_timer / aiming_system.reload_time) * 100
		reload_bar.value = progress
