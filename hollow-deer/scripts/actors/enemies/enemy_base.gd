class_name EnemyBase
extends CharacterBody2D
## Shared grunt enemy AI: Idle -> Chase -> Attack, and Dead from any state.
## Subclasses change how the enemy moves by overriding _move_toward_target().

signal attack_landed(target: Node2D, damage: int)
signal died

enum State { IDLE, CHASE, ATTACK, DEAD }

@export var max_health: int = 3
@export var move_speed: float = 40.0
@export var attack_damage: int = 1
## Telegraph time before the hit lands, so the player can react.
@export var attack_windup: float = 0.4
## Pause after the hit before the enemy chases again.
@export var attack_recovery: float = 0.4
@export var attack_cooldown: float = 1.0
@export var windup_tint: Color = Color(1.0, 0.4, 0.4)
## How far ahead to look for floor before stepping. Stops enemies chasing off ledges.
@export var ledge_check_distance: float = 8.0
## A drop deeper than this counts as a ledge.
@export var ledge_check_depth: float = 12.0

var _state: State = State.IDLE
var _target: Node2D = null
var _health: int = 0
var _state_time: float = 0.0
var _cooldown_left: float = 0.0
var _has_struck: bool = false

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _detection_area: Area2D = %DetectionArea
@onready var _attack_area: Area2D = %AttackArea


func _ready() -> void:
	_health = max_health
	_detection_area.body_entered.connect(_on_detection_area_body_entered)
	_detection_area.body_exited.connect(_on_detection_area_body_exited)
	_change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_state_time += delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _target and not is_instance_valid(_target):
		# Player was freed (e.g. died and the level reloaded them).
		_target = null

	match _state:
		State.IDLE:
			_update_idle()
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack()
		State.DEAD:
			velocity.x = 0.0

	move_and_slide()


func take_damage(amount: int) -> void:
	if _state == State.DEAD:
		return
	_health -= amount
	if _health <= 0:
		_change_state(State.DEAD)


func _change_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	_sprite.modulate = Color.WHITE

	match new_state:
		State.IDLE:
			_sprite.play("idle")
		State.CHASE:
			_sprite.play("walk")
		State.ATTACK:
			_has_struck = false
			_sprite.play("attack")
			_sprite.modulate = windup_tint
		State.DEAD:
			_sprite.play("death")
			collision_layer = 0
			_detection_area.set_deferred("monitoring", false)
			_attack_area.set_deferred("monitoring", false)
			died.emit()
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.5)
			tween.finished.connect(queue_free)


func _update_idle() -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	if _target:
		_change_state(State.CHASE)


func _update_chase(delta: float) -> void:
	if not _target:
		_change_state(State.IDLE)
		return
	if _can_attack():
		_change_state(State.ATTACK)
		return
	_move_toward_target(delta)


func _update_attack() -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	if not _has_struck and _state_time >= attack_windup:
		_has_struck = true
		_sprite.modulate = Color.WHITE
		_strike()
	elif _state_time >= attack_windup + attack_recovery:
		_cooldown_left = attack_cooldown
		_change_state(State.CHASE if _target else State.IDLE)


## Default movement: walk straight at the target. Override for other styles.
func _move_toward_target(_delta: float) -> void:
	var dir := _direction_to_target()
	_face(dir)
	velocity.x = dir * move_speed if _has_floor_ahead(dir) else 0.0


func _strike() -> void:
	if not _target or not _attack_area.overlaps_body(_target):
		return
	attack_landed.emit(_target, attack_damage)
	# Works automatically once the player gets a take_damage(amount) method.
	if _target.has_method("take_damage"):
		_target.call("take_damage", attack_damage)


func _can_attack() -> bool:
	return _cooldown_left == 0.0 and _attack_area.overlaps_body(_target)


## True if there is ground just ahead in direction dir, or if airborne
## (mid-air there is nothing to check against).
func _has_floor_ahead(dir: float) -> bool:
	if dir == 0.0 or not is_on_floor():
		return true
	var ahead := global_transform.translated(Vector2(dir * ledge_check_distance, 0.0))
	return test_move(ahead, Vector2(0.0, ledge_check_depth))


func _direction_to_target() -> float:
	return signf(_target.global_position.x - global_position.x)


## Placeholder art faces right; flip_h turns it left.
func _face(dir: float) -> void:
	if dir == 0.0:
		return
	_sprite.flip_h = dir < 0.0
	_attack_area.scale.x = dir


func _on_detection_area_body_entered(body: Node2D) -> void:
	_target = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == _target:
		_target = null
