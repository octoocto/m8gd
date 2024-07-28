shader_type spatial;
render_mode unshaded;

uniform sampler2D albedo: repeat_enable, filter_nearest, source_color;
uniform vec2 uv_min = vec2(0);
uniform vec2 uv_max = vec2(1);

uniform vec3 color_bg: source_color = vec3(0);
uniform vec3 color_fg: source_color = vec3(1);

uniform vec2 polar_offset;
uniform float offset = 0.0;
uniform float scroll = 0.0;

vec2 rect_to_polar(vec2 p, float o) {
	return vec2(length(p), atan(p.y + o, p.x + o));
}

vec2 wrap(vec2 vec, vec2 mn, vec2 mx) {
	return mn + mod(vec, mx - mn);
}

void fragment() {
	vec2 uv = rect_to_polar(abs(UV + polar_offset), offset) - vec2(scroll);

	vec4 color = texture(albedo, wrap(uv, uv_min, uv_max));
	if (color.a == 1.0) {
		ALBEDO = color_fg;
	} else {
		ALBEDO = color_bg;
	}

	//ALPHA = clamp(ALBEDO.r + 0.5, 0.0, 1.0);
}