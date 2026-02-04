#include "../pixelart_utils_updated.gdshaderinc"

varying flat int input_palette_size;
varying flat int effect_palette_size;
varying flat vec3 palette_colors[MAX_VERTEX_PALETTE_SIZE];

void vertex() {
	input_palette_size = get_palette_size(input_palette_texture);
	effect_palette_size = get_palette_size(effect_palette_texture);
	
	if (input_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		for (int i = 0; i < input_palette_size; i++) {
			palette_colors[i] = texelFetch(input_palette_texture, ivec2(i, 0), 0).rgb;
		}
	}
}

void fragment() {
	vec4 final_color = preprocess_input(TEXTURE, ivec2(UV / TEXTURE_PIXEL_SIZE));

	if (!show_original) {
		final_color.a = 0.0;
	}

	vec3 cached_palette[MAX_PALETTE_SIZE];
	bool palette_loaded = false;

	bool is_blocking_pixel = final_color.a > 0.0 && show_original;

	if (is_blocking_pixel && effect_over_non_palette_colors) {
		if (input_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
			cache_palette_vertex(input_palette_size, cached_palette, palette_colors);
		} else {
			cache_palette(input_palette_texture, input_palette_size, cached_palette);
		}
		palette_loaded = true;
		if (find_palette_id(final_color, cached_palette, input_palette_size).a < -0.1) {
			is_blocking_pixel = false;
		}
	}

	if (!is_blocking_pixel) {
		float rotation_angle;
		if (time <= 1.0 && time != -1.0) {
			rotation_angle = time * TAU;
		} else {
			rotation_angle = TIME * rotation_speed;
		}
		vec2 center = vec2(0.5, 0.5);
		int effective_range = (palette_range > 0) ? min(palette_range + palette_offset, effect_palette_size) - palette_offset : effect_palette_size - palette_offset;
		int active_effective_range = (active_palette_range > 0) ? min(active_palette_range + active_palette_offset, input_palette_size) - active_palette_offset : input_palette_size - active_palette_offset;

		for (int i = 0; i < effective_range; i++) {
			float angle = -( TAU / float(effective_range)) * float(i) + rotation_angle;
			angle += uv_x_angle_distortion * UV.x * TAU;
			angle += uv_y_angle_distortion * UV.y * TAU;

			float scale_factor = 1.0;
			if (effective_range > 1) scale_factor = (1.0 - radius_variation) + (radius_variation * (float(i) / float(effective_range - 1)));
			float current_radius = rotation_radius * scale_factor;
			vec2 rotation_offset = vec2(cos(angle), sin(angle)) * current_radius;
			if (pixel_perfect) {
				rotation_offset = floor(rotation_offset + 0.5);
			}
			vec2 offset_uv = (UV / TEXTURE_PIXEL_SIZE) + rotation_offset;

			vec4 afterimage = preprocess_input(TEXTURE, ivec2(int(offset_uv.x), int(offset_uv.y)));

			if (afterimage.a > 0.0) {
				bool valid_palette_color = true;
				if (only_active_colors) {
					if (!palette_loaded) {
						if (input_palette_size + effect_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
							cache_palette_vertex(input_palette_size, cached_palette, palette_colors);
						} else {
							cache_palette(input_palette_texture, input_palette_size, cached_palette);
						}
						palette_loaded = true;
					}
					vec4 palette_color = find_palette_id(afterimage, cached_palette, MAX_PALETTE_SIZE);

					if (inverse_palette) {
						if (int(palette_color.a) >= input_palette_size - active_palette_offset) valid_palette_color = false;
						if (int(palette_color.a) < input_palette_size - (active_palette_offset + active_effective_range)) valid_palette_color = false;
					} else {
						if (int(palette_color.a) < active_palette_offset) valid_palette_color = false;
						if (int(palette_color.a) >= active_palette_offset + active_effective_range) valid_palette_color = false;
					}
				}
				if (valid_palette_color || !only_active_colors) {
					int base_index = inverse_palette ? (effect_palette_size - palette_offset - i - 1) : i + palette_offset;
					int palette_index = clamp(base_index, 0, effect_palette_size - 1);

					afterimage.rgb = texelFetch(effect_palette_texture, ivec2(palette_index, 0), 0).rgb;

					if (blend_afterimages) {
						final_color = vec4(final_color.rgb * final_color.a + afterimage.rgb * afterimage.a, min(final_color.a + afterimage.a, 1.0));
					} else {
						final_color = afterimage;
						break;
					}
				}
			}
		}
	}

	COLOR = final_color;
}
