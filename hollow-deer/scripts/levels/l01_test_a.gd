extends Node2D
## L01 test room A. Walk right into the encounter, defeat both enemies (left-click near
## them until real combat exists), then the exit to room B opens.

const DEBUG_ATTACK_RANGE := 24.0

@onready var _player: CharacterBody2D = %Player
@onready var _enemies: Node2D = %Enemies
@onready var _encounter: EncounterTrigger = %EncounterTrigger
@onready var _exit: LevelTransition = %ExitToB


func _ready() -> void:
	_encounter.encounter_started.connect(_on_encounter_started)
	_encounter.encounter_completed.connect(_on_encounter_completed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack"):
		return
	for child: Node in _enemies.get_children():
		var enemy := child as EnemyBase
		if enemy != null and enemy.global_position.distance_to(_player.global_position) <= DEBUG_ATTACK_RANGE:
			enemy.take_damage(1)


func _on_encounter_started() -> void:
	print("[L01] Encounter started: %d enemies" % _encounter.get_remaining_count())


func _on_encounter_completed() -> void:
	print("[L01] Encounter completed, exit to room B is open")
	_exit.set_enabled(true)
