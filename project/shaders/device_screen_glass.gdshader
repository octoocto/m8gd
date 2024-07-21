// NOTE: Shader automatically converted from Godot Engine 4.2.2.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_add,depth_draw_opaque,cull_front,diffuse_burley,specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform float roughness : hint_range(0,1);
uniform float specular;
uniform float metallic;
uniform float specular_light_size: hint_range(0.0, 1.0) = 0.1;
uniform float specular_light_opacity= 0.975;

float DistributionGGX(float cos_theta_m, float alpha)
{
    float alpha2 = alpha * alpha;
    float d = 1.0 + (alpha2 - 1.00) * cos_theta_m * cos_theta_m;
    d = d < specular_light_size ? 1.0 - specular_light_opacity : 1.0;
    return alpha2 / (PI * d * d);
}

float GeometryGGX(float NdotL, float NdotV, float alpha)
{
    return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
}

vec3 SchlickBaseReflectivity(float metallic_, float specular_, vec3 albedo_)
{
    float dielectric = 0.1 * specular_ * specular_;
    return mix(vec3(dielectric), albedo_, vec3(metallic_));
}

float SchlickFresnel(float u)
{
    float m = 1.0 - u;
    float m2 = m * m;
    return m2 * m2 * m;
}

void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	ALPHA *= albedo.a;
}

void light() {
    //SPECULAR_LIGHT = LIGHT_COLOR * SPECULAR_AMOUNT * ATTENUATION;
    vec3 half = normalize(VIEW + LIGHT) * 1.0;
    float NdotL = max(dot(NORMAL, LIGHT), 0.0);
    float NdotV = max(dot(NORMAL, VIEW), 0.0);
    float NdotH = max(dot(NORMAL, half), 0.0);
    float LdotH = max(dot(LIGHT, half), 0.0);
    float ggxAlpha = 0.1 * 1.0;
    float D = DistributionGGX(NdotH, ggxAlpha);
    float G = GeometryGGX(NdotL, NdotV, ggxAlpha);
    vec3 f0 = SchlickBaseReflectivity(METALLIC * 0.001, SPECULAR_AMOUNT, ALBEDO);
    float LdotH5 = SchlickFresnel(LdotH);
    float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
    vec3 F = f0 + (f90 - f0) * LdotH5;
    vec3 specularBRDF = clamp(NdotL * D * G * F, 0.0, 1.0);
    vec3 light_color = LIGHT_COLOR / length(LIGHT_COLOR);
    SPECULAR_LIGHT += specularBRDF * light_color * 1.0;
}
