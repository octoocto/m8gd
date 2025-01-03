@tool
class_name M8SceneCamera3D extends Node3D

# Emitted when any of the camera properties change.
signal camera_updated

# Emitted when the camera is repositioning (right-click pressed).
signal reposition_started

# Emitted when the camera has stopped repositioning (right-click unpressed).
signal reposition_stopped


@export var mouse_controlled_pan_zoom := true

@export var humanized_movement := true
@export var humanize_freq := 1.0
@export var humanize_amount := 0.05

@export var pan_smoothing_focused := 0.05
@export var pan_smoothing_unfocused := 0.01

@export var fov_smoothing := 0.05

@export var pan_range_zoomout := Vector2(5, 2)
@export var pan_range_zoomin := Vector2(15, 10)

@export var cam_pan_range_zoomout := Vector2(0, 0)
@export var cam_pan_range_zoomin := Vector2(0, 0)

@export var fov_zoomout := 30.0
@export var fov_zoomin := 15.0

@export var dof_zoomout := 1.5
@export var dof_zoomin := 0.5

@export var dof_focus_distance := 13.5:
	set(value):
		dof_focus_distance = value
		if is_inside_tree():
			%Camera3D.attributes.dof_blur_far_distance = value + dof_focus_width
			%Camera3D.attributes.dof_blur_near_distance = value - dof_focus_width

@export_range(-0.5, 100, 0.1) var dof_focus_width := 1.5:
	set(value):
		dof_focus_width = value
		if is_inside_tree():
			%Camera3D.attributes.dof_blur_far_distance = dof_focus_distance + value
			%Camera3D.attributes.dof_blur_near_distance = dof_focus_distance - value

@export_range(0.0, 1.0, 0.01) var dof_blur_amount := 0.18:
	set(value):
		dof_blur_amount = value
		if is_inside_tree():
			%Camera3D.attributes.dof_blur_amount = value

@export var arm_length := 0.0:
	set(value):
		arm_length = value
		if is_inside_tree():
			%Camera3D.position.z = arm_length

@onready var main: Main
@onready var cam: Camera3D = %Camera3D

@onready var base_rotation := rotation
@onready var base_position := position

@onready var noise: FastNoiseLite = FastNoiseLite.new()
@onready var noise_u: float = 0.0

var rclick_pressed := false

func is_between(x: float, a: float, b: float) -> bool:
	return a < x and x < b

func is_mouse_position_in_window(mouse_position: Vector2) -> bool:
	return is_between(mouse_position.x, -1.0, 1.0) and is_between(mouse_position.y, -1.0, 1.0)

func vdeg_to_rad(v: Vector2) -> Vector2:
	return Vector2(deg_to_rad(v.x), deg_to_rad(v.y))

func _ready() -> void:
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

func init(p_main: Main) -> void:
	main = p_main

func update(delta: float) -> void:

	if main.menu_camera.visible or main.menu_scene.visible:
		update_reposition(delta)
	elif !main.is_any_menu_open():
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

	var mouse_position := _mouse_position()
	var mouse_clicked := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	var target_fov := fov_zoomin if mouse_clicked else fov_zoomout
	var target_dof := dof_zoomin if mouse_clicked else dof_zoomout

	# mouse panning/zoom controls
	rotation = _new_rotation(mouse_position, mouse_clicked)
	cam.rotation = _new_cam_rotation(mouse_position, mouse_clicked)
	cam.fov = lerp(cam.fov, target_fov, fov_smoothing)
	dof_focus_width = lerp(dof_focus_width, target_dof, 0.1)

##
## Get the mouse position in the window in the range (-1, -1) to (1, 1),
## where (0, 0) is the center of the window.
##
func _mouse_position() -> Vector2:

	# get mouse position as vector between (0, 0) and (1, 1)
	var mouse_position := get_viewport().get_mouse_position() / Vector2(get_window().size)

	# remap mouse position to be in range (-1, -1) to (1, 1). (0, 0) is center of the window.
	mouse_position = (mouse_position * 2.0) - Vector2(1.0, 1.0)

	# ignore mouse positions outside this range (outside the window)
	if !is_mouse_position_in_window(mouse_position):
		return Vector2.ZERO
	else:
		return mouse_position

func _new_cam_rotation(mouse_position: Vector2, mouse_clicked: bool) -> Vector3:

	var pan_range := (
		vdeg_to_rad(cam_pan_range_zoomin)
		if mouse_clicked
		else vdeg_to_rad(cam_pan_range_zoomout)
	)

	var target_rotation := (
		Vector3(
			- mouse_position.y * pan_range.y,
			- mouse_position.x * pan_range.x,
			0)
	)

	return lerp(cam.rotation, target_rotation, 0.1)

func _new_rotation(mouse_position: Vector2, mouse_clicked: bool) -> Vector3:

	var pan_range := (
		vdeg_to_rad(pan_range_zoomin)
		if mouse_clicked
		else vdeg_to_rad(pan_range_zoomout)
	)

	var pan_smoothing := (
		pan_smoothing_focused
		if is_mouse_position_in_window(mouse_position)
		else pan_smoothing_unfocused
	)

	var target_rotation := (
		base_rotation + Vector3(
			- mouse_position.y * pan_range.y,
			- mouse_position.x * pan_range.x,
			0)
	)

	return lerp(rotation, target_rotation, pan_smoothing)

func update_reposition(delta: float) -> void:

	if (main.menu_camera.visible or main.menu_scene.visible) and rclick_pressed:
		if Input.is_action_pressed("cam_forward"):
			global_position -= global_transform.basis.z * delta * 10
		if Input.is_action_pressed("cam_back"):
			global_position += global_transform.basis.z * delta * 10
		if Input.is_action_pressed("cam_left"):
			global_position -= global_transform.basis.x * delta * 10
		if Input.is_action_pressed("cam_right"):
			global_position += global_transform.basis.x * delta * 10

		camera_updated.emit()

func reposition_start() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rclick_pressed = true
	main.cam_help.visible = true
	if main.menu_scene.visible:
		main.menu_camera.menu_open_as_info()
	reposition_started.emit()

func reposition_stop() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rclick_pressed = false
	main.cam_help.visible = false
	set_current_transform_as_base()
	if main.menu_scene.visible:
		main.menu_camera.menu_close()
	reposition_stopped.emit()

func _input(event: InputEvent) -> void:

	if main.menu_camera.visible or main.menu_scene.visible:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				reposition_start()
			else:
				reposition_stop()

		if rclick_pressed:
			if event is InputEventMouseMotion:
				rotation.y -= event.relative.x * 0.001
				rotation.x -= event.relative.y * 0.001
		
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					dof_focus_distance += 0.1
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					dof_focus_distance -= 0.1

			camera_updated.emit()

	elif rclick_pressed:
		reposition_stop()

func set_transform_to_base() -> void:
	position = base_position
	rotation = base_rotation
	cam.rotation = Vector3.ZERO
	cam.fov = fov_zoomout

func set_current_transform_as_base() -> void:
	base_position = position
	base_rotation = rotation
	dof_zoomout = dof_focus_width