shader_type spatial;
//render_mode unshaded;
//render_mode depth_draw_always;
//render_mode depth_draw_always;
render_mode diffuse_lambert_wrap;

uniform sampler2D color_ramp: hint_default_white, source_color, repeat_disable;
uniform sampler2D wind_noise: hint_default_white, repeat_enable;
uniform float uv_offset = 0;
uniform vec2 heightmap_offset = vec2(0);
uniform float heightmap_strength = 1.0;
uniform vec2 wind_dir = vec2(1.0, 1.0);
uniform float wind_strength = 4.0;
uniform float wind_speed = 10;

uniform sampler2D heightmap: hint_default_black, repeat_enable;

uniform sampler2D depth_texture: hint_depth_texture, repeat_enable;
uniform float proximity_fade_distance = 0.0;
uniform float distance_fade_min = 0.0;
uniform float distance_fade_max = 0.0;

void vertex() {
    vec2 nwind_dir = normalize(wind_dir);
    vec3 w_vert = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec2 w_uv = (MODEL_MATRIX * vec4(UV, 0.0, 1.0)).xy;
    vec2 uv = (w_vert.xz + nwind_dir * TIME * wind_speed) / 50.0;
    float wind = textureLod(wind_noise, uv, 0.0).r - 0.5;

    float displacement = 0.5 - UV.y;

    vec2 wind_wdir = (MODEL_MATRIX * vec4(wind_dir, 0.0, 0.0)).xy;
    wind_wdir = normalize(wind_wdir);

    vec3 wind_bump = vec3(wind_wdir.x * wind * wind_strength, 1, wind_wdir.y * wind * wind_strength);
    wind_bump = normalize(wind_bump) * vec3(displacement, 0, displacement);

    //VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // fixed-y billboard code
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);

    VERTEX += wind_bump;
    VERTEX.y += -0.5 + (texture(heightmap, (w_vert.xz + heightmap_offset) / 80.0).r * heightmap_strength) * 2.0;
}

void fragment() {
    vec3 w_uv = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    w_uv.y = 0.5 - w_uv.y / 4.0;
	//ALBEDO = texture(color_ramp, vec2(w_uv.y, 0)).rgb + (texture(wind_noise, w_uv.xy * 50.0).rgb - 0.5) * 0.02;

    // proximity fade code
    //float depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
    //vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0-1.0, depth_tex, 1.0);
    //world_pos.xyz /= world_pos.w;
    //ALPHA *= clamp(1.0 - smoothstep(world_pos.z + proximity_fade_distance, world_pos.z, VERTEX.z), 0.0, 1.0);

    // dither distance fade code
    float fade_distance = length(VERTEX);
    const vec3 magic = vec3(0.06711056f, 0.00583715f, 52.9829189f);
    float fade = clamp(smoothstep(distance_fade_min, distance_fade_max, fade_distance), 0.0, 1.0);
    if (fade < 0.001 || fade < fract(magic.z * fract(dot(FRAGCOORD.xy, magic.xy)))) {
        discard;
    }

    ALBEDO = texture(color_ramp, vec2(w_uv.y + uv_offset, 0)).rgb;

	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 1.0;
}
