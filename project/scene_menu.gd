class_name SceneMenu extends PanelContainer

const DEFAULT_PROFILE := "__main"

var main: M8SceneDisplay
var current_profile: String = DEFAULT_PROFILE
var current_scene: M8Scene

signal setting_changed(setting: String, value: Variant)

signal setting_editable(setting: String, editable: bool)

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
	for dict: Dictionary in setting_changed.get_connections():
		setting_changed.disconnect(dict.callable)

	for dict: Dictionary in setting_editable.get_connections():
		setting_editable.disconnect(dict.callable)

	for c in get_param_container().get_children():
		get_param_container().remove_child(c)
		c.queue_free()

func push_param(left: Control, middle: Control, right: Control) -> HBoxContainer:
	right.custom_minimum_size.x = 80

	var container := HBoxContainer.new()
	container.add_child(left)
	container.add_child(middle)
	container.add_child(right)
	get_param_container().add_child(container)

	return container

func read_params_from_scene(p_scene: M8Scene) -> void:

	init_profile(p_scene)

	# add menu items
	var export_vars := current_scene.get_export_vars()
	for v: Dictionary in export_vars:
		add_export_var(v.name)

func init_profile(p_scene: M8Scene, profile:=DEFAULT_PROFILE) -> void:

	var config := main.config
	current_scene = p_scene

	# add scene parameter dict to config if not exists
	if !config.scene_parameters.has(_scene_file_path()):
		config.scene_parameters[_scene_file_path()] = {}

	# clear menu
	clear_params()

	config_load_profile(profile)

##
## Add a UI setting from a scene's export variable.
## [property] must match the name of an export var that exists
## in the current scene.
##
func add_export_var(property: String) -> void:

	var regex_int_range := RegEx.new()
	var regex_float_range := RegEx.new()

	regex_int_range.compile("^-?\\d+,-?\\d+$") # match "#,#" export_range patterns
	regex_float_range.compile("^-?\\d+[.]?\\d*,-?\\d+[.]?\\d*,-?\\d+[.]?\\d*$") # match "#,#,#" export_range patterns

	# add menu items
	var export_vars := current_scene.get_export_vars()
	for v: Dictionary in export_vars:
		if v.name != property:
			continue

		if v.hint_string == "bool":
			var default: bool = current_scene.get(property)
			push_scene_var_bool(property, default, func(toggle_mode: bool) -> void:
				current_scene.set(property, toggle_mode)
			)
			current_scene.set(property, config_get_property(property, default))
			break

		if v.hint_string == "float":
			var default: float = current_scene.get(property)
			push_scene_var_slider(property, default, 0.0, 1.0, 0.01, func(value: float) -> void:
				current_scene.set(property, value)
			)
			current_scene.set(property, config_get_property(property, default))
			break

		if v.hint_string == "Color":
			var default: Color = current_scene.get(property)
			push_scene_var_color(property, default, func(color: Color) -> void:
				current_scene.set(property, color)
			)
			current_scene.set(property, config_get_property(property, default))
			break

		if v.hint_string == "Vector2i":
			var default: Vector2i = current_scene.get(property)
			push_setting_vec2i(property, default, func(vec: Vector2i) -> void:
				current_scene.set(property, vec)
			)
			current_scene.set(property, config_get_property(property, default))
			break

		# @export_range() variables
		if regex_int_range.search(v.hint_string):
			var range_min := int(v.hint_string.split(",")[0])
			var range_max := int(v.hint_string.split(",")[1])
			var default: int = current_scene.get(property)
			push_scene_var_int_slider(property, default, range_min, range_max, func(value: float) -> void:
				current_scene.set(property, value)
			)
			current_scene.set(property, config_get_property(property, default))
			break

		if regex_float_range.search(v.hint_string):
			var range_min := float(v.hint_string.split(",")[0])
			var range_max := float(v.hint_string.split(",")[1])
			var step := float(v.hint_string.split(",")[2])
			var default: int = current_scene.get(property)
			push_scene_var_slider(property, default, range_min, range_max, step, func(value: float) -> void:
				current_scene.set(property, value)
			)
			current_scene.set(property, config_get_property(property, default))
			break

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
	profile[property] = value
	print("scene: profile %s: set %s=%s" % [current_profile, property, value])
	setting_changed.emit(property, value)

func push_scene_var_bool(setting: String, default: bool, fn: Callable) -> void:
	var cont := push_param(
		_label(setting),
		_spacer(),
		_check(setting, default, fn)
	)
	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(cont):
			cont.modulate.a=1.0 if editable else 0.5
	)

func push_scene_var_color(setting: String, default: Color, fn: Callable) -> void:
	var cont := push_param(
		_label(setting),
		_spacer(),
		_colorpicker(setting, default, fn)
	)
	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(cont):
			cont.modulate.a=1.0 if editable else 0.5
	)

func push_scene_var_slider(setting: String, default: float, range_min: float, range_max: float, step: float, fn: Callable) -> void:
	var label := _label(setting)
	var slider := _slider(setting, default, range_min, range_max, step, fn)
	var value_label := _slider_label(slider, "%.2f")
	var cont := push_param(label, value_label, slider)
	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(cont):
			cont.modulate.a=1.0 if editable else 0.5
	)

func push_scene_var_int_slider(setting: String, default: int, range_min: int, range_max: int, fn: Callable) -> void:
	var label := _label(setting)
	var slider := _int_slider(setting, default, range_min, range_max, fn)
	var value_label := _slider_label(slider, "%d")
	var cont := push_param(label, value_label, slider)
	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(cont):
			cont.modulate.a=1.0 if editable else 0.5
	)

