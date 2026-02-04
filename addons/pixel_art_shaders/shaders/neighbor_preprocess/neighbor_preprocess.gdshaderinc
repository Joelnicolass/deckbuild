#include "../pixelart_utils_updated.gdshaderinc"

varying flat int actual_palette_size;
varying flat vec3 palette_colors[MAX_VERTEX_PALETTE_SIZE];

#include "../adding_includes/static_preprocess.gdshaderinc"

const int neighbor_indices[16] = int[16](1, 2, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 22, 23);


find_majority_palette_id(25)

void vertex() {
	actual_palette_size = get_palette_size(input_palette_texture);
	if (actual_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		cache_palette_vertex(actual_palette_size, cached_palette, palette_colors);
	} else {
		cache_palette(input_palette_texture, actual_palette_size, cached_palette);
	}
}

void fragment() {
	bool disable_override = false;
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
	vec4 center_pixel_orig;
	int center_pixel_id;

	vec4 pixel_orig[25];
	vec4 pixel[25];
	int pixel_id[25];
	sample_5x5_grid(TEXTURE, center_coords, offset_pixels, pixel_orig);
	find_pixels_to_palette(pixel_orig, cached_palette, actual_palette_size, pixel, pixel_id);
	for (int i = 0; i < 25; i++) {
		if (pixel_orig[i].a < 0.1) { transparent_count++; }
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
	}

	PreprocessData preprocess_data;
	preprocess_data.transparent_neighbors = min(min(preprocess_data.transparent_neighbors, 8), neighbor_analysis.transparent_neighbors);

	preprocess_data.minimum_palette_difference = neighbor_analysis.min_diff;
	preprocess_data.is_border_pixel = neighbor_analysis.border_pixel;
	if (abs(preprocess_data.palette_difference) > 0) {
		preprocess_data.palette_difference = int(neighbor_analysis.palette_offset - float(sign(neighbor_analysis.palette_offset)) * float(neighbor_analysis.transparent_neighbors));
	} else {
		preprocess_data.palette_difference = 0;
	}
	preprocess_data.invalid_id = center_pixel_id == -1 || center_pixel_orig.a == 0.0;
	preprocess_data.color_pos = 0;
	for (int i = 0; i < 16; i++) {
		int neighbor_idx = neighbor_indices[i];
		if (pixel_id[neighbor_idx] == majority_result.palette_id) {
			preprocess_data.color_pos = i;
			break;
		}
	}
	COLOR = encode_data(preprocess_data);
}
