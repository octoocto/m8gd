class_name MenuUtils extends Node

const SETTING_NUMBER := preload("res://ui/setting_number.tscn")
const SETTING_VEC2I := preload("res://ui/setting_vec2i.tscn")
const SETTING_BOOL := preload("res://ui/setting_bool.tscn")
const SETTING_OPTIONS := preload("res://ui/setting_options.tscn")
const SETTING_COLOR := preload("res://ui/setting_color.tscn")
const SETTING_FILE := preload("res://ui/setting_file.tscn")

const LABEL_HEADER := preload("res://ui/label_header.tscn")


##
## Automatically create a Setting from a property dictionary (from [get_property_list()]).
##
static func create_setting_from_property(prop: Dictionary) -> SettingBase:
	var property: String = prop.name
	var hint: PropertyHint = prop.hint
	var type: PropertyHint = prop.type
	var hint_string: String = prop.hint_string
	var setting: Node = null

	print("creating setting: found prop %s, hint = %s, hint_string = %s" % [prop.name, prop.hint, prop.hint_string])

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
					setting.step = 0.01
				TYPE_COLOR:
					setting = SETTING_COLOR.instantiate()
				var x:
					assert(false, "Unrecognized property type when populating menu: name=%s, hint=%s, hint_string=%s, %s" % [property, hint, x, prop])

		PropertyHint.PROPERTY_HINT_RANGE: # prop using @export_range
			var split := hint_string.split(",")
			setting = SETTING_NUMBER.instantiate()
			setting.min_value = split[0].to_float()
			setting.max_value = split[1].to_float()
			if split.size() == 3: setting.step = split[2].to_float()
			if is_equal_approx(setting.step, 1): setting.format_string = "%d"

		PropertyHint.PROPERTY_HINT_ENUM: # prop is an enum
			setting = SETTING_OPTIONS.instantiate()
			for s in hint_string.split(","):
				setting.items.append(s.split(":")[0])
			setting.setting_type = 1
		
		var x:
			assert(false, "Unrecognized property hint when populating menu: name=%s, hint=%s, hint_string=%s, %s" % [property, hint, x, prop])

	return setting

static func create_setting_options() -> SettingBase:
	return SETTING_OPTIONS.instantiate()

static func create_setting_file() -> SettingFile:
	return SETTING_FILE.instantiate()

static func create_header(text: String) -> Control:
	var label := LABEL_HEADER.instantiate()
	label.text = text
	return label
