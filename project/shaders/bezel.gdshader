shader_type canvas_item;

uniform sampler2D tex: hint_screen_texture, filter_linear_mipmap_anisotropic;

uniform sampler2D noise_texture: filter_nearest_mipmap, repeat_enable;

uniform float zoom_amount: hint_range(1.0, 2.0) = 1.0;

uniform float curvature_amount: hint_range(-1.0, 10.0) = 0.5;
uniform int _curvature_type: hint_range(0, 1) = 1;
uniform float curvature_aspect: hint_range(0.001, 10.0) = 0.563;

uniform float border_alpha = 1.0;

uniform float reflection_blur: hint_range(0.0, 8.0, 0.1) = 1.0;
uniform float reflection_amount: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float reflection_contrast: hint_range(0.0, 2.0, 0.1) = 1.0;
uniform float reflection_brightness: hint_range(0.0, 2.0, 0.1) = 1.0;

uniform float reflection_seamless_margin = 0.1;

uniform vec3 bezel_color: source_color = vec3(0.0);
uniform float bezel_lighting_amount: hint_range(0.0, 0.1, 0.01) = 0.02;
uniform float bezel_lighting_angle: hint_range(0.0, 360.0, 1.0) = 0.;
uniform float bezel_noise_amount: hint_range(0.0, 0.1, 0.001) = 0.01;

uniform float border_shadow_range = 5.0;
uniform float border_shadow_ramp = 0.5;

uniform float vignette_ramp = 1.0;
uniform float vignette_intensity = 75.0;
uniform float vignette_opacity = 0.1;

vec2 curve(vec2 uv) {
	if (_curvature_type == 0) {
		vec2 delta = uv - 0.5;
		float delta2 = dot(delta.xy, delta.xy);
		float delta4 = delta2 * delta2;
		float delta_offset = delta4 * curvature_amount;
		return uv + delta * delta_offset;
	}
	else {
		// Barrel/pincushion warp in normalized space, with aspect-correct x
	    uv -= 0.5;
	    uv.x /= curvature_aspect;
	    float warping = dot(uv, uv) * curvature_amount * 0.5;
	    warping -= curvature_amount * 0.25 * 0.5;
	    uv /= (1.0 - warping);
	    uv.x *= curvature_aspect;
	    uv += 0.5;
	    return uv;
	}
}

vec2 zoom(vec2 uv) {
	return uv * zoom_amount - vec2((zoom_amount - 1.0) / 2.0);
}

float vignette(vec2 uv){
    uv *= 1.0 - uv.xy;
    float vignette = uv.x * uv.y * vignette_intensity;
    return min(1.0, pow(vignette, vignette_ramp * vignette_opacity));
}

// Adds a black border to hide stretched pixel created by the warp effect
float border(vec2 uv){
    float radius = min(curvature_amount, 0.02);
    radius = max(min(min(abs(radius * 2.0), abs(1.0)), abs(1.0)), 1e-5);
    vec2 abs_uv = abs(uv * 2.0 - 1.0) - vec2(1.0) + radius;
    float dist = length(max(vec2(0.0), abs_uv)) / radius;
    float square = smoothstep(0.98, 1.0, dist);
    return clamp((1.0 - square), 0.0, 1.0);
}

vec2 mirror(vec2 uv) {
	uv = fract(uv * 0.5) * 2.0;
	uv = 1.0 - abs(uv - 1.0);
	return uv;
}



float mirror_lod(vec2 uv) {
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) { return 0.0; }
	else { return reflection_blur; }
}

bool is_reflection(vec2 uv) {
	return !(uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0);
}

bool is_reflection_top(vec2 uv) {
	return uv.y < 0.0 && uv.y < uv.x && uv.y < (1.0 - uv.x);
}

bool is_reflection_bottom(vec2 uv) {
	return uv.y > 1.0 && uv.y > uv.x && uv.y > (1.0 - uv.x);
}

bool is_reflection_left(vec2 uv) {
	return uv.x < 0.0 && uv.x < uv.y && uv.x < (1.0 - uv.y);
}

