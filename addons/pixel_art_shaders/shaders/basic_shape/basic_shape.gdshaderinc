#include "../pixelart_utils_updated.gdshaderinc"

varying flat int actual_palette_size;
varying flat vec3 palette_colors[MAX_VERTEX_PALETTE_SIZE];

bool is_in_shape(vec2 frag_uv, vec2 center_px, ivec2 main_texture_size, float radius_pixels, int mode) {
	vec2 frag_px = frag_uv * vec2(main_texture_size);
	vec2 d = abs(frag_px - center_px);
	if (mode == 0) {
		return length(frag_px - center_px) <= radius_pixels * 1.12;
	} else if (mode == 1) {
		return (d.x + d.y) <= radius_pixels * 1.5;
	} else if (mode == 2) {
		float a = radius_pixels;
		float b = radius_pixels * 1.5;
		return (d.x <= a) && ((d.x + d.y) <= b);
	} else if (mode == 3) {
		float a = radius_pixels;
		float b = radius_pixels * 1.5;
		return (d.y <= a) && ((d.x + d.y) <= b);
	} else if (mode == 4) {
		float a = radius_pixels;
		float b = radius_pixels * 1.5;
		return (d.x <= a) && (d.y <= a) && ((d.x + d.y) <= b);
	} else if (mode == 5) {
		float a = radius_pixels;
		return (d.x <= a) && (d.y <= a);
	} else if (mode == 5) {
		float a = radius_pixels;
		return (d.x <= a) && (d.y <= a);
	} else {
		return false;
	}
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
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 offset = 1.0 / texture_size;

	vec3 cached_palette[MAX_PALETTE_SIZE];
	if (actual_palette_size > MAX_VERTEX_PALETTE_SIZE) {
		cache_palette(input_palette_texture, actual_palette_size, cached_palette);
	} else {
		cache_palette_vertex(actual_palette_size, cached_palette, palette_colors);
	}

	ivec2 main_texture_size = textureSize(TEXTURE, 0);
	ivec2 center_idx = ivec2(floor(UV * vec2(main_texture_size)));
	vec2 uv_base = UV;
	bool x_offset_applied = false;
	bool y_offset_applied = false;
	if (mod(float(center_idx.x), 2.0) == 0.0 && !disable) {
		uv_base.y += offset_y / vec2(main_texture_size).y;
		y_offset_applied = true;
	}
	if (mod(float(center_idx.y), 2.0) == 0.0 && !disable) {
		uv_base.x += offset_x / vec2(main_texture_size).x;
		x_offset_applied = true;
	}
	center_idx = ivec2(floor(uv_base * vec2(main_texture_size)));

	vec2 offset_pixels = offset;

	vec4 pixel_orig[9];
	vec4 pixel[9];
	int pixel_id[9];

	sample_3x3_grid_raw(TEXTURE, vec2(main_texture_size), uv_base, offset_pixels, pixel_orig);
	bool has_nontransparent_neighbor = false;
	for(int i = 0; i < 9; i++) {
		if (pixel_orig[i].a > 0.1) {
			has_nontransparent_neighbor = true;
		}
	}
	if (!has_nontransparent_neighbor) {
		discard;
	}
	find_9pixels_to_palette(pixel_orig, cached_palette, actual_palette_size, pixel, pixel_id);

	if (!disable) {
		bool found = false;
		int best_id = 0;
		vec3 best_color = vec3(0.0);
		float best_a = 0.0;
		for (int oy = -1; oy <= 1; oy++) {
			for (int ox = -1; ox <= 1; ox++) {
				ivec2 n_idx = center_idx + ivec2(ox, oy);
				vec2 n_center_px = vec2(n_idx) + vec2(0.5);
				if(x_offset_applied || y_offset_applied || true) {
					if (x_offset_applied) {
						if (mod(float(n_idx.y), 2.0) == 1.0) {
							n_center_px.x += offset_x;
						}
					} else {
						if (mod(float(n_idx.y), 2.0) == 0.0) {
							n_center_px.x -= offset_x;
						}
					}
					if (y_offset_applied) {
						if (mod(float(n_idx.x), 2.0) == 1.0) {
							n_center_px.y += offset_y;
						}
					} else {
						if (mod(float(n_idx.x), 2.0) == 0.0) {
							n_center_px.y -= offset_y;
						}
					}
				}

				if (is_in_shape(uv_base, n_center_px, main_texture_size, shape_size, pixel_shape)) {
					vec4 n_orig = pixel_orig[(oy + 1) * 3 + (ox + 1)];
					if (n_orig.a >= 0.1) {
						int nid = pixel_id[(oy + 1) * 3 + (ox + 1)];
						if ((!found || (prefer_higher_palette_ids ? (nid > best_id) : (nid < best_id))) && nid != -1) {
							found = true;
							best_id = nid;
							best_color = cached_palette[nid];
							best_a = n_orig.a;
						}
					}
				}
			}
		}
		if (found) {
			COLOR = vec4(best_color, best_a);
		} else {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	} else {
		COLOR = pixel[4];
	}
}
