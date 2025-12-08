@tool
extends MenuBase

func _menu_init() -> void:
	%Setting_ShaderVHS.setting_connect_profile("shader_vhs", func(value: bool) -> void:
		main.get_node("%VHSShader1").visible = value
		main.get_node("%VHSShader2").visible = value
	)
	%Setting_ShaderCRT.setting_connect_profile("shader_crt", func(value: bool) -> void:
		main.get_node("%CRTShader1").visible = value and %Setting_ShaderCRTScanLines.value
		main.get_node("%CRTShader2").visible = value and %Setting_ShaderCRTReverseCurvature.value
		main.get_node("%CRTShader3").visible = value
	)
	%Setting_ShaderNoise.setting_connect_profile("shader_noise", func(value: bool) -> void:
		main.get_node("%NoiseShader").visible = value
	)

	%Setting_ShaderVHSSmear.init_config_shader("%VHSShader1", "smear")
	%Setting_ShaderVHSWiggle.init_config_shader("%VHSShader1", "wiggle")
	%Setting_ShaderVHSNoise.init_config_shader("%VHSShader2", "crease_opacity")
	%Setting_ShaderVHSTape.init_config_shader("%VHSShader2", "tape_crease_smear")

	%Setting_ShaderCRTScanLines.setting_connect_profile("shader_crt_scan_lines", func(value: bool) -> void:
		main.get_node("%CRTShader1").visible = value and %Setting_ShaderCRT.value
	)
	%Setting_ShaderCRTReverseCurvature.setting_connect_profile("shader_crt_reverse_curvature", func(value: bool) -> void:
		main.get_node("%CRTShader2").visible = value and %Setting_ShaderCRT.value
	)
	%Setting_ShaderCRTCurvature.init_config_shader("%CRTShader3", "warp_amount")
	%Setting_ShaderCRTVignette.init_config_shader("%CRTShader3", "vignette_opacity")

	%Setting_ShaderCRTAudioB.setting_connect_global("audio_to_brightness", func(value: float) -> void:
		main.visualizer_brightness_amount = value
	)
	%Setting_ShaderCRTAudioCA.setting_connect_global("audio_to_aberration", func(value: float) -> void:
		main.visualizer_aberration_amount = value
	)
	
	%Setting_ShaderNoiseStrength.init_config_shader("%NoiseShader", "noise_strength")

	%Setting_ShaderVHS.setting_add_child_readonly(%Setting_ShaderVHSSmear)
	%Setting_ShaderVHS.setting_add_child_readonly(%Setting_ShaderVHSWiggle)
	%Setting_ShaderVHS.setting_add_child_readonly(%Setting_ShaderVHSNoise)
	%Setting_ShaderVHS.setting_add_child_readonly(%Setting_ShaderVHSTape)

	%Setting_ShaderCRT.setting_add_child_readonly(%Setting_ShaderCRTScanLines)
	%Setting_ShaderCRT.setting_add_child_readonly(%Setting_ShaderCRTReverseCurvature)
	%Setting_ShaderCRT.setting_add_child_readonly(%Setting_ShaderCRTCurvature)
	%Setting_ShaderCRT.setting_add_child_readonly(%Setting_ShaderCRTVignette)
	%Setting_ShaderCRT.setting_add_child_readonly(%Setting_ShaderCRTAudioB)
	%Setting_ShaderCRT.setting_add_child_readonly(%Setting_ShaderCRTAudioCA)

	Events.profile_loaded.connect(func(_profile_name: String) -> void:
		%Setting_ShaderVHS.reinit()
		%Setting_ShaderVHSSmear.reinit()
		%Setting_ShaderVHSWiggle.reinit()
		%Setting_ShaderVHSNoise.reinit()
		%Setting_ShaderVHSTape.reinit()
		%Setting_ShaderCRT.reinit()
		%Setting_ShaderCRTScanLines.reinit()
		%Setting_ShaderCRTReverseCurvature.reinit()
		%Setting_ShaderCRTCurvature.reinit()
		%Setting_ShaderCRTVignette.reinit()
		%Setting_ShaderCRTAudioB.reinit()
		%Setting_ShaderCRTAudioCA.reinit()
		%Setting_ShaderNoise.reinit()
		%Setting_ShaderNoiseStrength.reinit()
	)

