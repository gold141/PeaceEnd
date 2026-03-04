# PeaceEnd Minimal Prototype — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Создать минимальный играбельный прототип: артиллерийское орудие стреляет снарядом по параболе. Игрок задаёт угол и силу, снаряд летит в реальном времени.

**Architecture:** Godot 4.6.1 проект с одной сценой. Node2D для игрового мира, Area2D для снарядов. Физика снаряда — ручная математика (парабола), без встроенной физики Godot. Прицеливание мышкой (перетягивание для угла и силы).

**Tech Stack:** Godot 4.6.1, GDScript, экспорт в HTML5

**Godot Path:** `D:\Games\Godot\Godot_v4.6.1-stable_win64.exe`
**Project Path:** `E:\YandexDisk\Programs\Games\PeaceEnd`

---

## Важно: Godot файлы

Godot 4 использует формат `.tscn` (text scene) и `.gd` (GDScript). Файлы `.tscn` можно создавать текстовым редактором, но проще создать базовый `project.godot` и затем открыть в редакторе. **Мы создадим project.godot и все скрипты текстом, а сцены соберём в редакторе через инструкции.**

Однако для полностью автоматической сборки — мы создадим и `.tscn` файлы текстом.

---

### Task 1: Инициализация Godot-проекта

**Files:**
- Create: `project.godot`
- Create: `assets/sprites/` (директория)

**Step 1: Создай project.godot**

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; but we're bootstrapping here.

[application]

config/name="PeaceEnd"
config/version="0.1.0"
run/main_scene="res://scenes/game/battle.tscn"
config/features=PackedStringArray("4.4")

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[rendering]

textures/canvas_textures/default_texture_filter=0
```

Заметка: `default_texture_filter=0` означает NEAREST — важно для пиксель-арта.

**Step 2: Создай структуру директорий**

```bash
mkdir -p "E:/YandexDisk/Programs/Games/PeaceEnd/scenes/game"
mkdir -p "E:/YandexDisk/Programs/Games/PeaceEnd/scripts/game"
mkdir -p "E:/YandexDisk/Programs/Games/PeaceEnd/scripts/ui"
mkdir -p "E:/YandexDisk/Programs/Games/PeaceEnd/assets/sprites"
```

**Step 3: Коммит**

```bash
cd "E:/YandexDisk/Programs/Games/PeaceEnd"
git add project.godot .gitignore docs/
git commit -m "feat: init Godot 4.6 project with design docs"
```

---

### Task 2: Скрипт снаряда (projectile.gd)

Снаряд летит по параболе. Это ядро всей механики.

**Files:**
- Create: `scripts/game/projectile.gd`

**Step 1: Создай скрипт снаряда**

```gdscript
# scripts/game/projectile.gd
extends Area2D

## Начальная скорость (пиксели/сек)
@export var speed: float = 500.0
## Угол запуска (градусы от горизонтали)
@export var launch_angle: float = 45.0
## Гравитация (пиксели/сек²)
@export var gravity: float = 980.0
## Радиус взрыва
@export var explosion_radius: float = 50.0

var velocity: Vector2 = Vector2.ZERO
var launched: bool = false

signal hit(position: Vector2)
signal off_screen()


func launch(angle_deg: float, power: float) -> void:
	var angle_rad = deg_to_rad(angle_deg)
	velocity.x = power * cos(angle_rad)
	velocity.y = -power * sin(angle_rad)  # Negative = up in Godot
	launched = true


func _process(delta: float) -> void:
	if not launched:
		return

	# Apply gravity
	velocity.y += gravity * delta

	# Move
	position += velocity * delta

	# Rotate sprite to match trajectory
	rotation = velocity.angle()

	# Check if off screen (below ground or too far)
	if position.y > 800 or position.x > 1400 or position.x < -100:
		off_screen.emit()
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	hit.emit(global_position)
	queue_free()
```

**Step 2: Коммит**

```bash
git add scripts/game/projectile.gd
git commit -m "feat: add projectile script with parabolic trajectory"
```

---

### Task 3: Система прицеливания (aiming_system.gd)

Игрок перетягивает мышь от пушки — видит линию траектории. Отпускает — стреляет.

**Files:**
- Create: `scripts/game/aiming_system.gd`

**Step 1: Создай скрипт прицеливания**

```gdscript
# scripts/game/aiming_system.gd
extends Node2D

