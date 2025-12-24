@tool
class_name SettingVec3
extends SettingBase

@export var value := Vector3.ZERO:
	set(p_value):
		value = p_value.clamp(min_value, max_value)
		emit_value_changed()

@export var min_value := Vector3.ZERO:
	set(p_value):
		min_value = p_value
		value = value
		emit_ui_changed()

@export var max_value := Vector3(100, 100, 100):
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

@export var prefix_z := "z":
	set(value):
		prefix_z = value
		emit_ui_changed()

@export var suffix := "":
	set(value):
		suffix = value
		emit_ui_changed()

@onready var spin_box_x: SpinBox = %SpinBoxX
@onready var spin_box_y: SpinBox = %SpinBoxY
@onready var spin_box_z: SpinBox = %SpinBoxZ
@onready var label_name: Label = %LabelName
@onready var label_x: Label = %LabelX
@onready var label_y: Label = %LabelY
@onready var label_z: Label = %LabelZ


func _on_ready() -> void:
	spin_box_x.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"
	spin_box_y.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"
	spin_box_z.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"

	spin_box_x.value_changed.connect(
		func(p_value: float) -> void: value = Vector3(p_value, value.y, value.z)
	)
	spin_box_y.value_changed.connect(
		func(p_value: float) -> void: value = Vector3(value.x, p_value, value.z)
	)
	spin_box_z.value_changed.connect(
		func(p_value: float) -> void: value = Vector3(value.x, value.y, p_value)
	)
	spin_box_x.get_line_edit().focus_exited.connect(_update_format)
	spin_box_y.get_line_edit().focus_exited.connect(_update_format)
	spin_box_z.get_line_edit().focus_exited.connect(_update_format)


func _on_changed() -> void:
	if not is_inside_tree():
		await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	spin_box_x.editable = enabled
	spin_box_y.editable = enabled
	spin_box_z.editable = enabled

	if setting_name == "":
		label_name.visible = false
	else:
		label_name.visible = true
		label_name.text = _format_text(setting_name)

	label_name.custom_minimum_size.x = setting_name_min_width

	spin_box_x.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"
	spin_box_y.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"
	spin_box_z.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"

	spin_box_x.min_value = min_value.x
	spin_box_x.max_value = max_value.x

	spin_box_y.min_value = min_value.y
	spin_box_y.max_value = max_value.y

	spin_box_z.min_value = min_value.z
	spin_box_z.max_value = max_value.z

	spin_box_x.value = value.x
	spin_box_y.value = value.y
	spin_box_z.value = value.z

	label_x.text = prefix_x
	label_y.text = prefix_y
	label_z.text = prefix_z

	call_deferred("_update_format")


func _update_format() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	spin_box_x.get_line_edit().text = "%.2f %s" % [value.x, suffix]
	spin_box_y.get_line_edit().text = "%.2f %s" % [value.y, suffix]
	spin_box_z.get_line_edit().text = "%.2f %s" % [value.z, suffix]
