class_name DeviceModel extends StaticBody3D

@export var highlight_opacity := 1.0

@export var screw_material: Material
@export var body_material: Material
@export var bezel_material: Material
@export var screen_bezel_material: Material
@export var screen_material: ShaderMaterial
@export var keycap_material: Material
# @export var outline_color: Color:
#	 set(value):
#		 outline_color = value
#		 %BodyOutline.material_override.albedo_color = value

@export var key_up := false
@export var key_down := false
@export var key_left := false
@export var key_right := false
@export var key_shift := false
@export var key_play := false
@export var key_option := false
@export var key_edit := false

@onready var keycap_up: MeshInstance3D = %Keycap_Up
@onready var keycap_down: MeshInstance3D = %Keycap_Down
@onready var keycap_left: MeshInstance3D = %Keycap_Left
@onready var keycap_right: MeshInstance3D = %Keycap_Right
@onready var keycap_shift: MeshInstance3D = %Keycap_Shift
@onready var keycap_play: MeshInstance3D = %Keycap_Play
@onready var keycap_option: MeshInstance3D = %Keycap_Option
@onready var keycap_edit: MeshInstance3D = %Keycap_Edit

@onready var home_keycap_up: Vector3 = keycap_up.position
@onready var home_keycap_down: Vector3 = keycap_down.position
@onready var home_keycap_left: Vector3 = keycap_left.position
@onready var home_keycap_right: Vector3 = keycap_right.position
@onready var home_keycap_shift: Vector3 = keycap_shift.position
@onready var home_keycap_play: Vector3 = keycap_play.position
@onready var home_keycap_option: Vector3 = keycap_option.position
@onready var home_keycap_edit: Vector3 = keycap_edit.position

func init(main: Main) -> void:

	screen_material.set_shader_parameter("texture_linear", main.m8_client.get_display_texture())
	screen_material.set_shader_parameter("texture_nearest", main.m8_client.get_display_texture())

	main.m8_connected.connect(func() -> void:
		screen_material.set_shader_parameter("backlight", true)
	)

	main.m8_disconnected.connect(func() -> void:
		screen_material.set_shader_parameter("backlight", false)
	)

	if main.m8_is_connected:
		screen_material.set_shader_parameter("backlight", true)

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
		keycap_up, keycap_down, keycap_left, keycap_right,
		keycap_option, keycap_edit, keycap_shift, keycap_play
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

func _ready() -> void:
	for keycap: MeshInstance3D in get_keycaps():
		keycap.material_override = keycap.material_override.duplicate()
		keycap.material_overlay = keycap.material_overlay.duplicate()

func _physics_process(_delta: float) -> void:
	
	# translation of keys that are pressed
	var pressed_trans := Vector3(0, -0.003, 0)
	var press_speed := 0.3

	# animate keycap positions if pressed/unpressed
	keycap_up.position = lerp(keycap_up.position, home_keycap_up + int(key_up) * pressed_trans, press_speed)
	keycap_down.position = lerp(keycap_down.position, home_keycap_down + int(key_down) * pressed_trans, press_speed)
	keycap_left.position = lerp(keycap_left.position, home_keycap_left + int(key_left) * pressed_trans, press_speed)
	keycap_right.position = lerp(keycap_right.position, home_keycap_right + int(key_right) * pressed_trans, press_speed)
	keycap_shift.position = lerp(keycap_shift.position, home_keycap_shift + int(key_shift) * pressed_trans, press_speed)
	keycap_play.position = lerp(keycap_play.position, home_keycap_play + int(key_play) * pressed_trans, press_speed)
	keycap_option.position = lerp(keycap_option.position, home_keycap_option + int(key_option) * pressed_trans, press_speed)
	keycap_edit.position = lerp(keycap_edit.position, home_keycap_edit + int(key_edit) * pressed_trans, press_speed)

	# animate keycap colors if pressed/unpressed
	keycap_up.material_overlay.albedo_color.a = highlight_opacity if key_up else 0.0
	keycap_down.material_overlay.albedo_color.a = highlight_opacity if key_down else 0.0
	keycap_left.material_overlay.albedo_color.a = highlight_opacity if key_left else 0.0
	keycap_right.material_overlay.albedo_color.a = highlight_opacity if key_right else 0.0
	keycap_shift.material_overlay.albedo_color.a = highlight_opacity if key_shift else 0.0
	keycap_play.material_overlay.albedo_color.a = highlight_opacity if key_play else 0.0
	keycap_option.material_overlay.albedo_color.a = highlight_opacity if key_option else 0.0
	keycap_edit.material_overlay.albedo_color.a = highlight_opacity if key_edit else 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		match event.keycode:
			KEY_UP:
				key_up = event.pressed
			KEY_DOWN:
				key_down = event.pressed
			KEY_LEFT:
				key_left = event.pressed
			KEY_RIGHT:
				key_right = event.pressed
			KEY_SHIFT:
				key_shift = event.pressed
			KEY_SPACE: # play
				key_play = event.pressed
			KEY_Z: # option
				key_option = event.pressed
			KEY_X: # edit
				key_edit = event.pressed
