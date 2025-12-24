@tool
class_name SettingBool
extends SettingBase

@export var value := false:
	set(p_value):
		value = p_value
		emit_value_changed()

@export var text_true := "On":
	set(value):
		text_true = value
		emit_ui_changed()

@export var text_false := "Off":
	set(value):
		text_false = value
		emit_ui_changed()

@onready var check_button: CheckButton = %CheckButton
@onready var label_name: UILabel = %LabelName
@onready var label_value: UILabel = %LabelValue


func _on_ready() -> void:
	check_button.toggled.connect(func(p_value: bool) -> void: value = p_value)


func _on_changed() -> void:
	if not is_inside_tree():
		await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	check_button.disabled = !enabled

	if setting_name == "":
		label_name.visible = false
	else:
		label_name.visible = true
		label_name.text = _format_text(setting_name)

	label_name.custom_minimum_size.x = setting_name_min_width
	# %HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	check_button.set_pressed_no_signal(value)
	label_value.text = _format_text(text_true if value else text_false)
