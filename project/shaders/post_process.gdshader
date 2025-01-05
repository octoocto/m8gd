shader_type canvas_item;

group_uniforms Fisheye;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap, repeat_enable, source_color;

uniform float effect = -1.0;
uniform float effect_scale = 1.0;
uniform float crop = 1.0;

uniform float warp_amount = 1.0;
uniform float warp_aspect = 1.0;

uniform float border_alpha = 1.0;

group_uniforms Chromatic_Abberation;

uniform float ca_amount = 1.0;


uniform float mirror_blur = 1.0;
uniform float reflection_amount = 0.5;
uniform vec4 mirror_overlay: source_color = vec4(1.0, 1.0, 1.0, 0.05);

uniform vec3 border_color: source_color = vec3(0.1);
uniform float border_shadow_range = 5.0;
uniform float border_shadow_ramp = 0.5;

uniform float vignette_ramp = 1.0;
uniform float vignette_range = 0.9;

//float vignette(vec2 uv){
	//vec2 delta = uv - 0.5;
	//float delta2 = dot(delta.xy, delta.xy);
	//float delta4 = pow(delta2, vignette_intensity);
	//return clamp(1.0 - delta4, 0.0, 1.0);
//}

vec2 distort(vec2 uv) {
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta.xy, delta.xy);
	float delta4 = delta2 * delta2;
	float delta_offset = delta4 * warp_amount;

	return uv + delta * delta_offset;
}

// Adds a black border to hide stretched pixel created by the warp effect
float border (vec2 uv){
	float radius = 0.00;
	radius = max(min(min(abs(radius * 2.0), abs(1.0)), abs(1.0)), 1e-5);
	vec2 abs_uv = abs(uv * 2.0 - 1.0) - vec2(1.0, 1.0) + radius;
	float dist = length(max(vec2(0.0), abs_uv)) / radius;
	float square = smoothstep(0.96, 1.0, dist);
	return clamp(1.0 - square, 0.0, 1.0);
}

vec2 mirror(vec2 uv) {
	if (uv.x > 1.0) { uv.x = 2.0 - uv.x; }
	else if (uv.x < 0.0) { uv.x = 1.0 - uv.x; }
	if (uv.y > 1.0) { uv.y = 2.0 - uv.y; }
	else if (uv.y < 0.0) { uv.y = 1.0 - uv.y; }
	return uv;
}

float mirror_lod(vec2 uv) {
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) { return 0.0; }
	else { return mirror_blur; }
}

bool is_in_mirror(vec2 uv) {
	return !(uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0);
}

void fragment() {
	//vec2 uv = SCREEN_UV * 2.0;
	//uv.x = uv.x - 1.0;
	//uv.y = uv.y - 1.0;

	vec2 uv = distort(SCREEN_UV);
	vec2 uv_r = uv + abs(uv.x) * vec2(ca_amount / 100.0, 0.0);
	vec2 uv_g = uv;
	vec2 uv_b = uv - abs(uv.x) * vec2(ca_amount / 100.0, 0.0);

	COLOR.r = textureLod(SCREEN_TEXTURE, mirror(uv_r), mirror_lod(uv_r)).r;
	COLOR.g = textureLod(SCREEN_TEXTURE, mirror(uv_g), mirror_lod(uv_g)).g;
	COLOR.b = textureLod(SCREEN_TEXTURE, mirror(uv_b), mirror_lod(uv_b)).b;




	vec2 mirror_uv = mirror(uv);
	float border_depth = clamp(max(abs(0.5 - uv.x), abs(0.5 - uv.y)), 0, 1) * 2.0;
	float screen_depth = clamp(max(abs(0.5 - mirror_uv.x), abs(0.5 - mirror_uv.y)), 0, 1) * 2.0;
	float border_shadow = clamp(pow((border_depth - 1.000) * border_shadow_range, border_shadow_ramp), 0, 1) + 0.1;

	float screen_vignette = 1.0 - clamp(abs(border_depth - 1.95) * vignette_range, 0.0, 1.0);


	if (is_in_mirror(uv)) {
		COLOR.rgb *= reflection_amount * border_shadow;
		COLOR.rgb *= mirror_overlay.rgb;
	} else {
		COLOR.rgb *= 1.0 - vec3(pow(screen_vignette, vignette_ramp));
	}

	if (border_depth > 1.0) {
		COLOR.rgb += border_color * border_shadow;
		COLOR.rgb = clamp(COLOR.rgb, vec3(0), vec3(1));
	}


	//COLOR.rgb = texture(SCREEN_TEXTURE, uv).rgb;
	//COLOR.rgb *= clamp(border(uv) + border_alpha, 0.0, 1.0);

	//COLOR.rgb *= vignette(uv) * vignette_opacity;

}