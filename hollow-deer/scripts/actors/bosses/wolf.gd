class_name WolfBoss
extends CharacterBody2D
## Final boss: the Big Bad Lonesome Wolf.
## A phase-based state machine. Each phase adds one attack to the pool:
##   Phase 1: antler swipe, antler thrust (lunge).
##   Phase 2: + magic bolts (1 bolt, 3 in phase 3).
##   Phase 3: + antler spikes that burst out of the floor.
## Every attack has a tinted windup so the player can read it, and the boss is
## invulnerable while it roars between phases.

signal fight_started
signal phase_changed(phase: int)
signal health_changed(current: int, maximum: int)
signal attack_landed(target: Node2D, damage: int)
signal died

enum State { DORMANT, CHASE, WINDUP, ACTIVE, RECOVER, ROAR, DEAD }
enum Attack { SWIPE, THRUST, MAGIC_BOLT, ANTLER_SPIKES }

const BOLT_SCENE := preload("res://scenes/actors/bosses/wolf_magic_bolt.tscn")
const SPIKE_SCENE := preload("res://scenes/actors/bosses/wolf_antler_spike.tscn")
## Where bolts spawn, relative to the wolf's feet when facing right.
const BOLT_OFFSET := Vector2(12.0, -20.0)
## The same attack is never picked more than this many times in a row.
const MAX_REPEATS := 2

@export_group("Health")
@export var max_health: int = 30
## Phase 2 starts when health drops to this fraction of max_health.
@export_range(0.0, 1.0) var phase_two_at: float = 0.66
@export_range(0.0, 1.0) var phase_three_at: float = 0.33

@export_group("Movement")
@export var move_speed: float = 55.0
## Closer than this, the wolf can swipe. Farther, it lunges or uses magic.
@export var melee_range: float = 34.0
## If a melee chase takes longer than this, it gives up and picks again.
@export var chase_timeout: float = 2.5

@export_group("Pacing")
## Every phase multiplies windups and recovery by this, so later phases are faster.
@export_range(0.5, 1.0) var phase_speedup: float = 0.85
@export var recovery_time: float = 0.7
@export var roar_time: float = 1.4

@export_group("Swipe")
@export var swipe_damage: int = 1
@export var swipe_windup: float = 0.5
@export var swipe_active_time: float = 0.15

@export_group("Thrust")
@export var thrust_damage: int = 1
@export var thrust_windup: float = 0.65
@export var thrust_speed: float = 240.0
@export var thrust_time: float = 0.3

@export_group("Magic Bolt")
@export var bolt_windup: float = 0.6
@export var bolt_spread_degrees: float = 18.0

@export_group("Antler Spikes")
@export var spike_windup: float = 0.5
@export var spike_count: int = 3
@export var spike_spacing: float = 36.0

@export_group("Telegraph Tints")
@export var melee_tint: Color = Color(1.0, 0.4, 0.4)
@export var magic_tint: Color = Color(0.7, 0.45, 1.0)
@export var roar_tint: Color = Color(1.0, 0.85, 0.3)

var _state: State = State.DORMANT
var _target: Node2D = null
var _health: int = 0
var _phase: int = 1
var _state_time: float = 0.0
var _facing: float = 1.0
var _attack: Attack = Attack.SWIPE
var _last_attack: Attack = Attack.SWIPE
var _repeat_count: int = 0
var _windup_time: float = 0.0
var _active_time: float = 0.0
var _has_hit: bool = false

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _detection_area: Area2D = %DetectionArea
@onready var _melee_area: Area2D = %MeleeArea


func _ready() -> void:
	assert(phase_three_at < phase_two_at, "phase_three_at must be below phase_two_at")
	_health = max_health
	_detection_area.body_entered.connect(_on_detection_area_body_entered)
	_change_state(State.DORMANT)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_state_time += delta

	if _state != State.DORMANT and _state != State.DEAD and not is_instance_valid(_target):
		# Player was freed (e.g. died and the level reloaded them). Go back to sleep.
		_target = null
		_change_state(State.DORMANT)

	match _state:
		State.DORMANT, State.RECOVER, State.ROAR, State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			_update_timed_state()
		State.CHASE:
			_update_chase()
		State.ACTIVE:
			_update_active()
		State.DEAD:
			velocity.x = 0.0

	move_and_slide()


