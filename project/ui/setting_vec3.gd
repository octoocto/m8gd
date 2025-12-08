@tool
class_name SettingVec3
extends SettingBase


@export var value := Vector3.ZERO:
	set(p_value):
		value = p_value.clamp(min_value, max_value)
		await _update()
		emit_changed()

@export var min_value := Vector3.ZERO:
	set(p_value):
		min_value = p_value
		value = value
		_update()

@export var max_value := Vector3(100, 100, 100):
	set(p_value):
		max_value = p_value
		value = value
		_update()

@export var show_updown_arrows := false:
	set(p_value):
		show_updown_arrows = p_value
		_update()

@export var prefix_x := "x":
	set(value):
		prefix_x = value
		_update()

@export var prefix_y := "y":
	set(value):
		prefix_y = value
		_update()

@export var prefix_z := "z":
	set(value):
		prefix_z = value
		_update()

@export var suffix := "":
	set(value):
		suffix = value
		_update()


func _ready() -> void:
	super()
	%SpinBoxX.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"
	%SpinBoxY.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"
	%SpinBoxZ.get_line_edit().theme_type_variation = "SettingControlVec2LineEdit"

	%SpinBoxX.value_changed.connect(func(p_value: float) -> void:
		value = Vector3(p_value, value.y, value.z)
	)
	%SpinBoxY.value_changed.connect(func(p_value: float) -> void:
		value = Vector3(value.x, p_value, value.z)
	)
	%SpinBoxZ.value_changed.connect(func(p_value: float) -> void:
		value = Vector3(value.x, value.y, p_value)
	)
	%SpinBoxX.get_line_edit().focus_exited.connect(_update_format)
	%SpinBoxY.get_line_edit().focus_exited.connect(_update_format)
	%SpinBoxZ.get_line_edit().focus_exited.connect(_update_format)

	_update()


func _update() -> void:

	if not is_inside_tree(): await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	%SpinBoxX.editable = enabled
	%SpinBoxY.editable = enabled
	%SpinBoxZ.editable = enabled

	if setting_name == "":
		%LabelName.visible = false
	else:
		%LabelName.visible = true
		%LabelName.text = setting_name

	%LabelName.custom_minimum_size.x = setting_name_min_width

	%SpinBoxX.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"
	%SpinBoxY.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"
	%SpinBoxZ.theme_type_variation = "" if show_updown_arrows else "SettingControlVec2SpinBox"

	%SpinBoxX.min_value = min_value.x
	%SpinBoxX.max_value = max_value.x

	%SpinBoxY.min_value = min_value.y
	%SpinBoxY.max_value = max_value.y

	%SpinBoxZ.min_value = min_value.z
	%SpinBoxZ.max_value = max_value.z

	%SpinBoxX.value = value.x
	%SpinBoxY.value = value.y
	%SpinBoxZ.value = value.z

	%LabelX.text = prefix_x
	%LabelY.text = prefix_y
	%LabelZ.text = prefix_z

	call_deferred("_update_format")


func _update_format() -> void:
	if is_inside_tree(): await get_tree().process_frame
	%SpinBoxX.get_line_edit().text = "%.2f %s" % [value.x, suffix]
	%SpinBoxY.get_line_edit().text = "%.2f %s" % [value.y, suffix]
	%SpinBoxZ.get_line_edit().text = "%.2f %s" % [value.z, suffix]
