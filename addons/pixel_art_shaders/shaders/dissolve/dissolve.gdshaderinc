#include "../pixelart_utils_updated.gdshaderinc"

varying flat int actual_palette_size;
varying flat float fragmentation_scale;
varying flat vec3 palette_colors[MAX_VERTEX_PALETTE_SIZE];

float get_noise_value(vec2 l_uv, vec2 l_texture_size, float l_pixelization, sampler2D l_noise_texture, float l_noise_scale) {
	vec2 texel_uv = (floor(l_uv * l_texture_size * l_pixelization) / l_texture_size) / l_pixelization;
	vec2 noise_uv = texel_uv * l_noise_scale;
	ivec2 noise_texture_size = textureSize(l_noise_texture, 0);
	ivec2 noise_coords = ivec2(noise_uv * vec2(noise_texture_size)) % noise_texture_size;
	float raw_noise_value = texelFetch(l_noise_texture, noise_coords, 0).r;
	return raw_noise_value;
}

void vertex() {
	actual_palette_size = get_palette_size(input_palette_texture);
	fragmentation_scale = pow(2.0, float(-pixelization));
	if (actual_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		for (int i = 0; i < actual_palette_size; i++) {
			palette_colors[i] = texelFetch(input_palette_texture, ivec2(i, 0), 0).rgb;
		}
	}
}

void fragment() {
	COLOR = preprocess_ext_input(TEXTURE, ivec2(UV / TEXTURE_PIXEL_SIZE));
#ifdef MASK_EFFECT
	float pre_masking_alpha = COLOR.a;
#endif
	COLOR = preprocess_mask_input(COLOR, ivec2(UV / TEXTURE_PIXEL_SIZE));
#ifdef MASK_EFFECT
	bool unaffected = false;
	if (COLOR.a <= 0.0) {
		if (pre_masking_alpha <= 0.0 || remove_masked_pixels) {
			discard;
		}
		unaffected = true;
		COLOR.a = pre_masking_alpha;
	}
	if (!unaffected) {
#else
	if (COLOR.a <= 0.0) discard;
#endif
	vec3 cached_palette[MAX_PALETTE_SIZE];
	if (actual_palette_size > MAX_VERTEX_PALETTE_SIZE) {
		cache_palette(input_palette_texture, actual_palette_size, cached_palette);
	} else {
		cache_palette_vertex(actual_palette_size, cached_palette, palette_colors);
	}

	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float raw_progress = mod(TIME, 1.0);
	if (time <= 1.0 && time != -1.0) raw_progress = time;
	float progress = smoothstep(0.0, 1.0, raw_progress);
	progress *= 1.0 + dissolve_border_size;
	progress -= dissolve_border_size;


	float noise_value = get_noise_value(UV, texture_size, fragmentation_scale, noise_texture, noise_scale);
	if (noise_value <= progress) discard;
	if (noise_value - dissolve_border_size <= progress) {
		vec3 new_color = COLOR.rgb;
		if (palette_shift) {
			vec4 result = find_palette_id(COLOR, cached_palette, actual_palette_size);
			float palette_id = result.a;
			float new_palette_id = 0.0;
			if (inverse_palette_shift) {
				new_palette_id = palette_id - palette_id * raw_progress;
			} else {
				new_palette_id = palette_id + (float(actual_palette_size) - palette_id) * raw_progress;
			}
			new_palette_id = clamp(new_palette_id, 0.0, float(actual_palette_size));
			new_color = cached_palette[int(new_palette_id)];
		}
		if (use_dissolve_color) {
			new_color += mix(dissolve_color_from.rgb, dissolve_color_to.rgb, raw_progress) * dissolve_color_strength * raw_progress;
			float max_color = max(max(new_color.r, new_color.g), new_color.b);
			if (max_color > 1.0) {
				new_color -= max_color - 1.0;
			}
		}
		COLOR = vec4(new_color, COLOR.a);
	}
#ifdef MASK_EFFECT
	}
#endif
}
