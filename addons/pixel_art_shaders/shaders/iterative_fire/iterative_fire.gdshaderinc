#include "../pixelart_utils_updated.gdshaderinc"

const int PALETTE_ID_NONE = -1;
const int INPUT_PALETTE_FLAG = 100;

varying flat int input_palette_size;
varying flat int effect_palette_size;
varying flat vec3 palette_colors[MAX_VERTEX_PALETTE_SIZE];

struct PaletteContext {
	vec3 cached_palette[MAX_PALETTE_SIZE];
	vec3 cached_effect_palette[MAX_PALETTE_SIZE];
	bool palette_loaded;
	bool effect_palette_loaded;
	int input_size;
	int output_size;
	int input_offset;
	int output_offset;
};

void ensure_palette_loaded(inout PaletteContext l_ctx) {
	if (l_ctx.palette_loaded || ignore_input_palette) return;
	if (input_palette_size + effect_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		for (int i = 0; i < input_palette_size; i++) {
			l_ctx.cached_palette[i] = palette_colors[i];
		}
		l_ctx.palette_loaded = true;
		return;
	}
	cache_palette(input_palette_texture, l_ctx.input_size, l_ctx.cached_palette);
	l_ctx.palette_loaded = true;
}

void ensure_output_palette_loaded(inout PaletteContext l_ctx) {
	if (l_ctx.effect_palette_loaded) return;
	if (input_palette_size + effect_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		for (int i = 0; i < effect_palette_size; i++) {
			l_ctx.cached_effect_palette[i] = palette_colors[input_palette_size + i];
		}
		l_ctx.effect_palette_loaded = true;
		return;
	}
	cache_palette(effect_palette_texture, l_ctx.output_size, l_ctx.cached_effect_palette);
	l_ctx.effect_palette_loaded = true;
}

int process_spawn(int l_closest_id, inout PaletteContext l_palette_ctx) {
	return map_palette_ids ? (l_palette_ctx.output_offset + l_closest_id - l_palette_ctx.input_offset) : l_palette_ctx.output_offset;
}

int get_feedback_id(vec4 l_color, inout PaletteContext l_palette_ctx) {
	int id = int(find_palette_id(l_color, l_palette_ctx.cached_effect_palette, l_palette_ctx.output_size).a);
	if (id == PALETTE_ID_NONE && only_edge_emit && !ignore_input_palette) {
		int input_id = int(find_palette_id(l_color, l_palette_ctx.cached_palette, l_palette_ctx.input_size).a);
		if (input_id != PALETTE_ID_NONE) {
			return process_spawn(input_id, l_palette_ctx);
		}
	}
	return id;
}

int get_spread_feedback_id(vec4 l_right, vec4 l_left, inout PaletteContext l_palette_ctx) {
	if (l_right.a <= 0.0 && l_left.a <= 0.0) return PALETTE_ID_NONE;

	int l_right_id = (l_right.a > 0.0) ? get_feedback_id(l_right, l_palette_ctx) : PALETTE_ID_NONE;
	int l_left_id = (l_left.a > 0.0) ? get_feedback_id(l_left, l_palette_ctx) : PALETTE_ID_NONE;
	return max(l_right_id, l_left_id);
}

int process_decay(int l_feedback_id, float l_decay_value, int l_max_id, bool l_force_decay) {
	if (l_feedback_id == PALETTE_ID_NONE) return PALETTE_ID_NONE;
	bool should_advance_decay = l_force_decay || l_decay_value >= trail_persistence;
	if (!should_advance_decay) return l_feedback_id;
	int l_next_id = l_feedback_id + 1;
	return (l_next_id > l_max_id) ? PALETTE_ID_NONE : l_next_id;
}

int get_id_safe(sampler2D tex, ivec2 coord, vec2 size, inout PaletteContext ctx) {
	vec4 col = texelFetch(tex, coord, 0);
	if (col.a <= 0.0) return PALETTE_ID_NONE;
	return get_feedback_id(col, ctx);
}

