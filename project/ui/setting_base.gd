class_name SettingBase extends PanelContainer

signal value_changed(value: Variant)

var is_initialized := false

@export var enabled := true:
	set(value):
		enabled = value
		_update()

@export var setting_name := "":
	set(value):
		setting_name = value
		_update()

@export var setting_name_min_width := 160:
	set(value):
		setting_name_min_width = value
		_update()

@export var setting_name_indent := 0:
	set(value):
		setting_name_indent = max(0, value)
		_update()

func _update() -> void:
	assert(false, "not implemented")

func _clear_signals() -> void:
	for conn: Dictionary in value_changed.get_connections():
		value_changed.disconnect(conn.callable)

##
## Set this control to an initial value and value_changed function.
##
func init(value: Variant, value_changed_fn: Callable) -> void:
	assert("value" in self)

	if !is_initialized:
		_clear_signals()
		value_changed.connect(value_changed_fn)
		print_verbose("%s: initializing value" % name)
	else:
		print_verbose("%s: reinitializing value" % name)

	set("value",value)
	is_initialized = true


##
## Link this setting to a global config property and a callback function
## for the [value_changed] signal.
##
## This will initialize the value of this setting from the config and
## emit the [value_changed] signal.
##
## This setting's value will default to the corresponding property in [config_file.gd].
##
func init_config_global(main: M8SceneDisplay, property: String, value_changed_fn: Variant = null) -> void:
	assert(value_changed_fn is Callable or value_changed_fn == null)
	init(
		main.config.get_property_global(property),
		func(value: Variant) -> void:
			if value_changed_fn: value_changed_fn.call(value)
			main.config.set_property_global(property, value)
	)

##
## This setting's value will default to its value in the inspector.
##
func init_config_profile(main: M8SceneDisplay, property: String, value_changed_fn: Variant = null) -> void:
	assert(value_changed_fn is Callable or value_changed_fn == null)
	init(
		main.config.get_property(property, get("value")),
		func(value: Variant) -> void:
			if value_changed_fn: value_changed_fn.call(value)
			main.config.set_property(property, value)
	)

##
## This setting's value will default to its current value of the property in [overlay].
##
func init_config_overlay(main: M8SceneDisplay, overlay: Control, property: String) -> void:
	var config_property := main._get_propkey_overlay(overlay, property)
	init(
		main.config.get_property(config_property, overlay.get(property)),
		func(value: Variant) -> void:
			overlay.set(property, value)
			main.config.set_property(config_property, value)
	)

##
## This setting's value will default to its current value of the property in [overlay].
##
func init_config_shader(main: M8SceneDisplay, shader_node_path: NodePath, shader_parameter: String) -> void:
	assert(main.has_node(shader_node_path))
	var shader_node: ColorRect = main.get_node(shader_node_path)
	var config_property := main._get_propkey_filter_shader(shader_node, shader_parameter)
	init(
		main.config.get_property(config_property, main.get_shader_parameter(shader_node_path, shader_parameter)),
		func(value: Variant) -> void:
			main.set_shader_parameter(shader_node_path, shader_parameter, value)
			main.config.set_property(config_property, value)
	)

##
## Links this setting to enable/disable a control node.
##
func connect_to_enable(control: Control) -> void:
	var dst_property: String
	var invert := false

	if control is Slider:
		dst_property = "editable"
	elif control is Button:
		dst_property = "disabled"
		invert = true
	elif control is SettingBase:
		dst_property = "enabled"
	else:
		assert(false)

	assert(dst_property in control)

	value_changed.connect(func(value: Variant) -> void:
		control.set(dst_property, bool(value) if !invert else !bool(value))
		print("update button")
	)

	control.set(dst_property, bool(get("value")) if !invert else !bool(get("value")))
