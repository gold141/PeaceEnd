# scripts/game/camera_controller.gd
# Камера боя — масштабирование колесом мыши, прокрутка перетаскиванием и краями
# При отдалении камера расширяет вид вверх (небо), земля остаётся внизу
extends Camera2D

## Минимальный зум (макс. отдаление)
@export var min_zoom: float = 0.3
## Максимальный зум (макс. приближение)
@export var max_zoom: float = 1.0
## Шаг зума за один тик колеса
@export var zoom_step: float = 0.1
## Скорость прокрутки при курсоре у края экрана (пикс/сек)
@export var edge_scroll_speed: float = 500.0
## Размер зоны у края экрана для прокрутки (пиксели)
@export var edge_scroll_margin: float = 40.0
## Ширина поля боя
@export var battlefield_width: float = 6400.0
## Y-координата нижней границы игровой зоны (верх панели действий в мире)
@export var game_area_bottom: float = 520.0

# Перетаскивание средней кнопкой
var dragging: bool = false


func _ready() -> void:
	zoom = Vector2(1.0, 1.0)
	position = Vector2(640, 360)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_towards_mouse(zoom_step)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_towards_mouse(-zoom_step)
			elif event.button_index == MOUSE_BUTTON_MIDDLE:
				dragging = true
		else:
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				dragging = false

	elif event is InputEventMouseMotion and dragging:
		# Перетаскивание — только по горизонтали
		position.x -= event.relative.x / zoom.x
		_clamp_camera()


func _zoom_towards_mouse(step: float) -> void:
	var old_zoom = zoom.x
	var new_zoom = clampf(old_zoom + step, min_zoom, max_zoom)
	if new_zoom == old_zoom:
		return

	# Запоминаем мировую X-позицию мыши до зума
	var mouse_world_x = get_global_mouse_position().x
	zoom = Vector2(new_zoom, new_zoom)

	# Сдвигаем камеру по X чтобы точка под курсором осталась на месте
	var new_mouse_world_x = get_global_mouse_position().x
	position.x += mouse_world_x - new_mouse_world_x

	_clamp_camera()


func _process(delta: float) -> void:
	# Прокрутка при наведении курсора на край экрана
	var mouse_screen = get_viewport().get_mouse_position()
	var scroll_speed = edge_scroll_speed / zoom.x

	if mouse_screen.y < 520:
		var moved = false
		if mouse_screen.x < edge_scroll_margin:
			position.x -= scroll_speed * delta
			moved = true
		elif mouse_screen.x > get_viewport_rect().size.x - edge_scroll_margin:
			position.x += scroll_speed * delta
			moved = true
		if moved:
			_clamp_camera()


func _clamp_camera() -> void:
	var viewport_size = get_viewport_rect().size
	var half_view_w = viewport_size.x / zoom.x * 0.5

	# X: нормальный клэмп, или центрируем если видно всё поле
	if half_view_w * 2.0 >= battlefield_width:
		position.x = battlefield_width * 0.5
	else:
		position.x = clampf(position.x, half_view_w, battlefield_width - half_view_w)

	# Y: земля (Y=520) всегда на уровне верха панели действий (экран Y=520)
	# При отдалении вид расширяется вверх (небо), земля остаётся на месте
	var viewport_center_y = viewport_size.y * 0.5
	position.y = game_area_bottom - (game_area_bottom - viewport_center_y) / zoom.y
