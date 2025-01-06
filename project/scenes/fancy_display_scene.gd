extends M8Scene

@export_range(1, 6) var integer_zoom: int = 0:
	set(value):
		integer_zoom = value
		if is_inside_tree():
			update_viewport_size()

@export_range(0, 6) var panel_integer_scale: int = 1:
	set(value):
		panel_integer_scale = value
		if is_inside_tree():
			update_panel_size()

@export var enable_particles: bool = false:
	set(value):
		enable_particles = value
		if is_inside_tree():
			%GPUParticles2D.visible = value
			%GPUParticles2D2.visible = value

@export var panel_offset: Vector2i = Vector2i.ZERO:
	set(value):
		panel_offset = value
		if is_inside_tree():
			%PanelContainer.offset_left = value.x
			%PanelContainer.offset_right = value.x
			%PanelContainer.offset_top = value.y
			%PanelContainer.offset_bottom = value.y

@export var panel_padding: Vector2i = Vector2i(16, 16):
	set(value):
		panel_padding = value
		if is_inside_tree():
			var stylebox: StyleBox = %PanelContainer.get_theme_stylebox("panel")
			stylebox.content_margin_left = value.x
			stylebox.content_margin_right = value.x
			stylebox.content_margin_top = value.y
			stylebox.content_margin_bottom = value.y

@export_range(0, 16) var panel_corner_radius: int = 8:
	set(value):
		panel_corner_radius = value
		if is_inside_tree():
			var stylebox: StyleBox = %PanelContainer.get_theme_stylebox("panel")
			stylebox.corner_radius_top_left = value
			stylebox.corner_radius_top_right = value
			stylebox.corner_radius_bottom_left = value
			stylebox.corner_radius_bottom_right = value

@export_range(0.0, 1.0, 0.01) var panel_opacity: float = 1.0:
	set(value):
		panel_opacity = value
		if is_inside_tree():
			%PanelContainer.material.set_shader_parameter("panel_opacity", value)

@export_range(0.0, 8.0, 0.1) var panel_blur_amount: float = 2.0:
	set(value):
		panel_blur_amount = value
		if is_inside_tree():
			%PanelContainer.material.set_shader_parameter("blur_amount", value)

@export_range(0.0, 2.0, 0.01) var background_brightness: float = 1.0:
	set(value):
		background_brightness = value
		if is_inside_tree():
			%BGShader.material.set_shader_parameter("brightness", value)

@export_range(0.0, 1.0, 0.01) var background_theme_tint: float = 0.0:
	set(value):
		background_theme_tint = value
		if is_inside_tree():
			%BGShader.material.set_shader_parameter("tint_amount", value)

@export_range(0.0, 8.0, 0.1) var background_blur_amount: float = 4.0:
	set(value):
		background_blur_amount = value
		if is_inside_tree():
			%BGShader.material.set_shader_parameter("blur_amount", value)

@onready var panel: PanelContainer = %PanelContainer

func init(p_main: Main) -> void:
	super(p_main)

	%AudioSpectrum.init(main)
	%AudioWaveform.init(main)

	main.m8_client.set_display_background_alpha(0)

	# %TextureRect.texture = _display.m8_display_texture
	var texture := main.m8_client.get_display()
	%DisplayTextureRect.texture = texture
	# %BGTextureRect.texture.atlas = texture
	# region.size = Vector2i(texture.get_size())
	# %PanelContainer.size = texture.get_size()
	# %PanelContainer.anchors_preset = Control.PRESET_CENTER

	get_window().size_changed.connect(func() -> void:
		update_viewport_size()
	)

	update_viewport_size()
	update_panel_size()

	main.m8_system_info_received.connect(func(_hw: String, _fw: String) -> void:
		update_panel_size()
	)

func init_menu(menu: SceneMenu) -> void:

	menu.add_auto("integer_zoom")

	menu.add_auto("enable_particles")

	menu.add_section("Panel")
	menu.add_auto("panel_integer_scale")
	menu.add_auto("panel_corner_radius")
	menu.add_auto("panel_padding")
	menu.add_auto("panel_offset")
	menu.add_auto("panel_opacity")
	menu.add_auto("panel_blur_amount")

	menu.add_section("Background")
	menu.add_option_custom("background_mode", 0, [
		"M8 Background Color",
		"M8 Display",
		"Custom File"
	], func(index: int) -> void:
		match index:
			0:
				%BGTextureRect.visible = false
			1:
				%BGTextureRect.visible = true
				%BGTextureRect.texture = main.m8_client.get_display()
			2:
				%BGTextureRect.visible = true
				%BGTextureRect.texture = load_media_to_texture_rect(get_setting("background_file"), %BGVideoStreamPlayer)
	)

	menu.add_file_custom("background_file", "", func(path: String) -> void:
		if get_setting("background_mode") == 2:
			%BGTextureRect.texture = load_media_to_texture_rect(path, %BGVideoStreamPlayer)
	)

	menu.add_auto("background_brightness")
	menu.add_auto("background_theme_tint")
	menu.add_auto("background_blur_amount")

func update_viewport_size() -> void:

	var window_size := get_window().get_size()
	var viewport_size := Vector2i((window_size / float(integer_zoom)).ceil())
	%SubViewport.set_size(viewport_size)
	%SubViewportContainer.scale = Vector2(integer_zoom, integer_zoom)

	%Control.custom_minimum_size = window_size * integer_zoom

	%CenterContainer.set_anchors_preset(Control.PRESET_FULL_RECT)
	%CenterContainer.set_anchors_preset(Control.PRESET_TOP_LEFT)

	%GPUParticles2D.process_material.emission_box_extents.x = viewport_size.x
	%GPUParticles2D2.position = viewport_size / 2.0
	%GPUParticles2D2.process_material.emission_box_extents.x = viewport_size.x / 2.0
	%GPUParticles2D2.process_material.emission_box_extents.y = viewport_size.y / 2.0

func update_panel_size() -> void:
	var display_size := main.m8_client.get_display().get_size()
	if panel_integer_scale == 0: # auto
		%DisplayTextureRect.custom_minimum_size = display_size * get_auto_display_integer_scale()
	else:
		%DisplayTextureRect.custom_minimum_size = display_size * panel_integer_scale

func _process(_delta: float) -> void:

	# RenderingServer.set_default_clear_color(main.m8_client.get_background_color())
	var bg_color: Color = main.m8_get_theme_colors()[0]
	%BGColorRect.color = bg_color

	var modulate_color := bg_color
	# modulate_color.v = 1.0
	%BGShader.material.set_shader_parameter("tint_color", modulate_color)

	%PanelContainer.material.set_shader_parameter("panel_color", bg_color)

	%GPUParticles2D.modulate.a = 0.0 + pow(main.audio_get_level(), 2) * 1.0
	%GPUParticles2D.amount_ratio = 0.1 + main.audio_get_level() * 0.9
	%GPUParticles2D.speed_scale = 0.1 + main.audio_get_level() * 4.0

	%GPUParticles2D2.modulate.a = 0.25 + pow(main.audio_get_level(), 2) * 0.75
	%GPUParticles2D2.speed_scale = 0.5 + main.audio_get_level() * 1.5
	%GPUParticles2D2.amount_ratio = 0.5 + main.audio_get_level() * 0.5

	# %AudioSpectrum.modulate.a = pow(main.audio_get_level(), 3)

	# if force_integer_scale == 0:
	# 	%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * get_auto_display_integer_scale();
	# else:
	# 	%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * force_integer_scale;
