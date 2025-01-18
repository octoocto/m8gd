@tool
extends SubViewport

@export_range(0, 10) var integer_scale := 0:
	set(value):
		integer_scale = value
		if integer_scale == 0:
			size_2d_override_stretch = false
			size = size_2d_override
		else:
			size_2d_override_stretch = true
			size = size_2d_override * integer_scale

@export var integer_size := Vector2i(640, 480):
	set(value):
		integer_size = value
		size_2d_override = integer_size
		integer_scale = integer_scale