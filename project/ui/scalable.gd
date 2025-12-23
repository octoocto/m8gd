@tool
class_name ScalableContainer
extends Container
## A container that scales its children.
##
## All children will be fit to the full size of the container (similar to FULL_RECT) after scaling.

@export var content_scale := 1:
	set(value):
		content_scale = max(value, 1)
		_update_size()


func _ready() -> void:
	get_tree().root.size_changed.connect(_update_size)
	if not Engine.is_editor_hint():
		Events.window_modified.connect(_update_size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_update_size()


func _update_size() -> void:
	if not is_inside_tree():
		return

	scale = Vector2(content_scale, content_scale)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0 / content_scale
	anchor_bottom = 1.0 / content_scale

	for c in get_children():
		fit_child_in_rect(c, Rect2(Vector2.ZERO, size))