int get_weighted_previous_id(sampler2D tex, vec2 pos, vec2 texture_size, inout PaletteContext ctx, int max_id) {
	ivec2 p0 = ivec2(floor(pos));
	vec2 w = fract(pos);

	float phase_noise = sin(pos.x * 12.0 + pos.y * 17.0) * 0.3;
	w = clamp(w + vec2(phase_noise), 0.0, 1.0);
	w = smoothstep(0.1, 0.9, w);

	int id1 = get_id_safe(tex, p0 + ivec2(1, 0), texture_size, ctx);
	int id0 = get_id_safe(tex, p0, texture_size, ctx);
	int id2 = get_id_safe(tex, p0 + ivec2(0, 1), texture_size, ctx);
	int id3 = get_id_safe(tex, p0 + ivec2(1, 1), texture_size, ctx);

	float limit = float(max_id) + 1.5;

	float v0 = (id0 == PALETTE_ID_NONE) ? limit : float(id0);
	float v1 = (id1 == PALETTE_ID_NONE) ? limit : float(id1);
	float v2 = (id2 == PALETTE_ID_NONE) ? limit : float(id2);
	float v3 = (id3 == PALETTE_ID_NONE) ? limit : float(id3);

	float val_top = mix(v0, v1, w.x);
	float val_bot = mix(v2, v3, w.x);
	float val = mix(val_top, val_bot, w.y);

	if (val > float(max_id) + 0.5) return PALETTE_ID_NONE;
	return int(round(val));
}

