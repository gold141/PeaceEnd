# Unit Expansion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand PeaceEnd from 2 unit types to 12+ with economy, AI spawner, air combat, and anti-air.

**Architecture:** Dynamic unit registration via groups and signals. Economy system tracks money for both sides. Enemy AI spawner creates units on a timer with strategic logic. All units use procedural `_draw()` — no sprite textures. New projectile types (bullet, bomb, AA missile) extend the existing pattern.

**Tech Stack:** Godot 4.6.1, GDScript, procedural drawing, manual parabolic physics.

**Design doc:** `docs/plans/2026-03-04-unit-expansion-design.md`

---

## Phase 1: Core Infrastructure

### Task 1: New Projectile Scenes

Create 3 new projectile scenes matching the existing `projectile.tscn` and `rocket.tscn` pattern.

**Files:**
- Create: `scenes/projectiles/bullet.tscn`
- Create: `scenes/projectiles/bomb.tscn`
- Create: `scenes/projectiles/aa_missile.tscn`

**Step 1: Create bullet.tscn**

```tscn
[gd_scene load_steps=3 format=3 uid="uid://c1bullet"]

[ext_resource type="Script" path="res://scripts/game/bullet.gd" id="1_script"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 2.0

[node name="Bullet" type="Area2D"]
collision_layer = 2
collision_mask = 1
monitoring = true
monitorable = true
script = ExtResource("1_script")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]
```

**Step 2: Create bomb.tscn**

```tscn
[gd_scene load_steps=3 format=3 uid="uid://c1bomb"]

[ext_resource type="Script" path="res://scripts/game/bomb.gd" id="1_script"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 6.0

[node name="Bomb" type="Area2D"]
collision_layer = 2
collision_mask = 1
monitoring = true
monitorable = true
script = ExtResource("1_script")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]
```

**Step 3: Create aa_missile.tscn**

```tscn
[gd_scene load_steps=3 format=3 uid="uid://c1aamissile"]

[ext_resource type="Script" path="res://scripts/game/aa_missile.gd" id="1_script"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 3.0

[node name="AAMissile" type="Area2D"]
collision_layer = 2
collision_mask = 1
monitoring = true
monitorable = true
script = ExtResource("1_script")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]
```

**Step 4: Commit**
```bash
git add scenes/projectiles/bullet.tscn scenes/projectiles/bomb.tscn scenes/projectiles/aa_missile.tscn
git commit -m "feat: add bullet, bomb, and AA missile projectile scenes"
```

---

### Task 2: Projectile Scripts — bullet.gd

**Files:**
- Create: `scripts/game/bullet.gd`

Machine gun / rifle bullet — fast, nearly straight, thin trail.

```gdscript
# scripts/game/bullet.gd
# Пуля — быстрая, почти прямая, тонкий шлейф
extends Area2D

@export var gravity_force: float = 30.0
@export var air_drag: float = 0.05
@export var trail_color: Color = Color(1.0, 0.95, 0.5)

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false
var is_enemy: bool = false
var damage: float = 0.3

var trail_points: Array = []
const TRAIL_LENGTH: int = 15
const TRAIL_LIFETIME: float = 0.3
const TRAIL_MAX_WIDTH: float = 1.0

signal hit(position: Vector2, body: Node2D)
signal off_screen()


func launch(angle_deg: float, power: float) -> void:
	var angle_rad = deg_to_rad(angle_deg)
	velocity.x = power * cos(angle_rad)
	velocity.y = -power * sin(angle_rad)
	launched = true


func _process(delta: float) -> void:
	if not launched:
		return

	velocity -= velocity * air_drag * delta
	velocity.y += gravity_force * delta
	position += velocity * delta
	rotation = velocity.angle()

	trail_points.append({"pos": global_position, "age": 0.0})
	if trail_points.size() > TRAIL_LENGTH:
		trail_points.pop_front()

	var i = 0
	while i < trail_points.size():
		trail_points[i]["age"] += delta
		if trail_points[i]["age"] >= TRAIL_LIFETIME:
			trail_points.remove_at(i)
		else:
			i += 1

	queue_redraw()

	if position.y > 600 or position.x > 1400 or position.x < -100:
		off_screen.emit()
		queue_free()


func _draw() -> void:
	# Тело пули
	draw_circle(Vector2.ZERO, 1.5, Color(0.8, 0.75, 0.4))

	var count = trail_points.size()
	if count < 2:
		return

	for i in range(1, count):
		var t = float(i) / float(count - 1)
		var age_alpha = 1.0 - trail_points[i]["age"] / TRAIL_LIFETIME
		var alpha = t * age_alpha * 0.6
		var width = t * TRAIL_MAX_WIDTH * age_alpha

		var from = to_local(trail_points[i - 1]["pos"])
		var to = to_local(trail_points[i]["pos"])
		draw_line(from, to, Color(trail_color.r, trail_color.g, trail_color.b, alpha), maxf(width, 0.3))


func _on_body_entered(body: Node2D) -> void:
	if is_enemy and body.is_in_group("enemy_tanks"):
		return
	if not is_enemy and body.is_in_group("player_units"):
		return
	hit.emit(global_position, body)
	queue_free()
```

**Commit:** `git add scripts/game/bullet.gd && git commit -m "feat: add bullet projectile script"`

---

