shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap_anisotropic;

uniform sampler2D noise_texture: filter_nearest;
uniform float noise_strength: hint_range(0.0, 0.1, 0.005) = 0.04;
uniform float noise_speed: hint_range(0.0, 1.0, 0.01) = 1.0;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec3 noise = texture(noise_texture, SCREEN_UV + rand((SCREEN_UV + TIME) * noise_speed)).rgb - vec3(0.5);
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb + noise, noise_strength);
}
