class_name Main extends Node

signal m8_system_info_received(hardware: String, firmware: String)
signal m8_theme_changed(colors: PackedColorArray, complete: bool)

@warning_ignore("UNUSED_SIGNAL")
signal m8_connected

@warning_ignore("UNUSED_SIGNAL")
signal m8_disconnected

const DEVICE_SCAN_INTERVAL: float = 5.0

const MAIN_SCENE_PATH: String = "res://scenes/floating_scene.tscn"
const PATH_SCENES: String = "res://scenes/"

const FONT_01_SMALL: BitMap = preload("res://assets/m8_fonts/5_7.bmp")
const FONT_01_BIG: BitMap = preload("res://assets/m8_fonts/8_9.bmp")
const FONT_02_SMALL: BitMap = preload("res://assets/m8_fonts/9_9.bmp")
const FONT_02_BOLD: BitMap = preload("res://assets/m8_fonts/10_10.bmp")
const FONT_02_HUGE: BitMap = preload("res://assets/m8_fonts/12_12.bmp")

const M8_ACTIONS := [
	"key_up", "key_down", "key_left", "key_right", "key_shift", "key_play", "key_option", "key_edit"
]

const M8_KEYS: Array[int] = [
	LibM8.KEY_UP,
	LibM8.KEY_DOWN,
	LibM8.KEY_LEFT,
	LibM8.KEY_RIGHT,
	LibM8.KEY_SHIFT,
	LibM8.KEY_PLAY,
	LibM8.KEY_OPTION,
	LibM8.KEY_EDIT
]

static var instance: Main = null

@export var visualizer_aberration_amount := 1.0
@export var visualizer_brightness_amount := 0.1
@export var visualizer_frequency_min := 0
@export var visualizer_frequency_max := 400

@onready var label_fps: Label = %LabelFPS
@onready var label_status: Label = %LabelStatus

@onready var config := M8Config.load()

@onready var console: Console = %LabelConsole
@onready var audio_monitor: AudioStreamPlayer = %AudioStreamPlayer
@onready var label_serial_port: Label = %LabelPort
@onready var label_audio_device: Label = %LabelAudioDevice
@onready var label_hardware: Label = %LabelHardware
@onready var label_firmware: Label = %LabelFirmware

# @onready var scene_viewport: SubViewport = %SceneViewport
@onready var scene_root: Node = %SceneRoot
@onready var current_scene: M8Scene = null

@onready var overlays: OverlayContainer = %OverlayContainer
@onready var shaders: ShaderContainer = %ShaderContainer

@onready var menu: MainMenu = %MainMenuPanel
@onready var menu_scene: SceneConfigMenu = %SceneConfigMenu
@onready var menu_camera: SceneCameraMenu = %SceneCameraMenu
@onready var menu_overlay: OverlayConfigMenu = %MenuOverlay

@onready var cam_status: RichTextLabel = %CameraStatus
@onready var cam_help: RichTextLabel = %CameraControls
@onready var cam_status_template: String = cam_status.text

var m8c: GodotM8Client = GodotM8Client.new()

var m8_virtual_keyboard_enabled := false
var m8_virtual_keyboard_notes: Array[int] = []
var m8_virtual_keyboard_octave := 3
var m8_virtual_keyboard_velocity := 127

var device_manager := DeviceManager.new()

var audio_peak := 0.0  # audio peak (in dB)
var audio_peak_max := 0.0
var audio_level_raw := 0.0  # audio peak (in linear from 0.0 to 1.0)
var audio_level := 0.0  # audio peak (in linear from 0.0 to 1.0)
var last_peak := 0.0
var last_peak_max := 0.0
var last_audio_level := 0.0

# ALT+mouse dragging variables
var _window_drag_enabled := false
var _window_drag_initial_pos := Vector2.ZERO


static func is_ready() -> bool:
	return instance != null


static func get_instance(high_priority := false) -> Main:
	if not Engine.is_editor_hint():
		if not Main.is_ready():
			if high_priority:
				await Events.preinitialized
			else:
				await Events.initialized
		return instance
	return instance


