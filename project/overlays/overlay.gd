@tool
@abstract class_name OverlayBase
extends Control

@export var _position_offset := Vector2i.ZERO:
	set(value):
		_position_offset = value
		self._overlay_update()

@export var _draw_bounds := false:
	set(value):
		_draw_bounds = value
		self._overlay_update()

var position_offset: Vector2i:
	get:
		return _position_offset

var main: Main


func _ready() -> void:
	self.main = await Main.get_instance()
	if self.main:
		Log.call_task(_overlay_init, "init overlay '%s'" % name)

	Events.preset_loaded.connect(func(_profile_name: String) -> void: reload())
	reload()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func set_property(property_name: StringName, value: Variant) -> void:
	for property in self.get_property_list():
		if property.name == property_name:
			self.set(property_name, value)
			self._overlay_update()
			break


func get_overlay_property_list() -> Array[Dictionary]:
	return get_property_list().filter(
		func(prop: Dictionary) -> bool:
			return (
				prop.usage & PROPERTY_USAGE_STORAGE
				and prop.usage & PROPERTY_USAGE_EDITOR
				and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
				and not (prop.name as String).begins_with("_")
			)
	)


## Return a list of properties that should be config settings.
func get_overlay_property_names() -> Array[String]:
	var array: Array[String] = []
	array.assign(
		get_overlay_property_list().map(func(prop: Dictionary) -> String: return prop.name),
	)
	return array


func reload() -> void:
	if not is_instance_valid(main):
		return

	var config := main.config

	size = config.get_value_overlay(self, "size", size)
	anchors_preset = config.get_value_overlay(self, "anchors_preset", anchors_preset)
	_position_offset = config.get_value_overlay(self, "_position_offset", _position_offset)

	for prop_name in get_overlay_property_names():
		var prop_value: Variant = config.get_value_overlay(self, prop_name, get(prop_name))
		self.set(prop_name, prop_value)

	self._overlay_update()

	Log.ln("reloaded overlay from config: %s" % name)


## Called by [_ready()] after [Main] has been loaded.
func _overlay_init() -> void:
	self._overlay_update()


## Called when an export var changes or a preset has been loaded.
func _overlay_update() -> void:
	pass


func _draw() -> void:
	if _draw_bounds:
		draw_rect(Rect2(_position_offset, size), Color.WHITE, false)
