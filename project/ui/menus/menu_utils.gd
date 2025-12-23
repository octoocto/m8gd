class_name MenuUtils extends Node

const SETTING_NUMBER := preload("res://ui/settings/setting_number.tscn")
const SETTING_VEC2I := preload("res://ui/settings/setting_vec2i.tscn")
const SETTING_BOOL := preload("res://ui/settings/setting_bool.tscn")
const SETTING_OPTIONS := preload("res://ui/settings/setting_options.tscn")
const SETTING_STRING := preload("res://ui/settings/setting_string.tscn")
const SETTING_COLOR := preload("res://ui/settings/setting_color.tscn")
const SETTING_FILE := preload("res://ui/settings/setting_file.tscn")

const UI_BUTTON := preload("res://ui/button.tscn")

const HEADER := preload("res://ui/header.tscn")


##
## Automatically create a Setting from a property dictionary (from [get_property_list()]).
##
static func create_setting_from_property(prop: Dictionary, accept_no_hints := true) -> SettingBase:
	var property: String = prop.name
	var hint: PropertyHint = prop.hint
	var type: PropertyHint = prop.type
	var hint_string: String = prop.hint_string
	var setting: SettingBase

	# print("creating setting: found prop %s, hint = %s, hint_string = %s" % [prop.name, prop.hint, prop.hint_string])
	match hint:
		PropertyHint.PROPERTY_HINT_NONE:  # prop only has a type
			if type != TYPE_BOOL and not accept_no_hints:
				return null

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
					setting.step = 0.01
				TYPE_STRING:
					setting = SETTING_STRING.instantiate()
				TYPE_COLOR:
					setting = SETTING_COLOR.instantiate()
				var x:
					assert(
						false,
						(
							"Unrecognized property type when populating menu: name=%s, hint=%s, hint_string=%s, %s"
							% [property, hint, x, prop]
						)
					)

		PropertyHint.PROPERTY_HINT_RANGE:  # prop using @export_range
			var split := hint_string.split(",")
			var s: SettingNumber = SETTING_NUMBER.instantiate()

			match type:
				TYPE_INT:
					s.min_value = split[0].to_float()
					s.max_value = split[1].to_float()
					s.step = 1.0
					s.show_ticks = true
					s.format_string = "%d"
				TYPE_FLOAT:
					s.min_value = split[0].to_float()
					s.max_value = split[1].to_float()
					if split.size() == 3:
						s.step = split[2].to_float()
					else:
						s.step = 0.01
					s.show_ticks = false
					s.format_string = "%.2f"

			setting = s

		PropertyHint.PROPERTY_HINT_ENUM:  # prop is an enum
			var s: SettingOptions = SETTING_OPTIONS.instantiate()
			for part in hint_string.split(","):
				s.items.append(part.split(":")[0])
			s.setting_type = 1

			setting = s

		PropertyHint.PROPERTY_HINT_COLOR_NO_ALPHA:
			var s: SettingColor = SETTING_COLOR.instantiate()
			s.edit_alpha = false

			setting = s

		var _x:
			return null
			# assert(
			# 	false,
			# 	(
			# 		"Unrecognized property hint when populating menu: name=%s, hint=%s, hint_string=%s, %s"
			# 		% [property, hint, x, prop]
			# 	)
			# )

	return setting


static func create_setting_options() -> SettingBase:
	return SETTING_OPTIONS.instantiate()


static func create_setting_file() -> SettingFile:
	return SETTING_FILE.instantiate()


static func create_header(text: String) -> Control:
	var label := HEADER.instantiate()
	label.text = text
	return label
