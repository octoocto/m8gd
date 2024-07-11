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

func init(p_main: M8SceneDisplay, load_parameters:=true) -> void:
	super(p_main, load_parameters)

	%DeviceModel.init(main)
	%AudioSpectrum.init(main)
	%DisplayMesh.material_override.set_shader_parameter("tex", main.m8_client.get_display_texture())
	camera.init(main)

func _physics_process(delta: float) -> void:

	if main.is_menu_open(): return
	camera.update(delta)