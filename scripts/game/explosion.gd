# scripts/game/explosion.gd
extends Sprite2D

## Длительность анимации взрыва
@export var duration: float = 0.5
## Начальный масштаб
@export var start_scale: float = 0.02
## Конечный масштаб
@export var end_scale: float = 0.15

var elapsed: float = 0.0

@onready var sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	scale = Vector2(start_scale, start_scale)
	modulate.a = 1.0
	sound.play()


func _process(delta: float) -> void:
	elapsed += delta
	var t = elapsed / duration

	if t >= 1.0:
		queue_free()
		return

	# Быстро вырастает, потом замедляется (ease out)
	var ease_t = 1.0 - pow(1.0 - t, 2.0)
	var s = lerp(start_scale, end_scale, ease_t)
	scale = Vector2(s, s)

	# Прозрачность: держится первые 40%, потом затухает
	if t > 0.4:
		modulate.a = 1.0 - (t - 0.4) / 0.6
