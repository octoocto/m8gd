@tool
@abstract class_name OverlayBase
extends Control

@export var _position_offset := Vector2i.ZERO:
	set(value):
		_position_offset = value
		_update()

@export var _draw_bounds := false:
	set(value):
		_draw_bounds = value
		_update()

var position_offset: Vector2i:
	get:
		return _position_offset

var main: Main


func _ready() -> void:
	self.main = await Main.get_instance()
	if self.main:
		Log.call_task(_overlay_init, "init overlay '%s'" % name)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## Return a list of properties that should be config settings.
func overlay_get_properties() -> Array[String]:
	return []


func reload() -> void:
	if not is_instance_valid(main):
		return

	var config := main.config

	size = config.config_overlay_get(self, "size", size)
	anchors_preset = config.config_overlay_get(self, "anchors_preset", anchors_preset)
	position_offset = config.config_overlay_get(self, "position_offset", position_offset)

	for prop_name in overlay_get_properties():
		var prop_value: Variant = config.config_overlay_get(self, prop_name, get(prop_name))
		set(prop_name, prop_value)

	Log.ln("reloaded overlay from config: %s" % name)


@abstract func _overlay_init() -> void


func _update() -> void:
	pass


func _draw() -> void:
	if _draw_bounds:
		draw_rect(Rect2(_position_offset, size), Color.WHITE, false)
