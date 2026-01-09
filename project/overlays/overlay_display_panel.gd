@tool
extends OverlayBase

@export_range(1, 4) var integer_scale: int = 1:
	set(value):
		integer_scale = value
		_update()

@export var padding: Vector2i = Vector2i(16, 16):
	set(value):
		padding = value
		_update()

@export_range(0, 16) var corner_radius: int = 8:
	set(value):
		corner_radius = value
		_update()

@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0:
	set(value):
		opacity = value
		_update()

@export_range(0.0, 8.0, 0.1) var blur_amount: float = 2.0:
	set(value):
		opacity = value
		_update()

@onready var display_panel: PanelContainer = %DisplayPanel
@onready var display_texture_rect: TextureRect = %DisplayTextureRect


func _overlay_init() -> void:
	display_texture_rect.texture = main.m8c.get_display_texture()
	main.m8_theme_changed.connect(
		func(_colors: PackedColorArray, _complete: bool) -> void: _update()
	)


func _update() -> void:
	if is_inside_tree():
		# update position
		display_panel.position = position_offset

		# update padding
		var stylebox: StyleBoxFlat = display_panel.get_theme_stylebox("panel")
		stylebox.content_margin_left = padding.x
		stylebox.content_margin_right = padding.x
		stylebox.content_margin_top = padding.y
		stylebox.content_margin_bottom = padding.y
		stylebox.corner_radius_top_left = corner_radius
		stylebox.corner_radius_top_right = corner_radius
		stylebox.corner_radius_bottom_left = corner_radius
		stylebox.corner_radius_bottom_right = corner_radius

		# update shader
		(display_panel.material as ShaderMaterial).set_shader_parameter("panel_opacity", opacity)
		(display_panel.material as ShaderMaterial).set_shader_parameter("blur_amount", blur_amount)
		(display_panel.material as ShaderMaterial).set_shader_parameter(
			"panel_color", main.m8_get_theme_colors()[0]
		)

		# update size
		var display_size := main.m8c.get_display_texture().get_size() * integer_scale
		display_texture_rect.custom_minimum_size = display_size
		display_panel.custom_minimum_size = Vector2.ZERO
		display_panel.size = Vector2.ZERO
		size = display_panel.size

		anchors_preset = anchors_preset  # needed for correct anchor to be used
