class_name MainMenu extends Panel

const PATH_SCENES := "res://scenes/"

const REBIND_COOLDOWN := 100 # ms until can rebind again

@onready var button_exit: Button = %ButtonExit

@onready var slider_volume: HSlider = %SliderVolume

# the order of paths in scene_paths[] correspond to the items in option_scenes
@onready var option_scenes: OptionButton = %OptionScenes
@onready var scene_paths := []

@onready var main: M8SceneDisplay

var is_key_rebinding := false
var last_rebind_time := 0.0
var key_rebind_callback: Callable

func init(p_main: M8SceneDisplay) -> void:

	main = p_main
	var config := main.config

	# scan scenes folder
	var dir_scenes: DirAccess = DirAccess.open(PATH_SCENES)

	dir_scenes.list_dir_begin()
	var path := dir_scenes.get_next()
	while path != "":
		if path.trim_suffix(".remap").get_extension() == "tscn":
			option_scenes.add_item(path.get_file().get_basename())
			scene_paths.append(dir_scenes.get_current_dir().path_join(path))
		path = dir_scenes.get_next()

	option_scenes.item_selected.connect(func(index: int) -> void:
		if index != - 1:
			main.load_scene(scene_paths[index])
	)
	option_scenes.selected = -1

	button_exit.pressed.connect(func() -> void:
		main.quit()
	)

	%ButtonClose.pressed.connect(func() -> void:
		visible=false
	)

	%DisplayRect.texture = main.m8_client.get_display_texture()

	#==========================================================================
	# OPTIONS
	#==========================================================================

	# Scene settings
	#--------------------------------------------------------------------------

	%ButtonResetSceneVars.pressed.connect(func() -> void:
		main.current_scene.config_delete_profile(main.current_scene.DEFAULT_PROFILE)
		main.reload_scene()
	)

	# Audio Tab
	#--------------------------------------------------------------------------

	# volume

	slider_volume.value_changed.connect(func(value: float) -> void:
		var volume_db: float=linear_to_db(pow(value, 2))
		print("volume = %f" % volume_db)
		main.audio_set_volume(volume_db)
		%LabelVolume.text="%d%% (%05.2f dB)" % [round(slider_volume.value / slider_volume.max_value * 100), volume_db]
		config.volume=value
	)
	slider_volume.value = config.volume
	slider_volume.value_changed.emit(config.volume)

	# audio driver (readonly)

	%LineEditAudioDriver.placeholder_text = ProjectSettings.get_setting("audio/driver/driver")

	# audio mix rate (readonly)

	%LineEditAudioRate.placeholder_text = "%d Hz" % AudioServer.get_mix_rate()
	# %LineEditAudioRate.text_submitted.connect(func(text):
	# 	if text.is_valid_int():
	# 		ProjectSettings.set_setting("audio/driver/mix_rate", int(text))
	# 	%LineEditAudioRate.text=""
	# 	%LineEditAudioRate.placeholder_text="%d Hz" % AudioServer.get_mix_rate()
	# )

	# audio latency (readonly)

	var audio_latency_update_timer := Timer.new()
	add_child(audio_latency_update_timer)
	audio_latency_update_timer.start(1.0)
	audio_latency_update_timer.timeout.connect(func() -> void:
		if visible:
			%LineEditAudioLatency.placeholder_text="%f ms" % AudioServer.get_output_latency()
	)

	%CheckButtonEnableSA.toggled.connect(func(toggled_on: bool) -> void:
		main.audio_set_spectrum_analyzer_enabled(toggled_on)
		config.audio_analyzer_enabled=toggled_on
	)
	%CheckButtonEnableSA.button_pressed = config.audio_analyzer_enabled

	%SpinBoxAVMinFreq.value_changed.connect(func(value: int) -> void:
		main.visualizer_frequency_min=value
		config.audio_analyzer_min_freq=value
	)
	%SpinBoxAVMinFreq.value = config.audio_analyzer_min_freq

	%SpinBoxAVMaxFreq.value_changed.connect(func(value: int) -> void:
		main.visualizer_frequency_max=value
		config.audio_analyzer_max_freq=value
	)
	%SpinBoxAVMaxFreq.value = config.audio_analyzer_max_freq

	%SliderAVBrightness.value_changed.connect(func(value: float) -> void:
		main.visualizer_brightness_amount=value
		%LabelAVBrightness.text="%d%%" % (value * 100.0)
		config.audio_to_brightness=value
	)
	%SliderAVBrightness.value = config.audio_to_brightness

	%SliderAVCA.value_changed.connect(func(value: float) -> void:
		main.visualizer_ca_amount=value
		%LabelAVCA.text="%d%%" % (value * 1000.0)
		config.audio_to_ca=value
	)
	%SliderAVCA.value = config.audio_to_ca

	# Video Tab
	#--------------------------------------------------------------------------

	# video

	%CheckButtonFullscreen.toggled.connect(func(toggled_on: bool) -> void:
		if toggled_on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		config.fullscreen=toggled_on
	)
	%CheckButtonFullscreen.button_pressed = config.fullscreen

	%CheckButtonVsync.toggled.connect(func(toggled_on: bool) -> void:
		if toggled_on:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		config.vsync=toggled_on
	)
	%CheckButtonVsync.button_pressed = config.vsync

	# Window resolution
	# ------------------------------------------------------------------------

	%OptionRes.select(0)

	get_tree().physics_frame.connect(func() -> void:
		var wsize:=DisplayServer.window_get_size()
		%OptionRes.set_item_text(0, "%dx%d" % [wsize.x, wsize.y])
	)

	%OptionRes.item_selected.connect(func(index: int) -> void:
		match index:
			2: DisplayServer.window_set_size(Vector2i(640, 480))
			3: DisplayServer.window_set_size(Vector2i(960, 720))
			4: DisplayServer.window_set_size(Vector2i(1280, 960))
			6: DisplayServer.window_set_size(Vector2i(960, 640))
			7: DisplayServer.window_set_size(Vector2i(1440, 960))
			8: DisplayServer.window_set_size(Vector2i(1920, 1280))
		%OptionRes.select(0)
	)

	%SliderFPSCap.value_changed.connect(func(value: float) -> void:
		if value > 0 and value < 15: value=15
		Engine.max_fps=int(value)
		config.fps_cap=int(value)
	)
	%SliderFPSCap.value = config.fps_cap

	# graphics

	%SliderDOFShape.value_changed.connect(func(value: RenderingServer.DOFBokehShape) -> void:
		RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(value)
		match value:
			RenderingServer.DOF_BOKEH_BOX:
				%LabelDOFShape.text="Box"
			RenderingServer.DOF_BOKEH_HEXAGON:
				%LabelDOFShape.text="Hexagon"
			RenderingServer.DOF_BOKEH_CIRCLE:
				%LabelDOFShape.text="Circle"
		config.dof_bokeh_shape=value
	)
	%SliderDOFShape.value = config.dof_bokeh_shape

	%SliderDOFQuality.value_changed.connect(func(value: RenderingServer.DOFBlurQuality) -> void:
		RenderingServer.camera_attributes_set_dof_blur_quality(value, true)
		match value:
			RenderingServer.DOF_BLUR_QUALITY_VERY_LOW:
				%LabelDOFQuality.text="Very Low"
			RenderingServer.DOF_BLUR_QUALITY_LOW:
				%LabelDOFQuality.text="Low"
			RenderingServer.DOF_BLUR_QUALITY_MEDIUM:
				%LabelDOFQuality.text="Medium"
			RenderingServer.DOF_BLUR_QUALITY_HIGH:
				%LabelDOFQuality.text="High"
		config.dof_blur_quality=value
	)
	%SliderDOFQuality.value = config.dof_blur_quality

	# MSAA

	%SliderMSAA.value_changed.connect(func(value: int) -> void:
		match value:
			0:
				get_viewport().msaa_3d=Viewport.MSAA_DISABLED
				%LabelMSAA.text="Disabled"
			1:
				get_viewport().msaa_3d=Viewport.MSAA_2X
				%LabelMSAA.text="2X"
			2:
				get_viewport().msaa_3d=Viewport.MSAA_4X
				%LabelMSAA.text="4X"
			3:
				get_viewport().msaa_3d=Viewport.MSAA_8X
				%LabelMSAA.text="8X"
		config.msaa=value
	)
	%SliderMSAA.value = config.msaa

	# TAA

	%CheckButtonTAA.toggled.connect(func(toggled_on: bool) -> void:
		get_viewport().use_taa=toggled_on
		config.taa=toggled_on
	)
	%CheckButtonTAA.button_pressed = config.taa

	# Filter / Shader Settings
	# --------------------------------------------------------------------

	%CheckButtonFilter1.toggled.connect(func(toggled_on: bool) -> void:
		main.get_node("%VHSFilter1").visible=toggled_on
		config.filter_1=toggled_on
	)
	%CheckButtonFilter1.button_pressed = config.filter_1

	%CheckButtonFilter2.toggled.connect(func(toggled_on: bool) -> void:
		main.get_node("%VHSFilter2").visible=toggled_on
		config.filter_2=toggled_on
	)
	%CheckButtonFilter2.button_pressed = config.filter_2

	%CheckButtonFilter3.toggled.connect(func(toggled_on: bool) -> void:
		main.get_node("%VHSFilter3").visible=toggled_on
		config.filter_3=toggled_on
	)
	%CheckButtonFilter3.button_pressed = config.filter_3

	%CheckButtonFilter4.toggled.connect(func(toggled_on: bool) -> void:
		main.get_node("%Filter4").visible=toggled_on
		config.filter_4=toggled_on
	)
	%CheckButtonFilter4.button_pressed = config.filter_4

	%CheckButtonFilter5.toggled.connect(func(toggled_on: bool) -> void:
		main.get_node("%CRTShader").visible=toggled_on
		config.crt_filter=toggled_on
	)
	%CheckButtonFilter5.button_pressed = config.crt_filter

	# Keybindings
	# --------------------------------------------------------------------

	get_tree().physics_frame.connect(func() -> void:
		%ButtonBindUp1.text=get_key_bind("key_up", 0)
		%ButtonBindUp2.text=get_key_bind("key_up", 1)
		%ButtonBindDown1.text=get_key_bind("key_down", 0)
		%ButtonBindDown2.text=get_key_bind("key_down", 1)
		%ButtonBindLeft1.text=get_key_bind("key_left", 0)
		%ButtonBindLeft2.text=get_key_bind("key_left", 1)
		%ButtonBindRight1.text=get_key_bind("key_right", 0)
		%ButtonBindRight2.text=get_key_bind("key_right", 1)
		%ButtonBindOpt1.text=get_key_bind("key_option", 0)
		%ButtonBindOpt2.text=get_key_bind("key_option", 1)
		%ButtonBindEdit1.text=get_key_bind("key_edit", 0)
		%ButtonBindEdit2.text=get_key_bind("key_edit", 1)
		%ButtonBindShift1.text=get_key_bind("key_shift", 0)
		%ButtonBindShift2.text=get_key_bind("key_shift", 1)
		%ButtonBindPlay1.text=get_key_bind("key_play", 0)
		%ButtonBindPlay2.text=get_key_bind("key_play", 1)
	)

	%ButtonBindUp1.button_down.connect(start_key_rebind.bind("key_up", 0))
	%ButtonBindUp2.button_down.connect(start_key_rebind.bind("key_up", 1))
	%ButtonBindDown1.button_down.connect(start_key_rebind.bind("key_down", 0))
	%ButtonBindDown2.button_down.connect(start_key_rebind.bind("key_down", 1))
	%ButtonBindLeft1.button_down.connect(start_key_rebind.bind("key_left", 0))
	%ButtonBindLeft2.button_down.connect(start_key_rebind.bind("key_left", 1))
	%ButtonBindRight1.button_down.connect(start_key_rebind.bind("key_right", 0))
	%ButtonBindRight2.button_down.connect(start_key_rebind.bind("key_right", 1))
	%ButtonBindOpt1.button_down.connect(start_key_rebind.bind("key_option", 0))
	%ButtonBindOpt2.button_down.connect(start_key_rebind.bind("key_option", 1))
	%ButtonBindEdit1.button_down.connect(start_key_rebind.bind("key_edit", 0))
	%ButtonBindEdit2.button_down.connect(start_key_rebind.bind("key_edit", 1))
	%ButtonBindShift1.button_down.connect(start_key_rebind.bind("key_shift", 0))
	%ButtonBindShift2.button_down.connect(start_key_rebind.bind("key_shift", 1))
	%ButtonBindPlay1.button_down.connect(start_key_rebind.bind("key_play", 0))
	%ButtonBindPlay2.button_down.connect(start_key_rebind.bind("key_play", 1))

	%ButtonResetBinds.button_down.connect(reset_key_rebinds.bind());

	load_key_rebinds()

	# M8 Model Options
	# --------------------------------------------------------------------
	
	# Background color (read-only)

	get_tree().physics_frame.connect(func() -> void:
		var color: Color=main.m8_client.get_background_color()
		if color != %ThemeBGColor.color:
			%LabelThemeBGColor.text="#%s" % color.to_html(false).to_upper()
			%ThemeBGColor.color=color
	)

	# Key highlight colors (also affects key overlay color)

	%SliderHL_Opacity.value_changed.connect(func(value: float) -> void:
		config.hl_opacity=value
		%LabelHL_Opacity.text="%d%%" % (value * 100)
		if get_device_model():
			get_device_model().highlight_opacity=value
	)
	%SliderHL_Opacity.value = config.hl_opacity

	%CheckButtonHL_Filters.toggled.connect(func(toggled_on: bool) -> void:
		config.hl_filters=toggled_on
		var index_on:=main.get_node("%VHSFilter1").get_index()
		var index_off:=main.get_node("%CRTShader").get_index()
		if toggled_on:
			main.get_node("%UI").move_child(main.key_overlay, index_on)
		else:
			main.get_node("%UI").move_child(main.key_overlay, index_off)
	)
	%CheckButtonHL_Filters.button_pressed = config.hl_filters

	var on_directional_color_changed := func(color: Color) -> void:
		main.key_overlay.color_directional = color
		config.hl_color_directional = color

		%ColorPickerHL_Up.color = color
		%ColorPickerHL_Down.color = color
		%ColorPickerHL_Left.color = color
		%ColorPickerHL_Right.color = color

		if get_device_model():
			get_device_model().get_node("%Keycap_Up").material_overlay.albedo_color = color
			get_device_model().get_node("%Keycap_Down").material_overlay.albedo_color = color
			get_device_model().get_node("%Keycap_Left").material_overlay.albedo_color = color
			get_device_model().get_node("%Keycap_Right").material_overlay.albedo_color = color

	%ColorPickerHL_Up.color_changed.connect(on_directional_color_changed)
	%ColorPickerHL_Down.color_changed.connect(on_directional_color_changed)
	%ColorPickerHL_Left.color_changed.connect(on_directional_color_changed)
	%ColorPickerHL_Right.color_changed.connect(on_directional_color_changed)
	%ColorPickerHL_Up.color = config.hl_color_directional
	%ColorPickerHL_Down.color = config.hl_color_directional
	%ColorPickerHL_Left.color = config.hl_color_directional
	%ColorPickerHL_Right.color = config.hl_color_directional

	%ColorPickerHL_Shift.color_changed.connect(func(color: Color) -> void:
		main.key_overlay.color_shift=color
		config.hl_color_shift=color
		if get_device_model():
			get_device_model().get_node("%Keycap_Shift").material_overlay.albedo_color=color
	)
	%ColorPickerHL_Shift.color = config.hl_color_shift

	%ColorPickerHL_Play.color_changed.connect(func(color: Color) -> void:
		main.key_overlay.color_play=color
		config.hl_color_play=color
		if get_device_model():
			get_device_model().get_node("%Keycap_Play").material_overlay.albedo_color=color
	)
	%ColorPickerHL_Play.color = config.hl_color_play

	%ColorPickerHL_Option.color_changed.connect(func(color: Color) -> void:
		main.key_overlay.color_option=color
		config.hl_color_option=color
		if get_device_model():
			get_device_model().get_node("%Keycap_Option").material_overlay.albedo_color=color
	)
	%ColorPickerHL_Option.color = config.hl_color_option

	%ColorPickerHL_Edit.color_changed.connect(func(color: Color) -> void:
		main.key_overlay.color_edit=color
		config.hl_color_edit=color
		if get_device_model():
			get_device_model().get_node("%Keycap_Edit").material_overlay.albedo_color=color
	)
	%ColorPickerHL_Edit.color = config.hl_color_edit

	for colorpicker: ColorPickerButton in [
		%ColorPickerHL_Up,
		%ColorPickerHL_Down,
		%ColorPickerHL_Left,
		%ColorPickerHL_Right,
		%ColorPickerHL_Shift,
		%ColorPickerHL_Play,
		%ColorPickerHL_Option,
		%ColorPickerHL_Edit
	]:
		colorpicker.get_picker().preset_added.connect(on_color_picker_add_preset)
		colorpicker.get_picker().preset_removed.connect(on_color_picker_erase_preset)

	%CheckButtonKeyOverlayEnable.toggled.connect(func(toggled_on: bool) -> void:
		main.key_overlay.visible=toggled_on
		if toggled_on == false:
			main.key_overlay.clear()
		config.key_overlay_enabled=toggled_on
	)
	%CheckButtonKeyOverlayEnable.button_pressed = config.key_overlay_enabled

	%SliderKeyOverlayStyle.value_changed.connect(func(value: int) -> void:
		main.key_overlay.overlay_style=value
		config.key_overlay_style=value
		if value == 0:
			%LabelKeyOverlayStyle.text="Boxed"
		else:
			%LabelKeyOverlayStyle.text="Unboxed"
	)
	%SliderKeyOverlayStyle.value = config.key_overlay_style

	# Misc
	# --------------------------------------------------------------------

	# serial ports

	var refresh_serial_ports := func() -> void:
		%ListSerialPorts.clear()
		for port in M8GD.list_devices():
			%ListSerialPorts.add_item(port)

	refresh_serial_ports.call()

	%ListSerialPorts.item_selected.connect(func(index: int) -> void:
		%ButtonConnectSerialPort.disabled=false
		if main.current_serial_device == %ListSerialPorts.get_item_text(index):
			%ButtonConnectSerialPort.text="Reconnect"
			%ButtonDisconnectSerialPort.disabled=false
		else:
			%ButtonConnectSerialPort.text="Connect"
			%ButtonDisconnectSerialPort.disabled=true
	)

	%ButtonRefreshSerialPorts.pressed.connect(refresh_serial_ports)

	%ButtonConnectSerialPort.pressed.connect(func() -> void:
		var index: int= %ListSerialPorts.get_selected_items()[0]
		var text: String= %ListSerialPorts.get_item_text(index)
		main.m8_device_connect(text)
		%ListSerialPorts.deselect_all()
		%ButtonConnectSerialPort.disabled=true
		%ButtonConnectSerialPort.text="Connect"
	)

	%ButtonDisconnectSerialPort.pressed.connect(func() -> void:
		main.m8_device_disconnect(false)
	)

	# audio devices

	var refresh_audio_devices := func() -> void:
		%ListAudioDevices.clear()
		for device in AudioServer.get_input_device_list():
			%ListAudioDevices.add_item(device)

	refresh_audio_devices.call()

	%ListAudioDevices.item_selected.connect(func(index: int) -> void:
		%ButtonConnectAudioDevice.disabled=false
		if main.current_audio_device == %ListAudioDevices.get_item_text(index):
			%ButtonConnectAudioDevice.text="Reconnect"
			%ButtonDisconnectAudioDevice.disabled=false
		else:
			%ButtonConnectAudioDevice.text="Connect"
			%ButtonDisconnectAudioDevice.disabled=true
	)

	%ButtonRefreshAudioDevices.pressed.connect(refresh_audio_devices)

	%ButtonConnectAudioDevice.pressed.connect(func() -> void:
		var index: int= %ListAudioDevices.get_selected_items()[0]
		var text: String= %ListAudioDevices.get_item_text(index)
		main.m8_audio_connect(text)
		%ListAudioDevices.deselect_all()
		%ButtonConnectAudioDevice.disabled=true
		%ButtonConnectAudioDevice.text="Connect"
	)

	%ButtonDisconnectAudioDevice.pressed.connect(func() -> void:
		main.m8_audio_disconnect()
	)

	%TabContainer.tab_changed.connect(func(tab: int) -> void:
		if tab == 5: # misc tab
			refresh_serial_ports.call()
			refresh_audio_devices.call()
	)

	# Debug Tab
	# --------------------------------------------------------------------

	%CheckButtonDebug.toggled.connect(func(toggled_on: bool) -> void:
		main.get_node("%DebugLabels").visible=toggled_on
		config.debug_info=toggled_on
	)
	%CheckButtonDebug.button_pressed = config.debug_info

	%ButtonM8Enable.pressed.connect(main.m8_send_enable_display)
	%ButtonM8Disable.pressed.connect(main.m8_send_disable_display)
	%ButtonM8Reset.pressed.connect(main.m8_send_reset_display)

	%SpinBoxM8Keys.value_changed.connect(func(value: float) -> void:
		%LabelM8KeysBinary.text=String.num_int64(int(value), 2).pad_zeros(8)
	)

	%ButtonM8Control.pressed.connect(func() -> void:
		var keys: int= %SpinBoxM8Keys.get_line_edit().text.to_int()
		main.m8_send_control(keys)
	)

	%ButtonM8KeyJazz.pressed.connect(func() -> void:
		var n: int= %SpinBoxM8Note.get_line_edit().text.to_int()
		var v: int= %SpinBoxM8Vel.get_line_edit().text.to_int()
		print("debug: sending keyjazz (n=%d, v=%d)" % [n, v])
		main.m8_send_keyjazz(n, v)
	)

	%SpinBoxM8ThemeDelay.value_changed.connect(func(value: float) -> void:
		%LabelM8ThemeDelayMS.text="%.1fms" % (value / 60.0 * 1000.0)
	)

	var m8t_colors := [
		%ColorM8T0, %ColorM8T1, %ColorM8T2, %ColorM8T3,
		%ColorM8T4, %ColorM8T5, %ColorM8T6, %ColorM8T7,
		%ColorM8T8, %ColorM8T9, %ColorM8T10, %ColorM8T11,
		%ColorM8T12
	]

	%ButtonM8Theme.pressed.connect(func() -> void:
		print("debug: sending theme colors")
		var delay_frames: int= %SpinBoxM8ThemeDelay.get_line_edit().text.to_int()
		for i: int in range(m8t_colors.size()):
			main.m8_send_theme_color(i, m8t_colors[i].color)
			for j in range(delay_frames):
				await get_tree().physics_frame
	)

