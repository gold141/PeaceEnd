# scripts/game/infantry.gd
# Пехотный юнит — солдат за мешками с песком, автоматическая стрельба
extends Node2D

## Здоровье
@export var max_hp: int = 2
## Дальность стрельбы (пиксели)
@export var fire_range: float = 400.0
## Интервал стрельбы (секунды)
@export var fire_interval: float = 1.5
## Урон за выстрел
@export var damage: int = 1

var hp: int
var alive: bool = true
var fire_timer: float = 0.0

# Визуальные цвета
var bag_color: Color = Color(0.6, 0.5, 0.3)
var bag_color2: Color = Color(0.55, 0.45, 0.28)
var uniform_color: Color = Color(0.3, 0.35, 0.25)
var skin_color: Color = Color(0.55, 0.5, 0.4)
var helmet_color: Color = Color(0.3, 0.35, 0.25)
var weapon_color: Color = Color(0.2, 0.2, 0.18)

# Вспышка выстрела
var muzzle_flash_timer: float = 0.0
const MUZZLE_FLASH_DURATION: float = 0.08

signal destroyed


func _ready() -> void:
	hp = max_hp
	add_to_group("infantry")
	fire_timer = randf_range(0.5, fire_interval)


func _process(delta: float) -> void:
	if not alive:
		return

	fire_timer -= delta
	if fire_timer <= 0:
		fire_timer = fire_interval + randf_range(-0.2, 0.2)
		_try_fire()

	if muzzle_flash_timer > 0:
		muzzle_flash_timer -= delta
		queue_redraw()


func _try_fire() -> void:
	# Ищем ближайший танк в радиусе
	var targets = get_tree().get_nodes_in_group("enemy_tanks")
	var closest: Node2D = null
	var closest_dist: float = fire_range

	for tank in targets:
		if not tank.alive:
			continue
		var dist = abs(tank.global_position.x - global_position.x)
		if dist < closest_dist:
			closest_dist = dist
			closest = tank

	if closest and closest.has_method("take_damage"):
		closest.take_damage(damage)
		muzzle_flash_timer = MUZZLE_FLASH_DURATION
		queue_redraw()


func take_damage(amount: int = 1) -> void:
	if not alive:
		return
	hp -= amount
	_flash()
	if hp <= 0:
		alive = false
		destroyed.emit()
		_die()


func _flash() -> void:
	modulate = Color(3.0, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)


func _die() -> void:
	# Становимся серыми руинами
	bag_color = Color(0.3, 0.28, 0.25)
	bag_color2 = Color(0.28, 0.25, 0.22)
	uniform_color = Color(0.18, 0.18, 0.16)
	skin_color = Color(0.3, 0.28, 0.25)
	helmet_color = Color(0.18, 0.18, 0.16)
	modulate = Color.WHITE
	queue_redraw()
	# Удаляем через 10 секунд
	var timer = get_tree().create_timer(10.0)
	timer.timeout.connect(queue_free)


func _draw() -> void:
	# Центр = позиция юнита (на уровне земли)

	# Мешки с песком — нижний ряд (3 мешка)
	var bag_w = 16.0
	var bag_h = 10.0
	var base_y = -bag_h

	for i in range(3):
		var bx = -1.5 * bag_w + i * bag_w
		var c = bag_color if i % 2 == 0 else bag_color2
		draw_rect(Rect2(bx, base_y, bag_w - 1, bag_h), c)
		draw_rect(Rect2(bx, base_y, bag_w - 1, bag_h), c.darkened(0.3), false, 1.0)

	# Верхний ряд (2 мешка)
	var top_y = base_y - bag_h
	for i in range(2):
		var bx = -bag_w + i * bag_w
		var c = bag_color2 if i % 2 == 0 else bag_color
		draw_rect(Rect2(bx, top_y, bag_w - 1, bag_h), c)
		draw_rect(Rect2(bx, top_y, bag_w - 1, bag_h), c.darkened(0.3), false, 1.0)

	if not alive:
		return

	# Солдат за мешками
	var soldier_y = -bag_h * 2

	# Голова
	draw_circle(Vector2(0, soldier_y - 8), 5.0, skin_color)

	# Каска
	draw_arc(Vector2(0, soldier_y - 10), 6.0, PI, TAU, 12, helmet_color, 2.5)

	# Тело
	draw_rect(Rect2(-5, soldier_y - 2, 10, 14), uniform_color)

	# Оружие (винтовка вправо — стреляет по врагам справа)
	draw_line(Vector2(5, soldier_y), Vector2(18, soldier_y - 10), weapon_color, 2.0)

	# Вспышка выстрела
	if muzzle_flash_timer > 0:
		var flash_pos = Vector2(20, soldier_y - 12)
		draw_circle(flash_pos, 4.0, Color(1.0, 0.9, 0.3, 0.9))
		draw_circle(flash_pos, 2.5, Color(1.0, 1.0, 0.8, 1.0))
