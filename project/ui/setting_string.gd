@tool
extends SettingBase


@export var value := "":
	set(p_value):
		value = p_value
		await _update()
		force_update()


func _ready() -> void:
	super()
	%LineEdit.text_changed.connect(func(p_value: String) -> void:
		value = p_value
	)
	_update()


func _update() -> void:
	if not is_inside_tree(): await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	%LineEdit.editable = enabled

	if setting_name == "":
		%LabelName.visible = false
	else:
		%LabelName.visible = true
		%LabelName.text = setting_name

	%LabelName.custom_minimum_size.x = setting_name_min_width
	%HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	if not %LineEdit.has_focus():
		%LineEdit.text = value


func init(p_value: Variant, changed_fn: Callable) -> void:
	assert(p_value is bool)
	super(p_value, changed_fn)