func on_color_picker_add_preset(color: Color) -> void:
	%ColorPickerHL_Up.get_picker().add_preset(color)
	%ColorPickerHL_Down.get_picker().add_preset(color)
	%ColorPickerHL_Left.get_picker().add_preset(color)
	%ColorPickerHL_Right.get_picker().add_preset(color)
	%ColorPickerHL_Shift.get_picker().add_preset(color)
	%ColorPickerHL_Play.get_picker().add_preset(color)
	%ColorPickerHL_Option.get_picker().add_preset(color)
	%ColorPickerHL_Edit.get_picker().add_preset(color)

func on_color_picker_erase_preset(color: Color) -> void:
	%ColorPickerHL_Up.get_picker().erase_preset(color)
	%ColorPickerHL_Down.get_picker().erase_preset(color)
	%ColorPickerHL_Left.get_picker().erase_preset(color)
	%ColorPickerHL_Right.get_picker().erase_preset(color)
	%ColorPickerHL_Shift.get_picker().erase_preset(color)
	%ColorPickerHL_Play.get_picker().erase_preset(color)
	%ColorPickerHL_Option.get_picker().erase_preset(color)
	%ColorPickerHL_Edit.get_picker().erase_preset(color)

##
## Try to return the device model in the current scene.
## If there isn't one, returns null.
##
func get_device_model() -> DeviceModel:
	if main.current_scene:
		return main.current_scene.get_node("%DeviceModel")
	else:
		return null

