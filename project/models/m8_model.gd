class_name DeviceModel extends StaticBody3D

@export var model_auto := true:
	set(value):
		model_auto = value
		if value:
			_auto_model_type()

@export_enum("M8 M:01", "M8 M:02") var model := 0:
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

@onready var m01_screen: MeshInstance3D = %M01_Screen
@onready var m02_screen: MeshInstance3D = %M02_Screen

var main: Main

var _node_prefix := "M01_"

var _node_origin_positions := {}

@onready var screen_material: ShaderMaterial = m01_screen.material_override


func _ready() -> void:
	var keycaps := [
		%M01_KeyUpCap,
		%M01_KeyLeftCap,
		%M01_KeyRightCap,
		%M01_KeyDownCap,
		%M01_KeyOptionCap,
		%M01_KeyEditCap,
		%M01_KeyShiftCap,
		%M01_KeyPlayCap,
		%M02_KeyUpCap,
		%M02_KeyLeftCap,
		%M02_KeyRightCap,
		%M02_KeyDownCap,
		%M02_KeyOptionCap,
		%M02_KeyEditCap,
		%M02_KeyShiftCap,
		%M02_KeyPlayCap
	]
	for keycap: MeshInstance3D in keycaps:
		keycap.material_override = keycap.material_override.duplicate()
		keycap.material_overlay = keycap.material_overlay.duplicate()
		_node_origin_positions[keycap] = keycap.position

	# %M02_Screen.material_override = %M01_Screen.material_override


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

	var key_u_material: StandardMaterial3D = key_u.material_overlay
	var key_d_material: StandardMaterial3D = key_d.material_overlay
	var key_l_material: StandardMaterial3D = key_l.material_overlay
	var key_r_material: StandardMaterial3D = key_r.material_overlay
	var key_o_material: StandardMaterial3D = key_o.material_overlay
	var key_e_material: StandardMaterial3D = key_e.material_overlay
	var key_s_material: StandardMaterial3D = key_s.material_overlay
	var key_p_material: StandardMaterial3D = key_p.material_overlay

	# animate keycap positions if pressed/unpressed
	key_u.position = lerp(
		key_u.position, _node_origin_positions[key_u] + int(key_up) * pressed_trans, press_speed
	)
	key_d.position = lerp(
		key_d.position, _node_origin_positions[key_d] + int(key_down) * pressed_trans, press_speed
	)
	key_l.position = lerp(
		key_l.position, _node_origin_positions[key_l] + int(key_left) * pressed_trans, press_speed
	)
	key_r.position = lerp(
		key_r.position, _node_origin_positions[key_r] + int(key_right) * pressed_trans, press_speed
	)
	key_o.position = lerp(
		key_o.position, _node_origin_positions[key_o] + int(key_option) * pressed_trans, press_speed
	)
	key_e.position = lerp(
		key_e.position, _node_origin_positions[key_e] + int(key_edit) * pressed_trans, press_speed
	)
	key_s.position = lerp(
		key_s.position, _node_origin_positions[key_s] + int(key_shift) * pressed_trans, press_speed
	)
	key_p.position = lerp(
		key_p.position, _node_origin_positions[key_p] + int(key_play) * pressed_trans, press_speed
	)

	# animate keycap colors if pressed/unpressed
	key_u_material.albedo_color.a = highlight_opacity if key_up else 0.0
	key_d_material.albedo_color.a = highlight_opacity if key_down else 0.0
	key_l_material.albedo_color.a = highlight_opacity if key_left else 0.0
	key_r_material.albedo_color.a = highlight_opacity if key_right else 0.0
	key_o_material.albedo_color.a = highlight_opacity if key_option else 0.0
	key_e_material.albedo_color.a = highlight_opacity if key_edit else 0.0
	key_s_material.albedo_color.a = highlight_opacity if key_shift else 0.0
	key_p_material.albedo_color.a = highlight_opacity if key_play else 0.0


func init(p_main: Main) -> void:
	main = p_main

	screen_material.set_shader_parameter("texture_linear", main.m8c.get_display_texture())
	screen_material.set_shader_parameter("texture_nearest", main.m8c.get_display_texture())

	main.m8_connected.connect(
		func() -> void: screen_material.set_shader_parameter("backlight", true)
	)

	main.m8_disconnected.connect(
		func() -> void: screen_material.set_shader_parameter("backlight", false)
	)

	screen_material.set_shader_parameter("backlight", false)

	main.m8c.key_pressed.connect(
		func(key: int, pressed: bool) -> void:
			match key:
				LibM8.KEY_UP:
					key_up = pressed
				LibM8.KEY_DOWN:
					key_down = pressed
				LibM8.KEY_LEFT:
					key_left = pressed
				LibM8.KEY_RIGHT:
					key_right = pressed
				LibM8.KEY_OPTION:
					key_option = pressed
				LibM8.KEY_EDIT:
					key_edit = pressed
				LibM8.KEY_SHIFT:
					key_shift = pressed
				LibM8.KEY_PLAY:
					key_play = pressed
	)

	main.m8c.system_info_received.connect(
		func(_hw: String, _fw: String) -> void: _auto_model_type()
	)

	_update_model()


