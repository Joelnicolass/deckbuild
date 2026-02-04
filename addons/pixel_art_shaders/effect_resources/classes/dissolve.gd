#gdlint: disable=max-line-length
@tool
class_name DissolveEffect
extends EffectParameters

const NON_SHADER_VARS: Array[String] = []

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
## Texture containing the color palette.
@export var input_palette_texture: Texture2D = null:
	set(val):
		if input_palette_texture != val:
			input_palette_texture = val
			emit_changed()
## Whether to shift each pixel's color along the palette during the dissolve.
## Enable to remap colors over time; disable to only mask pixels without recoloring.
@export var palette_shift: bool = true:
	set(val):
		if palette_shift != val:
			palette_shift = val
			emit_changed()
## Reverses the palette shift direction.
## When true, colors move toward lower palette indices; otherwise toward higher indices.
@export var inverse_palette_shift: bool = false:
	set(val):
		if inverse_palette_shift != val:
			inverse_palette_shift = val
			emit_changed()
## Level of pixelization for the dissolve effect. Higher values make the dissolve pixels larger.
@export var pixelization: int = 0:
	set(val):
		if pixelization != val:
			pixelization = val
			emit_changed()
## Thickness of the tinted dissolve edge band (0.0–1.0).
## Higher values produce a wider rim around the dissolving area.
@export var dissolve_border_size: float = 0.1:
	set(val):
		if dissolve_border_size != val:
			dissolve_border_size = val
			emit_changed()
## Enables color tinting along the dissolve edge.
## When true, blends between dissolve_color_from and dissolve_color_to over progress.
@export var use_dissolve_color: bool = false:
	set(val):
		if use_dissolve_color != val:
			use_dissolve_color = val
			emit_changed()
## Starting tint color for the dissolve gradient.
## Interpolates toward dissolve_color_to as progress increases.
@export var dissolve_color_from: Color = Color(0.0, 0.0, 0.0, 0.0):
	set(val):
		if dissolve_color_from != val:
			dissolve_color_from = val
			emit_changed()
## Ending tint color for the dissolve gradient.
## Reached when dissolve progress is 1.0.
@export var dissolve_color_to: Color = Color(0.0, 0.0, 0.0, 0.0):
	set(val):
		if dissolve_color_to != val:
			dissolve_color_to = val
			emit_changed()
## Overall intensity multiplier for the dissolve tint (0.0–5.0).
## Higher values produce a stronger color influence.
@export var dissolve_color_strength: float = 0.5:
	set(val):
		if dissolve_color_strength != val:
			dissolve_color_strength = val
			emit_changed()
## Ignore the input palette and use the original colors.
@export var ignore_palette: bool = false:
	set(val):
		if ignore_palette != val:
			ignore_palette = val
			emit_changed()


func get_non_shader_vars() -> Array[String]:
	return NON_SHADER_VARS
