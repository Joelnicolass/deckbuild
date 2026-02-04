#include "../pixelart_utils_updated.gdshaderinc"

varying flat int actual_palette_size;
varying flat vec3 palette_colors[MAX_VERTEX_PALETTE_SIZE];

#ifdef USE_PREPROCESS
#include "../adding_includes/static_preprocess.gdshaderinc"
#endif

const int neighbor_indices[16] = int[16](1, 2, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 22, 23);

find_majority_palette_id(25)

float compute_noise_threshold(vec2 l_uv, vec2 l_texture_size, float l_random_fragmentation, bool l_time_shift, float l_time_speed, sampler2D l_noise_texture, float l_noise_scale, float l_time) {
	vec2 texel_uv = (floor(l_uv * l_texture_size * l_random_fragmentation) / l_texture_size) / l_random_fragmentation;
	vec2 noise_uv = texel_uv * l_noise_scale;
	if (l_time_shift) {
		noise_uv += vec2(l_time * l_time_speed * 0.001, l_time * l_time_speed * 0.01);
	}

	ivec2 noise_texture_size = textureSize(l_noise_texture, 0);
	ivec2 noise_coords = ivec2(noise_uv * vec2(noise_texture_size)) % noise_texture_size;
	float raw_noise_value = texelFetch(l_noise_texture, noise_coords, 0).r;

	float noise_value = raw_noise_value * raw_noise_value;
	if (noise_value > 0.0) {
		float log_val = log2(noise_value);
		float rounded_log = ceil(log_val);
		noise_value = pow(2.0, rounded_log);
		noise_value = min(noise_value, 1.0);
	}

	return pow(1.0 - raw_noise_value, 1.0) * (palette_max_jump- palette_min_jump) + palette_min_jump;
}

float compute_cursor_threshold(vec2 l_uv, vec2 l_cursor_position, float l_cursor_radius_pixels, float l_cursor_border_radius_pixels, vec2 l_texture_size, bool l_inverse) {
	vec2 texel_uv = floor(l_uv * l_texture_size) / l_texture_size;

	vec2 delta_uv = texel_uv - floor(l_cursor_position * l_texture_size) / l_texture_size;
	vec2 delta_pixels = delta_uv * l_texture_size;
	float distance_pixels = length(delta_pixels);

	float inner_threshold, outer_threshold, threshold_value;

	if (l_inverse) {
		inner_threshold = palette_max_jump;
		outer_threshold = palette_min_jump;
	} else {
		inner_threshold = palette_min_jump;
		outer_threshold = palette_max_jump;
	}

	if (distance_pixels <= l_cursor_radius_pixels) {
		return inner_threshold;
	}

	if (distance_pixels >= l_cursor_border_radius_pixels) {
		return outer_threshold;
	}

	float normalized_distance = (distance_pixels - l_cursor_radius_pixels) / (l_cursor_border_radius_pixels - l_cursor_radius_pixels);

	if (l_inverse) {
		normalized_distance = 1.0 - normalized_distance;
	}
	threshold_value = normalized_distance * (palette_max_jump - palette_min_jump - 1.0) + 1.0;
	return threshold_value;
}

void vertex() {
	actual_palette_size = get_palette_size(input_palette_texture);
	if (actual_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		for (int i = 0; i < actual_palette_size; i++) {
			palette_colors[i] = texelFetch(input_palette_texture, ivec2(i, 0), 0).rgb;
		}
	}
}

