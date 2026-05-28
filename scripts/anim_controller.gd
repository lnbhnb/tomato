extends Node
class_name CharacterAnimController

var animated_sprite: AnimatedSprite2D


func _init(sprite: AnimatedSprite2D = null):
	animated_sprite = sprite


func setup(sprite: AnimatedSprite2D):
	animated_sprite = sprite


func play_animation(state_name: String):
	if not animated_sprite:
		return
	var anim_name = state_name.to_lower()
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		push_warning("Animation not found: " + anim_name)