### Task 3: Projectile Scripts — bomb.gd

**Files:**
- Create: `scripts/game/bomb.gd`

Bomb dropped from aircraft — falls with gravity, large blast radius.

```gdscript
# scripts/game/bomb.gd
# Авиабомба — падает с гравитацией, большой радиус взрыва
extends Area2D

@export var gravity_force: float = 300.0
@export var air_drag: float = 0.02

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false
var is_enemy: bool = true
var damage: float = 3.0
var blast_radius: float = 80.0

signal hit(position: Vector2, body: Node2D)
signal off_screen()


func launch(horizontal_speed: float = 0.0, vertical_speed: float = 0.0) -> void:
	velocity = Vector2(horizontal_speed, vertical_speed)
	launched = true


func _process(delta: float) -> void:
	if not launched:
		return

	velocity -= velocity * air_drag * delta
	velocity.y += gravity_force * delta
	position += velocity * delta
	rotation = velocity.angle()
	queue_redraw()

	if position.y > 600 or position.x > 1400 or position.x < -100:
		off_screen.emit()
		queue_free()


func _draw() -> void:
	# Корпус бомбы
	draw_rect(Rect2(-3, -6, 6, 12), Color(0.3, 0.3, 0.28))
	# Стабилизаторы
	draw_line(Vector2(-4, -6), Vector2(0, -10), Color(0.4, 0.4, 0.35), 1.5)
	draw_line(Vector2(4, -6), Vector2(0, -10), Color(0.4, 0.4, 0.35), 1.5)
	# Носик
	draw_circle(Vector2(0, 6), 3.0, Color(0.5, 0.2, 0.15))


func _on_body_entered(body: Node2D) -> void:
	hit.emit(global_position, body)
	queue_free()
```

**Commit:** `git add scripts/game/bomb.gd && git commit -m "feat: add bomb projectile script"`

---

### Task 4: Projectile Scripts — aa_missile.gd

**Files:**
- Create: `scripts/game/aa_missile.gd`

Guided AA missile — tracks air target, white smoke trail.

```gdscript
# scripts/game/aa_missile.gd
# Зенитная ракета — наводится на воздушную цель, белый дымовой шлейф
extends Area2D

@export var speed: float = 500.0
@export var turn_rate: float = 3.5
@export var lifetime: float = 4.0

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false
var is_enemy: bool = false
var damage: float = 3.0
var target: Node2D = null
var age: float = 0.0

var trail_points: Array = []
const TRAIL_LENGTH: int = 30
const TRAIL_LIFETIME: float = 0.8
const TRAIL_MAX_WIDTH: float = 2.5

signal hit(position: Vector2, body: Node2D)
signal off_screen()


func launch_at(target_node: Node2D, initial_dir: Vector2) -> void:
	target = target_node
	velocity = initial_dir.normalized() * speed
	launched = true
	age = 0.0


func _process(delta: float) -> void:
	if not launched:
		return

	age += delta
	if age >= lifetime:
		queue_free()
		return

	# Наведение на цель
	if is_instance_valid(target) and target.has_method("take_damage"):
		var to_target = (target.global_position - global_position).normalized()
		var current_dir = velocity.normalized()
		var new_dir = current_dir.lerp(to_target, turn_rate * delta).normalized()
		velocity = new_dir * speed

	position += velocity * delta
	rotation = velocity.angle()

	trail_points.append({"pos": global_position, "age": 0.0})
	if trail_points.size() > TRAIL_LENGTH:
		trail_points.pop_front()

	var i = 0
	while i < trail_points.size():
		trail_points[i]["age"] += delta
		if trail_points[i]["age"] >= TRAIL_LIFETIME:
			trail_points.remove_at(i)
		else:
			i += 1

	queue_redraw()

	if position.y > 600 or position.y < -100 or position.x > 1400 or position.x < -100:
		off_screen.emit()
		queue_free()


func _draw() -> void:
	# Тело ракеты
	draw_rect(Rect2(-4, -1.5, 8, 3), Color(0.7, 0.7, 0.65))
	# Головка
	draw_circle(Vector2(5, 0), 2.0, Color(0.85, 0.3, 0.2))
	# Стабилизаторы
	draw_line(Vector2(-4, 0), Vector2(-7, -3), Color(0.5, 0.5, 0.45), 1.5)
	draw_line(Vector2(-4, 0), Vector2(-7, 3), Color(0.5, 0.5, 0.45), 1.5)

	# Двигатель
	var flicker = randf_range(0.6, 1.0)
	draw_circle(Vector2(-6, 0), 2.5 * flicker, Color(1.0, 0.7, 0.2, 0.9))

	# Шлейф
	var count = trail_points.size()
	if count < 2:
		return

	for j in range(1, count):
		var t = float(j) / float(count - 1)
		var age_alpha = 1.0 - trail_points[j]["age"] / TRAIL_LIFETIME
		var alpha = t * age_alpha * 0.5
		var width = t * TRAIL_MAX_WIDTH * age_alpha

		var from = to_local(trail_points[j - 1]["pos"])
		var to = to_local(trail_points[j]["pos"])
		draw_line(from, to, Color(0.85, 0.85, 0.8, alpha), maxf(width, 0.3))


func _on_body_entered(body: Node2D) -> void:
	hit.emit(global_position, body)
	queue_free()
```

