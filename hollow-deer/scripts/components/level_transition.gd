@tool
class_name LevelTransition
extends Area2D
## Exit zone. When the player walks in, SceneManager loads target_scene and moves the
## player to the node named target_spawn in that scene.
## Set enabled to false to keep an exit shut until something calls set_enabled(true),
## for example when an EncounterTrigger finishes.

signal triggered

@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn: StringName = &""
@export var enabled: bool = true
@export var size: Vector2 = Vector2(16.0, 48.0):
	set(value):
		size = value
		_update_shape()

var _used: bool = false

@onready var _shape: CollisionShape2D = %CollisionShape2D


func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	assert(target_scene != "", "%s has no target_scene" % name)
	body_entered.connect(_on_body_entered)


func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and not get_overlapping_bodies().is_empty():
		_trigger()


func _on_body_entered(_body: Node2D) -> void:
	_trigger()


func _trigger() -> void:
	if _used or not enabled:
		return
	# Looked up at runtime so this @tool script compiles in the editor without the autoload.
	var manager := get_node("/root/SceneManager")
	# Ignore entries during a fade, but stay usable so the exit works on the next entry.
	if manager.get(&"is_transitioning"):
		return
	# A missing target would be rejected by SceneManager; stay usable instead of latching.
	if not ResourceLoader.exists(target_scene):
		push_warning("%s: target scene not found: %s" % [name, target_scene])
		return
	_used = true
	triggered.emit()
	manager.change_scene(target_scene, target_spawn)


func _update_shape() -> void:
	if not is_node_ready():
		return
	(_shape.shape as RectangleShape2D).size = size
