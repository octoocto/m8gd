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

@export var enable_directional_light := true:
	set(value):
		enable_directional_light = value
		%DirectionalLight3D.visible = value

@export var directional_light_color := Color(0.9, 0.9, 1.0, 0.25):
	set(value):
		left_light_color = value
		%DirectionalLight3D.light_color = value
		%DirectionalLight3D.light_energy = value.a * 4
	
@export var enable_lamp_light := true:
	set(value):
		enable_lamp_light = value
		%LightLamp.visible = value

@export var lamp_light_color := Color(1, 0.9, 0.6):
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

@export var enable_right_light = false:
	set(value):
		enable_right_light = value
		%LightRight.visible = value

@export var right_light_color := Color(0, 0, 1):
	set(value):
		right_light_color = value
		%LightRight.light_color = value
		%LightRight.light_energy = value.a * 16

var time := 0.0
var raw_time := 0.0

func initialize(main_: M8SceneDisplay):
	super(main_)

	%M8Model.init(main)

func _physics_process(delta):

	time += delta + (audio_peak * 0.25)
	raw_time += delta

	%WorldEnvironment.environment.adjustment_brightness = 1.0 + audio_peak * 0.1

	camera.update_humanized_movement(delta)

	if main.is_menu_open(): return

	camera.update_mouse_movement(delta)
