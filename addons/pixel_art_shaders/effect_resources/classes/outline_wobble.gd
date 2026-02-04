#gdlint: disable=max-line-length
@tool
class_name OutlineWobbleEffect
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
## Whether the noise sampling coordinates are offset over time to animate the wobble effect.
@export var time_shift: bool = true:
	set(val):
		if time_shift != val:
			time_shift = val
			emit_changed()
## Speed multiplier applied to TIME when time shifting the noise. Higher values make the wobble animate faster. Typical range is 0.1 - 100.0.
@export var time_speed: float = 8.0:
	set(val):
		if time_speed != val:
			time_speed = val
			emit_changed()
## Controls the granularity of the noise tiling used for threshold calculation. Values > 1 increase the pixelated fragmentation of the noise sampling; smaller values make the effect more coherent across multiple pixels.
@export var random_fragmentation: float = 1.0:
	set(val):
		if random_fragmentation != val:
			random_fragmentation = val
			emit_changed()
## Noise texture used as a source of pseudo-random values for computing palette jump thresholds. Should be a tiled noise texture.
@export var noise_texture: Texture2D = null:
	set(val):
		if noise_texture != val:
			noise_texture = val
			emit_changed()
## Scales the coordinate space used when sampling the noise texture. Values < 1 zoom in on the noise, values > 1 tile the noise more densely. Typical range is 0.1 - 10.0.
@export var noise_scale: float = 1.0:
	set(val):
		if noise_scale != val:
			noise_scale = val
			emit_changed()


func get_non_shader_vars() -> Array[String]:
	return NON_SHADER_VARS