func take_damage(amount: int) -> void:
	# Invulnerable before the fight, while roaring between phases, and once dead.
	if _state == State.DORMANT or _state == State.ROAR or _state == State.DEAD:
		return
	_health = maxi(_health - amount, 0)
	health_changed.emit(_health, max_health)
	_flash_hurt()

	if _health == 0:
		_change_state(State.DEAD)
		return
	var new_phase := _phase_for_health()
	if new_phase > _phase:
		_phase = new_phase
		phase_changed.emit(_phase)
		_change_state(State.ROAR)


func get_phase() -> int:
	return _phase


func get_health() -> int:
	return _health


func _change_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	_sprite.modulate = Color.WHITE

	match new_state:
		State.DORMANT:
			_play("idle")
		State.CHASE:
			_pick_attack()
			_play("walk")
		State.WINDUP:
			_begin_windup()
		State.ACTIVE:
			_begin_active()
		State.RECOVER:
			_play("idle")
		State.ROAR:
			_sprite.modulate = roar_tint
			_play("roar")
		State.DEAD:
			_play("death")
			collision_layer = 0
			_detection_area.set_deferred("monitoring", false)
			_melee_area.set_deferred("monitoring", false)
			died.emit()
			var tween := create_tween()
			tween.tween_interval(1.0)
			tween.tween_property(self, "modulate:a", 0.0, 0.8)
			tween.finished.connect(queue_free)


## DORMANT, WINDUP, RECOVER and ROAR only wait for their timer to run out.
func _update_timed_state() -> void:
	match _state:
		State.WINDUP:
			if _state_time >= _windup_time:
				_change_state(State.ACTIVE)
		State.RECOVER:
			if _state_time >= recovery_time * _pace():
				_change_state(State.CHASE)
		State.ROAR:
			if _state_time >= roar_time:
				_change_state(State.CHASE)


func _update_chase() -> void:
	var dir := _direction_to_target()
	_face(dir)
	# Only the swipe needs to walk into range; everything else starts right away.
	if _attack != Attack.SWIPE or _distance_to_target() <= melee_range:
		velocity.x = 0.0
		_change_state(State.WINDUP)
		return
	if _state_time >= chase_timeout:
		# Player keeps running. Re-roll; far away, swipe is not in the pool.
		_change_state(State.CHASE)
		return
	velocity.x = dir * move_speed


func _update_active() -> void:
	if _attack == Attack.THRUST:
		velocity.x = _facing * thrust_speed
	else:
		velocity.x = 0.0

	var is_melee := _attack == Attack.SWIPE or _attack == Attack.THRUST
	if is_melee and not _has_hit and _melee_area.overlaps_body(_target):
		_has_hit = true
		_deal_damage(_target, swipe_damage if _attack == Attack.SWIPE else thrust_damage)

	if _state_time >= _active_time:
		velocity.x = 0.0
		_change_state(State.RECOVER)


func _pick_attack() -> void:
	var pool: Array[Attack] = [Attack.SWIPE, Attack.THRUST]
	if _phase >= 2:
		pool.append(Attack.MAGIC_BOLT)
	if _phase >= 3:
		pool.append(Attack.ANTLER_SPIKES)
	# Far away, a swipe would just be a long walk. Lunge or cast instead.
	if _distance_to_target() > melee_range * 2.5:
		pool.erase(Attack.SWIPE)
	# Keep it readable but not a loop: no attack more than MAX_REPEATS in a row.
	if _repeat_count >= MAX_REPEATS and pool.size() > 1:
		pool.erase(_last_attack)

	_attack = pool.pick_random()
	_repeat_count = _repeat_count + 1 if _attack == _last_attack else 1
	_last_attack = _attack


