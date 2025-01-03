extends PanelContainer

const SETTING_NUMBER := preload("res://ui/setting_number.tscn")
const SETTING_VEC2I := preload("res://ui/setting_vec2i.tscn")
const SETTING_BOOL := preload("res://ui/setting_bool.tscn")
const SETTING_OPTIONS := preload("res://ui/setting_options.tscn")

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

	init_settings(overlay_target)

func init_settings(overlay: Control) -> void:

	%Setting_Position.uninit()
	%Setting_Anchor.uninit()
	%Setting_Size.uninit()

	%Setting_Position.init_config_overlay(main, overlay, "position_offset")
	%Setting_Anchor.init_config_overlay(main, overlay, "anchors_preset", func(_value: int) -> void:
		%Setting_Position.value = Vector2i.ZERO
	)
	%Setting_Size.init_config_overlay(main, overlay, "size", func(_value: Vector2) -> void:
		%Setting_Anchor._emit_value_changed()
	)

##
## Called when this menu is closed
##
func menu_close() -> void:

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
		if prop.name in props:
			print("overlay menu: found prop %s, hint = %s, hint_string = %s" % [prop.name, prop.hint, prop.hint_string])
			var property: String = prop.name
			var value: Variant = overlay_target.get(property)
			var hint: PropertyHint = prop.hint
			var type: PropertyHint = prop.type
			var hint_string: String = prop.hint_string
			var setting: Node = null

			match hint:
				PropertyHint.PROPERTY_HINT_NONE: # prop only has a type
					match type:
						TYPE_VECTOR2I:
							setting = SETTING_VEC2I.instantiate()
							setting.min_value = Vector2i(-3000, -3000)
							setting.max_value = Vector2i(3000, 3000)
						TYPE_BOOL:
							setting = SETTING_BOOL.instantiate()
						TYPE_INT:
							setting = SETTING_NUMBER.instantiate()
							setting.format_string = "%d"
						TYPE_FLOAT:
							setting = SETTING_NUMBER.instantiate()
							setting.value = value
							setting.step = 0.01
						var x:
							assert(false, "Unrecognized property type when populating menu: name=%s, hint=%s, hint_string=%s, %s" % [property, hint, x, prop])

				PropertyHint.PROPERTY_HINT_RANGE: # prop using @export_range
					var split := hint_string.split(",")
					setting = SETTING_NUMBER.instantiate()
					setting.min_value = split[0].to_float()
					setting.max_value = split[1].to_float()
					setting.step = split[2].to_float()
					if is_equal_approx(setting.step, 1): setting.format_string = "%d"

				PropertyHint.PROPERTY_HINT_ENUM: # prop is an enum
					setting = SETTING_OPTIONS.instantiate()
					for s in hint_string.split(","):
						setting.items.append(s.split(":")[0])
					setting.setting_type = 1

			if setting:
				setting.value = value
				setting.setting_name = property.capitalize()
				%ParamContainer.add_child(setting)
				setting.init_config_overlay(main, overlay_target, property)