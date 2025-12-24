@abstract class_name SettingBase
extends UIBase

var STYLEBOX_FOCUS := preload("res://ui/theme/stylebox_focus.tres")

signal value_changed(value: Variant)

enum DisableMethod {
	DISABLE, # show but make non-editable subsettings that have been disabled
	HIDE,    # hide subsettings that have been disabled
}

@export var setting_name := "":
	set(value):
		setting_name = value
		emit_ui_changed()

@export var setting_name_min_width := LEFT_WIDTH:
	set(value):
		setting_name_min_width = value
		emit_ui_changed()

@export var setting_name_indent := 0:
	set(value):
		setting_name_indent = max(0, value)
		emit_ui_changed()

@export var label_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		label_alignment = value
		emit_ui_changed()

@export var label_separation := 0:
	set(value):
		label_separation = value
		emit_ui_changed()

@export var ignore_text_format := false:
	set(p_value):
		ignore_text_format = p_value
		emit_ui_changed()

var _default_value: Variant

var main: Main

var config: M8Config

var is_initialized: bool:
	get():
		return _is_initialized

## If true, one of the [connect] methods has been called.
var _is_initialized := false

## If true, fire the [value_changed] signal when [value] is set.
var _value_changed_signal_enabled := true

## Set to a Callable that gets the initial value of [value].
## This callable should try to read a value from the config file first, or return a default value.
var _value_read_fn: Callable

func _ready() -> void:
	assert(get("value") != null, "SettingBase subclass %s must have a 'value' property" % name)
	_default_value = get("value")

	self.main = await Main.get_instance()
	if is_instance_valid(self.main):
		self.config = main.config

	super()

func get_value() -> Variant:
	return get("value")

func set_value(value: Variant) -> void:
	set("value", value)

func set_value_no_signal(value: Variant) -> void:
	_value_changed_signal_enabled = false
	set("value",value)
	_value_changed_signal_enabled = true

func emit_value_changed() -> void:
	emit_ui_changed()
	if _value_changed_signal_enabled:
		value_changed.emit(get("value"))
	# else:
	# 	print("%s: value_changed signal suppressed" % name)

##
## Re-initialize this setting to an initial value and emits [value_changed].
## This is useful when a profile or scene has just been loaded, and
## the initial value could be different.
##
func reload(emit_value_changed_signal := true) -> void:
	assert(_is_initialized and _value_read_fn, "This setting has not been initialized yet: %s" % name)
	if emit_value_changed_signal:
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
## Connect this setting to arbitrary callback functions.
##
## [/br][param value_read_fn] called to read the value from the config, or get a default value.
## [/br][param value_write_fn] called when the value in this setting changes and needs to be written to the config.
##
func setting_connect(value_read_fn: Variant, value_changed_fn: Callable) -> void:
	assert(!_is_initialized, "This setting has already been initialized: %s" % name)
	assert(is_instance_valid(self.main), "Tried to initialize setting, but main has not finished initializing")
	assert(is_instance_valid(self.config), "Tried to initialize setting, but config is not loaded")
	assert(value_changed_fn is Callable and value_changed_fn.is_valid(), "value_changed_fn must be a valid Callable")
	assert("value" in self, "SettingBase subclass %s must have a 'value' property" % name)

	if value_read_fn is Callable:
		_value_read_fn = value_read_fn
	else:
		_value_read_fn = func() -> Variant: return value_read_fn
		
	value_changed.connect(value_changed_fn)
	set("value", _value_read_fn.call())

	_is_initialized = true

##
## Link this setting to a global config property and a callback function
## for the [value_changed] signal.
##
## This will initialize the value of this setting from the config and
## emit the [value_changed] signal.
##
## This setting's value will default to the corresponding property in [config_file.gd].
##
func setting_connect_global(property: String, value_changed_fn := Callable()) -> void:
	setting_connect(
		# on read
		func() -> Variant: return main.config.get_global_value(property),
		# on write
		func(value: Variant) -> void:
			main.config.set_global_value(property, value)
			if value_changed_fn.is_valid(): value_changed_fn.call(value)
			Events.setting_changed.emit(self, value)
	)

