#include "adding_includes/base.gdshaderinc"

const int MAX_PALETTE_SIZE = 32;
const int MAX_VERTEX_PALETTE_SIZE = 15;


int get_palette_size(sampler2D l_palette_texture) {
	ivec2 palette_size_vec = textureSize(l_palette_texture, 0);
	int detected_size = palette_size_vec.x;
	return min(detected_size, MAX_PALETTE_SIZE);
}

float random(vec2 l_seed, float l_speed, float l_time) {
	vec2 time_seed = l_seed;
	if (l_speed > 0.0) {
		time_seed += vec2(ceil(l_time * l_speed) / l_speed);
	}
	return fract(sin(dot(time_seed, vec2(12.9898, 78.233))) * 43758.5453);
}

float random_shift(vec2 l_seed, float l_offset, float l_speed, float l_time) {
	float r = random(l_seed + vec2(l_offset, 0.0), l_speed, l_time);
	if (r < 0.33) return -1.0;
	else if (r < 0.66) return 1.0;
	else return 0.0;
}

vec4 find_closest_palette_color_and_id(vec3 l_original_color, vec3 l_cached_palette[MAX_PALETTE_SIZE], int l_palette_size) {
	float min_distance = 999.0;
	vec3 closest_color = l_original_color;
	int closest_id = 0;

	for (int i = 0; i < l_palette_size; i++) {
		vec3 palette_color = l_cached_palette[i];

		vec3 diff = l_original_color - palette_color;
		float distance = dot(diff, diff);

		if (distance < min_distance) {
			min_distance = distance;
			closest_color = palette_color;
			closest_id = i;

			if (distance < 0.0001) {
				break;
			}
		}
	}

	return vec4(closest_color, float(closest_id));
}

vec4 find_palette_id(vec4 l_original_color, vec3 l_cached_palette[MAX_PALETTE_SIZE], int l_palette_size) {
	if (ignore_palette) {
		if (l_original_color.a > 0.0) {
			return vec4(l_original_color.rgb, 0.0);
		} else {
			return vec4(l_original_color.rgb, -1.0);
		}
	}
	float min_distance = 0.00000001;
	vec3 closest_color = l_original_color.rgb;
	int closest_id = -1;

	for (int i = 0; i < l_palette_size; i++) {
		vec3 palette_color = l_cached_palette[i];

		vec3 diff = l_original_color.rgb - palette_color;
		float distance = dot(diff, diff);

		if (distance < min_distance) {
			min_distance = distance;
			closest_color = palette_color;
			closest_id = i;

			if (distance < 0.00000001) {
				break;
			}
		}
	}
	return vec4(closest_color, float(closest_id));
}

void cache_palette(sampler2D l_palette_texture, int l_palette_size, inout vec3 l_cached_palette[MAX_PALETTE_SIZE]) {
	if (!ignore_palette) {
		for (int i = 0; i < l_palette_size; i++) {
			l_cached_palette[i] = texelFetch(l_palette_texture, ivec2(i, 0), 0).rgb;
		}
	} else {
		l_cached_palette[0] = vec3(1.0, 1.0, 1.0);
	}
}

void cache_palette_vertex(int l_palette_size, inout vec3 l_cached_palette[MAX_PALETTE_SIZE], vec3 l_vertex_palette[MAX_VERTEX_PALETTE_SIZE]) {
	if (!ignore_palette) {
		for (int i = 0; i < l_palette_size; i++) {
			l_cached_palette[i] = l_vertex_palette[i];
		}
	} else {
		l_cached_palette[0] = vec3(1.0, 1.0, 1.0);
	}
}