**Commit:** `git add scripts/game/aa_missile.gd && git commit -m "feat: add AA missile guided projectile"`

---

### Task 5: Economy System

**Files:**
- Create: `scripts/game/economy.gd`

Standalone economy manager — tracks money, income, costs for both sides.

```gdscript
# scripts/game/economy.gd
# Экономика — деньги, доход, расходы для обеих сторон
extends Node

signal player_money_changed(amount: int)
signal enemy_money_changed(amount: int)

var player_money: int = 300
var enemy_money: int = 400

var player_income: float = 15.0  # $/s
var enemy_income: float = 18.0   # $/s

var _player_income_acc: float = 0.0
var _enemy_income_acc: float = 0.0

# Стоимости юнитов
const UNIT_COSTS = {
	"infantry": 100,
	"machine_gunner": 80,
	"light_vehicle": 200,
	"player_tank": 400,
	"aa_gun": 250,
	"manpads": 150,
	"enemy_infantry": 80,
	"enemy_tank": 350,
	"enemy_apc": 250,
	"fighter_jet": 300,
	"attack_helicopter": 350,
	"kamikaze_drone": 120,
}

# Бонус за убийство (30% стоимости жертвы)
const KILL_BONUS_PERCENT: float = 0.3


func _process(delta: float) -> void:
	_player_income_acc += player_income * delta
	_enemy_income_acc += enemy_income * delta

	if _player_income_acc >= 1.0:
		var earned = int(_player_income_acc)
		_player_income_acc -= earned
		player_money += earned
		player_money_changed.emit(player_money)

	if _enemy_income_acc >= 1.0:
		var earned = int(_enemy_income_acc)
		_enemy_income_acc -= earned
		enemy_money += earned
		enemy_money_changed.emit(enemy_money)


func can_player_afford(unit_type: String) -> bool:
	return player_money >= UNIT_COSTS.get(unit_type, 99999)


func can_enemy_afford(unit_type: String) -> bool:
	return enemy_money >= UNIT_COSTS.get(unit_type, 99999)


func player_spend(unit_type: String) -> bool:
	var cost = UNIT_COSTS.get(unit_type, 0)
	if player_money >= cost:
		player_money -= cost
		player_money_changed.emit(player_money)
		return true
	return false


func enemy_spend(unit_type: String) -> bool:
	var cost = UNIT_COSTS.get(unit_type, 0)
	if enemy_money >= cost:
		enemy_money -= cost
		enemy_money_changed.emit(enemy_money)
		return true
	return false


func player_earn_kill(killed_unit_type: String) -> void:
	var cost = UNIT_COSTS.get(killed_unit_type, 0)
	var bonus = int(cost * KILL_BONUS_PERCENT)
	if bonus > 0:
		player_money += bonus
		player_money_changed.emit(player_money)


func enemy_earn_kill(killed_unit_type: String) -> void:
	var cost = UNIT_COSTS.get(killed_unit_type, 0)
	var bonus = int(cost * KILL_BONUS_PERCENT)
	if bonus > 0:
		enemy_money += bonus
		enemy_money_changed.emit(enemy_money)


func get_cost(unit_type: String) -> int:
	return UNIT_COSTS.get(unit_type, 0)
```

**Commit:** `git add scripts/game/economy.gd && git commit -m "feat: add economy system with income and unit costs"`

---

### Task 6: Refactor battle_manager.gd — Dynamic Unit Registration

**Files:**
- Modify: `scripts/game/battle_manager.gd` (complete rewrite)

The new battle_manager supports dynamic registration of any unit type. Units register via groups. Projectile hits check all damageable units.

