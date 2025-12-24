@tool
@icon("res://assets/icon/Label.png")
class_name UILabel
extends UIBase

@export var min_width: int = 0:
	set(value):
		min_width = value
		emit_ui_changed()

@export var no_padding: bool = false:
	set(value):
		no_padding = value
		emit_ui_changed()

@export_multiline var text: String = "":
	set(value):
		text = value
		emit_ui_changed()

@export var color_override: Variant = -1:
	set(value):
		color_override = value
		emit_ui_changed()

@export var horizontal_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		horizontal_alignment = value
		emit_ui_changed()

@onready var label: Label = %_Label


func _on_changed() -> void:
	if no_padding:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		remove_theme_stylebox_override("panel")

	label.text = _format_text(text)
	label.custom_minimum_size.x = min_width
	label.horizontal_alignment = horizontal_alignment

	label.add_theme_color_override("font_color", _pal_or("text", color_override))

	reset_size()
