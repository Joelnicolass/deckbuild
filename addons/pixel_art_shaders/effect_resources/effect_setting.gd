#gdlint: disable=max-line-length
@tool
## [b]Effect Setting[/b]
## A resource that configures a single instance of a pixel art effect, including its type, palette, and parameters.
class_name EffectSetting
extends Resource

static var _next_id: int = 1

## [b]ID[/b]
## A unique numerical identifier for this effect setting instance.
## Automatically assigned during initialization but can be manually overridden.
@export var id: int:
	set(value):
		id = value
		emit_changed()

## [b]Name[/b]
## A human-readable name for the effect, used for referencing it (e.g., in BBCode tags).
@export var name: String:
	set(value):
		name = value
		emit_changed()

## [b]Effect Type[/b]
## The name of the shader effect to apply (e.g., "Outline", "Dissolve").
## This string corresponds to keys in the [ShaderRegistry].
## Setting this property automatically updates [member replace_character] and [member suffix].
@export var effect_type: String:
	set(value):
		effect_type = value
		replace_character = effect_type in ["Dissolve", "Afterimage", "Fuzzy", "Edge Shape", "Outline", "Outline Wobble", "Outline Cursor"]
		suffix = "_ext_mask"
		# Disabling preprocessing until it works on all platforms and works properly in Godot 4.6
		# if effect_type in ["Outline", "Outline Wobble", "Outline Cursor"] and OS.get_name() != "Web":
		#	suffix = "_pre_ext_mask"
		emit_changed()

## [b]Effect Parameters[/b]
## A resource holding the specific uniform values for the selected [member effect_type].
## The type of this resource should match the expected parameters of the shader.
@export var effect_parameters: EffectParameters:
	set(value):
		if is_instance_valid(effect_parameters):
			effect_parameters.changed.disconnect(emit_changed)
		effect_parameters = value
		if is_instance_valid(effect_parameters):
			effect_parameters.changed.connect(emit_changed)
		emit_changed()

## [b]Primary Palette[/b]
## An array of colors used as the input palette for the effect.
## Used by shaders that require palette swapping or mapping.
@export var input_palette: Array[Color] = []:
	set(value):
		input_palette = value
		emit_changed()

## [b]Secondary Palette[/b]
## An array of colors used as the secondary or effect palette.
## Often used to define target colors for effects like dissolves or outlines.
@export var effect_palette: Array[Color] = []:
	set(value):
		effect_palette = value
		emit_changed()

## [b]Normalize Time[/b]
## If [code]true[/code], the 'time' uniform passed to the shader will be normalized (0.0 to 1.0) based on animation duration.
## If [code]false[/code], 'time' will be set to -1.0, often disabling time-based animations or indicating static rendering.
@export var normalize_time: bool = true:
	set(value):
		normalize_time = value
		emit_changed()

var active: bool = false
var replace_character: bool = false
var suffix: String = ""


func _init(p_name: String = "", p_effect_type: String = "", p_params: EffectParameters = null, p_input_palette: Array[Color] = [], p_effect_palette: Array[Color] = [], p_normalize_time: bool = true) -> void:
	id = _next_id
	_next_id += 1
	name = p_name if p_name != "" else "%d" % id
	effect_type = p_effect_type if p_effect_type != "" else "Iterative Fire"
	effect_parameters = p_params
	input_palette = p_input_palette
	effect_palette = p_effect_palette
	normalize_time = p_normalize_time
	replace_character = effect_type in ["Dissolve", "Afterimage", "Fuzzy", "Edge Shape", "Outline", "Outline Wobble", "Outline Cursor"]
	suffix = "_ext_mask"
	if effect_type in ["Outline", "Outline Wobble", "Outline Cursor"] and OS.get_name() != "Web":
		suffix = "_pre_ext_mask"
