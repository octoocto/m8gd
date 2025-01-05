shader_type spatial;

uniform float emission_amount = 0.7;

uniform float edge_darken = -0.3;

uniform float edge_burn = 0.0;
uniform float edge_burn_ramp = 10.0;

uniform float brightness = 0.0;

uniform sampler2D texture_linear: source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D texture_nearest: source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform bool backlight = true;
uniform bool use_linear_filter = true;


void fragment() {
	if (use_linear_filter)
	{
		ALBEDO = texture(texture_linear, UV).rgb;
	}
	else
	{
		ALBEDO = texture(texture_nearest, UV).rgb;
	}

	if (backlight)
	{
		ALBEDO = clamp(ALBEDO + brightness, 0.0, 1.0);

		ALBEDO -= pow(abs(UV.x - 0.5), 7) * edge_darken;
		ALBEDO -= pow(abs(UV.y - 0.5), 6) * edge_darken;

		ALBEDO -= pow(abs(UV.x - 0.5) * 2.0, edge_burn_ramp) * edge_burn;
		ALBEDO -= pow(abs(UV.y - 0.5) * 2.0, edge_burn_ramp) * edge_burn;

		EMISSION = ALBEDO * emission_amount;
	}

	METALLIC = 0.3;
}