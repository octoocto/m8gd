@tool
class_name SettingVec2
extends SettingBase

@export var value := Vector2.ZERO:
	set(p_value):
		value = p_value.clamp(min_value, max_value)
		await _on_changed()
		emit_changed()

@export var min_value := Vector2.ZERO:
	set(p_value):
		min_value = p_value
		value = value
		_on_changed()

@export var max_value := Vector2(100, 100):
	set(p_value):
		max_value = p_value
		value = value
		_on_changed()

@export var show_updown_arrows := false:
	set(p_value):
		show_updown_arrows = p_value
		_on_changed()

@export var prefix_x := "x":
	set(value):
		prefix_x = value
		_on_changed()

@export var prefix_y := "y":
	set(value):
		prefix_y = value
		_on_changed()

@export var suffix := "":
	set(value):
		suffix = value
		_on_changed()


func _on_ready() -> void:
	%SpinBoxX.theme_type_variation = "SettingControlVec2SpinBox"
	%SpinBoxY.theme_type_variation = "SettingControlVec2SpinBox"

	%SpinBoxX.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"
	%SpinBoxY.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"

	%SpinBoxX.value_changed.connect(func(p_value: float) -> void: value = Vector2(p_value, value.y))
	%SpinBoxY.value_changed.connect(func(p_value: float) -> void: value = Vector2(value.x, p_value))
	%SpinBoxX.get_line_edit().focus_exited.connect(_update_format)
	%SpinBoxY.get_line_edit().focus_exited.connect(_update_format)


func _on_changed() -> void:
	if not is_inside_tree():
		await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	%SpinBoxX.editable = enabled
	%SpinBoxY.editable = enabled

	%LabelName.visible = setting_name != ""
	%LabelName.text = setting_name
	%LabelName.custom_minimum_size.x = setting_name_min_width

	%SpinBoxX.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"
	%SpinBoxX.min_value = min_value.x
	%SpinBoxX.max_value = max_value.x
	%SpinBoxX.value = value.x

	%SpinBoxY.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"
	%SpinBoxY.min_value = min_value.y
	%SpinBoxY.max_value = max_value.y
	%SpinBoxY.value = value.y

	%LabelX.text = prefix_x
	%LabelY.text = prefix_y

	call_deferred("_update_format")


func _update_format() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	%SpinBoxX.get_line_edit().text = "%.2f %s" % [value.x, suffix]
	%SpinBoxY.get_line_edit().text = "%.2f %s" % [value.y, suffix]


##
## Initialize this setting to two different camera config properties,
## where the [x] and [y] components of [value] are the values of [property_x] and [property_y].
##
## This setting's initial value will be read from the config, and default to
## the property's value in the current scene's camera.
##
## Changing this setting's value will write the value to the config,
## set the property in the current scene's camera.
##
func setting_connect_camera_2(property_x: String, property_y: String) -> void:
	var config_property_x := main._get_propkey_camera(property_x)
	var config_property_y := main._get_propkey_camera(property_y)
	setting_connect(
		func() -> Variant:
			var camera := main.get_scene_camera()
			if camera:
				assert(property_x in camera, "Property does not exist in camera: %s" % property_x)
				assert(property_y in camera, "Property does not exist in camera: %s" % property_y)
				var default_x: Variant = camera.get(property_x)
				var default_y: Variant = camera.get(property_y)
				return Vector2(
					main.config.get_property_scene(config_property_x, default_x),
					main.config.get_property_scene(config_property_y, default_y)
				)
			else:
				return null,
		func(p_value: Variant) -> void:
			var camera := main.get_scene_camera()
			if camera:
				main.get_scene_camera().set(property_x, p_value.x)
				main.get_scene_camera().set(property_y, p_value.y)
				main.config.set_property_scene(config_property_x, p_value.x)
				main.config.set_property_scene(config_property_y, p_value.y)
	)
