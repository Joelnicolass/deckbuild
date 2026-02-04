shader_type canvas_item;

//VARIATIONOPTIONS_START: EXTEND_FRAME,MASK_EFFECT

/**
 * Noise texture used as a source of pseudo-random values for computing palette jump thresholds. Should be a tiled noise texture.
 */
uniform sampler2D noise_texture : repeat_enable, filter_linear;
/**
 * Scales the coordinate space used when sampling the noise texture. Values < 1 zoom in on the noise, values > 1 tile the noise more densely. Typical range is 0.1 - 10.0.
 */
uniform float noise_scale : hint_range(0.01, 10.0) = 1.0;
/**
 * Texture containing the color palette.
 */
uniform sampler2D input_palette_texture : filter_nearest;
/**
 * Whether to shift each pixel's color along the palette during the dissolve.
 * Enable to remap colors over time; disable to only mask pixels without recoloring.
 */
uniform bool palette_shift = true;
/**
 * Reverses the palette shift direction.
 * When true, colors move toward lower palette indices; otherwise toward higher indices.
 */
uniform bool inverse_palette_shift = false;
/**
 * Level of pixelization for the dissolve effect. Higher values make the dissolve pixels larger.
 */
uniform int pixelization : hint_range(0, 6) = 0;
/**
 * Normalized dissolve progress for manual control from scripts (0.0–1.0).
 * Use when not relying on the built-in TIME progression.
 */
uniform float time : hint_range(0.0, 1.1) = 1.1; // DYNAMIC SETTING
/**
 * Thickness of the tinted dissolve edge band (0.0–1.0).
 * Higher values produce a wider rim around the dissolving area.
 */
uniform float dissolve_border_size : hint_range(0.0, 1.0) = 0.1;
/**
 * Enables color tinting along the dissolve edge.
 * When true, blends between dissolve_color_from and dissolve_color_to over progress.
 */
uniform bool use_dissolve_color = false;
/**
 * Starting tint color for the dissolve gradient.
 * Interpolates toward dissolve_color_to as progress increases.
 */
uniform vec4 dissolve_color_from : source_color = vec4(0.0, 0.0, 0.0, 0.0);
/**
 * Ending tint color for the dissolve gradient.
 * Reached when dissolve progress is 1.0.
 */
uniform vec4 dissolve_color_to : source_color = vec4(0.0, 0.0, 0.0, 0.0);
/**
 * Overall intensity multiplier for the dissolve tint (0.0–5.0).
 * Higher values produce a stronger color influence.
 */
uniform float dissolve_color_strength : hint_range(0.0, 5.0) = 0.5;
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
/**
 * Remove pixels that are masked out.
 */
uniform bool remove_masked_pixels = true;
#endif

#include "dissolve.gdshaderinc"