int process_iteration(sampler2D l_previous_frame, float l_time, ivec2 base_uv_pos, int step_offset, vec2 texture_size, vec4 last_iteration_color, inout PaletteContext palette_ctx, int max_output_id, int effective_range, int output_effective_range) {
	ivec2 lookup_uv_pos = base_uv_pos + ivec2(int(flow_direction_x * float(step_offset - 1)), int(flow_direction_y * float(step_offset - 1)));

	vec2 flow_vec = vec2(flow_direction_x, flow_direction_y);

	vec2 drift_phase = vec2(base_uv_pos) * 0.1 + vec2(l_time * 0.1);
	vec2 river_offset = vec2(
		sin(drift_phase.x * 2.1 + drift_phase.y * 1.4),
		cos(drift_phase.x * 1.7 + drift_phase.y * 2.5)
	) * 0.15;

	vec2 target_uv_float = vec2(lookup_uv_pos) + flow_vec + river_offset;
	ivec2 flow_shifted_uv = ivec2(round(target_uv_float));

	int previous_palette_id = PALETTE_ID_NONE;
	vec4 previous_frame_color = last_iteration_color;

	if (step_offset == iterations) {
		previous_palette_id = get_weighted_previous_id(l_previous_frame, target_uv_float, texture_size, palette_ctx, max_output_id);

		if (previous_palette_id != PALETTE_ID_NONE) {
			previous_frame_color = vec4(palette_ctx.cached_effect_palette[previous_palette_id], 1.0);
		} else {
			previous_frame_color = vec4(0.0);
		}
	}

	vec4 current_pixel_color = preprocess_original_input(lookup_uv_pos);

	ivec2 flow_forward_offset = ivec2(0, 1);
	ivec2 flow_left_offset = ivec2(-1, 0);
	ivec2 flow_right_offset = ivec2(1, 0);
	if (abs(flow_direction_x) > abs(flow_direction_y)) {
		flow_left_offset = ivec2(0, -1);
		flow_right_offset = ivec2(0, 1);
		if (flow_direction_x > 0.0) {
			flow_forward_offset = ivec2(1, 0);
		} else {
			flow_forward_offset = ivec2(-1, 0);
		}
	} else {
		if (flow_direction_y > 0.0) {
			flow_forward_offset = ivec2(0, 1);
		} else {
			flow_forward_offset = ivec2(0, -1);
		}
	}

	bool has_spread_effect = abs(spread) > 0.0001;
	vec4 previous_frame_right = vec4(0.0);
	vec4 previous_frame_left = vec4(0.0);
	if (has_spread_effect && step_offset == iterations) {
		previous_frame_right = texelFetch(l_previous_frame, flow_shifted_uv + flow_right_offset, 0);
		previous_frame_left = texelFetch(l_previous_frame, flow_shifted_uv + flow_left_offset, 0);
	}

	vec2 seed = vec2(float(lookup_uv_pos.x) / texture_size.x, float(lookup_uv_pos.y) / texture_size.y) + vec2(0.1 * random_seed, 0.12 * random_seed);
	float decay_value = random(seed, random_frequency, l_time + dot(seed, vec2(12.9898, 78.233)) * 10.0);

	float dist_to_edge = min(
		min(seed.x, 1.0 - seed.x) * texture_size.x,
		min(seed.y, 1.0 - seed.y) * texture_size.y
	);
	float min_decay = step(dist_to_edge, float(edge_pixel_size));
	decay_value = clamp(decay_value, min_decay, 1.0);

	float spawn_value = random(seed + vec2(0.37, 0.19) + vec2(0.2 * random_seed, 0.03 * random_seed), random_frequency, l_time + dot(seed, vec2(39.75, 59.31)) * 10.0);

	int output_palette_id = PALETTE_ID_NONE;
	bool has_current_pixel = current_pixel_color.a > 0.0;
	bool has_previous_pixel = previous_frame_color.a == 1.0;
	bool can_decay_pixel = decay_value > -1.0;

	if (has_current_pixel) {
		int matched_input_palette_id = PALETTE_ID_NONE;
		bool is_in_input_range = false;
		if (!disable_emission) {
			matched_input_palette_id = ignore_input_palette ? palette_ctx.input_offset : int(find_palette_id(current_pixel_color, palette_ctx.cached_palette, input_palette_size).a);
			if (inverse_palette) {
				matched_input_palette_id = input_palette_size - matched_input_palette_id - 1;
			}
			is_in_input_range = matched_input_palette_id >= palette_ctx.input_offset && matched_input_palette_id < palette_ctx.input_offset + effective_range;
			if (is_in_input_range) {
				if (only_edge_emit && !ignore_input_palette) {
					return INPUT_PALETTE_FLAG + matched_input_palette_id;
				} else if (spawn_value <= spawn_chance && spawn_chance > 0.0) {
					output_palette_id = process_spawn(matched_input_palette_id, palette_ctx);
				}
				can_decay_pixel = false;
			}
		}
		if (has_previous_pixel) {
			if ((output_palette_id == PALETTE_ID_NONE || output_palette_id > previous_palette_id || matched_input_palette_id == PALETTE_ID_NONE) && (matched_input_palette_id >= previous_palette_id || matched_input_palette_id == PALETTE_ID_NONE || overlay_higher_colors)) {
				if (matched_input_palette_id == previous_palette_id && is_in_input_range) {
					decay_value = 0.0;
				}
				if (previous_palette_id > PALETTE_ID_NONE) {
					float spread_modifier = 1.0 - float(previous_palette_id - palette_ctx.output_offset) / float(output_effective_range);
					spread_modifier = spread_modifier * trail_persistence;
					bool force_edge_decay = has_spread_effect && spread < 0.0 &&
						(previous_frame_right.a == 0.0 || previous_frame_left.a == 0.0) &&
						decay_value < abs(spread * spread_modifier);
					output_palette_id = process_decay(previous_palette_id, decay_value, max_output_id, force_edge_decay);
				} else {
					output_palette_id = PALETTE_ID_NONE;
				}
			}
		} else if (can_decay_pixel && has_spread_effect && spread > 0.0) {
			previous_palette_id = get_spread_feedback_id(previous_frame_right, previous_frame_left, palette_ctx);
			if (previous_palette_id > PALETTE_ID_NONE) {
				float spread_modifier = 1.0 - float(previous_palette_id - palette_ctx.output_offset) / float(output_effective_range);
				spread_modifier = spread_modifier * trail_persistence;
				output_palette_id = (decay_value <= abs(spread * spread_modifier)) ? previous_palette_id : PALETTE_ID_NONE;
			}
		}
	} else if (has_previous_pixel) {
		float spread_modifier = 1.0 - float(previous_palette_id - palette_ctx.output_offset) / float(output_effective_range);
		spread_modifier = spread_modifier * trail_persistence;
		bool force_edge_decay = has_spread_effect && spread < 0.0 &&
			(previous_frame_right.a == 0.0 || previous_frame_left.a == 0.0) &&
			decay_value < abs(spread * spread_modifier);
		output_palette_id = process_decay(previous_palette_id, decay_value, max_output_id, force_edge_decay);
	} else {
		if (has_spread_effect && spread > 0.0) {
			int previous_palette_id = get_spread_feedback_id(previous_frame_right, previous_frame_left, palette_ctx);
			if (previous_palette_id > PALETTE_ID_NONE) {
				float spread_modifier = 1.0 -float(previous_palette_id - palette_ctx.output_offset) / float(output_effective_range);
				spread_modifier = spread_modifier * trail_persistence;
				output_palette_id = (decay_value < abs(spread * spread_modifier)) ? previous_palette_id : PALETTE_ID_NONE;
			}
		}
	}
	return output_palette_id;
}


