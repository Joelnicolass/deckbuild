#define MASK_EFFECT
shader_type canvas_item;

//VARIATIONOPTIONS_START: USE_PREPROCESS,EXTEND_FRAME,MASK_EFFECT

/**
 * Disable the shader effect.
 */
uniform bool disable = false;
/**
 * Keep the original colors of border pixels (pixels adjacent to transparent pixels).
 */
uniform bool keep_border_colors = true;
/**
 * Texture containing the color palette.
 */
uniform sampler2D input_palette_texture : filter_nearest;

#ifdef USE_PREPROCESS
/**
 * Texture containing preprocessed neighbor data.
 */
uniform sampler2D preprocess_data_texture : hint_default_black, filter_nearest;
#endif

/**
 * Threshold for considering palette differences between neighboring pixels. Larger values make the effect occur between colors further apart in the palette. 0 disables the threshold, so the effect is applied to all neighboring pixels.
 */
uniform int palette_diff_threshold : hint_range(0, 16) = 1;
/**
 * Thickness scale for the outline effect. Modifies the distance at which neighboring pixels are considered. Values smaller than 1.0 make the outline smaller than the original pixel size, values larger than 1.0 make the outline thicker.
 */
uniform float offset_scale : hint_range(0.0, 2.0) = 1.0;
/**
 * Minimum palette jump for outline effect to occur.
 */
uniform float palette_min_jump = 1.0;
/**
 * Maximum palette jump for outline effect to occur.
 */
uniform float palette_max_jump = 4.0;
/**
 * Ignore the input palette and use the original colors.
 */
uniform bool ignore_palette = false;
/**
 * Treat transparent pixels as a color for outline calculations.
 */
uniform bool treat_transparent_as_color = false;

#ifdef WOBBLE_ENABLED
group_uniforms Wobble_Settings;
/**
 * Whether the noise sampling coordinates are offset over time to animate the wobble effect.
 */
uniform bool time_shift = true;
/**
 * Speed multiplier applied to TIME when time shifting the noise. Higher values make the wobble animate faster. Typical range is 0.1 - 100.0.
 */
uniform float time_speed : hint_range(0.1, 100.0) = 8.0;
/**
 * Time value for animating the wobble effect. If negative, uses TIME.
 */
uniform float time = -1.0;  // DYNAMIC SETTING
/**
 * Controls the granularity of the noise tiling used for threshold calculation. Values > 1 increase the pixelated fragmentation of the noise sampling; smaller values make the effect more coherent across multiple pixels.
 */
uniform float random_fragmentation : hint_range(0.01, 16.0) = 1.0;
/**
 * Noise texture used as a source of pseudo-random values for computing palette jump thresholds. Should be a tiled noise texture.
 */
uniform sampler2D noise_texture : repeat_enable, filter_linear;
/**
 * Scales the coordinate space used when sampling the noise texture. Values < 1 zoom in on the noise, values > 1 tile the noise more densely. Typical range is 0.1 - 10.0.
 */
uniform float noise_scale : hint_range(0.1, 10.0) = 1.0;
#endif

#ifdef CURSOR_ENABLED
group_uniforms Cursor_Settings;
/**
 * Cursor center position in normalized UV space (0.0 - 1.0). This represents the cursor location relative to the texture being processed (vec2(0.0,0.0) is top-left, vec2(1.0,1.0) is bottom-right).
 */
uniform vec2 cursor_position = vec2(0.5, 0.5); // DYNAMIC SETTING
/**
 * Inner radius in pixels. Within this radius (measured in texture pixels) the outline effect is applied.
 */
uniform float cursor_radius : hint_range(0.0, 500.0) = 50.0;
/**
 * Outer border radius in pixels that defines the falloff region. Between [b]cursor_radius[/b] and [b]cursor_border_radius[/b] the effect strength interpolates from full to no effect. Beyond this radius there is no effect.
 */
uniform float cursor_border_radius : hint_range(0.0, 500.0) = 150.0;
/**
 * When true, the cursor effect is inverted -> outside full effect, inside no effect. The inner region uses the outer threshold and the outer region uses the inner threshold.
 */
uniform bool cursor_inverse = false;
#endif

#ifdef EXTEND_FRAME
group_uniforms Extend_Frame;
/**
 * Use original texture instead of built-in TEXTURE.
 */
uniform bool use_input_texture = false; // Value usually set through script
/**
 * Optional input texture if built-in TEXTURE should not be used.
 */
uniform sampler2D original_texture : hint_default_black; // Value usually set through script
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

#include "outline_shared.gdshaderinc"
