class_name MenuUtils extends Node

const DEFAULT_PROFILE := "__main"

static var main: M8SceneDisplay = null
static var config: M8Config = null
static var current_profile := DEFAULT_PROFILE

static func init(p_main: M8SceneDisplay) -> void:
	main = p_main
	config = main.config

## Sets a profile setting to a value (for the active profile)
static func _profile_scene_set(property: String, value: Variant) -> void:
	main.current_scene.set(property, value)
	main.config.set_scene_property(property, value)

static func _profile_scene_get(property: String, default: Variant = null) -> Variant:
	if default == null:
		default = main.current_scene.get(property)
	return main.config.get_scene_property(property, default)

## Return an HBoxContainer of 3 control nodes.
static func _bundle(a: Control, b: Control, c: Control) -> HBoxContainer:
	c.custom_minimum_size.x = 80
	var node := HBoxContainer.new()
	node.add_child(a)
	node.add_child(b)
	node.add_child(c)
	return node

##
## Create a Vector2i control node.
##
static func create_vec2i(label_text: String, default: Vector2i, fn: Callable) -> Control:
	var label := _label(label_text)
	var hbox := _vec2i(default, fn)
	var cont := _bundle(label, _spacer(), hbox)

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(cont):
	# 		cont.modulate.a=1.0 if editable else 0.5
	# )

	return cont

