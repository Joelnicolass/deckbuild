#gdlint: disable=max-line-length
@tool
class_name FuzzyEffect
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
## Threshold for considering palette differences between neighboring pixels. Larger values make the effect occur between colors further apart in the palette.
@export var palette_diff_threshold: int = 0:
	set(val):
		if palette_diff_threshold != val:
			palette_diff_threshold = val
			emit_changed()
## Percentage of how many pixels should be affected by the fuzziness effect.
@export var fuzziness: float = 0.5:
	set(val):
		if fuzziness != val:
			fuzziness = val
			emit_changed()
## Level of fragmentation for the fuzziness effect. Negative values make the fuzziness effect more coherent across multiple pixels, positive values fragment the fuzziness effect to sub-pixel sizes.
@export var fragmentation_level: int = 0:
	set(val):
		if fragmentation_level != val:
			fragmentation_level = val
			emit_changed()
## The displaced pixels are more random.
@export var random_fuzz: bool = false:
	set(val):
		if random_fuzz != val:
			random_fuzz = val
			emit_changed()
## Whether the fuzziness effect changes over time.
@export var time_shift: bool = false:
	set(val):
		if time_shift != val:
			time_shift = val
			emit_changed()
## Speed of the time-based shift for the fuzziness effect.
@export var time_speed: float = 8.0:
	set(val):
		if time_speed != val:
			time_speed = val
			emit_changed()
## Ignore the input palette and use the original colors.
@export var ignore_palette: bool = false:
	set(val):
		if ignore_palette != val:
			ignore_palette = val
			emit_changed()


func get_non_shader_vars() -> Array[String]:
	return NON_SHADER_VARS