```gdscript
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
const BOMB_BLAST_RADIUS: float = 80.0

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

	# Setup enemy AI
	enemy_ai.setup(self, economy)


func spawn_unit(unit_type: String, pos: Vector2, team: String) -> Node2D:
	var script = unit_scripts.get(unit_type)
	if not script:
		return null

	var unit: Node2D
	# Определяем нужен ли StaticBody2D (для танков с коллизией)
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

	# Передаём ссылки
	if unit.has_method("setup_battle"):
		unit.setup_battle(projectiles, projectile_scenes, self)

	add_child(unit)

	# Подключаем сигналы
	if unit.has_signal("fired_projectile"):
		unit.fired_projectile.connect(_on_unit_projectile)
	if unit.has_signal("destroyed"):
		unit.destroyed.connect(_on_unit_destroyed.bind(unit, unit_type, team))
	if unit.has_signal("fired_rocket"):
		unit.fired_rocket.connect(_on_unit_projectile)

	return unit


func _on_projectile_fired(_angle: float, _power: float) -> void:
	var proj = projectiles.get_child(projectiles.get_child_count() - 1)
	proj.hit.connect(_on_projectile_hit)


func _on_unit_projectile(proj: Node2D) -> void:
	if proj.has_signal("hit"):
		proj.hit.connect(_on_projectile_hit)


func _on_projectile_hit(pos: Vector2, body: Node2D) -> void:
	var hit_vehicle = body.is_in_group("enemy_tanks") or body.is_in_group("player_vehicles")

	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = pos
		add_child(explosion)

	if not hit_vehicle:
		if dirt_burst_scene:
			var dirt = dirt_burst_scene.instantiate()
			dirt.global_position = pos
			add_child(dirt)
		if crater_scene:
			var crater = crater_scene.instantiate()
			crater.global_position = pos
			add_child(crater)

	# Урон по юниту, в который попали напрямую
	if body.has_method("take_damage"):
		var dmg = 1.0
		body.take_damage(dmg)

	# Определяем радиус взрыва
	var radius = BLAST_RADIUS

	# Осколочный урон по всем юнитам в радиусе
	var all_groups = ["infantry", "player_units", "enemy_infantry_group", "air_units"]
	for group_name in all_groups:
		for unit in get_tree().get_nodes_in_group(group_name):
			if unit == body:
				continue
			if not unit.has_method("take_damage"):
				continue
			if unit.has_method("is_alive") and not unit.is_alive():
				continue
			if "alive" in unit and not unit.alive:
				continue
			if unit.global_position.distance_to(pos) <= radius:
				unit.take_damage(1)


func _on_unit_destroyed(unit: Node2D, unit_type: String, team: String) -> void:
	# Взрыв при уничтожении
	if explosion_scene:
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


func _on_unit_selected(unit_id: String) -> void:
	if not economy.can_player_afford(unit_id):
		action_panel.selected_id = ""
		action_panel.queue_redraw()
		return

	placing_unit_type = unit_id

	if unit_id == "aa_gun":
		# AA gun is placed like infantry
		infantry_placer.start_placing()
		aiming_system.input_blocked = true
	elif unit_id in ["infantry", "machine_gunner", "manpads"]:
		# Walking units spawn at left edge
		economy.player_spend(unit_id)
		var spawn_x = -30.0
		spawn_unit(unit_id, Vector2(spawn_x, GROUND_Y), "player")
		action_panel.selected_id = ""
		action_panel.queue_redraw()
	elif unit_id in ["light_vehicle", "player_tank"]:
		# Driving units spawn at left edge
		economy.player_spend(unit_id)
		var spawn_x = -60.0
		spawn_unit(unit_id, Vector2(spawn_x, GROUND_Y - 2), "player")
		action_panel.selected_id = ""
		action_panel.queue_redraw()
	else:
		action_panel.selected_id = ""
		action_panel.queue_redraw()


func _on_unit_deselected() -> void:
	infantry_placer.stop_placing()
	aiming_system.input_blocked = false
	placing_unit_type = ""


func _on_unit_placed(pos: Vector2) -> void:
	if placing_unit_type != "" and economy.player_spend(placing_unit_type):
		spawn_unit(placing_unit_type, pos, "player")

	action_panel.selected_id = ""
	action_panel.queue_redraw()
	aiming_system.input_blocked = false
	placing_unit_type = ""


func spawn_enemy_unit(unit_type: String) -> Node2D:
	if not economy.enemy_spend(unit_type):
		return null

	var pos: Vector2
	if unit_type in ["fighter_jet"]:
		pos = Vector2(1350, randf_range(80, 140))
	elif unit_type in ["attack_helicopter"]:
		pos = Vector2(1350, randf_range(120, 180))
	elif unit_type in ["kamikaze_drone"]:
		pos = Vector2(1350, randf_range(100, 200))
	elif unit_type in ["enemy_tank", "enemy_apc"]:
		pos = Vector2(1350, GROUND_Y - 2)
	else:
		pos = Vector2(1320, GROUND_Y)

	return spawn_unit(unit_type, pos, "enemy")
```

**Commit:** `git add scripts/game/battle_manager.gd && git commit -m "feat: refactor battle_manager for dynamic unit registration"`

---

### Task 7: Update action_panel.gd — 6 Unit Buttons with Costs

**Files:**
- Modify: `scripts/ui/action_panel.gd` (complete rewrite)

