@abstract class_name UIBase
extends PanelContainer

const THEME := preload("res://ui/theme/menu_theme.tres")
const PALETTE := preload("res://ui/theme/palette.tres")

const LEFT_WIDTH := 160

@export var enabled := true:
	set(value):
		enabled = value
		emit_ui_changed()

@export_multiline var hint_text: String = ""

var _watch_notifications := true

var _is_mouse_inside := false


func _ready() -> void:
	theme = THEME
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme_type_variation = ""

	reset_size()

	if not Engine.is_editor_hint():
		mouse_entered.connect(Events.gui_mouse_entered.emit.bind(self))
		mouse_exited.connect(Events.gui_mouse_exited.emit.bind(self))

	_watch_notifications = false
	_on_ready()
	emit_ui_changed()
	_watch_notifications = true


func _notification(what: int) -> void:
	if not _watch_notifications:
		return

	if is_node_ready() and what == NOTIFICATION_THEME_CHANGED:
		_watch_notifications = false
		_on_theme_changed()
		emit_ui_changed()
		_watch_notifications = true


func _on_theme_changed() -> void:
	pass


func _on_ready() -> void:
	pass


@abstract func _on_changed() -> void


func emit_ui_changed() -> void:
	if not is_inside_tree():
		return
	_on_changed()


func show_if(setting: SettingBase, cond_fn: Callable = Callable()) -> void:
	var callback := func(value: Variant) -> void:
		if cond_fn.is_valid():
			visible = cond_fn.call(value)
		else:
			visible = value as bool

	setting.value_changed.connect(callback)
	callback.call(setting.get_value())


func enable_if(setting: SettingBase, cond_fn: Callable = Callable()) -> void:
	var callback := func(value: Variant) -> void:
		if cond_fn.is_valid():
			enabled = cond_fn.call(value)
		else:
			enabled = value as bool

	setting.value_changed.connect(callback)
	callback.call(setting.get_value())


func _format_text(text: String) -> String:
	match get_theme_constant("text_case", "UIBase"):
		1:
			return text.to_upper()
		2:
			return text.to_lower()
		_:
			return text


## Connects mouse entered and exited signals.
func _connect_mouse_events(control: Control = self) -> void:
	control.mouse_entered.connect(
		func() -> void:
			_is_mouse_inside = true
			emit_ui_changed()
	)
	control.mouse_exited.connect(
		func() -> void:
			_is_mouse_inside = false
			emit_ui_changed()
	)


func is_mouse_inside(control: Control = self) -> bool:
	if control == self:
		return (
			Rect2i(Vector2i.ZERO, control.size).has_point(control.get_local_mouse_position())
			and _is_mouse_inside
		)
	else:
		return Rect2i(Vector2i.ZERO, control.size).has_point(control.get_local_mouse_position())


func _pal_index(index: int) -> Color:
	if index >= PALETTE.colors.size():
		return Color.TRANSPARENT
	return PALETTE.colors[index]


func _pal(constant_name: String, theme_type: StringName = "ThemePalette") -> Color:
	var index := get_theme_constant(constant_name, theme_type)
	return _pal_index(index)


func _pal_or(constant_name: String, color_override: Variant) -> Color:
	if color_override is int and color_override >= 0:
		return _pal_index(color_override as int)
	elif color_override is Color:
		return color_override

	return _pal(constant_name)


func _make_stylebox_unique(stylebox_name: StringName, control: Control = self) -> StyleBox:
	control.remove_theme_stylebox_override(stylebox_name)
	var stylebox: StyleBox = control.get_theme_stylebox(stylebox_name).duplicate()
	control.add_theme_stylebox_override(stylebox_name, stylebox)
	return stylebox
