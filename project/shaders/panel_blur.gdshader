shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap_anisotropic;

uniform float blur_amount: hint_range(0.0, 8.0) = 0.0;

uniform vec3 panel_color: source_color = vec3(0);
uniform float panel_opacity: hint_range(0.0, 1.0) = 1.0;

uniform sampler2D noise_texture: filter_nearest;
uniform float noise_strength = 0.015;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	COLOR = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);

	COLOR.rgb = mix(COLOR.rgb, panel_color, panel_opacity);

	vec3 noise = texture(noise_texture, SCREEN_UV).rgb - vec3(0.5);
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb + noise, noise_strength);
}