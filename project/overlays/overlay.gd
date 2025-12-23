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

	Events.profile_loaded.connect(func(_profile_name: String) -> void: reload())
	reload()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func get_overlay_property_list() -> Array[Dictionary]:
	return get_property_list().filter(
		func(prop: Dictionary) -> bool:
			return (
				prop.usage & PROPERTY_USAGE_STORAGE
				and prop.usage & PROPERTY_USAGE_EDITOR
				and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
				and not prop.name.begins_with("_")
			)
	)


## Return a list of properties that should be config settings.
func get_overlay_property_names() -> Array[String]:
	var array: Array[String] = []
	array.assign(
		get_overlay_property_list().map(func(prop: Dictionary) -> String: return prop.name)
	)
	return array


func reload() -> void:
	if not is_instance_valid(main):
		return

	var config := main.config

	size = config.config_overlay_get(self, "size", size)
	anchors_preset = config.config_overlay_get(self, "anchors_preset", anchors_preset)
	_position_offset = config.config_overlay_get(self, "_position_offset", _position_offset)

	for prop_name in get_overlay_property_names():
		var prop_value: Variant = config.config_overlay_get(self, prop_name, get(prop_name))
		set(prop_name, prop_value)

	_update()

	Log.ln("reloaded overlay from config: %s" % name)


@abstract func _overlay_init() -> void


func _update() -> void:
	pass


func _draw() -> void:
	if _draw_bounds:
		draw_rect(Rect2(_position_offset, size), Color.WHITE, false)