##
## Sets the color of a key cap. [key_name] must be capitalized and
## be the name of one of the M8 keys (ex: "Up").
##
func set_key_cap_color(key_name: String, color: Color) -> void:
	var m01_keycap: MeshInstance3D = get_node("%M01_Key{0}Cap".format([key_name]))
	var m02_keycap: MeshInstance3D = get_node("%M02_Key{0}Cap".format([key_name]))
	var m01_material: StandardMaterial3D = m01_keycap.material_override
	var m02_material: StandardMaterial3D = m02_keycap.material_override
	m01_material.albedo_color = color
	m02_material.albedo_color = color


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
		return

	var m01_keycap: MeshInstance3D = get_node("%M01_Key{0}Cap".format([key_name]))
	var m02_keycap: MeshInstance3D = get_node("%M02_Key{0}Cap".format([key_name]))
	var m01_material: StandardMaterial3D = m01_keycap.material_overlay
	var m02_material: StandardMaterial3D = m02_keycap.material_overlay
	var c: Color = m01_material.albedo_color
	m01_material.albedo_color = Color(color, c.a)
	m02_material.albedo_color = Color(color, c.a)


func set_dir_key_highlight_color(color: Color) -> void:
	var keycaps := [
		%M01_KeyUpCap,
		%M01_KeyDownCap,
		%M01_KeyLeftCap,
		%M01_KeyRightCap,
		%M02_KeyUpCap,
		%M02_KeyDownCap,
		%M02_KeyLeftCap,
		%M02_KeyRightCap
	]
	for keycap: MeshInstance3D in keycaps:
		var material: StandardMaterial3D = keycap.material_overlay
		material.albedo_color = Color(color, material.albedo_color.a)


func set_part_color(part_name: String, color: Color) -> void:
	var m01_part: MeshInstance3D = get_node("%M01_{0}".format([part_name]))
	var m02_part: MeshInstance3D = get_node("%M02_{0}".format([part_name]))
	var m01_material: StandardMaterial3D = m01_part.material_override
	var m02_material: StandardMaterial3D = m02_part.material_override
	m01_material.albedo_color = color
	m02_material.albedo_color = color


func get_part_color(part_name: String) -> Color:
	var m01_part: MeshInstance3D = get_node("%M01_{0}".format([part_name]))
	var m01_material: StandardMaterial3D = m01_part.material_override
	return m01_material.albedo_color


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


func _auto_model_type() -> void:
	if not is_inside_tree():
		return
	if model_auto:
		model = 1 if main.m8c.get_hardware_name() == "model_02" else 0


func _update_model() -> void:
	if not is_inside_tree():
		return

	# update 3D model
	_node_prefix = "M01_" if model == 0 else "M02_"
	for child: Node in get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			mesh.visible = mesh.name.begins_with(_node_prefix)
			if mesh.name.ends_with("Stem"):  # hide switch stems
				mesh.visible = false

	set_part_color("Body", main.config.get_color(&"model_color_body"))

	# update 3D model screen
	set_screen_filter(main.config.get_value_model(&"model_screen_linear_filter", true) as bool)
	set_screen_emission(main.config.get_value_model(&"model_screen_emission", 0.5) as float)

	# update keycap colors
	for key_name: String in ["Up", "Down", "Left", "Right", "Option", "Edit", "Shift", "Play"]:
		var property := StringName("model_color_key_%s" % key_name.to_lower())
		set_key_cap_color(key_name, main.config.get_color(property))

	# update highlight colors
	for key_name: String in ["Up", "Down", "Left", "Right"]:
		var property := StringName("hl_color_directional")
		set_key_highlight_color(key_name, main.config.get_color(property))

	for key_name: String in ["Option", "Edit", "Shift", "Play"]:
		var property := StringName("hl_color_%s" % key_name.to_lower())
		set_key_highlight_color(key_name, main.config.get_color(property))

	highlight_opacity = main.config.get_value_model(&"model_hl_opacity", 1.0)

	print("m8_model.gd: updated model")