func update_device_colors() -> void:

	if get_device_model():

		get_device_model().highlight_opacity = %SliderHL_Opacity.value

		get_device_model().get_node("%Keycap_Up").material_overlay.albedo_color = %ColorPickerHL_Up.color
		get_device_model().get_node("%Keycap_Down").material_overlay.albedo_color = %ColorPickerHL_Down.color
		get_device_model().get_node("%Keycap_Left").material_overlay.albedo_color = %ColorPickerHL_Left.color
		get_device_model().get_node("%Keycap_Right").material_overlay.albedo_color = %ColorPickerHL_Right.color
		get_device_model().get_node("%Keycap_Shift").material_overlay.albedo_color = %ColorPickerHL_Shift.color
		get_device_model().get_node("%Keycap_Play").material_overlay.albedo_color = %ColorPickerHL_Play.color
		get_device_model().get_node("%Keycap_Option").material_overlay.albedo_color = %ColorPickerHL_Option.color
		get_device_model().get_node("%Keycap_Edit").material_overlay.albedo_color = %ColorPickerHL_Edit.color

	main.key_overlay.color_directional = %ColorPickerHL_Up.color
	main.key_overlay.color_shift = %ColorPickerHL_Shift.color
	main.key_overlay.color_play = %ColorPickerHL_Play.color
	main.key_overlay.color_option = %ColorPickerHL_Option.color
	main.key_overlay.color_edit = %ColorPickerHL_Edit.color

