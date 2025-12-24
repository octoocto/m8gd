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

@export var enable_display_background := true:
	set(value):
		display_mesh.visible = value
		enable_display_background = value

@export var enable_audio_spectrum := false:
	set(value):
		enable_audio_spectrum = value
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

@export_range(0, 10) var jumbotron_distortion_amount := 3:
	set(value):
		jumbotron_distortion_amount = value
		(display_mesh.material_override as ShaderMaterial).set_shader_parameter(
			"distort_amount", value
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

@export var solid_background_color := Color.BLACK:
	set(value):
		world_environment.environment.background_color = value
		solid_background_color = value

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


func init(p_main: Main) -> void:
	super(p_main)

	get_device_model().init(main)
	(display_mesh.material_override as ShaderMaterial).set_shader_parameter(
		"tex", main.m8_client.get_display()
	)
	camera.init(main)


func init_menu(menu: SceneConfigMenu) -> void:
	# menu.add_exports_from(self)
	# menu._preset_init(self)

	menu.add_section("Audio Spectrum")
	var setting_spectrum := menu.add_auto("enable_audio_spectrum")
	menu.add_auto("audio_spectrum_color").show_if(setting_spectrum)
	menu.add_auto("audio_spectrum_width").show_if(setting_spectrum)
	menu.add_auto("audio_spectrum_interlace").show_if(setting_spectrum)

	menu.add_section("Jumbotron")
	menu.add_option_custom(
		"jumbotron_mode",
		1,
		["Disabled", "M8 Display"],
		func(index: int) -> void: display_mesh.visible = index == 1
	)
	menu.add_auto("jumbotron_size", "*Size")
	menu.add_auto("jumbotron_brightness", "*Brightness")
	menu.add_auto("jumbotron_contrast", "*Contrast")
	menu.add_auto("jumbotron_distortion_amount", "*Distortion")

	menu.add_section("Background")

	var setting_bg_mode := menu.add_option_custom(
		"background_mode",
		0,
		[
			"Solid Color",
			"Custom File",
			"Custom File (Panorama)",
		],
		func(index: int) -> void:
			bg_texture_rect.visible = false
			bg_video_stream_player.visible = false
			world_environment.environment.background_mode = Environment.BG_CLEAR_COLOR
			world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
			match index:
				0:
					world_environment.environment.background_mode = Environment.BG_COLOR
				1:
					world_environment.environment.background_mode = Environment.BG_CANVAS
					bg_texture_rect.visible = true
					if bg_video_stream_player.is_playing():
						bg_video_stream_player.visible = true
				2:
					world_environment.environment.background_mode = Environment.BG_SKY
	)

	menu.add_auto("solid_background_color").show_if(
		setting_bg_mode, func(value: int) -> bool: return value == 0
	)

	var on_load_bg_file := func(path: String) -> void:
		var texture := load_media_to_texture_rect(path, bg_video_stream_player)
		bg_texture_rect.texture = texture
		(world_environment.environment.sky.sky_material as PanoramaSkyMaterial).panorama = texture

	menu.add_file_custom("background_file", "", on_load_bg_file).show_if(
		setting_bg_mode, func(value: int) -> bool: return value != 0
	)

	menu.add_section("Lighting")

	var setting_light_lamp := menu.add_auto("enable_lamp_light")
	menu.add_auto("lamp_light_color", "*Light Color").show_if(setting_light_lamp)
	var setting_light_left := menu.add_auto("enable_left_light")
	menu.add_auto("left_light_color", "*Light Color").show_if(setting_light_left)
	var setting_light_right := menu.add_auto("enable_right_light")
	menu.add_auto("right_light_color", "*Light Color").show_if(setting_light_right)


func _physics_process(delta: float) -> void:
	if main.is_menu_open():
		return
	camera.update(delta)
