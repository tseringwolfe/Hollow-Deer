class_name Slime
extends EnemyBase
## Moves in hops instead of walking, both on patrol and when chasing.

@export var hop_velocity: float = -140.0
@export var hop_interval: float = 0.6

var _hop_wait: float = 0.0


func _move_in_direction(dir: float, speed: float, delta: float) -> bool:
	if not is_on_floor():
		# Hit a wall mid-hop: stop pushing into it, and report it as blocked
		# so a patrolling slime turns around.
		if is_on_wall():
			velocity.x = 0.0
			return false
		return true
	velocity.x = 0.0
	_hop_wait -= delta
	if _hop_wait > 0.0:
		return true
	_face(dir)
	var launch := Vector2(dir * speed, hop_velocity)
	if not _can_land_hop(launch, delta):
		return false
	velocity = launch
	_hop_wait = hop_interval
	return true


func _can_land_hop(launch: Vector2, delta: float) -> bool:
	var gravity := get_gravity()
	if gravity.y <= 0.0 or launch.y >= 0.0:
		return false
	var lifted := global_transform.translated(Vector2(0.0, -2.0))
	if test_move(lifted, Vector2(signf(launch.x) * ledge_check_distance, 0.0)):
		return false

	# Sweep the body along the same steps used by EnemyBase. Gravity starts
	# on the tick after launch, and floor deeper than the drop limit is unsafe.
	var offset := Vector2.ZERO
	var step_velocity := launch
	var collision := KinematicCollision2D.new()
	var drop_limit := maxf(ledge_check_depth, 0.0)
	while offset.y <= drop_limit:
		var step := step_velocity * delta
		var reaches_drop_limit := step.y > 0.0 and offset.y + step.y >= drop_limit
		if reaches_drop_limit:
			step *= (drop_limit - offset.y) / step.y
		if test_move(global_transform.translated(offset), step, collision):
			return collision.get_normal().dot(up_direction) >= cos(floor_max_angle)
		if reaches_drop_limit:
			break
		offset += step
		step_velocity += gravity * delta
	return false
