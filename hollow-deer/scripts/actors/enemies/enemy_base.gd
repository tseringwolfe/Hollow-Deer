class_name EnemyBase
extends CharacterBody2D
## Shared grunt enemy AI: Idle (patrol) -> Chase -> Attack, Hurt when hit,
## and Dead from any state.
## Subclasses change how the enemy moves by overriding _move_in_direction().

signal attack_landed(target: Node2D, damage: int)
signal died

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }

@export var max_health: int = 3
@export var move_speed: float = 40.0
@export var attack_damage: int = 1
## Telegraph time before the hit lands, so the player can react.
@export var attack_windup: float = 0.4
## Pause after the hit before the enemy chases again.
@export var attack_recovery: float = 0.4
@export var attack_cooldown: float = 1.0
@export var windup_tint: Color = Color(1.0, 0.4, 0.4)
## How far ahead to look for floor or walls before stepping. Stops enemies
## chasing off ledges.
@export var ledge_check_distance: float = 8.0
## A drop deeper than this counts as a ledge.
@export var ledge_check_depth: float = 12.0

@export_group("Patrol")
## How far from its spawn point the enemy wanders while idle. 0 stands still.
@export var patrol_distance: float = 48.0
## Patrol speed as a fraction of move_speed.
@export_range(0.0, 1.0) var patrol_speed_scale: float = 0.5
## Keeps chasing this long after the player leaves detection range.
@export var lose_interest_time: float = 1.5

@export_group("Hurt")
## Getting hit interrupts the enemy (including an attack windup) for this long.
@export var hurt_time: float = 0.25
@export var knockback_speed: float = 120.0

var _state: State = State.IDLE
var _target: Node2D = null
var _health: int = 0
var _state_time: float = 0.0
var _cooldown_left: float = 0.0
var _has_struck: bool = false
var _spawn_x: float = 0.0
var _patrol_dir: float = 1.0
## Seconds since the target left detection range, or -1 while it is in range.
var _lost_time: float = -1.0

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _detection_area: Area2D = %DetectionArea
@onready var _attack_area: Area2D = %AttackArea


func _ready() -> void:
	_health = max_health
	_spawn_x = global_position.x
	_detection_area.body_entered.connect(_on_detection_area_body_entered)
	_detection_area.body_exited.connect(_on_detection_area_body_exited)
	_change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_state_time += delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_update_target(delta)

	match _state:
		State.IDLE:
			_update_idle(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack()
		State.HURT:
			_update_hurt(delta)
		State.DEAD:
			velocity.x = 0.0

	move_and_slide()


func take_damage(amount: int) -> void:
	if _state == State.DEAD:
		return
	_health -= amount
	_flash_hurt()
	if _health <= 0:
		_change_state(State.DEAD)
	else:
		_change_state(State.HURT)


func _change_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	_sprite.modulate = Color.WHITE

	match new_state:
		State.IDLE:
			_play("walk" if patrol_distance > 0.0 else "idle")
		State.CHASE:
			_play("walk")
		State.ATTACK:
			_has_struck = false
			_play("attack")
			_sprite.modulate = windup_tint
		State.HURT:
			_play("hurt")
			# Knocked away from the player, or backwards if there is no player.
			var away := -_direction_to_target() if _target else -_facing()
			if away == 0.0:
				away = -_facing()
			velocity.x = away * knockback_speed
		State.DEAD:
			_play("death")
			collision_layer = 0
			_detection_area.set_deferred("monitoring", false)
			_attack_area.set_deferred("monitoring", false)
			died.emit()
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.5)
			tween.finished.connect(queue_free)


## Drops the target if it was freed, or if it stayed out of range too long.
func _update_target(delta: float) -> void:
	if not is_instance_valid(_target):
		# Covers no target and a freed player (e.g. died and the level reloaded).
		_target = null
		_lost_time = -1.0
		return
	if _lost_time < 0.0:
		return
	_lost_time += delta
	if _lost_time >= lose_interest_time:
		_target = null
		_lost_time = -1.0


func _update_idle(delta: float) -> void:
	if _target:
		_change_state(State.CHASE)
		return
	if patrol_distance <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		return
	# Turn at the end of the patrol range. Also walks the enemy back home if it
	# was knocked or chased away from its spawn point.
	if (global_position.x - _spawn_x) * _patrol_dir >= patrol_distance:
		_patrol_dir = -_patrol_dir
	if not _move_in_direction(_patrol_dir, move_speed * patrol_speed_scale, delta):
		_patrol_dir = -_patrol_dir


func _update_chase(delta: float) -> void:
	if not _target:
		_change_state(State.IDLE)
		return
	if _can_attack():
		_change_state(State.ATTACK)
		return
	_move_in_direction(_direction_to_target(), move_speed, delta)


func _update_attack() -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	if not _has_struck and _state_time >= attack_windup:
		_has_struck = true
		_sprite.modulate = Color.WHITE
		_strike()
	elif _state_time >= attack_windup + attack_recovery:
		_cooldown_left = attack_cooldown
		_change_state(State.CHASE if _target else State.IDLE)


func _update_hurt(delta: float) -> void:
	# Slide to a stop over the hurt time.
	velocity.x = move_toward(velocity.x, 0.0, knockback_speed / hurt_time * delta)
	if _state_time >= hurt_time:
		_change_state(State.CHASE if _target else State.IDLE)


## Default movement: walk in direction dir at the given speed, stopping at
## ledges and walls. Returns false if the way is blocked, so patrols can turn.
## Override for other movement styles.
func _move_in_direction(dir: float, speed: float, _delta: float) -> bool:
	_face(dir)
	if _is_path_blocked(dir, ledge_check_distance):
		velocity.x = 0.0
		return false
	velocity.x = dir * speed
	return true


func _strike() -> void:
	if not _target or not _attack_area.overlaps_body(_target):
		return
	attack_landed.emit(_target, attack_damage)
	# Works automatically once the player gets a take_damage(amount) method.
	if _target.has_method("take_damage"):
		_target.call("take_damage", attack_damage)


func _can_attack() -> bool:
	return _cooldown_left == 0.0 and _attack_area.overlaps_body(_target)


## True if there is a wall just ahead in direction dir, or no floor reach
## pixels ahead. Never blocked while airborne (there is nothing to check against).
func _is_path_blocked(dir: float, reach: float) -> bool:
	if dir == 0.0 or not is_on_floor():
		return false
	# Lift the wall probe slightly so it does not scrape the floor.
	var lifted := global_transform.translated(Vector2(0.0, -2.0))
	if test_move(lifted, Vector2(dir * ledge_check_distance, 0.0)):
		return true
	var ahead := global_transform.translated(Vector2(dir * reach, 0.0))
	return not test_move(ahead, Vector2(0.0, ledge_check_depth))


func _direction_to_target() -> float:
	return signf(_target.global_position.x - global_position.x)


## Placeholder art faces right, so flip_h means facing left.
func _facing() -> float:
	return -1.0 if _sprite.flip_h else 1.0


## Placeholder art faces right; flip_h turns it left.
func _face(dir: float) -> void:
	if dir == 0.0:
		return
	_sprite.flip_h = dir < 0.0
	_attack_area.scale.x = dir


## Plays an animation only if the art has it, so missing frames don't crash.
func _play(anim: StringName) -> void:
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func _flash_hurt() -> void:
	_sprite.self_modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(_sprite, "self_modulate", Color.WHITE, 0.12)


func _on_detection_area_body_entered(body: Node2D) -> void:
	_target = body
	_lost_time = -1.0


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == _target:
		# Start the give-up timer instead of forgetting the player instantly.
		_lost_time = 0.0
