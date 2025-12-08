@tool
extends MenuBase

const ICON_LOAD := preload("res://assets/icon/Load.png")

func _menu_init() -> void:
	_init_menu_scene()
	_init_menu_camera()
	_init_menu_model()


func _init_menu_scene() -> void:
	var _setup_as_button := func() -> void:
		# ensure this function gets called after _setup_as_list
		await get_tree().process_frame
		%Option_LoadScene.clear()
		%Option_LoadScene.add_item("Change Scene...")
		%Option_LoadScene.set_item_icon(0, ICON_LOAD)

	var _setup_as_list := func() -> void:
		%Option_LoadScene.clear()

		for scene_path: String in main.get_scene_paths():
			var idx: int = %Option_LoadScene.item_count
			var scene_name := main.get_scene_name(scene_path)
			%Option_LoadScene.add_item(scene_name, idx)
			%Option_LoadScene.set_item_metadata(idx, scene_path)

		%Option_LoadScene.select(-1)

	%Option_LoadScene.pressed.connect(_setup_as_list)
	%Option_LoadScene.get_popup().popup_hide.connect(_setup_as_button)
	%Option_LoadScene.item_selected.connect(func(idx: int) -> void:
		if idx != -1:
			main.load_scene(%Option_LoadScene.get_item_metadata(idx))
		_setup_as_button.call()
	)
	_setup_as_button.call()

	%Button_OpenSceneMenu.pressed.connect(func() -> void:
		hide()
		main.menu_scene.menu_show()
	)

	Events.scene_loaded.connect(func(scene_path: String, _scene: M8Scene) -> void:
		var scene_name := main.get_scene_name(scene_path)
		%Label_CurrentScene.text = "%s" % scene_name
	)

func _init_menu_camera() -> void:
	%Button_SceneCameraMenu.pressed.connect(func() -> void:
		hide()
		main.menu_camera.menu_show()
	)

	%Setting_MouseCamera.setting_connect_camera("mouse_controlled_pan_zoom", func(value: bool) -> void:
		main.current_scene.get_3d_camera().mouse_controlled_pan_zoom = value
		if !value: main.current_scene.get_3d_camera().reset_transform()
	)

	%Setting_HumanCamera.setting_connect_camera("humanized_movement", func(value: bool) -> void:
		main.current_scene.get_3d_camera().humanized_movement = value
	)
	%Setting_HumanCameraStrength.setting_connect_camera("humanize_amount")
	%Setting_HumanCameraFrequency.setting_connect_camera("humanize_freq")

	Events.scene_loaded.connect(func(_scene_path: String, scene: M8Scene) -> void:
		if !scene.has_3d_camera():
			%Button_SceneCameraMenu.disabled = true
			%Setting_MouseCamera.enabled = false
			%Setting_HumanCamera.enabled = false
			return

		%Button_SceneCameraMenu.disabled = false
		%Setting_MouseCamera.enabled = true
		%Setting_HumanCamera.enabled = true

		%Setting_MouseCamera.reinit()
		%Setting_HumanCamera.reinit()
		%Setting_HumanCameraStrength.reinit()
		%Setting_HumanCameraFrequency.reinit()
	)