func push_setting_vec2i(setting: String, default: Vector2i, fn: Callable) -> void:
	var label := _label(setting)
	var hbox := _vec2i(setting, default, fn)
	var cont := push_param(label, _spacer(), hbox)
	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(cont):
			cont.modulate.a=1.0 if editable else 0.5
	)

func add_option(setting: String, default: int, items: Array, fn: Callable) -> void:
	var cont := push_param(
		_label(setting),
		_spacer(),
		_option(setting, default, items, fn)
	)
	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(cont):
			cont.modulate.a=1.0 if editable else 0.5
	)

func add_file(setting: String, default: String, fn: Callable) -> void:
	var cont := push_param(
		_label(setting),
		_spacer(),
		_file(setting, default, fn)
	)
	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(cont):
			cont.modulate.a=1.0 if editable else 0.5
	)

func add_section(title: String) -> void:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.bbcode_enabled = true
	label.text = "[b]%s[/b]" % title
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	get_param_container().add_child(label)

func reg_link_editable(from_setting: String, to_setting: String) -> void:
	setting_editable.emit(to_setting, bool(config_get_property(from_setting)))
	setting_changed.connect(func(setting: String, value: Variant) -> void:
		if setting == from_setting:
			setting_editable.emit(to_setting, bool(value))
	)

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	return label

func _slider_label(slider: HSlider, format: String) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = format % slider.value
	slider.value_changed.connect(func(value: float) -> void:
		label.text=format % value
	)
	return label

func _spacer() -> VSeparator:
	var empty_sep := VSeparator.new()
	empty_sep.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	return empty_sep

func _check(setting: String, default: bool, fn: Callable) -> CheckButton:
	var button := CheckButton.new()

	button.toggled.connect(func(toggle_mode: bool) -> void:
		config_set_property(setting, toggle_mode)
	)
	button.toggled.connect(fn)
	button.button_pressed = config_get_property(setting, default)
	button.toggled.emit(button.button_pressed)

	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(button):
			button.disabled=!editable
	)

	return button

func _colorpicker(setting: String, default: Color, fn: Callable) -> ColorPickerButton:
	var button := ColorPickerButton.new()

	button.color_changed.connect(func(color: Color) -> void:
		config_set_property(setting, color)
	)
	button.color_changed.connect(fn)
	button.color = config_get_property(setting, default)
	button.color_changed.emit(button.color)

	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(button):
			button.disabled=!editable
	)

	return button

func _slider(setting: String, default: float, range_min: float, range_max: float, step: float, fn: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.max_value = range_max
	slider.min_value = range_min
	slider.step = step

	slider.value_changed.connect(func(value: float) -> void:
		config_set_property(setting, value)
	)
	slider.value_changed.connect(fn)
	slider.value = config_get_property(setting, default)
	slider.value_changed.emit(slider.value)

	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(slider):
			slider.editable=editable
	)

	return slider

func _int_slider(setting: String, default: int, range_min: int, range_max: int, fn: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.max_value = range_max
	slider.min_value = range_min
	slider.step = 1
	slider.tick_count = (range_max - range_min)
	slider.ticks_on_borders = true

	slider.value_changed.connect(func(value: float) -> void:
		config_set_property(setting, int(value))
	)
	slider.value_changed.connect(fn)
	slider.value = config_get_property(setting, default)
	slider.value_changed.emit(slider.value)

	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(slider):
			slider.editable=editable
	)

	return slider

func _vec2i(setting: String, default: Vector2i, fn: Callable) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	var spin_x := SpinBox.new()
	var spin_y := SpinBox.new()
	hbox.add_child(spin_x)
	hbox.add_child(spin_y)

	spin_x.value_changed.connect(func(value: float) -> void:
		var vec2i: Vector2i=config_get_property(setting, default)
		vec2i.x=int(value)
		config_set_property(setting, vec2i)
		fn.call(vec2i)
	)
	spin_x.min_value = -3000
	spin_x.max_value = 3000
	spin_x.allow_lesser = true
	spin_x.allow_greater = true
	spin_x.select_all_on_focus = true
	spin_x.value = config_get_property(setting, default).x

	spin_y.value_changed.connect(func(value: float) -> void:
		var vec2i: Vector2i=config_get_property(setting, default)
		vec2i.y=int(value)
		config_set_property(setting, vec2i)
		fn.call(vec2i)
	)
	spin_y.min_value = -3000
	spin_y.max_value = 3000
	spin_y.allow_lesser = true
	spin_y.allow_greater = true
	spin_y.select_all_on_focus = true
	spin_y.value = config_get_property(setting, default).y

	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting:
			if is_instance_valid(spin_x):
				spin_x.editable=editable
			if is_instance_valid(spin_y):
				spin_y.editable=editable
	)

	return hbox

func _option(setting: String, default: int, items: Array, fn: Callable) -> OptionButton:
	var option := OptionButton.new()
	for item: String in items:
		option.add_item(item)

	option.item_selected.connect(func(index: int) -> void:
		config_set_property(setting, index)
	)
	option.item_selected.connect(fn)
	option.selected = config_get_property(setting, default)
	option.item_selected.emit(option.selected)

	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(option):
			option.disabled=!editable
	)

	return option

func _file(setting: String, default: String, fn: Callable) -> Button:
	var button := Button.new()
	var on_file_selected := func(path: String) -> void:
			config_set_property(setting, path)
			button.text = path.get_file()
			fn.call(path)

	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	button.pressed.connect(func() -> void:
		print("opening file dialog")
		main.open_file_dialog(on_file_selected)
	)
	on_file_selected.call(config_get_property(setting, default))

	setting_editable.connect(func(p_setting: String, editable: bool) -> void:
		if p_setting == setting and is_instance_valid(button):
			button.disabled=!editable
	)

	return button
