extends M8Scene

@export_range(0, 6) var integer_scale: int = 0:
	set(value):
		integer_scale = value

func init(p_main: Main) -> void:
	super(p_main)

	# %TextureRect.texture = _display.m8_display_texture
	%TextureRect.texture = main.m8_client.get_display()

func init_menu(menu: SceneMenu) -> void:
	menu.add_auto("integer_scale")

func _process(_delta: float) -> void:

	RenderingServer.set_default_clear_color(main.m8_client.get_theme_colors()[0])

	if integer_scale == 0:
		%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * get_auto_display_integer_scale();
	else:
		%TextureRect.custom_minimum_size = %TextureRect.texture.get_size() * integer_scale;
