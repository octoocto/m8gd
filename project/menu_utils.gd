class_name MenuUtils extends Node

const DEFAULT_PROFILE := "__main"

static var main: M8SceneDisplay = null
static var current_profile := DEFAULT_PROFILE

static func init(p_main: M8SceneDisplay) -> void:
	main = p_main

## Retrieve a scene profile from the config.
static func _profile(profile_name: String) -> Dictionary:
	assert(main != null and main.current_scene != null)

	var scene_path := main.current_scene.scene_file_path
	if !main.config.scene_parameters[scene_path].has(profile_name):
		print("scene: initializing profile '%s'" % profile_name)
		main.config.scene_parameters[scene_path][profile_name] = {}

	var profile: Dictionary = main.config.scene_parameters[scene_path][profile_name]

	assert(profile is Dictionary)
	# print("scene: using profile '%s'" % profile_name)
	return profile

## Sets a profile setting to a value (for the active profile)
static func _profile_set(property: String, value: Variant) -> void:

	var profile := _profile(current_profile)
	profile[property] = value
	print("scene: profile %s: set %s=%s" % [current_profile, property, value])
	# setting_changed.emit(property, value)

static func _profile_get(property: String, default: Variant = null) -> Variant:
	var profile := _profile(current_profile)

	# set parameter from config, or add parameter to config
	if !profile.has(property) or profile[property] == null:
		print("scene: %s: adding property '%s' to config" % [current_profile, property])
		profile[property] = default

	# print("scene: profile %s: get %s=%s" % [current_profile, property, profile[property]])

	return profile[property]

## Return an HBoxContainer of 3 control nodes.
static func _bundle(a: Control, b: Control, c: Control) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_child(a)
	node.add_child(b)
	node.add_child(c)
	return node

static func create_vec2i(setting: String, label_text: String, default: Vector2i, fn: Callable) -> Control:
	var label := _label(label_text)
	var hbox := _vec2i(setting, default, fn)
	var cont := _bundle(label, _spacer(), hbox)
	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(cont):
	# 		cont.modulate.a=1.0 if editable else 0.5
	# )
	return cont

static func create_check(
	setting: String,
	label_text: String,
	default: bool,
	fn: Callable) -> Control:

	var container := _bundle(
		_label(label_text),
		_spacer(),
		_check(setting, default, fn)
	)
	return container

static func create_spinbox(
	setting: String,
	label_text: String, suffix: String,
	default: float, step: float,
	fn: Callable) -> Control:

	var spinbox := _spinbox(setting, suffix, default, step, fn)
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var container := _bundle(
		_label(label_text),
		_spacer(),
		spinbox
	)
	return container

static func create_slider(
	setting: String,
	label_text: String, label_format: String,
	default: float,
	range_min: float, range_max: float, step: float,
	fn: Callable) -> Control:

	var slider := _slider(setting, default, range_min, range_max, step, fn)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var container := _bundle(
		_label(label_text),
		_label_slider(slider, label_format),
		slider
	)
	return container

static func create_option(setting: String, label_text: String, default: int, items: Array, fn: Callable) -> Control:
	var cont := _bundle(
		_label(label_text),
		_spacer(),
		_option(setting, default, items, fn)
	)
	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(cont):
	# 		cont.modulate.a=1.0 if editable else 0.5
	# )
	return cont


static func add_file(setting: String, default: String, fn: Callable) -> Control:
	var cont := _bundle(
		_label(setting),
		_spacer(),
		_file(setting, default, fn)
	)
	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(cont):
	# 		cont.modulate.a=1.0 if editable else 0.5
	# )
	return cont

static func add_section(title: String) -> void:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.bbcode_enabled = true
	label.text = "[b]%s[/b]" % title
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	# get_param_container().add_child(label)

# func reg_link_editable(from_setting: String, to_setting: String) -> void:
	# setting_editable.emit(to_setting, bool(_profile_get(from_setting)))
	# setting_changed.connect(func(setting: String, value: Variant) -> void:
	# 	if setting == from_setting:
	# 		setting_editable.emit(to_setting, bool(value))
	# )

## Generate a label that displays static text.
static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text.capitalize()
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	return label

## Generate a label that displays the value of a slider.
static func _label_slider(slider: HSlider, format: String) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = format % slider.value
	slider.value_changed.connect(func(value: float) -> void:
		label.text = format % value
	)
	return label

## Generate a separator.
static func _spacer() -> VSeparator:
	var empty_sep := VSeparator.new()
	empty_sep.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	return empty_sep

