@tool
class_name SettingColor extends SettingBase

@export var value := Color.WHITE:
	set(p_value):
		value = p_value
		emit_value_changed()

@export var edit_alpha := true:
	set(p_value):
		edit_alpha = p_value
		emit_ui_changed()

@export var show_html := true:
	set(p_value):
		show_html = p_value
		emit_ui_changed()

@export var button_min_size := Vector2():
	set(p_value):
		button_min_size = p_value
		emit_ui_changed()

@onready var reset_value: Color = value

@onready var button: ColorPickerButton = %ColorPickerButton

@onready var picker: ColorPicker = button.get_picker()

@onready var spacer_l: Control = %SpacerLeft
@onready var spacer_r: Control = %SpacerRight


func _on_ready() -> void:
	button.color_changed.connect(func(p_value: Color) -> void: value = p_value)
	# reset to default handler
	button.gui_input.connect(
		func(event: InputEvent) -> void:
			if (
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_RIGHT
				and event.pressed
			):
				%ColorPickerButton.accept_event()
				value = reset_value
	)

	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	%PanelContainer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	reset_size()

	picker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _on_changed() -> void:
	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)
	button.disabled = !enabled
	button.edit_alpha = edit_alpha
	button.custom_minimum_size = button_min_size

	if button_min_size == Vector2():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	if setting_name == "":
		%LabelName.visible = false
		%HBoxContainer.visible = false
	else:
		%LabelName.text = _format_text(setting_name)
		%LabelName.visible = true
		%HBoxContainer.visible = true

	spacer_r.visible = label_separation > 0
	spacer_r.custom_minimum_size.x = label_separation

	# %PanelContainer.set("theme_override_styles/panel", panel_style_value)

	%LabelName.horizontal_alignment = label_alignment
	%LabelName.custom_minimum_size.x = setting_name_min_width
	%LabelName.color_override = _pal("text")

	%HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	button.color = value
	%LabelValue.text = "%s" % value.to_html(false).to_upper()
	%LabelValue.visible = show_html
	%LabelValue.color_override = _pal("text_value")


func get_color_picker() -> ColorPicker:
	return picker
