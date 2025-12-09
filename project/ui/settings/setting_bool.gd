@tool
class_name SettingBool
extends SettingBase


@export var value := false:
	set(p_value):
		value = p_value
		await _update()
		emit_changed()

@export var text_true := "On":
	set(value):
		text_true = value
		_update()

@export var text_false := "Off":
	set(value):
		text_false = value
		_update()


func _ready() -> void:
	super()
	%CheckButton.toggled.connect(func(p_value: bool) -> void:
		value = p_value
	)
	_update()


func _update() -> void:
	if not is_inside_tree(): await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	%CheckButton.disabled = !enabled

	if setting_name == "":
		%LabelName.visible = false
	else:
		%LabelName.visible = true
		%LabelName.text = setting_name

	%LabelName.custom_minimum_size.x = setting_name_min_width
	%HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	%CheckButton.set_pressed_no_signal(value)
	%LabelValue.text = text_true if value else text_false
