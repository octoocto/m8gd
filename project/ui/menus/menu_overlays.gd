@tool
extends MenuBase

@onready var s_scale: SettingBase = %Setting_OverlayScale
@onready var s_apply_filters: SettingBase = %Setting_OverlayFilters

@onready var s_spectrum_enable: SettingBase = %Setting_OverlaySpectrum
@onready var s_waveform_enable: SettingBase = %Setting_OverlayWaveform
@onready var s_display_enable: SettingBase = %Setting_OverlayDisplay
@onready var s_keys_enable: SettingBase = %Setting_OverlayKeys

@onready var btn_spectrum_config: Button = %Button_OverlaySpectrumConfig
@onready var btn_waveform_config: Button = %Button_OverlayWaveformConfig
@onready var btn_display_config: Button = %Button_OverlayDisplayConfig
@onready var btn_keys_config: Button = %Button_OverlayKeysConfig

func _menu_init() -> void:
	s_scale.setting_connect_profile("overlay_scale", func(value: int) -> void:
		main.overlay_integer_zoom = value
	)

	s_apply_filters.setting_connect_profile("overlay_apply_filters", func(value: bool) -> void:
		main.get_node("%OverlayContainer").z_index = 0 if value else 1
	)

	s_spectrum_enable.setting_connect_overlay(main.overlay_spectrum, "visible")
	s_waveform_enable.setting_connect_overlay(main.overlay_waveform, "visible")
	s_display_enable.setting_connect_overlay(main.overlay_display, "visible")
	s_keys_enable.setting_connect_overlay(main.overlay_keys, "visible")

	s_spectrum_enable.setting_add_child_readonly(btn_spectrum_config)
	s_waveform_enable.setting_add_child_readonly(btn_waveform_config)
	s_display_enable.setting_add_child_readonly(btn_display_config)
	s_keys_enable.setting_add_child_readonly(btn_keys_config)

	main.overlay_waveform.visibility_changed.connect(func() -> void:
		s_waveform_enable.value = main.overlay_waveform.visible
	)
	main.overlay_spectrum.visibility_changed.connect(func() -> void:
		s_spectrum_enable.value = main.overlay_spectrum.visible
	)
	main.overlay_display.visibility_changed.connect(func() -> void:
		s_display_enable.value = main.overlay_display.visible
	)
	main.overlay_keys.visibility_changed.connect(func() -> void:
		s_keys_enable.value = main.overlay_keys.visible
	)

	Events.profile_loaded.connect(func(_profile_name: String) -> void:
		s_scale.reinit()
		s_apply_filters.reinit()
		s_spectrum_enable.reinit()
		s_waveform_enable.reinit()
		s_display_enable.reinit()
		s_keys_enable.reinit()
	)

	btn_spectrum_config.pressed.connect(func() -> void:
		main.menu.menu_hide()
		main.menu_overlay.menu_show_for(main.overlay_spectrum)
	)
	btn_waveform_config.pressed.connect(func() -> void:
		main.menu.menu_hide()
		main.menu_overlay.menu_show_for(main.overlay_waveform)
	)
	btn_display_config.pressed.connect(func() -> void:
		main.menu.menu_hide()
		main.menu_overlay.menu_show_for(main.overlay_display)
	)
	btn_keys_config.pressed.connect(func() -> void:
		main.menu.menu_hide()
		main.menu_overlay.menu_open(main.overlay_keys)
	)
