shader_type canvas_item;

/**
 * Texture containing the color palette.
 */
uniform sampler2D effect_palette_texture : filter_nearest;
/**
 * Index of the palette color to use for the afterimage effect.
 */
uniform int palette_id;
/**
 * Inverts the active palette range selection logic.
 */
uniform bool inverse_palette = false;
/**
 * Enables pixel-perfect rendering for the afterimage.
 */
uniform bool pixel_perfect = true;
/**
 * Only show afterimage for pixels matching colors in the active palette range.
 */
uniform bool only_active_colors = false;
/**
 * Starting index in the palette for the active color range.
 */
uniform int active_palette_offset = 0;
/**
 * Number of palette colors to include in the active range. 0 means all colors from offset to end.
 */
uniform int active_palette_range = 0;

const bool ignore_palette = false;

#define BASIC_UTILS
#include "pixelart_utils_updated.gdshaderinc"

varying flat int actual_palette_size;

void vertex() {
	actual_palette_size = get_palette_size(effect_palette_texture);
}

void fragment() {
	vec3 cached_palette[MAX_PALETTE_SIZE];
	bool palette_loaded = false;

	int active_effective_range = (active_palette_range > 0) ? min(active_palette_range + active_palette_offset, actual_palette_size) - active_palette_offset : actual_palette_size - active_palette_offset;

	vec4 final_color = COLOR;

	if (COLOR.a != 0.0 && palette_id >= 0) {
		final_color.rgb = texelFetch(effect_palette_texture, ivec2(palette_id, 0), 0).rgb;

		bool valid_palette_color = true;
		if (only_active_colors) {
			vec4 afterimage = texture(TEXTURE, UV);
			if (!palette_loaded) {
				cache_palette(effect_palette_texture, actual_palette_size, cached_palette);
				palette_loaded = true;
			}
			vec4 palette_color = find_palette_id(afterimage, cached_palette, MAX_PALETTE_SIZE);

			if (inverse_palette) {
				if (int(palette_color.a) >= actual_palette_size - active_palette_offset) valid_palette_color = false;
				if (int(palette_color.a) < actual_palette_size - (active_palette_offset + active_effective_range)) valid_palette_color = false;
			} else {
				if (int(palette_color.a) < active_palette_offset) valid_palette_color = false;
				if (int(palette_color.a) >= active_palette_offset + active_effective_range) valid_palette_color = false;
			}
		}
		if (!valid_palette_color && only_active_colors) {
			final_color.a = 0.0;
		}
	}

	COLOR = final_color;
}