```gdscript
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
		var can_afford = economy and economy.can_player_afford(btn["id"])
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

		# Draw unit icon
		var cx = rect.position.x + rect.size.x * 0.5
		var cy = rect.position.y + 28
		_draw_unit_icon(btn["id"], Vector2(cx, cy), 0.7)

		# Draw cost text
		var cost_y = rect.position.y + rect.size.y - 18
		var cost_color = Color(0.9, 0.85, 0.3) if can_afford else Color(0.7, 0.2, 0.2)
		_draw_cost_indicator(Vector2(cx, cost_y), btn["cost"], cost_color)

		# Hotkey indicator
		var key_names = {KEY_Q: "Q", KEY_W: "W", KEY_E: "E", KEY_R: "R", KEY_T: "T", KEY_Y: "Y"}
		var key_str = key_names.get(btn["hotkey"], "")
		if key_str != "":
			var key_pos = Vector2(rect.position.x + 6, rect.position.y + 10)
			draw_circle(key_pos, 7, Color(0.15, 0.15, 0.15, 0.8))
			# Small dot to hint the key
			draw_circle(key_pos, 2, Color(0.7, 0.7, 0.6))


func _draw_unit_icon(unit_id: String, center: Vector2, s: float) -> void:
	match unit_id:
		"infantry":
			# Soldier with RPG
			draw_circle(center + Vector2(0, -10) * s, 4.0 * s, Color(0.55, 0.5, 0.4))
			draw_rect(Rect2(center + Vector2(-3, -5) * s, Vector2(6, 10) * s), Color(0.3, 0.35, 0.25))
			draw_line(center + Vector2(3, -4) * s, center + Vector2(10, -8) * s, Color(0.3, 0.32, 0.25), 2.0 * s)
		"machine_gunner":
			# Soldier with MG on tripod
			draw_circle(center + Vector2(0, -10) * s, 4.0 * s, Color(0.55, 0.5, 0.4))
			draw_rect(Rect2(center + Vector2(-3, -5) * s, Vector2(6, 10) * s), Color(0.3, 0.35, 0.25))
			# Tripod
			draw_line(center + Vector2(-4, 5) * s, center + Vector2(-8, 10) * s, Color(0.3, 0.3, 0.28), 1.5 * s)
			draw_line(center + Vector2(4, 5) * s, center + Vector2(8, 10) * s, Color(0.3, 0.3, 0.28), 1.5 * s)
			# MG barrel
			draw_line(center + Vector2(0, 2) * s, center + Vector2(12, -2) * s, Color(0.2, 0.2, 0.18), 2.5 * s)
		"light_vehicle":
			# Pickup truck
			draw_rect(Rect2(center + Vector2(-10, -4) * s, Vector2(20, 8) * s), Color(0.45, 0.5, 0.35))
			draw_circle(center + Vector2(-6, 5) * s, 3.0 * s, Color(0.2, 0.2, 0.18))
			draw_circle(center + Vector2(6, 5) * s, 3.0 * s, Color(0.2, 0.2, 0.18))
			# Gun
			draw_line(center + Vector2(2, -4) * s, center + Vector2(10, -8) * s, Color(0.3, 0.3, 0.28), 2.0 * s)
		"player_tank":
			# Tank
			draw_rect(Rect2(center + Vector2(-10, 0) * s, Vector2(20, 6) * s), Color(0.2, 0.2, 0.18))
			draw_rect(Rect2(center + Vector2(-9, -5) * s, Vector2(18, 7) * s), Color(0.35, 0.4, 0.3))
			draw_rect(Rect2(center + Vector2(-4, -10) * s, Vector2(10, 6) * s), Color(0.3, 0.35, 0.25))
			draw_line(center + Vector2(6, -8) * s, center + Vector2(14, -8) * s, Color(0.3, 0.35, 0.25), 2.5 * s)
		"aa_gun":
			# AA emplacement
			draw_rect(Rect2(center + Vector2(-8, 2) * s, Vector2(16, 6) * s), Color(0.6, 0.5, 0.3))
			# Twin barrels pointing up
			draw_line(center + Vector2(-2, 0) * s, center + Vector2(-4, -12) * s, Color(0.3, 0.3, 0.28), 2.0 * s)
			draw_line(center + Vector2(2, 0) * s, center + Vector2(4, -12) * s, Color(0.3, 0.3, 0.28), 2.0 * s)
		"manpads":
			# Soldier with tube on shoulder
			draw_circle(center + Vector2(0, -10) * s, 4.0 * s, Color(0.55, 0.5, 0.4))
			draw_rect(Rect2(center + Vector2(-3, -5) * s, Vector2(6, 10) * s), Color(0.3, 0.35, 0.25))
			# Tube
			draw_line(center + Vector2(-2, -6) * s, center + Vector2(10, -14) * s, Color(0.25, 0.4, 0.25), 3.0 * s)


func _draw_cost_indicator(center: Vector2, cost: int, color: Color) -> void:
	# Simple cost display using geometric shapes
	# Dollar sign as a circle with line
	draw_circle(center + Vector2(-14, 0), 5, Color(0.15, 0.15, 0.15, 0.6))
	draw_circle(center + Vector2(-14, 0), 3, Color(color, 0.8))

	# Cost bars (each bar = $100)
	var bars = ceili(cost / 100.0)
	var bar_w = 5.0
	var total_w = bars * bar_w + (bars - 1) * 1.5
	var start_x = center.x - total_w * 0.5 + 4
	for i in range(bars):
		var bx = start_x + i * (bar_w + 1.5)
		draw_rect(Rect2(bx, center.y - 3, bar_w, 6), Color(color, 0.7))
```

**Commit:** `git add scripts/ui/action_panel.gd && git commit -m "feat: expand action panel to 6 unit buttons with costs"`

---

### Task 8: Update hud.gd — Money Display

**Files:**
- Modify: `scripts/ui/hud.gd`

Add money counter display in top-right corner.

Add after existing vars at top:
```gdscript
var economy: Node
var money_display: float = 300.0
```

Change `setup` signature:
```gdscript
func setup(aim_sys: Node2D, econ: Node = null) -> void:
	aiming_system = aim_sys
	economy = econ
	aiming_system.charge_changed.connect(_on_charge_changed)
	for i in range(charge_buttons.size()):
		charge_buttons[i].pressed.connect(_on_charge_button.bind(i))
	aiming_system.set_charge(0)
```

Add to end of `_process`:
```gdscript
	if economy:
		money_display = economy.player_money
```

Add a `_draw` method to the HUD's CanvasLayer — but CanvasLayer can't draw. Instead, add a custom Control node for money. We'll do this via the MoneyLabel approach:

Actually, simpler: add a Label node to HUD in battle.tscn and update it in _process.

**In hud.gd, add to _process:**
```gdscript
	if economy:
		$MoneyLabel.text = "$%d  (+%d/s)" % [economy.player_money, int(economy.player_income)]
```