bool is_reflection_right(vec2 uv) {
	return uv.x > 1.0 && uv.x > uv.y && uv.x > (1.0 - uv.y);
}
vec4 text(sampler2D t, vec2 uv, float lod) {
	float margin = max(0.0, reflection_blur * 0.004);
	vec4 color = textureLod(t, uv, lod);
	
	//if (uv.x > 1.0 - margin) {
		//color = mix(color, textureLod(t, vec2(1.0 - uv.x, uv.y), lod), abs((1.0 - margin) - uv.x) / margin * 0.5);
	//} else if(uv.x < margin) {
		//color = mix(color, textureLod(t, vec2(-uv.x, uv.y), lod), abs(margin - uv.x) / margin * 0.5);
	//}
	//if (uv.y > 1.0 - margin) {
		//color = mix(color, textureLod(t, vec2(uv.x, 1.0 - uv.y), lod), abs((1.0 - margin) - uv.y) / margin * 0.5);
	//} else if(uv.y < margin) {
		//color = mix(color, textureLod(t, vec2(uv.x, -uv.y), lod), abs(margin - uv.y) / margin * 0.5);
	//}
	
	if (uv.x > 1.0 - margin) {
		uv.x = 1.0 - margin;
	} else if(uv.x < margin) {
		uv.x = margin;
	}
	if (uv.y > 1.0 - margin) {
		uv.y = 1.0 - margin;
	} else if(uv.y < margin) {
		uv.y = margin;
	}
	
	return textureLod(t, uv, lod);

	//if (uv.y > 1.0 - margin) {
		//color = mix(color, textureLod(t, vec2(uv.x, uv.y - 1.0), lod), abs(uv.y - margin));
	//}
	return color;
}

void fragment() {
	//vec2 uv = SCREEN_UV * 2.0;
	//uv.x = uv.x - 1.0;
	//uv.y = uv.y - 1.0;
	vec2 uv = SCREEN_UV;

	//uv = distort(SCREEN_UV);
	uv = curve(zoom(uv));

	//COLOR = textureLod(SCREEN_TEXTURE, mirror(uv), mirror_lod(uv));
	if (is_reflection(uv)) {
		COLOR = text(tex, mirror(uv), reflection_blur);
		COLOR.rgb = mix(vec3(0.0), COLOR.rgb, reflection_brightness);
		COLOR.rgb = mix(vec3(0.5), COLOR.rgb, reflection_contrast);
	}
	else {
		COLOR = textureLod(tex, mirror(uv), 0.0);
	}
	


	vec2 mirror_uv = mirror(uv);
	
	float border_depth = clamp(max(abs(0.5 - uv.x), abs(0.5 - uv.y)), 0, 1) * 2.0;
	//float screen_depth = clamp(max(abs(0.5 - mirror_uv.x), abs(0.5 - mirror_uv.y)), 0, 1) * 2.0;
	float border_shadow = clamp(pow((border_depth - 1.000) * border_shadow_range, border_shadow_ramp), 0, 1);

	//float screen_vignette = 1.0 - clamp(abs(border_depth - 1.95) * vignette_range, 0.0, 1.0);

	if (is_reflection(uv) && border(uv) == 0.0) {
		vec3 reflect_color = COLOR.rgb * reflection_amount;
		COLOR.rgb = 1.0 - (1.0 - reflect_color) * (1.0 - bezel_color);
		COLOR.rgb += (textureLod(noise_texture, uv, 8.0).rgb - 0.5) * bezel_noise_amount;
		COLOR.rgb *= border_shadow;
	} else {
		COLOR.rgb *= vignette(uv);
		//COLOR.rgb *= 1.0 - vec3(pow(screen_vignette, vignette_ramp));
	}
	
	float ang = radians(bezel_lighting_angle);
	
	if (is_reflection_top(uv)) {
		COLOR.rgb += vec3(1.0) * -cos(ang) * bezel_lighting_amount;
	}
	
	if (is_reflection_bottom(uv)) {
		COLOR.rgb += vec3(1.0) * cos(ang) * bezel_lighting_amount;
	}
	
	if (is_reflection_left(uv)) {
		COLOR.rgb += vec3(1.0) * -sin(ang) * bezel_lighting_amount;
	}
	
	if (is_reflection_right(uv)) {
		COLOR.rgb += vec3(1.0) * sin(ang) * bezel_lighting_amount;
	}
	
	COLOR.rgb = clamp(COLOR.rgb, vec3(0), vec3(1));
	
}