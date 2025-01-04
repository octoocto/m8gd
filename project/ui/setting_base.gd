class_name SettingBase extends PanelContainer

signal value_changed(value: Variant)

const CONFIG_KEY_OVERLAY = "overlay.%s.%s"
const CONFIG_KEY_CAMERA = "camera.%s"
const CONFIG_KEY_SHADER = "filter.%s.shader.%s"
const CONFIG_KEY_SCENE_CUSTOM = "custom.%s"

## If true, one of the [init] methods has been called.
var _is_initialized := false

## If true, fire the [value_changed] signal when [value] is set.
var _value_changed_signal_enabled := true

## Set to a Callable that gets the initial value of [value].
var _value_init_fn: Callable

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

func set_value_no_signal(value: Variant) -> void:
	_value_changed_signal_enabled = false
	set("value",value)
	_value_changed_signal_enabled = true

func _emit_value_changed() -> void:
	if _value_changed_signal_enabled:
		value_changed.emit(get("value"))

func _clear_signals() -> void:
	for conn: Dictionary in value_changed.get_connections():
		value_changed.disconnect(conn.callable)

func init_to_value(value_init_fn: Variant, value_changed_fn: Callable) -> void:
	assert("value" in self)
	assert(!_is_initialized, "This setting has already been initialized: %s" % name)

	var initial_value: Variant

	if value_init_fn is Callable:
		_value_init_fn = value_init_fn
		initial_value = _value_init_fn.call()

	else:
		_value_init_fn = func() -> Variant: return value_init_fn
		initial_value = _value_init_fn
		
	value_changed.connect(value_changed_fn)
	set("value",initial_value)

	_is_initialized = true

##
## Re-initialize this setting to an initial value and emits [value_changed].
## This is useful when a profile or scene has just been loaded, and
## the initial value could be different.
##
func reinit(emit_value_changed := true) -> void:
	assert(_is_initialized and _value_init_fn, "This setting has not been initialized yet: %s" % name)
	if emit_value_changed:
		set("value", _value_init_fn.call())
	else:
		set_value_no_signal(_value_init_fn.call())
	# print("%s: reinitializing value" % name)

##
## Uninitialize this setting, disconnecting all signal connections.
## Note: the value won't change.
##
func uninit() -> void:
	if _is_initialized:
		_clear_signals()
		_value_init_fn = func() -> void: return
		_is_initialized = false

##
## Set this control to an initial value and value_changed function.
##
func init(value: Variant, value_changed_fn: Callable) -> void:
	init_to_value(func() -> Variant: return value, value_changed_fn)


##
## Link this setting to a global config property and a callback function
## for the [value_changed] signal.
##
## This will initialize the value of this setting from the config and
## emit the [value_changed] signal.
##
## This setting's value will default to the corresponding property in [config_file.gd].
##
func init_config_global(main: Main, property: String, value_changed_fn: Variant = null) -> void:
	assert(value_changed_fn is Callable or value_changed_fn == null)
	init_to_value(
		func() -> Variant: return main.config.get_property_global(property),
		func(value: Variant) -> void:
			if value_changed_fn: value_changed_fn.call(value)
			main.config.set_property_global(property, value)
	)

##
## This setting's value will default to its current value in the inspector.
##
func init_config_profile(main: Main, property: String, value_changed_fn: Variant = null) -> void:
	assert(value_changed_fn is Callable or value_changed_fn == null)
	init_to_value(
		func() -> Variant: return main.config.get_property(property, get("value")),
		func(value: Variant) -> void:
			if value_changed_fn: value_changed_fn.call(value)
			main.config.set_property(property, value)
	)

##
## Initialize this setting to a scene property.
##
## This setting's initial value will be read from the config, and default to
## the property's value in the current scene.
##
func init_config_scene(main: Main, property: String, value_changed_fn: Variant = null) -> void:
	assert(value_changed_fn is Callable or value_changed_fn == null)
	init_to_value(
		func() -> Variant:
			if property in main.current_scene:
				return main.config.get_property_scene(property, main.current_scene.get(property))
			else:
				return main.config.get_property_scene(property, get("value")),
		func(value: Variant) -> void:
			if property in main.current_scene:
				main.current_scene.set(property, value)
			main.config.set_property_scene(property, value)
			if value_changed_fn: value_changed_fn.call(value)
	)