**In battle.tscn, add MoneyLabel node under HUD.**

**Commit:** `git add scripts/ui/hud.gd && git commit -m "feat: add money display to HUD"`

---

### Task 9: Update battle.tscn — Remove Hardcoded Tanks, Add Economy & AI

**Files:**
- Modify: `scenes/game/battle.tscn`

Remove the 3 hardcoded EnemyTank nodes. Add Economy and EnemyAI nodes. Add MoneyLabel to HUD.

This is a major scene edit — the new battle.tscn should have this structure:
```
Battle (Node2D) [battle_manager.gd]
├── Background (ColorRect)
├── Terrain (Node2D) [destructible_terrain.gd]
├── AimingSystem (Node2D @ 100,425) [aiming_system.gd]
├── Projectiles (Node2D)
├── Economy (Node) [economy.gd]
├── EnemyAI (Node) [enemy_ai.gd]
├── HUD (CanvasLayer) [hud.gd]
│   ├── AngleLabel, PowerLabel, ReloadBar, ChargePanel (existing)
│   ├── MoneyLabel (new, top-right)
│   └── ActionPanel (updated)
├── InfantryPlacer (Node2D)
└── RangeVisualizer (Node2D)
```

**Commit:** `git add scenes/game/battle.tscn && git commit -m "feat: update battle scene with economy, AI, remove hardcoded tanks"`

---

## Phase 2: Player Units

### Task 10: infantry.gd — Add Walking Entry

**Files:**
- Modify: `scripts/game/infantry.gd`

Add walk-in behavior: unit spawns at left edge, walks right to a "deploy position", then sets up. Add `setup_battle()` method for new registration system. Add `unit_type` var.

Key changes:
- Add `var unit_type: String = "infantry"`
- Add `var team: String = "player"`
- Add `var walk_speed: float = 30.0`
- Add `var deploy_x: float = -1.0` (set randomly between 100-500)
- Add `var deployed: bool = false`
- Add `func setup_battle(proj_container, proj_scenes, _manager)` that sets rocket_scene and projectiles_container
- In `_process`: if not deployed, walk right; once past deploy_x, deploy (set deployed=true)
- Only fire when deployed
- Keep existing `_draw()` but add walking legs animation when not deployed

**Commit:** `git add scripts/game/infantry.gd && git commit -m "feat: infantry walks in from left edge before deploying"`

---

### Task 11: machine_gunner.gd

**Files:**
- Create: `scripts/game/machine_gunner.gd`

Machine gunner — high rate of fire, targets infantry and drones. Walks from left, deploys behind sandbags.

Key specs:
- HP: 2, fire_range: 250, fire_interval: 0.25s, damage: 0.3
- Targets: enemy_infantry_group, air_units (drones only, 20% accuracy)
- Fires bullets (fast, straight)
- Visual: Soldier behind sandbags with MG on tripod, rapid muzzle flash
- Walk speed: 30 px/s, deploys at random 80-400 px
- Groups: "player_units", "infantry"

**Commit:** `git add scripts/game/machine_gunner.gd && git commit -m "feat: add machine gunner unit — rapid fire anti-infantry"`

---

### Task 12: light_vehicle.gd

**Files:**
- Create: `scripts/game/light_vehicle.gd`

Light vehicle (Technical) — fast, MG turret, moderate HP. Drives from left edge.

Key specs:
- HP: 5, speed: 80 px/s, fire_range: 350, fire_interval: 1.5s, damage: 1
- Targets: all ground enemies
- Fires bullets
- Visual: Pickup truck with mounted gun, 4 wheels, dust trail
- Groups: "player_units", "player_vehicles"
- StaticBody2D (has collision for projectile hits)
- Drives to random position 200-700 px, then stops and fires

**Commit:** `git add scripts/game/light_vehicle.gd && git commit -m "feat: add light vehicle (Technical) — fast MG truck"`

---

### Task 13: player_tank.gd

**Files:**
- Create: `scripts/game/player_tank.gd`

Player tank — heavy, slow, big gun. Drives from left edge.

Key specs:
- HP: 8, speed: 20 px/s, fire_range: 500, fire_interval: 4.0s, damage: 2
- Targets: all ground enemies
- Fires shells (same as player mortar projectile)
- Visual: Green/olive tank, barrel pointing RIGHT, mirror of enemy tank
- Groups: "player_units", "player_vehicles"
- StaticBody2D
- Drives to random position 150-500 px, then engages

**Commit:** `git add scripts/game/player_tank.gd && git commit -m "feat: add player tank — heavy armor, big gun"`

---

### Task 14: aa_gun.gd

**Files:**
- Create: `scripts/game/aa_gun.gd`

AA gun emplacement — placed like infantry, shoots at air targets.

Key specs:
- HP: 4, fire_range: 450, fire_interval: 0.4s, damage: 1.5
- Targets: air_units only (fighters, helis, drones)
- Fires AA bullets (fast, upward)
- Visual: Sandbag base with twin barrels, rotates to track target
- Groups: "player_units", "anti_air_units"
- Placed by player (not walking)

**Commit:** `git add scripts/game/aa_gun.gd && git commit -m "feat: add AA gun emplacement — anti-air defense"`

---

### Task 15: manpads.gd

