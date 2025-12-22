shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap_anisotropic;

uniform sampler2D noise_texture: filter_nearest;
uniform float noise_strength: hint_range(0.0, 0.1, 0.005) = 0.04;
uniform float noise_speed: hint_range(0.0, 1.0, 0.01) = 1.0;

uniform float brightness: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float contrast: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float saturation: hint_range(0.0, 10.0, 0.01) = 1.0;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	vec4 col = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	col.rgb = mix(vec3(0.0), col.rgb, brightness);
	col.rgb = mix(vec3(0.5), col.rgb, contrast);
	col.rgb = mix(vec3(dot(vec3(1.0), col.rgb) * 0.33333), col.rgb, saturation);
	
	vec3 noise = texture(noise_texture, SCREEN_UV + rand((SCREEN_UV + TIME) * noise_speed)).rgb - vec3(0.5);
	col.rgb = mix(col.rgb, col.rgb + noise, noise_strength);
	
	COLOR = col;
}