## Сцена снаряда для инстанцирования
@export var projectile_scene: PackedScene
## Минимальная сила выстрела
@export var min_power: float = 200.0
## Максимальная сила выстрела
@export var max_power: float = 800.0
## Чувствительность перетягивания (пиксели мыши -> сила)
@export var drag_sensitivity: float = 1.5
## Гравитация (должна совпадать с projectile.gd)
@export var gravity: float = 980.0
## Перезарядка (секунды)
@export var reload_time: float = 2.0
## Количество точек предсказания траектории
@export var trajectory_points: int = 40
## Интервал времени между точками траектории
@export var trajectory_time_step: float = 0.05

var is_aiming: bool = false
var aim_start: Vector2 = Vector2.ZERO
var current_angle: float = 45.0
var current_power: float = 400.0
var can_fire: bool = true
var reload_timer: float = 0.0

## Ссылка на контейнер снарядов (назначить из battle scene)
@export var projectiles_container: Node2D

signal fired(angle: float, power: float)


func _process(delta: float) -> void:
	# Reload timer
	if not can_fire:
		reload_timer -= delta
		if reload_timer <= 0:
			can_fire = true

	# Redraw trajectory line
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_aiming(event.global_position)
			else:
				_fire()

	elif event is InputEventMouseMotion and is_aiming:
		_update_aim(event.global_position)


func _start_aiming(mouse_pos: Vector2) -> void:
	if not can_fire:
		return
	is_aiming = true
	aim_start = mouse_pos


func _update_aim(mouse_pos: Vector2) -> void:
	var drag = aim_start - mouse_pos  # Drag AWAY from target = more power

	# Angle from horizontal (drag direction)
	current_angle = rad_to_deg(atan2(-drag.y, drag.x))
	current_angle = clamp(current_angle, 10.0, 85.0)

	# Power from drag distance
	current_power = clamp(drag.length() * drag_sensitivity, min_power, max_power)


func _fire() -> void:
	if not is_aiming or not can_fire:
		is_aiming = false
		return

	is_aiming = false

	if projectile_scene and projectiles_container:
		var proj = projectile_scene.instantiate()
		proj.global_position = global_position
		proj.launch(current_angle, current_power)
		projectiles_container.add_child(proj)

		fired.emit(current_angle, current_power)

	# Start reload
	can_fire = false
	reload_timer = reload_time


func _draw() -> void:
	if not is_aiming:
		return

	# Draw predicted trajectory
	var angle_rad = deg_to_rad(current_angle)
	var vel = Vector2(
		current_power * cos(angle_rad),
		-current_power * sin(angle_rad)
	)

	var prev_point = Vector2.ZERO  # local coordinates
	for i in range(1, trajectory_points):
		var t = i * trajectory_time_step
		var point = Vector2(
			vel.x * t,
			vel.y * t + 0.5 * gravity * t * t
		)
		draw_line(prev_point, point, Color.YELLOW, 2.0)
		prev_point = point

	# Draw power indicator
	var power_ratio = (current_power - min_power) / (max_power - min_power)
	var indicator_color = Color.GREEN.lerp(Color.RED, power_ratio)
	draw_arc(Vector2.ZERO, 30.0, 0, TAU, 32, indicator_color, 3.0)
```

**Step 2: Коммит**

```bash
git add scripts/game/aiming_system.gd
git commit -m "feat: add aiming system with trajectory prediction"
```

---

### Task 4: HUD скрипт (hud.gd)

Минимальный UI: показывает угол, силу, статус перезарядки.

**Files:**
- Create: `scripts/ui/hud.gd`

**Step 1: Создай скрипт HUD**

```gdscript
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
```

**Step 2: Коммит**

```bash
git add scripts/ui/hud.gd
git commit -m "feat: add HUD script for angle/power/reload display"
```

---

### Task 5: Менеджер боя (battle_manager.gd)

Главный скрипт сцены — связывает всё вместе.

**Files:**
- Create: `scripts/game/battle_manager.gd`

**Step 1: Создай скрипт менеджера**

```gdscript
# scripts/game/battle_manager.gd
extends Node2D