**Files:**
- Create: `scripts/game/manpads.gd`

MANPADS soldier — walks from left, fires guided AA missiles.

Key specs:
- HP: 2, fire_range: 400, fire_interval: 5.0s, damage: 3
- Targets: air_units (guided missiles)
- Fires AA missiles (guided, tracks target)
- Visual: Kneeling soldier with tube on shoulder, backblast effect
- Walk speed: 30 px/s, deploys at random 80-350 px
- Groups: "player_units", "infantry", "anti_air_units"

**Commit:** `git add scripts/game/manpads.gd && git commit -m "feat: add MANPADS soldier — mobile anti-air missiles"`

---

## Phase 3: Enemy Units

### Task 16: enemy_tank.gd — Rework to Spawn from Edge

**Files:**
- Modify: `scripts/game/enemy_tank.gd`

Add `setup_battle()` method. Unit now spawns at X=1350 and drives left. Add `unit_type`, `team` vars. Target player_units and player_vehicles groups in addition to mortar position. Keep existing drawing and behavior.

Key changes:
- Add `var unit_type: String = "enemy_tank"`
- Add `var team: String = "enemy"`
- Add `func setup_battle(proj_container, proj_scenes, _manager)` that self-configures
- Update `_find_closest_target()` to check "player_units" and "player_vehicles" groups
- Remove dependence on `setup_firing()` from outside

**Commit:** `git add scripts/game/enemy_tank.gd && git commit -m "feat: rework enemy tank for dynamic spawning from right edge"`

---

### Task 17: enemy_infantry.gd

**Files:**
- Create: `scripts/game/enemy_infantry.gd`

Enemy infantry — walks from right, fires rifle at player units. Mirror of machine gunner but with rifle.

Key specs:
- HP: 2, speed: 30 px/s walk LEFT, fire_range: 250, fire_interval: 1.0s, damage: 0.3
- Targets: infantry, player_units (ground only)
- Fires rifle bullets (fast, left-facing)
- Visual: Dark-uniformed soldier with rifle, walks left, stops to fire
- Groups: "enemy_infantry_group", "enemy_units"
- Walks to random deploy position 700-1100 px

**Commit:** `git add scripts/game/enemy_infantry.gd && git commit -m "feat: add enemy infantry — rifles, walks from right"`

---

### Task 18: enemy_apc.gd

**Files:**
- Create: `scripts/game/enemy_apc.gd`

Enemy APC — drives from right, has MG, deploys 2 infantry when destroyed or at destination.

Key specs:
- HP: 6, speed: 40 px/s, fire_range: 200 (MG), fire_interval: 0.5s, damage: 0.3
- Targets: ground player units with MG
- On death or reaching deploy point: spawns 2 enemy_infantry
- Visual: Large armored box, 6 wheels, small turret
- Groups: "enemy_tanks" (for collision), "enemy_units"
- StaticBody2D

**Commit:** `git add scripts/game/enemy_apc.gd && git commit -m "feat: add enemy APC — armored transport deploys infantry"`

---

## Phase 4: Air Units

### Task 19: fighter_jet.gd

**Files:**
- Create: `scripts/game/fighter_jet.gd`

Fighter jet — flies fast across screen, drops bomb on target, exits other side. Single pass.

Key specs:
- HP: 3, speed: 300 px/s, bomb damage: 3, bomb blast: 80px
- Flies at Y=100-140, enters from right (X=1350)
- AI: Find most valuable ground cluster, drop bomb directly above
- When X reaches bomb target: drop bomb, continue flying left
- Exits at X=-50, then queue_free()
- Visual: Delta wing silhouette, engine trail, afterburner glow
- Groups: "air_units", "enemy_units"
- No collision body (hit by AA projectiles via area detection)

For AA to hit jets: jets should be Area2D or have an Area2D child that detects AA projectiles.

**Commit:** `git add scripts/game/fighter_jet.gd && git commit -m "feat: add fighter jet — fast bombing run"`

---

### Task 20: attack_helicopter.gd

**Files:**
- Create: `scripts/game/attack_helicopter.gd`

Attack helicopter — flies to combat zone, hovers, fires rockets downward.

Key specs:
- HP: 5, speed: 60 px/s, fire_range: 350, fire_interval: 2.0s, damage: 1.5
- Flies at Y=140-180, enters from right
- Hovers at random X (500-900), fires rockets at ground targets
- Retreats (flies right) when HP <= 2
- Visual: Fuselage body, spinning rotor line, rocket pods
- Fires rockets (similar to infantry RPG but angled down)
- Groups: "air_units", "enemy_units"

**Commit:** `git add scripts/game/attack_helicopter.gd && git commit -m "feat: add attack helicopter — hovering rocket platform"`

---

### Task 21: kamikaze_drone.gd

**Files:**
- Create: `scripts/game/kamikaze_drone.gd`

Kamikaze drone — flies toward target, dives into it, explodes.

Key specs:
- HP: 1, speed: 150 px/s, damage: 4 (on impact)
- Enters from right at Y=100-200
- AI: Find nearest high-value target (tanks > vehicles > infantry)
- Flies in straight line toward target, dives in final approach
- On contact: explode (damage 4 to target + blast radius 45px)
- Visual: Small X-shape quadcopter, propeller blur, red blink
- Groups: "air_units", "enemy_units"
- Very vulnerable to AA (1 HP)

