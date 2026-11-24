extends Node

const VFX_SCENES = {
	"dash": preload("res://scenes/components/dash_smoke.tscn"),
}

# TODO: create dictionary for clean function declaration

func play(effect_name: String, position: Vector2, flip_h: bool, offset: Vector2 = Vector2.ZERO) -> void:
	if not VFX_SCENES.has(effect_name):
		push_warning("Unknown VFX: " + effect_name)
		return

	var effect:Node2D = VFX_SCENES[effect_name].instantiate()

	get_tree().current_scene.add_child(effect)
	effect.global_position = position
	
	var sprite := effect.get_node("AnimatedSprite2D")
	sprite.global_position += offset
	sprite.flip_h = flip_h
