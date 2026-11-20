extends CharacterBody2D

signal dash_started
signal dash_ended
signal dash_available_changed(available: bool)

const SPEED = 100.0
const JUMP_VELOCITY = -200.0
const TIME_BEFORE_SLIDING = 0.25
const WALL_SLIDE_ACCELERATION = 40.0
const WALL_SLIDE_MAX_SPEED = 220.0
const WALL_JUMP_PUSH_X = 160.0
const WALL_JUMP_VELOCITY_Y = -200.0
const WALL_JUMP_LOCKOUT = 0.12

#dash related exports
@export var dash_speed: float = 300.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.4

var _is_dashing := false
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0 #stops player from dashing forever
var _dash_direction := 1.0
var _can_air_dash := true #we have a one-air-dash limit

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var animated_sprite = $AnimatedSprite2D

var _wall_jump_lockout := 0.0
var _wall_cling_time := 0.0


func _physics_process(delta: float) -> void:
	if is_on_floor() and not _can_air_dash:
		_can_air_dash = true
		dash_available_changed.emit(true)

	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta #reduce timer

	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0 and (is_on_floor() or _can_air_dash):
		_start_dash()

	if _is_dashing:
		_update_dash(delta)
		move_and_slide() #move player using dash velocity
		return

	var on_wall := is_on_wall_only()
	var clinging := on_wall and velocity.y >= 0.0

	# Gravity only applies when not clinging; clinging takes over the Y velocity.
	if not is_on_floor() and not clinging:
		velocity += get_gravity() * delta

	# Wall cling: hold still briefly, then accelerate into a slide up to a max.
	if clinging:
		if _wall_cling_time < TIME_BEFORE_SLIDING:
			velocity.y = 0.0
		else:
			var slide_time := _wall_cling_time - TIME_BEFORE_SLIDING
			velocity.y = min(slide_time * WALL_SLIDE_ACCELERATION, WALL_SLIDE_MAX_SPEED)
		_wall_cling_time += delta
	else:
		_wall_cling_time = 0.0

	# Handle jump / wall jump.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif on_wall:
			var wall_normal := get_wall_normal()
			velocity.x = wall_normal.x * WALL_JUMP_PUSH_X
			velocity.y = WALL_JUMP_VELOCITY_Y
			_wall_jump_lockout = WALL_JUMP_LOCKOUT

	if _wall_jump_lockout > 0.0:
		_wall_jump_lockout -= delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")

	# Flip the sprite
	if direction > 0:
		animated_sprite.flip_h = true
	elif direction < 0:
		animated_sprite.flip_h = false

	# play animations
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("walk")
	else:
		# TODO: swap to a wall_slide animation when it exists.
		animated_sprite.play("jump")

	# During the lockout, preserve the wall-jump push instead of taking input.
	if _wall_jump_lockout <= 0.0:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _start_dash() -> void:
	_is_dashing = true
	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown
	if not is_on_floor():
		_can_air_dash = false
		dash_available_changed.emit(false)

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		_dash_direction = sign(direction)
	#if you press dash without left or right just dash the way youre already facing
	elif animated_sprite.flip_h:
		_dash_direction = 1.0 #right
	else:
		_dash_direction = -1.0 #left
	dash_started.emit()

func _update_dash(delta: float) -> void:
	velocity.x = _dash_direction * dash_speed
	velocity.y = 0.0
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_is_dashing = false
		dash_ended.emit()