extends M8Scene

@export_group("Scale")

@export_range(0, 6) var integer_scale: int = 0:
	set(value):
		integer_scale = value
		self._update()

@export_group("Background", "background_")

@export var background_mode := BackgroundContainer.BackgroundMode.M8_BACKGROUND_COLOR:
	set(value):
		background_mode = value
		self.bg.mode = value

@export_file var background_file := "":
	set(value):
		background_file = value
		self.bg.texture_file = value

@export_range(0.0, 2.0, 0.01) var background_brightness: float = 1.0:
	set(value):
		background_brightness = value
		self.bg.brightness = value

@export_range(0.0, 1.0, 0.01) var background_theme_tint: float = 0.0:
	set(value):
		background_theme_tint = value
		self.bg.tint_amount = value

@export_range(0.0, 8.0, 0.1) var background_blur_amount: float = 4.0:
	set(value):
		background_blur_amount = value
		self.bg.blur_amount = value

@export_group("Panel", "panel_")

@export_range(1, 6) var panel_integer_scale: int = 1:
	set(value):
		panel_integer_scale = value
		self._update()

@export var panel_offset: Vector2i = Vector2i.ZERO:
	set(value):
		panel_offset = value
		self._update()

@export var panel_padding: Vector2i = Vector2i(16, 16):
	set(value):
		panel_padding = value
		self._update()

@export_range(0, 16) var panel_corner_radius: int = 8:
	set(value):
		panel_corner_radius = value
		self._update()

@export_range(0.0, 1.0, 0.01) var panel_opacity: float = 1.0:
	set(value):
		panel_opacity = value
		self._update()

@export_range(0.0, 8.0, 0.1) var panel_blur_amount: float = 2.0:
	set(value):
		panel_blur_amount = value
		self._update()

@onready var bg: BackgroundContainer = %BackgroundContainer
@onready var panel: PanelContainer = %PanelContainer
@onready var display_texture_rect: TextureRect = %DisplayTextureRect


func init() -> void:
	self.display_texture_rect.texture = self.main.m8c.get_display_texture()

	Events.window_modified.connect(_update)

	Events.m8_system_info_received.connect(
		func(_hw: String, _fw: String) -> void:
			_update(),
	)
	main.m8c.background_color_changed.connect(
		func(_color: Color) -> void:
			_update(),
	)

	_update()


func _update() -> void:
	if not is_inside_tree():
		return

	_update_integer_scale()
	_update_panel()
	_update_display()


func _update_integer_scale() -> void:
	if self.integer_scale == 0:
		self.integer_scale = get_auto_display_integer_scale()
	self.bg.content_scale = self.integer_scale


func _update_panel() -> void:
	self.panel.offset_left = self.panel_offset.x
	self.panel.offset_right = self.panel_offset.x
	self.panel.offset_top = self.panel_offset.y
	self.panel.offset_bottom = self.panel_offset.y

	var stylebox: StyleBoxFlat = self.panel.get_theme_stylebox("panel")
	stylebox.expand_margin_left = self.panel_padding.x
	stylebox.expand_margin_right = self.panel_padding.x
	stylebox.expand_margin_top = self.panel_padding.y
	stylebox.expand_margin_bottom = self.panel_padding.y
	stylebox.set_corner_radius_all(self.panel_corner_radius)

	var panel_mat: ShaderMaterial = self.panel.material as ShaderMaterial
	panel_mat.set_shader_parameter("panel_opacity", self.panel_opacity)
	panel_mat.set_shader_parameter("blur_amount", self.panel_blur_amount)
	panel_mat.set_shader_parameter("panel_color", self.main.m8_get_theme_colors()[0])

	self.panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func _update_display() -> void:
	var display_size := self.main.m8c.get_display_texture().get_size()
	if self.panel_integer_scale == 0: # auto
		self.display_texture_rect.custom_minimum_size = display_size * get_auto_display_integer_scale()
	else:
		self.display_texture_rect.custom_minimum_size = display_size * self.panel_integer_scale
