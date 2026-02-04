#gdlint: disable=max-line-length
@tool
class_name IterativeFireEffect
extends EffectParameters

const NON_SHADER_VARS: Array[String] = ["fps", "show_original", "original_behind"]

## Disable the shader effect.
@export var disable: bool = false:
	set(val):
		if disable != val:
			disable = val
			emit_changed()
## Disable the emission of new effect pixels.
@export var disable_emission: bool = false:
	set(val):
		if disable_emission != val:
			disable_emission = val
			emit_changed()
## 1×N strip of colors used for mapping. Import with filter: [code]Nearest[/code].
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
## Reverses input palette for mapping input to output palette color.
@export var inverse_palette: bool = false:
	set(val):
		if inverse_palette != val:
			inverse_palette = val
			emit_changed()
## Starting index within the input palette to consider.
@export var input_palette_offset: int = 0:
	set(val):
		if input_palette_offset != val:
			input_palette_offset = val
			emit_changed()
## Number of colors from [code]input_palette_offset[/code] to include. [code]-1[/code] (or ≤0) means until end.
@export var input_palette_range: int = -1:
	set(val):
		if input_palette_range != val:
			input_palette_range = val
			emit_changed()
## Starting index within the output/effect palette used for mapping.
@export var output_palette_offset: int = 0:
	set(val):
		if output_palette_offset != val:
			output_palette_offset = val
			emit_changed()
## Number of colors from [code]output_palette_offset[/code] to allow. [code]-1[/code] (or ≤0) means until end.
@export var output_palette_range: int = -1:
	set(val):
		if output_palette_range != val:
			output_palette_range = val
			emit_changed()
## When enabled, preserves relative index: output_id = output_offset + (input_id - input_offset).
@export var map_palette_ids: bool = true:
	set(val):
		if map_palette_ids != val:
			map_palette_ids = val
			emit_changed()
## Horizontal flow component in [-1, 1]. The pixels flow in this direction per iteration. Through iteration_count, values < 1.0 accumulate until 1.0 to take effect.
@export var flow_direction_x: float = 0.0:
	set(val):
		if flow_direction_x != val:
			flow_direction_x = val
			emit_changed()
## Vertical flow component in [-1, 1]. The pixels flow in this direction per iteration. Through iteration_count, values < 1.0 accumulate until 1.0 to take effect.
@export var flow_direction_y: float = 1.0:
	set(val):
		if flow_direction_y != val:
			flow_direction_y = val
			emit_changed()
## Sub-steps per frame used to simulate multiple iterations per render step for low fps effects.
@export var iterations: int = 1:
	set(val):
		if iterations != val:
			iterations = val
			emit_changed()
## Global iteration index used to stagger fractional flow over frames for non 1.0 flow values.
@export var iteration_count: int = 0:
	set(val):
		if iteration_count != val:
			iteration_count = val
			emit_changed()
## Base seed used for random sampling in decay/spawn decisions.
@export var random_seed: float = 0.0:
	set(val):
		if random_seed != val:
			random_seed = val
			emit_changed()
## Frequency parameter for random sampling function.
@export var random_frequency: float = 100.0:
	set(val):
		if random_frequency != val:
			random_frequency = val
			emit_changed()
## Probability [0..1] that a valid input pixel spawns a trail on this step.
@export var spawn_chance: float = 1.0:
	set(val):
		if spawn_chance != val:
			spawn_chance = val
			emit_changed()
## Higher values resist decay; lower values advance decay faster.
@export var trail_persistence: float = 0.5:
	set(val):
		if trail_persistence != val:
			trail_persistence = val
			emit_changed()
## Lateral diffusion amount. [code]>0[/code] adopts neighbors -> spreads to the sides; [code]<0[/code] forces edge decay -> shrinks from sides; [code]0[/code] disables spread.
@export var spread: float = 0.0:
	set(val):
		if spread != val:
			spread = val
			emit_changed()
## Allows input pixels with higher palette IDs to override decay feedback.
@export var overlay_higher_colors: bool = true:
	set(val):
		if overlay_higher_colors != val:
			overlay_higher_colors = val
			emit_changed()
## Limits spawning to only outside the active input colors area.
@export var only_edge_emit: bool = false:
	set(val):
		if only_edge_emit != val:
			only_edge_emit = val
			emit_changed()
## Distance threshold (in pixels) from texture bounds where decay is forced.
@export var edge_pixel_size: int = 2:
	set(val):
		if edge_pixel_size != val:
			edge_pixel_size = val
			emit_changed()
## Ignore the input palette in iterative effects.
@export var ignore_input_palette: bool = false:
	set(val):
		if ignore_input_palette != val:
			ignore_input_palette = val
			emit_changed()
@export var fps: float = 20.0:
	set(val):
		if fps != val:
			fps = val
			emit_changed()
@export var show_original: bool = false:
	set(val):
		if show_original != val:
			show_original = val
			emit_changed()
@export var original_behind: bool = true:
	set(val):
		if original_behind != val:
			original_behind = val
			emit_changed()


func get_non_shader_vars() -> Array[String]:
	return NON_SHADER_VARS
