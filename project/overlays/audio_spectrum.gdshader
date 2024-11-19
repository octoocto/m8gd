shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

uniform bool blend_soft_light = false;


float _blend(float base, float blend) {
	// overlay
	return base<0.5?(2.0*base*blend):(1.0-2.0*(1.0-base)*(1.0-blend));
	
	// soft light
	//return (blend<0.5)?(2.0*base*blend+base*base*(1.0-2.0*blend)):(sqrt(base)*(2.0*blend-1.0)+2.0*base*(1.0-blend));
}

vec3 soft_light(vec3 a, vec3 b) {
	return vec3(_blend(a.r, b.r), _blend(a.g, b.g), _blend(a.b, b.b));
}

void fragment() {
	vec3 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	
	if(blend_soft_light) {
		COLOR.rgb = mix(soft_light(screen_color, COLOR.rgb), COLOR.rgb, COLOR.a);
	}
}

