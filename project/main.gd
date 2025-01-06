class_name Main extends Node

signal m8_system_info_received(hardware: String, firmware: String)
signal m8_font_changed
signal m8_theme_changed(colors: PackedColorArray, complete: bool)
signal m8_connected
signal m8_disconnected

## Emitted after a profile has been loaded.
signal profile_loaded(profile_name: String)

## Emitted after a scene has been loaded.
## Loading a profile will also emit this signal if a new scene wasn't loaded.
signal scene_loaded(scene_path: String, scene: M8Scene)

const MAIN_SCENE_PATH: String = "res://scenes/floating_scene.tscn"
const PATH_SCENES: String = "res://scenes/"

const FONT_01_SMALL: BitMap = preload("res://assets/m8_fonts/5_7.bmp")
const FONT_01_BIG: BitMap = preload("res://assets/m8_fonts/8_9.bmp")
const FONT_02_SMALL: BitMap = preload("res://assets/m8_fonts/9_9.bmp")
const FONT_02_BOLD: BitMap = preload("res://assets/m8_fonts/10_10.bmp")
const FONT_02_HUGE: BitMap = preload("res://assets/m8_fonts/12_12.bmp")

const M8_ACTIONS := [
	"key_up", "key_down", "key_left", "key_right",
	"key_shift", "key_play", "key_option", "key_edit"]

@export var visualizer_aberration_amount := 1.0
@export var visualizer_brightness_amount := 0.1
@export var visualizer_frequency_min := 0
@export var visualizer_frequency_max := 400

@export var overlay_integer_zoom: int = 1:
	set(value):
		overlay_integer_zoom = value
		if is_inside_tree():
			_overlay_update_viewport_size()

var m8_virtual_keyboard_enabled := false
var m8_virtual_keyboard_notes := []
var m8_virtual_keyboard_octave := 3
var m8_virtual_keyboard_velocity := 127

var current_serial_device: String = ""
var current_audio_device: String = ""

## if true, keep scanning for devices until one is found
var is_waiting_for_device := true

## true if audio device is in the middle of connecting
var is_audio_connecting := false
var audio_device_last: String = ""

var audio_peak := 0.0 # audio peak (in dB)
var audio_peak_max := 0.0
var audio_level_raw := 0.0 # audio peak (in linear from 0.0 to 1.0)
var audio_level := 0.0 # audio peak (in linear from 0.0 to 1.0)
var last_peak := 0.0
var last_peak_max := 0.0
var last_audio_level := 0.0

@onready var config := M8Config.load()

@onready var audio_monitor: AudioStreamPlayer = %AudioStreamPlayer

# @onready var scene_viewport: SubViewport = %SceneViewport
@onready var scene_root: Node = %SceneRoot
@onready var current_scene: M8Scene = null

# overlays
@onready var overlay_keys: OverlayKeys = %KeyOverlay
@onready var overlay_spectrum: OverlayBase = %OverlayAudioSpectrum
@onready var overlay_waveform: OverlayBase = %OverlayAudioWaveform
@onready var overlay_display: OverlayBase = %OverlayDisplayPanel

@onready var menu: MainMenu = %MainMenuPanel
@onready var menu_scene: SceneMenu = %SceneMenu
@onready var menu_camera: PanelContainer = %SceneCameraMenu
@onready var menu_overlay: PanelContainer = %MenuOverlay

@onready var cam_status: RichTextLabel = %CameraStatus
@onready var cam_help: RichTextLabel = %CameraControls
@onready var cam_status_template: String = cam_status.text
@onready var m8_client: M8GD = %M8GD
@onready var m8_is_connected := false
@onready var m8_audio_connected := false

func _ready() -> void:

	# add_child(m8_client)

	get_window().min_size = Vector2i(960, 640)

	var start_time := Time.get_ticks_msec()

	_start_task("init overlays", func() -> void:
		overlay_spectrum.init(self)
		overlay_waveform.init(self)
		overlay_display.init(self)
		overlay_keys.init(self)
	)

	_start_task("init menus", func() -> void:
		menu.init(self)
		menu_scene.init(self)
		menu_camera.init(self)
		menu_overlay.init(self)
	)

	load_last_profile()

	_print("finished initializing in %.3f seconds!" % ((Time.get_ticks_msec() - start_time) / 1000.0))

	%Check_SplashDoNotShow.toggled.connect(func(toggle_mode: bool) -> void:
		config.splash_show = !toggle_mode
	)

	%ButtonSplashClose.pressed.connect(func() -> void:
		%SplashContainer.visible = false
	)

	%SplashContainer.visible = config.splash_show

