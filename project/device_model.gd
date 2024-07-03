class_name DeviceModel extends StaticBody3D

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

@onready var keycap_up = %Keycap_Up
@onready var keycap_down = %Keycap_Down
@onready var keycap_left = %Keycap_Left
@onready var keycap_right = %Keycap_Right
@onready var keycap_shift = %Keycap_Shift
@onready var keycap_play = %Keycap_Play
@onready var keycap_option = %Keycap_Option
@onready var keycap_edit = %Keycap_Edit

@onready var home_keycap_up: Vector3 = keycap_up.position
@onready var home_keycap_down: Vector3 = keycap_down.position
@onready var home_keycap_left: Vector3 = keycap_left.position
@onready var home_keycap_right: Vector3 = keycap_right.position
@onready var home_keycap_shift: Vector3 = keycap_shift.position
@onready var home_keycap_play: Vector3 = keycap_play.position
@onready var home_keycap_option: Vector3 = keycap_option.position
@onready var home_keycap_edit: Vector3 = keycap_edit.position

func init(display: M8SceneDisplay):
	screen_material.set_shader_parameter("tex", display.m8_client.get_display_texture())
	display.m8_key_changed.connect(func(key, pressed):
		match key:
			"up":
				key_up=pressed
			"down":
				key_down=pressed
			"left":
				key_left=pressed
			"right":
				key_right=pressed
			"shift":
				key_shift=pressed
			"play":
				key_play=pressed
			"option":
				key_option=pressed
			"edit":
				key_edit=pressed
	)

func _ready() -> void:
	for keycap in [keycap_up, keycap_down, keycap_left, keycap_right, keycap_shift, keycap_play, keycap_option, keycap_edit]:
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
	keycap_up.material_overlay.albedo_color.a = 1.0 if key_up else 0.0
	keycap_down.material_overlay.albedo_color.a = 1.0 if key_down else 0.0
	keycap_left.material_overlay.albedo_color.a = 1.0 if key_left else 0.0
	keycap_right.material_overlay.albedo_color.a = 1.0 if key_right else 0.0
	keycap_shift.material_overlay.albedo_color.a = 1.0 if key_shift else 0.0
	keycap_play.material_overlay.albedo_color.a = 1.0 if key_play else 0.0
	keycap_option.material_overlay.albedo_color.a = 1.0 if key_option else 0.0
	keycap_edit.material_overlay.albedo_color.a = 1.0 if key_edit else 0.0

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
