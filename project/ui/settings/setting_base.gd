class_name SettingBase extends PanelContainer

signal value_changed(value: Variant)

enum DisableMethod {
	DISABLE, # show but make non-editable subsettings that have been disabled
	HIDE,    # hide subsettings that have been disabled
}

const CONFIG_KEY_OVERLAY = "overlay.%s.%s"
const CONFIG_KEY_CAMERA = "camera.%s"
const CONFIG_KEY_SHADER = "filter.%s.shader.%s"
const CONFIG_KEY_SCENE_CUSTOM = "custom.%s"

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

@export_node_path("SettingBase") var parent_setting := NodePath("")

@export var parent_setting_mode := DisableMethod.DISABLE

@export var parent_setting_invert := false


## If true, one of the [connect] methods has been called.
var _is_initialized := false

## If true, fire the [value_changed] signal when [value] is set.
var _value_changed_signal_enabled := true

## Set to a Callable that gets the initial value of [value].
var _value_read_fn: Callable

## A Callable that maps the parent setting's value to a bool,
## which decides whether to disable/hide this setting.
var _parent_value_check_fn: Callable

var main: Main

var config: M8Config


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	elif not Main.is_ready():
		await Events.initialized

	self.main = Main.instance
	self.config = main.config

	if parent_setting:
		get_node(parent_setting).value_changed.connect(func(_value: Variant) -> void:
			_check_parent()
		)
		_check_parent()

func set_value_no_signal(value: Variant) -> void:
	_value_changed_signal_enabled = false
	set("value",value)
	_value_changed_signal_enabled = true

##
## Connect this setting to arbitrary callback functions.
##
## [/br][param value_read_fn] called when the value needs to be read from the config, or to get a default value.
## [/br][param value_write_fn] called when the value in this setting changes.
## It should handle the value changing AND setting the corresponding property in the config.
##
func setting_connect(value_read_fn: Variant, value_changed_fn: Callable) -> void:
	assert(!_is_initialized, "This setting has already been initialized: %s" % name)
	assert(self.main != null or self.config != null, "Tried to initialize setting, but main has not finished initializing")
	assert(self.config != null, "Tried to initialize setting, but config is not loaded")
	assert(value_changed_fn is Callable or value_changed_fn == null)
	assert("value" in self)

	if value_read_fn is Callable:
		_value_read_fn = value_read_fn
	else:
		_value_read_fn = func() -> Variant: return value_read_fn
		
	value_changed.connect(value_changed_fn)
	set("value", _value_read_fn.call())

	_is_initialized = true

func emit_changed() -> void:
	if _value_changed_signal_enabled:
		value_changed.emit(get("value"))

##
## Re-initialize this setting to an initial value and emits [value_changed].
## This is useful when a profile or scene has just been loaded, and
## the initial value could be different.
##
func reinit(emit_value_changed := true) -> void:
	assert(_is_initialized and _value_read_fn, "This setting has not been initialized yet: %s" % name)
	if emit_value_changed:
		set("value", _value_read_fn.call())
	else:
		set_value_no_signal(_value_read_fn.call())
	# print("%s: reinitializing value" % name)

##
## Uninitialize this setting, disconnecting all signal connections.
## Note: the value won't change.
##
func uninit() -> void:
	if _is_initialized:
		_clear_signals()
		_value_read_fn = func() -> void: return
		_is_initialized = false

##
## Link this setting to a global config property and a callback function
## for the [value_changed] signal.
##
## This will initialize the value of this setting from the config and
## emit the [value_changed] signal.
##
## This setting's value will default to the corresponding property in [config_file.gd].
##
func setting_connect_global(property: String, value_changed_fn: Variant = null) -> void:
	setting_connect(
		func() -> Variant: return main.config.get_property_global(property),
		func(value: Variant) -> void:
			main.config.set_property_global(property, value)
			if value_changed_fn: value_changed_fn.call(value)
			Events.setting_changed.emit(self, value)
	)

