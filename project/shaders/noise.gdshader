shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_nearest;

uniform float noise_offset: hint_range(0.0, 1.0) = 0.5;
uniform float noise_strength = 0.015;
uniform float noise_speed = 10.0;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {

    //COLOR = mix(COLOR, vec4(vec3(rand(pixel_uv + rand(vec2(TIME)))), 1.0), 0.03);
    COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);

    float n = fract(abs(rand(UV + rand(vec2(floor(TIME * noise_speed)))))) - noise_offset;
    COLOR = mix(COLOR, COLOR + vec4(vec3(n), 1.0), noise_strength);
}