func _init_menu_model() -> void:
	for arr: Array in [
		[%Setting_ModelColorUp, "Up", "model_color_key_up"],
		[%Setting_ModelColorDown, "Down", "model_color_key_down"],
		[%Setting_ModelColorLeft, "Left", "model_color_key_left"],
		[%Setting_ModelColorRight, "Right", "model_color_key_right"],
		[%Setting_ModelColorOption, "Option", "model_color_key_option"],
		[%Setting_ModelColorEdit, "Edit", "model_color_key_edit"],
		[%Setting_ModelColorShift, "Shift", "model_color_key_shift"],
		[%Setting_ModelColorPlay, "Play", "model_color_key_play"],
	]:
		var setting: SettingBase = arr[0]
		var node_path: String = arr[1]
		var config_property: String = arr[2]

		setting.setting_connect_profile(config_property, func(value: Color) -> void:
			if _model(): _model().set_key_cap_color(node_path, value)
		)

	%Setting_ModelColorBody.setting_connect_profile("model_color_body", func(value: Color) -> void:
		if _model(): _model().set_part_color("Body", value)
	)

	# highlight color for directional buttons (can only edit together)
	var color_settings_highlights: Array[SettingBase] = [
		%Setting_ModelColorHLUp,
		%Setting_ModelColorHLDown,
		%Setting_ModelColorHLLeft,
		%Setting_ModelColorHLRight,
	]

	for setting in color_settings_highlights:
		setting.setting_connect_profile("hl_color_directional", func(value: Color) -> void:
			for s in color_settings_highlights: s.set_value_no_signal(value)
			if _model(): _model().set_dir_key_highlight_color(value)
			main.overlay_keys.color_directional = value
		)

	# highlight color for other buttons
	for arr: Array in [
		[%Setting_ModelColorHLOption, "Option", "color_option", "hl_color_option"],
		[%Setting_ModelColorHLEdit, "Edit", "color_edit", "hl_color_edit"],
		[%Setting_ModelColorHLShift, "Shift", "color_shift", "hl_color_shift"],
		[%Setting_ModelColorHLPlay, "Play", "color_play", "hl_color_play"],
	]:
		var setting: SettingBase = arr[0]
		var key_name: String = arr[1]
		var overlay_prop: String = arr[2]
		var config_property: String = arr[3]

		setting.setting_connect_profile(config_property, func(value: Color) -> void:
				if _model(): _model().set_key_highlight_color(key_name, value)
				main.overlay_keys.set(overlay_prop, value)
		)

	# sync color swatches between all color pickers

	var color_settings: Array[SettingColor] = [
		%Setting_ModelColorHLUp, %Setting_ModelColorHLDown,
		%Setting_ModelColorHLLeft, %Setting_ModelColorHLRight,
		%Setting_ModelColorHLOption, %Setting_ModelColorHLEdit,
		%Setting_ModelColorHLShift, %Setting_ModelColorHLPlay,
		%Setting_ModelColorUp, %Setting_ModelColorDown,
		%Setting_ModelColorLeft, %Setting_ModelColorRight,
		%Setting_ModelColorOption, %Setting_ModelColorEdit,
		%Setting_ModelColorShift, %Setting_ModelColorPlay,
		%Setting_ModelColorBody
	]

	for setting in color_settings:
		setting.get_color_picker().preset_added.connect(func(color: Color) -> void:
			for s in color_settings:
				s.get_color_picker().add_preset(color)
		)
		setting.get_color_picker().preset_removed.connect(func(color: Color) -> void:
			for s in color_settings:
				s.get_color_picker().erase_preset(color)
		)

	Events.profile_loaded.connect(func(_profile_name: String) -> void:
		for setting in color_settings: setting.reinit()
	)

	# Model settings

	%Setting_ModelType.setting_connect_profile("model_type", func(value: int) -> void:
		if not _model(): return
		_model().model_auto = value == 0
		if value == 1: _model().model = 0
		elif value == 2: _model().model = 1
	)
	%Setting_ModelHighlightOpacity.setting_connect_profile("model_hl_opacity", func(value: float) -> void:
		if _model(): _model().highlight_opacity = value
	)
	%Setting_ModelScreenFilter.setting_connect_profile("model_screen_linear_filter", func(value: bool) -> void:
		if _model(): _model().set_screen_filter(value)
	)
	%Setting_ModelScreenEmission.setting_connect_profile("model_screen_emission", func(value: float) -> void:
		if _model(): _model().set_screen_emission(value)
	)

	Events.scene_loaded.connect(func(_scene_path: String, scene: M8Scene) -> void:
		var enabled := scene.has_3d_camera()

		for setting in color_settings:
			setting.enabled = enabled
			%Setting_ModelType.enabled = enabled
			%Setting_ModelHighlightOpacity.enabled = enabled
			%Setting_ModelScreenFilter.enabled = enabled
			%Setting_ModelScreenEmission.enabled = enabled

		if enabled:
			%Setting_ModelType.reinit()
			%Setting_ModelHighlightOpacity.reinit()
			%Setting_ModelScreenFilter.reinit()
			%Setting_ModelScreenEmission.reinit()
	)

##
## Try to return the device model in the current scene.
## If there isn't one, returns null.
##
func _model() -> DeviceModel:
	return main.get_scene_m8_model()