**Commit:** `git add scripts/game/kamikaze_drone.gd && git commit -m "feat: add kamikaze drone — cheap suicide attacker"`

---

## Phase 5: AI & Integration

### Task 22: enemy_ai.gd — Enemy Spawner AI

**Files:**
- Create: `scripts/game/enemy_ai.gd`

The enemy AI evaluates the battlefield and spawns units to counter the player.

```gdscript
# scripts/game/enemy_ai.gd
# ИИ противника — оценивает поле боя, создаёт юнитов
extends Node

var battle_manager: Node2D
var economy: Node

var spawn_timer: float = 0.0
var spawn_interval: float = 3.0  # Seconds between spawn decisions
var wave_timer: float = 0.0
var wave_interval: float = 30.0  # Big wave every 30s

var initial_delay: float = 3.0  # Don't spawn immediately


func setup(manager: Node2D, econ: Node) -> void:
	battle_manager = manager
	economy = econ


func _process(delta: float) -> void:
	if not battle_manager or not economy:
		return

	initial_delay -= delta
	if initial_delay > 0:
		return

	spawn_timer += delta
	wave_timer += delta

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_evaluate_and_spawn()

	if wave_timer >= wave_interval:
		wave_timer = 0.0
		_spawn_wave()


func _evaluate_and_spawn() -> void:
	# Count player forces
	var player_ground = get_tree().get_nodes_in_group("player_units").size()
	var player_vehicles = get_tree().get_nodes_in_group("player_vehicles").size()
	var player_aa = get_tree().get_nodes_in_group("anti_air_units").size()
	var enemy_ground = get_tree().get_nodes_in_group("enemy_units").size()
	var enemy_air = get_tree().get_nodes_in_group("air_units").size()

	# Strategy: respond to player composition
	var options: Array = []

	# Always need ground presence
	if enemy_ground < 3:
		options.append("enemy_infantry")
		options.append("enemy_tank")

	# If player has many ground units, use area attacks
	if player_ground > 4 and player_aa < 2:
		options.append("fighter_jet")
		options.append("kamikaze_drone")

	# If player has AA, avoid air, push ground
	if player_aa >= 2:
		options.append("enemy_tank")
		options.append("enemy_apc")
		options.append("enemy_infantry")
	else:
		# No AA? Air dominance!
		options.append("attack_helicopter")
		options.append("kamikaze_drone")
		options.append("fighter_jet")

	# If player has tanks, need anti-tank
	if player_vehicles > 0:
		options.append("enemy_tank")

	# Default fallback
	if options.is_empty():
		options = ["enemy_infantry", "enemy_tank"]

	# Pick random option from available
	options.shuffle()
	for option in options:
		if economy.can_enemy_afford(option):
			battle_manager.spawn_enemy_unit(option)
			break


func _spawn_wave() -> void:
	# Spend up to 50% of current money in a wave
	var budget = economy.enemy_money / 2
	var wave_options = ["enemy_infantry", "enemy_tank", "enemy_apc", "kamikaze_drone"]
	wave_options.shuffle()

	var spent = 0
	for option in wave_options:
		var cost = economy.get_cost(option)
		while spent + cost <= budget and economy.can_enemy_afford(option):
			battle_manager.spawn_enemy_unit(option)
			spent += cost
			# Small delay between spawns (handled by staggering start positions)
```

**Commit:** `git add scripts/game/enemy_ai.gd && git commit -m "feat: add enemy AI spawner with strategic decisions"`

---

### Task 23: Update range_visualizer.gd for New Unit Types

**Files:**
- Modify: `scripts/game/range_visualizer.gd`

Add support for player_units, player_vehicles, air_units groups. Color-code by team.

Key changes:
- Check "player_units" group (green, fires right)
- Check "player_vehicles" group (green, fires right)
- Check "enemy_units" group (red, fires left)
- Check "air_units" group (orange, full circle)
- Handle units that have `fire_range` property

**Commit:** `git add scripts/game/range_visualizer.gd && git commit -m "feat: update range visualizer for all unit types"`

---

### Task 24: Final Integration & Scene Update

**Files:**
- Modify: `scenes/game/battle.tscn` (final version)

Write the complete battle.tscn with all new ext_resources, Economy and EnemyAI nodes, MoneyLabel, no hardcoded enemy tanks.

**Commit:** `git add scenes/game/battle.tscn && git commit -m "feat: final battle scene with economy, AI, all unit support"`

---

### Task 25: Balance Pass & Commit

Review all unit values, ensure game is playable:
- Test that economy provides enough for both sides to field units
- Verify projectile speeds feel right
- Check AA can actually hit air units
- Ensure no crashes from missing references

**Commit:** `git add -A && git commit -m "feat: balance pass — tune economy, damage, and spawn rates"`

---

## Agent Assignment

These tasks can be parallelized as follows:

**Sequential (must be first):** Tasks 1-9 (Core infrastructure)

**Parallel Group A (after core):**
- Agent 1: Tasks 10-15 (All player units)
- Agent 2: Tasks 16-18 (All enemy ground units)
- Agent 3: Tasks 19-21 (All air units)
- Agent 4: Task 22 (Enemy AI)

**Sequential (after all units):** Tasks 23-25 (Integration, range vis, balance)
