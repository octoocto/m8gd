class_name SceneMenu extends PanelContainer

var main: M8SceneDisplay

signal setting_changed(propname: String, value: Variant)

signal setting_editable(propname: String, editable: bool)

func init(p_main: M8SceneDisplay) -> void:
	main = p_main

	%ButtonFinish.pressed.connect(func() -> void:
		visible = false
		main.menu.visible = true
	)

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

##
## Set a property in the current scene to the saved value from the config.
## If a saved value doesn't exist, saves the current value of the property to the config.
##
func _set_prop_from_config(propname: String) -> void:
	var default: Variant = main.current_scene.get(propname)
	main.current_scene.set(propname, main.config.get_property_scene(propname, default))

##
## Set a property in the current scene and in the config.
##
func _set_prop(propname: String, value: Variant) -> void:
	main.current_scene.set(propname, value)
	main.config.set_property_scene(propname, value)

##
## Get the value of a property from the config.
##
func _get_prop(propname: String) -> Variant:
	var default: Variant = main.current_scene.get(propname)
	return main.config.get_property_scene(propname, default)

##
## Set a custom property in ONLY the config.
## This will not be set in the current scene.
##
func _set_prop_custom(key: String, value: Variant) -> void:
	key = "custom.%s" % key
	main.config.set_property_scene(key, value)

##
## Get the value of a custom property from the config.
## [default] will be returned if the property does not exist.
##
func _get_prop_custom(key: String, default: Variant = null) -> Variant:
	key = "custom.%s" % key
	return main.config.get_property_scene(key, default)


##
## Scan and add control nodes for all export variables in the given scene.
##
func add_exports_from(scene: M8Scene) -> void:
	for prop: Dictionary in main.current_scene.get_export_vars():
		add_auto(prop.name)

##
## Add a control node from a scene's export variable.
## [property] must match the name of an export var that exists
## in the current scene.
## The type of control is chosen automatically based on the type of the property.
##
func add_auto(property: String) -> void:

	var regex_int_range := RegEx.new()
	var regex_float_range := RegEx.new()

	regex_int_range.compile("^-?\\d+,-?\\d+$") # match "#,#" export_range patterns
	regex_float_range.compile("^-?\\d+[.]?\\d*,-?\\d+[.]?\\d*,-?\\d+[.]?\\d*$") # match "#,#,#" export_range patterns

	# add menu items
	var export_vars := main.current_scene.get_export_vars()
	for v: Dictionary in export_vars:
		if v.name != property:
			continue

		if v.type == TYPE_BOOL:
			add_bool(property)
			break

		if v.type == TYPE_FLOAT:
			add_float(property, 0.0, 1.0, 0.01)
			break

		if v.type == TYPE_COLOR:
			add_color(property)
			break

		if v.type == TYPE_VECTOR2I:
			add_vec2i(property)
			break

		if v.type == TYPE_INT:
		# if regex_int_range.search(v.hint_string):
			var range_min := int(v.hint_string.split(",")[0])
			var range_max := int(v.hint_string.split(",")[1])
			add_int(property, range_min, range_max)
			break

		if v.type == TYPE_FLOAT:
		# if regex_float_range.search(v.hint_string):
			var range_min := float(v.hint_string.split(",")[0])
			var range_max := float(v.hint_string.split(",")[1])
			var step := float(v.hint_string.split(",")[2])
			add_float(property, range_min, range_max, step)
			break

		printerr("scene: unrecognized export var type: %s" % v.hint_string)


func add_bool(propname: String, fn: Variant = null) -> void:
	var control := MenuUtils.create_bool_scene_prop(propname, propname, fn)
	get_param_container().add_child(control)


func add_color(propname: String, fn: Variant = null) -> void:
	var control := MenuUtils.create_colorpicker_scene_prop(propname, propname, fn)
	get_param_container().add_child(control)


func add_float(propname: String, range_min: float, range_max: float, step: float, fn: Variant = null) -> void:
	var control := MenuUtils.create_slider_scene_prop(propname, propname, "%.2f", range_min, range_max, step, fn)
	get_param_container().add_child(control)


func add_int(propname: String, range_min: int, range_max: int, fn: Variant = null) -> void:
	var control := MenuUtils.create_slider_scene_prop(propname, propname, "%d", range_min, range_max, 1.0, fn)
	get_param_container().add_child(control)


func add_vec2i(propname: String, fn: Variant = null) -> void:
	var control := MenuUtils.create_vec2i_scene_prop(propname, propname, fn)
	get_param_container().add_child(control)

##
## Add a labled OptionButton to the menu.
## This creates a drop-down list of items.
##
func add_option(propname: String, items: Array[String], fn: Variant = null) -> void:
	var callback := func(value: int) -> void:
		_set_prop(propname, value)
		if fn is Callable: fn.call(value)
	var control := MenuUtils.create_option_scene_prop(propname, propname, null, items, callback)
	get_param_container().add_child(control)

##
## Add a labled OptionButton to the menu.
## This creates a drop-down list of items.
##
func add_option_custom(key: String, default: int, items: Array[String], fn: Variant = null) -> void:
	var callback := func(value: int) -> void:
		_set_prop_custom(key, value)
		if fn is Callable: fn.call(value)
	var control := MenuUtils.create_option_scene_prop(key, key, default, items, callback)
	get_param_container().add_child(control)


func add_file_custom(propname: String, default: String, fn: Variant = null) -> void:
	var callback := func(value: String) -> void:
		_set_prop_custom(propname, value)
		if fn is Callable: fn.call(value)
	var control := MenuUtils.create_file_scene_prop(propname, propname, default, callback)
	get_param_container().add_child(control)


func add_section(title: String) -> void:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.bbcode_enabled = true
	label.text = "[b]%s[/b]" % title
	label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
	get_param_container().add_child(label)

func reg_link_editable(from_setting: String, to_setting: String) -> void:
	setting_editable.emit(to_setting, bool(_get_prop(from_setting)))
	setting_changed.connect(func(propname: String, value: Variant) -> void:
		if propname == from_setting:
			setting_editable.emit(to_setting, bool(value))
	)
