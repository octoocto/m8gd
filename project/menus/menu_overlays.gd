@tool
extends MenuBase

func _menu_init() -> void:
	%Setting_OverlayScale.setting_connect_profile("overlay_scale", func(value: int) -> void:
		main.overlay_integer_zoom = value
	)

	%Setting_OverlayFilters.setting_connect_profile("overlay_apply_filters", func(value: bool) -> void:
		main.get_node("%OverlayContainer").z_index = 0 if value else 1
	)

	%Setting_OverlaySpectrum.setting_connect_overlay(main.overlay_spectrum, "visible")
	%Setting_OverlayWaveform.setting_connect_overlay(main.overlay_waveform, "visible")
	%Setting_OverlayDisplay.setting_connect_overlay(main.overlay_display, "visible")
	%Setting_OverlayKeys.setting_connect_overlay(main.overlay_keys, "visible")

	%Setting_OverlaySpectrum.setting_add_child_readonly(%Button_OverlaySpectrumConfig)
	%Setting_OverlayWaveform.setting_add_child_readonly(%Button_OverlayWaveformConfig)
	%Setting_OverlayDisplay.setting_add_child_readonly(%Button_OverlayDisplayConfig)
	%Setting_OverlayKeys.setting_add_child_readonly(%Button_OverlayKeysConfig)

	main.overlay_waveform.visibility_changed.connect(func() -> void:
		%Setting_OverlayWaveform.value = main.overlay_waveform.visible
	)
	main.overlay_spectrum.visibility_changed.connect(func() -> void:
		%Setting_OverlaySpectrum.value = main.overlay_spectrum.visible
	)
	main.overlay_display.visibility_changed.connect(func() -> void:
		%Setting_OverlayDisplay.value = main.overlay_display.visible
	)
	main.overlay_keys.visibility_changed.connect(func() -> void:
		%Setting_OverlayKeys.value = main.overlay_keys.visible
	)

	Events.profile_loaded.connect(func(_profile_name: String) -> void:
		%Setting_OverlayScale.reinit()
		%Setting_OverlayFilters.reinit()
		%Setting_OverlaySpectrum.reinit()
		%Setting_OverlayWaveform.reinit()
		%Setting_OverlayDisplay.reinit()
		%Setting_OverlayKeys.reinit()
	)

	%Button_OverlaySpectrumConfig.pressed.connect(func() -> void:
		visible = false
		main.menu_overlay.menu_show_for(main.overlay_spectrum)
	)
	%Button_OverlayWaveformConfig.pressed.connect(func() -> void:
		visible = false
		main.menu_overlay.menu_show_for(main.overlay_waveform)
	)
	%Button_OverlayDisplayConfig.pressed.connect(func() -> void:
		visible = false
		main.menu_overlay.menu_show_for(main.overlay_display)
	)
	%Button_OverlayKeysConfig.pressed.connect(func() -> void:
		visible = false
		main.menu_overlay.menu_open(main.overlay_keys)
	)
