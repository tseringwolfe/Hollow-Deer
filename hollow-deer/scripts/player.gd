extends CharacterBody2D

const SPEED = 100.0
const JUMP_VELOCITY = -200.0
const WALL_SLIDE_SPEED = 40.0
const WALL_JUMP_PUSH_X = 160.0
const WALL_JUMP_VELOCITY_Y = -200.0
const WALL_JUMP_LOCKOUT = 0.12

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var animated_sprite = $AnimatedSprite2D

var _wall_jump_lockout := 0.0


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	var on_wall := is_on_wall_only()

	# Wall slide: cap downward speed while hugging a wall mid-air.
	if on_wall and velocity.y > 0:
		velocity.y = min(velocity.y, WALL_SLIDE_SPEED)

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