@onready var aiming_system: Node2D = $AimingSystem
@onready var projectiles: Node2D = $Projectiles
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	# Connect aiming system to projectiles container
	aiming_system.projectiles_container = projectiles

	# Setup HUD
	hud.setup(aiming_system)
```

**Step 2: Коммит**

```bash
git add scripts/game/battle_manager.gd
git commit -m "feat: add battle manager to wire game systems together"
```

---

### Task 6: Создание сцены снаряда (projectile.tscn)

**Files:**
- Create: `scenes/projectiles/projectile.tscn`

**Step 1: Создай директорию и сцену**

```bash
mkdir -p "E:/YandexDisk/Programs/Games/PeaceEnd/scenes/projectiles"
```

Создай файл `scenes/projectiles/projectile.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/game/projectile.gd" id="1"]

[node name="Projectile" type="Area2D"]
script = ExtResource("1")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("1_shape")

[node name="Sprite2D" type="Sprite2D" parent="."]

[node name="VisibleOnScreenNotifier2D" type="VisibleOnScreenNotifier2D" parent="."]

[connection signal="body_entered" from="." to="." method="_on_body_entered"]
```

**ВАЖНО:** Эта сцена может потребовать доработки в редакторе Godot (задать shape, назначить спрайт). Альтернатива — собрать в редакторе:

1. Открой Godot: `D:\Games\Godot\Godot_v4.6.1-stable_win64.exe`
2. Открой проект `E:\YandexDisk\Programs\Games\PeaceEnd`
3. Создай новую сцену: Scene -> New Scene
4. Корневой нод: Area2D (переименуй в "Projectile")
5. Добавь дочерний: CollisionShape2D -> задай CircleShape2D (radius=5)
6. Добавь дочерний: Sprite2D -> пока без текстуры (или назначь shell.png)
7. Прикрепи скрипт: `res://scripts/game/projectile.gd`
8. Подключи сигнал: Area2D.body_entered -> _on_body_entered
9. Сохрани как: `res://scenes/projectiles/projectile.tscn`

**Step 2: Коммит**

```bash
git add scenes/projectiles/
git commit -m "feat: add projectile scene"
```

---

### Task 7: Создание главной сцены боя (battle.tscn)

**Files:**
- Create: `scenes/game/battle.tscn`

**Step 1: Собери сцену в редакторе Godot**

1. Создай новую сцену: Scene -> New Scene
2. Корневой нод: Node2D (переименуй в "Battle")
3. Прикрепи скрипт: `res://scripts/game/battle_manager.gd`

Добавь дочерние ноды:

```
Battle (Node2D) [battle_manager.gd]
├── Background (ColorRect)
│     position: (0, 0)
│     size: (1280, 720)
│     color: Color(0.53, 0.81, 0.92)  # Голубое небо
│
├── Ground (StaticBody2D)
│   ├── CollisionShape2D
│   │     shape: RectangleShape2D(size=Vector2(1280, 100))
│   │     position: (640, 670)  # Низ экрана
│   └── ColorRect
│         position: (0, 620)
│         size: (1280, 100)
│         color: Color(0.4, 0.3, 0.2)  # Коричневая земля
│
├── AimingSystem (Node2D) [aiming_system.gd]
│     position: (100, 600)  # Левый нижний угол — позиция пушки
│     projectile_scene: res://scenes/projectiles/projectile.tscn
│
├── MortarSprite (Sprite2D)
│     position: (100, 600)
│     texture: (пока пусто, позже mortar.png)
│
├── Projectiles (Node2D)
│     # Контейнер для летящих снарядов
│
├── TargetDummy (StaticBody2D)
│   ├── CollisionShape2D
│   │     shape: RectangleShape2D(size=Vector2(60, 80))
│   │     position: (900, 580)
│   └── ColorRect  # Временная мишень
│         position: (870, 540)
│         size: (60, 80)
│         color: Color(0.8, 0.2, 0.2)  # Красный блок-мишень
│
└── HUD (CanvasLayer) [hud.gd]
    ├── AngleLabel (Label)
    │     position: (20, 20)
    │     text: "Angle: 45°"
    │     theme_override_font_sizes/font_size: 20
    │
    ├── PowerLabel (Label)
    │     position: (20, 50)
    │     text: "Power: 400"
    │     theme_override_font_sizes/font_size: 20
    │
    └── ReloadBar (ProgressBar)
          position: (20, 80)
          size: (200, 20)
          value: 100
```

