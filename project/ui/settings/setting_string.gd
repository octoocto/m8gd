@tool
class_name SettingString
extends SettingBase

@export var value := "":
	set(p_value):
		value = p_value
		emit_value_changed()


func _on_ready() -> void:
	%LineEdit.text_changed.connect(func(p_value: String) -> void: value = p_value)


func _on_changed() -> void:
	if not is_inside_tree():
		await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	%LineEdit.editable = enabled

	if setting_name == "":
		%LabelName.visible = false
	else:
		%LabelName.visible = true
		%LabelName.text = _format_text(setting_name)

	%LabelName.custom_minimum_size.x = setting_name_min_width
	%HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	if not %LineEdit.has_focus():
		%LineEdit.text = value
