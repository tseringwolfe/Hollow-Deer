extends CharacterBody2D

const SPEED = 100.0
const JUMP_VELOCITY = -200.0
const TIME_BEFORE_SLIDING = 0.25
const WALL_SLIDE_ACCELERATION = 40.0
const WALL_SLIDE_MAX_SPEED = 220.0
const WALL_JUMP_PUSH_X = 160.0
const WALL_JUMP_VELOCITY_Y = -200.0
const WALL_JUMP_LOCKOUT = 0.12

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var animated_sprite = $AnimatedSprite2D

var _wall_jump_lockout := 0.0
var _wall_cling_time := 0.0


func _physics_process(delta: float) -> void:
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