4. В AimingSystem: задай параметр `projectile_scene` = `res://scenes/projectiles/projectile.tscn`
5. Сохрани как: `res://scenes/game/battle.tscn`

**Step 2: Коммит**

```bash
git add scenes/game/
git commit -m "feat: add battle scene with ground, aiming, target, HUD"
```

---

### Task 8: Первый запуск и тестирование

**Step 1: Открой проект в Godot**

```bash
"D:\Games\Godot\Godot_v4.6.1-stable_win64.exe" --path "E:\YandexDisk\Programs\Games\PeaceEnd"
```

**Step 2: Проверь что всё на месте**

- project.godot: main_scene = `res://scenes/game/battle.tscn`
- В редакторе: откри battle.tscn
- Проверь что AimingSystem имеет ссылку на projectile_scene
- Проверь что скрипты прикреплены

**Step 3: Запусти (F5)**

Ожидаемое поведение:
1. Голубой фон + коричневая земля внизу
2. Красный блок-мишень справа
3. Зажми ЛКМ и тяни мышь — жёлтая линия траектории
4. Отпусти — снаряд летит по параболе
5. HUD показывает угол, силу, перезарядку
6. Перезарядка 2 секунды между выстрелами

**Step 4: Исправь проблемы если есть**

Частые проблемы:
- Снаряд не сталкивается с мишенью → проверь collision layers (Area2D и StaticBody2D должны быть на одном layer)
- Траектория не рисуется → проверь что `_draw()` вызывается (is_aiming должен быть true)
- HUD не обновляется → проверь что `hud.setup(aiming_system)` вызывается в `_ready()`

**Step 5: Коммит рабочего прототипа**

```bash
git add -A
git commit -m "feat: working minimal prototype — artillery fires parabolic shells"
```

---

### Task 9 (Опционально): Добавь спрайты когда они будут готовы

Когда отдельный чат сгенерирует спрайты через ComfyUI:

1. Импортируй спрайты в Godot (просто скопируй в `assets/sprites/`)
2. Назначь текстуры:
   - MortarSprite.texture = `res://assets/sprites/mortar.png`
   - Projectile/Sprite2D.texture = `res://assets/sprites/shell.png`
   - Background = `res://assets/sprites/background_battlefield.png`
3. Удали временные ColorRect
4. Коммит

```bash
git add assets/sprites/ scenes/
git commit -m "art: replace placeholder graphics with pixel art sprites"
```

---

## Итоговая структура после всех задач

```
PeaceEnd/
├── project.godot
├── .gitignore
├── docs/
│   └── plans/
│       ├── 2026-03-04-peaceend-game-design.md
│       ├── 2026-03-04-sprite-generation.md
│       └── 2026-03-04-minimal-prototype.md
├── scenes/
│   ├── game/
│   │   └── battle.tscn
│   └── projectiles/
│       └── projectile.tscn
├── scripts/
│   ├── game/
│   │   ├── battle_manager.gd
│   │   ├── aiming_system.gd
│   │   └── projectile.gd
│   └── ui/
│       └── hud.gd
└── assets/
    └── sprites/
        ├── background_battlefield.png  (из ComfyUI)
        ├── mortar.png                  (из ComfyUI)
        ├── shell.png                   (из ComfyUI)
        ├── explosion.png               (из ComfyUI)
        ├── infantry.png                (из ComfyUI)
        ├── enemy_trench.png            (из ComfyUI)
        ├── enemy_bunker.png            (из ComfyUI)
        ├── player_base.png             (из ComfyUI)
        └── enemy_base.png              (из ComfyUI)
```