func _process(_delta: float) -> void:

	# auto connect to m8s
	if !m8_is_connected and is_waiting_for_device:
		m8_device_connect_auto()

	# auto monitor audio if m8 is connected
	if m8_is_connected:
		if m8_audio_connected:
			m8_audio_check()
		else:
			m8_audio_connect_auto()

	%LabelFPS.text = "%d" % Engine.get_frames_per_second()

	var palette := m8_get_theme_colors()

	if palette.size() < 16:
		for i in range(16):
			get_node("%%Color_Palette%d" % (i + 1)).color = Color(0, 0, 0, 0)
		for i in range(palette.size()):
			get_node("%%Color_Palette%d" % (i + 1)).color = palette[i]


func _physics_process(delta: float) -> void:

	update_audio_analyzer()

	var modulate_color := m8_client.get_theme_colors()[0]
	# modulate_color.v = 1.0
	%BGShader.material.set_shader_parameter("tint_color", modulate_color)

	# do shader parameter responses to audio

	%CRTShader3.material.set_shader_parameter("aberration", audio_level * visualizer_aberration_amount)
	%CRTShader3.material.set_shader_parameter("brightness", 1.0 + (audio_level * visualizer_brightness_amount))
	# %BGShader.material.set_shader_parameter("brightness", 1.0 + (audio_level * visualizer_brightness_amount))

	# fade out status message

	if %LabelStatus.modulate.a > 0:
		%LabelStatus.modulate.a = lerp(%LabelStatus.modulate.a, %LabelStatus.modulate.a - delta * 2.0, 0.2)

func _input(event: InputEvent) -> void:

	if event is InputEventKey:
		# screenshot F12
		if event.pressed and event.keycode == KEY_F12:
			var id := 1
			var screenshot_name := "%d.png" % id

			while FileAccess.file_exists(screenshot_name):
				id += 1
				screenshot_name = "%d.png" % id

			get_viewport().get_texture().get_image().save_png(screenshot_name)

		# fullscreen ALT+ENTER toggle
		if event.pressed and event.keycode == KEY_ENTER and event.alt_pressed:
			if get_window().mode == Window.MODE_WINDOWED:
				get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			else:
				get_window().mode = Window.MODE_WINDOWED

		if event.pressed and event.keycode == KEY_ESCAPE:

			if %SplashContainer.visible:
				%SplashContainer.visible = false
				return

			# menu on/off toggle
			if is_menu_open():
				menu_close()
			else:
				menu_open()

	if _handle_input_keys(event): return

	if _handle_input_profile_hotkeys(event): return

	if _handle_input_keyjazz(event): return

func _notification(what: int) -> void:
	# enable quitting by clicking the X on the window.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()

func quit() -> void:
	config.save()
	m8_device_disconnect(false)
	get_tree().quit()

## Temporarily show a message on the bottom-left of the screen.
func print_blink(msg: String) -> void:
	%LabelStatus.text = msg
	%LabelStatus.modulate.a = 1.0

## Return true if user is in the menu.
func is_menu_open() -> bool:
	return menu.visible

func is_any_menu_open() -> bool:
	return menu.visible or menu_scene.visible or menu_camera.visible or menu_overlay.visible

func menu_open() -> void:
	menu_camera.menu_close()
	menu_scene.visible = false
	menu_overlay.menu_close()
	menu.visible = true

func menu_close() -> void:
	menu.visible = false

##
## Return the name of an M8 scene from its file.
## The scene's formatted name is stored in the export variable [m8_scene_name].
##
func get_scene_name(scene_path: String) -> String:
	return scene_path.get_file().get_basename().capitalize().trim_suffix("Scene")

