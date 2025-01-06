class_name SceneMenu extends PanelContainer

var main: Main


func init(p_main: Main) -> void:
	main = p_main

	%ButtonFinish.pressed.connect(func() -> void:
		visible = false
		main.menu.visible = true
	)

func get_param_container() -> GridContainer:
	return %SceneParamsContainer

func clear_params() -> void:
	for c in get_param_container().get_children():
		get_param_container().remove_child(c)
		c.queue_free()

##
## Add a control node from a scene's export variable.
## [property] must match the name of an export var that exists
## in the current scene.
## The type of control is chosen automatically based on the type of the property.
##
func add_auto(property: String, setting_name: String = "") -> SettingBase:

	var regex_int_range := RegEx.new()
	var regex_float_range := RegEx.new()

	regex_int_range.compile("^-?\\d+,-?\\d+$") # match "#,#" export_range patterns
	regex_float_range.compile("^-?\\d+[.]?\\d*,-?\\d+[.]?\\d*,-?\\d+[.]?\\d*$") # match "#,#,#" export_range patterns

	# add menu items
	var scene := main.current_scene
	var property_list := scene.get_property_list()

	for prop: Dictionary in property_list:
		if prop.name != property: continue

		var setting := MenuUtils.create_setting_from_property(prop)

		setting.setting_name = prop.name.capitalize() if setting_name == "" else setting_name
		setting.value = scene.get(property)

		get_param_container().add_child(setting)
		setting.init_config_scene(main, property)

		return setting

	assert(false, "Unable to create setting, property not found: %s" % property)
	return null

##
## Scan and add control nodes for all export variables in the given scene.
##
func add_auto_all() -> void:
	for prop: Dictionary in main.current_scene.get_export_vars():
		add_auto(prop.name)

##
## Add a labled OptionButton to the menu.
## This creates a drop-down list of items.
##
func add_option_custom(property: String, default: int, items: Array[String], value_changed_fn: Variant = null) -> SettingBase:
	assert(property not in main.current_scene)

	var setting := MenuUtils.create_setting_options()
	setting.setting_name = property.capitalize()
	setting.setting_type = 1
	setting.items = items
	setting.value = default
	get_param_container().add_child(setting)
	setting.init_config_scene(main, property, value_changed_fn)

	return setting

func add_file_custom(property: String, default: String, value_changed_fn: Variant = null) -> SettingBase:
	assert(property not in main.current_scene)

	var setting := MenuUtils.create_setting_file()
	setting.setting_name = property.capitalize()
	setting.value = default
	get_param_container().add_child(setting)
	setting.init_config_scene(main, property, value_changed_fn)

	return setting


func add_section(title: String) -> void:
	var label := MenuUtils.create_header(title)
	get_param_container().add_child(label)