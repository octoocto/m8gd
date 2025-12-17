@tool
class_name SettingOptions
extends SettingBase

@export_enum("Arrows", "Dropdown") var setting_type := 0:
	set(value):
		setting_type = value
		emit_ui_changed()

@export var items: PackedStringArray

@export var value := -1:
	set(p_value):
		value = clampi(p_value, 0, items.size() - 1) if items.size() else -1
		emit_value_changed()

@onready var option_button: UIOptionButton = %OptionButton


func _on_ready() -> void:
	%ButtonLeft.pressed.connect(func() -> void: value -= 1)
	%ButtonRight.pressed.connect(func() -> void: value += 1)

	option_button.item_selected.connect(func(p_value: int) -> void: value = p_value)
	option_button.get_popup().canvas_item_default_texture_filter = (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)

	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	reset_size()


func _on_changed() -> void:
	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)

	%LabelName.visible = setting_name != ""

	if ignore_text_format:
		%LabelName.text = setting_name
	else:
		%LabelName.text = _format_text(setting_name)

	%LabelName.custom_minimum_size.x = setting_name_min_width

	%ButtonLeft.visible = false
	%ButtonRight.visible = false
	%LabelValue.visible = false
	%OptionButton.visible = false

	match setting_type:
		0:  # arrows
			%ButtonLeft.visible = true
			%ButtonLeft.disabled = !enabled or value <= 0

			%ButtonRight.visible = true
			%ButtonRight.disabled = !enabled or value >= items.size() - 1

			%LabelValue.visible = true
			%LabelValue.text = _format_text(items[value]) if items.size() > 0 else ""
		1:  # dropdown
			option_button.visible = true
			if items.size():
				option_button.clear()
				for item: String in items:
					option_button.add_item(_format_text(item))
				option_button.selected = value
