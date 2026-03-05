# Manual Unit Control Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow the player to click on any player unit to take direct control — movement (A/D), aiming (mouse), and firing (LMB) — using that unit's native capabilities.

**Architecture:** A new `unit_control.gd` node manages selection/input/visuals. Each player unit gets a `manually_controlled` flag and `manual_fire_at(pos)` method. When controlled, the unit's auto-fire is suppressed and the artillery aiming system is blocked.

**Tech Stack:** Godot 4.6.1, GDScript

---

### Task 1: Add manual control support to Infantry

**Files:**
- Modify: `scripts/game/infantry.gd`

**Step 1: Add manually_controlled flag and skip auto-fire**

At the top of the script, after `var walk_timer: float = 0.0`, add:

```gdscript
var manually_controlled: bool = false
```

In `_process()`, wrap the auto-fire section (lines 87-94) with a guard:

```gdscript
	# Развёрнуты — стреляем
	if not manually_controlled:
		fire_timer -= delta
		if fire_timer <= 0:
			fire_timer = fire_interval + randf_range(-0.3, 0.3)
			_try_fire()
	else:
		# Timer still ticks for reload tracking
		if fire_timer > 0:
			fire_timer -= delta
```

**Step 2: Add manual_fire_at method**

After `_try_fire()`, add:

```gdscript
func manual_fire_at(target_pos: Vector2) -> bool:
	if not alive or not deployed:
		return false
	if fire_timer > 0:
		return false
	if not rocket_scene or not projectiles_container:
		return false

	# Calculate angle to target (RPG-style: elevation based on distance)
	var distance = abs(target_pos.x - global_position.x)
	var elevation = remap(distance, 50.0, fire_range, 1.0, 6.0)
	elevation += randf_range(-spread_degrees, spread_degrees)
	elevation = clampf(elevation, -3.0, 8.0)

	var rocket = rocket_scene.instantiate()
	rocket.global_position = global_position + Vector2(18, -30)
	rocket.launch(elevation)
	projectiles_container.add_child(rocket)
	fired_rocket.emit(rocket)
	shots_fired += 1

	fire_timer = fire_interval
	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()
	return true
```

**Step 3: Commit**

```bash
git add scripts/game/infantry.gd
git commit -m "feat: add manual control support to infantry"
```

---

### Task 2: Add manual control support to Machine Gunner

**Files:**
- Modify: `scripts/game/machine_gunner.gd`

**Step 1: Add flag and skip auto-fire**

After `var walk_timer: float = 0.0`, add:

```gdscript
var manually_controlled: bool = false
```

In `_process()`, wrap auto-fire (lines 86-89):

```gdscript
	if not manually_controlled:
		fire_timer -= delta
		if fire_timer <= 0:
			fire_timer = fire_interval + randf_range(-0.03, 0.03)
			_try_fire()
	else:
		if fire_timer > 0:
			fire_timer -= delta
```

**Step 2: Add manual_fire_at method**

```gdscript
func manual_fire_at(target_pos: Vector2) -> bool:
	if not alive or not deployed:
		return false
	if fire_timer > 0:
		return false
	if not projectile_scenes.has("bullet") or not projectiles_container:
		return false

	var angle = randf_range(0.0, 3.0)
	angle += randf_range(-spread_degrees, spread_degrees)
	angle = clampf(angle, -2.0, 6.0)

	var bullet_scene = projectile_scenes["bullet"]
	var proj = bullet_scene.instantiate()
	proj.global_position = global_position + Vector2(26, -28)
	proj.damage = damage
	proj.launch(angle, 900.0)
	projectiles_container.add_child(proj)
	fired_bullet.emit(proj)
	shots_fired += 1

	fire_timer = fire_interval
	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()
	return true
```

**Step 3: Commit**

```bash
git add scripts/game/machine_gunner.gd
git commit -m "feat: add manual control support to machine gunner"
```

---

### Task 3: Add manual control support to Player Tank

**Files:**
- Modify: `scripts/game/player_tank.gd`

**Step 1: Add flag and skip auto-fire**

After `var smoke_spawn_timer: float = 0.0`, add:

