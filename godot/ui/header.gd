@tool
@icon("res://assets/icon/Label.png")
class_name UIHeader
extends UIBase

@export var text: String = "":
	set(value):
		text = value
		emit_ui_changed()

@export var panel_style: StyleBox = null:
	set(value):
		panel_style = value
		emit_ui_changed()

@export var top_spacing := true:
	set(value):
		top_spacing = value
		emit_ui_changed()

@export var color_override: Variant = -1:
	set(value):
		color_override = value
		emit_ui_changed()

@onready var label: UILabel = %Label
@onready var top_separator: HSeparator = %HSeparator


func _on_changed() -> void:
	if not is_inside_tree():
		await ready

	label.text = _format_text(text)
	label.color_override = _pal_or("header", color_override)

	top_separator.visible = top_spacing
