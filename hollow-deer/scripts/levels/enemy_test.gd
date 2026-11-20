extends Node2D
## Sandbox for enemy AI. Until real combat exists, left-click damages
## enemies near the player, and enemy hits are printed to the Output panel.

const DEBUG_ATTACK_RANGE := 24.0

@onready var _player: CharacterBody2D = %Player
@onready var _enemies: Node2D = %Enemies


func _ready() -> void:
	for enemy: EnemyBase in _enemies.get_children():
		enemy.attack_landed.connect(_on_enemy_attack_landed.bind(enemy))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack"):
		return
	for enemy: EnemyBase in _enemies.get_children():
		if enemy.global_position.distance_to(_player.global_position) <= DEBUG_ATTACK_RANGE:
			enemy.take_damage(1)


func _on_enemy_attack_landed(_target: Node2D, damage: int, enemy: EnemyBase) -> void:
	print("%s hit the player for %d" % [enemy.name, damage])
