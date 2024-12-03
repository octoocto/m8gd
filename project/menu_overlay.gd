extends PanelContainer

var main: M8SceneDisplay

## The overlay element currently being edited.
var overlay_target: Control


# disconnect all connections to this signal
func _disconnect_all(sig: Signal) -> void:
	for conn: Dictionary in sig.get_connections():
		sig.disconnect(conn.callable)

##
## Called once on initial app startup.
##
func init(p_main: M8SceneDisplay) -> void:
	main = p_main

	%Option_Anchor.add_item("Top Left", 0)
	%Option_Anchor.set_item_metadata(0, Control.PRESET_TOP_LEFT)
	%Option_Anchor.add_item("Top Right", 1)
	%Option_Anchor.set_item_metadata(1, Control.PRESET_TOP_RIGHT)
	%Option_Anchor.add_item("Bottom Left", 2)
	%Option_Anchor.set_item_metadata(2, Control.PRESET_BOTTOM_LEFT)
	%Option_Anchor.add_item("Bottom Right", 3)
	%Option_Anchor.set_item_metadata(3, Control.PRESET_BOTTOM_RIGHT)
	%Option_Anchor.add_item("Center", 4)
	%Option_Anchor.set_item_metadata(4, Control.PRESET_CENTER)
	%Option_Anchor.add_item("Left Wide", 5)
	%Option_Anchor.set_item_metadata(5, Control.PRESET_LEFT_WIDE)
	%Option_Anchor.add_item("Right Wide", 6)
	%Option_Anchor.set_item_metadata(6, Control.PRESET_RIGHT_WIDE)

	%ButtonFinish.pressed.connect(func() -> void:
		menu_close()
		main.menu.visible = true
	)

##
## Called when this menu is opened to edit the given overlay.
##
func menu_open(overlay: Control) -> void:

	assert(!visible, "tried to open menu when menu is already open")
	visible = true

	overlay_target = overlay
	overlay_target.draw_bounds = true

	update_menu()


##
## Called when this menu is closed
##
func menu_close() -> void:

	visible = false

	if overlay_target:
		overlay_target.draw_bounds = false
		overlay_target = null

##
## Update the current target overlay and the config from this menu.
##
func _update_overlay() -> void:

	if overlay_target:
		overlay_target.position_offset = Vector2(%Spin_PosX.value, %Spin_PosY.value)
		overlay_target.size = Vector2(%Spin_SizeW.value, %Spin_SizeH.value)

		main.save_overlay(overlay_target)

##
## Update this menu with the current target overlay and its properties.
##
func update_menu() -> void:

	assert(overlay_target)

	%LabelTarget.text = "Editing: %s" % overlay_target.name

	_populate_overlay_properties()

	_disconnect_all(%Spin_PosX.value_changed)
	_disconnect_all(%Spin_PosY.value_changed)
	_disconnect_all(%Spin_SizeW.value_changed)
	_disconnect_all(%Spin_SizeH.value_changed)
	_disconnect_all(%Option_Anchor.item_selected)

	%Spin_PosX.value = overlay_target.position_offset.x
	%Spin_PosY.value = overlay_target.position_offset.y
	%Spin_SizeW.value = overlay_target.size.x
	%Spin_SizeH.value = overlay_target.size.y

	var callback := func(_value: float) -> void:
		_update_overlay()

	%Spin_PosX.value_changed.connect(callback)
	%Spin_PosY.value_changed.connect(callback)
	%Spin_SizeW.value_changed.connect(callback)
	%Spin_SizeH.value_changed.connect(callback)

	match overlay_target.anchors_preset:
		Control.PRESET_TOP_LEFT:
			%Option_Anchor.selected = 0
		Control.PRESET_TOP_RIGHT:
			%Option_Anchor.selected = 1
		Control.PRESET_BOTTOM_LEFT:
			%Option_Anchor.selected = 2
		Control.PRESET_BOTTOM_RIGHT:
			%Option_Anchor.selected = 3
		Control.PRESET_CENTER:
			%Option_Anchor.selected = 4
		Control.PRESET_LEFT_WIDE:
			%Option_Anchor.selected = 5
		Control.PRESET_RIGHT_WIDE:
			%Option_Anchor.selected = 6
		_:
			assert(false, "Unrecognized anchor selected")

	%Option_Anchor.item_selected.connect(func(_idx: int) -> void:
		overlay_target.anchors_preset = %Option_Anchor.get_selected_metadata()
		_update_overlay()
	)

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
		if prop.name in props:
			print("overlay menu: found prop %s, hint = %s, hint_string = %s" % [prop.name, prop.hint, prop.hint_string])
			var propname: String = prop.name
			var propkey := main._get_propkey_overlay(overlay_target, propname)
			var value: Variant = overlay_target.get(propname)
			var hint: PropertyHint = prop.hint
			var type: PropertyHint = prop.type
			var hint_string: String = prop.hint_string

			match hint:
				PropertyHint.PROPERTY_HINT_NONE: # prop only has a type
					match type:
						TYPE_VECTOR2I:
							var node := MenuUtils.create_vec2i_prop(propkey, propname, value, func(v: Vector2i) -> void:
								overlay_target.set(propname, v)
							)
							%ParamContainer.add_child(node)
						TYPE_BOOL:
							var node := MenuUtils.create_bool_prop(propkey, propname, value, func(v: bool) -> void:
								overlay_target.set(propname, v)
							)
							%ParamContainer.add_child(node)
						TYPE_INT:
							var node := MenuUtils.create_spinbox_prop(propkey, propname, value, 1.0, "", func(v: float) -> void:
								overlay_target.set(propname, v)
							)
							%ParamContainer.add_child(node)
						TYPE_FLOAT:
							var node := MenuUtils.create_spinbox_prop(propkey, propname, value, 0.1, "", func(v: float) -> void:
								overlay_target.set(propname, v)
							)
							%ParamContainer.add_child(node)
						var x:
							assert(false, "Unrecognized property type when populating menu: name=%s, hint=%s, hint_string=%s, %s" % [propname, hint, x, prop])
				PropertyHint.PROPERTY_HINT_RANGE: # prop using @export_range
					var split := hint_string.split(",")
					var mn := int(split[0])
					var mx := int(split[1])
					var step := 1.0 if split.size() < 3 else float(split[2])
					var node := MenuUtils.create_slider_prop(propkey, propname, value, "%f", mn, mx, step, func(v: float) -> void:
						overlay_target.set(propname, v)
					)
					%ParamContainer.add_child(node)
				PropertyHint.PROPERTY_HINT_ENUM: # prop is an enum
					var items: Array[String] = []
					for s in hint_string.split(","):
						items.append(s.split(":")[0])
					var node := MenuUtils.create_option_prop(propkey, propname, int(value), items, func(v: int) -> void:
						overlay_target.set(propname, v)
					)
					%ParamContainer.add_child(node)