func _begin_windup() -> void:
	# Facing locks in here, so the player can dodge behind the attack.
	_face(_direction_to_target())
	match _attack:
		Attack.SWIPE:
			_windup_time = swipe_windup
			_sprite.modulate = melee_tint
			_play("swipe")
		Attack.THRUST:
			_windup_time = thrust_windup
			_sprite.modulate = melee_tint
			_play("thrust")
		Attack.MAGIC_BOLT:
			_windup_time = bolt_windup
			_sprite.modulate = magic_tint
			_play("cast")
		Attack.ANTLER_SPIKES:
			_windup_time = spike_windup
			_sprite.modulate = magic_tint
			_play("summon")
	_windup_time *= _pace()


func _begin_active() -> void:
	_has_hit = false
	match _attack:
		Attack.SWIPE:
			_active_time = swipe_active_time
		Attack.THRUST:
			_active_time = thrust_time
		Attack.MAGIC_BOLT:
			_active_time = 0.1
			_fire_bolts()
		Attack.ANTLER_SPIKES:
			_active_time = 0.1
			_summon_spikes()


func _fire_bolts() -> void:
	var origin := global_position + Vector2(BOLT_OFFSET.x * _facing, BOLT_OFFSET.y)
	var aim := origin.direction_to(_target.global_position)
	var count := 1 if _phase < 3 else 3
	for i in count:
		var angle := deg_to_rad(bolt_spread_degrees) * (i - (count - 1) / 2.0)
		var bolt: WolfMagicBolt = BOLT_SCENE.instantiate()
		bolt.top_level = true
		add_child(bolt)
		bolt.hit.connect(_on_hazard_hit)
		bolt.launch(origin, aim.rotated(angle))


## Spikes go under the player and to either side, on the wolf's floor height.
## Assumes a flat arena floor.
func _summon_spikes() -> void:
	var center_x := _target.global_position.x
	for i in spike_count:
		var offset := spike_spacing * (i - (spike_count - 1) / 2.0)
		var spike: WolfAntlerSpike = SPIKE_SCENE.instantiate()
		spike.top_level = true
		add_child(spike)
		spike.hit.connect(_on_hazard_hit)
		spike.global_position = Vector2(center_x + offset, global_position.y)


func _deal_damage(body: Node2D, damage: int) -> void:
	attack_landed.emit(body, damage)
	# Works automatically once the player gets a take_damage(amount) method.
	if body.has_method("take_damage"):
		body.call("take_damage", damage)


## Windups and recovery shrink each phase.
func _pace() -> float:
	return pow(phase_speedup, _phase - 1)


func _phase_for_health() -> int:
	var ratio := float(_health) / float(max_health)
	if ratio <= phase_three_at:
		return 3
	if ratio <= phase_two_at:
		return 2
	return 1


func _direction_to_target() -> float:
	var dir := signf(_target.global_position.x - global_position.x)
	return dir if dir != 0.0 else _facing


func _distance_to_target() -> float:
	return absf(_target.global_position.x - global_position.x)


## Placeholder art faces right; flip_h turns it left.
func _face(dir: float) -> void:
	if dir == 0.0:
		return
	_facing = dir
	_sprite.flip_h = dir < 0.0
	_melee_area.scale.x = dir


## Plays an animation only if the art has it, so missing frames don't crash.
func _play(anim: StringName) -> void:
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


func _flash_hurt() -> void:
	_sprite.self_modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(_sprite, "self_modulate", Color.WHITE, 0.12)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if _state != State.DORMANT:
		return
	_target = body
	fight_started.emit()
	phase_changed.emit(_phase)
	health_changed.emit(_health, max_health)
	# Opening roar gives the player a beat before the first attack.
	_change_state(State.ROAR)


func _on_hazard_hit(body: Node2D, damage: int) -> void:
	attack_landed.emit(body, damage)