##
## This setting's value will default to its current value in the inspector.
##
func setting_connect_profile(section: String, key: String, value_changed_fn := Callable()) -> void:
	setting_connect(
		# on read
		func() -> Variant:
			return main.config.get_value(section, key, _default_value),

		# on write
		func(value: Variant) -> void:
			main.config.set_value(section, key, value)
			if value_changed_fn.is_valid(): value_changed_fn.call(value)
			Events.setting_changed.emit(self, value)
	)

func setting_connect_overlay_global(key: String, value_changed_fn := Callable()) -> void:
	setting_connect_profile(config.SECTION_OVERLAY, key, value_changed_fn)

func setting_connect_shader_global(key: String, value_changed_fn := Callable()) -> void:
	setting_connect_profile(config.SECTION_SHADER, key, value_changed_fn)

func setting_connect_colors(key: String, value_changed_fn := Callable()) -> void:
	setting_connect_profile(config.SECTION_COLORS, key, value_changed_fn)

func setting_connect_model(key: String, value_changed_fn := Callable()) -> void:
	setting_connect_profile(config.SECTION_MODEL, key, value_changed_fn)

##
## Initialize this setting to a scene property.
##
## This setting's initial value will be read from the config, and default to
## the property's value in the current scene.
##
func setting_connect_scene(property: String, value_changed_fn := Callable()) -> void:
	setting_connect(
		# on read
		func() -> Variant:
			var scene := main.current_scene
			if property in scene:
				return config.get_value_scene(scene, property, scene.get(property))
			else:
				return config.get_value_scene(scene, property, get("value")),
		# on write
		func(value: Variant) -> void:
			var scene := main.current_scene
			if property in scene:
				scene.set(property, value)
			config.set_value_scene(scene, property, value)
			if value_changed_fn.is_valid(): value_changed_fn.call(value)
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
func setting_connect_overlay(overlay: Control, property: String, value_changed_fn := Callable()) -> void:
	setting_connect(
		# on read
		func() -> Variant: return config.get_value_overlay(overlay, property, overlay.get(property)),

		# on write
		func(value: Variant) -> void:
			config.set_value_overlay(overlay, property, value)
			if value_changed_fn.is_valid(): value_changed_fn.call(value)
			Events.setting_changed.emit(self, value)
	)

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
	setting_connect(
		# on read
		func() -> Variant:
			var scene := main.current_scene
			var init_value: Variant
			if main.get_scene_camera():
				var default: Variant
				if value_init_fn is Callable and (value_init_fn as Callable).is_valid():
					default = (value_init_fn as Callable).call()
				else:
					default = main.get_scene_camera().get(property)
				init_value = config.get_value_scene(scene, property, default)
			else:
				init_value = null
			return init_value,
		# on write
		func(value: Variant) -> void:
			var scene := main.current_scene
			if main.get_scene_camera():
				config.set_value_scene(scene, property, value)
				if value_changed_fn is Callable and (value_changed_fn as Callable).is_valid():
					(value_changed_fn as Callable).call(value)
				else:
					main.get_scene_camera().set(property, value)
				Events.setting_changed.emit(self, value)
	)

##
## Connect this setting to a shader uniform.
## This setting's value will default to its current value of the property in [overlay].
##
func conf_shader_parameter(shader_rect: ShaderRect, parameter: String) -> void:
	assert(shader_rect)
	setting_connect(
		# on read
		func() -> Variant:
			var default: Variant = shader_rect.get_uniform_value(parameter)
			return main.config.get_value_shader(shader_rect, parameter, default),
		# on write
		func(value: Variant) -> void:
			main.shaders.set_shader_parameter(shader_rect, parameter, value)
			main.config.set_value_shader(shader_rect, parameter, value)
			Events.setting_changed.emit(self, value)
	)

func validate_string(value: String) -> String:
	# var regex := RegEx.new()
	# regex.compile("__+")
	value = value.strip_edges()
	value = value.validate_filename()
	# value = value.to_snake_case()
	# value = regex.sub(value, "_", true)
	return value


func _clear_signals() -> void:
	for conn: Dictionary in value_changed.get_connections():
		value_changed.disconnect(conn.callable as Callable)
