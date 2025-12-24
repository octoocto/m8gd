@tool
extends MenuBase

@onready var vbox: VBoxContainer = %VBoxContainer


func _on_menu_init() -> void:
	for shader_rect: ShaderRect in main.shaders.get_shader_rects():
		var s_enable := _create_enable_setting(shader_rect)
		_create_parameter_settings(shader_rect, s_enable)
		vbox.add_child(HSeparator.new())

	Events.preset_loaded.connect(
		func(_profile_name: String) -> void:
			for c in vbox.get_children():
				if c is SettingBase and c.is_initialized:
					c.reload()
	)


func _create_enable_setting(shader_rect: ShaderRect) -> SettingBool:
	var s: SettingBool = MenuUtils.SETTING_BOOL.instantiate()
	vbox.add_child(s)

	var key: String = ("enable_%s" % shader_rect.name).to_snake_case()
	s.setting_name = "Enable %s" % shader_rect.name.capitalize()
	s.setting_connect_shader_global(key, func(value: bool) -> void: shader_rect.visible = value)
	print("connected setting to key: %s" % key)
	return s


func _create_parameter_settings(shader_rect: ShaderRect, s_enable: SettingBool) -> void:
	for d: Dictionary in shader_rect.get_uniform_list():
		if d.name.begins_with("_"):
			continue
		var s := MenuUtils.create_setting_from_property(d, false)
		if s != null:
			vbox.add_child(s)
			s.setting_name = " %s" % d.name.capitalize()
			s.conf_shader_parameter(shader_rect, d.name)
			s.show_if(s_enable)
