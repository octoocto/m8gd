@tool
extends MenuBase

@onready var s_ui_scale: SettingNumber = %Setting_UIScale
@onready var s_text_casing: SettingOptions = %STextCasing
@onready var s_fullscreen: SettingBase = %Setting_Fullscreen
@onready var s_window_borderless: SettingBase = %Setting_WindowBorderless
@onready var s_always_on_top: SettingBase = %Setting_AlwaysOnTop
@onready var s_window_size: SettingBase = %Setting_WindowSize
@onready var s_custom_window_size: SettingBase = %Setting_CustomWindowSize
@onready var s_vsync: SettingBase = %Setting_VSync
@onready var s_fps_limit: SettingBase = %Setting_FPSLimit
@onready var s_dof_shape: SettingBase = %Setting_DOFShape
@onready var s_dof_quality: SettingBase = %Setting_DOFQuality
@onready var s_msaa: SettingBase = %Setting_MSAA
@onready var s_taa: SettingBase = %Setting_TAA
@onready var s_upscaling_method: SettingBase = %Setting_UpscalingMethod
@onready var s_render_scale: SettingBase = %Setting_RenderScale
@onready var s_fsr_sharpness: SettingBase = %Setting_FSRSharpness


func _on_menu_init() -> void:
	var config := main.config
	var window := get_tree().root
	var viewport := window.get_viewport()

	# UI

	var func_update_ui_scale := func() -> void:
		var display_scale: float = s_ui_scale.value
		if display_scale < 1.0:
			display_scale = min(main.display_get_auto_scale(), main.display_get_max_scale())
			Log.ln("Auto UI scale detected: %f" % display_scale)
		else:
			display_scale = min(display_scale, main.display_get_max_scale())
			Log.ln("UI scale set to: %f" % display_scale)
		main.display_set_scale(display_scale)

	s_ui_scale.setting_connect_global("ui_scale", func(_value: float) -> void:
		func_update_ui_scale.call()
	)
	s_ui_scale.set_format_function(func(value: float) -> String:
		if value < 1.0:
			var display_scale: float = min(main.display_get_auto_scale(), main.display_get_max_scale())
			return "Auto (%d%%)" % (int)(display_scale * 100)
		else:
			return "%d%%" % (int)(value * 100)
	)
	viewport.size_changed.connect(func_update_ui_scale)

	s_text_casing.setting_connect_global(
		"ui_text_case", func(value: int) -> void: THEME.set_constant("text_case", "UIBase", value)
	)

	# Display

	s_fullscreen.setting_connect_global(
		"fullscreen",
		func(value: bool) -> void:
			if value:
				window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			else:
				window.mode = Window.MODE_WINDOWED
				s_window_borderless.emit_value_changed()
	)

	s_window_borderless.setting_connect_global(
		"window_borderless",
		func(value: bool) -> void:
			if window.mode == Window.MODE_WINDOWED:
				window.borderless = value
	)

	s_always_on_top.setting_connect_global(
		"always_on_top", func(value: bool) -> void: window.always_on_top = value
	)

	s_window_size.setting_connect(
		6,
		func(value: int) -> void:
			s_custom_window_size.visible = false
			match value:
				0:
					s_custom_window_size.value = Vector2i(640, 480)
				1:
					s_custom_window_size.value = Vector2i(960, 720)
				2:
					s_custom_window_size.value = Vector2i(1280, 960)
				3:
					s_custom_window_size.value = Vector2i(960, 640)
				4:
					s_custom_window_size.value = Vector2i(1440, 960)
				5:
					s_custom_window_size.value = Vector2i(1920, 1280)
				6:
					s_custom_window_size.visible = true
	)

	var init_window_size := Vector2i(config.window_width, config.window_height)
	s_custom_window_size.setting_connect(
		init_window_size,
		func(value: Vector2i) -> void:
			window.size = value
			config.set_global_value("window_width", value.x)
			config.set_global_value("window_height", value.y)
	)

	window.size_changed.connect(
		func() -> void:
			var is_fullscreen := window.mode != Window.MODE_WINDOWED

			s_fullscreen.set_value_no_signal(is_fullscreen)
			s_custom_window_size.value = window.size
	)

	s_vsync.setting_connect_global(
		"vsync", func(value: int) -> void: DisplayServer.window_set_vsync_mode(value)
	)

	s_fps_limit.setting_connect_global(
		"fps_cap",
		func(value: int) -> void:
			match value:
				0:
					Engine.max_fps = 30
				1:
					Engine.max_fps = 45
				2:
					Engine.max_fps = 60
				3:
					Engine.max_fps = 72
				4:
					Engine.max_fps = 90
				5:
					Engine.max_fps = 120
				6:
					Engine.max_fps = 144
				7:
					Engine.max_fps = 240
				_:
					Engine.max_fps = 0
	)

	# Blur settings

	s_dof_shape.setting_connect_global(
		"dof_bokeh_shape",
		func(index: int) -> void: RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(index)
	)

	s_dof_quality.setting_connect_global(
		"dof_blur_quality",
		func(index: int) -> void:
			RenderingServer.camera_attributes_set_dof_blur_quality(index, true)
	)

	# Anti-aliasing

	s_msaa.setting_connect_global(
		"msaa",
		func(value: int) -> void:
			match value:
				0:
					get_viewport().msaa_3d = Viewport.MSAA_DISABLED
				1:
					get_viewport().msaa_3d = Viewport.MSAA_2X
				2:
					get_viewport().msaa_3d = Viewport.MSAA_4X
				3:
					get_viewport().msaa_3d = Viewport.MSAA_8X
	)

	s_taa.setting_connect_global("taa", func(value: bool) -> void: viewport.use_taa = value)

	# Render Scale

	s_upscaling_method.setting_connect_global(
		"scale_mode",
		func(value: int) -> void:
			match value:
				0:
					viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
					s_fsr_sharpness.enabled = false
					s_taa.enabled = true
				1:
					viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
					s_fsr_sharpness.enabled = true
					s_taa.enabled = true
				2:
					s_taa.value = false
					viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
					s_fsr_sharpness.enabled = true
					s_taa.enabled = false
	)

	s_render_scale.setting_connect_global(
		"render_scale", func(value: float) -> void: viewport.scaling_3d_scale = value
	)

	s_fsr_sharpness.setting_connect_global(
		"fsr_sharpness",
		func(value: float) -> void: viewport.fsr_sharpness = (2.0 - (value / 6.0 * 2.0))
	)
