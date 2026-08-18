extends M8Scene

@export_range(0, 6) var integer_scale: int = 0:
	set(value):
		integer_scale = value

@onready var texture_rect: TextureRect = %DisplayTextureRect


func init() -> void:
	texture_rect.texture = main.m8c.get_display_texture()

	RenderingServer.set_default_clear_color(main.m8c.get_background_color())
	main.m8c.background_color_changed.connect(
		func(color: Color) -> void:
			RenderingServer.set_default_clear_color(color),
	)

	_update_integer_scale()
	get_window().size_changed.connect(_update_integer_scale)
	main.m8c.system_info_received.connect(
		func(... _args: Array) -> void:
			_update_integer_scale(),
	)


func _update_integer_scale() -> void:
	var fn := func() -> void:
		var integer_scale := 0
		if self.integer_scale == 0:
			integer_scale = get_auto_display_integer_scale()
		else:
			integer_scale = min(self.integer_scale, get_auto_display_integer_scale())

		texture_rect.custom_minimum_size = (texture_rect.texture.get_size() * integer_scale)
	fn.call_deferred()