```gdscript
var manually_controlled: bool = false
```

In `_process()`, wrap the deployed firing section (lines 87-97):

```gdscript
	elif alive and deployed:
		if not manually_controlled:
			var best_target = _find_closest_target()
			if best_target != Vector2.ZERO:
				fire_timer -= delta
				if fire_timer <= 0:
					fire_timer = fire_interval + randf_range(-0.5, 0.5)
					_fire_at(best_target)
		else:
			if fire_timer > 0:
				fire_timer -= delta

		if muzzle_flash_timer > 0:
			muzzle_flash_timer -= delta
			queue_redraw()
```

**Step 2: Add manual_fire_at method**

```gdscript
func manual_fire_at(target_pos: Vector2) -> bool:
	if not alive or not deployed:
		return false
	if fire_timer > 0:
		return false
	if not projectile_scenes.has("shell") or not projectiles_container:
		return false

	_fire_at(target_pos)
	fire_timer = fire_interval
	return true
```

Note: reuses existing `_fire_at()` which already handles parabolic calculation, spread, and muzzle flash.

**Step 3: Commit**

```bash
git add scripts/game/player_tank.gd
git commit -m "feat: add manual control support to player tank"
```

---

### Task 4: Add manual control support to Light Vehicle

**Files:**
- Modify: `scripts/game/light_vehicle.gd`

**Step 1: Add flag and skip auto-fire**

After `const SMOKE_DURATION: float = 30.0`, add:

```gdscript
var manually_controlled: bool = false
```

In `_process()`, wrap the deployed firing section (lines 93-102):

```gdscript
	elif alive and deployed:
		if not manually_controlled:
			fire_timer -= delta
			if fire_timer <= 0:
				fire_timer = fire_interval + randf_range(-0.2, 0.2)
				_try_fire()
		else:
			if fire_timer > 0:
				fire_timer -= delta

		if muzzle_flash_timer > 0:
			muzzle_flash_timer -= delta
			queue_redraw()
```

**Step 2: Add manual_fire_at method**

```gdscript
func manual_fire_at(target_pos: Vector2) -> bool:
	if not alive or not deployed:
		return false
	if fire_timer > 0:
		return false
	if not projectile_scenes.has("bullet") or not projectiles_container:
		return false

	var angle = randf_range(0.0, 5.0)
	angle += randf_range(-spread_degrees, spread_degrees)
	angle = clampf(angle, -3.0, 8.0)

	var bullet_scene = projectile_scenes["bullet"]
	var proj = bullet_scene.instantiate()
	proj.global_position = global_position + Vector2(16, -22)
	proj.damage = damage
	proj.launch(angle, 900.0)
	projectiles_container.add_child(proj)
	fired_bullet.emit(proj)
	shots_fired += 1

	fire_timer = fire_interval
	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()
	return true
```

**Step 3: Commit**

```bash
git add scripts/game/light_vehicle.gd
git commit -m "feat: add manual control support to light vehicle"
```

---

### Task 5: Add manual control support to AA Gun

**Files:**
- Modify: `scripts/game/aa_gun.gd`

**Step 1: Add flag and skip auto-targeting/firing**

After `const MUZZLE_FLASH_DURATION: float = 0.08`, add:

```gdscript
var manually_controlled: bool = false
var can_move: bool = false  # AA Gun is stationary
```

In `_process()`, wrap the target finding and firing (lines 63-78):

```gdscript
	if not manually_controlled:
		current_target = _find_air_target()

		if current_target:
			var to_target = current_target.global_position - global_position
			gun_angle = to_target.angle()
		else:
			gun_angle = lerp_angle(gun_angle, -PI / 2, delta * 2.0)

		fire_timer -= delta
		if fire_timer <= 0:
			fire_timer = fire_interval + randf_range(-0.05, 0.05)
			_try_fire()
	else:
		if fire_timer > 0:
			fire_timer -= delta
```

Note: when manually controlled, `gun_angle` and `current_target` are set externally by unit_control.gd.

**Step 2: Add manual_fire_at and manual_aim methods**