##
## Load an M8 scene from a filepath.
##
## If the scene has loaded successfully, returns [true].
## If the filepath is invalid or the scene is unable to load, returns [false].
##
func load_scene(scene_path: String) -> bool:
	return _start_task("load scene \"%s\"" % scene_path, func() -> bool:

		var p_scene_path := scene_path
		var scene := _load_scene_from_file_path(p_scene_path)

		if !scene is M8Scene:
			p_scene_path = MAIN_SCENE_PATH
			scene = _load_scene_from_file_path(MAIN_SCENE_PATH)

		# remove existing scene from viewport
		if current_scene:
			print("freeing current scene...")
			scene_root.remove_child(current_scene)
			current_scene.queue_free()
			current_scene = null

		# add new scene and initialize
		print("adding new scene...")
		scene_root.add_child(scene)
		scene.init(self)
		menu.update_device_colors()
		config.use_scene(scene)
		current_scene = scene

		menu_scene.clear_params()
		scene.init_menu(menu_scene)

		scene_loaded.emit(p_scene_path, scene)

		print("scene loaded!")

		return true
	)

##
## Reset the current scene's properties to their default values.
## Clears the saved scene properties in the config file.
##
func reset_scene_to_default() -> void:
	assert(current_scene)
	config.clear_scene_parameters(current_scene)
	load_scene(current_scene.scene_file_path)

##
## Get the list of filepaths to M8 scene files.
##
func get_scene_paths() -> PackedStringArray:

	var scene_paths: PackedStringArray = []
	var dir_scenes: DirAccess = DirAccess.open(PATH_SCENES)

	dir_scenes.list_dir_begin()
	var path := dir_scenes.get_next()
	while path != "":
		if path.trim_suffix(".remap").get_extension() == "tscn":
			var scene_path := dir_scenes.get_current_dir().path_join(path).trim_suffix(".remap")
			scene_paths.append(scene_path)
		path = dir_scenes.get_next()

	return scene_paths

##
## Load the last saved profile.
##
func load_last_profile() -> void:
	load_profile(config.current_profile)

##
## Load a profile. If the profile doesn't exist, it will be initialized with
## the current scene and properties.
##
## Loading a profile will load the scene that was saved to it, as well as its
## scene properties, and all profile properties (overlays, filters, etc).
##
func load_profile(profile_name: String) -> bool:
	return _start_task("load profile \"%s\"" % profile_name, func() -> bool:
		config.use_profile(profile_name)
		var scene_path := config.get_current_scene_path()
		assert(scene_path != null)

		if current_scene == null or scene_path != current_scene.scene_file_path:
			load_scene(scene_path)
		else: # just reset the scene menu (also loads properties from config)
			menu_scene.clear_params()
			current_scene.init(self)
			current_scene.init_menu(menu_scene)
			scene_loaded.emit(scene_path, current_scene)

		init_overlays()

		profile_loaded.emit(profile_name)

		print("profile loaded!")

		return true
	)

func load_default_profile() -> void:
	load_profile(config.DEFAULT_PROFILE)

##
## Get the name of the active profile.
##
func get_current_profile_name() -> String:
	return config.current_profile

func is_using_default_profile() -> bool:
	return config.current_profile == config.DEFAULT_PROFILE

func list_profile_names() -> Array:
	return config.list_profile_names()

func rename_profile(new_profile_name: String) -> void:
	config.rename_current_profile(new_profile_name)

func create_new_profile() -> String:
	return config.create_new_profile()

func delete_profile(profile_name: String) -> void:
	if profile_name == get_current_profile_name():
		load_default_profile()
	config.delete_profile(profile_name)

func _get_propkey_overlay(overlay: Control, property: String) -> String:
	return "overlay.%s.%s" % [overlay.name, property]

func _get_propkey_camera(property: String) -> String:
	return "camera.%s" % property

func _get_propkey_filter(filter: ColorRect, property: String) -> String:
	return "filter.%s.%s" % [filter.name, property]

func _get_propkey_filter_shader(filter: ColorRect, property: String) -> String:
	return "filter.%s.shader.%s" % [filter.name, property]

##
## Set properties of the given overlay according to the current profile/scene.
##
func _init_overlay(overlay: OverlayBase) -> void:

	# manually init the overlay properties here since we won't have a
	# Setting node for all of them
	menu_overlay.init_settings(overlay)
	for property: String in overlay.overlay_get_properties():
		SettingBase.init_overlay_property(self, overlay, property)

##
## Initializes or re-initializes the state of the overlays.
## The overlays' states will be loaded from the config.
##
func init_overlays() -> void:

	m8_client.set_display_background_alpha(0)

	_init_overlay(overlay_display)
	_init_overlay(overlay_keys)
	_init_overlay(overlay_spectrum)
	_init_overlay(overlay_waveform)

	if !get_window().size_changed.is_connected(_overlay_update_viewport_size):
		get_window().size_changed.connect(_overlay_update_viewport_size)
	_overlay_update_viewport_size()

