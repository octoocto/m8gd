@tool
extends MenuBase

@onready var s_highlights: Array = [
	# [<setting>, <config property>, <overlay property>, <key name>]
	[%SHighDir, "hl_color_directional"],
	[%SHighOption, "hl_color_option", "Option"],
	[%SHighEdit, "hl_color_edit", "Edit"],
	[%SHighShift, "hl_color_shift", "Shift"],
	[%SHighPlay, "hl_color_play", "Play"],
]

@onready var s_keycaps: Array = [
	# [<setting>, <config property>, <key name>]
	[%SKeyUp, "model_color_key_up", "Up"],
	[%SKeyDown, "model_color_key_down", "Down"],
	[%SKeyLeft, "model_color_key_left", "Left"],
	[%SKeyRight, "model_color_key_right", "Right"],
	[%SKeyOption, "model_color_key_option", "Option"],
	[%SKeyEdit, "model_color_key_edit", "Edit"],
	[%SKeyShift, "model_color_key_shift", "Shift"],
	[%SKeyPlay, "model_color_key_play", "Play"],
]

@onready var s_body: Array = [[%SBodyFront, "model_color_body", "Body"]]

@onready var all_settings: Array = _collect_settings()


func _on_menu_init() -> void:
	for arr: Array in s_keycaps:
		var setting: SettingColor = arr[0]
		var conf_property: String = arr[1]
		var key_name: String = arr[2]

		setting.setting_connect_colors(
			conf_property, func(value: Color) -> void: _model_set_keycap_color(key_name, value)
		)

	for arr: Array in s_highlights:
		var setting: SettingColor = arr[0]
		var conf_property: String = arr[1]

		if arr.size() == 2:  # directional color
			setting.setting_connect_colors(
				conf_property, func(value: Color) -> void: _model_set_dir_key_highlight_color(value)
			)
			continue

		var key_name: String = arr[2]

		setting.setting_connect_colors(
			conf_property,
			func(value: Color) -> void: _model_set_key_highlight_color(key_name, value)
		)

	for arr: Array in s_body:
		var setting: SettingColor = arr[0]
		var conf_property: String = arr[1]
		var part_name: String = arr[2]

		setting.setting_connect_colors(
			conf_property, func(value: Color) -> void: _model_set_part_color(part_name, value)
		)

	for setting: SettingColor in all_settings:
		setting.get_color_picker().preset_added.connect(
			func(color: Color) -> void:
				for s: SettingColor in all_settings:
					s.get_color_picker().add_preset(color)
		)
		setting.get_color_picker().preset_removed.connect(
			func(color: Color) -> void:
				for s: SettingColor in all_settings:
					s.get_color_picker().erase_preset(color)
		)

	Events.preset_loaded.connect(
		func(_profile_name: String) -> void:
			for setting: SettingColor in all_settings:
				setting.reload()
	)

	Events.scene_loaded.connect(
		func(_scene_path: String, scene: M8Scene) -> void:
			var is_3d_scene := scene.has_3d_camera()
			for arr: Array in s_keycaps:
				arr[0].enabled = is_3d_scene
			for arr: Array in s_body:
				arr[0].enabled = is_3d_scene
	)


func _collect_settings() -> Array:
	var list: Array
	for arr: Array in s_keycaps:
		list.append(arr[0])
	for arr: Array in s_highlights:
		list.append(arr[0])
	for arr: Array in s_body:
		list.append(arr[0])
	return list


func _model_set_part_color(part_name: String, color: Color) -> void:
	var model := main.get_scene_m8_model()
	if model == null:
		return

	model.set_part_color(part_name, color)


func _model_set_key_highlight_color(key_name: String, color: Color) -> void:
	var model := main.get_scene_m8_model()
	if model == null:
		return

	model.set_key_highlight_color(key_name, color)


func _model_set_dir_key_highlight_color(color: Color) -> void:
	var model := main.get_scene_m8_model()
	if model == null:
		return

	model.set_dir_key_highlight_color(color)


func _model_set_keycap_color(node_path: String, color: Color) -> void:
	var model := main.get_scene_m8_model()
	if model == null:
		return

	model.set_key_cap_color(node_path, color)
