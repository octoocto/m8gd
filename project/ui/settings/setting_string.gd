@tool
class_name SettingString
extends SettingBase

@export var value := "":
	set(p_value):
		if validate:
			value = validate_string(p_value)
		else:
			value = p_value
		emit_value_changed()

@export var validate := false:
	set(p_value):
		validate = p_value
		value = value

@onready var line_edit: LineEdit = %LineEdit
@onready var label_name: UILabel = %LabelName


func _on_ready() -> void:
	line_edit.text_changed.connect(func(p_value: String) -> void: value = p_value)


func _on_changed() -> void:
	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	line_edit.editable = enabled

	if setting_name == "":
		label_name.visible = false
	else:
		label_name.visible = true
		label_name.text = _format_text(setting_name)

	label_name.custom_minimum_size.x = setting_name_min_width
	# %HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	if not line_edit.has_focus():
		line_edit.text = value
