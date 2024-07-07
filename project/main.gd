class_name M8SceneDisplay extends Node

const MAIN_SCENE: PackedScene = preload ("res://scenes/floating_scene.tscn")

const FONT_01_SMALL: BitMap = preload ("res://assets/m8_fonts/5_7.bmp")
const FONT_01_BIG: BitMap = preload ("res://assets/m8_fonts/8_9.bmp")
const FONT_02_SMALL: BitMap = preload ("res://assets/m8_fonts/9_9.bmp")
const FONT_02_BOLD: BitMap = preload ("res://assets/m8_fonts/10_10.bmp")
const FONT_02_HUGE: BitMap = preload ("res://assets/m8_fonts/12_12.bmp")

const M8K_UP = 64
const M8K_DOWN = 32
const M8K_LEFT = 128
const M8K_RIGHT = 4
const M8K_SHIFT = 16
const M8K_PLAY = 8
const M8K_OPTION = 2
const M8K_EDIT = 1

const M8_ACTIONS := [
	"key_up", "key_down", "key_left", "key_right",
	"key_shift", "key_play", "key_option", "key_edit"]

signal m8_key_changed(key: String, pressed: bool)
signal m8_scene_changed

@export var visualizer_ca_amount := 1.0
@export var visualizer_glow_amount := 0.5
@export var visualizer_brightness_amount := 0.1
@export var visualizer_frequency_min := 0
@export var visualizer_frequency_max := 400

@onready var audio_monitor: AudioStreamPlayer

# @onready var scene_viewport: SubViewport = %SceneViewport
@onready var scene_root: Node = %SceneRoot
@onready var current_scene: M8Scene = null

@onready var key_overlay: M8KeyOverlay = %KeyOverlay

@onready var menu: MainMenu = %MainMenuPanel

@onready var config := M8Config.load()

@onready var m8_client := M8GD.new()
@onready var m8_connected := false
@onready var m8_audio_connected := false
@onready var m8_keystate: int = 0 # bitfield containing state of all 8 keys
@onready var m8_keystate_last: int = 0
@onready var m8_locally_controlled := false

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

