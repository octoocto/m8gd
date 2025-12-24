@tool
extends MenuBase

@onready var option_load_scene: UIOptionButton = %Option_LoadScene
@onready var button_open_scene_config: UIButton = %ButtonOpenSceneConfig
@onready var button_open_camera_config: UIButton = %ButtonOpenCameraConfig
@onready var label_current_scene: UILabel2 = %LabelCurrentScene

@onready var s_model_type: SettingOptions = %Setting_ModelType
@onready var s_model_hl_opacity: SettingNumber = %Setting_ModelHighlightOpacity
@onready var s_model_screen_filter: SettingOptions = %Setting_ModelScreenFilter
@onready var s_model_screen_emission: SettingNumber = %Setting_ModelScreenEmission


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
				main.load_scene(option_load_scene.get_item_metadata(idx) as String)
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


@onready var s_mouse_camera: SettingBool = %Setting_MouseCamera
@onready var s_human_camera: SettingBool = %Setting_HumanCamera
@onready var s_human_camera_strength: SettingNumber = %Setting_HumanCameraStrength
@onready var s_human_camera_frequency: SettingNumber = %Setting_HumanCameraFrequency


func _init_menu_camera() -> void:
	button_open_camera_config.pressed.connect(
		func() -> void:
			main.menu.menu_hide()
			main.menu_camera.menu_show()
	)

	s_mouse_camera.setting_connect_camera(
		"mouse_controlled_pan_zoom",
		func(value: bool) -> void:
			main.current_scene.get_3d_camera().mouse_controlled_pan_zoom = value
			if !value:
				main.current_scene.get_3d_camera().reset_transform()
	)

	s_human_camera.setting_connect_camera(
		"humanized_movement",
		func(value: bool) -> void: main.current_scene.get_3d_camera().humanized_movement = value
	)
	s_human_camera_strength.setting_connect_camera("humanize_amount")
	s_human_camera_strength.enable_if(s_human_camera)
	s_human_camera_frequency.setting_connect_camera("humanize_freq")
	s_human_camera_frequency.enable_if(s_human_camera)

	Events.scene_loaded.connect(
		func(_scene_path: String, scene: M8Scene) -> void:
			if !scene.has_3d_camera():
				button_open_camera_config.enabled = false
				s_mouse_camera.enabled = false
				s_human_camera.enabled = false
				return

			button_open_camera_config.enabled = true
			s_mouse_camera.enabled = true
			s_human_camera.enabled = true

			s_mouse_camera.reload()
			s_human_camera.reload()
			s_human_camera_strength.reload()
			s_human_camera_frequency.reload()
	)


func _init_menu_model() -> void:
	# Model settings

	s_model_type.setting_connect_model(
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
	s_model_hl_opacity.setting_connect_model(
		"model_hl_opacity",
		func(value: float) -> void:
			if _model():
				_model().highlight_opacity = value
	)
	s_model_screen_filter.setting_connect_model(
		"model_screen_linear_filter",
		func(value: int) -> void:
			if _model():
				_model().set_screen_filter(true if value == 1 else false)
	)
	s_model_screen_emission.setting_connect_model(
		"model_screen_emission",
		func(value: float) -> void:
			if _model():
				_model().set_screen_emission(value)
	)

	Events.preset_loaded.connect(
		func(_profile_name: String) -> void:
			s_model_type.reload()
			s_model_hl_opacity.reload()
			s_model_screen_filter.reload()
			s_model_screen_emission.reload()
	)

	Events.scene_loaded.connect(
		func(_scene_path: String, scene: M8Scene) -> void:
			var is_3d_scene := scene.has_3d_camera()

			s_model_type.enabled = is_3d_scene
			s_model_hl_opacity.enabled = is_3d_scene
			s_model_screen_filter.enabled = is_3d_scene
			s_model_screen_emission.enabled = is_3d_scene
	)


##
## Try to return the device model in the current scene.
## If there isn't one, returns null.
##
func _model() -> DeviceModel:
	return main.get_scene_m8_model()
