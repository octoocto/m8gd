class_name BackgroundScene extends M8Scene

enum BackgroundMode {
	M8_BACKGROUND_COLOR,
	M8_DISPLAY,
	IMAGE,
}
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

@onready var bg_color_rect: ColorRect = %BackgroundColorRect
@onready var bg_video_stream_player: VideoStreamPlayer = %BGVideoStreamPlayer
@onready var bg_shader: ColorRect = %BackgroundShader
@onready var bg_texture_rect: TextureRect = %BackgroundTextureRect


func init() -> void:
	main.m8c.background_color_changed.connect(
		func(_color: Color) -> void:
			_update_background_color(),
	)

	_update_background_color()


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


func _update_background_color() -> void:
	var bg_color: Color = main.m8_get_theme_colors()[0]
	bg_color_rect.color = bg_color
	(bg_shader.material as ShaderMaterial).set_shader_parameter("tint_color", bg_color)
