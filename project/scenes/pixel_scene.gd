extends M8Scene

@export_range(1, 6) var integer_zoom: int = 1:
	set(value):
		integer_zoom = value
		if is_inside_tree():
			update_viewport_size()

@export var enable_particles: bool = false:
	set(value):
		enable_particles = value
		if is_inside_tree():
			%GPUParticles2D.visible = value
			%GPUParticles2D2.visible = value

@export_range(1, 4) var panel_integer_scale: int = 1:
	set(value):
		panel_integer_scale = value
		if is_inside_tree():
			var display_size := main.m8_client.get_display_texture().get_size()
			%DisplayTextureRect.custom_minimum_size = display_size * value

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

func init(p_main: M8SceneDisplay, load_parameters:=true) -> void:
	super(p_main, load_parameters)

	%AudioSpectrum.init(main)

	main.m8_client.set_background_alpha(0)

	# %TextureRect.texture = _display.m8_display_texture
	var texture := main.m8_client.get_display_texture()
	%DisplayTextureRect.texture = texture
	# %BGTextureRect.texture.atlas = texture
	# region.size = Vector2i(texture.get_size())
	# %PanelContainer.size = texture.get_size()
	# %PanelContainer.anchors_preset = Control.PRESET_CENTER

	get_window().size_changed.connect(func() -> void:
		update_viewport_size()
	)

	if load_parameters:
		main.menu_scene.init_profile(self)

		main.menu_scene.add_export_var("integer_zoom")

		main.menu_scene.add_export_var("enable_particles")

		main.menu_scene.add_section("Panel")
		main.menu_scene.add_export_var("panel_integer_scale")
		main.menu_scene.add_export_var("panel_corner_radius")
		main.menu_scene.add_export_var("panel_padding")
		main.menu_scene.add_export_var("panel_offset")
		main.menu_scene.add_export_var("panel_opacity")
		main.menu_scene.add_export_var("panel_blur_amount")

		main.menu_scene.add_section("Background")
		main.menu_scene.add_option("background_mode", 0, [
			"M8 Background Color",
			"M8 Display",
			"Custom File"
		], func(index: int) -> void:
			match index:
				0:
					%BGTextureRect.visible=false
				1:
					%BGTextureRect.visible=true
					%BGTextureRect.texture=main.m8_client.get_display_texture()
				2:
					%BGTextureRect.visible=true
					%BGTextureRect.texture=load_media_to_texture_rect(get_setting("background_file"), %BGVideoStreamPlayer)
		)

		main.menu_scene.add_file("background_file", "", func(path: String) -> void:
			if get_setting("background_mode") == 2:
				%BGTextureRect.texture=load_media_to_texture_rect(path, %BGVideoStreamPlayer)
		)

		main.menu_scene.add_export_var("background_brightness")
		main.menu_scene.add_export_var("background_theme_tint")
		main.menu_scene.add_export_var("background_blur_amount")

	update_viewport_size()

func get_auto_integer_scale() -> int:

	var window_size: Vector2i = get_viewport().size
	var texture: Texture2D = %TextureRect.texture
	var intscale := 1

	while ((intscale + 1) * texture.get_size().x <= window_size.x and (intscale + 1) * texture.get_size().y <= window_size.y):
		intscale += 1

	return intscale

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

func _process(_delta: float) -> void:

	# RenderingServer.set_default_clear_color(main.m8_client.get_background_color())
	%BGColorRect.color = main.m8_client.get_background_color()

	var modulate_color := main.m8_client.get_background_color()
	# modulate_color.v = 1.0
	%BGShader.material.set_shader_parameter("tint_color", modulate_color)

	%PanelContainer.material.set_shader_parameter("panel_color", main.m8_client.get_background_color())

	%GPUParticles2D.modulate.a = 0.0 + pow(main.audio_get_level(), 2) * 1.0
	%GPUParticles2D.amount_ratio = 0.1 + main.audio_get_level() * 0.9
	%GPUParticles2D.speed_scale = 0.1 + main.audio_get_level() * 4.0

	%GPUParticles2D2.modulate.a = 0.25 + pow(main.audio_get_level(), 2) * 0.75
	%GPUParticles2D2.speed_scale = 0.5 + main.audio_get_level() * 1.5
	%GPUParticles2D2.amount_ratio = 0.5 + main.audio_get_level() * 0.5

	%AudioSpectrum.modulate.a = pow(main.audio_get_level(), 3)

	# if force_integer_scale == 0:
	# 	%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * get_auto_integer_scale();
	# else:
	# 	%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * force_integer_scale;