func _ready() -> void:
	add_child(m8c)
	get_window().min_size = Vector2i(640, 480)

	Log.call_task(
		func() -> void:
			device_manager.init(self)
			m8c.system_info_received.connect(on_m8_system_info)
			m8c.disconnected.connect(on_m8_device_disconnect)
			m8c.theme_colors_updated.connect(on_m8_theme_changed)
			m8c.key_pressed.connect(Events.device_key_pressed.emit),
		"init devices"
	)

	get_window().size_changed.connect(Events.window_modified.emit)

	Events.preset_loaded.connect(_on_preset_loaded)

	# %Check_SplashDoNotShow.toggled.connect(
	# 	func(toggle_mode: bool) -> void: config.splash_show = !toggle_mode
	# )
	# %ButtonSplashClose.pressed.connect(func() -> void: %SplashContainer.visible = false)
	# %SplashContainer.visible = config.splash_show

	instance = self
	Log.call_task(Events.preinitialized.emit.bind(self), "emit preinitialized signal")
	Log.call_task(Events.initialized.emit.bind(self), "emit initialized signal")

	device_manager.start_waiting_for_devices()
	_update_labels()

	load_last_profile()


func _process(delta: float) -> void:
	device_manager._process(delta)
	label_fps.text = "%d" % Engine.get_frames_per_second()

	# var palette := m8_get_theme_colors()
	# if palette.size() < 16:
	# 	for i in range(16):
	# 		get_node("%%Color_Palette%d" % (i + 1)).color = Color(0, 0, 0, 0)
	# 	for i in range(palette.size()):
	# 		get_node("%%Color_Palette%d" % (i + 1)).color = palette[i]


func _physics_process(delta: float) -> void:
	update_audio_analyzer()

	# var modulate_color := m8c.get_theme_colors()[0]
	# modulate_color.v = 1.0
	# %BGShader.material.set_shader_parameter("tint_color", modulate_color)

	# %BGShader.material.set_shader_parameter("brightness", 1.0 + (audio_level * visualizer_brightness_amount))

	# fade out status message

	if label_status.modulate.a > 0:
		label_status.modulate.a = lerp(
			label_status.modulate.a, label_status.modulate.a - delta * 2.0, 0.2
		)


func _input(event: InputEvent) -> void:
	# ALT+mouse window dragging
	if get_window().mode == Window.MODE_WINDOWED:
		if event is InputEventMouseButton:
			var event_mb := event as InputEventMouseButton
			if event_mb.button_index == MOUSE_BUTTON_LEFT:
				if event_mb.pressed and Input.is_key_pressed(KEY_ALT) and !_window_drag_enabled:
					_window_drag_enabled = true
					_window_drag_initial_pos = get_window().get_mouse_position()
				elif !event_mb.pressed and _window_drag_enabled:
					_window_drag_enabled = false

		if event is InputEventMouseMotion:
			if _window_drag_enabled:
				var delta := get_window().get_mouse_position() - _window_drag_initial_pos
				get_window().position += Vector2i(delta)

	if event is InputEventKey:
		var event_key := event as InputEventKey
		# screenshot F12
		if event_key.pressed and event_key.keycode == KEY_F12:
			var id := 1
			var screenshot_name := "%d.png" % id

			while FileAccess.file_exists(screenshot_name):
				id += 1
				screenshot_name = "%d.png" % id

			get_viewport().get_texture().get_image().save_png(screenshot_name)
			print_to_screen("Screenshot saved as %s" % screenshot_name)

		# fullscreen ALT+ENTER toggle
		if event_key.pressed and event_key.keycode == KEY_ENTER and event_key.alt_pressed:
			if get_window().mode == Window.MODE_WINDOWED:
				get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			else:
				get_window().mode = Window.MODE_WINDOWED

		# manual reset audio
		if event_key.pressed and event_key.keycode == KEY_R and event_key.ctrl_pressed:
			device_manager.reset_audio_device()

		if event_key.pressed and event_key.keycode == KEY_ESCAPE:
			# if %SplashContainer.visible:
			# 	%SplashContainer.visible = false
			# 	return

			# menu on/off toggle
			if is_menu_open():
				main_menu_hide()
			else:
				main_menu_show()

	if _handle_input_keys(event):
		return

	if _handle_input_hotkeys_overlays(event):
		return

	if _handle_input_hotkeys_presets(event):
		return

	if _handle_input_keyjazz(event):
		return


func _notification(what: int) -> void:
	# enable quitting by clicking the X on the window.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


func quit() -> void:
	config.save()
	Events.deinitialized.emit()
	device_manager.disconnect_serial_device()
	device_manager.disconnect_audio_device()
	get_tree().quit()


