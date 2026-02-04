#include "../pixelart_utils_updated.gdshaderinc"

varying flat int actual_palette_size;
varying flat vec3 palette_colors[MAX_VERTEX_PALETTE_SIZE];

bool is_in_shape(vec2 frag_uv, vec2 center_px, ivec2 main_texture_size, float radius_pixels, int mode) {
	vec2 frag_px = frag_uv * vec2(main_texture_size);
	vec2 d = abs(frag_px - center_px);
	if (mode == 1) {
		return length(frag_px - center_px) <= radius_pixels * 1.12;
	} else if (mode == 2) {
		return (d.x + d.y) <= radius_pixels * 1.5;
	} else if (mode == 3) {
		float a = radius_pixels;
		float b = radius_pixels * 1.5;
		return (d.x <= a) && ((d.x + d.y) <= b);
	} else if (mode == 4) {
		float a = radius_pixels;
		float b = radius_pixels * 1.5;
		return (d.y <= a) && ((d.x + d.y) <= b);
	} else if (mode == 5) {
		float a = radius_pixels;
		float b = radius_pixels * 1.5;
		return (d.x <= a) && (d.y <= a) && ((d.x + d.y) <= b);
	} else if (mode == 6) {
		float a = radius_pixels;
		return (d.x <= a) && (d.y <= a);
	} else {
		return false;
	}
}

bool equal_pixel(vec4 pixel_local[9], int pixel_id_local[9], int id_a, int id_b) {
	if (!ignore_palette) {
		if (pixel_local[id_a].a < 0.1 || pixel_local[id_b].a < 0.1) {
			return false;
		} else {
			return (pixel_id_local[id_a] == pixel_id_local[id_b]);
		}
	} else {
		if (pixel_local[id_a].a > 0.0 && pixel_local[id_b].a > 0.0) {
			return true;
		} else {
			return false;
		}
	}
}

bool is_horizontal_edge_local(bool l_match[9]) {
	int left_i = 3;
	int right_i = 5;
	int up_i = 1;
	int down_i = 7;
	int right_up_i = 2;
	int right_down_i = 8;
	int left_up_i = 0;
	int left_down_i = 6;
	int center_i = 4;
	bool edge = false;
	if (!l_match[up_i]) {
		edge = !l_match[left_up_i] || !l_match[right_up_i];
	} else if (!l_match[down_i]) {
		edge = !l_match[left_down_i] || !l_match[right_down_i];
	}
	return edge && (
		(l_match[left_i] && (l_match[right_down_i] || l_match[right_up_i] || l_match[right_i])) ||
		(l_match[right_i] && (l_match[left_down_i] || l_match[left_up_i] || l_match[left_i]))
	);
}

bool is_vertical_edge_local(bool l_match[9]) {
	int left_i = 3;
	int right_i = 5;
	int up_i = 1;
	int down_i = 7;
	int right_up_i = 2;
	int right_down_i = 8;
	int left_up_i = 0;
	int left_down_i = 6;
	int center_i = 4;
	bool edge = false;
	if (!l_match[left_i]) {
		edge = !l_match[left_up_i] || !l_match[left_down_i];
	} else if (!l_match[right_i]) {
		edge = !l_match[right_up_i] || !l_match[right_down_i];
	}
	return edge && (
		(l_match[up_i] && (l_match[left_down_i] || l_match[right_down_i] || l_match[down_i])) ||
		(l_match[down_i] && (l_match[left_up_i] || l_match[right_up_i] || l_match[up_i]))
	);
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
	if (actual_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		cache_palette_vertex(actual_palette_size, cached_palette, palette_colors);
	} else {
		cache_palette(input_palette_texture, actual_palette_size, cached_palette);
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

	vec2 center_coords = uv_base * vec2(main_texture_size);
	vec2 offset_pixels = offset * vec2(main_texture_size);

	vec4 pixel_orig[25];
	vec4 pixel[25];
	int pixel_id[25];

	sample_5x5_grid(TEXTURE, center_coords, offset_pixels, pixel_orig);
	bool has_nontransparent_neighbor = false;
	for(int i = 0; i < 25; i++) {
		if (pixel_orig[i].a > 0.1) {
			has_nontransparent_neighbor = true;
		}
	}
	if (!has_nontransparent_neighbor) {
		discard;
	}
	find_pixels_to_palette(pixel_orig, cached_palette, actual_palette_size, pixel, pixel_id);

	if (!disable) {
		bool found = false;
		int best_id = 0;
		vec3 best_color = vec3(0.0);
		float best_a = 0.0;
		for (int oy = -1; oy <= 1; oy++) {
			for (int ox = -1; ox <= 1; ox++) {
				bool match[9] = bool[9](false, false, false, false, false, false, false, false, false);
				ivec2 n_idx = center_idx + ivec2(ox, oy);
				vec2 n_center_px = vec2(n_idx) + vec2(0.5);
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

				vec4 neigh_pixel9[9];
				int neigh_id9[9];
				for (int ny = -1; ny <= 1; ny++) {
					for (int nx = -1; nx <= 1; nx++) {
						neigh_pixel9[(ny + 1) * 3 + (nx + 1)] = pixel_orig[(oy + ny + 2) * 5 + (ox + nx + 2)];
						neigh_id9[(ny + 1) * 3 + (nx + 1)] = pixel_id[(oy + ny + 2) * 5 + (ox + nx + 2)];
					}
				}

				for (int i = 0; i < 9; i++) {
					if (equal_pixel(neigh_pixel9, neigh_id9, i, 4)) {
						match[i] = true;
					}
				}

				bool neigh_h = is_horizontal_edge_local(match);
				bool neigh_v = is_vertical_edge_local(match);
				int shape_overwrite_local = filling_shape;
				if (neigh_h && !neigh_v) {
					shape_overwrite_local = edge_shape == 0 ? 4 : edge_shape;
				} else if (!neigh_h && neigh_v) {
					shape_overwrite_local = edge_shape == 0 ? 3 : edge_shape;
				} else if (neigh_h && neigh_v) {
					shape_overwrite_local = edge_shape == 0 ? 2 : edge_shape;
				} else {
					shape_overwrite_local = filling_shape;
					if (corniness > 0) {
						int matches = 0;
						for (int i = 0; i < 9; i++) {
							if (i != 4 && match[i]) {
								matches++;
							}
						}
						if (matches > 7 - int((corniness + 1)/2) || matches <= int(corniness/2)) {
							if (!match[1] || !match[3] || !match[5] || !match[7]) {
								shape_overwrite_local = edge_shape == 0 ? 5 : edge_shape;
							}
						}
					}
				}
				if (is_in_shape(uv_base, n_center_px, main_texture_size, shape_size, shape_overwrite_local)) {
					vec4 n_orig = neigh_pixel9[4];
					if (n_orig.a >= 0.1) {
						int nid = neigh_id9[4];
						if ((!found || (prefer_higher_palette_ids ? (nid > best_id) : (nid  < best_id))) && nid != -1) {
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
		COLOR = pixel[12];
	}
}