void sample_5x5_grid(sampler2D l_texture, vec2 l_center_coords, vec2 l_offset_pixels, inout vec4 l_pixel_orig[25]) {
	l_pixel_orig[0]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -2.0, l_offset_pixels.y * -2.0)));
	l_pixel_orig[1]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -1.0, l_offset_pixels.y * -2.0)));
	l_pixel_orig[2]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 0.0, l_offset_pixels.y * -2.0)));
	l_pixel_orig[3]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 1.0, l_offset_pixels.y * -2.0)));
	l_pixel_orig[4]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 2.0, l_offset_pixels.y * -2.0)));
	l_pixel_orig[5]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -2.0, l_offset_pixels.y * -1.0)));
	l_pixel_orig[6]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -1.0, l_offset_pixels.y * -1.0)));
	l_pixel_orig[7]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 0.0, l_offset_pixels.y * -1.0)));
	l_pixel_orig[8]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 1.0, l_offset_pixels.y * -1.0)));
	l_pixel_orig[9]  = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 2.0, l_offset_pixels.y * -1.0)));
	l_pixel_orig[10] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -2.0, l_offset_pixels.y * 0.0)));
	l_pixel_orig[11] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -1.0, l_offset_pixels.y * 0.0)));
	l_pixel_orig[12] = preprocess_input(l_texture, ivec2(l_center_coords));
	l_pixel_orig[13] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 1.0, l_offset_pixels.y * 0.0)));
	l_pixel_orig[14] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 2.0, l_offset_pixels.y * 0.0)));
	l_pixel_orig[15] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -2.0, l_offset_pixels.y * 1.0)));
	l_pixel_orig[16] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -1.0, l_offset_pixels.y * 1.0)));
	l_pixel_orig[17] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 0.0, l_offset_pixels.y * 1.0)));
	l_pixel_orig[18] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 1.0, l_offset_pixels.y * 1.0)));
	l_pixel_orig[19] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 2.0, l_offset_pixels.y * 1.0)));
	l_pixel_orig[20] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -2.0, l_offset_pixels.y * 2.0)));
	l_pixel_orig[21] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * -1.0, l_offset_pixels.y * 2.0)));
	l_pixel_orig[22] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 0.0, l_offset_pixels.y * 2.0)));
	l_pixel_orig[23] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 1.0, l_offset_pixels.y * 2.0)));
	l_pixel_orig[24] = preprocess_input(l_texture, ivec2(l_center_coords + vec2(l_offset_pixels.x * 2.0, l_offset_pixels.y * 2.0)));
}

void convert_pixels_to_palette(vec4 l_pixel_orig[25], vec3 l_cached_palette[MAX_PALETTE_SIZE], int l_palette_size, inout vec4 l_pixel[25], inout int l_pixel_id[25]) {
	for (int i = 0; i < 25; i++) {
		vec4 result = find_closest_palette_color_and_id(l_pixel_orig[i].rgb, l_cached_palette, l_palette_size);
		l_pixel[i] = vec4(result.rgb, l_pixel_orig[i].a);
		l_pixel_id[i] = int(result.a);
	}
}

void find_pixels_to_palette(vec4 l_pixel_orig[25], vec3 l_cached_palette[MAX_PALETTE_SIZE], int l_palette_size, inout vec4 l_pixel[25], inout int l_pixel_id[25]) {
	for (int i = 0; i < 25; i++) {
		vec4 result = find_palette_id(l_pixel_orig[i], l_cached_palette, l_palette_size);
		l_pixel[i] = vec4(result.rgb, int(result.a) >= 0 ? l_pixel_orig[i].a : 0.0);
		l_pixel_id[i] = int(result.a);
	}
}

struct MajorityPaletteResult {
	int palette_id;
	int index;
	int count;
	bool transparent;
};

#define find_majority_palette_id(N) MajorityPaletteResult find_majority_palette_id_##N(int l_pixel_id[N], vec4 l_pixel_orig[N], int l_palette_size) { \
	int palette_counts[MAX_PALETTE_SIZE]; \
	int transparent_count = 0; \
	for (int i = 0; i < l_palette_size; i++) { \
		palette_counts[i] = 0; \
	} \
	for (int i = 0; i < N; i++) { \
		if (l_pixel_id[i] >= 0 && l_pixel_id[i] < l_palette_size && l_pixel_orig[i].a > 0.1) { \
			palette_counts[l_pixel_id[i]]++; \
		} \
		if (l_pixel_orig[i].a < 0.1) { \
			transparent_count++; \
		} \
	} \
	 \
	MajorityPaletteResult result; \
	result.palette_id = 0; \
	result.count = 0; \
	for (int i = 0; i < l_palette_size; i++) { \
		if (palette_counts[i] > result.count) { \
			result.count = palette_counts[i]; \
			result.palette_id = i; \
		} \
	} \
	if (transparent_count >= result.count) { \
		result.transparent = true; \
	} else { \
		result.transparent = false; \
	} \
	return result; \
}

struct NeighborAnalysis {
	float palette_offset;
	bool border_pixel;
	int min_diff;
	int transparent_neighbors;
};

NeighborAnalysis analyze_neighbors_8(int l_pixel_id[25], vec4 l_pixel_orig[25], int l_center_palette_id, int l_palette_diff_threshold) {
	NeighborAnalysis result;
	result.palette_offset = 0.0;
	result.border_pixel = false;
	result.min_diff = 1000;
	result.transparent_neighbors = 0;

	int neighbor_indices[8] = int[8](6, 7, 8, 11, 13, 16, 17, 18);
	for (int i = 0; i < 8; i++) {
		if ((l_pixel_orig[neighbor_indices[i]].a < 0.1 || l_pixel_id[neighbor_indices[i]] == -1)) {
			result.border_pixel = true;
			result.transparent_neighbors++;
			continue;
		}
		int neighbor_palette_id = l_pixel_id[neighbor_indices[i]];
		int id_diff = neighbor_palette_id - l_center_palette_id;
		if (abs(id_diff) <= l_palette_diff_threshold || l_palette_diff_threshold == 0) {
			result.palette_offset += float(id_diff);
		}
		if (abs(id_diff) < result.min_diff && id_diff != 0) {
			result.min_diff = abs(id_diff);
		}
	}
	if (abs(result.palette_offset) > 0.0) {
		result.palette_offset += float(sign(result.palette_offset)) * float(result.transparent_neighbors);
	}
	return result;
}

