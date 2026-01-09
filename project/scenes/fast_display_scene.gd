extends M8Scene

@export_range(0, 6) var integer_scale: int = 0:
	set(value):
		integer_scale = value

@onready var texture_rect: TextureRect = %TextureRect


func init(p_main: Main) -> void:
	super(p_main)

	texture_rect.texture = main.m8c.get_display_texture()

	RenderingServer.set_default_clear_color(main.m8c.get_background_color())
	main.m8c.background_color_changed.connect(
		func(color: Color) -> void: RenderingServer.set_default_clear_color(color)
	)


func init_menu(menu: SceneConfigMenu) -> void:
	menu.add_auto("integer_scale")


func _get_integer_scale() -> int:
	if integer_scale == 0:
		return get_auto_display_integer_scale()
	else:
		return min(integer_scale, get_auto_display_integer_scale())


func _process(_delta: float) -> void:
	texture_rect.custom_minimum_size = (texture_rect.texture.get_size() * _get_integer_scale())
