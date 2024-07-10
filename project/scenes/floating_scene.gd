extends M8Scene

@onready var camera: HumanizedCamera3D = %Camera3D

@export var enable_mouse_controlled_pan_zoom := true:
	set(value):
		%Camera3D.mouse_controlled_pan_zoom = value
		enable_mouse_controlled_pan_zoom = value

@export var humanized_camera_movement := true:
	set(value):
		%Camera3D.humanized_movement = value
		humanized_camera_movement = value

@export var enable_depth_of_field := true:
	set(value):
		%Camera3D.attributes.dof_blur_far_enabled = value
		%Camera3D.attributes.dof_blur_near_enabled = value
		enable_depth_of_field = value

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

func init(p_main: M8SceneDisplay) -> void:
	super(p_main)

	%DeviceModel.init(main)
	%AudioSpectrum.init(main)
	%DisplayMesh.material_override.set_shader_parameter("tex", main.m8_client.get_display_texture())
	camera.init(main)

func is_between(x: float, a: float, b: float) -> bool:
	return a < x and x < b

func _physics_process(delta: float) -> void:

	if main.is_menu_open(): return

	camera.update(delta)
	
	if !enable_mouse_controlled_pan_zoom or camera.is_repositioning: return

	# get mouse position as vector between (0, 0) and (1, 1)
	var mouse_position := get_viewport().get_mouse_position() / Vector2(get_window().size)

	# ignore mouse positions outside this range (outside the window)
	if !is_between(mouse_position.x, 0.0, 1.0) or !is_between(mouse_position.y, 0.0, 1.0):
		mouse_position = Vector2(0.5, 0.5)

	# remap mouse position to be in range (-1, -1) to (1, 1). (0, 0) is center of the window.
	mouse_position = (mouse_position * 2.0) - Vector2(1.0, 1.0)

	var camera_arm_mouse_range := Vector2(deg_to_rad(10), deg_to_rad(5))
	var camera_arm_target_rotation := (
		Vector3(
			- mouse_position.y * camera_arm_mouse_range.y,
			- mouse_position.x * camera_arm_mouse_range.x,
			0)
	)

	# mouse panning/zoom controls
	%CameraArm.rotation = lerp( %CameraArm.rotation, camera_arm_target_rotation, camera.pan_smoothing_focused)
