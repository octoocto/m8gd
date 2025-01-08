@tool
class_name SettingColor extends SettingBase

@onready var reset_value: Color = value

@export var value := Color.WHITE:
	set(p_value):
		value = p_value
		await _update()
		force_update()

@export var edit_alpha := true:
	set(p_value):
		edit_alpha = p_value
		_update()

@export var show_html := true:
	set(p_value):
		show_html = p_value
		_update()

@export var panel_style_value: StyleBox = null:
	set(p_value):
		panel_style_value = p_value
		_update()


func _ready() -> void:
	super()
	%ColorPickerButton.color_changed.connect(func(p_value: Color) -> void:
		value = p_value
	)
	# reset to default handler
	%ColorPickerButton.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			%ColorPickerButton.accept_event()
			value = reset_value
	)
	_update()


func _update() -> void:
	if not is_inside_tree(): await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	%ColorPickerButton.disabled = !enabled
	%ColorPickerButton.edit_alpha = edit_alpha

	if setting_name == "":
		%LabelName.visible = false
		%HBoxContainer.visible = false
	else:
		%LabelName.text = setting_name
		%LabelName.visible = true
		%HBoxContainer.visible = true

	%PanelContainer.set("theme_override_styles/panel", panel_style_value)

	%LabelName.custom_minimum_size.x = setting_name_min_width
	%HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	%ColorPickerButton.color = value
	%LabelValue.text = "#%s" % value.to_html(false).to_upper()
	%LabelValue.visible = show_html


func init(p_value: Variant, changed_fn: Callable) -> void:
	assert(p_value is Color)
	super(p_value, changed_fn)


func get_color_picker() -> ColorPicker:
	return %ColorPickerButton.get_picker()
