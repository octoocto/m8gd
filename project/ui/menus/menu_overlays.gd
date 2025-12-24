@tool
extends MenuBase

@onready var s_scale: SettingBase = %Setting_OverlayScale
@onready var s_apply_filters: SettingBase = %Setting_OverlayFilters

@onready var _grid: GridContainer = %GridContainer


func _on_menu_init() -> void:
	var overlays: OverlayContainer = main.overlays

	s_scale.setting_connect_overlay_global(
		"overlay_scale", func(value: int) -> void: overlays.content_scale = value
	)

	s_apply_filters.setting_connect_overlay_global(
		"overlay_above_shaders", func(value: bool) -> void: overlays.z_index = 1 if value else 0
	)

	for overlay: OverlayBase in overlays.get_overlays():
		var s_enable: SettingBase = MenuUtils.SETTING_BOOL.instantiate()
		var button_open_config: UIButton = MenuUtils.UI_BUTTON.instantiate()

		_grid.add_child(s_enable)
		_grid.add_child(button_open_config)

		s_enable.setting_name = overlay.name.trim_prefix("Overlay").capitalize()
		s_enable.setting_name_min_width = 120
		s_enable.setting_connect_overlay(overlay, "visible")

		button_open_config.text = "Configure..."
		button_open_config.enable_if(s_enable)
		button_open_config.pressed.connect(
			func() -> void:
				main.menu.menu_hide()
				main.menu_overlay.menu_show_for(overlay)
		)

		overlay.visibility_changed.connect(func() -> void: s_enable.value = overlay.visible)

	Log.ln("added %d overlay settings" % overlays.get_overlays().size())

	Events.preset_loaded.connect(
		func(_profile_name: String) -> void:
			s_scale.reload()
			s_apply_filters.reload()
	)