## Generate a check button.
static func _check(setting: String, default: bool, fn: Callable) -> CheckButton:
	var button := CheckButton.new()

	button.toggled.connect(func(toggle_mode: bool) -> void:
		_profile_set(setting, toggle_mode)
	)
	button.toggled.connect(fn)
	button.button_pressed = _profile_get(setting, default)
	button.toggled.emit(button.button_pressed)

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(button):
	# 		button.disabled=!editable
	# )

	return button

## Generate a color picker button to edit a color.
static func _colorpicker(setting: String, default: Color, fn: Callable) -> ColorPickerButton:
	var button := ColorPickerButton.new()

	button.color_changed.connect(func(color: Color) -> void:
		_profile_set(setting, color)
		fn.call(color)
	)
	button.color = _profile_get(setting, default)
	button.color_changed.emit(button.color)

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(button):
	# 		button.disabled=!editable
	# )

	return button

## Generate a slider to edit a float or int within a range.
static func _slider(setting: String, default: float, range_min: float, range_max: float, step: float, fn: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.max_value = range_max
	slider.min_value = range_min
	slider.step = step

	# add ticks if slider is limited to integers only
	if slider.step == 1 and range_min == int(range_min) and range_max == int(range_max):
		slider.tick_count = int(range_max - range_min) + 1
		slider.ticks_on_borders = true

	slider.value_changed.connect(func(value: float) -> void:
		_profile_set(setting, value)
		fn.call(value)
	)
	slider.set_value_no_signal(_profile_get(setting, default))
	slider.value_changed.emit(slider.value)

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(slider):
	# 		slider.editable=editable
	# )

	return slider

## Generate a spinbox to edit a float or int.
static func _spinbox(setting: String, suffix: String, default: float, step: float, fn: Callable) -> SpinBox:
	var spinbox := SpinBox.new()

	spinbox.min_value = -3000
	spinbox.max_value = +3000
	spinbox.step = step
	spinbox.suffix = suffix

	spinbox.value_changed.connect(func(value: float) -> void:
		_profile_set(setting, value)
		fn.call(value)
	)
	spinbox.set_value_no_signal(_profile_get(setting, default))
	spinbox.value_changed.emit(spinbox.value)

	return spinbox

## Generate control nodes to edit a Vector2i.
static func _vec2i(setting: String, default: Vector2i, fn: Callable) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	var spin_x := SpinBox.new()
	var spin_y := SpinBox.new()
	hbox.add_child(spin_x)
	hbox.add_child(spin_y)

	spin_x.value_changed.connect(func(value: float) -> void:
		var vec2i: Vector2i = _profile_get(setting, default)
		vec2i.x = int(value)
		_profile_set(setting, vec2i)
		fn.call(vec2i)
	)
	spin_x.min_value = -3000
	spin_x.max_value = 3000
	spin_x.allow_lesser = true
	spin_x.allow_greater = true
	spin_x.select_all_on_focus = true
	spin_x.value = _profile_get(setting, default).x

	spin_y.value_changed.connect(func(value: float) -> void:
		var vec2i: Vector2i = _profile_get(setting, default)
		vec2i.y = int(value)
		_profile_set(setting, vec2i)
		fn.call(vec2i)
	)
	spin_y.min_value = -3000
	spin_y.max_value = 3000
	spin_y.allow_lesser = true
	spin_y.allow_greater = true
	spin_y.select_all_on_focus = true
	spin_y.value = _profile_get(setting, default).y

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting:
	# 		if is_instance_valid(spin_x):
	# 			spin_x.editable=editable
	# 		if is_instance_valid(spin_y):
	# 			spin_y.editable=editable
	# )

	return hbox

## Generate an option button.
##
static func _option(setting: String, default: int, items: Array, fn: Callable) -> OptionButton:
	var option := OptionButton.new()
	for item: String in items:
		option.add_item(item)

	option.item_selected.connect(func(index: int) -> void:
		_profile_set(setting, index)
	)
	option.item_selected.connect(fn)
	option.selected = _profile_get(setting, default)
	option.item_selected.emit(option.selected)

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(option):
	# 		option.disabled=!editable
	# )

	return option

## Generate a button that opens the system open file prompt.
##
static func _file(setting: String, default: String, fn: Callable) -> Button:
	var button := Button.new()
	var on_file_selected := func(path: String) -> void:
			_profile_set(setting, path)
			button.text = path.get_file()
			fn.call(path)

	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	button.pressed.connect(func() -> void:
		print("opening file dialog")
		main.open_file_dialog(on_file_selected)
	)
	on_file_selected.call(_profile_get(setting, default))

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(button):
	# 		button.disabled = !editable
	# )

	return button
