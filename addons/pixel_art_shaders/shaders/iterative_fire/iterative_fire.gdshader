shader_type canvas_item;
render_mode unshaded, blend_disabled;

//VARIATIONOPTIONS_START: EXTEND_FRAME,MASK_EFFECT

group_uniforms Feedback_Settings;
/**
 * Disable the shader effect.
 */
uniform bool disable = false;
/**
 * Disable the emission of new effect pixels.
 */
uniform bool disable_emission = false;
/**
 * Optional input texture if built-in TEXTURE should not be used.
 */
uniform sampler2D original_texture : hint_default_black; // Value usually set through script
/**
 * Time value for animating the fuzziness effect. If negative, uses TIME.
 */
uniform float time = -1.0; // DYNAMIC SETTING

group_uniforms Palette_Settings;
/**
 * 1×N strip of colors used for mapping. Import with filter: [code]Nearest[/code].
 */
uniform sampler2D input_palette_texture : filter_nearest;
/**
 * Optional alternate 1×N palette used for output colors.
 */
uniform sampler2D effect_palette_texture : filter_nearest;
/**
 * Reverses input palette for mapping input to output palette color.
 */
uniform bool inverse_palette = false;

group_uniforms Mapping_Settings;
/**
 * Starting index within the input palette to consider.
 */
uniform int input_palette_offset = 0;
/**
 * Number of colors from [code]input_palette_offset[/code] to include. [code]-1[/code] (or ≤0) means until end.
 */
uniform int input_palette_range = -1;
/**
 * Starting index within the output/effect palette used for mapping.
 */
uniform int output_palette_offset = 0;
/**
 * Number of colors from [code]output_palette_offset[/code] to allow. [code]-1[/code] (or ≤0) means until end.
 */
uniform int output_palette_range = -1;
/**
 * When enabled, preserves relative index: output_id = output_offset + (input_id - input_offset).
 */
uniform bool map_palette_ids = true;

group_uniforms Flow_Settings;
/**
 * Horizontal flow component in [-1, 1]. The pixels flow in this direction per iteration. Through iteration_count, values < 1.0 accumulate until 1.0 to take effect.
 */
uniform float flow_direction_x : hint_range(-1.0, 1.0, 0.0001) = 0.0;
/**
 * Vertical flow component in [-1, 1]. The pixels flow in this direction per iteration. Through iteration_count, values < 1.0 accumulate until 1.0 to take effect.
 */
uniform float flow_direction_y : hint_range(-1.0, 1.0, 0.0001) = 1.0;
/**
 * Sub-steps per frame used to simulate multiple iterations per render step for low fps effects.
 */
uniform int iterations : hint_range(1, 100) = 1;
/**
 * Global iteration index used to stagger fractional flow over frames for non 1.0 flow values.
 */
uniform int iteration_count = 0;

group_uniforms Random_Settings;
/**
 * Base seed used for random sampling in decay/spawn decisions.
 */
uniform float random_seed : hint_range(0.0, 1000.0) = 0.0;
/**
 * Frequency parameter for random sampling function.
 */
uniform float random_frequency : hint_range(0.0, 100.0) = 100.0;
/**
 * Probability [0..1] that a valid input pixel spawns a trail on this step.
 */
uniform float spawn_chance : hint_range(0.0, 1.0) = 1.0;

group_uniforms Effect_Settings;
/**
 * Higher values resist decay; lower values advance decay faster.
 */
uniform float trail_persistence : hint_range(0.0, 1.0) = 0.5;
/**
 * Lateral diffusion amount. [code]>0[/code] adopts neighbors -> spreads to the sides; [code]<0[/code] forces edge decay -> shrinks from sides; [code]0[/code] disables spread.
 */
uniform float spread : hint_range(-1.0, 1.0, 0.0001) = 0.0;
/**
 * Allows input pixels with higher palette IDs to override decay feedback.
 */
uniform bool overlay_higher_colors = true;
/**
 * Limits spawning to only outside the active input colors area.
 */
uniform bool only_edge_emit = false;
/**
 * Distance threshold (in pixels) from texture bounds where decay is forced.
 */
uniform int edge_pixel_size : hint_range(0, 100) = 2;
/**
 * Ignore the input palette in iterative effects.
 */
uniform bool ignore_input_palette = false;

/**
 * Ignore the input palette and use the original colors.
 */
const bool ignore_palette = false;

// Non-uniforms variables
// external float fps = 20.0;
// external bool show_original = false;
// external bool original_behind = true;

#ifdef EXTEND_FRAME
group_uniforms Extend_Frame;
/**
 * Use original texture instead of built-in TEXTURE.
 */
uniform bool use_input_texture = false; // Value usually set through script
/**
 * Border pixel size if the original texture is used and the resulting texture is larger than the original.
 */
uniform ivec2 border_pixels = ivec2(0, 0); // Value usually set through script
#endif

#ifdef MASK_EFFECT
group_uniforms Mask_Effect;
/**
 * Use the mask color directly on the texture.
 */
uniform bool use_mask_color = false; // Value usually set through script
/**
 * Use the mask texture to mask out parts of the texture.
 */
uniform bool use_mask_texture = false; // Value usually set through script
/**
 * Color used for masking either directly or through the mask texture.
 */
uniform vec3 mask_color : source_color = vec3(1.0, 1.0, 1.0); // Value usually set through script
/**
 * Texture used for masking out parts of the texture.
 */
uniform sampler2D mask_texture : hint_default_black; // Value usually set through script
#endif

#include "iterative_fire.gdshaderinc"
