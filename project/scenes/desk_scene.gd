extends M8Scene

@onready var camera: HumanizedCamera3D = %Camera3D
@onready var main: M8SceneDisplay

var time := 0.0
var raw_time := 0.0

func initialize(main_: M8SceneDisplay):
	super(main_)
	main = main_

	%M8Model.init(main)

func _physics_process(delta):
	super(delta)

	time += delta + (audio_peak * 0.25)
	raw_time += delta

	%WorldEnvironment.environment.adjustment_brightness = 1.0 + audio_peak * 0.1

	camera.update_humanized_movement(delta)

	if main.is_menu_open(): return

	camera.update_mouse_movement(delta)
