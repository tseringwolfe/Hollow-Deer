extends Node2D
## Sandbox arena for the Wolf boss. Until real combat exists:
##   Left-click: hit the Wolf for 1 if the player is close.
##   E (interact): hit the Wolf for 5 from anywhere, to jump through phases.
## Wolf hits, phase changes, and health print to the Output panel.

const DEBUG_ATTACK_RANGE := 40.0
const DEBUG_SKIP_DAMAGE := 5

@onready var _player: CharacterBody2D = %Player
@onready var _wolf: WolfBoss = %Wolf


func _ready() -> void:
	_wolf.fight_started.connect(func() -> void: print("Wolf fight started"))
	_wolf.phase_changed.connect(func(phase: int) -> void: print("Wolf phase %d" % phase))
	_wolf.health_changed.connect(
		func(current: int, maximum: int) -> void: print("Wolf HP %d/%d" % [current, maximum])
	)
	_wolf.attack_landed.connect(
		func(_target: Node2D, damage: int) -> void: print("Wolf hit the player for %d" % damage)
	)
	_wolf.died.connect(func() -> void: print("Wolf defeated, antlers recovered!"))


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_wolf):
		return
	if event.is_action_pressed("attack"):
		if _wolf.global_position.distance_to(_player.global_position) <= DEBUG_ATTACK_RANGE:
			_wolf.take_damage(1)
	elif event.is_action_pressed("interact"):
		_wolf.take_damage(DEBUG_SKIP_DAMAGE)
