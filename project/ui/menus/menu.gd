@tool
class_name MenuBase
extends PanelContainer

const THEME := preload("res://ui/theme/menu_theme.tres")

var main: Main

func _ready() -> void:
	if not Engine.is_editor_hint():
		await Events.initialized
	else:
		await get_tree().create_timer(0.1).timeout
	
	main = Main.instance

	custom_minimum_size = Vector2i(320, 240)
	anchors_preset = Control.PRESET_FULL_RECT
	set_theme(THEME)

	if not Engine.is_editor_hint():
		Log.call_task(_menu_init, "init menu '%s'" % name)

func get_tab_title() -> String:
	return name

func menu_show() -> void:
	show()

func menu_hide() -> void:
	hide()

## Setup any menu control nodes.
func _menu_init() -> void:
	assert(false, "_menu_init() not implemented in %s" % name)
