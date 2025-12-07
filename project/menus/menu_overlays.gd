@tool
extends MenuBase

func _menu_init() -> void:
	%Setting_OverlayScale.init_config_profile(main, "overlay_scale", func(value: int) -> void:
		main.overlay_integer_zoom = value
	)

	%Setting_OverlayFilters.init_config_profile(main, "overlay_apply_filters", func(value: bool) -> void:
		main.get_node("%OverlayContainer").z_index = 0 if value else 1
	)

	%Setting_OverlaySpectrum.init_config_overlay(main, main.overlay_spectrum, "visible")
	%Setting_OverlayWaveform.init_config_overlay(main, main.overlay_waveform, "visible")
	%Setting_OverlayDisplay.init_config_overlay(main, main.overlay_display, "visible")
	%Setting_OverlayKeys.init_config_overlay(main, main.overlay_keys, "visible")

	%Setting_OverlaySpectrum.connect_to_enable(%Button_OverlaySpectrumConfig)
	%Setting_OverlayWaveform.connect_to_enable(%Button_OverlayWaveformConfig)
	%Setting_OverlayDisplay.connect_to_enable(%Button_OverlayDisplayConfig)
	%Setting_OverlayKeys.connect_to_enable(%Button_OverlayKeysConfig)

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
		main.menu_overlay.menu_open(main.overlay_spectrum)
	)
	%Button_OverlayWaveformConfig.pressed.connect(func() -> void:
		visible = false
		main.menu_overlay.menu_open(main.overlay_waveform)
	)
	%Button_OverlayDisplayConfig.pressed.connect(func() -> void:
		visible = false
		main.menu_overlay.menu_open(main.overlay_display)
	)
	%Button_OverlayKeysConfig.pressed.connect(func() -> void:
		visible = false
		main.menu_overlay.menu_open(main.overlay_keys)
	)

