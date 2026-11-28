extends Node2D
## Level 1: the dungeon under the forest, built top to bottom.
## Tier 1 runs right (dip slime, encounter 1) and drops down the right side.
## Tier 2 climbs stairs to the left (encounter 2) and drops through the hole.
## Tier 3 runs right over a dash gap (encounter 3), past the Plague Rat room,
## then the player wall-jumps up the shaft to the exit ledge.
##
## Placeholders until other tasks land:
## - Checkpoints/* are markers where L02 checkpoints go.
## - Walkers named Rat* stand in for rats until E03.
## - PlagueRatSpawn (R03, only if R01 is GO) and HealthPotionSpot (L08) mark
##   where those go; the room works empty if the mini boss is cut.
## - Falling into the dash-gap pit sends the player to the last checkpoint.
##   Once P06 lands, pits also deal 1 damage through the player's take_damage().
## - Left-click hits nearby enemies until the scythe (P04) exists.

const DEBUG_ATTACK_RANGE := 24.0
const PIT_DAMAGE := 1

@onready var _player: CharacterBody2D = %Player
@onready var _enemies: Node2D = %Enemies
@onready var _hazards: Node2D = %Hazards


func _ready() -> void:
	for pit: Node in _hazards.get_children():
		var area := pit as Area2D
		if area != null:
			area.body_entered.connect(_on_pit_entered.bind(area))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack") or _player.has_method("attack"):
		return
	for node: Node in _enemies.find_children("*", "EnemyBase", true, false):
		var enemy := node as EnemyBase
		if enemy.global_position.distance_to(_player.global_position) <= DEBUG_ATTACK_RANGE:
			enemy.take_damage(1)


func _on_pit_entered(body: Node2D, pit: Area2D) -> void:
	if body != _player:
		return
	var respawn := pit.get_node("Respawn") as Node2D
	_player.set_deferred("global_position", respawn.global_position)
	_player.set_deferred("velocity", Vector2.ZERO)
	if _player.has_method("take_damage"):
		_player.call_deferred("take_damage", PIT_DAMAGE)
	for camera: Camera2D in _player.find_children("*", "Camera2D", true, false):
		camera.call_deferred("reset_smoothing")
