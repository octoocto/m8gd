@tool
extends MenuBase

func _menu_init() -> void:
	var config := main.config

	# custom font loading
	for tuple: Array in [
		["Font01Normal", 0, M8GD.M8_FONT_01_SMALL],
		["Font01Big", 1, M8GD.M8_FONT_01_BIG],
		["Font02Normal", 2, M8GD.M8_FONT_02_SMALL],
		["Font02Bold", 3, M8GD.M8_FONT_02_BOLD],
		["Font02Huge", 4, M8GD.M8_FONT_02_HUGE],
	]:
		var setting_options := get_node("%%%s/SettingOptions" % tuple[0])
		var setting_file := get_node("%%%s/SettingFile" % tuple[0])
		setting_options.setting_connect(tuple[1], func(value: int) -> void:
			match value:
				0:
					main.m8_set_font(tuple[2], main.FONT_01_SMALL)
					setting_file.value = ""
				1:
					main.m8_set_font(tuple[2], main.FONT_01_BIG)
					setting_file.value = ""
				2:
					main.m8_set_font(tuple[2], main.FONT_02_SMALL)
					setting_file.value = ""
				3:
					main.m8_set_font(tuple[2], main.FONT_02_BOLD)
					setting_file.value = ""
				4:
					main.m8_set_font(tuple[2], main.FONT_02_HUGE)
					setting_file.value = ""
		)
		setting_file.setting_connect("", func(value: String) -> void:
			if value:
				setting_options.value = 5
				main.m8_set_font_from_file(tuple[2], value)
		)

	%CheckButtonDebug.toggled.connect(func(toggled_on: bool) -> void:
		main.get_node("%DebugLabels").visible = toggled_on
		config.debug_info = toggled_on
	)
	%CheckButtonDebug.button_pressed = config.debug_info

	%ButtonM8Enable.pressed.connect(main.m8_send_enable_display)
	%ButtonM8Disable.pressed.connect(main.m8_send_disable_display)
	%ButtonM8Reset.pressed.connect(main.m8_send_reset_display)

	%SpinBoxM8Keys.value_changed.connect(func(value: float) -> void:
		%LabelM8KeysBinary.text = String.num_int64(int(value), 2).pad_zeros(8)
	)

	%ButtonM8Control.pressed.connect(func() -> void:
		var keys: int = %SpinBoxM8Keys.get_line_edit().text.to_int()
		main.m8_send_control(keys)
	)

	%ButtonM8KeyJazz.pressed.connect(func() -> void:
		var n: int = %SpinBoxM8Note.get_line_edit().text.to_int()
		var v: int = %SpinBoxM8Vel.get_line_edit().text.to_int()
		print("debug: sending keyjazz (n=%d, v=%d)" % [n, v])
		main.m8_send_keyjazz(n, v)
	)

	%SpinBoxM8ThemeDelay.value_changed.connect(func(value: float) -> void:
		%LabelM8ThemeDelayMS.text = "%.1fms" % (value / 60.0 * 1000.0)
	)

	var m8t_colors := [
		%ColorM8T0, %ColorM8T1, %ColorM8T2, %ColorM8T3,
		%ColorM8T4, %ColorM8T5, %ColorM8T6, %ColorM8T7,
		%ColorM8T8, %ColorM8T9, %ColorM8T10, %ColorM8T11,
		%ColorM8T12
	]

	%ButtonM8Theme.pressed.connect(func() -> void:
		print("debug: sending theme colors")
		var delay_frames: int = %SpinBoxM8ThemeDelay.get_line_edit().text.to_int()
		for i: int in range(m8t_colors.size()):
			main.m8_send_theme_color(i, m8t_colors[i].color)
			for j in range(delay_frames):
				await get_tree().physics_frame
	)