void sample_3x3_grid(sampler2D l_texture, vec2 l_main_texture_size, vec2 l_uv, vec2 l_offset, vec2 l_shift_offset[8], inout vec4 l_pixel_orig[9]) {
	l_pixel_orig[4] = preprocess_input(l_texture, ivec2(l_uv * l_main_texture_size));
	l_pixel_orig[0] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(-1.0 * l_offset.x + l_offset.x * l_shift_offset[0].x, -1.0 * l_offset.y + l_offset.y * l_shift_offset[0].y))));
	l_pixel_orig[1] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(0.0 * l_offset.x + l_offset.x * l_shift_offset[1].x, -1.0 * l_offset.y + l_offset.y * l_shift_offset[1].y))));
	l_pixel_orig[2] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(1.0 * l_offset.x + l_offset.x * l_shift_offset[2].x, -1.0 * l_offset.y + l_offset.y * l_shift_offset[2].y))));
	l_pixel_orig[3] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(-1.0 * l_offset.x + l_offset.x * l_shift_offset[3].x, 0.0 * l_offset.y + l_offset.y * l_shift_offset[3].y))));
	l_pixel_orig[5] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(1.0 * l_offset.x + l_offset.x * l_shift_offset[4].x, 0.0 * l_offset.y + l_offset.y * l_shift_offset[4].y))));
	l_pixel_orig[6] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(-1.0 * l_offset.x + l_offset.x * l_shift_offset[5].x, 1.0 * l_offset.y + l_offset.y * l_shift_offset[5].y))));
	l_pixel_orig[7] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(0.0 * l_offset.x + l_offset.x * l_shift_offset[6].x, 1.0 * l_offset.y + l_offset.y * l_shift_offset[6].y))));
	l_pixel_orig[8] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(1.0 * l_offset.x + l_offset.x * l_shift_offset[7].x, 1.0 * l_offset.y + l_offset.y * l_shift_offset[7].y))));
}


void sample_3x3_grid_raw(sampler2D l_texture, vec2 l_main_texture_size, vec2 l_uv, vec2 l_offset, inout vec4 l_pixel_orig[9]) {
	l_pixel_orig[4] = preprocess_input(l_texture, ivec2(l_uv * l_main_texture_size));
	l_pixel_orig[0] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(-1.0 * l_offset.x, -1.0 * l_offset.y))));
	l_pixel_orig[1] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(0.0 * l_offset.x, -1.0 * l_offset.y))));
	l_pixel_orig[2] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(1.0 * l_offset.x, -1.0 * l_offset.y))));
	l_pixel_orig[3] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(-1.0 * l_offset.x, 0.0 * l_offset.y))));
	l_pixel_orig[5] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(1.0 * l_offset.x, 0.0 * l_offset.y))));
	l_pixel_orig[6] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(-1.0 * l_offset.x, 1.0 * l_offset.y))));
	l_pixel_orig[7] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(0.0 * l_offset.x, 1.0 * l_offset.y))));
	l_pixel_orig[8] = preprocess_input(l_texture, ivec2(l_main_texture_size * (l_uv + vec2(1.0 * l_offset.x, 1.0 * l_offset.y))));
}

void convert_9pixels_to_palette(vec4 l_pixel_orig[9], vec3 l_cached_palette[MAX_PALETTE_SIZE], int l_palette_size, inout vec4 l_pixel[9], inout int l_pixel_id[9]) {
	for (int i = 0; i < 9; i++) {
		vec4 result = find_closest_palette_color_and_id(l_pixel_orig[i].rgb, l_cached_palette, l_palette_size);
		l_pixel[i] = vec4(result.rgb, l_pixel_orig[i].a);
		l_pixel_id[i] = int(result.a);
	}
}

void find_9pixels_to_palette(vec4 l_pixel_orig[9], vec3 l_cached_palette[MAX_PALETTE_SIZE], int l_palette_size, inout vec4 l_pixel[9], inout int l_pixel_id[9]) {
	for (int i = 0; i < 9; i++) {
		vec4 result = find_palette_id(l_pixel_orig[i], l_cached_palette, l_palette_size);
		l_pixel[i] = vec4(result.rgb, int(result.a) >= 0 ? l_pixel_orig[i].a : 0.0);
		l_pixel_id[i] = int(result.a);
	}
}
