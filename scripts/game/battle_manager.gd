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
