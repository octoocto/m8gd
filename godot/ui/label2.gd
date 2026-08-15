@tool
@icon("res://assets/icon/Label.png")
class_name UILabel2
extends UIBase

@export var min_width_left: int = LEFT_WIDTH:
	set(value):
		min_width_left = value
		emit_ui_changed()

@export var no_padding: bool = false:
	set(value):
		no_padding = value
		emit_ui_changed()

@export var text_left: String = "":
	set(value):
		text_left = value
		emit_ui_changed()

@export var text: String = "":
	set(value):
		text = value
		emit_ui_changed()

@export var color_override: Variant = -1:
	set(value):
		color_override = value
		emit_ui_changed()

@export var color_override_right: Variant = -1:
	set(value):
		color_override_right = value
		emit_ui_changed()

@export var align_right_text_to_right: bool = false:
	set(value):
		align_right_text_to_right = value
		emit_ui_changed()

@onready var label_left: Label = %LabelLeft
@onready var label_right: Label = %LabelRight
@onready var hbox: HBoxContainer = %HBoxContainer


func _on_ready() -> void:
	hbox.add_theme_constant_override("separation", 0)


func _on_changed() -> void:
	if no_padding:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		remove_theme_stylebox_override("panel")

	if align_right_text_to_right:
		label_right.size_flags_horizontal = Control.SIZE_SHRINK_END + Control.SIZE_EXPAND
	else:
		label_right.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	label_left.custom_minimum_size.x = min_width_left

	label_left.text = _format_text(text_left)
	label_right.text = _format_text(text)

	label_left.add_theme_color_override("font_color", _pal_or("text", color_override))
	label_right.add_theme_color_override("font_color", _pal_or("text_right", color_override_right))
