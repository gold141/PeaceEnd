# scripts/game/battle_manager.gd
extends Node2D

@export var explosion_scene: PackedScene
@export var crater_scene: PackedScene
@export var dirt_burst_scene: PackedScene

@onready var aiming_system: Node2D = $AimingSystem
@onready var projectiles: Node2D = $Projectiles
@onready var hud: CanvasLayer = $HUD
@onready var action_panel: Control = $HUD/ActionPanel
@onready var infantry_placer: Node2D = $InfantryPlacer

var infantry_script = preload("res://scripts/game/infantry.gd")
var rocket_scene = preload("res://scenes/projectiles/rocket.tscn")


func _ready() -> void:
	aiming_system.projectiles_container = projectiles
	aiming_system.fired.connect(_on_projectile_fired)
	hud.setup(aiming_system)

	# Панель действий
	action_panel.unit_selected.connect(_on_unit_selected)
	action_panel.unit_deselected.connect(_on_unit_deselected)

	# Система размещения пехоты
	infantry_placer.infantry_placed.connect(_on_infantry_placed)

	# Настраиваем танки
	for tank in get_tree().get_nodes_in_group("enemy_tanks"):
		tank.destroyed.connect(_on_tank_destroyed.bind(tank))
		tank.fired_projectile.connect(_on_enemy_projectile)
		tank.setup_firing(aiming_system.projectile_scene, aiming_system.global_position, projectiles)


func _on_projectile_fired(_angle: float, _power: float) -> void:
	var proj = projectiles.get_child(projectiles.get_child_count() - 1)
	proj.hit.connect(_on_projectile_hit)


func _on_enemy_projectile(proj: Node2D) -> void:
	proj.hit.connect(_on_projectile_hit)


func _on_infantry_rocket(rocket: Node2D) -> void:
	rocket.hit.connect(_on_projectile_hit)


func _on_projectile_hit(pos: Vector2, body: Node2D) -> void:
	var hit_tank = body.is_in_group("enemy_tanks")

	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = pos
		add_child(explosion)

	# Кратеры и земля только при попадании в землю
	if not hit_tank:
		if dirt_burst_scene:
			var dirt = dirt_burst_scene.instantiate()
			dirt.global_position = pos
			add_child(dirt)

		if crater_scene:
			var crater = crater_scene.instantiate()
			crater.global_position = pos
			add_child(crater)

	# Урон танку
	if hit_tank and body.has_method("take_damage"):
		body.take_damage()


func _on_unit_selected(unit_id: String) -> void:
	if unit_id == "infantry":
		infantry_placer.start_placing()
		aiming_system.input_blocked = true


func _on_unit_deselected() -> void:
	infantry_placer.stop_placing()
	aiming_system.input_blocked = false


func _on_infantry_placed(pos: Vector2) -> void:
	var unit = Node2D.new()
	unit.set_script(infantry_script)
	unit.global_position = pos
	# Даём пехоте ракету и контейнер
	unit.rocket_scene = rocket_scene
	unit.projectiles_container = projectiles
	add_child(unit)
	# Подключаем сигнал ракеты
	unit.fired_rocket.connect(_on_infantry_rocket)
	# Снимаем выделение с кнопки и разблокируем стрельбу
	action_panel.selected_id = ""
	action_panel.queue_redraw()
	aiming_system.input_blocked = false


func _on_tank_destroyed(tank: Node2D) -> void:
	if not explosion_scene:
		return
	var explosion = explosion_scene.instantiate()
	explosion.global_position = tank.global_position
	explosion.end_scale = 0.35
	explosion.duration = 1.0
	add_child(explosion)
