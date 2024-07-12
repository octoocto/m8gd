class_name SceneMenu extends PanelContainer

const DEFAULT_PROFILE := "__main"

var main: M8SceneDisplay
var current_profile: String = DEFAULT_PROFILE
var current_scene: M8Scene

func init(p_main: M8SceneDisplay) -> void:
	main = p_main

	%ButtonFinish.pressed.connect(func() -> void:
		visible=false
		main.menu.visible=true
	)

func _scene_file_path() -> String:
	return current_scene.scene_file_path

func get_param_container() -> GridContainer:
	return %SceneParamsContainer

func clear_params() -> void:
	for c in get_param_container().get_children():
		get_param_container().remove_child(c)
		c.queue_free()

func push_param(left: Control, middle: Control, right: Control) -> void:
	get_param_container().add_child(left)
	get_param_container().add_child(middle)
	get_param_container().add_child(right)

func push_param_two(left: Control, right: Control) -> void:
	var empty_sep := VSeparator.new()
	empty_sep.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	get_param_container().add_child(left)
	get_param_container().add_child(empty_sep)
	get_param_container().add_child(right)

func read_params_from_scene(p_scene: M8Scene) -> void:

	var config := main.config
	current_scene = p_scene

	# add scene parameter dict to config if not exists
	if !config.scene_parameters.has(_scene_file_path()):
		config.scene_parameters[_scene_file_path()] = {}

	# clear menu
	clear_params()

	config_load_profile(DEFAULT_PROFILE)

	var regex := RegEx.new()
	regex.compile("^-?\\d+,-?\\d+$") # match "#,#" export_range patterns

	# add menu items
	var export_vars := current_scene.get_export_vars()
	for v: Dictionary in export_vars:
		var property: String = v.name
		if v.hint_string == "bool":
			push_scene_var_bool(property)
			continue
		if v.hint_string == "Color":
			push_scene_var_color(property)
			continue
		if v.hint_string == "float":
			push_scene_var_slider(property)
			continue

		if regex.search(v.hint_string):
			var range_min := int(v.hint_string.split(",")[0])
			var range_max := int(v.hint_string.split(",")[1])
			push_scene_var_int_slider(property, range_min, range_max)
			continue

		printerr("scene: unrecognized export var type: %s" % v.hint_string)

##
## Load a profile. Sets that profile name as the current.
##
func config_load_profile(profile_name: String) -> void:
	print("scene: %s: loading profile '%s'" % [_scene_file_path(), profile_name])
	current_profile = profile_name
	var export_vars := current_scene.get_export_vars()
	for v: Dictionary in export_vars:
		var property: String = v.name
		var default: Variant = current_scene.get(property)
		current_scene.set(property, config_get_property(property, default))

func config_get_profile(profile_name: String) -> Dictionary:
	if !main.config.scene_parameters[_scene_file_path()].has(profile_name):
		print("scene: initializing profile '%s'" % profile_name)
		main.config.scene_parameters[_scene_file_path()][profile_name] = {}

	var profile: Dictionary = main.config.scene_parameters[_scene_file_path()][profile_name]
	assert(profile is Dictionary)
	# print("scene: using profile '%s'" % profile_name)
	return profile

func config_delete_profile(profile_name: String) -> void:
	if main.config.scene_parameters[_scene_file_path()].has(profile_name):
		print("scene: deleting profile '%s'" % profile_name)
		main.config.scene_parameters[_scene_file_path()].erase(profile_name)

func config_get_property(property: String, default: Variant=null) -> Variant:
	var profile := config_get_profile(current_profile)

	# set parameter from config, or add parameter to config
	if !profile.has(property) or profile[property] == null:
		print("scene: %s: adding property '%s' to config" % [current_profile, property])
		profile[property] = default

	# print("scene: profile %s: get %s=%s" % [current_profile, property, profile[property]])

	return profile[property]

func config_set_property(property: String, value: Variant) -> void:
	var profile := config_get_profile(current_profile)

	current_scene.set(property, value) # FIXME: this line not needed if property not in scene
	profile[property] = value
	print("scene: profile %s: set %s=%s" % [current_profile, property, value])

func push_scene_var_bool(property: String) -> void:

	var label := Label.new()
	var button := CheckButton.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	button.button_pressed = current_scene.get(property)
	button.toggled.connect(func(toggled_on: bool) -> void:
		config_set_property(property, toggled_on)
	)

	push_param_two(label, button)

func push_scene_var_color(property: String) -> void:

	var label := Label.new()
	var button := ColorPickerButton.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	button.color = current_scene.get(property)
	button.color_changed.connect(func(color: Color) -> void:
		config_set_property(property, color)
	)

	push_param_two(label, button)

func push_scene_var_slider(property: String) -> void:

	var label := Label.new()
	var value_label := Label.new()
	var slider := HSlider.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND

	value_label.text = "%.2f" % current_scene.get(property)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	slider.custom_minimum_size.x = 80
	slider.max_value = 1.0
	slider.min_value = 0.0
	slider.step = 0.01
	slider.value = current_scene.get(property)
	slider.value_changed.connect(func(value: float) -> void:
		config_set_property(property, value)
		value_label.text="%.2f" % value
	)

	push_param(label, value_label, slider)

func push_scene_var_int_slider(property: String, range_min: int, range_max: int) -> void:

	var label := Label.new()
	var value_label := Label.new()
	var slider := HSlider.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND

	value_label.text = "%d" % current_scene.get(property)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	slider.custom_minimum_size.x = 80
	slider.max_value = range_max
	slider.min_value = range_min
	slider.step = 1
	slider.tick_count = range_max - range_min
	slider.ticks_on_borders = true
	slider.value = current_scene.get(property)
	slider.value_changed.connect(func(value: float) -> void:
		config_set_property(property, value)
		value_label.text="%d" % value
	)

	push_param(label, value_label, slider)
