#define MASK_EFFECT
shader_type canvas_item;

//VARIATIONOPTIONS_START: EXTEND_FRAME,MASK_EFFECT

/**
 * Texture containing the input color palette.
 */
uniform sampler2D input_palette_texture : filter_nearest;
/**
 * Optional alternate 1×N palette used for output colors.
 */
uniform sampler2D effect_palette_texture : filter_nearest;
/**
 * Inverts the palette color selection logic for the afterimage effect.
 */
uniform bool inverse_palette = false;
/**
 * Starting offset in the palette for afterimage colors.
 */
uniform int palette_offset = 0;
/**
 * Number of palette colors to use for the afterimage trail. 0 means all colors from offset to end.
 */
uniform int palette_range = 0;
/**
 * Starting index in the palette for the active color range filter.
 */
uniform int active_palette_offset = 0;
/**
 * Number of palette colors to include in the active range filter. 0 means all colors from offset to end.
 */
uniform int active_palette_range = 0;
/**
 * Only show afterimage for pixels matching colors in the active input palette range.
 */
uniform bool only_active_colors = false;
/**
 * Whether to show the original sprite in the afterimage trail.
 */
uniform bool show_original = true;
/**
 * Distance in pixels from the sprite center for the afterimage rotation.
 */
uniform float rotation_radius = 2.0;
/**
 * Variation in radius across the afterimage trail. 0 = uniform radius, 1 = full variation from 0 to rotation_radius.
 */
uniform float radius_variation: hint_range(0.0, 1.0) = 0.0;
/**
 * Speed multiplier for the afterimage rotation animation.
 */
uniform float rotation_speed = 1.0;
/**
 * Enables pixel-perfect rendering for the afterimage positions.
 */
uniform bool pixel_perfect = true;
/**
 * Normalized rotation progress (0.0–1.0). When set to a value <= 1.0, controls rotation position manually.
 * 0.0 = start position, 1.0 = completes one full rotation back to start. Values > 1.0 use TIME-based animation.
 */
uniform float time : hint_range(0.0, 1.1) = 1.1;  // DYNAMIC SETTING
/**
 * Blend afterimages together (additive) instead of layering them opaquely. Red Green Blue results in white.
 */
uniform bool blend_afterimages = true;
/**
 * The afterimages that are rotating around the center have the current angle distorted based on the uv-coordinates by this amount. Resulting in a swirling effect.
 */
uniform float uv_x_angle_distortion = 0.0;
/**
 * The afterimages that are rotating around the center have the current angle distorted based on the uv-coordinates by this amount. Resulting in a swirling effect.
 */
uniform float uv_y_angle_distortion = 0.0;
/**
 * Put afterimages on top of non palette colors.
 */
uniform bool effect_over_non_palette_colors = false;

/**
 * Ignore the input palette and use the original colors.
 */
const bool ignore_palette = false;

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

#include "afterimage.gdshaderinc"
