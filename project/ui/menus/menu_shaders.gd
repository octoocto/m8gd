@tool
extends MenuBase


func _on_menu_init() -> void:
	var shaders: ShaderContainer = main.shaders

	%Setting_ShaderVHS.setting_connect_profile(
		"shader_vhs",
		func(value: bool) -> void:
			shaders.vhs_shader_1.visible = value
			shaders.vhs_shader_2.visible = value
	)
	%Setting_ShaderCRT.setting_connect_profile(
		"shader_crt",
		func(value: bool) -> void:
			shaders.crt_shader_1.visible = value and %Setting_ShaderCRTScanLines.value
			shaders.crt_shader_2.visible = (value and %Setting_ShaderCRTReverseCurvature.value)
			shaders.crt_shader_3.visible = value
	)
	%Setting_ShaderNoise.setting_connect_profile(
		"shader_noise", func(value: bool) -> void: shaders.noise_shader.visible = value
	)

	%Setting_ShaderVHSSmear.init_config_shader("%VHSShader1", "smear")
	%Setting_ShaderVHSWiggle.init_config_shader("%VHSShader1", "wiggle")
	%Setting_ShaderVHSNoise.init_config_shader("%VHSShader2", "crease_opacity")
	%Setting_ShaderVHSTape.init_config_shader("%VHSShader2", "tape_crease_smear")

	%Setting_ShaderCRTScanLines.setting_connect_profile(
		"shader_crt_scan_lines",
		func(value: bool) -> void: shaders.crt_shader_1.visible = value and %Setting_ShaderCRT.value
	)
	%Setting_ShaderCRTReverseCurvature.setting_connect_profile(
		"shader_crt_reverse_curvature",
		func(value: bool) -> void: shaders.crt_shader_2.visible = value and %Setting_ShaderCRT.value
	)
	%Setting_ShaderCRTCurvature.init_config_shader("%CRTShader3", "warp_amount")
	%Setting_ShaderCRTVignette.init_config_shader("%CRTShader3", "vignette_opacity")

	%Setting_ShaderCRTAudioB.setting_connect_global(
		"audio_to_brightness", func(value: float) -> void: main.visualizer_brightness_amount = value
	)
	%Setting_ShaderCRTAudioCA.setting_connect_global(
		"audio_to_aberration", func(value: float) -> void: main.visualizer_aberration_amount = value
	)

	%Setting_ShaderNoiseStrength.init_config_shader("%NoiseShader", "noise_strength")
	%Setting_ShaderNoiseStrength.enable_if(%Setting_ShaderNoise)

	%Setting_ShaderVHSSmear.enable_if(%Setting_ShaderVHS)
	%Setting_ShaderVHSWiggle.enable_if(%Setting_ShaderVHS)
	%Setting_ShaderVHSNoise.enable_if(%Setting_ShaderVHS)
	%Setting_ShaderVHSTape.enable_if(%Setting_ShaderVHS)

	%Setting_ShaderCRTScanLines.enable_if(%Setting_ShaderCRT)
	%Setting_ShaderCRTReverseCurvature.enable_if(%Setting_ShaderCRT)
	%Setting_ShaderCRTCurvature.enable_if(%Setting_ShaderCRT)
	%Setting_ShaderCRTVignette.enable_if(%Setting_ShaderCRT)
	%Setting_ShaderCRTAudioB.enable_if(%Setting_ShaderCRT)
	%Setting_ShaderCRTAudioCA.enable_if(%Setting_ShaderCRT)

	Events.profile_loaded.connect(
		func(_profile_name: String) -> void:
			%Setting_ShaderVHS.reload()
			%Setting_ShaderVHSSmear.reload()
			%Setting_ShaderVHSWiggle.reload()
			%Setting_ShaderVHSNoise.reload()
			%Setting_ShaderVHSTape.reload()
			%Setting_ShaderCRT.reload()
			%Setting_ShaderCRTScanLines.reload()
			%Setting_ShaderCRTReverseCurvature.reload()
			%Setting_ShaderCRTCurvature.reload()
			%Setting_ShaderCRTVignette.reload()
			%Setting_ShaderCRTAudioB.reload()
			%Setting_ShaderCRTAudioCA.reload()
			%Setting_ShaderNoise.reload()
			%Setting_ShaderNoiseStrength.reload()
	)
