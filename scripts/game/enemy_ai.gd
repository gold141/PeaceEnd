# scripts/game/enemy_ai.gd
# ИИ противника — оценивает поле боя и спавнит юнитов
extends Node

var battle_manager: Node2D
var economy: Node

var spawn_timer: float = 0.0
var spawn_interval: float = 3.0  # Секунды между решениями о спавне
var wave_timer: float = 0.0
var wave_interval: float = 30.0  # Большая волна каждые 30с
var wave_count: int = 0

var initial_delay: float = 3.0  # Не спавним сразу
var spawn_stagger: float = 0.0  # Задержка между юнитами в волне
var spawn_queue: Array = []


func setup(manager: Node2D, econ: Node) -> void:
	battle_manager = manager
	economy = econ


func _process(delta: float) -> void:
	if not battle_manager or not economy:
		return

	initial_delay -= delta
	if initial_delay > 0:
		return

	# Обработка очереди спавна
	if spawn_queue.size() > 0:
		spawn_stagger -= delta
		if spawn_stagger <= 0:
			spawn_stagger = 0.8  # 0.8с между юнитами в волне
			var unit_type = spawn_queue.pop_front()
			battle_manager.spawn_enemy_unit(unit_type)

	spawn_timer += delta
	wave_timer += delta

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_evaluate_and_spawn()

	if wave_timer >= wave_interval:
		wave_timer = 0.0
		wave_count += 1
		_spawn_wave()


func _count_group(group_name: String) -> int:
	var count = 0
	for unit in get_tree().get_nodes_in_group(group_name):
		if "alive" in unit and unit.alive:
			count += 1
		elif not ("alive" in unit):
			count += 1
	return count


func _evaluate_and_spawn() -> void:
	var player_ground = _count_group("player_units")
	var player_vehicles = _count_group("player_vehicles")
	var player_aa = _count_group("anti_air_units")
	var enemy_ground = _count_group("enemy_units")

	var options: Array = []

	# Всегда нужна наземная поддержка
	if enemy_ground < 3:
		options.append("enemy_infantry")
		options.append("enemy_tank")

	# Если у игрока много наземных юнитов — бомбить
	if player_ground > 4 and player_aa < 2:
		options.append("fighter_jet")
		options.append("kamikaze_drone")

	# Если у игрока есть ПВО — больше наземных
	if player_aa >= 2:
		options.append("enemy_tank")
		options.append("enemy_apc")
		options.append("enemy_infantry")
	else:
		# Нет ПВО — воздушное превосходство
		options.append("attack_helicopter")
		options.append("kamikaze_drone")
		options.append("fighter_jet")

	# Если у игрока танки — нужны танки
	if player_vehicles > 0:
		options.append("enemy_tank")

	# АПЦ для доставки пехоты
	if enemy_ground < 5 and wave_count > 0:
		options.append("enemy_apc")

	if options.is_empty():
		options = ["enemy_infantry", "enemy_tank"]

	# Выбираем случайный вариант
	options.shuffle()
	for option in options:
		if economy.can_enemy_afford(option):
			battle_manager.spawn_enemy_unit(option)
			break


func _spawn_wave() -> void:
	# Тратим до 50% текущих денег в волне
	var budget = economy.enemy_money / 2
	var wave_options: Array

	# Состав волны зависит от номера
	match wave_count % 4:
		0:
			wave_options = ["enemy_infantry", "enemy_infantry", "enemy_tank"]
		1:
			wave_options = ["enemy_apc", "kamikaze_drone", "kamikaze_drone"]
		2:
			wave_options = ["enemy_tank", "enemy_tank", "fighter_jet"]
		3:
			wave_options = ["attack_helicopter", "enemy_infantry", "enemy_apc", "kamikaze_drone"]

	# Добавляем в очередь что можем себе позволить
	var spent = 0
	for unit_type in wave_options:
		var cost = economy.get_cost(unit_type)
		if spent + cost <= budget and economy.can_enemy_afford(unit_type):
			economy.enemy_spend(unit_type)
			spawn_queue.append(unit_type)
			spent += cost
