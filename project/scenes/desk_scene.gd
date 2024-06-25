extends M8Scene

@onready var camera: Camera3D = %Camera3D
@onready var camera_base_rotation := camera.rotation
@onready var camera_base_position := camera.position

@onready var camera_noise: FastNoiseLite = FastNoiseLite.new()
@onready var camera_noise_u: float = 0.0

var time := 0.0
var raw_time := 0.0

# func _ready():
#     %SpectrumVisual.vscene = self

func initialize(_display: M8SceneDisplay):
	super(_display)

	%M8Model.init(_display)

	camera_noise.noise_type = FastNoiseLite.TYPE_PERLIN

func is_between(x, a, b) -> bool:
	return a < x and x < b

func _physics_process(delta):
	super(delta)

	time += delta + (audio_peak * 0.25)
	raw_time += delta

	%WorldEnvironment.environment.adjustment_brightness = 1.0 + audio_peak * 0.1

	#camera.rotation_degrees.x = -15 + sin(time) * 0.05
	#camera.rotation_degrees.y = sin(raw_time * 0.5) * 0.5

	#%DirectionalLight3D.light_color = color_fg.lightened(0.5)
	# %M8Model.outline_color = color_fg

	# get mouse position as vector between (0, 0) and (1, 1)
	var mouse_position = get_viewport().get_mouse_position() / Vector2(get_window().size)
	var mouse_clicked = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var camera_smoothing = 0.05
	var camera_fov_smoothing = 0.05

	# ignore mouse positions outside this range (outside the window)
	if !is_between(mouse_position.x, 0.0, 1.0) or !is_between(mouse_position.y, 0.0, 1.0):
		camera_smoothing = 0.01
		mouse_position = Vector2(0.5, 0.5)

	# remap mouse position to be in range (-1, -1) to (1, 1). (0, 0) is center of the window.
	mouse_position = (mouse_position * 2.0) - Vector2(1.0, 1.0)

	var camera_mouse_range := Vector2(deg_to_rad(15), deg_to_rad(10)) if mouse_clicked else Vector2(deg_to_rad(5), deg_to_rad(2))
	var camera_target_fov = 15.0 if mouse_clicked else 30.0
	var camera_target_dof = 17.0 if mouse_clicked else 15.0
	var camera_target_rotation := (
		camera_base_rotation + Vector3(
			- mouse_position.y * camera_mouse_range.y,
			- mouse_position.x * camera_mouse_range.x,
			0)
	)

	camera_noise.frequency = 1
	camera.rotation = lerp(camera.rotation, camera_target_rotation, camera_smoothing)
	camera.position = camera_base_position + Vector3(
		camera_noise.get_noise_2d(camera_noise_u, 0.0),
		camera_noise.get_noise_2d(camera_noise_u, 0.3),
		camera_noise.get_noise_2d(camera_noise_u, 0.6),
	) * 0.05
	camera.fov = lerp(camera.fov, camera_target_fov, camera_fov_smoothing)
	camera.attributes.dof_blur_far_distance = lerp(camera.attributes.dof_blur_far_distance, camera_target_dof, 0.01)

	camera_noise_u += delta
