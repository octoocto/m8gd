extends M8Scene

@export_range(0, 6) var integer_scale: int = 0:
	set(value):
		integer_scale = value

@onready var texture_rect: TextureRect = %TextureRect


func init(p_main: Main) -> void:
	super(p_main)

	texture_rect.texture = main.m8_client.get_display()


func init_menu(menu: SceneConfigMenu) -> void:
	menu.add_auto("integer_scale")


func _process(_delta: float) -> void:
	RenderingServer.set_default_clear_color(main.m8_client.get_theme_colors()[0])

	if integer_scale == 0:
		texture_rect.custom_minimum_size = (
			texture_rect.texture.get_size() * get_auto_display_integer_scale()
		)
	else:
		texture_rect.custom_minimum_size = texture_rect.texture.get_size() * integer_scale
