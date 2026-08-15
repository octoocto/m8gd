shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap_anisotropic;

uniform sampler2D noise_texture: filter_nearest, repeat_enable;
uniform float noise_strength: hint_range(0.0, 0.1, 0.001) = 0.04;
uniform float static_noise_strength: hint_range(0.0, 0.1, 0.001) = 0.0;

uniform float brightness: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float contrast: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float saturation: hint_range(0.0, 10.0, 0.01) = 1.0;

uniform float vignette_strength: hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float vignette_inner_radius: hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float vignette_outer_radius: hint_range(0.0, 1.0, 0.01) = 1;
uniform float vignette_dither_strength: hint_range(0.0, 0.1, 0.001) = 0.03;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}



float vignette_fac(vec2 uv) {
	float dist = distance(uv, vec2(0.5));
	
	float vignette = smoothstep(vignette_inner_radius, vignette_outer_radius, dist) * vignette_strength;
	float dither = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123) * vignette_dither_strength;
	
	return vignette + dither;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 col = texture(SCREEN_TEXTURE, uv);
	
	col.rgb = mix(vec3(0.0), col.rgb, brightness);
	col.rgb = mix(vec3(0.5), col.rgb, contrast);
	col.rgb = mix(vec3(dot(vec3(1.0), col.rgb) * 0.33333), col.rgb, saturation);

	const float noise_speed = 1.0;
	vec3 noise = texture(noise_texture, uv + rand((uv + TIME) * noise_speed)).rgb - vec3(0.5);
	col.rgb = mix(col.rgb, col.rgb + noise, noise_strength);
	
	if (vignette_strength> 0.) {
		float noise_vignette = texture(noise_texture, uv).r - 0.5;
    	float vig = vignette_fac(uv);
		col.rgb = mix(col.rgb, vec3(0), vignette_fac(uv));
	}
	
	if (static_noise_strength > 0.) {
		vec3 noise_static = texture(noise_texture, uv + 0.1).rgb - 0.5;
		col.rgb = mix(col.rgb, col.rgb + noise_static, static_noise_strength);	
	}
	
	COLOR = col;
}
