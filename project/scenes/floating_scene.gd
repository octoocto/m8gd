extends M8Scene

@onready var camera: M8SceneCamera3D = %Camera3D


@export var enable_display_background := true:
	set(value):
		%DisplayMesh.visible = value
		enable_display_background = value

@export var enable_audio_spectrum := false:
	set(value):
		enable_audio_spectrum = value
		%AudioSpectrum.visible = value
		%SpriteAudioSpectrum.visible = value

@export var audio_spectrum_color := Color.WHITE:
	set(value):
		audio_spectrum_color = value
		%SpriteAudioSpectrum.modulate = value

@export_range(-1, 8) var audio_spectrum_width: int = 1:
	set(value):
		audio_spectrum_width = value
		%AudioSpectrum.style_line_width = value

@export var audio_spectrum_interlace := true:
	set(value):
		audio_spectrum_interlace = value
		%AudioSpectrum.style_bar_interlace = value
		%AudioSpectrum.style_line_interlace = value

@export_range(0, 10) var jumbotron_distortion_amount := 3:
	set(value):
		jumbotron_distortion_amount = value
		%DisplayMesh.material_override.set_shader_parameter("distort_amount", value)

@export_range(0.75, 2.0, 0.05) var jumbotron_size := 0.75:
	set(value):
		jumbotron_size = value
		%DisplayMesh.scale = Vector3(value, value, value)

@export_range(0.0, 2.0, 0.1) var jumbotron_brightness := 0.3:
	set(value):
		jumbotron_brightness = value
		%DisplayMesh.material_override.set_shader_parameter("brightness", value)

@export_range(0.0, 2.0, 0.1) var jumbotron_contrast := 1.2:
	set(value):
		jumbotron_contrast = value
		%DisplayMesh.material_override.set_shader_parameter("contrast", value)

@export var solid_background_color := Color.BLACK:
	set(value):
		%WorldEnvironment.environment.background_color = value
		solid_background_color = value

@export var enable_lamp_light := true:
	set(value):
		enable_lamp_light = value
		%LightLamp.visible = value

@export var lamp_light_color := Color(0.85, 0.8, 1.0):
	set(value):
		left_light_color = value
		%LightLamp.light_color = value
		%LightLamp.light_energy = value.a

@export var enable_left_light := false:
	set(value):
		enable_left_light = value
		%LightLeft.visible = value

@export var left_light_color := Color(1, 0, 0):
	set(value):
		left_light_color = value
		%LightLeft.light_color = value
		%LightLeft.light_energy = value.a * 16

@export var enable_right_light := false:
	set(value):
		enable_right_light = value
		%LightRight.visible = value

@export var right_light_color := Color(0, 0, 1):
	set(value):
		right_light_color = value
		%LightRight.light_color = value
		%LightRight.light_energy = value.a * 16

func init(p_main: Main) -> void:
	super(p_main)

	get_device_model().init(main)
	%AudioSpectrum.init(main)
	%DisplayMesh.material_override.set_shader_parameter("tex", main.m8_client.get_display())
	camera.init(main)

func init_menu(menu: SceneMenu) -> void:

	# menu.add_exports_from(self)
	# menu.init_profile(self)

	menu.add_section("Audio Spectrum")
	var setting_spectrum := menu.add_auto("enable_audio_spectrum")
	setting_spectrum.connect_to_visible(menu.add_auto("audio_spectrum_color"))
	setting_spectrum.connect_to_visible(menu.add_auto("audio_spectrum_width"))
	setting_spectrum.connect_to_visible(menu.add_auto("audio_spectrum_interlace"))

	menu.add_section("Jumbotron")
	menu.add_option_custom("jumbotron_mode", 1, [
		"Disabled",
		"M8 Display"
	], func(index: int) -> void:
		%DisplayMesh.visible = index == 1
	)
	menu.add_auto("jumbotron_size", "• Size")
	menu.add_auto("jumbotron_brightness", "• Brightness")
	menu.add_auto("jumbotron_contrast", "• Contrast")
	menu.add_auto("jumbotron_distortion_amount", "• Distortion")

	menu.add_section("Background")

	var setting_bg_mode := menu.add_option_custom("background_mode", 0, [
		"Solid Color",
		"Custom File",
		"Custom File (Panorama)",
	], func(index: int) -> void:
		%BGTextureRect.visible = false
		%BGVideoStreamPlayer.visible = false
		%WorldEnvironment.environment.background_mode = Environment.BG_CLEAR_COLOR
		%WorldEnvironment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
		match index:
			0:
				%WorldEnvironment.environment.background_mode = Environment.BG_COLOR
			1:
				%WorldEnvironment.environment.background_mode = Environment.BG_CANVAS
				%BGTextureRect.visible = true
				if %BGVideoStreamPlayer.is_playing():
					%BGVideoStreamPlayer.visible = true
			2:
				%WorldEnvironment.environment.background_mode = Environment.BG_SKY
	)

	setting_bg_mode.connect_to_visible(menu.add_auto("solid_background_color"),
		func(value: int) -> bool: return value == 0
	)

	setting_bg_mode.connect_to_visible(
		menu.add_file_custom("background_file", "", func(path: String) -> void:
			var texture := load_media_to_texture_rect(path, %BGVideoStreamPlayer)
			%BGTextureRect.texture = texture
			%WorldEnvironment.environment.sky.sky_material.panorama = texture
			),
		func(value: int) -> bool: return value != 0
	)

	menu.add_section("Lighting")

	var setting_light_lamp := menu.add_auto("enable_lamp_light")
	setting_light_lamp.connect_to_visible(menu.add_auto("lamp_light_color", "• Light Color"))
	var setting_light_left := menu.add_auto("enable_left_light")
	setting_light_left.connect_to_visible(menu.add_auto("left_light_color", "• Light Color"))
	var setting_light_right := menu.add_auto("enable_right_light")
	setting_light_right.connect_to_visible(menu.add_auto("right_light_color", "• Light Color"))

func _physics_process(delta: float) -> void:

	if main.is_menu_open(): return
	camera.update(delta)

	var env: Environment = %WorldEnvironment.environment
	if env.volumetric_fog_enabled:
		var color: Color = main.m8_get_color_palette()[0]
		# color.v = 1.0
		env.volumetric_fog_emission = color
