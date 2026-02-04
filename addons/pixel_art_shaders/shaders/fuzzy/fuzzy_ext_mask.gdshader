#define EXTEND_FRAME
#define MASK_EFFECT
shader_type canvas_item;

//VARIATIONOPTIONS_START: EXTEND_FRAME,MASK_EFFECT

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
/**
 * Threshold for considering palette differences between neighboring pixels. Larger values make the effect occur between colors further apart in the palette.
 */
uniform int palette_diff_threshold : hint_range(0, 16) = 0;
/**
 * Percentage of how many pixels should be affected by the fuzziness effect.
 */
uniform float fuzziness : hint_range(0.0, 1.0) = 0.5;
/**
 * Level of fragmentation for the fuzziness effect. Negative values make the fuzziness effect more coherent across multiple pixels, positive values fragment the fuzziness effect to sub-pixel sizes.
 */
uniform int fragmentation_level : hint_range(-6, 6) = 0;
/**
 * The displaced pixels are more random.
 */
uniform bool random_fuzz = false;

/**
 * Whether the fuzziness effect changes over time.
 */
uniform bool time_shift = false;
/**
 * Time value for animating the fuzziness effect. If negative, uses TIME.
 */
uniform float time = -1.0; // DYNAMIC SETTING
/**
 * Speed of the time-based shift for the fuzziness effect.
 */
uniform float time_speed : hint_range(0.1, 100.0) = 8.0;
/**
 * Ignore the input palette and use the original colors.
 */
uniform bool ignore_palette = false;

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
#else
#define NO_ORIGINAL_TEXTURE
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

#include "fuzzy.gdshaderinc"
