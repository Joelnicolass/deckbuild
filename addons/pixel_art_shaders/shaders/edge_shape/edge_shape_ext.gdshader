#define EXTEND_FRAME
shader_type canvas_item;

//VARIATIONOPTIONS_START: EXTEND_FRAME,MASK_EFFECT

/**
 * Disable the shader effect.
 */
uniform bool disable = false;
/**
 * Texture containing the color palette.
 */
uniform sampler2D input_palette_texture : filter_nearest;
/**
 * Size of the shape representing a pixel.
 */
uniform float shape_size : hint_range(0.0, 1.0) = 1.0;
/**
 * Prefer higher palette IDs when pixel shapes overlap.
 */
uniform bool prefer_higher_palette_ids = false;

group_uniforms Edge_Settings;
/**
 * Shape used for non edge pixels.
 * [b]0[/b] for [b]Circle[/b][br][b]1[/b] for [b]Diamond[/b][br][b]2[/b] for [b]Vertical Hexagon[/b][br][b]3[/b] for [b]Horizontal Hexagon[/b][br][b]4[/b] for [b]Octagon[/b][br][b]5[/b] for [b]Square[/b][br][b]6[/b] for [b]Empty[/b]
 */
uniform int filling_shape : hint_enum("Circle", "Diamond", "Vertical Hexagon", "Horizontal Hexagon", "Octagon", "Square", "Empty") = 1;
/**
 * Shape used for non edge pixels.
 * [b]-1[/b] for [b]Automatic[/b] setting shape based on edge orientation[br][b]0[/b] for [b]Circle[/b][br][b]1[/b] for [b]Diamond[/b][br][b]2[/b] for [b]Vertical Hexagon[/b][br][b]3[/b] for [b]Horizontal Hexagon[/b][br][b]4[/b] for [b]Octagon[/b][br][b]5[/b] for [b]Square[/b][br][b]6[/b] for [b]Empty[/b]
 */
uniform int edge_shape : hint_enum("Automatic", "Circle", "Diamond", "Vertical Hexagon", "Horizontal Hexagon", "Octagon", "Square", "Empty") = 0;
/**
 * Corniness level influencing which corner pixels are considered as edges, higher values result in more corners being treated as edges.
 */
uniform int corniness : hint_range(0, 8) = 8;

group_uniforms Offset_Settings;
/**
 * X Offset for every other column in pixels
 */
uniform float offset_x : hint_range(-1.0, 1.0) = 0.0;
/**
 * Y Offset for every other row in pixels
 */
uniform float offset_y : hint_range(-1.0, 1.0) = 0.0;
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

#include "edge_shape.gdshaderinc"
