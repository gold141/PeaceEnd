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
