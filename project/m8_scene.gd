class_name M8Scene extends Node3D

const DEFAULT_PROFILE = "__main"

# const COLOR_SAMPLE_POINT_1 := Vector2i(0, 0)
# const COLOR_SAMPLE_POINT_2 := Vector2i(19, 67)
# const COLOR_SAMPLE_POINT_3 := Vector2i(400, 67)

# @export var receiver_texture: ImageTexture

## 3 colors sampled from the m8's display texture
# @export var color_fg: Color
# @export var color_fg2: Color
# @export var color_bg: Color

var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance

var main: M8SceneDisplay

func init(p_main: M8SceneDisplay) -> void:
	main = p_main

	var config: M8Config = main.config

	# populate scene parameters in menu

	# add scene parameter dict to config if not exists
	if !config.scene_parameters.has(scene_file_path):
		config.scene_parameters[scene_file_path] = {}

	# clear menu
	clear_scene_vars()

	config_load_profile(DEFAULT_PROFILE)

	var regex := RegEx.new()
	regex.compile("^-?\\d+,-?\\d+$") # match "#,#" export_range patterns

	# add menu items
	var export_vars := get_export_vars()
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

func clear_scene_vars() -> void:
	var grid: GridContainer = main.menu.get_node("%ContainerSceneVars")

	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()

func push_scene_var_bool(property: String) -> void:
	var grid: GridContainer = main.menu.get_node("%ContainerSceneVars")

	var label := Label.new()
	var sep := VSeparator.new()
	var button := CheckButton.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	button.button_pressed = get(property)
	button.toggled.connect(func(toggled_on: bool) -> void:
		set(property, toggled_on)
		config_update_property(DEFAULT_PROFILE, property)
	)

	grid.add_child(label)
	grid.add_child(sep)
	grid.add_child(button)

func push_scene_var_color(property: String) -> void:
	var grid: GridContainer = main.menu.get_node("%ContainerSceneVars")

	var label := Label.new()
	var sep := VSeparator.new()
	var button := ColorPickerButton.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	button.color = get(property)
	button.color_changed.connect(func(color: Color) -> void:
		set(property, color)
		config_update_property(DEFAULT_PROFILE, property)
	)

	grid.add_child(label)
	grid.add_child(sep)
	grid.add_child(button)

func push_scene_var_slider(property: String) -> void:
	var grid: GridContainer = main.menu.get_node("%ContainerSceneVars")

	var label := Label.new()
	var value_label := Label.new()
	var slider := HSlider.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND

	value_label.text = "%.2f" % get(property)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	slider.custom_minimum_size.x = 80
	slider.max_value = 1.0
	slider.min_value = 0.0
	slider.step = 0.01
	slider.value = get(property)
	slider.value_changed.connect(func(value: float) -> void:
		set(property, value)
		config_update_property(DEFAULT_PROFILE, property)
		value_label.text="%.2f" % value
	)

	grid.add_child(label)
	grid.add_child(value_label)
	grid.add_child(slider)

func push_scene_var_int_slider(property: String, range_min: int, range_max: int) -> void:

	var grid: GridContainer = main.menu.get_node("%ContainerSceneVars")

	var label := Label.new()
	var value_label := Label.new()
	var slider := HSlider.new()

	label.text = property.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND

	value_label.text = "%d" % get(property)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	slider.custom_minimum_size.x = 80
	slider.max_value = range_max
	slider.min_value = range_min
	slider.step = 1
	slider.tick_count = range_max - range_min
	slider.ticks_on_borders = true
	slider.value = get(property)
	slider.value_changed.connect(func(value: float) -> void:
		set(property, value)
		config_update_property(DEFAULT_PROFILE, property)
		value_label.text="%d" % value
	)

	grid.add_child(label)
	grid.add_child(value_label)
	grid.add_child(slider)

func get_export_vars() -> Array:
	return get_property_list().filter(func(prop: Dictionary) -> bool:
		return prop["usage"] == (
			PROPERTY_USAGE_SCRIPT_VARIABLE +
			PROPERTY_USAGE_STORAGE +
			PROPERTY_USAGE_EDITOR
		)
	)

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
	var export_vars := get_export_vars()
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

func _fft(from_hz: float, to_hz: float) -> float:
	var magnitude := spectrum_analyzer.get_magnitude_for_frequency_range(
		from_hz,
		to_hz,
		AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
	).length()
	return clamp(magnitude, 0, 1)

# func update_m8_color_samples():
#	 if main.m8_display_viewport != null:
#		 var image = receiver_texture.get_image()
#		 if image != null:
#			 color_fg2 = image.get_pixelv(COLOR_SAMPLE_POINT_3)
#			 color_fg = image.get_pixelv(COLOR_SAMPLE_POINT_2)
#			 color_bg = image.get_pixelv(COLOR_SAMPLE_POINT_1)

# func _physics_process(_delta):
#	 if receiver_texture != null:
#		 var image = receiver_texture.get_image()
#		 if image != null:
#			 color_fg2 = image.get_pixelv(COLOR_SAMPLE_POINT_3)
#			 color_fg = image.get_pixelv(COLOR_SAMPLE_POINT_2)
#			 color_bg = image.get_pixelv(COLOR_SAMPLE_POINT_1)
