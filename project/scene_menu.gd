class_name SceneMenu extends PanelContainer

const DEFAULT_PROFILE := "__main"

var main: M8SceneDisplay
var scene: M8Scene

func init(p_main: M8SceneDisplay) -> void:
	main = p_main

	%ButtonFinish.pressed.connect(func() -> void:
		visible=false
		main.menu.visible=true
	)

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
	scene = p_scene

	# add scene parameter dict to config if not exists
	if !config.scene_parameters.has(scene_file_path):
		config.scene_parameters[scene_file_path] = {}

	# clear menu
	clear_params()

	config_load_profile(DEFAULT_PROFILE)

	var regex := RegEx.new()
	regex.compile("^-?\\d+,-?\\d+$") # match "#,#" export_range patterns

	# add menu items
	var export_vars := scene.get_export_vars()
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

func config_get_profile(profile_name: String) -> Dictionary:
	if !main.config.scene_parameters[scene_file_path].has(profile_name):
		print("scene: initializing profile '%s'" % profile_name)
		main.config.scene_parameters[scene_file_path][profile_name] = {}

	var profile: Dictionary = main.config.scene_parameters[scene_file_path][profile_name]
	assert(profile is Dictionary)
	# print("scene: using profile '%s'" % profile_name)
	return profile

func config_delete_profile(profile_name: String) -> void:
	if main.config.scene_parameters[scene_file_path].has(profile_name):
		print("scene: deleting profile '%s'" % profile_name)
		main.config.scene_parameters[scene_file_path].erase(profile_name)

func config_load_profile(profile_name: String) -> void:
	print("scene: %s: loading profile '%s'" % [scene_file_path, profile_name])
	var export_vars := scene.get_export_vars()
	for v: Dictionary in export_vars:
		var property: String = v.name
		set(property, config_get_property(profile_name, property))

func config_get_property(profile_name: String, property: String) -> Variant:
	var profile := config_get_profile(profile_name)

	# set parameter from config, or add parameter to config
	if profile.has(property):
		print("scene: %s: setting property '%s' from config" % [profile_name, property])
	else:
		print("scene: %s: adding property '%s' to config" % [profile_name, property])
		profile[property] = get(property)

	return profile[property]

func config_update_property(profile_name: String, property: String) -> void:
	print("scene: updating property '%s' in config" % property)
	config_get_profile(profile_name)[property] = get(property)

func push_scene_var_bool(property: String) -> void:

	var label := Label.new()
	var button := CheckButton.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	button.button_pressed = scene.get(property)
	button.toggled.connect(func(toggled_on: bool) -> void:
		scene.set(property, toggled_on)
		config_update_property(DEFAULT_PROFILE, property)
	)

	push_param_two(label, button)

func push_scene_var_color(property: String) -> void:

	var label := Label.new()
	var button := ColorPickerButton.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	button.color = scene.get(property)
	button.color_changed.connect(func(color: Color) -> void:
		scene.set(property, color)
		config_update_property(DEFAULT_PROFILE, property)
	)

	push_param_two(label, button)

func push_scene_var_slider(property: String) -> void:

	var label := Label.new()
	var value_label := Label.new()
	var slider := HSlider.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND

	value_label.text = "%.2f" % scene.get(property)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	slider.custom_minimum_size.x = 80
	slider.max_value = 1.0
	slider.min_value = 0.0
	slider.step = 0.01
	slider.value = scene.get(property)
	slider.value_changed.connect(func(value: float) -> void:
		scene.set(property, value)
		config_update_property(DEFAULT_PROFILE, property)
		value_label.text="%.2f" % value
	)

	push_param(label, value_label, slider)

func push_scene_var_int_slider(property: String, range_min: int, range_max: int) -> void:

	var label := Label.new()
	var value_label := Label.new()
	var slider := HSlider.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND

	value_label.text = "%d" % scene.get(property)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	slider.custom_minimum_size.x = 80
	slider.max_value = range_max
	slider.min_value = range_min
	slider.step = 1
	slider.tick_count = range_max - range_min
	slider.ticks_on_borders = true
	slider.value = scene.get(property)
	slider.value_changed.connect(func(value: float) -> void:
		scene.set(property, value)
		config_update_property(DEFAULT_PROFILE, property)
		value_label.text="%d" % value
	)

	push_param(label, value_label, slider)
