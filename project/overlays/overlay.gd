class_name OverlayBase extends Control

@export var position_offset := Vector2i.ZERO:
	set(value):
		position_offset = value
		_update()

@export var draw_bounds := false:
	set(value):
		draw_bounds = value
		_update()

var main: Main

func init(p_main: Main) -> void:
	main = p_main

func _update() -> void:
	pass

func overlay_get_properties() -> Array[String]:
	return []
