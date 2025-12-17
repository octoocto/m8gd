@tool
class_name SceneConfigMenu
extends MenuFrameBase

@onready var params_container: VBoxContainer = %SceneParamsContainer


func _on_menu_init() -> void:
	super()

	Events.scene_loaded.connect(
		func(scene_path: String, _scene: M8Scene) -> void:
			assert(main.current_scene, "There is no M8 scene loaded!")
			_clear_params()
			main.current_scene.init_menu(self)
			Log.ln("initialized %d param(s) from scene: %s" % [_num_params(), scene_path])
	)


func _clear_params() -> void:
	for c in params_container.get_children():
		c.queue_free()
	Log.ln("cleared params")


func _num_params() -> int:
	return params_container.get_children().size()


##
## Add a control node from a scene's export variable.
## [property] must match the name of an export var that exists
## in the current scene.
## The type of control is chosen automatically based on the type of the property.
##
func add_auto(property: String, setting_name: String = "") -> SettingBase:
	var regex_int_range := RegEx.new()
	var regex_float_range := RegEx.new()

	regex_int_range.compile("^-?\\d+,-?\\d+$")  # match "#,#" export_range patterns
	regex_float_range.compile("^-?\\d+[.]?\\d*,-?\\d+[.]?\\d*,-?\\d+[.]?\\d*$")  # match "#,#,#" export_range patterns

	# add menu items
	var scene := main.current_scene
	var property_list := scene.get_property_list()

	for prop: Dictionary in property_list:
		if prop.name != property:
			continue

		var setting := MenuUtils.create_setting_from_property(prop)

		setting.setting_name = prop.name.capitalize() if setting_name == "" else setting_name
		setting.value = scene.get(property)

		params_container.add_child(setting)
		setting.setting_connect_scene(property)

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
func add_option_custom(
	property: String, default: int, items: Array[String], value_changed_fn := Callable()
) -> SettingBase:
	assert(property not in main.current_scene)

	var setting := MenuUtils.create_setting_options()
	setting.setting_name = property.capitalize()
	setting.setting_type = 1
	setting.items = items
	setting.value = default
	params_container.add_child(setting)
	setting.setting_connect_scene(property, value_changed_fn)

	return setting


func add_file_custom(
	property: String, default: String, value_changed_fn := Callable()
) -> SettingBase:
	assert(property not in main.current_scene)

	var setting := MenuUtils.create_setting_file()
	setting.setting_name = property.capitalize()
	setting.value = default
	params_container.add_child(setting)
	setting.setting_connect_scene(property, value_changed_fn)

	return setting


func add_section(section_title: String) -> void:
	var label := MenuUtils.create_header(section_title)
	params_container.add_child(label)
