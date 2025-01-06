class_name DeviceModel extends StaticBody3D

@export var highlight_opacity := 1.0

@export var key_up := false
@export var key_down := false
@export var key_left := false
@export var key_right := false
@export var key_shift := false
@export var key_play := false
@export var key_option := false
@export var key_edit := false

@onready var screen_material: ShaderMaterial = %Screen.material_override

func _ready() -> void:
	for keycap: MeshInstance3D in get_keycaps():
		keycap.material_override = keycap.material_override.duplicate()
		keycap.material_overlay = keycap.material_overlay.duplicate()

func _physics_process(_delta: float) -> void:
	# translation of keys that are pressed
	var pressed_trans := Vector3(0, -0.15, 0)
	var press_speed := 0.3

	# animate keycap positions if pressed/unpressed
	%KeyUp.position = lerp(%KeyUp.position, int(key_up) * pressed_trans, press_speed)
	%KeyDown.position = lerp(%KeyDown.position, int(key_down) * pressed_trans, press_speed)
	%KeyLeft.position = lerp(%KeyLeft.position, int(key_left) * pressed_trans, press_speed)
	%KeyRight.position = lerp(%KeyRight.position, int(key_right) * pressed_trans, press_speed)
	%KeyShift.position = lerp(%KeyShift.position, int(key_shift) * pressed_trans, press_speed)
	%KeyPlay.position = lerp(%KeyPlay.position, int(key_play) * pressed_trans, press_speed)
	%KeyOption.position = lerp(%KeyOption.position, int(key_option) * pressed_trans, press_speed)
	%KeyEdit.position = lerp(%KeyEdit.position, int(key_edit) * pressed_trans, press_speed)

	# animate keycap colors if pressed/unpressed
	%KeyUp.material_overlay.albedo_color.a = highlight_opacity if key_up else 0.0
	%KeyDown.material_overlay.albedo_color.a = highlight_opacity if key_down else 0.0
	%KeyLeft.material_overlay.albedo_color.a = highlight_opacity if key_left else 0.0
	%KeyRight.material_overlay.albedo_color.a = highlight_opacity if key_right else 0.0
	%KeyShift.material_overlay.albedo_color.a = highlight_opacity if key_shift else 0.0
	%KeyPlay.material_overlay.albedo_color.a = highlight_opacity if key_play else 0.0
	%KeyOption.material_overlay.albedo_color.a = highlight_opacity if key_option else 0.0
	%KeyEdit.material_overlay.albedo_color.a = highlight_opacity if key_edit else 0.0

func init(main: Main) -> void:

	screen_material.set_shader_parameter("texture_linear", main.m8_client.get_display())
	screen_material.set_shader_parameter("texture_nearest", main.m8_client.get_display())

	main.m8_connected.connect(func() -> void:
		screen_material.set_shader_parameter("backlight", true)
	)

	main.m8_disconnected.connect(func() -> void:
		screen_material.set_shader_parameter("backlight", false)
	)

	screen_material.set_shader_parameter("backlight", main.m8_is_connected)

	screen_material.set_shader_parameter("use_linear_filter", main.config.model_use_linear_filter)

	main.m8_client.key_pressed.connect(func(key: int, pressed: bool) -> void:
		match key:
			M8GD.M8_KEY_UP:
				key_up = pressed
			M8GD.M8_KEY_DOWN:
				key_down = pressed
			M8GD.M8_KEY_LEFT:
				key_left = pressed
			M8GD.M8_KEY_RIGHT:
				key_right = pressed
			M8GD.M8_KEY_OPTION:
				key_option = pressed
			M8GD.M8_KEY_EDIT:
				key_edit = pressed
			M8GD.M8_KEY_SHIFT:
				key_shift = pressed
			M8GD.M8_KEY_PLAY:
				key_play = pressed
	)

func get_keycaps() -> Array:
	return [
		%KeyUp, %KeyDown, %KeyLeft, %KeyRight,
		%KeyOption, %KeyEdit, %KeyShift, %KeyPlay
	]

##
## Sets the texture filter of the screen material.
##
func set_screen_filter(use_linear_filter: bool) -> void:
	screen_material.set_shader_parameter("use_linear_filter", use_linear_filter)

##
## Sets the emission of the screen material. This gives the screen a "backlight" effect.
##
func set_screen_emission(emission: float) -> void:
	screen_material.set_shader_parameter("emission_amount", emission)
