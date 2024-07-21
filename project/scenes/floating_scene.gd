extends M8Scene

@onready var camera: HumanizedCamera3D = %Camera3D

@export var model_screen_emission := 0.25:
	set(value):
		if has_device_model():
			get_device_model().set_screen_emission(value)
		model_screen_emission = value

@export var enable_display_background := true:
	set(value):
		%DisplayMesh.visible = value
		enable_display_background = value

@export var enable_audio_spectrum := false:
	set(value):
		%SpriteAudioSpectrum.visible = value
		%AudioSpectrum.visible = value
		enable_audio_spectrum = value

@export var audio_spectrum_color := Color.WHITE:
	set(value):
		%SpriteAudioSpectrum.modulate = value
		audio_spectrum_color = value

@export_range(-1, 8) var audio_spectrum_width: int = 1:
	set(value):
		%AudioSpectrum.line_width = value
		audio_spectrum_width = value

@export var audio_spectrum_interlace := true:
	set(value):
		%AudioSpectrum.interlace = value
		audio_spectrum_interlace = value

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

var background_mode := 0

func init(p_main: M8SceneDisplay, load_parameters:=true) -> void:
	super(p_main, load_parameters)

	%DeviceModel.init(main)
	%AudioSpectrum.init(main)
	%DisplayMesh.material_override.set_shader_parameter("tex", main.m8_client.get_display_texture())
	camera.init(main)

	if load_parameters:
		# main.menu_scene.read_params_from_scene(self)

		main.menu_scene.init_profile(self)

		main.menu_scene.add_export_var("model_screen_emission")

		main.menu_scene.add_section("Audio Spectrum")
		main.menu_scene.add_export_var("enable_audio_spectrum")
		main.menu_scene.add_export_var("audio_spectrum_color")
		main.menu_scene.add_export_var("audio_spectrum_width")
		main.menu_scene.add_export_var("audio_spectrum_interlace")
		main.menu_scene.reg_link_editable("enable_audio_spectrum", "audio_spectrum_color")
		main.menu_scene.reg_link_editable("enable_audio_spectrum", "audio_spectrum_width")
		main.menu_scene.reg_link_editable("enable_audio_spectrum", "audio_spectrum_interlace")

		main.menu_scene.add_section("Jumbotron")
		main.menu_scene.add_option("jumbotron_mode", 1, [
			"Disabled",
			"M8 Display"
		], func(index: int) -> void:
			%DisplayMesh.visible=false

			match index:
				0:
					pass
				1:
					%DisplayMesh.visible=true
		)

		main.menu_scene.add_section("Background")
		main.menu_scene.add_option("background_mode", 0, [
			"Solid Color",
			"Panorama",
			"Media",
		], func(index: int) -> void:
			%BGImageTexture.visible=false
			%BGVideoStreamPlayer.visible=false
			%WorldEnvironment.environment.background_mode=Environment.BG_CLEAR_COLOR
			%WorldEnvironment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED

			match index:
				0:
					%WorldEnvironment.environment.background_mode=Environment.BG_COLOR
				1:
					%WorldEnvironment.environment.background_mode=Environment.BG_SKY
				2:
					%WorldEnvironment.environment.background_mode=Environment.BG_CANVAS
					%BGImageTexture.visible=true
					if %BGVideoStreamPlayer.is_playing():
						%BGVideoStreamPlayer.visible=true

			background_mode=index
		)
		main.menu_scene.add_export_var("solid_background_color")
		main.menu_scene.add_file("background_file", "", func(path: String) -> void:
			%BGVideoStreamPlayer.stop()
			# try to load an image from this path
			var ext:=path.get_extension()
			match ext:
				"png", "jpg", "jpeg":
					print("loading image")
					var image:=Image.load_from_file(path)
					%BGImageTexture.texture=ImageTexture.create_from_image(image)
					if background_mode == 2:
						# %BGImageTexture.visible=true
						%BGVideoStreamPlayer.visible=false
				"ogv":
					print("loading video")
					%BGVideoStreamPlayer.stream=load(path)
					%BGVideoStreamPlayer.play()
					%BGImageTexture.texture= %BGVideoStreamPlayer.get_video_texture()
					if background_mode == 2:
						# %BGImageTexture.visible=false
						%BGVideoStreamPlayer.visible=true
		)

		main.menu_scene.add_section("Lights")
		main.menu_scene.add_export_var("enable_lamp_light")
		main.menu_scene.add_export_var("lamp_light_color")
		main.menu_scene.add_export_var("enable_left_light")
		main.menu_scene.add_export_var("left_light_color")
		main.menu_scene.add_export_var("enable_right_light")
		main.menu_scene.add_export_var("right_light_color")
		main.menu_scene.reg_link_editable("enable_lamp_light", "lamp_light_color")
		main.menu_scene.reg_link_editable("enable_left_light", "left_light_color")
		main.menu_scene.reg_link_editable("enable_right_light", "right_light_color")

func _physics_process(delta: float) -> void:

	if main.is_menu_open(): return
	camera.update(delta)

	var env: Environment = %WorldEnvironment.environment
	if env.volumetric_fog_enabled:
		var color: Color = main.m8_get_color_palette()[0]
		# color.v = 1.0
		env.volumetric_fog_emission = color
