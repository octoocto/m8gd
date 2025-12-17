@tool
extends MenuBase

@onready var option_load_scene: UIOptionButton = %Option_LoadScene
@onready var button_open_scene_config: UIButton = %ButtonOpenSceneConfig
@onready var button_open_camera_config: UIButton = %ButtonOpenCameraConfig
@onready var label_current_scene: UILabel2 = %LabelCurrentScene


func _on_menu_init() -> void:
	_init_menu_scene()
	_init_menu_camera()
	_init_menu_model()


func _init_menu_scene() -> void:
	var _setup_as_button := func() -> void:
		# ensure this function gets called after _setup_as_list
		await get_tree().process_frame
		option_load_scene.clear()
		option_load_scene.add_item("Change Scene...")
		option_load_scene.set_item_icon(0, ICON_LOAD)

	var _setup_as_list := func() -> void:
		option_load_scene.clear()

		for scene_path: String in main.get_scene_paths():
			var idx: int = option_load_scene.item_count
			var scene_name := main.get_scene_name(scene_path)
			option_load_scene.add_item(scene_name, idx)
			option_load_scene.set_item_metadata(idx, scene_path)

		option_load_scene.select(-1)

	option_load_scene.pressed.connect(_setup_as_list)
	option_load_scene.get_popup().popup_hide.connect(_setup_as_button)
	option_load_scene.item_selected.connect(
		func(idx: int) -> void:
			if idx != -1:
				main.load_scene(option_load_scene.get_item_metadata(idx))
			_setup_as_button.call()
	)
	_setup_as_button.call()

	button_open_scene_config.pressed.connect(
		func() -> void:
			main.menu.menu_hide()
			main.menu_scene.menu_show()
	)

	Events.scene_loaded.connect(
		func(scene_path: String, _scene: M8Scene) -> void:
			var scene_name := main.get_scene_name(scene_path)
			label_current_scene.text = "%s" % scene_name
	)


func _init_menu_camera() -> void:
	button_open_camera_config.pressed.connect(
		func() -> void:
			main.menu.menu_hide()
			main.menu_camera.menu_show()
	)

	%Setting_MouseCamera.setting_connect_camera(
		"mouse_controlled_pan_zoom",
		func(value: bool) -> void:
			main.current_scene.get_3d_camera().mouse_controlled_pan_zoom = value
			if !value:
				main.current_scene.get_3d_camera().reset_transform()
	)

	%Setting_HumanCamera.setting_connect_camera(
		"humanized_movement",
		func(value: bool) -> void: main.current_scene.get_3d_camera().humanized_movement = value
	)
	%Setting_HumanCameraStrength.setting_connect_camera("humanize_amount")
	%Setting_HumanCameraStrength.enable_if(%Setting_HumanCamera)
	%Setting_HumanCameraFrequency.setting_connect_camera("humanize_freq")
	%Setting_HumanCameraFrequency.enable_if(%Setting_HumanCamera)

	Events.scene_loaded.connect(
		func(_scene_path: String, scene: M8Scene) -> void:
			if !scene.has_3d_camera():
				button_open_camera_config.enabled = false
				%Setting_MouseCamera.enabled = false
				%Setting_HumanCamera.enabled = false
				return

			button_open_camera_config.enabled = true
			%Setting_MouseCamera.enabled = true
			%Setting_HumanCamera.enabled = true

			%Setting_MouseCamera.reinit()
			%Setting_HumanCamera.reinit()
			%Setting_HumanCameraStrength.reinit()
			%Setting_HumanCameraFrequency.reinit()
	)


func _init_menu_model() -> void:
	# Model settings

	%Setting_ModelType.setting_connect_profile(
		"model_type",
		func(value: int) -> void:
			if not _model():
				return
			_model().model_auto = value == 0
			if value == 1:
				_model().model = 0
			elif value == 2:
				_model().model = 1
	)
	%Setting_ModelHighlightOpacity.setting_connect_profile(
		"model_hl_opacity",
		func(value: float) -> void:
			if _model():
				_model().highlight_opacity = value
	)
	%Setting_ModelScreenFilter.setting_connect_profile(
		"model_screen_linear_filter",
		func(value: int) -> void:
			if _model():
				_model().set_screen_filter(true if value == 1 else false)
	)
	%Setting_ModelScreenEmission.setting_connect_profile(
		"model_screen_emission",
		func(value: float) -> void:
			if _model():
				_model().set_screen_emission(value)
	)

	Events.scene_loaded.connect(
		func(_scene_path: String, scene: M8Scene) -> void:
			var enabled := scene.has_3d_camera()

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