##
## Get the 3D camera of the current scene.
## Return [null] if there is no camera present in the scene.
##
func get_scene_camera() -> M8SceneCamera3D:
	if current_scene:
		return current_scene.get_3d_camera()
	else:
		return null

func get_filter_shader_parameter(shader_node_path: NodePath, shader_parameter: String) -> Variant:
	var shader_node: ColorRect = get_node(shader_node_path)
	assert(shader_node.material.get_shader_parameter(shader_parameter) != null, "shader parameter does not exist in %s: %s" % [shader_node_path, shader_parameter])
	return shader_node.material.get_shader_parameter(shader_parameter)

func set_filter_shader_parameter(shader_node_path: NodePath, shader_parameter: String, value: Variant) -> void:
	var shader_node: ColorRect = get_node(shader_node_path)
	assert(shader_node.material.get_shader_parameter(shader_parameter) != null, "shader parameter does not exist in %s: %s" % [shader_node_path, shader_parameter])
	shader_node.material.set_shader_parameter(shader_parameter, value)

# M8 client methods
################################################################################

func m8_device_connect(port: String) -> void:

	if m8_client.is_connected():
		m8_device_disconnect()

	var m8_ports: Array = M8GD.list_devices()

	if !port in m8_ports:
		menu.set_status_serialport("Failed: port not found: %s" % port)
		return

	menu.set_status_serialport("Connecting to serial port %s..." % m8_ports[0])

	if !m8_client.connect(port):
		menu.set_status_serialport("Failed: failed to connect to port: %s" % port)
		return

	m8_is_connected = true
	%LabelPort.text = m8_ports[0]
	m8_client.system_info.connect(on_m8_system_info)
	m8_client.font_changed.connect(on_m8_font_changed)
	m8_client.device_disconnected.connect(on_m8_device_disconnect)
	m8_client.theme_changed.connect(on_m8_theme_changed)
	current_serial_device = port
	m8_connected.emit()

	print_blink("connected to M8 at %s!" % m8_ports[0])
	menu.set_status_serialport("Connected to: %s" % m8_ports[0])

## Automatically detect and connect to any M8 device.
func m8_device_connect_auto() -> void:

	menu.set_status_serialport("Scanning for M8 devices...")

	var m8_ports: Array = M8GD.list_devices()
	if m8_ports.size():
		m8_device_connect(m8_ports[0])
	else:
		menu.set_status_serialport("Not connected: No M8 devices found")

func m8_device_disconnect(wait_for_device := true) -> void:
	if m8_client.is_connected():
		m8_client.disconnect()
		on_m8_device_disconnect()
		is_waiting_for_device = wait_for_device
		if is_waiting_for_device:
			menu.set_status_serialport("Not connected. Waiting for device...")

##
## Connect to the audio input device with name `device_name`.
## If `hard_reset` is true, also free and create a new AudioStreamPlayer.
##
func m8_audio_connect(device_name: String, hard_reset: bool = false) -> void:
	if !device_name in AudioServer.get_input_device_list():
		menu.set_status_audiodevice("Failed: audio device not found: %s" % device_name)
		return

	if is_audio_connecting: return
	is_audio_connecting = true
	audio_set_muted(true)

	if m8_audio_connected:
		m8_audio_disconnect()

	if hard_reset and is_instance_valid(audio_monitor):
		print("audio: removing AudioStreamPlayer")
		remove_child(audio_monitor)
		audio_monitor.stream = null
		audio_monitor.queue_free()
		audio_monitor = null

	menu.set_status_audiodevice("Not connected")
	await get_tree().create_timer(0.1).timeout

	AudioServer.input_device = device_name

	if hard_reset or !is_instance_valid(audio_monitor):
		print("audio: adding AudioStreamPlayer")
		audio_monitor = AudioStreamPlayer.new()
		audio_monitor.stream = AudioStreamMicrophone.new()
		audio_monitor.bus = "Analyzer"
		add_child(audio_monitor)

	audio_monitor.playing = false

	menu.set_status_audiodevice("Starting...")
	await get_tree().create_timer(0.1).timeout

	audio_device_last = device_name
	audio_monitor.playing = true
	m8_audio_connected = true
	is_audio_connecting = false
	audio_set_muted(false)

	current_audio_device = device_name
	print("audio: connected to device %s" % device_name)
	menu.set_status_audiodevice("Connected to: %s" % device_name)

