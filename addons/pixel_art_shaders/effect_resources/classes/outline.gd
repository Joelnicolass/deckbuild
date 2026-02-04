#gdlint: disable=max-line-length
@tool
class_name OutlineEffect
extends EffectParameters

const NON_SHADER_VARS: Array[String] = []

## Disable the shader effect.
@export var disable: bool = false:
	set(val):
		if disable != val:
			disable = val
			emit_changed()
## Keep the original colors of border pixels (pixels adjacent to transparent pixels).
@export var keep_border_colors: bool = true:
	set(val):
		if keep_border_colors != val:
			keep_border_colors = val
			emit_changed()
## Texture containing the color palette.
@export var input_palette_texture: Texture2D = null:
	set(val):
		if input_palette_texture != val:
			input_palette_texture = val
			emit_changed()
## Threshold for considering palette differences between neighboring pixels. Larger values make the effect occur between colors further apart in the palette. 0 disables the threshold, so the effect is applied to all neighboring pixels.
@export var palette_diff_threshold: int = 1:
	set(val):
		if palette_diff_threshold != val:
			palette_diff_threshold = val
			emit_changed()
## Thickness scale for the outline effect. Modifies the distance at which neighboring pixels are considered. Values smaller than 1.0 make the outline smaller than the original pixel size, values larger than 1.0 make the outline thicker.
@export var offset_scale: float = 1.0:
	set(val):
		if offset_scale != val:
			offset_scale = val
			emit_changed()
## Minimum palette jump for outline effect to occur.
@export var palette_min_jump: float = 1.0:
	set(val):
		if palette_min_jump != val:
			palette_min_jump = val
			emit_changed()
## Maximum palette jump for outline effect to occur.
@export var palette_max_jump: float = 4.0:
	set(val):
		if palette_max_jump != val:
			palette_max_jump = val
			emit_changed()
## Ignore the input palette and use the original colors.
@export var ignore_palette: bool = false:
	set(val):
		if ignore_palette != val:
			ignore_palette = val
			emit_changed()
## Treat transparent pixels as a color for outline calculations.
@export var treat_transparent_as_color: bool = false:
	set(val):
		if treat_transparent_as_color != val:
			treat_transparent_as_color = val
			emit_changed()


func get_non_shader_vars() -> Array[String]:
	return NON_SHADER_VARS
