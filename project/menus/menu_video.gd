@tool
extends MenuBase

func _menu_init() -> void:
	var config := main.config

	# Display

	%Setting_Fullscreen.setting_connect_global("fullscreen", func(value: bool) -> void:
		if value:
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED
			%Setting_WindowBorderless.emit_changed()
	)

	%Setting_WindowBorderless.setting_connect_global("window_borderless", func(value: bool) -> void:
		if get_window().mode == Window.MODE_WINDOWED:
			get_window().borderless = value
	)

	%Setting_AlwaysOnTop.setting_connect_global("always_on_top", func(value: bool) -> void:
		get_window().always_on_top = value
	)

	%Setting_WindowSize.setting_connect(6, func(value: int) -> void:
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
	%Setting_CustomWindowSize.setting_connect(init_window_size, func(value: Vector2i) -> void:
		get_window().size = value
		config.set_property_global("window_width", value.x)
		config.set_property_global("window_height", value.y)
	)

	get_window().size_changed.connect(func() -> void:
		var is_fullscreen := get_window().mode != Window.MODE_WINDOWED

		%Setting_Fullscreen.set_value_no_signal(is_fullscreen)
		%Setting_CustomWindowSize.value = get_window().size
	)

	%Setting_VSync.setting_connect_global("vsync", func(value: int) -> void:
		DisplayServer.window_set_vsync_mode(value)
	)

	%Setting_FPSLimit.setting_connect_global("fps_cap", func(value: int) -> void:
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

	%Setting_DOFShape.setting_connect_global("dof_bokeh_shape", func(index: int) -> void:
		RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(index)
	)

	%Setting_DOFQuality.setting_connect_global("dof_blur_quality", func(index: int) -> void:
		RenderingServer.camera_attributes_set_dof_blur_quality(index, true)
	)

	# Anti-aliasing

	%Setting_MSAA.setting_connect_global("msaa", func(value: int) -> void:
		match value:
			0: get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			1: get_viewport().msaa_3d = Viewport.MSAA_2X
			2: get_viewport().msaa_3d = Viewport.MSAA_4X
			3: get_viewport().msaa_3d = Viewport.MSAA_8X
	)

	%Setting_TAA.setting_connect_global("taa", func(value: bool) -> void:
		get_viewport().use_taa = value
	)

	# Render Scale

	%Setting_UpscalingMethod.setting_connect_global("scale_mode", func(value: int) -> void:
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

	%Setting_RenderScale.setting_connect_global("render_scale", func(value: float) -> void:
		get_viewport().scaling_3d_scale = value
	)

	%Setting_FSRSharpness.setting_connect_global("fsr_sharpness", func(value: float) -> void:
		get_viewport().fsr_sharpness = (2.0 - (value / 6.0 * 2.0))
	)
