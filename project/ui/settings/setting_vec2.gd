@tool
class_name SettingVec2
extends SettingBase

@export var value := Vector2.ZERO:
	set(p_value):
		value = p_value.clamp(min_value, max_value)
		emit_value_changed()

@export var min_value := Vector2.ZERO:
	set(p_value):
		min_value = p_value
		value = value
		emit_ui_changed()

@export var max_value := Vector2(100, 100):
	set(p_value):
		max_value = p_value
		value = value
		emit_ui_changed()

@export var show_updown_arrows := false:
	set(p_value):
		show_updown_arrows = p_value
		emit_ui_changed()

@export var prefix_x := "x":
	set(value):
		prefix_x = value
		emit_ui_changed()

@export var prefix_y := "y":
	set(value):
		prefix_y = value
		emit_ui_changed()

@export var suffix := "":
	set(value):
		suffix = value
		emit_ui_changed()

@onready var spin_box_x: SpinBox = %SpinBoxX
@onready var spin_box_y: SpinBox = %SpinBoxY
@onready var label_name: Label = %LabelName
@onready var label_x: Label = %LabelX
@onready var label_y: Label = %LabelY


func _on_ready() -> void:
	spin_box_x.theme_type_variation = "SettingControlVec2SpinBox"
	spin_box_y.theme_type_variation = "SettingControlVec2SpinBox"

	spin_box_x.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"
	spin_box_y.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"

	spin_box_x.value_changed.connect(
		func(p_value: float) -> void: value = Vector2(p_value, value.y)
	)
	spin_box_y.value_changed.connect(
		func(p_value: float) -> void: value = Vector2(value.x, p_value)
	)
	spin_box_x.get_line_edit().focus_exited.connect(_update_format)
	spin_box_y.get_line_edit().focus_exited.connect(_update_format)


func _on_changed() -> void:
	if not is_inside_tree():
		await ready

	spin_box_x.get_line_edit().caret_blink = true
	spin_box_x.get_line_edit().add_theme_color_override("selection_color", _pal("input_selection"))
	spin_box_x.get_line_edit().add_theme_color_override("caret_color", _pal("input_caret"))

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	spin_box_x.editable = enabled
	spin_box_y.editable = enabled

	label_name.visible = setting_name != ""
	label_name.text = _format_text(setting_name)
	label_name.custom_minimum_size.x = setting_name_min_width

	spin_box_x.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"
	spin_box_x.min_value = min_value.x
	spin_box_x.max_value = max_value.x
	spin_box_x.value = value.x

	spin_box_y.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"
	spin_box_y.min_value = min_value.y
	spin_box_y.max_value = max_value.y
	spin_box_y.value = value.y

	label_x.text = prefix_x
	label_y.text = prefix_y

	call_deferred("_update_format")


func _update_format() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	spin_box_x.get_line_edit().text = "%.2f %s" % [value.x, suffix]
	spin_box_y.get_line_edit().text = "%.2f %s" % [value.y, suffix]


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
	setting_connect(
		func() -> Variant:
			var camera := main.get_scene_camera()
			var scene := main.current_scene
			if camera:
				assert(property_x in camera, "Property does not exist in camera: %s" % property_x)
				assert(property_y in camera, "Property does not exist in camera: %s" % property_y)
				var default_x: Variant = camera.get(property_x)
				var default_y: Variant = camera.get(property_y)
				return Vector2(
					main.config.get_value_scene(scene, property_x, default_x) as float,
					main.config.get_value_scene(scene, property_y, default_y) as float
				)
			else:
				return null,
		func(p_value: Variant) -> void:
			var camera := main.get_scene_camera()
			var scene := main.current_scene
			if camera:
				main.get_scene_camera().set(property_x, p_value.x)
				main.get_scene_camera().set(property_y, p_value.y)
				main.config.set_value_scene(scene, property_x, p_value.x)
				main.config.set_value_scene(scene, property_y, p_value.y)
	)