##
## Initialize this setting to an overlay property.
##
## This setting's initial value will be read from the config, and default to
## the property's value in the [overlay].
##
## Changing this setting's value will write the value to the config,
## set the property in [overlay], and call [value_changed_fn] if defined.
##
func init_config_overlay(main: Main, overlay: Control, property: String, value_changed_fn: Variant = null) -> void:
	assert(value_changed_fn is Callable or value_changed_fn == null)
	var config_property := main._get_propkey_overlay(overlay, property)
	init_to_value(
		func() -> Variant: return main.config.get_property(config_property, overlay.get(property)),
		func(value: Variant) -> void:
			overlay.set(property, value)
			main.config.set_property(config_property, overlay.get(property))
			if value_changed_fn: value_changed_fn.call(value)
	)

##
## Initialize an overlay property.
##
## The initial value of the property in [overlay] will be read from the config,
## and default to its current value (unchanged).
##
static func init_overlay_property(main: Main, overlay: Control, property: String) -> void:
	var config_property := main._get_propkey_overlay(overlay, property)
	var value: Variant = main.config.get_property(config_property, overlay.get(property))
	overlay.set(property, value)
	main.config.set_property(config_property, overlay.get(property))

##
## Initialize this setting to a camera config property.
##
## This setting's initial value will be read from the config, and default to
## the property's value in the current scene's camera or the value returned
## from [value_init_fn] if defined.
##
## Changing this setting's value will write the value to the config,
## set the property in the current scene's camera, and
## call [value_changed_fn] if defined.
##
func init_config_camera(main: Main, property: String, value_changed_fn: Variant = null, value_init_fn: Variant = null) -> void:
	assert(value_changed_fn is Callable or value_changed_fn == null)
	assert(value_init_fn is Callable or value_init_fn == null)
	var config_property := main._get_propkey_camera(property)
	init_to_value(
		func() -> Variant:
			var init_value: Variant
			if main.get_scene_camera():
				var default: Variant
				if value_init_fn:
					default = value_init_fn.call()
					# print("%s: reading value from value_init_fn() = %s" % [name, default])
				else:
					default = main.get_scene_camera().get(property)
					# print("%s: reading value from camera = %s" % [name, default])
				init_value = main.config.get_property_scene(config_property, default)
			else:
				init_value = null
			# print("%s: initialized value to %s" % [name, init_value])
			return init_value,
		func(value: Variant) -> void:
			if main.get_scene_camera():
				if value_changed_fn:
					value_changed_fn.call(value)
				else:
					main.get_scene_camera().set(property, value)
				main.config.set_property_scene(config_property, value)
	)

##
## This setting's value will default to its current value of the property in [overlay].
##
func init_config_shader(main: Main, shader_node_path: NodePath, shader_parameter: String) -> void:
	assert(main.has_node(shader_node_path))
	var shader_node: ColorRect = main.get_node(shader_node_path)
	var config_property := main._get_propkey_filter_shader(shader_node, shader_parameter)
	init_to_value(
		func() -> Variant: return main.config.get_property(config_property, main.get_filter_shader_parameter(shader_node_path, shader_parameter)),
		func(value: Variant) -> void:
			main.set_filter_shader_parameter(shader_node_path, shader_parameter, value)
			main.config.set_property(config_property, value)
	)

##
## Links this setting to enable/disable a control node.
##
func connect_to_enable(control: Control) -> SettingBase:
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
	)

	control.set(dst_property, bool(get("value")) if !invert else !bool(get("value")))

	return self

##
## Links this setting to unhide/hide a control node.
##
func connect_to_visible(control: Control, check_fn: Variant = null) -> SettingBase:
	assert(check_fn == null or check_fn is Callable)
	var invert := false

	var _check := func() -> bool:
		var bool_value: bool
		if check_fn:
			bool_value = check_fn.call(get("value"))
		else:
			bool_value = bool(get("value"))
		return !bool_value if invert else bool_value

	value_changed.connect(func(_value: Variant) -> void:
		control.visible = _check.call()
	)

	control.visible = _check.call()

	return self
