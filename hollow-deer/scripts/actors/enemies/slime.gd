class_name Slime
extends EnemyBase
## Moves in hops toward the player instead of walking.

@export var hop_velocity: float = -140.0
@export var hop_interval: float = 0.6

var _hop_wait: float = 0.0


func _move_toward_target(delta: float) -> void:
	if not is_on_floor():
		return
	velocity.x = 0.0
	_hop_wait -= delta
	if _hop_wait > 0.0:
		return
	var dir := _direction_to_target()
	_face(dir)
	velocity = Vector2(dir * move_speed, hop_velocity)
	_hop_wait = hop_interval
