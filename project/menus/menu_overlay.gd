extends PanelContainer

var main: Main

## The overlay element currently being edited.
var overlay_target: Control


# disconnect all connections to this signal
func _disconnect_all(sig: Signal) -> void:
	for conn: Dictionary in sig.get_connections():
		sig.disconnect(conn.callable)

##
## Called once on initial app startup.
##
func init(p_main: Main) -> void:
	main = p_main

	%ButtonFinish.pressed.connect(func() -> void:
		menu_hide()
		main.menu.visible = true
	)

##
## Called when this menu is opened to edit the given overlay.
##
func menu_open(overlay: OverlayBase) -> void:

	assert(!visible, "tried to open menu when menu is already open")
	visible = true

	overlay_target = overlay
	overlay_target.draw_bounds = true

	init_settings(overlay_target)
	_populate_overlay_properties()

func init_settings(overlay: OverlayBase) -> void:

	%Setting_Position.uninit()
	%Setting_Anchor.uninit()
	%Setting_Size.uninit()

	%Setting_Size.setting_connect_overlay(overlay, "size", func(_value: Vector2) -> void:
		%Setting_Anchor.emit_changed()
	)
	%Setting_Anchor.setting_connect_overlay(overlay, "anchors_preset", func(_value: int) -> void:
		%Setting_Position.value = Vector2i.ZERO
	)
	%Setting_Position.setting_connect_overlay(overlay, "position_offset")

##
## Called when this menu is closed
##
func menu_hide() -> void:

	visible = false

	if overlay_target:
		overlay_target.draw_bounds = false
		overlay_target = null

##
## Automatically add an overlay's additional properties as UI controls to
## this menu.
## The list of properties to add is taken from [overlay.overlay_get_properties()].
##
func _populate_overlay_properties() -> void:
	# depopulate property container
	for child in %ParamContainer.get_children():
		%ParamContainer.remove_child(child)
		child.queue_free()

	var props: Array[String] = overlay_target.overlay_get_properties()
	var propinfo: Array[Dictionary] = overlay_target.get_property_list()

	for prop in propinfo:
		if prop.name not in props: continue

		var property: String = prop.name
		var setting := MenuUtils.create_setting_from_property(prop)

		setting.value = overlay_target.get(property)
		setting.setting_name = prop.name.capitalize()
		%ParamContainer.add_child(setting)
		setting.setting_connect_overlay(overlay_target, property)