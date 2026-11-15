@tool
class_name EncounterTrigger
extends Area2D
## Combat room. When the player walks in, the barriers close and encounter_started fires.
## Once every node in `enemies` is defeated, the barriers open and encounter_completed fires.
## An enemy counts as defeated when it emits `died` (EnemyBase, WolfBoss) or leaves the tree.
## Barriers are any Node2D (usually a StaticBody2D wall); they are hidden and non-solid
## until the encounter starts.

signal encounter_started
signal encounter_completed

@export var enemies: Array[Node] = []
@export var barriers: Array[Node2D] = []
@export var size: Vector2 = Vector2(16.0, 64.0):
	set(value):
		size = value
		_update_shape()

var is_active: bool = false
var is_completed: bool = false

var _defeated: Dictionary = {}

@onready var _shape: CollisionShape2D = %CollisionShape2D


func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	for enemy: Node in enemies:
		if enemy == null:
			continue
		var id := enemy.get_instance_id()
		if enemy.has_signal("died"):
			enemy.connect("died", _on_enemy_defeated.bind(id), CONNECT_ONE_SHOT)
		enemy.tree_exited.connect(_on_enemy_defeated.bind(id), CONNECT_ONE_SHOT)
	_set_barriers_active(false)
	body_entered.connect(_on_body_entered)


## Starts the encounter. Called automatically when the player enters; levels can also call it.
func start() -> void:
	if is_active or is_completed:
		return
	is_active = true
	_set_barriers_active(true)
	encounter_started.emit()
	_check_completed()


func get_remaining_count() -> int:
	var count := 0
	for enemy: Node in enemies:
		if enemy != null and not _defeated.has(enemy.get_instance_id()):
			count += 1
	return count


func _on_body_entered(_body: Node2D) -> void:
	start()


func _on_enemy_defeated(id: int) -> void:
	_defeated[id] = true
	_check_completed()


func _check_completed() -> void:
	if not is_active or is_completed or get_remaining_count() > 0:
		return
	is_active = false
	is_completed = true
	if is_inside_tree():
		_set_barriers_active(false)
	encounter_completed.emit()


func _set_barriers_active(active: bool) -> void:
	for barrier: Node2D in barriers:
		if not is_instance_valid(barrier):
			continue
		barrier.visible = active
		for shape: CollisionShape2D in barrier.find_children("*", "CollisionShape2D", true, false):
			shape.set_deferred("disabled", not active)


func _update_shape() -> void:
	if not is_node_ready():
		return
	(_shape.shape as RectangleShape2D).size = size