func reset_key_rebinds() -> void:
	for action: String in [
		"key_up", "key_down", "key_left", "key_right",
		"key_shift", "key_play", "key_option", "key_edit"]:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, ProjectSettings.get_setting("input/" + action).events[0])
	save_key_rebinds()
	print("keybindings reset to default")

func load_key_rebinds() -> void:
	for action: String in main.config.action_events.keys():
		var events: Array = main.config.action_events[action]
		assert(events is Array)
		for event: InputEvent in events:
			assert(event is InputEvent, "event is not InputEvent, found %s" % type_string(typeof(event)))
			InputMap.action_add_event(action, event)
	print("key bindings loaded from config")

func save_key_rebinds() -> void:
	for action: String in main.M8_ACTIONS:
		var events := InputMap.action_get_events(action)
		main.config.action_events[action] = events
	print("key bindings saved to config")

func get_key_bind(action: String, index: int) -> String:

	var events := InputMap.action_get_events(action)
	var event: InputEvent
	if index == 0 and events.size() == 0:
		event = ProjectSettings.get_setting("input/" + action).events[0]
	elif index < events.size():
		event = events[index]
	else:
		return "----"

	return event.as_text()

func start_key_rebind(action: String, index: int) -> void:
	# prevent opening rebind prompt too fast
	if Time.get_ticks_msec() - last_rebind_time < REBIND_COOLDOWN:
		return

	%BindActionPopup.visible = true

	key_rebind_callback = func(event: InputEvent) -> void:
		var events := InputMap.action_get_events(action)

		if events.size() <= index:
			events.append(event)
		else:
			assert(index < events.size())
			events[index] = event

		# clear all events and add modified ones
		InputMap.action_erase_events(action)
		for e in events:
			InputMap.action_add_event(action, e)

		Input.action_release(action)
		save_key_rebinds()
	
	is_key_rebinding = true
	print("starting rebind of %s" % action)

func end_key_rebind() -> void:
	is_key_rebinding = false
	last_rebind_time = Time.get_ticks_msec()
	%BindActionPopup.visible = false

func set_status_serialport(text: String) -> void:
	%SerialPortStatus.text = text

func set_status_audiodevice(text: String) -> void:
	%AudioDeviceStatus.text = text

func _input(event: InputEvent) -> void:
	if is_key_rebinding:
		if event is InputEventKey and event.pressed:
			if event.keycode != KEY_ESCAPE:
				key_rebind_callback.call(event)
			end_key_rebind()
		if event is InputEventJoypadButton and event.pressed:
			key_rebind_callback.call(event)
			end_key_rebind()
		return

	if event is InputEventKey:
		# menu on/off toggle
		if event.pressed and event.keycode == KEY_ESCAPE:
			visible = !visible

func _process(_delta: float) -> void:
	%CheckButtonFullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	%OptionRes.disabled = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	%CheckButtonVsync.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	%LabelFPSCap.text = "%d" % Engine.max_fps
