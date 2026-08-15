@tool
@abstract class_name MenuBase
extends UIBase

const ICON_LOAD := preload("res://assets/icon/icon_folder.png")
const ICON_WARNING := preload("res://assets/icon/StatusWarning.png")

@export var is_inner_menu: bool = false:
	set(value):
		is_inner_menu = value
		_generate_styleboxes()
		emit_ui_changed()

var main: Main

var _menu_stylebox: StyleBox


func _ready() -> void:
	self.main = await Main.get_instance()
	super()


## Setup any menu control nodes.
@abstract func _on_menu_init() -> void


func get_tab_title() -> String:
	return name


func menu_show() -> void:
	_on_changed()
	show()


func menu_hide() -> void:
	hide()


func _on_ready() -> void:
	_generate_styleboxes()
	if not Engine.is_editor_hint():
		Log.call_task(_on_menu_init, "init menu '%s'" % name)


func _on_changed() -> void:
	pass


func _generate_styleboxes() -> void:
	_watch_notifications = false

	remove_theme_stylebox_override("panel")
	if is_inner_menu:
		_menu_stylebox = get_theme_stylebox("panel_inner", "MenuBase").duplicate()
	else:
		_menu_stylebox = get_theme_stylebox("panel_normal", "MenuBase").duplicate()
	add_theme_stylebox_override("panel", _menu_stylebox)

	_watch_notifications = true
