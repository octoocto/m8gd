@tool
extends Control

@export var ratio := size.x / size.y

# var last_size := size


func _ready() -> void:
	item_rect_changed.connect(_on_size_changed)


func _on_size_changed() -> void:
	size.y = size.x / ratio
	# if last_size.x != size.x:
	# 	size.y = size.x / ratio
	# elif last_size.y != size.y:
	# 	size.x = size.y * ratio
	# last_size = size