## Temporarily show a message on the bottom-left of the screen.
func print_to_screen(msg: String) -> void:
	console.print_line(msg)


## Return true if user is in the menu.
func is_menu_open() -> bool:
	return menu.visible


func is_any_menu_open() -> bool:
	return menu.visible or menu_scene.visible or menu_camera.visible or menu_overlay.visible


func main_menu_show() -> void:
	menu_camera.menu_hide()
	menu_scene.menu_hide()
	menu_overlay.menu_hide()
	menu.menu_show()


func main_menu_hide() -> void:
	menu.menu_hide()


##
## Return the name of an M8 scene from its file.
## The scene's formatted name is stored in the export variable [m8_scene_name].
##
func get_scene_name(scene_path: String) -> String:
	return scene_path.get_file().get_basename().capitalize().trim_suffix("Scene").strip_edges()


##
## Load an M8 scene from a filepath.
##
## If the scene has loaded successfully, returns [true].
## If the filepath is invalid or the scene is unable to load, returns [false].
##
func load_scene(scene_path: String) -> bool:
	return Log.call_task(
		func() -> bool:
			var scene: M8Scene
			var p_scene_path := scene_path

			if current_scene == null or scene_path != current_scene.scene_file_path:
				print("load_scene(): loading new scene...")

				scene = _load_scene_from_file_path(p_scene_path)

				if !scene is M8Scene:
					p_scene_path = MAIN_SCENE_PATH
					scene = _load_scene_from_file_path(MAIN_SCENE_PATH)

				# remove existing scene from viewport if there is one
				if current_scene:
					print("freeing current scene...")
					scene_root.remove_child(current_scene)
					current_scene.queue_free()
					current_scene = null

				# add new scene
				scene_root.add_child(scene)
			else:
				print("load_scene(): reloading same scene...")
				scene = current_scene

			print("load_scene(): initializing scene...")

			# initialize scene and config
			scene.init(self)
			config.set_scene(scene)
			current_scene = scene

			Events.scene_loaded.emit(p_scene_path, scene)

			print("load_scene(): scene loaded!")

			return true,
		'load scene "%s"' % scene_path
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
	config.preset_load_last()


func _on_preset_loaded(_preset_name: String) -> void:
	var scene_path := config.get_current_scene_path()
	assert(scene_path != null)

	load_scene(scene_path)
	m8c.set_display_bg_alpha(0.0)


func load_default_profile() -> void:
	config.preset_load_new()


##
## Get the name of the active profile.
##
func get_current_profile_name() -> String:
	return config.current_preset_name


func list_preset_names() -> Array:
	return config.list_preset_names()


func preset_delete(profile_name: String) -> void:
	if profile_name == get_current_profile_name():
		load_default_profile()
	config.preset_delete(profile_name)


##
## Get the 3D camera of the current scene.
## Return [null] if there is no camera present in the scene.
##
func get_scene_camera() -> M8SceneCamera3D:
	if current_scene:
		return current_scene.get_3d_camera()
	else:
		return null


##
## Try to return the device model in the current scene.
## If there isn't one, returns null.
##
func get_scene_m8_model() -> DeviceModel:
	if current_scene and current_scene.has_device_model():
		return current_scene.get_device_model()
	else:
		return null


# M8 client methods
################################################################################


func _update_labels() -> void:
	if not is_instance_valid(m8c):
		return

	if device_manager.is_serial_device_connected():
		label_serial_port.text = "serial port: %s" % device_manager.current_serial_device
		label_hardware.text = "HW: %s" % m8c.get_hardware_name()
		label_firmware.text = "FW: %s" % m8c.get_firmware_version()
	else:
		label_serial_port.text = "waiting for serial port..."
		label_hardware.text = ""
		label_firmware.text = ""

	if device_manager.is_audio_device_connected():
		label_audio_device.text = "audio device: %s" % device_manager.current_audio_device
	else:
		label_audio_device.text = "waiting for audio device..."


func on_m8_system_info(hardware: String, firmware: String) -> void:
	_update_labels()
	m8_system_info_received.emit(hardware, firmware)


## Called when the M8 has been disconnected.
func on_m8_device_disconnect() -> void:
	_update_labels()
	device_manager.disconnect_serial_device()


func on_m8_theme_changed(colors: PackedColorArray) -> void:
	m8_theme_changed.emit(colors, true)


func m8_send_theme_color(index: int, color: Color) -> void:
	m8c.set_theme_color(index, color)


func m8_send_enable_display() -> void:
	m8c.debug_enable_display()


func m8_send_disable_display() -> void:
	m8c.debug_enable_display()


func m8_send_reset_display() -> void:
	m8c.debug_reset_display()


func m8_send_keyjazz(note: int, velocity: int) -> void:
	m8c.play_note(note, velocity)


func m8_send_control(keys: int) -> void:
	m8c.debug_set_keys(keys)


func m8_is_key_pressed(keycode: int) -> bool:
	return m8c.is_key_pressed(keycode)


func m8_get_theme_colors() -> PackedColorArray:
	return m8c.get_theme_colors()


func m8_set_font(font: int, bitmap: BitMap) -> void:
	m8c.set_font_bitmap(font, bitmap)


func m8_set_font_from_file(font: int, path: String) -> void:
	if not path:
		return
	# no BitMap loader at the moment, so we load an image then
	# create a BitMap from scratch here
	var image := Image.load_from_file(path)
	if image:
		var bitmap := BitMap.new()
		bitmap.create(image.get_size())
		for i in image.get_width():
			for j in image.get_height():
				bitmap.set_bit(i, j, image.get_pixel(i, j).r)

		m8_set_font(font, bitmap)


func audio_set_handler(handler: DeviceManager.AudioHandler) -> void:
	device_manager.audio_set_handler(handler)


##
## Get the peak volume of the "Analyzer" bus.
##
func audio_get_peak_volume() -> Vector2:
	return device_manager.audio_get_peak_volume()


func audio_get_spectrum_analyzer() -> AudioEffectSpectrumAnalyzerInstance:
	return AudioServer.get_bus_effect_instance(0, 0)


func audio_set_spectrum_analyzer_enabled(enabled: bool) -> void:
	device_manager.audio_set_spectrum_analyzer_enabled(enabled)


func audio_is_spectrum_analyzer_enabled() -> bool:
	return device_manager.audio_is_spectrum_analyzer_enabled()


## Set audio volume, where [volume] is a float between 0.0 and 1.0.
func audio_set_volume(volume: float) -> void:
	device_manager.audio_set_volume(volume)


func audio_get_magnitude_at_freq(frequency: float) -> float:
	return device_manager.audio_get_magnitude_at_freq(frequency)


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

	var label_audio_peak_avg: Label = %LabelAudioPeakAvg
	var label_audio_peak_max: Label = %LabelAudioPeakMax
	var label_audio_level: Label = %LabelAudioLevel
	var rect_audio_level: ColorRect = %RectAudioLevel
	var rect_audio_level_avg: ColorRect = %RectAudioLevelAvg

	# label_audio_peak_avg.text = "%06f" % audio_peak
	label_audio_peak_avg.text = "%06f" % audio_peak
	label_audio_peak_max.text = "%06f" % audio_peak_max
	label_audio_level.text = "%06f" % audio_level

	rect_audio_level.size.x = (audio_level_raw) * 200
	rect_audio_level_avg.position.x = (audio_level) * 200.0 + 88.0


func display_get_scale() -> float:
	return get_window().content_scale_factor


func display_set_scale(scale: float) -> void:
	if scale < 1.0:
		scale = min(display_get_auto_scale(), display_get_max_scale())
		Log.ln("Auto UI scale detected: %.2f" % scale)
	else:
		scale = min(scale, display_get_max_scale())

	Log.ln("UI scale set to: %.2f" % scale)

	var menu_container: ScalableContainer = %MenuContainer
	# get_window().content_scale_factor = scale
	menu_container.content_scale = floori(scale * 2)
	Events.window_modified.emit()


## Based on [get_auto_display_scale()] from the Godot editor source code.
## Only returns integer scale values.
func display_get_auto_scale() -> float:
	var dispname := DisplayServer.get_name()

	if dispname == "Wayland":
		var dispscale := DisplayServer.screen_get_scale(DisplayServer.SCREEN_OF_MAIN_WINDOW)
		if DisplayServer.get_screen_count() == 1:
			dispscale = DisplayServer.screen_get_max_scale()
		return floor(dispscale)

	if OS.get_name() == "macOS" or OS.get_name() == "Android":
		return floor(DisplayServer.screen_get_max_scale())

	var screen := DisplayServer.window_get_current_screen()

	if DisplayServer.screen_get_size(screen) != Vector2i():
		var screen_dpi := DisplayServer.screen_get_dpi(screen)
		if OS.get_name() == "Windows":
			return floor(screen_dpi / 96.0)

		# guess scale based on DPI
		var screen_min: int = min(
			DisplayServer.screen_get_size(screen).x, DisplayServer.screen_get_size(screen).y
		)
		if screen_dpi >= 192 and screen_min >= 1400:
			return 2.0

	return 1.0


func display_get_max_scale() -> float:
	var horizontal_scale: float = floor(get_window().size.x / 640.0)
	var vertical_scale: float = floor(get_window().size.y / 480.0)
	return min(horizontal_scale, vertical_scale)


func _handle_input_keys(event: InputEvent) -> bool:
	if is_any_menu_open():
		return false

	var key := LibM8.KEY_UP
	if event.is_action("key_up"):
		pass
	elif event.is_action("key_down"):
		key = LibM8.KEY_DOWN
	elif event.is_action("key_left"):
		key = LibM8.KEY_LEFT
	elif event.is_action("key_right"):
		key = LibM8.KEY_RIGHT
	elif event.is_action("key_shift"):
		key = LibM8.KEY_SHIFT
	elif event.is_action("key_play"):
		key = LibM8.KEY_PLAY
	elif event.is_action("key_option"):
		key = LibM8.KEY_OPTION
	elif event.is_action("key_edit"):
		key = LibM8.KEY_EDIT
	else:
		return false

	m8c.set_key_pressed(key, event.is_pressed())

	return true


func _handle_input_hotkeys_presets(event: InputEvent) -> bool:
	if (
		is_any_menu_open()
		or (event is not InputEventKey and event is not InputEventJoypadButton)
		or !event.is_pressed()
		or event.is_echo()
	):
		return false

	var profile_name: String = config.find_profile_name_from_hotkey(event)
	if profile_name != "":
		print("loading profile from hotkey: %s" % profile_name)
		config.preset_load(profile_name)
		return true

	return false


func _handle_input_hotkeys_overlays(event: InputEvent) -> bool:
	if (
		is_any_menu_open()
		or (event is not InputEventKey and event is not InputEventJoypadButton)
		or !event.is_pressed()
		or event.is_echo()
	):
		return false

	var overlay_node_path: String = config.find_overlay_node_path_from_hotkey(event)
	if overlay_node_path != "":
		print("toggling overlay from hotkey: %s" % overlay_node_path)
		var overlay: OverlayBase = overlays.get_node("%" + overlay_node_path)
		if overlay:
			overlay.visible = not overlay.visible
		return true

	return false


func _handle_input_keyjazz(e: InputEvent) -> bool:
	if !m8_virtual_keyboard_enabled or is_any_menu_open() or e is not InputEventKey:
		return false

	var event := e as InputEventKey
	var note := m8_virtual_keyboard_octave * 12

	match event.physical_keycode:
		KEY_MINUS:
			if event.pressed and m8_virtual_keyboard_octave > 0:
				m8_virtual_keyboard_octave -= 1
				m8_virtual_keyboard_notes.clear()
				print_to_screen("octave = %d" % m8_virtual_keyboard_octave)
				m8_send_keyjazz(255, 0)
			return true
		KEY_EQUAL:
			if event.pressed and m8_virtual_keyboard_octave < 10:
				m8_virtual_keyboard_octave += 1
				m8_virtual_keyboard_notes.clear()
				print_to_screen("octave = %d" % m8_virtual_keyboard_octave)
				m8_send_keyjazz(255, 0)
			return true
		KEY_BRACKETLEFT:
			if event.pressed and m8_virtual_keyboard_velocity > 1:
				m8_virtual_keyboard_velocity -= 1
				print_to_screen(
					(
						"velocity = %X (%d)"
						% [m8_virtual_keyboard_velocity, m8_virtual_keyboard_velocity]
					)
				)
			return true
		KEY_BRACKETRIGHT:
			if event.pressed and m8_virtual_keyboard_velocity < 127:
				m8_virtual_keyboard_velocity += 1
				print_to_screen(
					(
						"velocity = %X (%d)"
						% [m8_virtual_keyboard_velocity, m8_virtual_keyboard_velocity]
					)
				)
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
