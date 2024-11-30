shader_type spatial;

uniform float emission_amount = 1.0;

uniform float curvature_amount_x = 1.0;
uniform float curvature_amount_y = 1.0;
uniform float curvature_ramp = 2.0;

uniform float edge_darken = 0.3;

uniform float edge_burn = 0.8;
uniform float edge_burn_ramp = 10.0;

uniform float distort_amount = 1.0;
uniform vec2 distort_offset = vec2(0);

uniform float brightness: hint_range(0.0, 2.0) = 1.0;
uniform float contrast: hint_range(0.0, 2.0) = 1.0;

uniform sampler2D tex: source_color, filter_linear, repeat_disable;
uniform sampler2D noise_texture: source_color, filter_nearest;
uniform sampler2D distort_texture: source_color, filter_nearest;

void vertex() {
	// Called for every vertex the material is visible on.
	VERTEX.y -= pow(abs(UV.x - 0.5), curvature_ramp) * curvature_amount_x;
	VERTEX.y -= pow(abs(UV.y - 0.5), curvature_ramp) * curvature_amount_y;
}

void fragment() {
	vec2 distort_uv = vec2(texture(distort_texture, vec2(-TIME * 0.1, UV.y - TIME * 0.7)).x * 0.005, 0.0) * distort_amount + distort_offset;
	ALBEDO = texture(tex, UV + distort_uv).rgb;
	ALBEDO = mix(vec3(0.0), ALBEDO, brightness);
	ALBEDO = mix(vec3(0.5), ALBEDO, contrast);

	ALBEDO -= pow(abs(UV.x - 0.5), 7) * edge_darken;
	ALBEDO -= pow(abs(UV.y - 0.5), 6) * edge_darken;

	ALBEDO -= pow(abs(UV.x - 0.5) * 2.0, edge_burn_ramp) * edge_burn;
	ALBEDO -= pow(abs(UV.y - 0.5) * 2.0, edge_burn_ramp) * edge_burn;

	ALBEDO *= texture(noise_texture, UV).rgb;

	ALBEDO = clamp(ALBEDO, 0.0, 1.0);

	EMISSION = ALBEDO * emission_amount;

	METALLIC = 0.3;
}