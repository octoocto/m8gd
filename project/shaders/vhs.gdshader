// https://www.shadertoy.com/view/MdffD7
// Fork of FMS_Cat's VCR distortion shader

shader_type canvas_item;

// TODO: Add uniforms for tape crease discoloration and image jiggle

uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform vec2 vhs_resolution = vec2(320.0, 240.0);

uniform int samples = 2;
uniform float crease_noise: hint_range(0.0, 2.0, 0.1) = 1.0;
uniform float crease_opacity: hint_range(0.0, 1.0, 0.1) = 0.5;
uniform float filter_intensity: hint_range(0.0, 1.0, 0.1) = 0.1;

group_uniforms tape_crease;
uniform float tape_crease_smear: hint_range(0.0, 2.0, 0.1) = 0.2;
uniform float tape_crease_intensity: hint_range(0.0, 1.0, 0.1) = 0.2;
uniform float tape_crease_jitter: hint_range(0.0, 1.0, 0.01) = 0.10;
uniform float tape_crease_speed: hint_range(-2.0, 2.0, 0.1) = 0.5;
uniform float tape_crease_discoloration: hint_range(0.0, 2.0, 0.1) = 1.0;

group_uniforms bottom_border;
uniform float bottom_border_thickness: hint_range(0.0,32.0, 0.1) = 6.0;
uniform float bottom_border_jitter: hint_range(0.0, 24.0, 0.5) = 6.0;

group_uniforms noise;
uniform float noise_intensity: hint_range(0.0, 1.0, 0.1) = 0.1;
uniform sampler2D noise_texture: filter_linear_mipmap, repeat_enable;

float v2random(vec2 uv) {
	return texture(noise_texture, mod(uv, vec2(1.0))).x;
}

mat2 rotate2D(float t) {
	return mat2(vec2(cos(t), sin(t)), vec2(-sin(t), cos(t)));
}

vec3 rgb2yiq(vec3 rgb) {
	return mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312)) * rgb;
}

vec3 yiq2rgb(vec3 yiq) {
	return mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703)) * yiq;
}

vec3 vhx_tex_2D(sampler2D tex, vec2 uv, float rot) {
	vec3 yiq = vec3(0.0);
	for (int i = 0; i < samples; i++) {
		yiq += rgb2yiq(texture(tex, uv - vec2(float(i), 0.0) / vhs_resolution).xyz) *
				vec2(float(i), float(samples - 1 - i)).yxx / float(samples - 1)
				/ float(samples) * 2.0;
	}
	if (rot != 0.0) {
		yiq.yz *= rotate2D(rot * tape_crease_discoloration);
	}
	return yiq2rgb(yiq);
}

void fragment() {
	vec2 uvn = UV;
	vec3 col = vec3(0.0, 0.0, 0.0);

	// Tape wave.
	uvn.x += (v2random(vec2(uvn.y / 10.0, TIME / 10.0) / 1.0) - 0.5) / vhs_resolution.x * 1.0;
	uvn.x += (v2random(vec2(uvn.y, TIME * 10.0)) - 0.5) / vhs_resolution.x * 1.0;

	// tape crease
	float tc_phase = smoothstep(0.9, 0.96, sin(uvn.y * 8.0 - (TIME * tape_crease_speed + tape_crease_jitter * v2random(TIME * vec2(0.67, 0.59))) * PI * 1.2));
	float tc_noise = smoothstep(0.3, 1.0, v2random(vec2(uvn.y * 4.77, TIME)));
	float tc = tc_phase * tc_noise;
	uvn.x = uvn.x - tc / vhs_resolution.x * 8.0 * tape_crease_smear;

	// switching noise
	float sn_phase = smoothstep(1.0 - bottom_border_thickness / vhs_resolution.y, 1.0, uvn.y);
	uvn.x += sn_phase * (v2random(vec2(UV.y * 100.0, TIME * 10.0)) - 0.5) / vhs_resolution.x * bottom_border_jitter;

	// fetch
	col = vhx_tex_2D(screen_texture, uvn, tc_phase * 0.2 + sn_phase * 2.0);

	// crease noise
	float cn = tc_noise * crease_noise * (0.7 * tc_phase * tape_crease_intensity + 0.3);
	if (0.29 < cn) {
		vec2 V = vec2(0.0, crease_opacity);
		vec2 uvt = (uvn + V.yx * v2random(vec2(uvn.y, TIME))) * vec2(0.1, 1.0);
		float n0 = v2random(uvt);
		float n1 = v2random(uvt + V.yx / vhs_resolution.x);
		if (n1 < n0) {
			col = mix(col, 2.0 * V.yyy, pow(n0, 10.0));
		}
	}

	// ac beat
	col *= 1.0 + 0.1 * smoothstep(0.4, 0.6, v2random(vec2(0.0, 0.1 * (UV.y + TIME * 0.2)) / 10.0));

	// color noise
	col *= 1.0 - noise_intensity * 0.5 + noise_intensity * texture(noise_texture, mod(uvn * vec2(1.0, 1.0) + TIME * vec2(5.97, 4.45), vec2(1.0))).xyz;
	col = clamp(col, 0.0, 1.0);

	// yiq
	col = rgb2yiq(col);
	col = vec3(0.9, 1.1, 1.5) * col + vec3(0.1, -0.1, 0.0) * filter_intensity;
	col = yiq2rgb(col);

	COLOR = vec4(col, 1.0);
}