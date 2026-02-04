shader_type canvas_item;

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
uniform sampler2D effect_palette_texture : filter_nearest;

#define BASIC_UTILS
#include "pixelart_utils_updated.gdshaderinc"

varying flat int actual_palette_size;
const int palette_jump_threshold = 4;

find_majority_palette_id(25)

void vertex() {
	actual_palette_size = get_palette_size(effect_palette_texture);
}

void fragment() {
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 offset = 1.0 / texture_size;

	vec3 cached_palette[MAX_PALETTE_SIZE];
	cache_palette(effect_palette_texture, actual_palette_size, cached_palette);

	ivec2 main_texture_size = textureSize(TEXTURE, 0);
	vec2 center_coords = UV * vec2(main_texture_size);
	vec2 offset_pixels = offset * vec2(main_texture_size);

	vec4 center_original = texelFetch(TEXTURE, ivec2(center_coords), 0);
	vec4 center_result = find_closest_palette_color_and_id(center_original.rgb, cached_palette, actual_palette_size);
	vec3 center_color = center_result.rgb;
	int center_id = int(center_result.a);
	vec4 center = vec4(center_color, center_original.a);
	if (center_original.a < 0.1) {
		discard;
	}

	vec4 pixel_orig[25];
	vec4 pixel[25];
	int pixel_id[25];
	sample_5x5_grid(TEXTURE, center_coords, offset_pixels, pixel_orig);
	pixel_orig[12] = center_original;

	convert_pixels_to_palette(pixel_orig, cached_palette, actual_palette_size, pixel, pixel_id);

	MajorityPaletteResult majority_result = find_majority_palette_id_25(pixel_id, pixel_orig, actual_palette_size);
	int majority_palette_id = majority_result.palette_id;
	int count = majority_result.count;

	int palette_offset = 0;
	int center_palette_id = pixel_id[12];
	bool border_pixel = false;
	int neighbor_indices[8] = int[8](6, 7, 8, 11, 13, 16, 17, 18);
	for (int i = 0; i < 8; i++) {
		if (pixel[neighbor_indices[i]].a < 0.1) {
			border_pixel = true;
			continue;
		}
		int neighbor_palette_id = pixel_id[neighbor_indices[i]];
		int id_diff = neighbor_palette_id - pixel_id[12];
		if (abs(id_diff) < 4) {
			palette_offset += id_diff;
		}
	}

	if (!disable && !(border_pixel && keep_border_colors)) {
		int higher_palette_count = 0;
		int lower_palette_count = 0;
		for (int i = 0; i < 25; i++) {
			if (pixel_id[i] > pixel_id[12]) {
				higher_palette_count++;
			} else if (pixel_id[i] < pixel_id[12]) {
				lower_palette_count++;
			}
		}

		if (majority_palette_id == pixel_id[12] && count > 3 && !(higher_palette_count > 0 && lower_palette_count > 0)) {
			if (palette_offset > palette_jump_threshold) {
				int new_palette_id = min(pixel_id[12] + 1, actual_palette_size - 1);
				vec3 new_color = cached_palette[new_palette_id];
				COLOR = vec4(new_color, center.a);
			} else if (palette_offset < -palette_jump_threshold) {
				int new_palette_id = max(pixel_id[12] - 1, 0);
				vec3 new_color = cached_palette[new_palette_id];
				COLOR = vec4(new_color, center.a);
			} else {
				COLOR = center;
			}
		} else {
			int diagonal_count = 0;
			if (pixel_id[6] == pixel_id[12] || pixel[6].a == 0.0) { diagonal_count++; }
			if (pixel_id[8] == pixel_id[12] || pixel[8].a == 0.0) { diagonal_count++; }
			if (pixel_id[16] == pixel_id[12] || pixel[16].a == 0.0) { diagonal_count++; }
			if (pixel_id[18] == pixel_id[12] || pixel[18].a == 0.0) { diagonal_count++; }
			int direct_count = 0;
			if (pixel_id[7] == pixel_id[12] || pixel[7].a == 0.0) { direct_count++; }
			if (pixel_id[17] == pixel_id[12] || pixel[17].a == 0.0) { direct_count++; }
			if (pixel_id[11] == pixel_id[12] || pixel[11].a == 0.0) { direct_count++; }
			if (pixel_id[13] == pixel_id[12] || pixel[13].a == 0.0) { direct_count++; }
			float neighbor_count = float(diagonal_count) * 0.5 + float(direct_count);

			if (neighbor_count >= 1.0 || abs(palette_offset) <= 4) {
				COLOR = center;
			} else {
				COLOR = vec4(cached_palette[majority_palette_id], center.a);
			}
		}
	} else {
		COLOR = center;
	}
}
