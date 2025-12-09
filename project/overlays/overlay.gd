@tool
class_name OverlayBase
extends Control

@export var position_offset := Vector2i.ZERO:
	set(value):
		position_offset = value
		_update()

@export var draw_bounds := false:
	set(value):
		draw_bounds = value
		_update()

var main: Main

func _ready() -> void:
	if not Engine.is_editor_hint():
		await Events.initialized
	else:
		await get_tree().create_timer(0.1).timeout

	main = Main.instance

	if not Engine.is_editor_hint():
		Log.call_task(_overlay_init, "init overlay '%s'" % name)

## Return a list of properties that should be config settings.
func overlay_get_properties() -> Array[String]:
	return []

func _overlay_init() -> void:
	assert(false, "_overlay_init() not implemented in %s" % name)

func _update() -> void:
	pass
