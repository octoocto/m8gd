@tool
class_name SettingButton
extends SettingBase

signal pressed

@export var value: bool = false:
	set(p_value):
		value = p_value
		await _on_changed()
		emit_changed()

@onready var button: Button = %Button


func _on_ready() -> void:
	button.pressed.connect(
		func() -> void:
			value = true
			value = false
			pressed.emit()
	)


func _on_changed() -> void:
	if not is_inside_tree():
		await ready
	button.disabled = not enabled
	button.text = setting_name
	custom_minimum_size.x = setting_name_min_width
