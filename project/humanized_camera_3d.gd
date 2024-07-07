class_name HumanizedCamera3D extends Camera3D

@export var mouse_controlled_pan_zoom := true
@export var humanized_movement := true
@export var humanize_freq := 1.0
@export var humanize_amount := 0.05
@export var pan_smoothing_focused := 0.05
@export var pan_smoothing_unfocused := 0.01
@export var fov_smoothing := 0.05
@export var pan_range_zoomout := Vector2(5, 2)
@export var pan_range_zoomin := Vector2(15, 10)
@export var fov_zoomout := 30.0
@export var fov_zoomin := 15.0
@export var dof_zoomout := 15.0
@export var dof_zoomin := 17.0

@onready var base_rotation := rotation
@onready var base_position := position

@onready var noise: FastNoiseLite = FastNoiseLite.new()
@onready var noise_u: float = 0.0

var is_repositioning := false

func is_between(x: float, a: float, b: float) -> bool:
	return a < x and x < b

func is_mouse_position_in_window(mouse_position: Vector2) -> bool:
	return is_between(mouse_position.x, 0.0, 1.0) and is_between(mouse_position.y, 0.0, 1.0)

func vdeg_to_rad(v: Vector2) -> Vector2:
	return Vector2(deg_to_rad(v.x), deg_to_rad(v.y))

func _ready() -> void:
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

func update(delta: float) -> void:

	if is_repositioning:
		update_reposition(delta)
	else:
		update_humanized_movement(delta)
		update_mouse_movement(delta)

func update_humanized_movement(delta: float) -> void:

	if !humanized_movement: return

	noise.frequency = humanize_freq
	position = base_position + Vector3(
		noise.get_noise_2d(noise_u, 0.0),
		noise.get_noise_2d(noise_u, 0.3),
		noise.get_noise_2d(noise_u, 0.6),
	) * humanize_amount
	noise_u += delta

func update_mouse_movement(_delta: float) -> void:

	if !mouse_controlled_pan_zoom: return

	# get mouse position as vector between (0, 0) and (1, 1)
	var mouse_position := get_viewport().get_mouse_position() / Vector2(get_window().size)
	var mouse_clicked := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var pan_smoothing := pan_smoothing_focused

	# ignore mouse positions outside this range (outside the window)
	if !is_mouse_position_in_window(mouse_position):
		pan_smoothing = pan_smoothing_unfocused
		mouse_position = Vector2(0.5, 0.5)

	# remap mouse position to be in range (-1, -1) to (1, 1). (0, 0) is center of the window.
	mouse_position = (mouse_position * 2.0) - Vector2(1.0, 1.0)

	var mouse_range := vdeg_to_rad(pan_range_zoomin) if mouse_clicked else vdeg_to_rad(pan_range_zoomout)
	var target_fov := fov_zoomin if mouse_clicked else fov_zoomout
	var target_dof := dof_zoomin if mouse_clicked else dof_zoomout
	var target_rotation := (
		base_rotation + Vector3(
			- mouse_position.y * mouse_range.y,
			- mouse_position.x * mouse_range.x,
			0)
	)

	# mouse panning/zoom controls
	rotation = lerp(rotation, target_rotation, pan_smoothing)
	fov = lerp(fov, target_fov, fov_smoothing)
	attributes.dof_blur_far_distance = lerp(attributes.dof_blur_far_distance, target_dof, 0.01)

func update_reposition(delta: float) -> void:
	if Input.is_action_pressed("cam_forward"):
		global_position -= global_transform.basis.z * delta * 10
	if Input.is_action_pressed("cam_back"):
		global_position += global_transform.basis.z * delta * 10
	if Input.is_action_pressed("cam_left"):
		global_position -= global_transform.basis.x * delta * 10
	if Input.is_action_pressed("cam_right"):
		global_position += global_transform.basis.x * delta * 10

func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_repositioning = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			is_repositioning = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			base_position = position
			base_rotation = rotation

	if is_repositioning:
		if event is InputEventMouseMotion:
			rotation.y -= event.relative.x * 0.001
			rotation.x -= event.relative.y * 0.001