extends TextureRect


func _on_mouse_entered() -> void:
	material.set_shader_parameter("mouse_position", get_global_mouse_position())
	material.set_shader_parameter("sprite_position", global_position)
	print("mouse_position: ", get_global_mouse_position())
	print("sprite_position: ", global_position)

func _on_mouse_exited() -> void:
	material.set_shader_parameter("mouse_position", Vector2.ZERO)
	material.set_shader_parameter("sprite_position", Vector2.ZERO)
	print("mouse_position: ", Vector2.ZERO)
	print("sprite_position: ", Vector2.ZERO)