class_name DeviceModel extends StaticBody3D

@export_enum("Model 01", "Model 02") var model := 0:
	set(value):
		model = value
		_update_model()

@export var highlight_opacity := 1.0

@export var key_up := false
@export var key_down := false
@export var key_left := false
@export var key_right := false
@export var key_shift := false
@export var key_play := false
@export var key_option := false
@export var key_edit := false

var _node_prefix := "M01_"

var _node_origin_positions := {}

@onready var screen_material: ShaderMaterial = %M01_Screen.material_override

func _ready() -> void:
	var keycaps := [
		%M01_KeyUpCap, %M01_KeyLeftCap, %M01_KeyRightCap, %M01_KeyDownCap,
		%M01_KeyOptionCap, %M01_KeyEditCap, %M01_KeyShiftCap, %M01_KeyPlayCap,
		%M02_KeyUpCap, %M02_KeyLeftCap, %M02_KeyRightCap, %M02_KeyDownCap,
		%M02_KeyOptionCap, %M02_KeyEditCap, %M02_KeyShiftCap, %M02_KeyPlayCap
	]
	for keycap: MeshInstance3D in keycaps:
		keycap.material_override = keycap.material_override.duplicate()
		keycap.material_overlay = keycap.material_overlay.duplicate()
		_node_origin_positions[keycap] = keycap.position

	# %M02_Screen.material_override = %M01_Screen.material_override
	_update_model()

func _physics_process(_delta: float) -> void:
	# translation of keys that are pressed
	var pressed_trans := Vector3(0, -0.15, 0)
	var press_speed := 0.3

	var key_u: MeshInstance3D = get_node(_node_prefix + "KeyUpCap")
	var key_d: MeshInstance3D = get_node(_node_prefix + "KeyDownCap")
	var key_l: MeshInstance3D = get_node(_node_prefix + "KeyLeftCap")
	var key_r: MeshInstance3D = get_node(_node_prefix + "KeyRightCap")
	var key_o: MeshInstance3D = get_node(_node_prefix + "KeyOptionCap")
	var key_e: MeshInstance3D = get_node(_node_prefix + "KeyEditCap")
	var key_s: MeshInstance3D = get_node(_node_prefix + "KeyShiftCap")
	var key_p: MeshInstance3D = get_node(_node_prefix + "KeyPlayCap")

	# animate keycap positions if pressed/unpressed
	key_u.position = lerp(key_u.position, _node_origin_positions[key_u] + int(key_up) * pressed_trans, press_speed)
	key_d.position = lerp(key_d.position, _node_origin_positions[key_d] + int(key_down) * pressed_trans, press_speed)
	key_l.position = lerp(key_l.position, _node_origin_positions[key_l] + int(key_left) * pressed_trans, press_speed)
	key_r.position = lerp(key_r.position, _node_origin_positions[key_r] + int(key_right) * pressed_trans, press_speed)
	key_o.position = lerp(key_o.position, _node_origin_positions[key_o] + int(key_option) * pressed_trans, press_speed)
	key_e.position = lerp(key_e.position, _node_origin_positions[key_e] + int(key_edit) * pressed_trans, press_speed)
	key_s.position = lerp(key_s.position, _node_origin_positions[key_s] + int(key_shift) * pressed_trans, press_speed)
	key_p.position = lerp(key_p.position, _node_origin_positions[key_p] + int(key_play) * pressed_trans, press_speed)

	# animate keycap colors if pressed/unpressed
	key_u.material_overlay.albedo_color.a = highlight_opacity if key_up else 0.0
	key_d.material_overlay.albedo_color.a = highlight_opacity if key_down else 0.0
	key_l.material_overlay.albedo_color.a = highlight_opacity if key_left else 0.0
	key_r.material_overlay.albedo_color.a = highlight_opacity if key_right else 0.0
	key_o.material_overlay.albedo_color.a = highlight_opacity if key_option else 0.0
	key_e.material_overlay.albedo_color.a = highlight_opacity if key_edit else 0.0
	key_s.material_overlay.albedo_color.a = highlight_opacity if key_shift else 0.0
	key_p.material_overlay.albedo_color.a = highlight_opacity if key_play else 0.0

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

	main.m8_client.system_info.connect(func(hw: String, _fw: String) -> void:
		model = 1 if hw == "model_02" else 0
	)

##
## Sets the color of a key cap. [key_name] must be capitalized and
## be the name of one of the M8 keys (ex: "Up").
##
func set_key_cap_color(key_name: String, color: Color) -> void:
	get_node("%M01_Key{0}Cap".format([key_name])).material_override.albedo_color = color
	get_node("%M02_Key{0}Cap".format([key_name])).material_override.albedo_color = color

##
## Sets the highlight color of a key cap (the color to show when the key is pressed).
## [key_name] must be capitalized and be the name of one of the M8 keys (ex: "Up").
##
## If the highlight color of a directional key is changed, this will also change the highlight color
## of the other directional keys.
##
func set_key_highlight_color(key_name: String, color: Color) -> void:
	if key_name in ["Up", "Down", "Left", "Right"]:
		set_dir_key_highlight_color(color)
	else:
		var c: Color = get_node("%M01_Key{0}Cap".format([key_name])).material_overlay.albedo_color
		get_node("%M01_Key{0}Cap".format([key_name])).material_overlay.albedo_color = Color(color, c.a)
		get_node("%M02_Key{0}Cap".format([key_name])).material_overlay.albedo_color = Color(color, c.a)

func set_dir_key_highlight_color(color: Color) -> void:
	var colors: Array[Color] = [
		%M01_KeyUpCap.material_overlay.albedo_color,
		%M01_KeyDownCap.material_overlay.albedo_color,
		%M01_KeyLeftCap.material_overlay.albedo_color,
		%M01_KeyRightCap.material_overlay.albedo_color,
		%M02_KeyUpCap.material_overlay.albedo_color,
		%M02_KeyDownCap.material_overlay.albedo_color,
		%M02_KeyLeftCap.material_overlay.albedo_color,
		%M02_KeyRightCap.material_overlay.albedo_color
	]
	%M01_KeyUpCap.material_overlay.albedo_color = Color(color, colors[0].a)
	%M01_KeyDownCap.material_overlay.albedo_color = Color(color, colors[1].a)
	%M01_KeyLeftCap.material_overlay.albedo_color = Color(color, colors[2].a)
	%M01_KeyRightCap.material_overlay.albedo_color = Color(color, colors[3].a)
	%M02_KeyUpCap.material_overlay.albedo_color = Color(color, colors[4].a)
	%M02_KeyDownCap.material_overlay.albedo_color = Color(color, colors[5].a)
	%M02_KeyLeftCap.material_overlay.albedo_color = Color(color, colors[6].a)
	%M02_KeyRightCap.material_overlay.albedo_color = Color(color, colors[7].a)

func set_part_color(part_name: String, color: Color) -> void:
	get_node("%M01_{0}".format([part_name])).material_override.albedo_color = color
	get_node("%M02_{0}".format([part_name])).material_override.albedo_color = color

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

func _update_model() -> void:
	if not is_inside_tree(): return
	_node_prefix = "M01_" if model == 0 else "M02_"
	for child in get_children():
		child.visible = child.name.begins_with(_node_prefix)
		if child.name.ends_with("Stem"): # hide switch stems
			child.visible = false