```gdscript
func manual_aim_at(target_pos: Vector2) -> void:
	if not alive:
		return
	var to_target = target_pos - global_position
	gun_angle = to_target.angle()
	queue_redraw()


func manual_fire_at(target_pos: Vector2) -> bool:
	if not alive:
		return false
	if fire_timer > 0:
		return false
	if not projectile_scenes.has("bullet") or not projectiles_container:
		return false

	var to_target = (target_pos - global_position).normalized()
	var angle = rad_to_deg(atan2(-to_target.y, to_target.x))
	angle += randf_range(-spread_degrees, spread_degrees)

	var barrel_dir = Vector2(cos(gun_angle), sin(gun_angle))
	var launch_pos = global_position + Vector2(0, -30) + barrel_dir * 20.0

	var bullet_scene = projectile_scenes["bullet"]
	var proj = bullet_scene.instantiate()
	proj.global_position = launch_pos
	proj.launch(angle, 800.0)
	projectiles_container.add_child(proj)
	fired_bullet.emit(proj)
	shots_fired += 1

	fire_timer = fire_interval
	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	queue_redraw()
	return true
```

**Step 3: Commit**

```bash
git add scripts/game/aa_gun.gd
git commit -m "feat: add manual control support to AA gun"
```

---

### Task 6: Add manual control support to MANPADS

**Files:**
- Modify: `scripts/game/manpads.gd`

**Step 1: Add flag and skip auto-fire**

After `const BACKBLAST_DURATION: float = 0.4`, add:

```gdscript
var manually_controlled: bool = false
```

In `_process()`, wrap auto-fire (lines 81-85):

```gdscript
	if not manually_controlled:
		fire_timer -= delta
		if fire_timer <= 0:
			fire_timer = fire_interval + randf_range(-0.5, 0.5)
			_try_fire()
	else:
		if fire_timer > 0:
			fire_timer -= delta
```

**Step 2: Add manual_fire_at method**

MANPADS fires AA missiles. When manually controlled, aim toward cursor position. The missile will fly toward that direction (no homing since target is a position, not a unit).

```gdscript
func manual_fire_at(target_pos: Vector2) -> bool:
	if not alive or not deployed:
		return false
	if fire_timer > 0:
		return false
	if not projectile_scenes.has("aa_missile") or not projectiles_container:
		return false

	var missile = projectile_scenes["aa_missile"].instantiate()
	missile.global_position = global_position + Vector2(8, -25)

	# Try to find nearest air unit near cursor for homing
	var best_air: Node2D = null
	var best_dist: float = 100.0  # search radius around cursor
	for unit in get_tree().get_nodes_in_group("air_units"):
		if "alive" in unit and not unit.alive:
			continue
		var dist = unit.global_position.distance_to(target_pos)
		if dist < best_dist:
			best_dist = dist
			best_air = unit

	if best_air:
		# Homing missile toward air unit
		var dir = (best_air.global_position - global_position).normalized()
		missile.launch_at(best_air, dir)
	else:
		# No air target near cursor — fire in direction of cursor (no homing)
		var dir = (target_pos - global_position).normalized()
		missile.launch_at(null, dir)

	projectiles_container.add_child(missile)
	fired_missile.emit(missile)
	shots_fired += 1

	fire_timer = fire_interval
	backblast_timer = BACKBLAST_DURATION
	queue_redraw()
	return true
```

**Step 3: Commit**

```bash
git add scripts/game/manpads.gd
git commit -m "feat: add manual control support to MANPADS"
```

---

### Task 7: Create UnitControl script

**Files:**
- Create: `scripts/game/unit_control.gd`

**Step 1: Write the full unit_control.gd script**

```gdscript
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
```

**Step 2: Commit**

```bash
git add scripts/game/unit_control.gd
git commit -m "feat: create unit_control.gd for manual unit control"
```

---

### Task 8: Wire UnitControl into Battle scene

**Files:**
- Modify: `scenes/game/battle.tscn`
- Modify: `scripts/game/battle_manager.gd`

**Step 1: Add UnitControl node to battle.tscn**

Add this after the RangeVisualizer node at the end of the .tscn file:

