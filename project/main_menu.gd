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

func initialize(p_main: M8SceneDisplay) -> void:

	main = p_main
	var config := main.config

	# scan scenes folder
	var dir_scenes = DirAccess.open(PATH_SCENES)

	dir_scenes.list_dir_begin()
	var path := dir_scenes.get_next()
	while path != "":
		if path.trim_suffix(".remap").get_extension() == "tscn":
			option_scenes.add_item(path.get_file().get_basename())
			scene_paths.append(dir_scenes.get_current_dir().path_join(path))
		path = dir_scenes.get_next()

	option_scenes.item_selected.connect(func(index: int):
		main.load_scene(scene_paths[index])
	)

	button_exit.pressed.connect(func():
		main.quit()
	)

	%DisplayRect.texture = main.m8_client.get_display_texture()

	#==========================================================================
	# OPTIONS
	#==========================================================================

	# Scene settings
	#--------------------------------------------------------------------------

	%ButtonResetSceneVars.pressed.connect(func():
		main.current_scene.config_delete_profile(main.current_scene.DEFAULT_PROFILE)
		main.reload_scene()
	)

	# Audio settings
	#--------------------------------------------------------------------------

	# volume

	slider_volume.value_changed.connect(func(value: float):
		var volume_db=- 60.0 * (1 - value)
		print("volume = %f" % volume_db)
		AudioServer.set_bus_volume_db(0, volume_db)
		%LabelVolume.text="%d%%" % round(slider_volume.value / slider_volume.max_value * 100)
		config.volume=value
	)

	slider_volume.value = config.volume

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
	audio_latency_update_timer.timeout.connect(func():
		if visible:
			%LineEditAudioLatency.placeholder_text="%f ms" % AudioServer.get_output_latency()
	)
	# %LineEditAudioLatency.text_submitted.connect(func(text):
	# 	if text.is_valid_int():
	# 		ProjectSettings.set_setting("audio/driver/output_latency", int(text))
	# 	%LineEditAudioLatency.text=""
	# 	%LineEditAudioLatency.placeholder_text="%f ms" % AudioServer.get_output_latency()
	# )

	# video

	%CheckButtonFullscreen.toggled.connect(func(toggled_on):
		if toggled_on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		config.fullscreen=toggled_on
	)
	%CheckButtonFullscreen.button_pressed = config.fullscreen

	%CheckButtonVsync.toggled.connect(func(toggled_on):
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

	get_tree().physics_frame.connect(func():
		var wsize:=DisplayServer.window_get_size()
		%OptionRes.set_item_text(0, "%dx%d" % [wsize.x, wsize.y])
	)

	%OptionRes.item_selected.connect(func(index):
		match index:
			2: DisplayServer.window_set_size(Vector2i(640, 480))
			3: DisplayServer.window_set_size(Vector2i(960, 720))
			4: DisplayServer.window_set_size(Vector2i(1280, 960))
			6: DisplayServer.window_set_size(Vector2i(960, 640))
			7: DisplayServer.window_set_size(Vector2i(1440, 960))
			8: DisplayServer.window_set_size(Vector2i(1920, 1280))
		%OptionRes.select(0)
	)

	%SliderFPSCap.value_changed.connect(func(value: float):
		if value > 0 and value < 15: value=15
		Engine.max_fps=int(value)
		config.fps_cap=int(value)
	)
	%SliderFPSCap.value = config.fps_cap

	# graphics

	%SliderDOFShape.value_changed.connect(func(value: RenderingServer.DOFBokehShape):
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

	%SliderDOFQuality.value_changed.connect(func(value: RenderingServer.DOFBlurQuality):
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

	%SliderMSAA.value_changed.connect(func(value: int):
		match value:
			0:
				main.scene_viewport.msaa_3d=Viewport.MSAA_DISABLED
				%LabelMSAA.text="Disabled"
			1:
				main.scene_viewport.msaa_3d=Viewport.MSAA_2X
				%LabelMSAA.text="2X"
			2:
				main.scene_viewport.msaa_3d=Viewport.MSAA_4X
				%LabelMSAA.text="4X"
			3:
				main.scene_viewport.msaa_3d=Viewport.MSAA_8X
				%LabelMSAA.text="8X"
		config.msaa=value
	)
	%SliderMSAA.value = config.msaa

	# TAA

	%CheckButtonTAA.toggled.connect(func(toggled_on: bool):
		# ProjectSettings.set_setting("rendering/anti_aliasing/quality/use_taa", toggled_on)
		main.scene_viewport.use_taa=toggled_on
		config.taa=toggled_on
	)
	%CheckButtonTAA.button_pressed = config.taa

	# Filter / Shader Settings
	# --------------------------------------------------------------------

	%CheckButtonFilter1.toggled.connect(func(toggled_on):
		main.get_node("%VHSFilter1").visible=toggled_on
		config.filter_1=toggled_on
	)
	%CheckButtonFilter1.button_pressed = config.filter_1

	%CheckButtonFilter2.toggled.connect(func(toggled_on):
		main.get_node("%VHSFilter2").visible=toggled_on
		config.filter_2=toggled_on
	)
	%CheckButtonFilter2.button_pressed = config.filter_2

	%CheckButtonFilter3.toggled.connect(func(toggled_on):
		main.get_node("%VHSFilter3").visible=toggled_on
		config.filter_3=toggled_on
	)
	%CheckButtonFilter3.button_pressed = config.filter_3

	%CheckButtonFilter4.toggled.connect(func(toggled_on):
		main.get_node("%Filter4").visible=toggled_on
		config.filter_4=toggled_on
	)
	%CheckButtonFilter4.button_pressed = config.filter_4

	%CheckButtonFilter5.toggled.connect(func(toggled_on):
		main.get_node("%CRTShader").visible=toggled_on
		config.crt_filter=toggled_on
	)
	%CheckButtonFilter5.button_pressed = config.crt_filter

	# M8 Model Options
	# --------------------------------------------------------------------
	
	# Background color (read-only)

	get_tree().physics_frame.connect(func():
		var color=main.m8_client.get_background_color()
		if color != %ThemeBGColor.color:
			%LabelThemeBGColor.text="#%s" % color.to_html(false).to_upper()
			%ThemeBGColor.color=color
	)

	# Keybindings
	# --------------------------------------------------------------------

	get_tree().physics_frame.connect(func():
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

	%ButtonBindUp1.button_down.connect(func(): start_key_rebind("key_up", 0))
	%ButtonBindUp2.button_down.connect(func(): start_key_rebind("key_up", 1))
	%ButtonBindDown1.button_down.connect(func(): start_key_rebind("key_down", 0))
	%ButtonBindDown2.button_down.connect(func(): start_key_rebind("key_down", 1))
	%ButtonBindLeft1.button_down.connect(func(): start_key_rebind("key_left", 0))
	%ButtonBindLeft2.button_down.connect(func(): start_key_rebind("key_left", 1))
	%ButtonBindRight1.button_down.connect(func(): start_key_rebind("key_right", 0))
	%ButtonBindRight2.button_down.connect(func(): start_key_rebind("key_right", 1))
	%ButtonBindOpt1.button_down.connect(func(): start_key_rebind("key_option", 0))
	%ButtonBindOpt2.button_down.connect(func(): start_key_rebind("key_option", 1))
	%ButtonBindEdit1.button_down.connect(func(): start_key_rebind("key_edit", 0))
	%ButtonBindEdit2.button_down.connect(func(): start_key_rebind("key_edit", 1))
	%ButtonBindShift1.button_down.connect(func(): start_key_rebind("key_shift", 0))
	%ButtonBindShift2.button_down.connect(func(): start_key_rebind("key_shift", 1))
	%ButtonBindPlay1.button_down.connect(func(): start_key_rebind("key_play", 0))
	%ButtonBindPlay2.button_down.connect(func(): start_key_rebind("key_play", 1))

	%ButtonResetBinds.button_down.connect(func(): reset_key_rebinds());

	load_key_rebinds()

	# Misc
	# --------------------------------------------------------------------

	# debug text

	%CheckButtonDebug.toggled.connect(func(toggled_on):
		main.get_node("%DebugLabels").visible=toggled_on
		config.debug_info=toggled_on
	)
	%CheckButtonDebug.button_pressed = config.debug_info

	# serial ports

	var refresh_serial_ports = func():
		%ListSerialPorts.clear()
		for port in M8GD.list_devices():
			%ListSerialPorts.add_item(port)

	refresh_serial_ports.call()

	%ListSerialPorts.item_selected.connect(func(_index):
		%ButtonConnectSerialPort.disabled=false
	)

	%ButtonRefreshSerialPorts.pressed.connect(refresh_serial_ports)

	%ButtonConnectSerialPort.pressed.connect(func():
		var index= %ListSerialPorts.get_selected_items()[0]
		var text= %ListSerialPorts.get_item_text(index)
		main.m8_device_connect(text)
		%ListSerialPorts.deselect_all()
		%ButtonConnectSerialPort.disabled=true
	)

	# audio devices

	var refresh_audio_devices = func():
		%ListAudioDevices.clear()
		for device in AudioServer.get_input_device_list():
			%ListAudioDevices.add_item(device)

	refresh_audio_devices.call()

	%ListAudioDevices.item_selected.connect(func(_index):
		%ButtonConnectAudioDevice.disabled=false
	)

	%ButtonRefreshAudioDevices.pressed.connect(refresh_audio_devices)

	%ButtonConnectAudioDevice.pressed.connect(func():
		var index= %ListAudioDevices.get_selected_items()[0]
		var text= %ListAudioDevices.get_item_text(index)
		main.m8_audio_connect(text)
		%ListAudioDevices.deselect_all()
		%ButtonConnectAudioDevice.disabled=true
	)

func reset_key_rebinds() -> void:
	for action in [
		"key_up", "key_down", "key_left", "key_right",
		"key_shift", "key_play", "key_option", "key_edit"]:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, ProjectSettings.get_setting("input/" + action).events[0])
	save_key_rebinds()
	print("keybindings reset to default")

func load_key_rebinds() -> void:
	for action in main.config.action_events.keys():
		var events = main.config.action_events[action]
		assert(events is Array)
		for event in events:
			assert(event is InputEvent, "event is not InputEvent, found %s" % type_string(typeof(event)))
			InputMap.action_add_event(action, event)
	print("key bindings loaded from config")

func save_key_rebinds() -> void:
	for action in main.M8_ACTIONS:
		var events = InputMap.action_get_events(action)
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

func start_key_rebind(action: String, index: int):
	# prevent opening rebind prompt too fast
	if Time.get_ticks_msec() - last_rebind_time < REBIND_COOLDOWN:
		return

	%BindActionPopup.visible = true

	key_rebind_callback = func(event: InputEvent):
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

func end_key_rebind():
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

func _process(_delta) -> void:
	%CheckButtonFullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	%OptionRes.disabled = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	%CheckButtonVsync.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	%LabelFPSCap.text = "%d" % Engine.max_fps
