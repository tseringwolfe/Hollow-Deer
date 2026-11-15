extends CanvasLayer
## Autoload that swaps levels behind a fade and moves the player to a named spawn point.
## Call SceneManager.change_scene(path, spawn_name). A spawn point is any Node2D
## (usually a Marker2D) in the new level whose name matches spawn_name.
## The game is paused during the fade so nothing can hit the player mid-transition.

signal transition_started(target_path: String)
signal scene_changed(new_scene: Node)

const PLAYER_NODE_NAME := "Player"

@export var fade_time: float = 0.25

var is_transitioning: bool = false

var _fade_rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)


func change_scene(path: String, spawn_name: StringName = &"") -> void:
	if is_transitioning:
		return
	if not ResourceLoader.exists(path):
		push_error("SceneManager: scene not found: %s" % path)
		return
	is_transitioning = true
	transition_started.emit(path)
	get_tree().paused = true
	await _fade_to(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	var new_scene := get_tree().current_scene
	if spawn_name != &"":
		_place_player(new_scene, spawn_name)
	scene_changed.emit(new_scene)
	get_tree().paused = false
	await _fade_to(0.0)
	is_transitioning = false


## Reloads the current level from its start. Useful for death and restart flows.
func reload_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		change_scene(scene.scene_file_path)


func _place_player(scene: Node, spawn_name: StringName) -> void:
	var spawn := scene.find_child(String(spawn_name), true, false) as Node2D
	if spawn == null:
		push_warning("SceneManager: no spawn point named '%s' in %s" % [spawn_name, scene.name])
		return
	var player := scene.find_child(PLAYER_NODE_NAME, true, false) as Node2D
	if player == null:
		push_warning("SceneManager: no node named '%s' in %s" % [PLAYER_NODE_NAME, scene.name])
		return
	player.global_position = spawn.global_position
	for camera: Camera2D in player.find_children("*", "Camera2D", true, false):
		camera.reset_smoothing()


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", alpha, fade_time)
	await tween.finished