```
[ext_resource type="Script" path="res://scripts/game/unit_control.gd" id="21_unit_control"]

[node name="UnitControl" type="Node2D" parent="."]
script = ExtResource("21_unit_control")
```

**Step 2: Wire UnitControl in battle_manager.gd**

Add onready reference after existing ones:

```gdscript
@onready var range_visualizer: Node2D = $RangeVisualizer
@onready var unit_control: Node2D = $UnitControl
@onready var camera: Camera2D = $Camera
```

In `_ready()`, after `enemy_ai.setup(self, economy)`, add:

```gdscript
	unit_control.setup(range_visualizer, aiming_system, camera)
```

**Step 3: Commit**

```bash
git add scenes/game/battle.tscn scripts/game/battle_manager.gd
git commit -m "feat: wire UnitControl into battle scene and manager"
```

---

### Task 9: Update HUD to show controlled unit info

**Files:**
- Modify: `scripts/ui/hud.gd`

**Step 1: Add unit control reference and display logic**

Add a variable for tracking controlled unit state:

```gdscript
var unit_control: Node2D = null
var controlled_unit: Node2D = null
```

Add setup method for unit_control (call from battle_manager):

```gdscript
func setup_unit_control(uc: Node2D) -> void:
	unit_control = uc
	unit_control.unit_selected.connect(_on_unit_controlled)
	unit_control.unit_deselected.connect(_on_unit_released)


func _on_unit_controlled(unit: Node2D) -> void:
	controlled_unit = unit


func _on_unit_released() -> void:
	controlled_unit = null
```

In `_process()`, update angle/power/reload to show unit info when controlling:

```gdscript
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
```

**Step 2: Wire from battle_manager.gd**

In `_ready()`, after `unit_control.setup(...)`:

```gdscript
	hud.setup_unit_control(unit_control)
```

**Step 3: Commit**

```bash
git add scripts/ui/hud.gd scripts/game/battle_manager.gd
git commit -m "feat: show controlled unit info in HUD"
```

---

### Task 10: Handle input priority between unit_control and aiming_system

**Files:**
- Modify: `scripts/game/aiming_system.gd`
- Modify: `scripts/game/unit_control.gd`

**Step 1: Hide crosshair when unit is controlled**

In `aiming_system.gd`, the `_draw()` method already checks `input_blocked` for cursor visibility. But we should also skip drawing crosshair when blocked. Add a check at the start of the crosshair drawing section (after the mortar drawing):

In `_process()` line 64, cursor hiding is already handled:
```gdscript
	if mouse_screen_y > 520 or input_blocked:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
```

In `_draw()`, wrap the crosshair drawing (lines 140-160) with:

```gdscript
	if input_blocked:
		return
```

Place this after the mortar barrel/base drawing (line 136) but before the ghost crosshairs.

**Step 2: Hide system cursor when controlling unit**

In `unit_control.gd`, in `_process()`, after movement handling, add cursor management:

```gdscript
	# Hide system cursor in game area
	var mouse_screen_y = get_viewport().get_mouse_position().y
	if mouse_screen_y <= 520:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
```

In `_deselect_unit()`, cursor mode will be restored by aiming_system's `_process()`.

**Step 3: Commit**

```bash
git add scripts/game/aiming_system.gd scripts/game/unit_control.gd
git commit -m "feat: handle input priority between unit control and aiming"
```

---

### Task 11: Verify in Godot

**Step 1: Open project in Godot**

```bash
"D:\Games\Godot\Godot_v4.6.1-stable_win64.exe" --path "E:\YandexDisk\Programs\Games\PeaceEnd"
```

**Step 2: Test checklist**

1. Run the game (F5)
2. Wait for units to deploy
3. Hover over a player unit — see range overlay (existing)
4. Click (release LMB) on infantry — should take control
5. Move with A/D — infantry should move
6. Click LMB — should fire rocket
7. Wait for reload — crosshair color change
8. Click another player unit — should switch
9. Press ESC — should return to artillery mode
10. Try AA Gun — should NOT move with A/D
11. Try Player Tank — parabolic shot should work
12. HUD should show unit name, HP, and reload

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete manual unit control system"
```
