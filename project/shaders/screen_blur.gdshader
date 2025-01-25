shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap_anisotropic;

uniform float blur_amount = 0.0;

uniform vec3 tint_color: source_color = vec3(1);
uniform float tint_amount: hint_range(0.0, 1.0) = 1.0;

uniform float brightness: hint_range(0.0, 2.0) = 1.0;

uniform sampler2D noise_texture: filter_nearest;
uniform float noise_strength = 0.015;
uniform float noise_speed = 1.0;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec2 uv_rotate(vec2 uv, vec2 pivot, float rotation) {
	mat2 rotation_matrix=mat2(
		vec2(sin(rotation),-cos(rotation)),
		vec2(cos(rotation),sin(rotation))
	);
	uv -= pivot;
	uv= uv*rotation_matrix;
	uv += pivot;
	return uv;
}

void fragment() {
	COLOR = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);

	COLOR.rgb = mix(COLOR.rgb, tint_color, tint_amount);

	COLOR.rgb = mix(vec3(0), COLOR.rgb, brightness);
	vec3 noise = texture(noise_texture, SCREEN_UV + rand((SCREEN_UV + TIME) * noise_speed)).rgb - vec3(0.5);
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb + noise, noise_strength);
}
