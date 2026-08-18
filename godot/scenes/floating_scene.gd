extends M8Scene

@onready var camera: M8SceneCamera3D = %Camera3D
@onready var display_mesh: MeshInstance3D = %DisplayMesh
@onready var audio_spectrum: OverlayAudioSpectrum = %AudioSpectrum
@onready var sprite_audio_spectrum: Sprite3D = %SpriteAudioSpectrum
@onready var world_environment: WorldEnvironment = %WorldEnvironment
@onready var light_lamp: SpotLight3D = %LightLamp
@onready var light_left: SpotLight3D = %LightLeft
@onready var light_right: SpotLight3D = %LightRight
@onready var bg_texture_rect: TextureRect = %BGTextureRect
@onready var bg_video_stream_player: VideoStreamPlayer = %BGVideoStreamPlayer

@export_group("Audio Spectrum", "audio_spectrum_")
@export var audio_spectrum_enabled := false:
	set(value):
		audio_spectrum_enabled = value
		audio_spectrum.visible = value
		sprite_audio_spectrum.visible = value

@export var audio_spectrum_color := Color.WHITE:
	set(value):
		audio_spectrum_color = value
		sprite_audio_spectrum.modulate = value

@export_range(-1, 8) var audio_spectrum_width: int = 1:
	set(value):
		audio_spectrum_width = value
		audio_spectrum.style_line_width = value

@export var audio_spectrum_interlace := true:
	set(value):
		audio_spectrum_interlace = value
		audio_spectrum.style_bar_interlace = value
		audio_spectrum.style_line_interlace = value

@export_group("Jumbotron", "jumbotron_")
@export var jumbotron_enabled := true:
	set(value):
		jumbotron_enabled = value
		self.display_mesh.visible = value

@export_range(0, 10) var jumbotron_distortion_amount := 3:
	set(value):
		jumbotron_distortion_amount = value
		(display_mesh.material_override as ShaderMaterial).set_shader_parameter(
			"distort_amount",
			value,
		)

@export_range(0.75, 2.0, 0.05) var jumbotron_size := 0.75:
	set(value):
		jumbotron_size = value
		display_mesh.scale = Vector3(value, value, value)

@export_range(0.0, 2.0, 0.1) var jumbotron_brightness := 0.3:
	set(value):
		jumbotron_brightness = value
		(display_mesh.material_override as ShaderMaterial).set_shader_parameter("brightness", value)

@export_range(0.0, 2.0, 0.1) var jumbotron_contrast := 1.2:
	set(value):
		jumbotron_contrast = value
		(display_mesh.material_override as ShaderMaterial).set_shader_parameter("contrast", value)

@export_group("Background", "background_")
@export var background_mode := BackgroundMode.SOLID_COLOR:
	set(value):
		background_mode = value
		self._set_background_mode(value)

@export_file var background_file: String = "":
	set(value):
		background_file = value
		self._set_background_file(value)

@export var solid_background_color := Color.BLACK:
	set(value):
		world_environment.environment.background_color = value
		solid_background_color = value

@export_group("Lights")
@export var enable_lamp_light := true:
	set(value):
		enable_lamp_light = value
		light_lamp.visible = value

@export var lamp_light_color := Color(0.85, 0.8, 1.0):
	set(value):
		left_light_color = value
		light_lamp.light_color = value
		light_lamp.light_energy = value.a

@export var enable_left_light := false:
	set(value):
		enable_left_light = value
		light_left.visible = value

@export var left_light_color := Color(1, 0, 0):
	set(value):
		left_light_color = value
		light_left.light_color = value
		light_left.light_energy = value.a * 16

@export var enable_right_light := false:
	set(value):
		enable_right_light = value
		light_right.visible = value

@export var right_light_color := Color(0, 0, 1):
	set(value):
		right_light_color = value
		light_right.light_color = value
		light_right.light_energy = value.a * 16


func init() -> void:
	get_device_model().init(self.main)
	self.camera.init(self.main)

	(display_mesh.material_override as ShaderMaterial).set_shader_parameter(
		"tex",
		main.m8c.get_display_texture(),
	)


func _physics_process(delta: float) -> void:
	if self.main.is_menu_open():
		return
	self.camera.update(delta)


enum BackgroundMode {
	SOLID_COLOR,
	IMAGE,
	IMAGE_PANORAMA,
}


func _set_background_file(path: String) -> void:
	var texture := load_media_to_texture_rect(path, self.bg_video_stream_player)
	self.bg_texture_rect.texture = texture
	(self.world_environment.environment.sky.sky_material as PanoramaSkyMaterial).panorama = texture


func _set_background_mode(mode: BackgroundMode) -> void:
	self.bg_texture_rect.visible = false
	self.bg_video_stream_player.visible = false
	self.world_environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	self.world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED

	match mode:
		BackgroundMode.SOLID_COLOR:
			self.world_environment.environment.background_mode = Environment.BG_COLOR
		BackgroundMode.IMAGE:
			self.world_environment.environment.background_mode = Environment.BG_CANVAS
			self.bg_texture_rect.visible = true
			if self.bg_video_stream_player.is_playing():
				self.bg_video_stream_player.visible = true
		BackgroundMode.IMAGE_PANORAMA:
			self.world_environment.environment.background_mode = Environment.BG_SKY
