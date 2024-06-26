extends M8Scene

@onready var camera: HumanizedCamera3D = %Camera3D
@onready var main: M8SceneDisplay

var time := 0.0
var raw_time := 0.0

func initialize(main_: M8SceneDisplay):
	super(main_)
	main = main_

	%M8Model.init(main)
	%MeshInstance3D.material_override.set_shader_parameter("tex", main.m8_client.get_display_texture())

func is_between(x, a, b) -> bool:
	return a < x and x < b

func _physics_process(delta):
	super(delta)

	time += delta + (audio_peak * 0.25)
	raw_time += delta

	%WorldEnvironment.environment.adjustment_brightness = 1.0 + audio_peak * 0.1

	camera.update_humanized_movement(delta)

	if main.is_menu_open(): return

	camera.update_mouse_movement(delta)

	# get mouse position as vector between (0, 0) and (1, 1)
	var mouse_position = get_viewport().get_mouse_position() / Vector2(get_window().size)

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