##
## This setting's value will default to its current value in the inspector.
##
func setting_connect_profile(property: String, value_changed_fn: Variant = null) -> void:
	setting_connect(
		func() -> Variant: return main.config.get_property(property, get("value")),
		func(value: Variant) -> void:
			main.config.set_property(property, value)
			if value_changed_fn: value_changed_fn.call(value)
			Events.setting_changed.emit(self, value)
	)

##
## Initialize this setting to a scene property.
##
## This setting's initial value will be read from the config, and default to
## the property's value in the current scene.
##
func setting_connect_scene(property: String, value_changed_fn: Variant = null) -> void:
	setting_connect(
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
			Events.setting_changed.emit(self, value)
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
func setting_connect_overlay(overlay: Control, property: String, value_changed_fn: Variant = null) -> void:
	var config_property := main._get_propkey_overlay(overlay, property)
	setting_connect(
		func() -> Variant: return main.config.get_property(config_property, overlay.get(property)),
		func(value: Variant) -> void:
			overlay.set(property, value)
			main.config.set_property(config_property, overlay.get(property))
			if value_changed_fn: value_changed_fn.call(value)
			Events.setting_changed.emit(self, value)
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
func setting_connect_camera(property: String, value_changed_fn: Variant = null, value_init_fn: Variant = null) -> void:
	assert(value_changed_fn is Callable or value_changed_fn == null)
	assert(value_init_fn is Callable or value_init_fn == null)
	var config_property := main._get_propkey_camera(property)
	setting_connect(
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
				main.config.set_property_scene(config_property, value)
				if value_changed_fn:
					value_changed_fn.call(value)
				else:
					main.get_scene_camera().set(property, value)
				Events.setting_changed.emit(self, value)
	)

##
## This setting's value will default to its current value of the property in [overlay].
##
func init_config_shader(shader_node_path: NodePath, shader_parameter: String) -> void:
	assert(main.has_node(shader_node_path))
	var shader_node: ColorRect = main.get_node(shader_node_path)
	var config_property := main._get_propkey_filter_shader(shader_node, shader_parameter)
	setting_connect(
		func() -> Variant: return main.config.get_property(config_property, main.get_filter_shader_parameter(shader_node_path, shader_parameter)),
		func(value: Variant) -> void:
			main.set_filter_shader_parameter(shader_node_path, shader_parameter, value)
			main.config.set_property(config_property, value)
			Events.setting_changed.emit(self, value)
	)

##
## Links this setting to enable/disable a control node.
##
func setting_add_child_readonly(control: Control) -> SettingBase:
	setting_add_child(control, DisableMethod.DISABLE, null)
	return self

##
## Links this setting to unhide/hide a control node.
##
func setting_add_child_hidden(control: Control, check_fn: Variant = null) -> SettingBase:
	setting_add_child(control, DisableMethod.HIDE, check_fn)
	return self

func setting_hide_if(cond_fn: Variant) -> void:
	pass

func setting_add_child(control: Control, mode: DisableMethod, check_fn: Variant = null) -> void:
	assert(check_fn == null or check_fn is Callable)

	var fn_is_enabled := func() -> bool:
		if check_fn:
			return check_fn.call(get("value"))
		else:
			return bool(get("value"))

	value_changed.connect(func(_v: Variant) -> void:
		_set_control_enabled(control, fn_is_enabled.call(), mode)
	)
	_set_control_enabled(control, fn_is_enabled.call(), mode)
	

func _set_control_enabled(control: Control, enabled: bool, mode: DisableMethod) -> void:
	match mode:
		DisableMethod.HIDE:
			control.visible = enabled
		DisableMethod.DISABLE:
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
			control.set(dst_property, enabled if !invert else !enabled)

func _update() -> void:
	assert(false, "not implemented")

func _check_parent() -> void:
	var can_enable := true
	if parent_setting:
		var setting := get_node(parent_setting)
		if _parent_value_check_fn:
			can_enable = _parent_value_check_fn.call(setting.value)
		else:
			can_enable = bool(setting.value)

	# invert if needed
	can_enable = !can_enable if parent_setting_invert else can_enable

	if parent_setting_mode == 0:
		enabled = can_enable
	else:
		visible = can_enable

func _clear_signals() -> void:
	for conn: Dictionary in value_changed.get_connections():
		value_changed.disconnect(conn.callable)