##
## Automatically detect and monitor an M8 audio device.
##
func m8_audio_connect_auto() -> void:

	# If the M8 device is plugged in and detected, use it as a microphone and
	# playback to the default audio output device.
	for device in AudioServer.get_input_device_list():
		if device.contains("M8"):
			m8_audio_connect(device)
			return
	
	menu.set_status_audiodevice("Not connected: No M8 audio device found")

##
## Disconnect the M8 audio device from the monitor.
##
func m8_audio_disconnect() -> void:
	m8_audio_connected = false
	AudioServer.input_device = "Default"
	audio_monitor.playing = false
	current_audio_device = ""
	print("audio: disconnected")
	menu.set_status_audiodevice("Not connected (Disconnected)")

## Check if the M8 audio device still exists. If not, disconnect.
func m8_audio_check() -> void:
	if is_audio_connecting: return

	if is_instance_valid(audio_monitor):
		if !AudioServer.input_device in AudioServer.get_input_device_list():
			print("audio: device no longer found, disconnecting...")
			m8_audio_disconnect()
			return

		if !audio_monitor.playing or audio_monitor.stream_paused:
			print("audio: stream stopped, reconnecting...")
			m8_audio_connect(audio_device_last)

func on_m8_system_info(hardware: String, firmware: String) -> void:
	%LabelVersion.text = "%s %s" % [hardware, firmware]
	m8_system_info_received.emit(hardware, firmware)

func on_m8_font_changed(model: String, font: int) -> void:
	# switch between small/big fonts (Model_01)
	match model:
		"model_02":
			if font == 0:
				m8_client.load_font(FONT_02_SMALL)
			elif font == 1:
				m8_client.load_font(FONT_02_BOLD)
			else:
				m8_client.load_font(FONT_02_HUGE)
		_:
			if font == 0:
				m8_client.load_font(FONT_01_SMALL)
			else:
				m8_client.load_font(FONT_01_BIG)

	m8_font_changed.emit()

## Called when the M8 has been disconnected.
func on_m8_device_disconnect() -> void:

	m8_is_connected = false
	%LabelPort.text = ""

	m8_client.system_info.disconnect(on_m8_system_info)
	m8_client.font_changed.disconnect(on_m8_font_changed)
	m8_client.device_disconnected.disconnect(on_m8_device_disconnect)
	m8_client.theme_changed.disconnect(on_m8_theme_changed)

	if m8_audio_connected:
		m8_audio_disconnect()

	current_serial_device = ""
	m8_disconnected.emit()
	print_blink("disconnected")
	menu.set_status_serialport("Not connected (Disconnected)")

func on_m8_theme_changed(colors: PackedColorArray, complete: bool) -> void:
	m8_theme_changed.emit(colors, complete)

func m8_send_theme_color(index: int, color: Color) -> void:
	m8_client.send_theme_color(index, color)

func m8_send_enable_display() -> void:
	m8_client.send_enable_display()

func m8_send_disable_display() -> void:
	m8_client.send_disable_display()

func m8_send_reset_display() -> void:
	m8_client.send_reset_display()

func m8_send_keyjazz(note: int, velocity: int) -> void:
	m8_client.send_keyjazz(note, velocity)

func m8_send_control(keys: int) -> void:
	m8_client.send_input(keys)

func m8_is_key_pressed(keycode: int) -> bool:
	return m8_client.is_key_pressed(keycode)

func m8_get_theme_colors() -> PackedColorArray:
	return m8_client.get_theme_colors()

func audio_get_level() -> float:
	return audio_level

##
## Get the peak volume of the "Analyzer" bus.
##
func audio_get_peak_volume() -> Vector2:
	return Vector2(
		# db_to_linear(AudioServer.get_bus_peak_volume_left_db(1, 0)),
		# db_to_linear(AudioServer.get_bus_peak_volume_right_db(1, 0))
		AudioServer.get_bus_peak_volume_left_db(1, 0),
		AudioServer.get_bus_peak_volume_right_db(1, 0)
	)

func audio_get_spectrum_analyzer() -> AudioEffectSpectrumAnalyzerInstance:
	return AudioServer.get_bus_effect_instance(1, 0)

func audio_set_spectrum_analyzer_enabled(enabled: bool) -> void:
	AudioServer.set_bus_effect_enabled(1, 0, enabled)

