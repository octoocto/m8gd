extends M8Scene

@onready var panel: PanelContainer = %PanelContainer
@onready var bg_video_stream_player: VideoStreamPlayer = %BGVideoStreamPlayer
@onready var bg_shader: ColorRect = %BackgroundShader
@onready var bg_texture_rect: TextureRect = %BackgroundTextureRect
@onready var display_texture_rect: TextureRect = %DisplayTextureRect
# @onready var sub_viewport: ScalableSubViewport = %SubViewport
@onready var scalable_container: ScalableContainer = %ScalableContainer
@onready var center_container: CenterContainer = %CenterContainer
@onready var bg_color_rect: ColorRect = %BackgroundColorRect
@onready var panel_container: PanelContainer = %PanelContainer

@export_group("Scale")

@export_range(0, 6) var integer_scale: int = 0:
	set(value):
		integer_scale = value
		_update()

@export_group("Panel", "panel_")

@export_range(1, 6) var panel_integer_scale: int = 1:
	set(value):
		panel_integer_scale = value
		_update()

@export var panel_offset: Vector2i = Vector2i.ZERO:
	set(value):
		panel_offset = value
		if is_inside_tree():
			panel.offset_left = value.x
			panel.offset_right = value.x
			panel.offset_top = value.y
			panel.offset_bottom = value.y

@export var panel_padding: Vector2i = Vector2i(16, 16):
	set(value):
		panel_padding = value
		if is_inside_tree():
			var stylebox: StyleBoxFlat = panel.get_theme_stylebox("panel")
			# stylebox.content_margin_left = value.x
			# stylebox.content_margin_right = value.x
			# stylebox.content_margin_top = value.y
			# stylebox.content_margin_bottom = value.y
			stylebox.expand_margin_left = value.x
			stylebox.expand_margin_right = value.x
			stylebox.expand_margin_top = value.y
			stylebox.expand_margin_bottom = value.y

@export_range(0, 16) var panel_corner_radius: int = 8:
	set(value):
		panel_corner_radius = value
		if is_inside_tree():
			var stylebox: StyleBoxFlat = panel.get_theme_stylebox("panel")
			stylebox.corner_radius_top_left = value
			stylebox.corner_radius_top_right = value
			stylebox.corner_radius_bottom_left = value
			stylebox.corner_radius_bottom_right = value

@export_range(0.0, 1.0, 0.01) var panel_opacity: float = 1.0:
	set(value):
		panel_opacity = value
		if is_inside_tree():
			(panel.material as ShaderMaterial).set_shader_parameter("panel_opacity", value)

@export_range(0.0, 8.0, 0.1) var panel_blur_amount: float = 2.0:
	set(value):
		panel_blur_amount = value
		if is_inside_tree():
			(panel.material as ShaderMaterial).set_shader_parameter("blur_amount", value)

@export_group("Background", "background_")

@export var background_mode := BackgroundMode.M8_BACKGROUND_COLOR:
	set(value):
		background_mode = value
		self._set_background_mode(value)

@export_file var background_file := "":
	set(value):
		background_file = value
		self._set_background_file(value)

@export_range(0.0, 2.0, 0.01) var background_brightness: float = 1.0:
	set(value):
		background_brightness = value
		if is_inside_tree():
			(bg_shader.material as ShaderMaterial).set_shader_parameter("brightness", value)

@export_range(0.0, 1.0, 0.01) var background_theme_tint: float = 0.0:
	set(value):
		background_theme_tint = value
		if is_inside_tree():
			(bg_shader.material as ShaderMaterial).set_shader_parameter("tint_amount", value)

@export_range(0.0, 8.0, 0.1) var background_blur_amount: float = 4.0:
	set(value):
		background_blur_amount = value
		if is_inside_tree():
			(bg_shader.material as ShaderMaterial).set_shader_parameter("blur_amount", value)


func _physics_process(_delta: float) -> void:
	_update_integer_scale()


func init() -> void:
	self.display_texture_rect.texture = main.m8c.get_display_texture()

	Events.window_modified.connect(_update)

	Events.m8_system_info_received.connect(
		func(_hw: String, _fw: String) -> void:
			_update(),
	)
	main.m8c.background_color_changed.connect(
		func(_color: Color) -> void:
			_update_background_color(),
	)

	_update()
	_update_background_color()


enum BackgroundMode {
	M8_BACKGROUND_COLOR,
	M8_DISPLAY,
	IMAGE,
}


func _set_background_mode(mode: BackgroundMode) -> void:
	match mode:
		BackgroundMode.M8_BACKGROUND_COLOR:
			bg_texture_rect.visible = false
		BackgroundMode.M8_DISPLAY:
			bg_texture_rect.visible = true
			bg_texture_rect.texture = main.m8c.get_display_texture()
		BackgroundMode.IMAGE:
			bg_texture_rect.visible = true
			bg_texture_rect.texture = load_media_to_texture_rect(
				get_value("background_file") as String,
				bg_video_stream_player,
			)


func _set_background_file(path: String) -> void:
	if self.background_mode == BackgroundMode.IMAGE:
		bg_texture_rect.texture = load_media_to_texture_rect(path, bg_video_stream_player)


func _update() -> void:
	if not is_inside_tree():
		return

	_update_integer_scale()

	var display_size := main.m8c.get_display_texture().get_size()

	if panel_integer_scale == 0: # auto
		display_texture_rect.custom_minimum_size = display_size * get_auto_display_integer_scale()
	else:
		display_texture_rect.custom_minimum_size = display_size * panel_integer_scale


func _update_integer_scale() -> void:
	if integer_scale == 0:
		integer_scale = get_auto_display_integer_scale()
	scalable_container.content_scale = integer_scale
	# var window_size := get_window().get_size()
	# var viewport_size := Vector2i((window_size / float(integer_scale)).ceil())
	# center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	# sub_viewport.integer_size = viewport_size
	# sub_viewport.integer_scale = integer_scale


func _update_background_color() -> void:
	var bg_color: Color = main.m8_get_theme_colors()[0]
	bg_color_rect.color = bg_color
	(bg_shader.material as ShaderMaterial).set_shader_parameter("tint_color", bg_color)
	(panel_container.material as ShaderMaterial).set_shader_parameter("panel_color", bg_color)
