shader_type canvas_item;

group_uniforms Fisheye;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_nearest, repeat_enable;

uniform float effect = -1.0;
uniform float effect_scale = 1.0;
uniform float crop = 1.0;

uniform float warp_amount = 1.0;

uniform float border_alpha = 1.0;

group_uniforms Chromatic_Abberation;

uniform float ca_amount = 1.0;
uniform float vignette_intensity = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_rgb: source_color = vec4(0.0, 0.0, 0.0, 1.0);

float vignette(vec2 uv){
	uv *= 1.0 - uv.xy;
	float vignette = uv.x * uv.y * 15.0;
	return pow(vignette, vignette_intensity * vignette_opacity);
}

vec2 distort(vec2 uv) {
    //float d = length(uv);
    //float z = sqrt(1.5 + d * d * effect);
    //float r = atan(d, z) / PI;
    //r *= effect_scale;
    //float phi = atan(uv.y, uv.x);
    //return vec2(r * cos(phi) + 0.5, r * sin(phi) + 0.5);
    
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
    if (uv.y > 1.0) { uv.y = 2.0 - uv.y; }
    if (uv.x < 0.0) { uv.x = 1.0 - uv.x; }
    if (uv.y < 0.0) { uv.y = 1.0 - uv.y; }
    return uv;
}

void fragment() {
    //vec2 uv = SCREEN_UV * 2.0;
    //uv.x = uv.x - 1.0;
    //uv.y = uv.y - 1.0;

    vec2 uv = distort(SCREEN_UV);
    vec2 uv_r = uv + abs(uv.x) * vec2(ca_amount / 100.0, 0.0);
    vec2 uv_g = uv;
    vec2 uv_b = uv - abs(uv.x) * vec2(ca_amount / 100.0, 0.0);
    
    COLOR.r = texture(SCREEN_TEXTURE, mirror(uv_r)).r;
    COLOR.g = texture(SCREEN_TEXTURE, mirror(uv_g)).g;
    COLOR.b = texture(SCREEN_TEXTURE, mirror(uv_b)).b;
    
    COLOR.rgb *= clamp(border(uv) + border_alpha, 0.0, 1.0);
	
	COLOR.rgb *= vignette_rgb.rgb * (vignette(uv));

}