func audio_is_spectrum_analyzer_enabled() -> bool:
	return AudioServer.is_bus_effect_enabled(1, 0)

func audio_set_muted(muted: bool) -> void:
	AudioServer.set_bus_mute(0, muted)

func audio_set_volume(volume_db: float) -> void:
	AudioServer.set_bus_volume_db(0, volume_db)

func audio_fft(from_hz: float, to_hz: float) -> float:
	var magnitude := audio_get_spectrum_analyzer().get_magnitude_for_frequency_range(
		from_hz,
		to_hz,
		AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE
	)
	return (magnitude.x + magnitude.y) / 2.0

func update_audio_analyzer() -> void:

	if !audio_is_spectrum_analyzer_enabled():
		audio_level = 0.0
		return

	# calculate peaks for visualizations

	# var audio_peak_raw = linear_to_db(audio_fft(1000, 2000) * 100.0)
	# var audio_peak_raw := audio_fft(visualizer_frequency_min, visualizer_frequency_max)
	# if is_nan(audio_peak_raw) or is_inf(audio_peak_raw):
	# 	audio_peak_raw = 0.0

	# # calculate ranges for audio level
	# audio_peak = max(audio_peak_raw, lerp(audio_peak_raw, last_peak, 0.70))

	# # if audio_peak_max_timer.time_left == 0.0:
	# audio_peak_max = lerp(audio_peak_raw, last_peak_max, 0.90)

	# if audio_peak_max < audio_peak_raw:
	# 	audio_peak_max = audio_peak_raw

	# last_peak = audio_peak
	# last_peak_max = audio_peak_max

	# # convert range from (audio_peak_raw, audio_peak_max) to (0, 1) and apply smoothing
	# audio_level_raw = clamp((audio_peak - audio_peak_raw) / (audio_peak_max - audio_peak_raw), 0.0, 1.0)
	# if is_nan(audio_level_raw):
	# 	audio_level_raw = 0.0
	# audio_level = max(audio_level_raw, lerp(audio_level_raw, last_audio_level, 0.95))
	# last_audio_level = audio_level

	var peak := db_to_linear((audio_get_peak_volume().x + audio_get_peak_volume().y) / 2.0)
	audio_level = lerp(audio_level, peak, 0.2)
	audio_level = max(audio_level, peak)
	last_audio_level = audio_level

	# %LabelAudioPeak.text = "%06f" % audio_peak_raw
	%LabelAudioPeakAvg.text = "%06f" % audio_peak
	%LabelAudioPeakMax.text = "%06f" % audio_peak_max
	%LabelAudioLevel.text = "%06f" % audio_level

	%RectAudioLevel.size.x = (audio_level_raw) * 200
	%RectAudioLevelAvg.position.x = (audio_level) * 200.0 + 88.0

func _print(text: String) -> void:
	print_rich("[color=green]%s[/color]" % text)

func _start_task(task_name: String, fn: Callable) -> Variant:
	var time := Time.get_ticks_msec()
	_print("starting task \"%s\"..." % task_name)
	var ret: Variant = fn.call()
	_print("finished task \"%s\" in %.3f seconds" % [task_name, ((Time.get_ticks_msec() - time) / 1000.0)])
	return ret

func _handle_input_keys(event: InputEvent) -> bool:
	var key := M8GD.M8_KEY_UP
	if event.is_action("key_up"): pass
	elif event.is_action("key_down"): key = M8GD.M8_KEY_DOWN
	elif event.is_action("key_left"): key = M8GD.M8_KEY_LEFT
	elif event.is_action("key_right"): key = M8GD.M8_KEY_RIGHT
	elif event.is_action("key_shift"): key = M8GD.M8_KEY_SHIFT
	elif event.is_action("key_play"): key = M8GD.M8_KEY_PLAY
	elif event.is_action("key_option"): key = M8GD.M8_KEY_OPTION
	elif event.is_action("key_edit"): key = M8GD.M8_KEY_EDIT
	else: return false

	m8_client.set_key_pressed(key, event.pressed)

	return true

func _handle_input_profile_hotkeys(event: InputEvent) -> bool:

	if (
		is_any_menu_open() or
		(
			event is not InputEventKey and
			event is not InputEventJoypadButton
		) or
		!event.is_pressed() or
		event.is_echo()
	):
		return false

	var profile_name: Variant = config.find_profile_name_from_hotkey(event)
	if profile_name is String:
		print("loading profile from hotkey: %s" % profile_name)
		load_profile(profile_name)
		return true
	
	return false

