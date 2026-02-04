#define EXTEND_FRAME
#define MASK_EFFECT
// PROCESSING SHADER
shader_type canvas_item;

//VARIATIONOPTIONS_START: EXTEND_FRAME,MASK_EFFECT

/**
 * Keep the original colors of border pixels (pixels adjacent to transparent pixels).
 */
uniform bool keep_border_colors = true;
/**
 * Texture containing the color palette.
 */
uniform sampler2D input_palette_texture : filter_nearest;
/**
 * Threshold for considering palette differences between neighboring pixels. Larger values make the effect occur between colors further apart in the palette. 0 disables the threshold, so the effect is applied to all neighboring pixels.
 */
uniform int palette_diff_threshold : hint_range(0, 16) = 0;
/**
 * Thickness scale for the outline effect. Modifies the distance at which neighboring pixels are considered. Values smaller than 1.0 make the outline smaller than the original pixel size, values larger than 1.0 make the outline thicker.
 */
uniform float offset_scale : hint_range(0.0, 2.0) = 1.0;
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

#include "neighbor_preprocess.gdshaderinc"
