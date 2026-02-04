@tool
class_name FeedbackTextureMasked
extends FeedbackTexture

## [b]Mask Texture[/b]
## [color=gray]Optional texture to use as a mask for the extended area.[/color]
@export var mask_texture: Texture:
	set(value):
		mask_texture = value
		_update_texture()

## [b]Use Mask Color[/b]
## [color=gray]If enabled, the specified mask color will be applied to the extended area.[/color]
@export var use_mask_color: bool = false:
	set(value):
		use_mask_color = value
		_update_material_settings()

## [b]Mask Color[/b]
## [color=gray]Color to apply to the extended area if 'Use Mask Color' is enabled.[/color]
@export var mask_color: Color = Color.WHITE:
	set(value):
		mask_color = value
		_update_material_settings()


func _update_material_settings() -> void:
	super()
	for i in range(2):
		if is_instance_valid(_texture_rect[i]) and is_instance_valid(_texture_rect[i].material):
			if use_mask_color:
				_texture_rect[i].material.set_shader_parameter("use_mask_color", true)
				_texture_rect[i].material.set_shader_parameter("mask_color", mask_color)
			else:
				_texture_rect[i].material.set_shader_parameter("use_mask_color", false)
				_texture_rect[i].material.set_shader_parameter("mask_color", mask_color)
			if is_instance_valid(mask_texture):
				_texture_rect[i].material.set_shader_parameter("use_mask_texture", true)
				_texture_rect[i].material.set_shader_parameter("mask_texture", mask_texture)
			else:
				_texture_rect[i].material.set_shader_parameter("use_mask_texture", false)
