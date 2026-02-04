#include "../pixelart_utils_updated.gdshaderinc"

const int palette_jump_threshold = 3;

varying flat int actual_palette_size;
varying flat vec3 palette_colors[MAX_VERTEX_PALETTE_SIZE];

find_majority_palette_id(9)

void vertex() {
	actual_palette_size = get_palette_size(input_palette_texture);
	if (actual_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		for (int i = 0; i < actual_palette_size; i++) {
			palette_colors[i] = texelFetch(input_palette_texture, ivec2(i, 0), 0).rgb;
		}
	}
}

void fragment() {
	float use_time = time;
	if (time < 0.0) use_time = TIME;
	bool disable_override = disable;
	vec2 main_texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;

	vec3 cached_palette[MAX_PALETTE_SIZE];
	if (actual_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		cache_palette_vertex(actual_palette_size, cached_palette, palette_colors);
	} else {
		cache_palette(input_palette_texture, actual_palette_size, cached_palette);
	}

	vec2 offset = 1.0 / texture_size;
	float fragmentation_scale = pow(2.0, float(fragmentation_level));
	vec2 texel_uv = floor(UV * texture_size * fragmentation_scale) / texture_size * fragmentation_scale;
	float applied_time_speed = 0.0;
	if (time_shift) applied_time_speed = time_speed;
	vec2 shift_offset[8];
	if (random_fuzz) {
		for (int i = 0; i < 8; i++) {
			shift_offset[i] = vec2(
				random_shift(texel_uv, float(i), applied_time_speed, use_time),
				random_shift(texel_uv, float(i) + 8.0, applied_time_speed, use_time)
			);
		}
	} else {
		if (fragmentation_level > 0 && !random_fuzz) {
			offset /= fragmentation_scale;
		}
		for (int i = 0; i < 8; i++) {
			shift_offset[i] = vec2(0.0, 0.0);
		}
	}

	vec4 pixel_orig[9];
	vec4 pixel[9];
	int pixel_id[9];

	sample_3x3_grid(TEXTURE, main_texture_size, UV, offset, shift_offset, pixel_orig);
	find_9pixels_to_palette(pixel_orig, cached_palette, actual_palette_size, pixel, pixel_id);	

	MajorityPaletteResult majority_result = find_majority_palette_id_9(pixel_id, pixel_orig, actual_palette_size);
	int majority_palette_id = majority_result.palette_id;

	if (pixel_orig[4].a < 0.1 || pixel_id[4] == -1) {
		pixel_id[4] = -1;
		pixel[4] = vec4(0.0, 0.0, 0.0, 0.0);
		if (keep_border_colors) {
			disable_override = true;
		}
	}

	bool border_pixel = false;
	float palette_offset = 0.0;
	float transparent_offset = 0.0;
	int neighbor_indices[8] = int[8](0, 1, 2, 3, 5, 6, 7, 8);
	if (!disable_override) {
		for (int i = 0; i < 8; i++) {
			int neighbor_idx = neighbor_indices[i];
			if (pixel[neighbor_idx].a < 0.1 && pixel_id[4] != -1) {
				transparent_offset += 1.0;
				border_pixel = true;
				continue;
			} else {
				if(pixel_id[4] == -1) {
					if (pixel[neighbor_idx].a >= 0.1) {
						transparent_offset += 1.0;
					}
					continue;
				}
			}
			int id_diff = pixel_id[neighbor_idx] - pixel_id[4];
			if (abs(id_diff) <= palette_diff_threshold || palette_diff_threshold == 0) {
				palette_offset += float(sign(id_diff));
			}
		}
		if (transparent_offset > 0.0) {
			palette_offset += sign(palette_offset) * transparent_offset;
		}

		if (time_shift) {
			disable_override = disable_override || (random(texel_uv + vec2(1.234, 5.678), time_speed, use_time) >= fuzziness);
		} else {
			disable_override = disable_override || (random(texel_uv + vec2(1.234, 5.678), 0.0, use_time) >= fuzziness);
		}

		if (!ignore_palette && pixel_id[4] == -1 && transparent_offset == 8.0) {
			disable_override = true;
		}
	}

	if (!disable_override && !(border_pixel && keep_border_colors) && !ignore_palette) {
		float diagonal_differences = 0.0;
		for (int i = 0; i < 4; i++) {
			int idx1 = neighbor_indices[i];
			int idx2 = neighbor_indices[7 - i];
			if (pixel[idx1].a >= 0.1 && pixel[idx2].a >= 0.1) {
				int id_diff = pixel_id[idx1] - pixel_id[idx2];
				if ((abs(id_diff) <= palette_diff_threshold || palette_diff_threshold == 0) && id_diff != 0) {
					diagonal_differences += 1.0;
				}
			}
		}
		if (pixel_id[4] == -1) {
			if (transparent_offset > float(palette_jump_threshold)) {
				COLOR = vec4(cached_palette[majority_palette_id], 1.0);
			} else {
				COLOR = pixel_orig[4];
			}
		} else {
			if (palette_offset > float(palette_jump_threshold) && diagonal_differences > 2.0) {
				int new_palette_id = min(pixel_id[4] + 1, actual_palette_size - 1);
				vec3 new_color = cached_palette[new_palette_id];
				COLOR = vec4(new_color, pixel_orig[4].a);
			} else if (palette_offset < -float(palette_jump_threshold) && diagonal_differences > 2.0) {
				int new_palette_id = max(pixel_id[4] - 1, 0);
				vec3 new_color = cached_palette[new_palette_id];
				COLOR = vec4(new_color, pixel_orig[4].a);
			} else {
				COLOR = pixel_orig[4];
			}
		}
	} else {
		COLOR = pixel_orig[4];
	}
	if (!disable_override && ignore_palette) {
		if (pixel_orig[4].a > 0.0 && transparent_offset > float(palette_jump_threshold)) {
			discard;
		} else if (pixel_orig[4].a == 0.0 && transparent_offset < 8.0 - float(palette_jump_threshold)) {
			for (int i = 0; i < 8; i++) {
				int neighbor_idx = neighbor_indices[i];
				if (pixel[neighbor_idx].a >= 0.1) {
					COLOR = pixel_orig[neighbor_idx];
					break;
				}
			}
		}
	}
}
