#gdlint: disable=max-line-length
@tool
class_name AfterimageEffect
extends EffectParameters

const NON_SHADER_VARS: Array[String] = []

## Texture containing the input color palette.
@export var input_palette_texture: Texture2D = null:
	set(val):
		if input_palette_texture != val:
			input_palette_texture = val
			emit_changed()
## Optional alternate 1×N palette used for output colors.
@export var effect_palette_texture: Texture2D = null:
	set(val):
		if effect_palette_texture != val:
			effect_palette_texture = val
			emit_changed()
## Inverts the palette color selection logic for the afterimage effect.
@export var inverse_palette: bool = false:
	set(val):
		if inverse_palette != val:
			inverse_palette = val
			emit_changed()
## Starting offset in the palette for afterimage colors.
@export var palette_offset: int = 0:
	set(val):
		if palette_offset != val:
			palette_offset = val
			emit_changed()
## Number of palette colors to use for the afterimage trail. 0 means all colors from offset to end.
@export var palette_range: int = 0:
	set(val):
		if palette_range != val:
			palette_range = val
			emit_changed()
## Starting index in the palette for the active color range filter.
@export var active_palette_offset: int = 0:
	set(val):
		if active_palette_offset != val:
			active_palette_offset = val
			emit_changed()
## Number of palette colors to include in the active range filter. 0 means all colors from offset to end.
@export var active_palette_range: int = 0:
	set(val):
		if active_palette_range != val:
			active_palette_range = val
			emit_changed()
## Only show afterimage for pixels matching colors in the active input palette range.
@export var only_active_colors: bool = false:
	set(val):
		if only_active_colors != val:
			only_active_colors = val
			emit_changed()
## Whether to show the original sprite in the afterimage trail.
@export var show_original: bool = true:
	set(val):
		if show_original != val:
			show_original = val
			emit_changed()
## Distance in pixels from the sprite center for the afterimage rotation.
@export var rotation_radius: float = 2.0:
	set(val):
		if rotation_radius != val:
			rotation_radius = val
			emit_changed()
## Variation in radius across the afterimage trail. 0 = uniform radius, 1 = full variation from 0 to rotation_radius.
@export var radius_variation: float = 0.0:
	set(val):
		if radius_variation != val:
			radius_variation = val
			emit_changed()
## Speed multiplier for the afterimage rotation animation.
@export var rotation_speed: float = 1.0:
	set(val):
		if rotation_speed != val:
			rotation_speed = val
			emit_changed()
## Enables pixel-perfect rendering for the afterimage positions.
@export var pixel_perfect: bool = true:
	set(val):
		if pixel_perfect != val:
			pixel_perfect = val
			emit_changed()
## Blend afterimages together (additive) instead of layering them opaquely. Red Green Blue results in white.
@export var blend_afterimages: bool = true:
	set(val):
		if blend_afterimages != val:
			blend_afterimages = val
			emit_changed()
## The afterimages that are rotating around the center have the current angle distorted based on the uv-coordinates by this amount. Resulting in a swirling effect.
@export var uv_x_angle_distortion: float = 0.0:
	set(val):
		if uv_x_angle_distortion != val:
			uv_x_angle_distortion = val
			emit_changed()
## The afterimages that are rotating around the center have the current angle distorted based on the uv-coordinates by this amount. Resulting in a swirling effect.
@export var uv_y_angle_distortion: float = 0.0:
	set(val):
		if uv_y_angle_distortion != val:
			uv_y_angle_distortion = val
			emit_changed()
## Put afterimages on top of non palette colors.
@export var effect_over_non_palette_colors: bool = false:
	set(val):
		if effect_over_non_palette_colors != val:
			effect_over_non_palette_colors = val
			emit_changed()


func get_non_shader_vars() -> Array[String]:
	return NON_SHADER_VARS