func _handle_input_keyjazz(event: InputEvent) -> bool:

	if (
		!m8_virtual_keyboard_enabled or
		is_any_menu_open() or
		event is not InputEventKey
	):
		return false

	var note := m8_virtual_keyboard_octave * 12

	match event.physical_keycode:
		KEY_MINUS:
			if event.pressed and m8_virtual_keyboard_octave > 0:
				m8_virtual_keyboard_octave -= 1
				m8_virtual_keyboard_notes.clear()
				print_blink("octave = %d" % m8_virtual_keyboard_octave)
				m8_send_keyjazz(255, 0)
			return true
		KEY_EQUAL:
			if event.pressed and m8_virtual_keyboard_octave < 10:
				m8_virtual_keyboard_octave += 1
				m8_virtual_keyboard_notes.clear()
				print_blink("octave = %d" % m8_virtual_keyboard_octave)
				m8_send_keyjazz(255, 0)
			return true
		KEY_BRACKETLEFT:
			if event.pressed and m8_virtual_keyboard_velocity > 1:
				m8_virtual_keyboard_velocity -= 1
				print_blink("velocity = %X (%d)" % [m8_virtual_keyboard_velocity, m8_virtual_keyboard_velocity])
			return true
		KEY_BRACKETRIGHT:
			if event.pressed and m8_virtual_keyboard_velocity < 127:
				m8_virtual_keyboard_velocity += 1
				print_blink("velocity = %X (%d)" % [m8_virtual_keyboard_velocity, m8_virtual_keyboard_velocity])
			return true
		KEY_A:
			pass
		KEY_W:
			note += 1
		KEY_S:
			note += 2
		KEY_E:
			note += 3
		KEY_D:
			note += 4
		KEY_F:
			note += 5
		KEY_T:
			note += 6
		KEY_G:
			note += 7
		KEY_Y:
			note += 8
		KEY_H:
			note += 9
		KEY_U:
			note += 10
		KEY_J:
			note += 11
		KEY_K:
			note += 12
		KEY_O:
			note += 13
		KEY_L:
			note += 14
		KEY_P:
			note += 15
		KEY_SEMICOLON:
			note += 16
		KEY_APOSTROPHE:
			note += 17
		_:
			return false

	if event.pressed and !event.is_echo():
		m8_send_keyjazz(note, m8_virtual_keyboard_velocity)
		m8_virtual_keyboard_notes.append(note)
		print("virtual keyboard: playing note = %d" % note)
	elif !event.pressed and m8_virtual_keyboard_notes.size() > 0:
		var last_note: int = m8_virtual_keyboard_notes[-1]
		m8_virtual_keyboard_notes.erase(note)
		if m8_virtual_keyboard_notes.size() == 0:
			m8_send_keyjazz(255, 0)
			print("virtual keyboard: note off")
		elif last_note != m8_virtual_keyboard_notes[-1]:
			m8_send_keyjazz(m8_virtual_keyboard_notes[-1], m8_virtual_keyboard_velocity)

	return true

##
## Load a M8Scene node from a filepath.
## Returns [null] if the scene is unable to load.
##
func _load_scene_from_file_path(scene_path: String) -> M8Scene:

	# load packed scene from file
	print("loading new scene from %s..." % scene_path)
	var packed_scene: PackedScene = load(scene_path.trim_suffix(".remap"))

	if packed_scene == null or !packed_scene is PackedScene:
		return null

	# instantiate scene
	print("instantiating scene...")
	var scene: M8Scene = packed_scene.instantiate()
	assert(scene != null and scene is M8Scene)

	return scene

func _overlay_update_viewport_size() -> void:

	var window_size := get_window().get_size()
	var viewport_size := Vector2i((window_size / float(overlay_integer_zoom)).ceil())

	%OverlaySubViewport.set_size(viewport_size)

	%OverlaySubViewportContainer.scale = Vector2(overlay_integer_zoom, overlay_integer_zoom)

	%OverlayControl.custom_minimum_size = window_size * overlay_integer_zoom

	%OverlayContainer.set_anchors_preset(Control.PRESET_FULL_RECT)
	%OverlayContainer.set_anchors_preset(Control.PRESET_TOP_LEFT)
