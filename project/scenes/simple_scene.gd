extends M8Scene

@export_range(0, 6) var force_integer_scale: int:
	set(value):
		force_integer_scale = value

func initialize(p_main: M8SceneDisplay):
	super(p_main)

	# %TextureRect.texture = _display.m8_display_texture
	%TextureRect.texture = main.m8_client.get_display_texture()

func get_auto_integer_scale() -> int:

	var window_size = DisplayServer.window_get_size()
	var texture = %TextureRect.texture
	var intscale := 1

	while ((intscale + 1) * texture.get_size().x <= window_size.x and (intscale + 1) * texture.get_size().y <= window_size.y):
		intscale += 1

	return intscale

func _process(_delta):

	RenderingServer.set_default_clear_color(main.m8_client.get_background_color())

	if force_integer_scale == 0:
		%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * get_auto_integer_scale();
	else:
		%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * force_integer_scale;
