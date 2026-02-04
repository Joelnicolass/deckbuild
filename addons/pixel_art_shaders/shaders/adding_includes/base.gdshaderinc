#ifndef BASIC_UTILS
#ifdef EXTEND_FRAME
vec4 preprocess_original_input(ivec2 l_uv) {
#ifdef EXTEND_FRAME
	vec4 color = texelFetch(original_texture, l_uv - border_pixels, 0);
#else
	vec4 color = texelFetch(original_texture, l_uv, 0);
#endif

#ifdef MASK_EFFECT
	if (use_mask_color) {
		float mask_diff = distance(color.rgb, mask_color);
		if (mask_diff > 0.01) {
			color.a = 0.0;
		}
	}
	if (use_mask_texture) {
#ifdef EXTEND_FRAME
		vec4 mask_texture_color = texelFetch(mask_texture, l_uv - border_pixels, 0);
#else
		vec4 mask_texture_color = texelFetch(mask_texture, l_uv, 0);
#endif
		float mask_diff = distance(mask_texture_color.rgb, mask_color);
		if (mask_diff > 0.01) {
			color.a = 0.0;
		}
	}
#endif
	return color;
}
#endif
#endif

vec4 preprocess_input(sampler2D l_texture, ivec2 l_uv) {
#ifdef EXTEND_FRAME
	vec4 color;
	if (use_input_texture) {
		color = texelFetch(original_texture, l_uv - border_pixels, 0);
	} else {
		color = texelFetch(l_texture, l_uv - border_pixels, 0);
	}
#else
	vec4 color = texelFetch(l_texture, l_uv, 0);
#endif

#ifdef MASK_EFFECT
	if (use_mask_color) {
		float mask_diff = distance(color.rgb, mask_color);
		if (mask_diff > 0.01) {
			color.a = 0.0;
		}
	}
	if (use_mask_texture) {
#ifdef EXTEND_FRAME
		vec4 mask_texture_color = texelFetch(mask_texture, l_uv - border_pixels, 0);
#else
		vec4 mask_texture_color = texelFetch(mask_texture, l_uv, 0);
#endif
		float mask_diff = distance(mask_texture_color.rgb, mask_color);
		if (mask_diff > 0.01) {
			color.a = 0.0;
		}
	}
#endif
	return color;
}

vec4 preprocess_ext_input(sampler2D l_texture, ivec2 l_uv) {
#ifdef EXTEND_FRAME
	vec4 color;
	if (use_input_texture) {
		color = texelFetch(original_texture, l_uv - border_pixels, 0);
	} else {
		color = texelFetch(l_texture, l_uv - border_pixels, 0);
	}
#else
	vec4 color = texelFetch(l_texture, l_uv, 0);
#endif
	return color;
}

#ifndef BASIC_UTILS
vec4 preprocess_mask_input(vec4 l_color, ivec2 l_uv) {
	vec4 color = l_color;
#ifdef MASK_EFFECT
	if (use_mask_color) {
		float mask_diff = distance(color.rgb, mask_color);
		if (mask_diff > 0.01) {
			color.a = 0.0;
		}
	}
	if (use_mask_texture) {
#ifdef EXTEND_FRAME
		vec4 mask_texture_color = texelFetch(mask_texture, l_uv - border_pixels, 0);
#else
		vec4 mask_texture_color = texelFetch(mask_texture, l_uv, 0);
#endif
		float mask_diff = distance(mask_texture_color.rgb, mask_color);
		if (mask_diff > 0.01) {
			color.a = 0.0;
		}
	}
#endif
	return color;
}
#endif
