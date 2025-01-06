class_name OverlayBase extends Control

@export var position_offset := Vector2i.ZERO:
	set(value):
		position_offset = value
		_update()

@export var draw_bounds := false:
	set(value):
		draw_bounds = value
		_update()

func _update() -> void:
	pass