class_name WolfAntlerSpike
extends Area2D
## Phase 3 attack: a magic antler that bursts out of the floor.
## Shows a blinking floor marker first so the player can step away,
## then rises, hurts anything on the player layer once, and sinks again.

signal hit(body: Node2D, damage: int)

@export var damage: int = 1
@export var warning_time: float = 0.7
@export var active_time: float = 0.35

var _age: float = 0.0
var _rising: bool = false
var _hit_bodies: Array[Node2D] = []

@onready var _warning: CanvasItem = %Warning
@onready var _spike: Node2D = %Spike


func _ready() -> void:
	_spike.scale.y = 0.0
	var blink := create_tween().set_loops(int(warning_time / 0.2))
	blink.tween_property(_warning, "modulate:a", 0.2, 0.1)
	blink.tween_property(_warning, "modulate:a", 1.0, 0.1)


func _physics_process(delta: float) -> void:
	_age += delta
	if not _rising and _age >= warning_time:
		_rise()
	if _rising:
		for body in get_overlapping_bodies():
			if body not in _hit_bodies:
				_hit_bodies.append(body)
				hit.emit(body, damage)
				if body.has_method("take_damage"):
					body.call("take_damage", damage)
	if _age >= warning_time + active_time:
		set_physics_process(false)
		_sink()


func _rise() -> void:
	_rising = true
	_warning.visible = false
	create_tween().tween_property(_spike, "scale:y", 1.0, 0.06)


func _sink() -> void:
	_rising = false
	var tween := create_tween()
	tween.tween_property(_spike, "scale:y", 0.0, 0.15)
	tween.finished.connect(queue_free)
