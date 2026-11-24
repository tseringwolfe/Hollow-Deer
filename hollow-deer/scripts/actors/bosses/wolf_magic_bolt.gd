class_name WolfMagicBolt
extends Area2D
## A slow magic bolt fired by the Wolf in phases 2 and 3.
## Damages the first player-layer body it touches; walls just destroy it.

signal hit(body: Node2D, damage: int)

@export var speed: float = 110.0
@export var damage: int = 1
@export var lifetime: float = 4.0

var _direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func launch(from: Vector2, direction: Vector2) -> void:
	global_position = from
	_direction = direction.normalized()
	rotation = _direction.angle()


func _on_body_entered(body: Node2D) -> void:
	# Collision mask is world (1) + player (2), so anything else here is a wall.
	# (TileMapLayer walls are not CollisionObject2D, hence the type check.)
	if body is CollisionObject2D and (body as CollisionObject2D).collision_layer & 2:
		hit.emit(body, damage)
		if body.has_method("take_damage"):
			body.call("take_damage", damage)
	queue_free()
