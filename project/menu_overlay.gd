extends PanelContainer

var main: M8SceneDisplay

## The overlay element currently being edited.
var overlay_target: Control

func _setprop(propname: String, value: Variant) -> void:
	assert(overlay_target != null)
	var propkey := _get_prop_key(overlay_target, propname)
	MenuUtils._profile_set(propkey, value)

func _getprop(propname: String, default: Variant = null) -> Variant:
	assert(overlay_target != null)
	var propkey := _get_prop_key(overlay_target, propname)
	return MenuUtils._profile_get(propkey, default)

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

## Set properties of the given overlay according to the saved config/profile.
## (Does not set the target overlay of this menu)
func init_overlay(overlay: Control) -> void:

	overlay.anchors_preset = MenuUtils._profile_get(_get_prop_key(overlay, "anchors_preset"), overlay.anchors_preset)
	overlay.position_offset = MenuUtils._profile_get(_get_prop_key(overlay, "position_offset"), overlay.position_offset)
	overlay.size = MenuUtils._profile_get(_get_prop_key(overlay, "size"), overlay.size)

	for propname: String in overlay.overlay_get_properties():
		var propkey := _get_prop_key(overlay, propname)
		overlay.set(propname, MenuUtils._profile_get(propkey, overlay.get(propname)))


func menu_open(overlay: Control) -> void:
	assert(!visible, "tried to open menu when menu is already open")
	visible = true

	overlay_target = overlay
	overlay_target.draw_bounds = true

	_populate_overlay_properties()

	%LabelTarget.text = "Editing: %s" % overlay_target.name

	_disconnect_all(%Spin_PosX.value_changed)
	_disconnect_all(%Spin_PosY.value_changed)
	_disconnect_all(%Spin_SizeW.value_changed)
	_disconnect_all(%Spin_SizeH.value_changed)
	_disconnect_all(%Option_Anchor.item_selected)

	%Spin_PosX.value = overlay_target.position_offset.x
	%Spin_PosY.value = overlay_target.position_offset.y
	%Spin_SizeW.value = overlay_target.size.x
	%Spin_SizeH.value = overlay_target.size.y

	%Spin_PosX.value_changed.connect(func(_value: float) -> void:
		update_overlay()
	)
	%Spin_PosY.value_changed.connect(func(_value: float) -> void:
		update_overlay()
	)
	%Spin_SizeW.value_changed.connect(func(_value: float) -> void:
		update_overlay()
	)
	%Spin_SizeH.value_changed.connect(func(_value: float) -> void:
		update_overlay()
	)

	overlay_target.anchors_preset = _getprop("anchors_preset", overlay_target.anchors_preset)

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
		_setprop("anchors_preset", overlay_target.anchors_preset)
	)

func menu_close() -> void:
	visible = false
	if overlay_target:
		overlay_target.draw_bounds = false
		overlay_target = null

# disconnect all connections to this signal
func _disconnect_all(sig: Signal) -> void:
	for conn: Dictionary in sig.get_connections():
		sig.disconnect(conn.callable)

func update_overlay() -> void:
	if overlay_target:
		overlay_target.position_offset = Vector2(%Spin_PosX.value, %Spin_PosY.value)
		overlay_target.size = Vector2(%Spin_SizeW.value, %Spin_SizeH.value)

		_setprop("position_offset", overlay_target.position_offset)
		_setprop("size", overlay_target.size)

func _get_prop_key(overlay: Control, propname: String) -> String:
	return "overlay.%s.%s" % [overlay.name, propname]

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
			var propkey := _get_prop_key(overlay_target, propname)
			var value: Variant = overlay_target.get(propname)
			var hint: PropertyHint = prop.hint
			var hint_string: String = prop.hint_string

			match hint:
				PropertyHint.PROPERTY_HINT_NONE: # prop only has a type
					match hint_string:
						"Vector2i":
							var node := MenuUtils.create_vec2i(propkey, propname, value, func(v: Vector2i) -> void:
								overlay_target.set(propname, v)
							)
							%ParamContainer.add_child(node)
						"bool":
							var node := MenuUtils.create_check(propkey, propname, value, func(v: bool) -> void:
								overlay_target.set(propname, v)
							)
							%ParamContainer.add_child(node)
						"int":
							var node := MenuUtils.create_spinbox(propkey, propname, "", value, 1.0, func(v: float) -> void:
								overlay_target.set(propname, v)
							)
							%ParamContainer.add_child(node)
						"float":
							var node := MenuUtils.create_spinbox(propkey, propname, "", value, 0.1, func(v: float) -> void:
								overlay_target.set(propname, v)
							)
							%ParamContainer.add_child(node)
						var x:
							assert(false, "Unrecognized property type when populating menu: %s" % x)
				PropertyHint.PROPERTY_HINT_RANGE: # prop using @export_range
					var split := hint_string.split(",")
					var mn := int(split[0])
					var mx := int(split[1])
					var step := 1.0 if split.size() < 3 else float(split[2])
					var node := MenuUtils.create_slider(propkey, propname, "%f", value, mn, mx, step, func(v: float) -> void:
						overlay_target.set(propname, v)
					)
					%ParamContainer.add_child(node)
				PropertyHint.PROPERTY_HINT_ENUM: # prop is an enum
					var items := []
					for s in hint_string.split(","):
						items.append(s.split(":")[0])
					var node := MenuUtils.create_option(propkey, propname, int(value), items, func(v: int) -> void:
						overlay_target.set(propname, v)
					)
					%ParamContainer.add_child(node)