void fragment() {
	bool disable_override = disable;
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 offset = offset_scale / texture_size;

	vec3 cached_palette[MAX_PALETTE_SIZE];
	if (actual_palette_size > MAX_VERTEX_PALETTE_SIZE) {
		cache_palette(input_palette_texture, actual_palette_size, cached_palette);
	} else {
		cache_palette_vertex(actual_palette_size, cached_palette, palette_colors);
	}

	ivec2 main_texture_size = textureSize(TEXTURE, 0);
	vec2 center_coords = UV * vec2(main_texture_size);
	vec2 offset_pixels = offset * vec2(main_texture_size);
	int transparent_count = 0;
	NeighborAnalysis neighbor_analysis;
	MajorityPaletteResult majority_result;
	int majority_palette_id = -1;
	float palette_jump_threshold = palette_min_jump;
	vec4 center_pixel_orig;
	int center_pixel_id;

	float test_value = 0.0;

	#ifndef USE_PREPROCESS
		vec4 pixel_orig[25];
		vec4 pixel[25];
		int pixel_id[25];
		sample_5x5_grid(TEXTURE, center_coords, offset_pixels, pixel_orig);
		find_pixels_to_palette(pixel_orig, cached_palette, actual_palette_size, pixel, pixel_id);
		for (int i = 0; i < 25; i++) {
			if (pixel_orig[i].a < 0.1) { transparent_count++; }
		}
		if (transparent_count >= 25) {
			discard;
		}
		center_pixel_orig = pixel_orig[12];
		center_pixel_id = pixel_id[12];
		majority_result = find_majority_palette_id_25(pixel_id, pixel_orig, actual_palette_size);

		if (pixel_orig[12].a < 0.1 || pixel_id[12] == -1) {
			pixel_id[12] = -1;
			center_pixel_id = -1;
			pixel[12] = vec4(cached_palette[majority_result.palette_id], 1.0);
			if (keep_border_colors) {
				disable_override = true;
			}
		}
		if (!disable_override) {
			neighbor_analysis = analyze_neighbors_8(pixel_id, pixel_orig, pixel_id[12], palette_diff_threshold);
			if (center_pixel_id == -1 && neighbor_analysis.transparent_neighbors == 8) {
				disable_override = true;
			}
		}
	#else
		main_texture_size = textureSize(TEXTURE, 0);
		ivec2 preprocess_texture_size = textureSize(preprocess_data_texture, 0);
		vec2 preprocess_scale = vec2(float(preprocess_texture_size.x) / float(main_texture_size.x), float(preprocess_texture_size.y) / float(main_texture_size.y));
		vec4 encoded_pixel = texelFetch(preprocess_data_texture, ivec2((center_coords) * preprocess_scale), 0);
		PreprocessData preprocess_data = decode_data(encoded_pixel);

		transparent_count = preprocess_data.transparent_neighbors;
		ivec2 offset_majority = ivec2(0);
		test_value = float(preprocess_data.color_pos);
		int color_pos = preprocess_data.color_pos;
		if (color_pos >= 0 && color_pos < 16) {
			int neighbor_index = neighbor_indices[color_pos];
			offset_majority.y = (neighbor_index / 5) - 2;
			offset_majority.x = (neighbor_index - (neighbor_index / 5) * 5) - 2;
		}
		vec4 majority_color = preprocess_input(TEXTURE, ivec2(center_coords) + offset_majority);
		majority_result.palette_id = int(find_palette_id(majority_color, cached_palette, actual_palette_size).a);
		center_pixel_orig = preprocess_input(TEXTURE, ivec2(center_coords));
		if (preprocess_data.invalid_id) {
			center_pixel_id = -1;
		} else {
			center_pixel_id = int(find_palette_id(center_pixel_orig, cached_palette, actual_palette_size).a);
		}
		if (center_pixel_orig.a == 0.0 && keep_border_colors) center_pixel_id = -1;

		neighbor_analysis.transparent_neighbors = preprocess_data.transparent_neighbors;
		neighbor_analysis.border_pixel = preprocess_data.is_border_pixel;
		neighbor_analysis.min_diff = preprocess_data.minimum_palette_difference;
		if (abs(preprocess_data.palette_difference) > 0) {
			neighbor_analysis.palette_offset = float(preprocess_data.palette_difference) + sign(float(preprocess_data.palette_difference)) * float(preprocess_data.transparent_neighbors);
		} else {
			neighbor_analysis.palette_offset = 0.0;
		}
		if (transparent_count >= 8 && center_pixel_orig.a < 0.1 ) {
			discard;
		}
		if (center_pixel_id == -1 && neighbor_analysis.transparent_neighbors == 8) {
			disable_override = true;
		}
	#endif

	if (!disable_override) {
		#ifdef WOBBLE_ENABLED
			float use_time = time;
			if (time < 0.0) { use_time = TIME; }
			palette_jump_threshold = compute_noise_threshold(UV, texture_size, random_fragmentation, time_shift, time_speed, noise_texture, noise_scale, use_time);
		#elif defined(CURSOR_ENABLED)
			palette_jump_threshold = compute_cursor_threshold(UV, cursor_position, cursor_radius, cursor_border_radius, texture_size, cursor_inverse);
			if (palette_jump_threshold >= palette_max_jump) {
				disable_override = true;
			}
			palette_jump_threshold = floor(palette_jump_threshold);
		#endif
	}
	if (!disable_override && !(neighbor_analysis.border_pixel && keep_border_colors)) {
		if (center_pixel_id == -1) {
			if (8.0 - float(neighbor_analysis.transparent_neighbors) > palette_jump_threshold) {
				if (majority_result.palette_id != -1) {
					COLOR = vec4(cached_palette[majority_result.palette_id], 1.0);
				} else {
					COLOR = vec4(0.0, 0.0, 0.0, 1.0);
				}
			} else {
				COLOR = center_pixel_orig;
			}
		} else {
			if (treat_transparent_as_color && neighbor_analysis.border_pixel && neighbor_analysis.transparent_neighbors >= palette_diff_threshold) {
				COLOR = vec4(0.0, 0.0, 0.0, 0.0);
			} else {
				if (neighbor_analysis.palette_offset > palette_jump_threshold) {
					int new_palette_id = min(center_pixel_id + neighbor_analysis.min_diff, actual_palette_size - 1);
					vec3 new_color = cached_palette[new_palette_id];
					COLOR = vec4(new_color, neighbor_analysis.transparent_neighbors > int(palette_jump_threshold) && (center_pixel_orig.a <= 0.1) ? 0.0 : 1.0);
				} else if (neighbor_analysis.palette_offset < -palette_jump_threshold) {
					int new_palette_id = max(center_pixel_id - neighbor_analysis.min_diff, 0);
					vec3 new_color = cached_palette[new_palette_id];
					COLOR = vec4(new_color, neighbor_analysis.transparent_neighbors > int(palette_jump_threshold) && (center_pixel_orig.a <= 0.1) ? 0.0 : 1.0);
				} else {
					COLOR = center_pixel_orig;
				}
			}
		}
	} else {
		COLOR = center_pixel_orig;
	}
	if (!disable_override && ignore_palette) {
		if (center_pixel_orig.a > 0.0 && neighbor_analysis.transparent_neighbors > int(palette_jump_threshold)) {
			discard;
		} else if (center_pixel_orig.a == 0.0 && neighbor_analysis.transparent_neighbors < 8 - int(palette_jump_threshold)) {
			#ifndef USE_PREPROCESS
				for (int i = 0; i < 16; i++) {
					int neighbor_idx = neighbor_indices[i];
					if (pixel_orig[neighbor_idx].a >= 0.1) {
						COLOR = pixel_orig[neighbor_idx];
						break;
					}
				}
			#else
				COLOR = majority_color;
			#endif
		}
	}
}
