extends M8Scene

@export_range(0, 6) var force_integer_scale: int = 0:
	set(value):
		force_integer_scale = value

func init(p_main: Main) -> void:
	super(p_main)

	# %TextureRect.texture = _display.m8_display_texture
	%TextureRect.texture = main.m8_client.get_display()

func init_menu(menu: SceneMenu) -> void:
	menu.add_auto("force_integer_scale")

func get_auto_integer_scale() -> int:

	var window_size: Vector2i = get_viewport().size
	var texture: Texture2D = %TextureRect.texture
	var intscale := 1

	while ((intscale + 1) * texture.get_size().x <= window_size.x and (intscale + 1) * texture.get_size().y <= window_size.y):
		intscale += 1

	return intscale

func _process(_delta: float) -> void:

	RenderingServer.set_default_clear_color(main.m8_client.get_theme_colors()[0])

	if force_integer_scale == 0:
		%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * get_auto_integer_scale();
	else:
		%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * force_integer_scale;
