@tool
class_name OverlayConfigMenu
extends MenuFrameBase

@onready var s_position: SettingVec2i = %Setting_Position
@onready var s_anchor: SettingOptions = %Setting_Anchor
@onready var s_size: SettingVec2i = %Setting_Size

@onready var param_container: VBoxContainer = %ParamContainer

# @onready var button_finish: Button = %ButtonFinish

## The overlay element currently being edited.
var overlay_target: Control


func _disconnect_all(sig: Signal) -> void:
	for conn: Dictionary in sig.get_connections():
		sig.disconnect(conn.callable)


func _on_menu_init() -> void:
# 	button_finish.pressed.connect(
# 		func() -> void:
# 			menu_hide()
# 			main.menu.menu_show()
# 	)
	super()


func menu_show() -> void:
	assert(false, "cannot open menu without an overlay target")


func menu_hide() -> void:
	hide()
	if overlay_target:
		overlay_target._draw_bounds = false
		overlay_target = null


##
## Called when this menu is opened to edit the given overlay.
##
func menu_show_for(overlay: OverlayBase) -> void:
	assert(!visible, "tried to open menu when menu is already open")

	overlay_target = overlay
	overlay_target._draw_bounds = true
	title = "Overlay > %s" % overlay_target.name

	_init_params_for(overlay_target)

	super.menu_show()


##
## Automatically add an overlay's additional properties as UI controls to
## this menu.
## The list of properties to add is taken from [overlay.overlay_get_properties()].
##
func _init_params_for(overlay: OverlayBase) -> void:
	# these params are always present

	s_position.uninit()
	s_anchor.uninit()
	s_size.uninit()

	s_size.setting_connect_overlay(
		overlay, "size", func(_value: Vector2) -> void: s_anchor.emit_value_changed()
	)
	s_anchor.setting_connect_overlay(
		overlay, "anchors_preset", func(_value: int) -> void: s_position.value = Vector2i.ZERO
	)
	s_position.setting_connect_overlay(overlay, "position_offset")

	# load any additional params

	for child in param_container.get_children():
		param_container.remove_child(child)
		child.queue_free()

	var proplist: Array[Dictionary] = overlay.get_property_list().filter(
		func(prop: Dictionary) -> bool:
			return (
				prop.usage & PROPERTY_USAGE_STORAGE
				and prop.usage & PROPERTY_USAGE_EDITOR
				and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
				and not prop.name.begins_with("_")
			)
	)

	print("overlay properties: %s" % [proplist])

	for prop: Dictionary in proplist:
		var property: String = prop.name
		var setting := MenuUtils.create_setting_from_property(prop)

		setting.value = overlay.get(property)
		setting.setting_name = prop.name.capitalize()
		param_container.add_child(setting)
		setting.setting_connect_overlay(overlay, property)

	Log.ln(
		(
			"initialized %d overlay param(s) for: %s"
			% [param_container.get_child_count(), overlay.name]
		)
	)