func _ready() -> void:

	# resize viewport with window
	DisplayServer.window_set_min_size(Vector2i(640, 480)) # 2x M8 screen size

	# initialize key overlay
	key_overlay.init(self)

	# initialize main menu
	print("initializing menu controls...")
	menu.init(self)

	# initialize main scene
	if not load_scene(config.last_scene_path):
		_preload_scene(MAIN_SCENE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()

func quit() -> void:
	if is_instance_valid(current_scene):
		config.last_scene_path = current_scene.scene_file_path
	config.save()
	get_tree().quit()

## Temporarily show a message on the bottom-left of the screen.
func print_blink(msg: String) -> void:
	%LabelStatus.text = msg
	%LabelStatus.modulate.a = 1.0

## Return true if user is in the menu.
func is_menu_open() -> bool:
	return %MainMenuPanel.visible

## Reload the current scene.
func reload_scene() -> void:
	if current_scene:
		load_scene(current_scene.scene_file_path)

## Load a scene from a filepath.
func load_scene(scene_path: String) -> bool:
	# load packed scene from file
	print("loading new scene from %s..." % scene_path)
	var packed_scene: PackedScene = load(scene_path.trim_suffix(".remap"))

	if packed_scene == null or !packed_scene is PackedScene:
		return false

	_preload_scene(packed_scene)

	return true

func _preload_scene(packed_scene: PackedScene) -> void:

	# instantiate scene
	print("instantiating scene...")
	var scene: M8Scene = packed_scene.instantiate()
	assert(scene != null and scene is M8Scene)

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
	current_scene = scene
	current_scene.spectrum_analyzer = AudioServer.get_bus_effect_instance(1, 0)
	menu.update_device_colors()

	print("scene loaded!")
	m8_scene_changed.emit()

# M8 client methods
################################################################################

func m8_device_connect(port: String) -> void:

	var m8_ports: Array = M8GD.list_devices()

	if !port in m8_ports:
		menu.set_status_serialport("Failed: port not found: %s" % port)
		return

	menu.set_status_serialport("Connecting to serial port %s..." % m8_ports[0])

	if !m8_client.connect(port):
		menu.set_status_serialport("Failed: failed to connect to port: %s" % port)
		return

	m8_connected = true
	%LabelPort.text = m8_ports[0]
	m8_client.keystate_changed.connect(on_m8_keystate_changed)
	m8_client.system_info.connect(on_m8_system_info)
	m8_client.font_changed.connect(on_m8_font_changed)
	m8_client.device_disconnected.connect(on_m8_device_disconnect)

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

func m8_audio_connect(device: String) -> void:
	if !device in AudioServer.get_input_device_list():
		menu.set_status_audiodevice("Failed: audio device not found: %s" % device)
		return

	if is_audio_connecting: return
	is_audio_connecting = true
	AudioServer.set_bus_mute(0, true)

	if audio_monitor and is_instance_valid(audio_monitor):
		audio_monitor.stream = null
		audio_monitor.queue_free()
		remove_child(audio_monitor)
		audio_monitor = null

	menu.set_status_audiodevice("Not connected")
	await get_tree().create_timer(0.1).timeout

	AudioServer.input_device = device

	audio_monitor = AudioStreamPlayer.new()
	audio_monitor.stream = AudioStreamMicrophone.new()
	audio_monitor.bus = "Analyzer"
	add_child(audio_monitor)
	audio_monitor.playing = false

	menu.set_status_audiodevice("Starting...")
	await get_tree().create_timer(0.1).timeout

	audio_device_last = device
	audio_monitor.playing = true
	m8_audio_connected = true
	is_audio_connecting = false
	AudioServer.set_bus_mute(0, false)

	print("audio: connected to device %s" % device)
	menu.set_status_audiodevice("Connected to: %s" % device)

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

func on_m8_keystate_changed(keystate: int) -> void:
	update_keystate(keystate, false)
	m8_locally_controlled = true

func on_m8_system_info(hardware: String, firmware: String) -> void:
	%LabelVersion.text = "%s %s" % [hardware, firmware]

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

## Called when the M8 has been disconnected.
func on_m8_device_disconnect() -> void:

	m8_connected = false
	%LabelPort.text = ""

	m8_client.keystate_changed.disconnect(on_m8_keystate_changed)
	m8_client.system_info.disconnect(on_m8_system_info)
	m8_client.font_changed.disconnect(on_m8_font_changed)
	m8_client.device_disconnected.disconnect(on_m8_device_disconnect)

	if m8_audio_connected:
		m8_audio_disconnect()

	print_blink("disconnected")
	menu.set_status_serialport("Not connected (Disconnected)")

func audio_get_level() -> float:
	return audio_level

func audio_get_spectrum_analyzer() -> AudioEffectSpectrumAnalyzerInstance:
	return AudioServer.get_bus_effect_instance(1, 0)

func audio_fft(from_hz: float, to_hz: float) -> float:
	var magnitude := audio_get_spectrum_analyzer().get_magnitude_for_frequency_range(
		from_hz,
		to_hz,
		AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE
	)
	return (magnitude.x + magnitude.y) / 2.0

func m8_is_key_pressed(bit: int) -> bool:
	return m8_keystate&bit

func _physics_process(delta: float) -> void:

	# calculate peaks for visualizations

	# var audio_peak_raw = linear_to_db(audio_fft(1000, 2000) * 100.0)
	var audio_peak_raw := audio_fft(visualizer_frequency_min, visualizer_frequency_max)
	if is_nan(audio_peak_raw) or is_inf(audio_peak_raw):
		audio_peak_raw = 0.0

	# calculate ranges for audio level
	# var audio_peak_raw = (AudioServer.get_bus_peak_volume_left_db(1, 0) + AudioServer.get_bus_peak_volume_right_db(1, 0)) / 2.0
	audio_peak = max(audio_peak_raw, lerp(audio_peak_raw, last_peak, 0.70))

	# if audio_peak_max_timer.time_left == 0.0:
	audio_peak_max = lerp(audio_peak_raw, last_peak_max, 0.90)

	if audio_peak_max < audio_peak_raw:
		audio_peak_max = audio_peak_raw

	last_peak = audio_peak
	last_peak_max = audio_peak_max

	# convert range from (audio_peak_raw, audio_peak_max) to (0, 1) and apply smoothing
	# audio_level = pow(clamp(db_to_linear(audio_peak), 0.0, 1.0), 2)
	audio_level_raw = clamp((audio_peak - audio_peak_raw) / (audio_peak_max - audio_peak_raw), 0.0, 1.0)
	if is_nan(audio_level_raw):
		audio_level_raw = 0.0
	audio_level = max(audio_level_raw, lerp(audio_level_raw, last_audio_level, 0.95))
	last_audio_level = audio_level

	%LabelAudioPeak.text = "%06f" % audio_peak_raw
	%LabelAudioPeakAvg.text = "%06f" % audio_peak
	%LabelAudioPeakMax.text = "%06f" % audio_peak_max
	%LabelAudioLevel.text = "%06f" % audio_level

	%RectAudioLevel.size.x = (audio_level_raw) * 200
	%RectAudioLevelAvg.position.x = (audio_level) * 200.0 + 88.0
	
	# do shader parameter responses to audio

	var material_crt_filter: ShaderMaterial = %CRTShader.material
	material_crt_filter.set_shader_parameter("aberration", audio_level * visualizer_ca_amount)
	material_crt_filter.set_shader_parameter("brightness", 1.0 + (audio_level * visualizer_brightness_amount))

	# fade out status message

	if %LabelStatus.modulate.a > 0:
		%LabelStatus.modulate.a = lerp( %LabelStatus.modulate.a, %LabelStatus.modulate.a - delta * 2.0, 0.2)

func _process(_delta: float) -> void:

	# read and update m8 display texture every frame
	if m8_connected and m8_client.read_serial_data():
		m8_client.update_texture()

	# auto connect to m8s
	if !m8_connected:
		m8_device_connect_auto()

	# auto monitor audio if m8 is connected
	if m8_connected and !m8_audio_connected:
		m8_audio_connect_auto()

	if m8_connected and m8_audio_connected:
		m8_audio_check()

	%LabelFPS.text = "%d" % Engine.get_frames_per_second()

	var is_anything_pressed := false

	for key: String in ["key_up", "key_down", "key_left", "key_right", "key_shift", "key_play", "key_option", "key_edit"]:
		if Input.is_action_pressed(key):
			is_anything_pressed = true
			break

	# godot action to m8 controller
	if !m8_locally_controlled or m8_locally_controlled and is_anything_pressed:

		var keystate := 0

		if Input.is_action_pressed("key_up"): keystate += M8K_UP
		if Input.is_action_pressed("key_down"): keystate += M8K_DOWN
		if Input.is_action_pressed("key_left"): keystate += M8K_LEFT
		if Input.is_action_pressed("key_right"): keystate += M8K_RIGHT
		if Input.is_action_pressed("key_shift"): keystate += M8K_SHIFT
		if Input.is_action_pressed("key_play"): keystate += M8K_PLAY
		if Input.is_action_pressed("key_option"): keystate += M8K_OPTION
		if Input.is_action_pressed("key_edit"): keystate += M8K_EDIT

		update_keystate(keystate, true)

		m8_locally_controlled = false

	if Input.is_action_just_pressed("force_read"): m8_client.update_texture()

func update_keystate(keystate: int, write: bool=false) -> void:

	if keystate != m8_keystate_last:

		m8_keystate = keystate

		if write: m8_client.send_input(m8_keystate)
		# m8.send_input(m8_keystate)

		if m8_keystate&M8K_UP and !m8_keystate_last&M8K_UP: m8_key_changed.emit("up", true)
		if !m8_keystate&M8K_UP and m8_keystate_last&M8K_UP: m8_key_changed.emit("up", false)
		if m8_keystate&M8K_DOWN and !m8_keystate_last&M8K_DOWN: m8_key_changed.emit("down", true)
		if !m8_keystate&M8K_DOWN and m8_keystate_last&M8K_DOWN: m8_key_changed.emit("down", false)
		if m8_keystate&M8K_LEFT and !m8_keystate_last&M8K_LEFT: m8_key_changed.emit("left", true)
		if !m8_keystate&M8K_LEFT and m8_keystate_last&M8K_LEFT: m8_key_changed.emit("left", false)
		if m8_keystate&M8K_RIGHT and !m8_keystate_last&M8K_RIGHT: m8_key_changed.emit("right", true)
		if !m8_keystate&M8K_RIGHT and m8_keystate_last&M8K_RIGHT: m8_key_changed.emit("right", false)
		if m8_keystate&M8K_SHIFT and !m8_keystate_last&M8K_SHIFT: m8_key_changed.emit("shift", true)
		if !m8_keystate&M8K_SHIFT and m8_keystate_last&M8K_SHIFT: m8_key_changed.emit("shift", false)
		if m8_keystate&M8K_PLAY and !m8_keystate_last&M8K_PLAY: m8_key_changed.emit("play", true)
		if !m8_keystate&M8K_PLAY and m8_keystate_last&M8K_PLAY: m8_key_changed.emit("play", false)
		if m8_keystate&M8K_OPTION and !m8_keystate_last&M8K_OPTION: m8_key_changed.emit("option", true)
		if !m8_keystate&M8K_OPTION and m8_keystate_last&M8K_OPTION: m8_key_changed.emit("option", false)
		if m8_keystate&M8K_EDIT and !m8_keystate_last&M8K_EDIT: m8_key_changed.emit("edit", true)
		if !m8_keystate&M8K_EDIT and m8_keystate_last&M8K_EDIT: m8_key_changed.emit("edit", false)

		m8_keystate_last = m8_keystate

func _input(event: InputEvent) -> void:

	if event is InputEventKey:
		# fullscreen ALT+ENTER toggle
		if event.pressed and event.keycode == KEY_ENTER and event.alt_pressed:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
