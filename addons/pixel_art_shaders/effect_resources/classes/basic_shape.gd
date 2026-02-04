#gdlint: disable=max-line-length
@tool
class_name BasicShapeEffect
extends EffectParameters

const NON_SHADER_VARS: Array[String] = []

## Disable the shader effect.
@export var disable: bool = false:
	set(val):
		if disable != val:
			disable = val
			emit_changed()
## Texture containing the color palette.
@export var input_palette_texture: Texture2D = null:
	set(val):
		if input_palette_texture != val:
			input_palette_texture = val
			emit_changed()
## Size of the shape representing a pixel.
@export var shape_size: float = 1.0:
	set(val):
		if shape_size != val:
			shape_size = val
			emit_changed()
## Prefer higher palette IDs when pixel shapes overlap.
@export var prefer_higher_palette_ids: bool = false:
	set(val):
		if prefer_higher_palette_ids != val:
			prefer_higher_palette_ids = val
			emit_changed()
## Shape used for pixels.
## [b]0[/b] for [b]Circle[/b][br][b]1[/b] for [b]Diamond[/b][br][b]2[/b] for [b]Vertical Hexagon[/b][br][b]3[/b] for [b]Horizontal Hexagon[/b][br][b]4[/b] for [b]Octagon[/b][br][b]5[/b] for [b]Square[/b]
@export var pixel_shape: int = 0:
	set(val):
		if pixel_shape != val:
			pixel_shape = val
			emit_changed()
## X Offset for every other column in pixels
@export var offset_x: float = 0.0:
	set(val):
		if offset_x != val:
			offset_x = val
			emit_changed()
## Y Offset for every other row in pixels
@export var offset_y: float = 0.0:
	set(val):
		if offset_y != val:
			offset_y = val
			emit_changed()


func get_non_shader_vars() -> Array[String]:
	return NON_SHADER_VARS
