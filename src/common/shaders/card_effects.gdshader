shader_type canvas_item;

group_uniforms code_set_parameters;
uniform vec2 mouse_position;
uniform vec2 sprite_position;

group_uniforms _3D_Perspective;
uniform float fov : hint_range(1, 179) = 90;
uniform bool cull_back = true;
uniform float inset : hint_range(0, 1) = 0.0;
uniform float max_tilt : hint_range(0,2.0) = 1.0;
uniform float max_distance = 500.0;

varying flat vec2 o;
varying vec3 p;

group_uniforms foil_uniforms;
uniform vec3 foilcolor : source_color;
uniform float threshold : hint_range(0.0, 2.0, 0.1) = 0.1;
uniform float fuzziness : hint_range(0.0,1.0,.01) = 0.1;
uniform float period = 1;
uniform float scroll = 1;
uniform float normal_strength = .1;
uniform float effect_alpha_mult : hint_range(0,1) = 1.0;
uniform float direction : hint_range(0,1.0) = 0.5;

uniform sampler2D foil_mask;
uniform sampler2D gradient;
uniform sampler2D noise;
uniform sampler2D normal_map;

group_uniforms dissolve_effect;
uniform bool enable_dissolve = false;
uniform vec2 dissolve_position;
uniform float dissolve_radius;
uniform float dissolve_borderWidth = 0.02;
uniform float dissolve_burnMult = 0.135;
uniform sampler2D dissolve_noiseTexture;
uniform vec4 dissolve_burnColor : source_color;

group_uniforms fill_effect;
uniform bool enable_fill = false;
uniform float fill_progress : hint_range(0.0, 1.0) = 0.5;
uniform vec4 fill_overlay_color : source_color = vec4(0.2, 1.0, 0.2, 0.5);
uniform vec2 fill_dir = vec2(1.0, 0.0);
uniform float fill_alpha_cutoff : hint_range(0.0, 1.0) = 0.01;

group_uniforms highlight_effect;
uniform bool enable_highlight = false;
uniform float highlight_Line_Smoothness : hint_range(0, 0.1) = 0.045;
uniform float highlight_Line_Width : hint_range(0, 0.2) = 0.09;
uniform float highlight_Brightness = 3.0;
uniform float highlight_Rotation_deg : hint_range(-90, 90) = 30;
uniform float highlight_Distortion : hint_range(1, 2) = 1.8;
uniform float highlight_Speed = 0.7;
uniform float highlight_Position : hint_range(0, 1) = 0;
uniform float highlight_Position_Min = 0.25;
uniform float highlight_Position_Max = 0.5;
uniform float highlight_Alpha : hint_range(0, 1) = 1;
uniform sampler2D highlight_surface : source_color;

group_uniforms collapse_effect;
uniform bool enable_collapse = false;
uniform float collapse_burst_progress : hint_range(0.0, 1.0) = 0.0;
uniform float collapse_spread_strength : hint_range(0.0, 2.0) = 1.0;
uniform float collapse_distortion_strength : hint_range(0.0, 0.2) = 0.05;
uniform float collapse_fade_start : hint_range(0.0, 1.0) = 0.7;

varying smooth vec2 direction_to;
varying smooth vec2 passthrough;

float inverse_lerp(float v, float a, float b){
	return (v - a) / (b - a);
}

float color_mask(vec3 mask, vec3 color, float mask_threshold, float mask_fuzziness){
	float d = distance(mask,color);
	return clamp(1.0 - smoothstep(mask_threshold,mask_threshold + mask_fuzziness, d),0.0,1.0);
}

mat2 rotate2d(float _angle){
    return mat2(vec2(cos(_angle),-sin(_angle)),vec2(sin(_angle),cos(_angle)));
}

vec3 rotate_vector(vec3 v, float angleX, float angleY, float magnitude) {
	mat3 rotX = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, cos(angleX), -sin(angleX)),
		vec3(0.0, sin(angleX), cos(angleX))
	);
	mat3 rotY = mat3(
		vec3(cos(angleY), 0.0, sin(angleY)),
		vec3(0.0, 1.0, 0.0),
		vec3(-sin(angleY), 0.0, cos(angleY))
	);
	mat3 combinedRotation = rotX * rotY;
	vec3 rotatedVector = combinedRotation * v;
	rotatedVector = normalize(rotatedVector) * magnitude;
	return rotatedVector;
}

