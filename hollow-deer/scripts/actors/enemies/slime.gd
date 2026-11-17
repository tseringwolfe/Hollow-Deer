class_name Slime
extends EnemyBase
## Moves in hops instead of walking, both on patrol and when chasing.

@export var hop_velocity: float = -140.0
@export var hop_interval: float = 0.6

var _hop_wait: float = 0.0


func _move_in_direction(dir: float, speed: float, delta: float) -> bool:
	if not is_on_floor():
		return true
	velocity.x = 0.0
	_hop_wait -= delta
	if _hop_wait > 0.0:
		return true
	_face(dir)
	# A hop covers more ground than a step, so look farther for a ledge.
	if _is_path_blocked(dir, speed * hop_interval):
		return false
	velocity = Vector2(dir * speed, hop_velocity)
	_hop_wait = hop_interval
	return true