void vertex() {
	input_palette_size = get_palette_size(input_palette_texture);
	effect_palette_size = get_palette_size(effect_palette_texture);

	if (input_palette_size + effect_palette_size <= MAX_VERTEX_PALETTE_SIZE) {
		for (int i = 0; i < input_palette_size; i++) {
			palette_colors[i] = texelFetch(input_palette_texture, ivec2(i, 0), 0).rgb;
		}
		for (int i = 0; i < effect_palette_size; i++) {
			palette_colors[input_palette_size + i] = texelFetch(effect_palette_texture, ivec2(i, 0), 0).rgb;
		}
	}
}

void fragment() {
	if (disable) {
		discard;
	} else {
		vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
		ivec2 fragment_uv_pos = ivec2(UV * texture_size);

		PaletteContext palette_ctx;
		palette_ctx.palette_loaded = false;
		palette_ctx.effect_palette_loaded = false;
		palette_ctx.input_size = input_palette_size;
		palette_ctx.output_size = effect_palette_size;
		palette_ctx.input_offset = input_palette_offset;
		palette_ctx.output_offset = output_palette_offset;

		int effective_range = (input_palette_range > 0) ?
			min(input_palette_range + input_palette_offset, input_palette_size) - input_palette_offset :
			input_palette_size - input_palette_offset;
		if (inverse_palette) {
			palette_ctx.input_offset = input_palette_size - effective_range - input_palette_offset;
		}
		int output_effective_range = (output_palette_range > 0) ?
			min(output_palette_range + output_palette_offset, palette_ctx.output_size) - output_palette_offset :
			palette_ctx.output_size - output_palette_offset;
		int max_output_id = min(palette_ctx.output_size - 1, output_effective_range + output_palette_offset - 1);

		int output_palette_id = PALETTE_ID_NONE;
		vec4 current_iteration_color = vec4(0.0);

		ensure_palette_loaded(palette_ctx);
		ensure_output_palette_loaded(palette_ctx);
		for (int step = iterations; step >= 1; step--) {
			float use_time = time;
			if (time < 0.0) use_time = TIME;
			output_palette_id = process_iteration(TEXTURE, use_time, fragment_uv_pos, step, texture_size, current_iteration_color, palette_ctx, max_output_id, effective_range, output_effective_range);
			if (output_palette_id >= INPUT_PALETTE_FLAG) {
				current_iteration_color = vec4(palette_ctx.cached_palette[output_palette_id - INPUT_PALETTE_FLAG], 1.0);
			} else if (output_palette_id >= 0) {
				current_iteration_color = vec4(palette_ctx.cached_effect_palette[output_palette_id], 1.0);
			} else {
				current_iteration_color = vec4(0.0);
			}
		}

		if (output_palette_id >= INPUT_PALETTE_FLAG) {
			int idx = output_palette_id - INPUT_PALETTE_FLAG;
			if (idx < palette_ctx.input_size) {
				 COLOR = vec4(palette_ctx.cached_palette[idx], 1.0);
			} else {
				 discard;
			}
		} else if (output_palette_id >= 0 && output_palette_id < palette_ctx.output_size) {
			COLOR = vec4(palette_ctx.cached_effect_palette[output_palette_id], 1.0);
		} else {
			discard;
		}
	}
}
