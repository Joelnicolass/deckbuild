/*
Channel R:
Bits 0-3: transparent_neighbors (4)
Bits 4-7: color_pos (4)

Channel G:
Bits 0-5: minimum_palette_difference (6)
Bit  6  : is_border_pixel (1)
Bit  7  : invalid_id (1)

Channel B:
Bits 0-6: palette_difference magnitude (7)
Bit  7  : palette_difference sign (1)

Channel A:
Always 1.0
*/

struct PreprocessData {
	int transparent_neighbors;
	int minimum_palette_difference;
	int color_pos;
	bool is_border_pixel;
	int palette_difference;
	bool invalid_id;
};

vec4 encode_data(PreprocessData data) {
	uvec4 p = uvec4(0u);
	p.x |= (uint(data.transparent_neighbors) & 0xFu);
	p.x |= (uint(data.color_pos) & 0xFu) << 4u;
	p.y |= (uint(data.minimum_palette_difference) & 0x3Fu);
	if (data.is_border_pixel) {
		p.y |= (1u << 6u);
	}
	if (data.invalid_id) {
		p.y |= (1u << 7u);
	}
	uint pd_abs = uint(abs(data.palette_difference));
	uint pd_sign = (data.palette_difference < 0) ? 1u : 0u;
	p.z |= (pd_abs & 0x7Fu) | (pd_sign << 7u);
	p.w = 255u;

	return vec4(p) / 255.0;
}

PreprocessData decode_data(vec4 color) {
	uvec4 p = uvec4(round(color * 255.0));

	PreprocessData data;
	data.transparent_neighbors = int(p.x & 0xFu);
	data.color_pos = int((p.x >> 4u) & 0xFu);
	data.minimum_palette_difference = int(p.y & 0x3Fu);
	data.is_border_pixel = bool((p.y >> 6u) & 0x1u);
	data.invalid_id = bool((p.y >> 7u) & 0x1u);

	int pd_mag = int(p.z & 0x7Fu);
	bool pd_neg = bool((p.z >> 7u) & 0x1u);
	data.palette_difference = pd_neg ? -pd_mag : pd_mag;

	return data;
}
