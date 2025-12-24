extends M8Scene

@export_range(0, 6) var integer_scale: int = 0:
	set(value):
		integer_scale = value
		_update()

@export_range(1, 6) var panel_integer_scale: int = 1:
	set(value):
		panel_integer_scale = value
		_update()

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
			%BackgroundShader.material.set_shader_parameter("brightness", value)

@export_range(0.0, 1.0, 0.01) var background_theme_tint: float = 0.0:
	set(value):
		background_theme_tint = value
		if is_inside_tree():
			%BackgroundShader.material.set_shader_parameter("tint_amount", value)

@export_range(0.0, 8.0, 0.1) var background_blur_amount: float = 4.0:
	set(value):
		background_blur_amount = value
		if is_inside_tree():
			%BackgroundShader.material.set_shader_parameter("blur_amount", value)

func _physics_process(_delta: float) -> void:
	_update_integer_scale()

func init(p_main: Main) -> void:
	super(p_main)

	var texture := main.m8_client.get_display()
	%DisplayTextureRect.texture = texture

	Events.window_modified.connect(_update)

	main.m8_system_info_received.connect(func(_hw: String, _fw: String) -> void:
		_update()
	)
	main.m8_theme_changed.connect(func(_colors: PackedColorArray, _complete: bool) -> void:
		_update_background_color()
	)

	_update()
	_update_background_color()

func init_menu(menu: SceneConfigMenu) -> void:

	menu.add_auto("integer_scale")

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
				%BackgroundTextureRect.visible = false
			1:
				%BackgroundTextureRect.visible = true
				%BackgroundTextureRect.texture = main.m8_client.get_display()
			2:
				%BackgroundTextureRect.visible = true
				%BackgroundTextureRect.texture = load_media_to_texture_rect(get_value("background_file"), %BGVideoStreamPlayer)
	)

	menu.add_file_custom("background_file", "", func(path: String) -> void:
		if get_value("background_mode") == 2:
			%BackgroundTextureRect.texture = load_media_to_texture_rect(path, %BGVideoStreamPlayer)
	)

	menu.add_auto("background_brightness")
	menu.add_auto("background_theme_tint")
	menu.add_auto("background_blur_amount")

func _update() -> void:
	if not is_inside_tree(): return

	_update_integer_scale()

	var display_size := main.m8_client.get_display().get_size()

	if panel_integer_scale == 0: # auto
		%DisplayTextureRect.custom_minimum_size = display_size * get_auto_display_integer_scale()
	else:
		%DisplayTextureRect.custom_minimum_size = display_size * panel_integer_scale

func _update_integer_scale() -> void:

	if integer_scale == 0:
		integer_scale = get_auto_display_integer_scale()

	var window_size := get_window().get_size()
	var viewport_size := Vector2i((window_size / float(integer_scale)).ceil())
	%CenterContainer.set_anchors_preset(Control.PRESET_FULL_RECT)
	%SubViewport.integer_size = viewport_size
	%SubViewport.integer_scale = integer_scale

func _update_background_color() -> void:
	var bg_color: Color = main.m8_get_theme_colors()[0]
	%BackgroundColorRect.color = bg_color
	%BackgroundShader.material.set_shader_parameter("tint_color", bg_color)
	%PanelContainer.material.set_shader_parameter("panel_color", bg_color)