##
## Create a Vector2i control node that is tied to a scene property.
##
static func create_vec2i_scene_prop(propkey: String, label_text: String, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	var default: Vector2i = _profile_scene_get(propkey)
	var fn := func(value: bool) -> void:
		_profile_scene_set(propkey, value)
		if callback is Callable: callback.call(value)

	return create_vec2i(label_text, default, fn)

##
## Create a Vector2i control node that is tied to a scene property.
##
static func create_vec2i_prop(propkey: String, label_text: String, default: Vector2i, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	var fn := func(value: Vector2i) -> void:
		config.set_property(propkey, value)
		if callback is Callable: callback.call(value)

	return create_vec2i(label_text, default, fn)

##
## Create a bool control node.
##
static func create_bool(
	label_text: String,
	default: bool,
	fn: Callable) -> Control:

	var container := _bundle(
		_label(label_text),
		_spacer(),
		_check(default, fn)
	)
	return container

##
## Create a bool control node that is tied to a scene property.
##
static func create_bool_scene_prop(propkey: String, label_text: String, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	var default: bool = _profile_scene_get(propkey)
	var fn := func(value: bool) -> void:
		_profile_scene_set(propkey, value)
		if callback is Callable: callback.call(value)

	return create_bool(label_text, default, fn)

##
## Create a bool control node that is tied to a property.
##
static func create_bool_prop(propkey: String, label_text: String, default: bool, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	config.get_property(propkey, default)
	var fn := func(value: bool) -> void:
		config.set_property(propkey, value)
		if callback is Callable: callback.call(value)

	return create_bool(label_text, default, fn)

##
## Create a spinbox (float or int) control node.
##
static func create_spinbox(
	label_text: String, default: float,
	step: float, suffix: String,
	fn: Callable) -> Control:

	var spinbox := _spinbox(default, step, suffix, fn)
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var container := _bundle(
		_label(label_text),
		_spacer(),
		spinbox
	)
	return container

##
## Create a spinbox (float or int) control node that is tied to a scene property.
##
static func create_spinbox_scene_prop(propkey: String, label_text: String, step: float, suffix: String, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	var default: float = _profile_scene_get(propkey)
	var fn := func(value: float) -> void:
		_profile_scene_set(propkey, value)
		if callback is Callable: callback.call(value)
	if callback is Callable: callback.call(default)

	return create_spinbox(label_text, default, step, suffix, fn)

##
## Create a spinbox (float or int) control node that is tied to a property.
##
static func create_spinbox_prop(propkey: String, label_text: String, default: float, step: float, suffix: String, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	config.get_property(propkey, default)
	var fn := func(value: float) -> void:
		config.set_property(propkey, value)
		if callback is Callable: callback.call(value)
	if callback is Callable: callback.call(default)

	return create_spinbox(label_text, default, step, suffix, fn)

##
## Create a slider (float or int) control node.
##
static func create_slider(
	label_text: String, default: float,
	label_format: String,
	range_min: float, range_max: float, step: float,
	fn: Callable) -> Control:

	var slider := _slider(default, range_min, range_max, step, fn)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var container := _bundle(
		_label(label_text),
		_label_slider(slider, label_format),
		slider
	)
	return container

##
## Create a slider (float or int) control node that is tied to a scene property.
##
static func create_slider_scene_prop(
	propkey: String, label_text: String,
	label_format: String,
	range_min: float, range_max: float, step: float,
	callback: Variant = null) -> Control:

	assert(callback == null or callback is Callable)
	var default: float = _profile_scene_get(propkey)
	var fn := func(value: float) -> void:
		_profile_scene_set(propkey, value)
		if callback is Callable: callback.call(value)
	if callback is Callable: callback.call(default)

	return create_slider(label_text, default, label_format, range_min, range_max, step, fn)

##
## Create a slider (float or int) control node that is tied to a property.
##
static func create_slider_prop(
	propkey: String, label_text: String,
	default: float, label_format: String,
	range_min: float, range_max: float, step: float,
	callback: Variant = null) -> Control:

	assert(callback == null or callback is Callable)
	var fn := func(value: float) -> void:
		config.set_property(propkey, value)
		if callback is Callable: callback.call(value)
	if callback is Callable: callback.call(default)

	return create_slider(label_text, default, label_format, range_min, range_max, step, fn)

##
## Create a color control node.
##
static func create_colorpicker(label_text: String, default: Color, fn: Callable) -> Control:
	var container := _bundle(
		_label(label_text),
		_spacer(),
		_colorpicker(default, fn)
	)
	return container

##
## Create a color control node that is tied to a scene property.
##
static func create_colorpicker_scene_prop(propkey: String, label_text: String, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	var default: Color = _profile_scene_get(propkey)
	var fn := func(value: Color) -> void:
		_profile_scene_set(propkey, value)
		if callback is Callable: callback.call(value)

	return create_colorpicker(label_text, default, fn)

##
## Create a color control node that is tied to a property.
##
static func create_colorpicker_prop(propkey: String, label_text: String, default: Color, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	config.get_property(propkey, default)
	var fn := func(value: Color) -> void:
		config.set_property(propkey, value)
		if callback is Callable: callback.call(value)

	return create_colorpicker(label_text, default, fn)


static func create_option(label_text: String, default: int, items: Array[String], fn: Callable) -> Control:
	var cont := _bundle(
		_label(label_text),
		_spacer(),
		_option(default, items, fn)
	)
	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(cont):
	# 		cont.modulate.a=1.0 if editable else 0.5
	# )
	return cont

##
## Create a option select (enums) control node that is tied to a scene property.
##
static func create_option_scene_prop(propkey: String, label_text: String, default: Variant, items: Array[String], callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)
	assert(default == null or default is int)

	default = _profile_scene_get(propkey, default)
	var fn := func(value: int) -> void:
		_profile_scene_set(propkey, value)
		if callback is Callable: callback.call(value)
	if callback is Callable: callback.call(default)

	return create_option(label_text, default, items, fn)

##
## Create a option select (enums) node that is tied to a property.
##
static func create_option_prop(propkey: String, label_text: String, default: int, items: Array[String], callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	config.get_property(propkey, default)
	var fn := func(value: int) -> void:
		config.set_property(propkey, value)
		if callback is Callable: callback.call(value)
	if callback is Callable: callback.call(default)

	return create_option(label_text, default, items, fn)

static func create_file(label_text: String, default: String, fn: Callable) -> Control:
	var cont := _bundle(
		_label(label_text),
		_spacer(),
		_file(default, fn)
	)
	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(cont):
	# 		cont.modulate.a=1.0 if editable else 0.5
	# )
	return cont

##
## Create a option select (enums) control node that is tied to a scene property.
##
static func create_file_scene_prop(propkey: String, label_text: String, default: Variant, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)
	assert(default == null or default is String)

	if default == null:
		default = _profile_scene_get(propkey)
	var fn := func(value: String) -> void:
		_profile_scene_set(propkey, value)
		if callback is Callable: callback.call(value)
	if callback is Callable: callback.call(default)

	return create_file(label_text, default, fn)

##
## Create a option select (enums) node that is tied to a property.
##
static func create_file_prop(propkey: String, label_text: String, default: String, callback: Variant = null) -> Control:
	assert(callback == null or callback is Callable)

	config.get_property(propkey, default)
	var fn := func(value: String) -> void:
		config.set_property(propkey, value)
		if callback is Callable: callback.call(value)
	if callback is Callable: callback.call(default)

	return create_file(label_text, default, fn)

static func add_section(title: String) -> void:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.bbcode_enabled = true
	label.text = "[b]%s[/b]" % title
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	# get_param_container().add_child(label)

# func reg_link_editable(from_setting: String, to_setting: String) -> void:
	# setting_editable.emit(to_setting, bool(_profile_scene_get(from_setting)))
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
static func _check(default: bool, fn: Callable) -> CheckButton:
	var button := CheckButton.new()

	button.set_pressed_no_signal(default)
	button.toggled.connect(fn)
	button.toggled.emit(default)

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(button):
	# 		button.disabled=!editable
	# )

	return button

## Generate a color picker button to edit a color.
static func _colorpicker(default: Color, fn: Callable) -> ColorPickerButton:
	var button := ColorPickerButton.new()

	button.color_changed.connect(fn)
	button.color = default
	button.color_changed.emit(button.color)

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(button):
	# 		button.disabled=!editable
	# )

	return button

## Generate a slider to edit a float or int within a range.
static func _slider(default: float, range_min: float, range_max: float, step: float, fn: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.max_value = range_max
	slider.min_value = range_min
	slider.step = step

	# add ticks if slider is limited to integers only
	if slider.step == 1 and range_min == int(range_min) and range_max == int(range_max):
		slider.tick_count = int(range_max - range_min) + 1
		slider.ticks_on_borders = true

	slider.set_value_no_signal(default)
	slider.value_changed.connect(fn)
	slider.value_changed.emit(slider.value)

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(slider):
	# 		slider.editable=editable
	# )

	return slider

## Generate a spinbox to edit a float or int.
static func _spinbox(default: float, step: float, suffix: String, fn: Callable) -> SpinBox:
	var spinbox := SpinBox.new()

	spinbox.min_value = -3000
	spinbox.max_value = +3000
	spinbox.step = step
	spinbox.suffix = suffix

	# spinbox.value_changed.connect(func(value: float) -> void:
	# 	_profile_scene_set(setting, value)
	# 	fn.call(value)
	# )
	# spinbox.set_value_no_signal(_profile_scene_get(setting, default))
	spinbox.set_value_no_signal(default)
	spinbox.value_changed.connect(fn)
	spinbox.value_changed.emit(spinbox.value)

	return spinbox

## Generate control nodes to edit a Vector2i.
static func _vec2i(default: Vector2i, fn: Callable) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	var spin_x := SpinBox.new()
	var spin_y := SpinBox.new()
	hbox.add_child(spin_x)
	hbox.add_child(spin_y)

	var vec := [default] # workaround to allow editing from inside lambdas

	spin_x.value_changed.connect(func(value: float) -> void:
		# var vec2i: Vector2i = _profile_scene_get(setting, default)
		# vec2i.x = int(value)
		# _profile_scene_set(setting, vec2i)
		# fn.call(vec2i)
		vec[0].x = int(value)
		fn.call(vec[0])
	)
	spin_x.min_value = -3000
	spin_x.max_value = 3000
	spin_x.allow_lesser = true
	spin_x.allow_greater = true
	spin_x.select_all_on_focus = true
	# spin_x.value = _profile_scene_get(setting, default).x
	spin_y.value = default.x

	spin_y.value_changed.connect(func(value: float) -> void:
		# var vec2i: Vector2i = _profile_scene_get(setting, default)
		# vec2i.y = int(value)
		# _profile_scene_set(setting, vec2i)
		# fn.call(vec2i)
		vec[0].y = int(value)
		fn.call(vec[0])
	)
	spin_y.min_value = -3000
	spin_y.max_value = 3000
	spin_y.allow_lesser = true
	spin_y.allow_greater = true
	spin_y.select_all_on_focus = true
	# spin_y.value = _profile_scene_get(setting, default).y
	spin_y.value = default.y

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
static func _option(default: int, items: Array[String], fn: Callable) -> OptionButton:
	var option := OptionButton.new()
	for item: String in items:
		option.add_item(item)

	# option.item_selected.connect(func(index: int) -> void:
	# 	_profile_scene_set(setting, index)
	# )
	# option.item_selected.connect(fn)
	# option.selected = _profile_scene_get(setting, default)
	# option.item_selected.emit(option.selected)
	option.item_selected.connect(fn)
	option.allow_reselect = true
	option.selected = default

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(option):
	# 		option.disabled=!editable
	# )

	return option

## Generate a button that opens the system open file prompt.
##
static func _file(default: String, fn: Callable) -> Button:
	var button := Button.new()
	var on_file_selected := func(path: String) -> void:
			# _profile_scene_set(setting, path)
			button.text = path.get_file()
			fn.call(path)

	button.text = default
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(func() -> void:
		print("opening file dialog")
		main.open_file_dialog(on_file_selected)
	)

	# on_file_selected.call(_profile_scene_get(setting, default))

	# setting_editable.connect(func(p_setting: String, editable: bool) -> void:
	# 	if p_setting == setting and is_instance_valid(button):
	# 		button.disabled = !editable
	# )

	return button
