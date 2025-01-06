class_name MainMenu extends Panel

const REBIND_COOLDOWN := 100 # ms until can rebind again

const ICON_LOAD := preload("res://assets/icon/Load.png")

@onready var button_exit: Button = %ButtonExit

@onready var main: Main

var is_key_rebinding := false
var last_rebind_time := 0.0
var key_rebind_callback: Callable

func init(p_main: Main) -> void:

	main = p_main

	button_exit.pressed.connect(func() -> void:
		main.quit()
	)

	%ButtonClose.pressed.connect(func() -> void:
		visible = false
	)

	%DisplayRect.texture = main.m8_client.get_display()

	_init_menu_profiles()
	_init_menu_scene()
	_init_menu_camera()
	_init_menu_overlays()
	_init_menu_filters()
	_init_menu_model()
	_init_menu_devices()
	_init_menu_input()
	_init_menu_video()
	_init_menu_audio()
	_init_menu_debug()

##
## Setup the profile menu controls.
##
func _init_menu_profiles() -> void:

	var _setup_as_button := func() -> void:
		# ensure this function gets called after _setup_as_list
		await get_tree().process_frame
		%OptionProfiles.clear()
		%OptionProfiles.add_item("Load profile...")
		%OptionProfiles.set_item_icon(0, ICON_LOAD)

	var _setup_as_list := func() -> void:
		%OptionProfiles.clear()
		%OptionProfiles.add_item("<default>")

		for profile_name: String in main.list_profile_names():
			%OptionProfiles.add_item(profile_name)

		%OptionProfiles.select(-1)

	var _update_ui := func() -> void:
		if main.is_using_default_profile():
			%LineEditProfileName.text = "<default>"
			%LineEditProfileName.editable = false
			%LineEditProfileName.select_all_on_focus = false
			%ButtonProfileDelete.disabled = true
		else:
			%LineEditProfileName.text = main.get_current_profile_name()
			%LineEditProfileName.editable = true
			%LineEditProfileName.select_all_on_focus = true
			%ButtonProfileDelete.disabled = false
		_setup_as_button.call()
		refresh_profile_hotkeys()

	var _load_profile := func(profile_name: String) -> void:
		if main.load_profile(profile_name):
			_update_ui.call()

	var _load_default_profile := func() -> void:
		main.load_default_profile()
		_update_ui.call()

	main.profile_loaded.connect(func(_profile_name: String) -> void:
		_update_ui.call()
	)

	_update_ui.call()

	%OptionProfiles.pressed.connect(_setup_as_list)
	%OptionProfiles.get_popup().popup_hide.connect(_setup_as_button)
	%OptionProfiles.item_selected.connect(func(index: int) -> void:
		if index == 0:
			_load_default_profile.call()
		elif index > 0:
			_load_profile.call(%OptionProfiles.get_item_text(index))

		_setup_as_button.call()
	)

	%LineEditProfileName.text_submitted.connect(func(new_text: String) -> void:
		main.rename_profile(new_text)
		%LineEditProfileName.release_focus()
	)

	%LineEditProfileName.focus_exited.connect(_update_ui)

	%ButtonProfileCreate.pressed.connect(func() -> void:
		_load_profile.call(main.create_new_profile())
	)

	%ButtonProfileReset.pressed.connect(func() -> void:
		main.reset_scene_to_default()
	)

	%ButtonProfileDelete.pressed.connect(func() -> void:
		main.delete_profile(main.get_current_profile_name())
		_update_ui.call()
	)

##
## Setup the scene menu controls.
##
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
		visible = false
		main.menu_scene.visible = true
	)

	main.scene_loaded.connect(func(scene_path: String, _scene: M8Scene) -> void:
		var scene_name := main.get_scene_name(scene_path)
		%Label_CurrentScene.text = "%s" % scene_name
	)


