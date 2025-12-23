@tool
class_name OverlayContainer
extends ScalableContainer

@onready var _control: Control = $Control

@onready var keycast: OverlayKeycast = %OverlayKeycast

var main: Main

var _overlays: Array[OverlayBase] = []


func _ready() -> void:
	main = await Main.get_instance(true)

	_overlays.assign(_control.get_children())
	Log.ln("found %d overlays" % _overlays.size())

	if not is_instance_valid(main):
		return

	reload_overlays()


func reload_overlays() -> void:
	for overlay: OverlayBase in _overlays:
		overlay.reload()


func get_overlays() -> Array[OverlayBase]:
	return _overlays