vec2 rotate_uv(vec2 uv, vec2 center, float rotation, bool use_degrees){
	float _angle = rotation;
	if(use_degrees){
		_angle = rotation * (3.1415926/180.0);
	}
	mat2 _rotation = mat2(
		vec2(cos(_angle), -sin(_angle)),
		vec2(sin(_angle), cos(_angle))
	);
	vec2 _delta = uv - center;
	_delta = _rotation * _delta;
	return _delta + center;
}

void vertex(){
	direction_to = mouse_position - sprite_position;
	float d = length( direction_to );
	float magnitude = min( max_tilt , d / max_distance);
	float angle = atan(direction_to.x,direction_to.y);
	float x_rota = abs(angle) / PI;
	float y_rota = abs(atan(direction_to.y,direction_to.x)) / PI;
	
	float sin_b = sin( (-y_rota + .5) * magnitude * (PI / 2.0) );
	float cos_b = cos( (-y_rota + .5) * magnitude * (PI / 2.0) );
	float sin_c = sin( (x_rota - .5) * magnitude * (PI / 2.0) );
	float cos_c = cos( (x_rota - .5) * magnitude * (PI / 2.0) );
	
	mat3 inv_rot_mat;
	inv_rot_mat[0][0] = cos_b;
	inv_rot_mat[0][1] = 0.0;
	inv_rot_mat[0][2] = -sin_b;
	
	inv_rot_mat[1][0] = sin_b * sin_c;
	inv_rot_mat[1][1] = cos_c;
	inv_rot_mat[1][2] = cos_b * sin_c;
	
	inv_rot_mat[2][0] = sin_b * cos_c;
	inv_rot_mat[2][1] = -sin_c;
	inv_rot_mat[2][2] = cos_b * cos_c;
	
	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((UV - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;

	VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE * t * (1.0 - inset);
}

void fragment() {
	// Cull back face
	if (cull_back && p.z <= 0.0) discard;
	
	// Get the UV from based on the tilt from the vertex function
	vec2 uv = (p.xy / p.z).xy - o;
	vec2 adjusted_uv = uv + 0.5;
	
	// Apply collapse effect to UV if enabled
	vec2 final_uv = adjusted_uv;
	if (enable_collapse) {
		vec2 centered_uv = adjusted_uv - vec2(0.5);
		vec2 dir = normalize(centered_uv);
		float dist = length(centered_uv);
		
		vec2 uv_outward = centered_uv + dir * collapse_burst_progress * collapse_spread_strength;
		uv_outward += collapse_distortion_strength * vec2(
			sin(dist * 20.0 - TIME * 10.0),
			cos(dist * 20.0 - TIME * 8.0)
		) * collapse_burst_progress;
		
		final_uv = uv_outward + vec2(0.5);
	}
	
	// Get the color texture
	vec4 albedo_tex = texture(TEXTURE, final_uv);
	
	// Apply dissolve effect
	if (enable_dissolve) {
		float dist = length(dissolve_position - final_uv) + (texture(dissolve_noiseTexture, final_uv).b) * dissolve_burnMult;
		albedo_tex.rgb = mix(albedo_tex.rgb, dissolve_burnColor.rgb, float(dist < dissolve_radius + dissolve_borderWidth));
		albedo_tex.a *= 1.0 - (float(dist < dissolve_radius));
	}
	
	// Apply fill effect
	if (enable_fill && albedo_tex.a > fill_alpha_cutoff) {
		vec2 dir = fill_dir;
		float len_dir = length(dir);
		dir = (len_dir < 1e-5) ? vec2(1.0, 0.0) : dir / len_dir;
		
		vec2 min_corner = vec2(dir.x > 0.0 ? 0.0 : 1.0, dir.y > 0.0 ? 0.0 : 1.0);
		vec2 max_corner = vec2(1.0 - min_corner.x, 1.0 - min_corner.y);
		
		float min_proj = dot(min_corner, dir);
		float max_proj = dot(max_corner, dir);
		
		float pa = dot(final_uv, dir);
		float t = clamp((pa - min_proj) / max(1e-6, (max_proj - min_proj)), 0.0, 1.0);
		
		if (t <= fill_progress) {
			albedo_tex = mix(albedo_tex, fill_overlay_color, fill_overlay_color.a);
		}
	}
	
	// Base color
	COLOR = albedo_tex;
	
	// Foil effect
	vec4 mask = texture(foil_mask, final_uv);
	float texture_similarity = color_mask(foilcolor, albedo_tex.rgb, threshold, fuzziness);
	
	float d = length( direction_to );
	float magnitude = min( max_tilt , d / max_distance);
	float angle = atan(direction_to.x, direction_to.y);
	float x_rota = abs(angle) / PI;
	float y_rota = abs(atan(direction_to.y, direction_to.x)) / PI;
	
	vec3 normal_map_tex = texture(normal_map, final_uv).rgb * 2.0 - 1.0;
	vec3 normal = rotate_vector(vec3(1.0,1.0,1.0), x_rota, y_rota, magnitude * magnitude);
	normal = rotate_vector(normal, normal_map_tex.x, normal_map_tex.y, length(normal_map_tex)) * normal_strength;
	
	vec4 noise_tex = texture(noise, final_uv);
	
	vec2 gradiant_sample = vec2((0.25+(normal.y*direction*2.0-normal.x*(1.0-direction)*2.0)/2.0+(uv.y*direction+uv.x*(1.0-direction))/2.0), 0.0);
	gradiant_sample += vec2(magnitude,0.0) * scroll;
	gradiant_sample = mod((gradiant_sample+final_uv * period),1.0);
	vec4 gradient_tex = texture(gradient, gradiant_sample);
	float strength = effect_alpha_mult * mask.r * texture_similarity;
	
	COLOR.rgb = mix(albedo_tex.rgb, gradient_tex.rgb*(noise_tex.rgb*2.0), strength);
	
	// Apply highlight effect
	if (enable_highlight) {
		vec2 center_uv = final_uv - vec2(0.5, 0.5);
		float gradient_to_edge = max(abs(center_uv.x), abs(center_uv.y));
		gradient_to_edge = gradient_to_edge * highlight_Distortion;
		gradient_to_edge = 1.0 - gradient_to_edge;
		vec2 rotaded_uv = rotate_uv(final_uv, vec2(0.5, 0.5), highlight_Rotation_deg, true);
		
		float output_range = highlight_Position_Max - highlight_Position_Min;
		float remapped_position = highlight_Position_Min + output_range * highlight_Position;
		
		float remapped_time = TIME * highlight_Speed + remapped_position;
		remapped_time = fract(remapped_time);
		remapped_time = -2.0 + 4.0 * remapped_time;
		
		vec2 offset_uv = vec2(rotaded_uv.xy) + vec2(remapped_time, 0.0);
		float line = vec3(offset_uv, 0.0).x;
		line = abs(line);
		line = gradient_to_edge * line;
		line = sqrt(line);
		
		float line_smoothness = clamp(highlight_Line_Smoothness, 0.001, 1.0);
		float offset_plus = highlight_Line_Width + line_smoothness;
		float offset_minus = highlight_Line_Width - line_smoothness;
		
		float input_range = offset_minus - offset_plus;
		float remapped_line = (line - offset_plus) / input_range;
		remapped_line *= highlight_Brightness;
		remapped_line = min(remapped_line, highlight_Alpha);
		remapped_line = max(0.0, remapped_line);
		
		vec4 surface_tex = texture(highlight_surface, final_uv);
		float highlight_value = remapped_line * surface_tex.a;
		COLOR.rgb += highlight_value;
	}
	
	// Apply collapse fade
	if (enable_collapse) {
		float alpha_factor = 1.0 - smoothstep(collapse_fade_start, 1.0, collapse_burst_progress);
		COLOR.a *= alpha_factor;
	}
	
	// Final alpha mask
	COLOR.a *= step(max(abs(uv.x), abs(uv.y)), 0.5);
}