##
## Setup the overlay menu controls.
##
func _init_menu_overlays() -> void:

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

	main.profile_loaded.connect(func(_profile_name: String) -> void:
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

##
## Setup the camera menu controls.
##
func _init_menu_camera() -> void:

	%Button_SceneCameraMenu.pressed.connect(func() -> void:
		visible = false
		main.menu_camera.menu_open()
	)

	%Setting_MouseCamera.init_config_camera(main, "mouse_controlled_pan_zoom", func(value: bool) -> void:
		main.current_scene.get_3d_camera().mouse_controlled_pan_zoom = value
		if !value: main.current_scene.get_3d_camera().set_transform_to_base()
	)

	%Setting_HumanCamera.init_config_camera(main, "humanized_movement", func(value: bool) -> void:
		main.current_scene.get_3d_camera().humanized_movement = value
	)

	main.scene_loaded.connect(func(_scene_path: String, scene: M8Scene) -> void:
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
	)

##
## Setup the audio menu controls.
##
func _init_menu_audio() -> void:

	# volume

	%Setting_Volume.init_config_global(main, "volume", func(value: float) -> void:
		var volume_db: float = linear_to_db(pow(value, 2))
		main.audio_set_volume(volume_db)
	)

	# audio driver (readonly)

	%LineEditAudioDriver.placeholder_text = ProjectSettings.get_setting("audio/driver/driver")

	# audio mix rate (readonly)

	%LineEditAudioRate.placeholder_text = "%d Hz" % AudioServer.get_mix_rate()
	# %LineEditAudioRate.text_submitted.connect(func(text):
	# 	if text.is_valid_int():
	# 		ProjectSettings.set_setting("audio/driver/mix_rate", int(text))
	# 	%LineEditAudioRate.text=""
	# 	%LineEditAudioRate.placeholder_text="%d Hz" % AudioServer.get_mix_rate()
	# )

	# audio latency (readonly)

	var audio_latency_update_timer := Timer.new()
	add_child(audio_latency_update_timer)
	audio_latency_update_timer.start(1.0)
	audio_latency_update_timer.timeout.connect(func() -> void:
		if visible:
			%LineEditAudioLatency.placeholder_text = "%f ms" % AudioServer.get_output_latency()
	)

	%Setting_SAEnable.init_config_global(main, "audio_analyzer_enabled", func(value: bool) -> void:
		main.audio_set_spectrum_analyzer_enabled(value)
	)

	%Setting_SAMin.init_config_global(main, "audio_analyzer_min_freq", func(value: int) -> void:
		main.visualizer_frequency_min = value
	)

	%Setting_SAMax.init_config_global(main, "audio_analyzer_max_freq", func(value: int) -> void:
		main.visualizer_frequency_max = value
	)


##
## Setup the video menu controls.
##
func _init_menu_video() -> void:

	var config := main.config

	# Display

	%Setting_Fullscreen.init_config_global(main, "fullscreen", func(value: bool) -> void:
		if value:
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED
	)

	%Setting_AlwaysOnTop.init_config_global(main, "always_on_top", func(value: bool) -> void:
		get_window().always_on_top = value
	)

	%Setting_WindowSize.init_to_value(6, func(value: int) -> void:
		%Setting_CustomWindowSize.visible = false
		match value:
			0: %Setting_CustomWindowSize.value = Vector2i(640, 480)
			1: %Setting_CustomWindowSize.value = Vector2i(960, 720)
			2: %Setting_CustomWindowSize.value = Vector2i(1280, 960)
			3: %Setting_CustomWindowSize.value = Vector2i(960, 640)
			4: %Setting_CustomWindowSize.value = Vector2i(1440, 960)
			5: %Setting_CustomWindowSize.value = Vector2i(1920, 1280)
			6: %Setting_CustomWindowSize.visible = true
	)

	var init_window_size := Vector2i(config.window_width, config.window_height)
	%Setting_CustomWindowSize.init_to_value(init_window_size, func(value: Vector2i) -> void:
		if get_window().size != value:
			get_window().size = value
			config.set_property_global("window_width", value.x)
			config.set_property_global("window_height", value.y)
	)
	get_window().size_changed.connect(func() -> void:
		var is_fullscreen := get_window().mode != Window.MODE_WINDOWED

		%Setting_Fullscreen.set_value_no_signal(is_fullscreen)
		%Setting_CustomWindowSize.set_value_no_signal(get_window().size)

		%Setting_WindowSize.enabled = !is_fullscreen
		%Setting_CustomWindowSize.enabled = !is_fullscreen
	)

	%Setting_VSync.init_config_global(main, "vsync", func(value: int) -> void:
		DisplayServer.window_set_vsync_mode(value)
	)

	%Setting_FPSLimit.init_config_global(main, "fps_cap", func(value: int) -> void:
		match value:
			0: Engine.max_fps = 30
			1: Engine.max_fps = 45
			2: Engine.max_fps = 60
			3: Engine.max_fps = 72
			4: Engine.max_fps = 90
			5: Engine.max_fps = 120
			6: Engine.max_fps = 144
			7: Engine.max_fps = 240
			_: Engine.max_fps = 0
	)
	
	# Blur settings

	%Setting_DOFShape.init_config_global(main, "dof_bokeh_shape", func(index: int) -> void:
		RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(index)
	)

	%Setting_DOFQuality.init_config_global(main, "dof_blur_quality", func(index: int) -> void:
		RenderingServer.camera_attributes_set_dof_blur_quality(index, true)
	)

	# Anti-aliasing

	%Setting_MSAA.init_config_global(main, "msaa", func(value: int) -> void:
		match value:
			0: get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			1: get_viewport().msaa_3d = Viewport.MSAA_2X
			2: get_viewport().msaa_3d = Viewport.MSAA_4X
			3: get_viewport().msaa_3d = Viewport.MSAA_8X
	)

	%Setting_TAA.init_config_global(main, "taa", func(value: bool) -> void:
		get_viewport().use_taa = value
	)

	# Render Scale

	%Setting_UpscalingMethod.init_config_global(main, "scale_mode", func(value: int) -> void:
		match value:
			0:
				get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				%Setting_FSRSharpness.enabled = false
				%Setting_TAA.enabled = true
			1:
				get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
				%Setting_FSRSharpness.enabled = true
				%Setting_TAA.enabled = true
			2:
				%Setting_TAA.value = false
				get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
				%Setting_FSRSharpness.enabled = true
				%Setting_TAA.enabled = false
	)

	%Setting_RenderScale.init_config_global(main, "render_scale", func(value: float) -> void:
		get_viewport().scaling_3d_scale = value
	)

	%Setting_FSRSharpness.init_config_global(main, "fsr_sharpness", func(value: float) -> void:
		get_viewport().fsr_sharpness = (2.0 - (value / 6.0 * 2.0))
	)

##
## Setup the filter menu controls.
##
func _init_menu_filters() -> void:

	%Setting_ShaderVHS.init_config_profile(main, "shader_vhs", func(value: bool) -> void:
		main.get_node("%VHSShader1").visible = value
		main.get_node("%VHSShader2").visible = value
	)
	%Setting_ShaderCRT.init_config_profile(main, "shader_crt", func(value: bool) -> void:
		main.get_node("%CRTShader1").visible = value and %Setting_ShaderCRTScanLines.value
		main.get_node("%CRTShader2").visible = value and %Setting_ShaderCRTReverseCurvature.value
		main.get_node("%CRTShader3").visible = value
	)
	%Setting_ShaderNoise.init_config_profile(main, "shader_noise", func(value: bool) -> void:
		main.get_node("%NoiseShader").visible = value
	)

	%Setting_ShaderVHSSmear.init_config_shader(main, "%VHSShader1", "smear")
	%Setting_ShaderVHSWiggle.init_config_shader(main, "%VHSShader1", "wiggle")
	%Setting_ShaderVHSNoise.init_config_shader(main, "%VHSShader2", "crease_opacity")
	%Setting_ShaderVHSTape.init_config_shader(main, "%VHSShader2", "tape_crease_smear")

	%Setting_ShaderCRTScanLines.init_config_profile(main, "shader_crt_scan_lines", func(value: bool) -> void:
		main.get_node("%CRTShader1").visible = value and %Setting_ShaderCRT.value
	)
	%Setting_ShaderCRTReverseCurvature.init_config_profile(main, "shader_crt_reverse_curvature", func(value: bool) -> void:
		main.get_node("%CRTShader2").visible = value and %Setting_ShaderCRT.value
	)
	%Setting_ShaderCRTCurvature.init_config_shader(main, "%CRTShader3", "warp_amount")
	%Setting_ShaderCRTVignette.init_config_shader(main, "%CRTShader3", "vignette_opacity")

	%Setting_ShaderCRTAudioB.init_config_global(main, "audio_to_brightness", func(value: float) -> void:
		main.visualizer_brightness_amount = value
	)
	%Setting_ShaderCRTAudioCA.init_config_global(main, "audio_to_aberration", func(value: float) -> void:
		main.visualizer_aberration_amount = value
	)

	%Setting_ShaderVHS.connect_to_enable(%Setting_ShaderVHSSmear)
	%Setting_ShaderVHS.connect_to_enable(%Setting_ShaderVHSWiggle)
	%Setting_ShaderVHS.connect_to_enable(%Setting_ShaderVHSNoise)
	%Setting_ShaderVHS.connect_to_enable(%Setting_ShaderVHSTape)

	%Setting_ShaderCRT.connect_to_enable(%Setting_ShaderCRTScanLines)
	%Setting_ShaderCRT.connect_to_enable(%Setting_ShaderCRTReverseCurvature)
	%Setting_ShaderCRT.connect_to_enable(%Setting_ShaderCRTCurvature)
	%Setting_ShaderCRT.connect_to_enable(%Setting_ShaderCRTVignette)
	%Setting_ShaderCRT.connect_to_enable(%Setting_ShaderCRTAudioB)
	%Setting_ShaderCRT.connect_to_enable(%Setting_ShaderCRTAudioCA)

	main.profile_loaded.connect(func(_profile_name: String) -> void:
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
	)

##
## Setup the input menu controls.
##
func _init_menu_input() -> void:

	_connect_config_global("virtual_keyboard_enabled", %Check_VirtualKeyboard, func(value: bool) -> void:
		main.m8_virtual_keyboard_enabled = value
	)

	get_tree().physics_frame.connect(func() -> void:
		%ButtonBindUp1.text = get_key_bind("key_up", 0)
		%ButtonBindUp2.text = get_key_bind("key_up", 1)
		%ButtonBindDown1.text = get_key_bind("key_down", 0)
		%ButtonBindDown2.text = get_key_bind("key_down", 1)
		%ButtonBindLeft1.text = get_key_bind("key_left", 0)
		%ButtonBindLeft2.text = get_key_bind("key_left", 1)
		%ButtonBindRight1.text = get_key_bind("key_right", 0)
		%ButtonBindRight2.text = get_key_bind("key_right", 1)
		%ButtonBindOpt1.text = get_key_bind("key_option", 0)
		%ButtonBindOpt2.text = get_key_bind("key_option", 1)
		%ButtonBindEdit1.text = get_key_bind("key_edit", 0)
		%ButtonBindEdit2.text = get_key_bind("key_edit", 1)
		%ButtonBindShift1.text = get_key_bind("key_shift", 0)
		%ButtonBindShift2.text = get_key_bind("key_shift", 1)
		%ButtonBindPlay1.text = get_key_bind("key_play", 0)
		%ButtonBindPlay2.text = get_key_bind("key_play", 1)
	)

	%ButtonBindUp1.button_down.connect(start_rebind_action.bind("key_up", 0))
	%ButtonBindUp2.button_down.connect(start_rebind_action.bind("key_up", 1))
	%ButtonBindDown1.button_down.connect(start_rebind_action.bind("key_down", 0))
	%ButtonBindDown2.button_down.connect(start_rebind_action.bind("key_down", 1))
	%ButtonBindLeft1.button_down.connect(start_rebind_action.bind("key_left", 0))
	%ButtonBindLeft2.button_down.connect(start_rebind_action.bind("key_left", 1))
	%ButtonBindRight1.button_down.connect(start_rebind_action.bind("key_right", 0))
	%ButtonBindRight2.button_down.connect(start_rebind_action.bind("key_right", 1))
	%ButtonBindOpt1.button_down.connect(start_rebind_action.bind("key_option", 0))
	%ButtonBindOpt2.button_down.connect(start_rebind_action.bind("key_option", 1))
	%ButtonBindEdit1.button_down.connect(start_rebind_action.bind("key_edit", 0))
	%ButtonBindEdit2.button_down.connect(start_rebind_action.bind("key_edit", 1))
	%ButtonBindShift1.button_down.connect(start_rebind_action.bind("key_shift", 0))
	%ButtonBindShift2.button_down.connect(start_rebind_action.bind("key_shift", 1))
	%ButtonBindPlay1.button_down.connect(start_rebind_action.bind("key_play", 0))
	%ButtonBindPlay2.button_down.connect(start_rebind_action.bind("key_play", 1))

	%ButtonResetBinds.button_down.connect(reset_key_rebinds.bind());

	load_key_rebinds()

##
## Setup the 3d model menu controls.
##
func _init_menu_model() -> void:

	for arr: Array in [
		[%Setting_ModelColorUp, "%KeyUp", "model_color_key_up"],
		[%Setting_ModelColorDown, "%KeyDown", "model_color_key_down"],
		[%Setting_ModelColorLeft, "%KeyLeft", "model_color_key_left"],
		[%Setting_ModelColorRight, "%KeyRight", "model_color_key_right"],
		[%Setting_ModelColorOption, "%KeyOption", "model_color_key_option"],
		[%Setting_ModelColorEdit, "%KeyEdit", "model_color_key_edit"],
		[%Setting_ModelColorShift, "%KeyShift", "model_color_key_shift"],
		[%Setting_ModelColorPlay, "%KeyPlay", "model_color_key_play"],
		[%Setting_ModelColorBody, "%Body", "model_color_body"]
	]:
		var setting: SettingBase = arr[0]
		var node_path: String = arr[1]
		var config_property: String = arr[2]

		setting.init_config_profile(main, config_property, func(value: Color) -> void:
			if _model(): _model(node_path).material_override.albedo_color = value
		)

	# highlight color for directional buttons (can only edit together)
	var color_settings_highlights: Array[SettingBase] = [
		%Setting_ModelColorHLUp,
		%Setting_ModelColorHLDown,
		%Setting_ModelColorHLLeft,
		%Setting_ModelColorHLRight,
	]

	for setting in color_settings_highlights:
		setting.init_config_profile(main, "hl_color_directional", func(value: Color) -> void:
			for s in color_settings_highlights:
				s.set_value_no_signal(value)
			if _model():
				var colors: Array[Color] = [
					_model("%KeyUp").material_overlay.albedo_color,
					_model("%KeyDown").material_overlay.albedo_color,
					_model("%KeyLeft").material_overlay.albedo_color,
					_model("%KeyRight").material_overlay.albedo_color
				]
				_model("%KeyUp").material_overlay.albedo_color = Color(value, colors[0].a)
				_model("%KeyDown").material_overlay.albedo_color = Color(value, colors[1].a)
				_model("%KeyLeft").material_overlay.albedo_color = Color(value, colors[2].a)
				_model("%KeyRight").material_overlay.albedo_color = Color(value, colors[3].a)
			main.overlay_keys.color_directional = value
		)

	# highlight color for other buttons
	for arr: Array in [
		[%Setting_ModelColorHLOption, "%KeyOption", "color_option", "hl_color_option"],
		[%Setting_ModelColorHLEdit, "%KeyEdit", "color_edit", "hl_color_edit"],
		[%Setting_ModelColorHLShift, "%KeyShift", "color_shift", "hl_color_shift"],
		[%Setting_ModelColorHLPlay, "%KeyPlay", "color_play", "hl_color_play"],
	]:
		var setting: SettingBase = arr[0]
		var node_path: String = arr[1]
		var overlay_prop: String = arr[2]
		var config_property: String = arr[3]

		setting.init_config_profile(main, config_property, func(value: Color) -> void:
				# set highlight color on model and key overlay
				if _model():
					var color: Color = _model(node_path).material_overlay.albedo_color
					_model(node_path).material_overlay.albedo_color = Color(value, color.a)
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

	main.profile_loaded.connect(func(_profile_name: String) -> void:
		for setting in color_settings: setting.reinit()
	)

	# Model settings

	%Setting_ModelHighlightOpacity.init_config_profile(main, "model_hl_opacity", func(value: float) -> void:
		if _model(): _model().highlight_opacity = value
	)
	%Setting_ModelScreenFilter.init_config_profile(main, "model_screen_linear_filter", func(value: bool) -> void:
		if _model(): _model().set_screen_filter(value)
	)
	%Setting_ModelScreenEmission.init_config_profile(main, "model_screen_emission", func(value: float) -> void:
		if _model(): _model().set_screen_emission(value)
	)

	main.scene_loaded.connect(func(_scene_path: String, scene: M8Scene) -> void:
		var enabled := scene.has_3d_camera()

		for setting in color_settings:
			setting.enabled = enabled
			%Setting_ModelHighlightOpacity.enabled = enabled
			%Setting_ModelScreenFilter.enabled = enabled
			%Setting_ModelScreenEmission.enabled = enabled

		%Setting_ModelHighlightOpacity.reinit()
		%Setting_ModelScreenFilter.reinit()
		%Setting_ModelScreenEmission.reinit()
	)

##
## Setup the device connection menu controls.
##
func _init_menu_devices() -> void:

	# serial ports

	refresh_serial_device_list()

	%ListSerialPorts.item_selected.connect(func(index: int) -> void:
		%ButtonConnectSerialPort.disabled = false
		if main.current_serial_device == %ListSerialPorts.get_item_text(index):
			%ButtonConnectSerialPort.text = "Reconnect"
			%ButtonDisconnectSerialPort.disabled = false
		else:
			%ButtonConnectSerialPort.text = "Connect"
			%ButtonDisconnectSerialPort.disabled = true
	)

	%ButtonRefreshSerialPorts.pressed.connect(refresh_audio_device_list)

	%ButtonConnectSerialPort.pressed.connect(func() -> void:
		var index: int = %ListSerialPorts.get_selected_items()[0]
		var text: String = %ListSerialPorts.get_item_text(index)
		main.m8_device_connect(text)
		%ListSerialPorts.deselect_all()
		%ButtonConnectSerialPort.disabled = true
		%ButtonConnectSerialPort.text = "Connect"
	)

	%ButtonDisconnectSerialPort.pressed.connect(func() -> void:
		main.m8_device_disconnect(false)
	)

	# audio devices

	refresh_audio_device_list()

	%ListAudioDevices.item_selected.connect(func(index: int) -> void:
		%ButtonConnectAudioDevice.disabled = false
		if main.current_audio_device == %ListAudioDevices.get_item_text(index):
			%ButtonConnectAudioDevice.text = "Reconnect"
			%ButtonDisconnectAudioDevice.disabled = false
			%ButtonHardResetAudioDevice.disabled = false
		else:
			%ButtonConnectAudioDevice.text = "Connect"
			%ButtonDisconnectAudioDevice.disabled = true
			%ButtonHardResetAudioDevice.disabled = true
	)

	%ButtonRefreshAudioDevices.pressed.connect(refresh_audio_device_list)

	%ButtonConnectAudioDevice.pressed.connect(func() -> void:
		var index: int = %ListAudioDevices.get_selected_items()[0]
		var text: String = %ListAudioDevices.get_item_text(index)
		main.m8_audio_connect(text)
		%ListAudioDevices.deselect_all()
		%ButtonConnectAudioDevice.disabled = true
		%ButtonHardResetAudioDevice.disabled = true
		%ButtonConnectAudioDevice.text = "Connect"
	)

	%ButtonHardResetAudioDevice.pressed.connect(func() -> void:
		var index: int = %ListAudioDevices.get_selected_items()[0]
		var text: String = %ListAudioDevices.get_item_text(index)
		main.m8_audio_connect(text, true)
		%ListAudioDevices.deselect_all()
		%ButtonConnectAudioDevice.disabled = true
		%ButtonHardResetAudioDevice.disabled = true
		%ButtonConnectAudioDevice.text = "Connect"
	)

	%ButtonDisconnectAudioDevice.pressed.connect(func() -> void:
		main.m8_audio_disconnect()
	)

	get_tree().process_frame.connect(func() -> void:
		if main.is_menu_open():
			var volume := main.audio_get_peak_volume()
			%Bar_AudioLevelL.value = volume.x
			%Bar_AudioLevelR.value = volume.y
	)

	# auto refresh list
	visibility_changed.connect(func() -> void:
		if visible:
			refresh_serial_device_list()
			refresh_audio_device_list()
			for item: int in %ListAudioDevices.get_selected_items():
				%ListAudioDevices.item_selected.emit(item)
			for item: int in %ListSerialPorts.get_selected_items():
				%ListSerialPorts.item_selected.emit(item)
	)

##
## Setup the debug menu controls.
##
func _init_menu_debug() -> void:

	var config := main.config

	%CheckButtonDebug.toggled.connect(func(toggled_on: bool) -> void:
		main.get_node("%DebugLabels").visible = toggled_on
		config.debug_info = toggled_on
	)
	%CheckButtonDebug.button_pressed = config.debug_info

	%ButtonM8Enable.pressed.connect(main.m8_send_enable_display)
	%ButtonM8Disable.pressed.connect(main.m8_send_disable_display)
	%ButtonM8Reset.pressed.connect(main.m8_send_reset_display)

	%SpinBoxM8Keys.value_changed.connect(func(value: float) -> void:
		%LabelM8KeysBinary.text = String.num_int64(int(value), 2).pad_zeros(8)
	)

	%ButtonM8Control.pressed.connect(func() -> void:
		var keys: int = %SpinBoxM8Keys.get_line_edit().text.to_int()
		main.m8_send_control(keys)
	)

	%ButtonM8KeyJazz.pressed.connect(func() -> void:
		var n: int = %SpinBoxM8Note.get_line_edit().text.to_int()
		var v: int = %SpinBoxM8Vel.get_line_edit().text.to_int()
		print("debug: sending keyjazz (n=%d, v=%d)" % [n, v])
		main.m8_send_keyjazz(n, v)
	)

	%SpinBoxM8ThemeDelay.value_changed.connect(func(value: float) -> void:
		%LabelM8ThemeDelayMS.text = "%.1fms" % (value / 60.0 * 1000.0)
	)

	var m8t_colors := [
		%ColorM8T0, %ColorM8T1, %ColorM8T2, %ColorM8T3,
		%ColorM8T4, %ColorM8T5, %ColorM8T6, %ColorM8T7,
		%ColorM8T8, %ColorM8T9, %ColorM8T10, %ColorM8T11,
		%ColorM8T12
	]

	%ButtonM8Theme.pressed.connect(func() -> void:
		print("debug: sending theme colors")
		var delay_frames: int = %SpinBoxM8ThemeDelay.get_line_edit().text.to_int()
		for i: int in range(m8t_colors.size()):
			main.m8_send_theme_color(i, m8t_colors[i].color)
			for j in range(delay_frames):
				await get_tree().physics_frame
	)

##
## Connect a Control node to a config global setting and callback function.
##
func _connect_config_global(property: String, control: Control, fn: Callable) -> void:
	main.config.assert_setting_exists(property)

	var callback := func(value: Variant) -> void:
		fn.call(value)
		main.config.set_property_global(property, value)

	var default: Variant = main.config.get_property_global(property)

	_connect(control, default, callback)

func _connect(control: Control, default: Variant, fn: Callable) -> void:

	if control is Slider: # fn should be func(value: float)
		control.value_changed.connect(fn)
		control.set_value_no_signal(default)
		control.value_changed.emit(default)

	elif control is CheckButton: # fn should be func(value: bool)
		control.toggled.connect(fn)
		control.set_pressed_no_signal(default)
		control.toggled.emit(default)

	else:
		assert(false, "Tried to connect setting to unrecognized node.")

##
## Links the first control to enable/disable the second control.
## First control should be a CheckButton. 
##
func _link_control_to_disable(setting: Control, control: Control) -> void:
	var sig: Signal
	var src_property: String
	var dst_property: String
	var invert := false

	if setting is CheckButton:
		sig = setting.toggled
		src_property = "button_pressed"
	elif setting is SettingBase:
		sig = setting.value_changed
		src_property = "value"
	else:
		assert(false)

	if control is Slider:
		dst_property = "editable"
	elif control is Button:
		dst_property = "disabled"
		invert = true
	else:
		assert(false)

	assert(src_property in setting and dst_property in control)

	sig.connect(func(value: bool) -> void:
		control.set(dst_property, value if !invert else !value)
		print("update button")
	)

	control.set(dst_property, setting.get(src_property) if !invert else !setting.get(src_property))

##
## Try to return the device model in the current scene.
## If there isn't one, returns null.
##
func _model(path: String = "") -> Node:
	if main.current_scene and main.current_scene.has_device_model():
		if path == "":
			return main.current_scene.get_device_model()
		else:
			return main.current_scene.get_device_model().get_node(path)
	else:
		return null

func update_device_colors() -> void:

	var config := main.config

	if _model():

		_model().highlight_opacity = %SliderHL_Opacity.value

		_model("%Body").material_override.albedo_color = config.model_color_body

		# update model keycap and highlight colors
		for arr: Array in [
			[_model("%Keycap_Up"), config.hl_color_directional, config.model_color_key_up],
			[_model("%Keycap_Down"), config.hl_color_directional, config.model_color_key_down],
			[_model("%Keycap_Left"), config.hl_color_directional, config.model_color_key_left],
			[_model("%Keycap_Right"), config.hl_color_directional, config.model_color_key_right],
			[_model("%Keycap_Option"), config.hl_color_option, config.model_color_key_option],
			[_model("%Keycap_Edit"), config.hl_color_edit, config.model_color_key_edit],
			[_model("%Keycap_Shift"), config.hl_color_shift, config.model_color_key_shift],
			[_model("%Keycap_Play"), config.hl_color_play, config.model_color_key_play],
		]:
			var keycap: MeshInstance3D = arr[0]
			var color: Color = arr[2]
			var hl_color: Color = arr[1]
			keycap.material_override.albedo_color = color
			keycap.material_overlay.albedo_color = hl_color

	# update key overlay colors
	main.overlay_keys.color_directional = config.hl_color_directional
	main.overlay_keys.color_shift = config.hl_color_shift
	main.overlay_keys.color_play = config.hl_color_play
	main.overlay_keys.color_option = config.hl_color_option
	main.overlay_keys.color_edit = config.hl_color_edit

func reset_key_rebinds() -> void:
	for action: String in [
		"key_up", "key_down", "key_left", "key_right",
		"key_shift", "key_play", "key_option", "key_edit"]:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, ProjectSettings.get_setting("input/" + action).events[0])
	save_key_rebinds()
	print("keybindings reset to default")

func load_key_rebinds() -> void:
	for action: String in main.config.action_events.keys():
		var events: Array = main.config.action_events[action]
		assert(events is Array)
		for event: InputEvent in events:
			assert(event is InputEvent, "event is not InputEvent, found %s" % type_string(typeof(event)))
			InputMap.action_add_event(action, event)
	print("key bindings loaded from config")

func save_key_rebinds() -> void:
	for action: String in main.M8_ACTIONS:
		var events := InputMap.action_get_events(action)
		main.config.action_events[action] = events
	print("key bindings saved to config")

func get_key_bind(action: String, index: int) -> String:

	var events := InputMap.action_get_events(action)
	var event: InputEvent
	if index == 0 and events.size() == 0:
		event = ProjectSettings.get_setting("input/" + action).events[0]
	elif index < events.size():
		event = events[index]
	else:
		return "----"

	return event.as_text()

##
## Open the rebind prompt. The callback function will be called
## with the InputEvent as the first argument.
##
func start_rebind(fn: Callable) -> void:

	# prevent opening rebind prompt too fast
	if Time.get_ticks_msec() - last_rebind_time < REBIND_COOLDOWN:
		return

	%BindActionPopup.visible = true

	key_rebind_callback = fn

	is_key_rebinding = true

##
## Open the rebind prompt to rebind an action.
## The index chooses which InputEvent to rebind.
##
func start_rebind_action(action: String, index: int = 0) -> void:

	var callback := func(event: InputEvent) -> void:
		var events := InputMap.action_get_events(action)

		if events.size() <= index:
			events.append(event)
		else:
			assert(index < events.size())
			events[index] = event

		# clear all events and add modified ones
		InputMap.action_erase_events(action)
		for e in events:
			InputMap.action_add_event(action, e)

		Input.action_release(action)
		save_key_rebinds()

	start_rebind(callback)

##
## Handles input while the rebind prompt is open. Called by [_input()].
##
func _handle_input_rebind(event: InputEvent) -> void:
	if is_key_rebinding:
		if event is InputEventKey and event.pressed:
			if event.keycode != KEY_ESCAPE:
				key_rebind_callback.call(event)
			end_rebind()
		if event is InputEventJoypadButton and event.pressed:
			key_rebind_callback.call(event)
			end_rebind()
		return

func end_rebind() -> void:
	is_key_rebinding = false
	last_rebind_time = Time.get_ticks_msec()
	%BindActionPopup.visible = false

func set_status_serialport(text: String) -> void:
	%SerialPortStatus.text = text

func set_status_audiodevice(text: String) -> void:
	%AudioDeviceStatus.text = text

##
## Refresh the serial device list UI.
##
func refresh_serial_device_list() -> void:
	%ListSerialPorts.clear()

	for port in M8GD.list_devices():
		%ListSerialPorts.add_item(port)

	for i in range(%ListSerialPorts.item_count):
		if %ListSerialPorts.get_item_text(i) == main.current_serial_device:
			%ListSerialPorts.select(i)
			break

##
## Refresh the audio device list UI.
##
func refresh_audio_device_list() -> void:
	%ListAudioDevices.clear()

	for device in AudioServer.get_input_device_list():
		%ListAudioDevices.add_item(device)

	for i in range(%ListAudioDevices.item_count):
		if %ListAudioDevices.get_item_text(i) == main.current_audio_device:
			%ListAudioDevices.select(i)
			break

func _input(event: InputEvent) -> void:
	_handle_input_rebind(event)

##
## Recreate the profile hotkey UI with the current list of profiles and
## their saved hotkey bindings.
##
func refresh_profile_hotkeys() -> void:
	for child in %ProfileHotkeysContainer.get_children():
		if child != %ProfileHotkeyTemplate:
			child.queue_free()

	for profile_name: String in main.list_profile_names():
		var container: HBoxContainer = %ProfileHotkeyTemplate.duplicate()
		var event: Variant = main.config.get_profile_hotkey(profile_name)
		container.visible = true
		container.get_node("Label").text = profile_name
		if event is InputEvent:
			container.get_node("ButtonBind").text = event.as_text()
		else:
			container.get_node("ButtonBind").text = "---"
		%ProfileHotkeysContainer.add_child(container)

		container.get_node("ButtonBind").pressed.connect(func() -> void:
			start_rebind(func(e: InputEvent) -> void:
				main.config.set_profile_hotkey(profile_name, e)
				refresh_profile_hotkeys()
			)
		)

		container.get_node("ButtonClear").pressed.connect(func() -> void:
			main.config.clear_profile_hotkey(profile_name)
			refresh_profile_hotkeys()
		)
