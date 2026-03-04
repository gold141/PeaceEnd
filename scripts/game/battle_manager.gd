# scripts/game/battle_manager.gd
# Центральный менеджер боя — регистрация юнитов, снаряды, урон
extends Node2D

@export var explosion_scene: PackedScene
@export var crater_scene: PackedScene
@export var dirt_burst_scene: PackedScene

@onready var aiming_system: Node2D = $AimingSystem
@onready var projectiles: Node2D = $Projectiles
@onready var hud: CanvasLayer = $HUD
@onready var action_panel: Control = $HUD/ActionPanel
@onready var infantry_placer: Node2D = $InfantryPlacer
@onready var economy: Node = $Economy
@onready var enemy_ai: Node = $EnemyAI

# Preloaded unit scripts
var unit_scripts = {
	"infantry": preload("res://scripts/game/infantry.gd"),
	"machine_gunner": preload("res://scripts/game/machine_gunner.gd"),
	"light_vehicle": preload("res://scripts/game/light_vehicle.gd"),
	"player_tank": preload("res://scripts/game/player_tank.gd"),
	"aa_gun": preload("res://scripts/game/aa_gun.gd"),
	"manpads": preload("res://scripts/game/manpads.gd"),
	"enemy_infantry": preload("res://scripts/game/enemy_infantry.gd"),
	"enemy_tank": preload("res://scripts/game/enemy_tank.gd"),
	"enemy_apc": preload("res://scripts/game/enemy_apc.gd"),
	"fighter_jet": preload("res://scripts/game/fighter_jet.gd"),
	"attack_helicopter": preload("res://scripts/game/attack_helicopter.gd"),
	"kamikaze_drone": preload("res://scripts/game/kamikaze_drone.gd"),
}

# Preloaded projectile scenes
var projectile_scenes = {
	"shell": preload("res://scenes/projectiles/projectile.tscn"),
	"rocket": preload("res://scenes/projectiles/rocket.tscn"),
	"bullet": preload("res://scenes/projectiles/bullet.tscn"),
	"bomb": preload("res://scenes/projectiles/bomb.tscn"),
	"aa_missile": preload("res://scenes/projectiles/aa_missile.tscn"),
}

const GROUND_Y: float = 450.0
const BLAST_RADIUS: float = 45.0

# Placement state
var placing_unit_type: String = ""


func _ready() -> void:
	aiming_system.projectiles_container = projectiles
	aiming_system.fired.connect(_on_projectile_fired)
	hud.setup(aiming_system, economy)

	action_panel.unit_selected.connect(_on_unit_selected)
	action_panel.unit_deselected.connect(_on_unit_deselected)
	action_panel.setup_economy(economy)

	infantry_placer.infantry_placed.connect(_on_unit_placed)

	enemy_ai.setup(self, economy)


# === SPAWN SYSTEM ===

func spawn_unit(unit_type: String, pos: Vector2, team: String) -> Node2D:
	var script = unit_scripts.get(unit_type)
	if not script:
		return null

	var unit: Node2D

	# Танки и машины — StaticBody2D для столкновений со снарядами
	if unit_type in ["enemy_tank", "player_tank", "light_vehicle", "enemy_apc"]:
		unit = StaticBody2D.new()
		unit.collision_layer = 1
		unit.collision_mask = 2
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		if unit_type in ["enemy_tank", "player_tank"]:
			rect.size = Vector2(60, 36)
		elif unit_type == "enemy_apc":
			rect.size = Vector2(70, 30)
		else:
			rect.size = Vector2(50, 28)
		shape.shape = rect
		unit.add_child(shape)
	else:
		unit = Node2D.new()

	unit.set_script(script)
	unit.global_position = pos

	# Передаём ссылки через стандартный метод
	if unit.has_method("setup_battle"):
		unit.setup_battle(projectiles, projectile_scenes, self)

	add_child(unit)

	# Подключаем сигналы
	if unit.has_signal("fired_projectile"):
		unit.fired_projectile.connect(_on_unit_projectile)
	if unit.has_signal("fired_rocket"):
		unit.fired_rocket.connect(_on_unit_projectile)
	if unit.has_signal("fired_bullet"):
		unit.fired_bullet.connect(_on_unit_projectile)
	if unit.has_signal("fired_bomb"):
		unit.fired_bomb.connect(_on_unit_projectile)
	if unit.has_signal("fired_missile"):
		unit.fired_missile.connect(_on_unit_projectile)
	if unit.has_signal("destroyed"):
		unit.destroyed.connect(_on_unit_destroyed.bind(unit, unit_type, team))
	if unit.has_signal("spawn_units"):
		unit.spawn_units.connect(_on_spawn_units)

	return unit


# === PLAYER ACTIONS ===

