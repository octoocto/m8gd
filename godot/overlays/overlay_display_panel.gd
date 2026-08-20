@tool
extends OverlayBase

@export_range(1, 4) var integer_scale: int = 1
@export var padding: Vector2i = Vector2i(16, 16)
@export_range(0, 16) var corner_radius: int = 8
@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0
@export_range(0.0, 8.0, 0.1) var blur_amount: float = 2.0

@onready var display_panel: PanelContainer = %DisplayPanel
@onready var display_texture_rect: TextureRect = %DisplayTextureRect


func _overlay_init() -> void:
	Events.m8_system_info_received.connect(
		func(_hw: String, _fw: String) -> void:
			self.display_texture_rect.texture = main.m8c.get_display_texture()
			self._overlay_update(),
	)
	main.m8c.background_color_changed.connect(
		func(_color: Color) -> void:
			self._overlay_update(),
	)


func _overlay_update() -> void:
	if not is_inside_tree():
		return

	# update position
	# display_panel.position = self.offset_transform_position

	# update padding
	var stylebox: StyleBoxFlat = self.display_panel.get_theme_stylebox("panel")
	stylebox.expand_margin_left = self.padding.x
	stylebox.expand_margin_right = self.padding.x
	stylebox.expand_margin_top = self.padding.y
	stylebox.expand_margin_bottom = self.padding.y
	stylebox.set_corner_radius_all(self.corner_radius)

	# update shader
	var panel_mat: ShaderMaterial = self.display_panel.material as ShaderMaterial
	panel_mat.set_shader_parameter("panel_opacity", self.opacity)
	panel_mat.set_shader_parameter("blur_amount", self.blur_amount)
	panel_mat.set_shader_parameter("panel_color", self.main.m8c.get_background_color())

	# update size
	var display_size := self.main.m8c.get_display_texture().get_size() * self.integer_scale
	self.display_texture_rect.custom_minimum_size = display_size
	self.display_panel.custom_minimum_size = Vector2.ZERO
	self.display_panel.size = Vector2.ZERO
	self.size = self.display_panel.size

	self.anchors_preset = self.anchors_preset # needed for correct anchor to be used