func _on_unit_selected(unit_id: String) -> void:
	if not economy.can_player_afford(unit_id):
		action_panel.selected_id = ""
		action_panel.queue_redraw()
		return

	placing_unit_type = unit_id

	if unit_id == "aa_gun":
		# AA размещается как пехота — выбор позиции
		infantry_placer.start_placing()
		aiming_system.input_blocked = true
	elif unit_id in ["infantry", "machine_gunner", "manpads"]:
		# Пешие юниты идут с левого края
		economy.player_spend(unit_id)
		spawn_unit(unit_id, Vector2(-30.0, GROUND_Y), "player")
		_finish_placement()
	elif unit_id in ["light_vehicle", "player_tank"]:
		# Техника едет с левого края
		economy.player_spend(unit_id)
		spawn_unit(unit_id, Vector2(-60.0, GROUND_Y - 2), "player")
		_finish_placement()
	else:
		_finish_placement()


func _on_unit_deselected() -> void:
	infantry_placer.stop_placing()
	aiming_system.input_blocked = false
	placing_unit_type = ""


func _on_unit_placed(pos: Vector2) -> void:
	if placing_unit_type != "" and economy.player_spend(placing_unit_type):
		spawn_unit(placing_unit_type, pos, "player")
	_finish_placement()


func _finish_placement() -> void:
	action_panel.selected_id = ""
	action_panel.queue_redraw()
	aiming_system.input_blocked = false
	placing_unit_type = ""


# === ENEMY SPAWNING ===

func spawn_enemy_unit(unit_type: String) -> Node2D:
	if not economy.enemy_spend(unit_type):
		return null

	var pos: Vector2
	match unit_type:
		"fighter_jet":
			pos = Vector2(1350, randf_range(80, 140))
		"attack_helicopter":
			pos = Vector2(1350, randf_range(120, 180))
		"kamikaze_drone":
			pos = Vector2(1350, randf_range(100, 200))
		"enemy_tank", "enemy_apc":
			pos = Vector2(1350, GROUND_Y - 2)
		_:
			pos = Vector2(1320, GROUND_Y)

	return spawn_unit(unit_type, pos, "enemy")


# === PROJECTILE & DAMAGE ===

func _on_projectile_fired(_angle: float, _power: float) -> void:
	var proj = projectiles.get_child(projectiles.get_child_count() - 1)
	if proj.has_signal("hit"):
		proj.hit.connect(_on_projectile_hit)


func _on_unit_projectile(proj: Node2D) -> void:
	if proj.has_signal("hit"):
		if not proj.hit.is_connected(_on_projectile_hit):
			proj.hit.connect(_on_projectile_hit)


func _on_projectile_hit(pos: Vector2, body: Node2D) -> void:
	var hit_vehicle = body.is_in_group("enemy_tanks") or body.is_in_group("player_vehicles")

	# Взрыв
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = pos
		add_child(explosion)

	# Кратеры только при попадании в землю
	if not hit_vehicle:
		if dirt_burst_scene:
			var dirt = dirt_burst_scene.instantiate()
			dirt.global_position = pos
			add_child(dirt)
		if crater_scene:
			var crater = crater_scene.instantiate()
			crater.global_position = pos
			add_child(crater)

	# Прямой урон
	if body.has_method("take_damage"):
		body.take_damage(1)

	# Осколочный урон по всем юнитам в радиусе
	_apply_blast_damage(pos, BLAST_RADIUS, body)


func _apply_blast_damage(pos: Vector2, radius: float, exclude: Node2D) -> void:
	var damaged: Array = []  # Избегаем двойного урона от перекрёстных групп
	var all_groups = ["infantry", "player_units", "player_vehicles", "enemy_infantry_group", "enemy_tanks", "air_units"]
	for group_name in all_groups:
		for unit in get_tree().get_nodes_in_group(group_name):
			if unit == exclude or unit in damaged:
				continue
			if not unit.has_method("take_damage"):
				continue
			if "alive" in unit and not unit.alive:
				continue
			if unit.global_position.distance_to(pos) <= radius:
				unit.take_damage(1)
				damaged.append(unit)


func _on_unit_destroyed(unit: Node2D, unit_type: String, team: String) -> void:
	# Большой взрыв при уничтожении техники
	if explosion_scene and unit_type in ["enemy_tank", "player_tank", "light_vehicle", "enemy_apc", "attack_helicopter"]:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = unit.global_position
		explosion.end_scale = 0.35
		explosion.duration = 1.0
		add_child(explosion)

	# Бонус за убийство
	if team == "enemy":
		economy.player_earn_kill(unit_type)
	elif team == "player":
		economy.enemy_earn_kill(unit_type)


func _on_spawn_units(unit_type: String, positions: Array, team: String) -> void:
	for pos in positions:
		spawn_unit(unit_type, pos, team)
